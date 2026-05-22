import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @ObservedObject var sessionTimer: SessionTimer
    @ObservedObject private var settings = AppSettings.shared

    @Environment(\.colorScheme) private var colorScheme

    @State private var showAIPanel: Bool = UserDefaults.standard.aiPanelOpen
    @State private var aiPanelWidth: CGFloat = 280
    @State private var abbreviationDict: [String: String] = [:]
    @State private var patternScrollToRow: Int = 0
    @State private var focusMode = false

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ───────────────────────────────────────────────
            if !focusMode {
                PatternLibraryView(library: library, store: store)
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            // ── Detail ────────────────────────────────────────────────
            VStack(spacing: 0) {
                if !focusMode {
                    CounterBarView(
                        store: store,
                        timer: sessionTimer,
                        entry: activeEntryBinding,
                        showAIPanel: $showAIPanel
                    )
                }

                HStack(spacing: 0) {
                    PatternContentView(
                        fileURL: activeFileURL,
                        library: library,
                        scrollToRow: patternScrollToRow,
                        abbreviationDict: abbreviationDict
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Mount AIPanelView ONLY when open so its .task never runs (no AI burst)
                    // while the panel is closed. The shared service (owned outside the panel)
                    // keeps the per-pattern cache alive across close/reopen.
                    if #available(macOS 26.0, *), showAIPanel, let entry = library.activeEntry, let text = loadedPatternText {
                        resizableDivider
                        AIPanelView(
                            service: AIInsights.service,
                            entry: entry,
                            patternText: text,
                            library: library,
                            showAIPanel: $showAIPanel,
                            abbreviationDict: $abbreviationDict
                        )
                        .frame(width: aiPanelWidth)
                        .transition(.move(edge: .trailing))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAIPanel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if focusMode {
                    GlassHUD {
                        CounterPill(
                            label: "ROW",
                            value: store.rowCount,
                            goal: library.activeEntry?.rowGoal,
                            color: settings.rowColor.legible(in: colorScheme),
                            size: settings.counterSize,
                            onDecrement: { store.decrementRow() },
                            onIncrement: { store.incrementRow() }
                        )
                        CounterPill(
                            label: "STITCH",
                            value: store.stitchCount,
                            goal: library.activeEntry?.stitchGoal,
                            color: settings.stitchColor.legible(in: colorScheme),
                            size: settings.counterSize,
                            onDecrement: { store.decrementStitch() },
                            onIncrement: { store.incrementStitch() }
                        )
                        if library.activeEntry?.showRepeatCounter == true {
                            CounterPill(
                                label: "REPEAT",
                                value: store.repeatCount,
                                goal: nil,
                                color: settings.repeatColor.legible(in: colorScheme),
                                size: settings.counterSize,
                                onDecrement: { store.decrementRepeat() },
                                onIncrement: { store.incrementRepeat() }
                            )
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .background(KeyboardShortcutHandler(store: store))
        .onReceive(NotificationCenter.default.publisher(for: .toggleFocusMode)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { focusMode.toggle() }
        }
        .onChange(of: showAIPanel) { UserDefaults.standard.aiPanelOpen = $0 }
        .onChange(of: library.activeEntry?.displayName) { name in
            NSApp.mainWindow?.title = name ?? "Crochet Helper"
        }
        .onChange(of: library.activeEntryID) { _ in
            abbreviationDict = [:]
            patternScrollToRow = 0
            // Kick off (or backfill) AI insight generation as soon as a pattern is
            // imported or opened. Idempotent + persisted, so this never re-bursts.
            if #available(macOS 26.0, *), let id = library.activeEntryID {
                AIInsights.ensure(for: id, in: library)
            }
        }
        .onChange(of: store.rowCount) { row in
            patternScrollToRow = row
        }
        .onAppear {
            NSApp.mainWindow?.title = library.activeEntry?.displayName ?? "Crochet Helper"
            if #available(macOS 26.0, *), let id = library.activeEntryID {
                AIInsights.ensure(for: id, in: library)
            }
        }
    }

    // MARK: - Resizable AI panel divider

    private var resizableDivider: some View {
        Rectangle()
            .fill(Color.dividerToken)
            .frame(width: 1)
            .overlay(
                Color.clear
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                aiPanelWidth = max(220, min(520, aiPanelWidth - value.translation.width))
                            }
                    )
                    .onHover { hovering in
                        if hovering { NSCursor.resizeLeftRight.push() }
                        else { NSCursor.pop() }
                    }
            )
    }

    // MARK: - Bindings / helpers

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
