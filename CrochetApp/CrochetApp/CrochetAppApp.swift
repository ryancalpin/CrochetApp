import SwiftUI

@main
struct CrochetAppApp: App {
    @StateObject private var library = PatternLibrary()
    @StateObject private var store = CounterStore()
    @StateObject private var sessionTimer = SessionTimer()

    var body: some Scene {
        WindowGroup {
            ContentView(library: library, store: store, sessionTimer: sessionTimer)
                .frame(minWidth: 700, minHeight: 500)
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
    static let resetAllCounters = Notification.Name("CrochetApp.resetAllCounters")
    static let toggleFocusMode = Notification.Name("CrochetApp.toggleFocusMode")
}
