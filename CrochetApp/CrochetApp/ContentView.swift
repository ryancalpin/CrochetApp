import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @ObservedObject var sessionTimer: SessionTimer

    @State private var showAIPanel: Bool = UserDefaults.standard.aiPanelOpen

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ───────────────────────────────────────────────
            PatternLibraryView(library: library, store: store)
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
                .frame(maxHeight: .infinity)

            Divider()

            // ── Detail ────────────────────────────────────────────────
            VStack(spacing: 0) {
                CounterBarView(
                    store: store,
                    timer: sessionTimer,
                    entry: activeEntryBinding,
                    showAIPanel: $showAIPanel
                )

                HStack(spacing: 0) {
                    PatternContentView(fileURL: activeFileURL, library: library)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showAIPanel, let entry = library.activeEntry, let text = loadedPatternText {
                        if #available(macOS 26.0, *) {
                            Divider()
                            AIPanelView(entry: entry, patternText: text, showAIPanel: $showAIPanel)
                                .transition(.move(edge: .trailing))
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAIPanel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KeyboardShortcutHandler(store: store))
        .onChange(of: showAIPanel) { newValue in
            UserDefaults.standard.aiPanelOpen = newValue
        }
        .onChange(of: library.activeEntry?.displayName) { name in
            NSApp.mainWindow?.title = name ?? "Crochet Helper"
        }
        .onAppear {
            NSApp.mainWindow?.title = library.activeEntry?.displayName ?? "Crochet Helper"
        }
    }

    private var activeEntryBinding: Binding<PatternEntry?> {
        Binding(
            get: { library.activeEntry },
            set: { newEntry in
                guard let e = newEntry,
                      let i = library.entries.firstIndex(where: { $0.id == e.id }) else { return }
                library.entries[i] = e
                library.save()
            }
        )
    }

    private var activeFileURL: URL? {
        guard let entry = library.activeEntry else { return nil }
        let url = entry.resolveURL()
        url?.startAccessingSecurityScopedResource()
        return url
    }

    private var loadedPatternText: String? {
        guard let url = activeFileURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Keyboard Shortcut Handler

struct KeyboardShortcutHandler: NSViewRepresentable {
    @ObservedObject var store: CounterStore

    func makeNSView(context: Context) -> KeyHandlerView {
        let view = KeyHandlerView()
        view.store = store
        return view
    }

    func updateNSView(_ nsView: KeyHandlerView, context: Context) {
        nsView.store = store
    }
}

class KeyHandlerView: NSView {
    var store: CounterStore?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let store = store else { super.keyDown(with: event); return }
        let mods = event.modifierFlags.intersection([.command, .option, .control])
        guard mods.isEmpty else { super.keyDown(with: event); return }

        switch event.keyCode {
        case 126: store.incrementRow()
        case 125: store.decrementRow()
        case 124: store.incrementStitch()
        case 123: store.decrementStitch()
        case 49: store.incrementStitch()   // Space
        case 36: store.endRow()            // Return — always resets stitch
        default:
            switch event.charactersIgnoringModifiers {
            case "R": store.incrementRow()
            case "r": store.decrementRow()
            case "S": store.incrementStitch()
            case "s": store.decrementStitch()
            default: super.keyDown(with: event)
            }
        }
    }
}

#Preview {
    let library = PatternLibrary()
    let store = CounterStore()
    store.library = library
    return ContentView(library: library, store: store, sessionTimer: SessionTimer())
        .frame(width: 960, height: 650)
}
