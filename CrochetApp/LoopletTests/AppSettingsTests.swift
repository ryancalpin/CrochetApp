import XCTest
import SwiftUI
@testable import Looplet

final class AppSettingsTests: XCTestCase {

    func testColorSchemeMapping() {
        XCTAssertNil(AppSettings.AppearanceMode.system.colorScheme)
        XCTAssertEqual(AppSettings.AppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppSettings.AppearanceMode.dark.colorScheme, .dark)
    }

    func testAppearanceModeLabels() {
        XCTAssertEqual(AppSettings.AppearanceMode.system.label, "System")
        XCTAssertEqual(AppSettings.AppearanceMode.light.label, "Light")
        XCTAssertEqual(AppSettings.AppearanceMode.dark.label, "Dark")
    }

    func testAppearanceModeRawRoundTrip() {
        for mode in AppSettings.AppearanceMode.allCases {
            XCTAssertEqual(AppSettings.AppearanceMode(rawValue: mode.rawValue), mode)
        }
    }

    func testCounterSizeFontAndLabels() {
        XCTAssertEqual(AppSettings.CounterSize.compact.label, "Compact")
        XCTAssertEqual(AppSettings.CounterSize.normal.label, "Normal")
        XCTAssertEqual(AppSettings.CounterSize.large.label, "Large")
        // Font size grows monotonically with size.
        XCTAssertLessThan(AppSettings.CounterSize.compact.fontSize, AppSettings.CounterSize.normal.fontSize)
        XCTAssertLessThan(AppSettings.CounterSize.normal.fontSize, AppSettings.CounterSize.large.fontSize)
    }
}
