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
}
