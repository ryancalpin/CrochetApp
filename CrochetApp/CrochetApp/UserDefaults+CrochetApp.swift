import Foundation

extension UserDefaults {
    private enum Keys {
        static let rowsPerHour = "crochet.rowsPerHour"
        static let aiPanelOpen = "crochet.aiPanelOpen"
    }

    /// Number of rows a user completes per hour. Used for time estimation. Default: 8.
    var rowsPerHour: Int {
        get {
            let stored = integer(forKey: Keys.rowsPerHour)
            return stored == 0 ? 8 : stored
        }
        set { set(newValue, forKey: Keys.rowsPerHour) }
    }

    /// Whether the AI inspector panel was open when the app last closed.
    var aiPanelOpen: Bool {
        get { bool(forKey: Keys.aiPanelOpen) }
        set { set(newValue, forKey: Keys.aiPanelOpen) }
    }
}
