import XCTest
@testable import Looplet

/// Tests for the deterministic `PatternAIService.estimatedTime(fromRows:rowsPerHour:)`
/// helper. Gated to macOS 26 because the helper lives on the `@available(macOS 26.0, *)`
/// service type.
@available(macOS 26.0, *)
@MainActor
final class PatternAIServiceTests: XCTestCase {

    func testWholeHoursFromRows() {
        // 60 rows at 20 rows/hour = 3.0 hours.
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "60", rowsPerHour: 20), "About 3 hr")
    }

    func testSubHourReturnsMinutes() {
        // 30 rows at 60 rows/hour = 0.5 hours = 30 min.
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "30", rowsPerHour: 60), "About 30 min")
    }

    func testFractionalHours() {
        // 30 rows at 20 rows/hour = 1.5 hours.
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "30", rowsPerHour: 20), "About 1.5 hr")
    }

    func testNonNumericRowsReturnsUnknown() {
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "Unknown", rowsPerHour: 20), "Unknown")
    }

    func testZeroRowsReturnsUnknown() {
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "0", rowsPerHour: 20), "Unknown")
    }

    func testZeroRowsPerHourReturnsUnknown() {
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "60", rowsPerHour: 0), "Unknown")
    }

    func testEmbeddedDigitsAreExtracted() {
        // Non-digit characters are stripped, leaving 60 -> 3 hr at 20/hr.
        XCTAssertEqual(PatternAIService.estimatedTime(fromRows: "Row 60", rowsPerHour: 20), "About 3 hr")
    }
}
