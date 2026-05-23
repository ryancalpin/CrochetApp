import XCTest
@testable import Looplet

/// Tests for CounterStore's pure counter arithmetic. A store with no `library`
/// reference performs no persistence (`sync()` no-ops), so these run without any
/// file I/O. `autoResetStitches` is forced to a known value per test for determinism.
final class CounterStoreTests: XCTestCase {

    private func makeStore(autoReset: Bool) -> CounterStore {
        AppSettings.shared.autoResetStitches = autoReset
        AppSettings.shared.audioCueEnabled = false
        let store = CounterStore()
        store.library = nil
        return store
    }

    // MARK: - Row

    func testIncrementRow() {
        let store = makeStore(autoReset: false)
        store.incrementRow()
        store.incrementRow()
        XCTAssertEqual(store.rowCount, 2)
    }

    func testIncrementRowResetsStitchesWhenAutoResetOn() {
        let store = makeStore(autoReset: true)
        store.incrementStitch()
        store.incrementStitch()
        XCTAssertEqual(store.stitchCount, 2)
        store.incrementRow()
        XCTAssertEqual(store.rowCount, 1)
        XCTAssertEqual(store.stitchCount, 0)
    }

    func testIncrementRowKeepsStitchesWhenAutoResetOff() {
        let store = makeStore(autoReset: false)
        store.incrementStitch()
        store.incrementStitch()
        store.incrementRow()
        XCTAssertEqual(store.rowCount, 1)
        XCTAssertEqual(store.stitchCount, 2)
    }

    func testDecrementRowClampsAtZero() {
        let store = makeStore(autoReset: false)
        store.decrementRow()
        XCTAssertEqual(store.rowCount, 0)
        store.incrementRow()
        store.decrementRow()
        XCTAssertEqual(store.rowCount, 0)
    }

    func testEndRowIncrementsRowAndZeroesStitches() {
        let store = makeStore(autoReset: false)
        store.incrementStitch()
        store.incrementStitch()
        store.endRow()
        XCTAssertEqual(store.rowCount, 1)
        XCTAssertEqual(store.stitchCount, 0)
    }

    // MARK: - Stitch

    func testIncrementAndDecrementStitch() {
        let store = makeStore(autoReset: false)
        store.incrementStitch()
        store.incrementStitch()
        store.incrementStitch()
        XCTAssertEqual(store.stitchCount, 3)
        store.decrementStitch()
        XCTAssertEqual(store.stitchCount, 2)
    }

    func testDecrementStitchClampsAtZero() {
        let store = makeStore(autoReset: false)
        store.decrementStitch()
        XCTAssertEqual(store.stitchCount, 0)
    }

    // MARK: - Repeat

    func testIncrementDecrementResetRepeat() {
        let store = makeStore(autoReset: false)
        store.incrementRepeat()
        store.incrementRepeat()
        XCTAssertEqual(store.repeatCount, 2)
        store.decrementRepeat()
        XCTAssertEqual(store.repeatCount, 1)
        store.resetRepeat()
        XCTAssertEqual(store.repeatCount, 0)
    }

    func testDecrementRepeatClampsAtZero() {
        let store = makeStore(autoReset: false)
        store.decrementRepeat()
        XCTAssertEqual(store.repeatCount, 0)
    }

    // MARK: - Reset & load

    func testResetZeroesAllCounters() {
        let store = makeStore(autoReset: false)
        store.incrementRow()
        store.incrementStitch()
        store.incrementRepeat()
        store.reset()
        XCTAssertEqual(store.rowCount, 0)
        XCTAssertEqual(store.stitchCount, 0)
        XCTAssertEqual(store.repeatCount, 0)
    }

    func testLoadFromEntry() throws {
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "displayName": "Loaded",
            "bookmark": "Ym9va21hcms=",
            "lastOpened": 700000000.0,
            "isPinned": false,
            "rowCount": 7,
            "stitchCount": 4,
            "repeatCount": 2
        }
        """
        let entry = try JSONDecoder().decode(PatternEntry.self, from: Data(json.utf8))
        let store = makeStore(autoReset: false)
        store.load(from: entry)
        XCTAssertEqual(store.rowCount, 7)
        XCTAssertEqual(store.stitchCount, 4)
        XCTAssertEqual(store.repeatCount, 2)
    }
}
