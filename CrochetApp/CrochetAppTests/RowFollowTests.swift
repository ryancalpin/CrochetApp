import XCTest
@testable import CrochetApp

/// Verifies the multi-part row auto-follow selection without needing the UI.
final class RowFollowTests: XCTestCase {

    // Mirrors the anatomical heart structure: several parts, each restarting at "Rnd 1".
    private let heartLike: [String] = [
        "Anatomical Heart Plush",            // 0  h1
        "PART 1 — Main Body",                // 1  h2
        "Rnd 1: MR, 6 sc. (6)",              // 2
        "Rnd 2: [inc] x 6. (12)",            // 3
        "Rnd 3: [sc, inc] x 6. (18)",        // 4
        "Rnds 5–7: sc around. (24)",         // 5  range row (won't match a single number)
        "Rnd 8: [sc 2, dec] x 6. (18)",      // 6
        "PART 2 — Right Ventricle Bump",     // 7  h2
        "Rnd 1: MR, 6 sc. (6)",              // 8
        "Rnd 2: [inc] x 6. (12)",            // 9
        "PART 3 — Aortic Arch",              // 10 h2
        "Rnd 1: MR, 6 sc. (6)",              // 11
        "Rnd 2: [inc] x 6. (12)"             // 12
    ]

    func testCountingUpStaysInPartOne() throws {
        var anchor = -1
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 1, anchor: anchor))
        XCTAssertEqual(anchor, 2, "Fresh open at Rnd 1 → Part 1's Rnd 1")
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 2, anchor: anchor))
        XCTAssertEqual(anchor, 3)
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 3, anchor: anchor))
        XCTAssertEqual(anchor, 4)
        // Rnd 8 (after the 5–7 range) still follows forward in Part 1.
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 8, anchor: anchor))
        XCTAssertEqual(anchor, 6)
    }

    func testResetToOneAdvancesIntoNextPart() {
        // Anchor sitting at Part 1's last matched round (index 6).
        let toPart2 = RowFollow.targetIndex(in: heartLike, row: 1, anchor: 6)
        XCTAssertEqual(toPart2, 8, "Reset to Rnd 1 from Part 1 → Part 2's Rnd 1, NOT Part 1's (index 2)")

        // From Part 2, reset again → Part 3.
        let toPart3 = RowFollow.targetIndex(in: heartLike, row: 1, anchor: 9)
        XCTAssertEqual(toPart3, 11, "Reset to Rnd 1 from Part 2 → Part 3's Rnd 1")
    }

    func testRangeRowMatchesWithinRange() {
        // "Rnds 5–7" (index 5) matches rows 5, 6, 7 — but not 4 or 8.
        XCTAssertEqual(RowFollow.matchingIndices(in: heartLike, row: 5), [5])
        XCTAssertEqual(RowFollow.matchingIndices(in: heartLike, row: 6), [5])
        XCTAssertEqual(RowFollow.matchingIndices(in: heartLike, row: 7), [5])
        XCTAssertEqual(RowFollow.matchingIndices(in: heartLike, row: 8), [6], "Standalone Rnd 8, not the range")
    }

    func testCountingThroughARangeStaysThenAdvances() throws {
        var anchor = 4 // at Rnd 3
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 5, anchor: anchor))
        XCTAssertEqual(anchor, 5, "Rnd 5 → the Rnds 5–7 range element")
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 6, anchor: anchor))
        XCTAssertEqual(anchor, 5, "Rnd 6 stays on the range element")
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 7, anchor: anchor))
        XCTAssertEqual(anchor, 5, "Rnd 7 stays on the range element")
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: heartLike, row: 8, anchor: anchor))
        XCTAssertEqual(anchor, 6, "Rnd 8 advances past the range")
    }

    func testCountingWithinRangeStaysDespiteLaterOverlappingRange() throws {
        // Mirrors the real heart: Part 1 has "Rnds 7–12" and a later part has
        // "Rnds 2–12" — both match rows 8–12. Counting within Part 1's range must STAY
        // on Part 1, not jump to the later part.
        let texts = [
            "PART 1",            // 0
            "Rnd 6: sc",         // 1
            "Rnds 7–12: sc",     // 2  Part 1 range
            "Rnd 13: dec",       // 3
            "PART 3 — Aortic",   // 4
            "Rnd 1: MR",         // 5
            "Rnds 2–12: sc"      // 6  Part 3 range (also matches 7–12)
        ]
        var anchor = 1 // at Rnd 6 in Part 1
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: texts, row: 7, anchor: anchor))
        XCTAssertEqual(anchor, 2, "Rnd 7 enters Part 1's range")
        for r in 8...12 {
            anchor = try XCTUnwrap(RowFollow.targetIndex(in: texts, row: r, anchor: anchor))
            XCTAssertEqual(anchor, 2, "Rnd \(r) must stay on Part 1's range, not jump to Part 3's")
        }
        anchor = try XCTUnwrap(RowFollow.targetIndex(in: texts, row: 13, anchor: anchor))
        XCTAssertEqual(anchor, 3, "Rnd 13 advances to Part 1's next round")
    }

    func testRangeWithPlainHyphen() {
        // Accept hyphen-minus as well as en/em dashes.
        let texts = ["Rows 10-12: sc across"]
        XCTAssertEqual(RowFollow.matchingIndices(in: texts, row: 11), [0])
        XCTAssertEqual(RowFollow.matchingIndices(in: texts, row: 13), [])
    }

    func testSteppingBackWithinAPart() {
        // In Part 3 at Rnd 2 (anchor 12), going back to Rnd 1 should pick Part 3's Rnd 1
        // (the closest at/before the anchor), not an earlier part's.
        XCTAssertEqual(RowFollow.targetIndex(in: heartLike, row: 1, anchor: 12), 11)
    }

    func testWordBoundaryAvoidsSubstringMatch() {
        let texts = ["Rnd 1: x", "Rnd 17: x", "Rnd 170: x"]
        XCTAssertEqual(RowFollow.matchingIndices(in: texts, row: 1), [0],
                       "\"Rnd 1\" must not match \"Rnd 17\" or \"Rnd 170\"")
        XCTAssertEqual(RowFollow.matchingIndices(in: texts, row: 17), [1])
    }

    func testHandlesRowAndRoundKeywords() {
        let texts = ["Row 1: ch 2", "Round 1: 6 sc", "Rnd 1: MR"]
        XCTAssertEqual(RowFollow.matchingIndices(in: texts, row: 1), [0, 1, 2])
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(RowFollow.targetIndex(in: heartLike, row: 99, anchor: 5))
    }
}
