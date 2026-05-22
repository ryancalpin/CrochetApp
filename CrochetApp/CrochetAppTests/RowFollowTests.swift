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

    func testRangeRowDoesNotForceBackToPartOne() {
        // Row 6 lives only inside the "Rnds 5–7" range (no standalone match), so no jump.
        XCTAssertNil(RowFollow.targetIndex(in: heartLike, row: 6, anchor: 8),
                     "A row that only exists inside a range should not match → no scroll")
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
