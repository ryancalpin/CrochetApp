import SwiftUI
import AppKit

@main
struct LoopletApp: App {
    @StateObject private var library = PatternLibrary()
    @StateObject private var store = CounterStore()
    @StateObject private var sessionTimer = SessionTimer()
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView(library: library, store: store, sessionTimer: sessionTimer)
                .frame(minWidth: 700, minHeight: 500)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .onAppear {
                    store.library = library
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button("Toggle Focus Mode") {
                    NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
            }
            CommandGroup(after: .help) {
                Button("Welcome to Looplet") {
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                }
                Button("Unlock Looplet Pro…") {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                }
                Button("Send Feedback & Suggestions…") {
                    if let url = URL(string: AppSettings.feedbackURLString) {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("Reset All Counters…") {
                    NotificationCenter.default.post(name: .resetAllCounters, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let resetAllCounters = Notification.Name("Looplet.resetAllCounters")
    static let toggleFocusMode = Notification.Name("Looplet.toggleFocusMode")
    static let showPaywall = Notification.Name("Looplet.showPaywall")
    static let showOnboarding = Notification.Name("Looplet.showOnboarding")
}
