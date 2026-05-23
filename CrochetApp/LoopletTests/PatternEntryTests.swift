import XCTest
@testable import Looplet

final class PatternEntryTests: XCTestCase {

    /// Minimal-but-complete JSON for a PatternEntry. `bookmark` is any base64 blob —
    /// decoding never resolves it. `lastOpened` is encoded as the default JSONDecoder
    /// expects for `Date`: seconds since the reference date (2001-01-01) as a Double.
    private func minimalJSON(
        id: String = "11111111-1111-1111-1111-111111111111",
        displayName: String = "Granny Square Blanket"
    ) -> Data {
        let json = """
        {
            "id": "\(id)",
            "displayName": "\(displayName)",
            "bookmark": "Ym9va21hcms=",
            "lastOpened": 700000000.0,
            "isPinned": false,
            "rowCount": 12,
            "stitchCount": 5
        }
        """
        return Data(json.utf8)
    }

    func testDecodeMinimalEntry() throws {
        let entry = try JSONDecoder().decode(PatternEntry.self, from: minimalJSON())
        XCTAssertEqual(entry.displayName, "Granny Square Blanket")
        XCTAssertEqual(entry.rowCount, 12)
        XCTAssertEqual(entry.stitchCount, 5)
        XCTAssertFalse(entry.isPinned)
        // bookmark base64 "Ym9va21hcms=" decodes to "bookmark".
        XCTAssertEqual(String(data: entry.bookmark, encoding: .utf8), "bookmark")
    }

    func testOptionalFieldsDefaultGracefully() throws {
        let entry = try JSONDecoder().decode(PatternEntry.self, from: minimalJSON())
        // Fields absent from the JSON should fall back to their defaults.
        XCTAssertTrue(entry.autoResetStitch)
        XCTAssertEqual(entry.repeatCount, 0)
        XCTAssertFalse(entry.showRepeatCounter)
        XCTAssertNil(entry.rowGoal)
        XCTAssertNil(entry.stitchGoal)
        XCTAssertTrue(entry.tags.isEmpty)
        XCTAssertTrue(entry.annotations.isEmpty)
        XCTAssertNil(entry.aiSummary)
        XCTAssertNil(entry.aiAbbreviations)
        XCTAssertNil(entry.aiMaterials)
        XCTAssertNil(entry.aiDifficulty)
        XCTAssertNil(entry.aiTimeEstimate)
    }

    func testCodableRoundTripIsStable() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let first = try decoder.decode(PatternEntry.self, from: minimalJSON())
        let reencoded = try encoder.encode(first)
        let second = try decoder.decode(PatternEntry.self, from: reencoded)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.displayName, second.displayName)
        XCTAssertEqual(first.rowCount, second.rowCount)
        XCTAssertEqual(first.stitchCount, second.stitchCount)
        XCTAssertEqual(first.isPinned, second.isPinned)
        XCTAssertEqual(first.bookmark, second.bookmark)
    }

    func testStableIDPreservedThroughDecode() throws {
        let entry = try JSONDecoder().decode(PatternEntry.self, from: minimalJSON())
        XCTAssertEqual(entry.id, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
    }
}
