import SwiftUI

/// Singleton that owns all user-configurable preferences, backed by UserDefaults via @AppStorage.
/// Observe it with `@ObservedObject private var settings = AppSettings.shared` in any View.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private var defaultsObserver: NSObjectProtocol?
    private init() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.objectWillChange.send() }
    }
    deinit { if let o = defaultsObserver { NotificationCenter.default.removeObserver(o) } }

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

    // MARK: - Audio

    /// Play a subtle tick sound when incrementing a row.
    @AppStorage("crochet.audioCueEnabled") var audioCueEnabled: Bool = false

    // MARK: - Counter colors (free color pickers)

    @AppStorage("crochet.rowColorHex")    var rowColorHex:    String = "#B5547D"
    @AppStorage("crochet.stitchColorHex") var stitchColorHex: String = "#7D4DCC"
    @AppStorage("crochet.repeatColorHex") var repeatColorHex: String = "#00897B"

    var rowColor: Color {
        get { Color(hex: rowColorHex)    ?? Color(red: 0.71, green: 0.33, blue: 0.49) }
        set { rowColorHex    = newValue.hexString }
    }

    var stitchColor: Color {
        get { Color(hex: stitchColorHex) ?? Color(red: 0.49, green: 0.30, blue: 0.80) }
        set { stitchColorHex = newValue.hexString }
    }

    var repeatColor: Color {
        get { Color(hex: repeatColorHex) ?? .teal }
        set { repeatColorHex = newValue.hexString }
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

    // MARK: - Built-in color presets (used by SettingsView)

    struct ColorPreset: Identifiable {
        let id = UUID()
        let name: String
        let rowHex: String
        let stitchHex: String
        let repeatHex: String
    }

    static let colorPresets: [ColorPreset] = [
        .init(name: "Classic", rowHex: "#B5547D", stitchHex: "#7D4DCC", repeatHex: "#00897B"),
        .init(name: "Ocean",   rowHex: "#007ACC", stitchHex: "#00899A", repeatHex: "#2E7D32"),
        .init(name: "Forest",  rowHex: "#2E7D4A", stitchHex: "#C47D2C", repeatHex: "#1565C0"),
        .init(name: "Sunset",  rowHex: "#E06021", stitchHex: "#BF3349", repeatHex: "#6A1B9A"),
        .init(name: "Mono",    rowHex: "#737373", stitchHex: "#A6A6A6", repeatHex: "#555555"),
    ]
}
