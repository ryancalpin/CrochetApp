import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @ObservedObject var sessionTimer: SessionTimer
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var proStore = ProStore.shared

    @Environment(\.colorScheme) private var colorScheme

    @State private var showAIPanel: Bool = UserDefaults.standard.aiPanelOpen
    @State private var aiPanelWidth: CGFloat = 280
    @State private var abbreviationDict: [String: String] = [:]
    @State private var focusMode = false
    @State private var showOnboarding = false
    @State private var showPaywall = false
    @State private var paywallReason: String? = nil

    // Cached pattern text for the active entry. Loaded once when the entry changes
    // (with a properly balanced security scope) instead of re-reading the file on
    // every view update.
    @State private var cachedPatternText: String? = nil
    @State private var cachedPatternTextID: UUID? = nil

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
                    if let entry = library.activeEntry {
                        PatternSummaryBar(entry: entry)
                    }
                }

                HStack(spacing: 0) {
                    PatternContentView(
                        fileURL: activeFileURL,
                        library: library,
                        abbreviationDict: abbreviationDict
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Mount AIPanelView ONLY when open so its .task never runs (no AI burst)
                    // while the panel is closed. The shared service (owned outside the panel)
                    // keeps the per-pattern cache alive across close/reopen.
                    // Free tier sees a locked panel inviting them to unlock Pro.
                    if showAIPanel {
                        if proStore.isPro {
                            if #available(macOS 26.0, *), let entry = library.activeEntry, let text = activePatternText {
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
                        } else {
                            resizableDivider
                            AILockedPanel(
                                onUnlock: {
                                    paywallReason = "AI insights read your pattern for a summary, abbreviations, materials, and answers to your questions."
                                    showPaywall = true
                                },
                                onClose: { showAIPanel = false }
                            )
                            .frame(width: aiPanelWidth)
                            .transition(.move(edge: .trailing))
                        }
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
                        Divider().frame(height: 28)
                        Button {
                            NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title3)
                                .foregroundColor(.textSecondary)
                                .padding(6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Exit focus mode (⌃⌘F)")
                        .accessibilityLabel("Exit focus mode")
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
        .onChange(of: library.activeEntryID) { _ in
            abbreviationDict = [:]
            reloadPatternText()
            // Kick off (or backfill) AI insight generation as soon as a pattern is
            // imported or opened. Idempotent + persisted, so this never re-bursts.
            // Pro-only — free users see the locked panel, so don't burn compute.
            if #available(macOS 26.0, *), proStore.isPro, let id = library.activeEntryID {
                AIInsights.ensure(for: id, in: library)
            }
        }
        .onAppear {
            NSApp.mainWindow?.title = "Looplet"
            reloadPatternText()
            showOnboarding = !settings.hasSeenOnboarding
            if #available(macOS 26.0, *), proStore.isPro, let id = library.activeEntryID {
                AIInsights.ensure(for: id, in: library)
            }
        }
        .sheet(isPresented: $showOnboarding) { OnboardingView() }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: paywallReason) }
        .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
            paywallReason = nil
            showPaywall = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            showOnboarding = true
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
        // The consumers (MarkdownView, PDFKitView) each open their own security scope
        // when they read the file, so we must NOT start one here (doing so leaked an
        // unbalanced access for the lifetime of the view).
        library.activeEntry?.resolveURL()
    }

    /// Cached text for the currently-active entry, or nil if not yet loaded for it.
    private var activePatternText: String? {
        guard let id = library.activeEntryID, id == cachedPatternTextID else { return nil }
        return cachedPatternText
    }

    /// Read the active pattern's text once, with a balanced security scope, and cache it.
    private func reloadPatternText() {
        guard let entry = library.activeEntry, let url = entry.resolveURL() else {
            cachedPatternText = nil; cachedPatternTextID = nil; return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "pdf" {
            // PDFs aren't UTF-8 text; pull the extracted text layer so AI features work.
            cachedPatternText = PDFDocument(url: url)?.string
        } else {
            cachedPatternText = try? String(contentsOf: url, encoding: .utf8)
        }
        cachedPatternTextID = entry.id
    }
}

// MARK: - Pattern Summary Bar

/// Slim metadata strip above the open pattern: name + AI-derived skill level and time.
struct PatternSummaryBar: View {
    let entry: PatternEntry

    var body: some View {
        let name: String = {
            if let n = entry.aiSummary?.patternName, !n.isEmpty, n != "Unknown" { return n }
            return entry.displayName
        }()
        let level = cleaned(entry.aiSummary?.skillLevel ?? entry.aiDifficulty)
        let time = cleaned(entry.aiSummary?.estimatedTime ?? entry.aiTimeEstimate)

        return HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.callout).foregroundColor(.textSecondary)
            Text(name)
                .font(Typo.rowTitle).foregroundColor(.textPrimary)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            if let level { summaryChip(icon: "chart.bar.fill", text: level) }
            if let time { summaryChip(icon: "clock", text: time) }
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceRaised)
        .overlay(alignment: .bottom) { Divider().background(Color.dividerToken) }
    }

    private func cleaned(_ value: String?) -> String? {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty, v != "Unknown" else { return nil }
        return v
    }

    private func summaryChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(Typo.metadata).lineLimit(1)
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(Color.surfaceSidebar))
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
