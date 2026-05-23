import XCTest
@testable import Looplet

final class PatternExporterTests: XCTestCase {

    /// Decode a PatternEntry from JSON, optionally embedding AI summary fields.
    private func entry(
        displayName: String = "Cozy Scarf",
        withSummary: Bool = false
    ) throws -> PatternEntry {
        let summaryBlock = withSummary ? """
        ,
            "aiSummary": {
                "patternName": "Cozy Scarf",
                "skillLevel": "Beginner",
                "materials": "Worsted yarn, 5mm hook",
                "totalRows": "40",
                "estimatedTime": "About 2 hr",
                "keyStitches": "sc, dc"
            }
        """ : ""

        let json = """
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "displayName": "\(displayName)",
            "bookmark": "Ym9va21hcms=",
            "lastOpened": 700000000.0,
            "isPinned": false,
            "rowCount": 8,
            "stitchCount": 3\(summaryBlock)
        }
        """
        return try JSONDecoder().decode(PatternEntry.self, from: Data(json.utf8))
    }

    func testMarkdownHasH1Title() throws {
        let md = PatternExporter.markdown(for: try entry())
        XCTAssertTrue(md.contains("# Cozy Scarf"), "Markdown should start with the displayName as an H1")
    }

    func testMarkdownHasPatternSection() throws {
        let md = PatternExporter.markdown(for: try entry())
        XCTAssertTrue(md.contains("## Pattern"), "Markdown should include a Pattern section")
    }

    func testMarkdownWithNilInsightsIsNonEmptyAndHasNoLiteralNil() throws {
        let md = PatternExporter.markdown(for: try entry(withSummary: false))
        XCTAssertFalse(md.isEmpty)
        // Progress line is always present even with no AI insights.
        XCTAssertTrue(md.contains("**Progress:**"))
        // No literal "nil" leaking from optional interpolation.
        XCTAssertFalse(md.contains("nil"), "Markdown should not contain a literal 'nil'")
    }

    func testMarkdownIncludesSummaryFieldsWhenPresent() throws {
        let md = PatternExporter.markdown(for: try entry(withSummary: true))
        XCTAssertTrue(md.contains("**Skill Level:** Beginner"))
        XCTAssertTrue(md.contains("**Total Rows:** 40"))
        XCTAssertTrue(md.contains("**Key Stitches:** sc, dc"))
    }
}
