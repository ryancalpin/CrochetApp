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
        migrateCounterColorsIfNeeded()
    }

    /// Pre-1.0, counter colors were free pickers persisted to a fixed "classic"
    /// palette independent of the theme. Clear any legacy persisted values once so
    /// the pills coordinate with the selected theme out of the box. Users can still
    /// re-customize afterward (which writes explicit hexes again).
    @AppStorage("crochet.counterColorThemeMigrated.v1") private var counterColorThemeMigrated = false
    private func migrateCounterColorsIfNeeded() {
        guard !counterColorThemeMigrated else { return }
        rowColorHex = ""
        stitchColorHex = ""
        repeatColorHex = ""
        counterColorThemeMigrated = true
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

    /// In-app override for the system color scheme (System / Light / Dark).
    @AppStorage("crochet.appearanceMode") var appearanceModeRaw: String = AppearanceMode.system.rawValue

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

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

    // MARK: - Onboarding

    /// Set once the first-launch welcome flow has been completed or skipped.
    @AppStorage("crochet.hasSeenOnboarding") var hasSeenOnboarding: Bool = false

    // MARK: - Support

    /// Web form opened by the "Send Feedback" / "Suggestions" action.
    /// TODO: replace with the real Looplet feedback form URL.
    static let feedbackURLString = "https://looplet.app/feedback"

    // MARK: - App theme (coordinated accent + background palette)

    @AppStorage("crochet.appTheme") private var appThemeRaw = AppTheme.plum.rawValue
    var appTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .plum }
        set { appThemeRaw = newValue.rawValue }
    }

    // MARK: - Counter colors
    //
    // An empty stored hex means "follow the current theme's coordinated counter
    // color" (see `AppTheme.Palette.counter*`). A non-empty hex is an explicit
    // user override. This lets the pills coordinate with each theme out of the box
    // while still allowing full customization.

    @AppStorage("crochet.rowColorHex")    var rowColorHex:    String = ""
    @AppStorage("crochet.stitchColorHex") var stitchColorHex: String = ""
    @AppStorage("crochet.repeatColorHex") var repeatColorHex: String = ""

    private var themePalette: AppTheme.Palette { appTheme.palette }

    var rowColor: Color {
        get { color(forHex: rowColorHex, themeDefault: themePalette.counterRow) }
        set { rowColorHex = newValue.hexString }
    }

    var stitchColor: Color {
        get { color(forHex: stitchColorHex, themeDefault: themePalette.counterStitch) }
        set { stitchColorHex = newValue.hexString }
    }

    var repeatColor: Color {
        get { color(forHex: repeatColorHex, themeDefault: themePalette.counterRepeat) }
        set { repeatColorHex = newValue.hexString }
    }

    private func color(forHex hex: String, themeDefault: String) -> Color {
        if hex.isEmpty { return ThemeColor.color(themeDefault) }
        return Color(hex: hex) ?? ThemeColor.color(themeDefault)
    }

    /// True when any counter color has been overridden away from the theme defaults.
    var counterColorsCustomized: Bool {
        !rowColorHex.isEmpty || !stitchColorHex.isEmpty || !repeatColorHex.isEmpty
    }

    /// Revert all counter colors so they follow the current theme again.
    func resetCounterColorsToTheme() {
        rowColorHex = ""
        stitchColorHex = ""
        repeatColorHex = ""
    }

    // MARK: - Appearance mode enum

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }

        /// Color scheme to force, or nil to follow the system setting.
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
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
