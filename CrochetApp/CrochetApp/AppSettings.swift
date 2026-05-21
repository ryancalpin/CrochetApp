import SwiftUI

/// Singleton that owns all user-configurable preferences, backed by UserDefaults via @AppStorage.
/// Observe it with `@ObservedObject private var settings = AppSettings.shared` in any View.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()
    private init() {}

    // MARK: - Counting

    /// Whether incrementing a row automatically resets the stitch counter.
    @AppStorage("crochet.autoResetStitches") var autoResetStitches: Bool = true

    /// Default row goal applied to newly-added patterns (0 = no default).
    @AppStorage("crochet.defaultRowGoal") var defaultRowGoal: Int = 0

    /// Default stitch goal applied to newly-added patterns (0 = no default).
    @AppStorage("crochet.defaultStitchGoal") var defaultStitchGoal: Int = 0

    // MARK: - Pace & AI

    /// Rows per hour the user completes. Used by the AI time estimator.
    @AppStorage("crochet.rowsPerHour") var rowsPerHour: Int = 8

    // MARK: - Appearance

    /// Display size of the numeric counters in the counter bar.
    @AppStorage("crochet.counterSize") var counterSizeRaw: String = CounterSize.normal.rawValue

    var counterSize: CounterSize {
        get { CounterSize(rawValue: counterSizeRaw) ?? .normal }
        set { counterSizeRaw = newValue.rawValue }
    }

    /// Whether the AI inspector panel was open when the app last closed.
    @AppStorage("crochet.aiPanelOpen") var aiPanelOpen: Bool = false

    /// Whether the session timer is visible in the counter bar.
    @AppStorage("crochet.showTimer") var showTimer: Bool = true

    // MARK: - Pill color scheme

    @AppStorage("crochet.pillColorScheme") var pillColorSchemeRaw: String = PillColorScheme.classic.rawValue

    var pillColorScheme: PillColorScheme {
        get { PillColorScheme(rawValue: pillColorSchemeRaw) ?? .classic }
        set { pillColorSchemeRaw = newValue.rawValue }
    }

    // MARK: - Counter size enum

    enum CounterSize: String, CaseIterable {
        case compact, normal, large

        var label: String {
            switch self {
            case .compact: return "Compact"
            case .normal:  return "Normal"
            case .large:   return "Large"
            }
        }

        /// Font size for the main count numeral.
        var fontSize: CGFloat {
            switch self {
            case .compact: return 15
            case .normal:  return 22
            case .large:   return 28
            }
        }

        /// Height of the counter pill (expands with font).
        var pillHeight: CGFloat {
            switch self {
            case .compact: return 28
            case .normal:  return 36
            case .large:   return 44
            }
        }
    }

    // MARK: - Pill color scheme enum

    enum PillColorScheme: String, CaseIterable {
        case classic, ocean, forest, sunset, mono

        var label: String {
            switch self {
            case .classic: return "Classic"
            case .ocean:   return "Ocean"
            case .forest:  return "Forest"
            case .sunset:  return "Sunset"
            case .mono:    return "Mono"
            }
        }

        var rowColor: Color {
            switch self {
            case .classic: return Color(red: 0.71, green: 0.33, blue: 0.49)
            case .ocean:   return Color(red: 0.00, green: 0.48, blue: 0.80)
            case .forest:  return Color(red: 0.18, green: 0.49, blue: 0.29)
            case .sunset:  return Color(red: 0.88, green: 0.38, blue: 0.13)
            case .mono:    return Color(white: 0.45)
            }
        }

        var stitchColor: Color {
            switch self {
            case .classic: return Color(red: 0.49, green: 0.30, blue: 0.80)
            case .ocean:   return Color(red: 0.00, green: 0.55, blue: 0.60)
            case .forest:  return Color(red: 0.77, green: 0.49, blue: 0.17)
            case .sunset:  return Color(red: 0.75, green: 0.20, blue: 0.29)
            case .mono:    return Color(white: 0.65)
            }
        }
    }
}
