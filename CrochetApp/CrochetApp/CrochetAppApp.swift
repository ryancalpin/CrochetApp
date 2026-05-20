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
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .help) {
                Divider()
                Button("Reset All Counters…") {
                    NotificationCenter.default.post(name: .resetAllCounters, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let resetAllCounters = Notification.Name("CrochetApp.resetAllCounters")
}
