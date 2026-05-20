# Pattern Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent pattern library sidebar and per-pattern counter state so users never need to re-browse for a file and always resume where they left off.

**Architecture:** `PatternLibrary` (ObservableObject) owns the list of `PatternEntry` values, persists them as JSON in Application Support, and is the source of truth for which pattern is active. `CounterStore` is simplified to a pure view-model: it loads from and writes back to the active `PatternEntry` via `PatternLibrary`. `ContentView` wires the two together in a 2-column `NavigationSplitView`.

**Tech Stack:** SwiftUI, macOS 13+, Foundation (Codable/JSON, security-scoped bookmarks), AppKit (NSApplicationDelegate terminate notification)

**Build command (run after every task to verify):**
```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

> **Note — adding files to Xcode:** After creating each new `.swift` file, add it to the `CrochetApp` target by editing `CrochetApp.xcodeproj/project.pbxproj`. The pattern to follow is the existing entries (search for `CrochetAppApp.swift` to see the format). Each new file needs a `PBXFileReference` entry, a `PBXBuildFile` entry, appears in the `PBXGroup` children list, and in the `PBXSourcesBuildPhase` files list. Alternatively, open the project in Xcode and drag the file into the target.

---

## File Map

| File | Status | Responsibility |
|------|--------|---------------|
| `CrochetApp/PatternEntry.swift` | **Create** | Codable model for a single library entry |
| `CrochetApp/PatternLibrary.swift` | **Create** | ObservableObject — owns entries, persistence, active selection |
| `CrochetApp/PatternLibraryView.swift` | **Create** | SwiftUI sidebar list (pinned + recent sections) |
| `CrochetApp/CounterBarView.swift` | **Create** | Compact sticky counter bar (replaces CounterView in layout) |
| `CrochetApp/CounterStore.swift` | **Modify** | Remove UserDefaults counter keys; add `load(from:)` and `syncToLibrary()` |
| `CrochetApp/ContentView.swift` | **Modify** | 2-column split; wire library + counter bar; remove old 2-column toolbar |
| `CrochetApp/CrochetAppApp.swift` | **Modify** | Inject `PatternLibrary` as `@StateObject`; pass to CounterStore |
| `CrochetApp/CounterView.swift` | **Delete** | Replaced by `CounterBarView` |

---

## Task 1: PatternEntry model

**Files:**
- Create: `CrochetApp/CrochetApp/PatternEntry.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

struct PatternEntry: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var bookmark: Data
    var lastOpened: Date
    var isPinned: Bool
    var rowCount: Int
    var stitchCount: Int
    var autoResetStitch: Bool

    init(url: URL) throws {
        self.id = UUID()
        self.displayName = url.deletingPathExtension().lastPathComponent
        self.bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.lastOpened = Date()
        self.isPinned = false
        self.rowCount = 0
        self.stitchCount = 0
        self.autoResetStitch = true
    }

    func resolveURL() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return url
    }
}
```

- [ ] **Step 2: Add file to Xcode project target** (see note at top of plan)

- [ ] **Step 3: Build to verify no errors**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "CrochetApp/CrochetApp/PatternEntry.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj"
git commit -m "feat: add PatternEntry model with security-scoped bookmark"
```

---

## Task 2: PatternLibrary

**Files:**
- Create: `CrochetApp/CrochetApp/PatternLibrary.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation
import Combine

class PatternLibrary: ObservableObject {
    @Published var entries: [PatternEntry] = []
    @Published var activeEntryID: UUID? = nil

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("CrochetApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("patterns.json")
    }()

    // MARK: - Computed

    var pinned: [PatternEntry] {
        entries.filter(\.isPinned).sorted { $0.lastOpened > $1.lastOpened }
    }

    var recent: [PatternEntry] {
        entries.filter { !$0.isPinned }
            .sorted { $0.lastOpened > $1.lastOpened }
    }

    var activeEntry: PatternEntry? {
        entries.first { $0.id == activeEntryID }
    }

    // MARK: - Init

    init() {
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    // MARK: - Public API

    /// Add a pattern from a file-picker URL. Returns the new entry's id.
    @discardableResult
    func add(url: URL) -> UUID? {
        // Don't add duplicates
        if let existing = entries.first(where: { $0.resolveURL() == url }) {
            return existing.id
        }
        guard let entry = try? PatternEntry(url: url) else { return nil }
        entries.append(entry)
        save()
        return entry.id
    }

    /// Switch active pattern. Caller must flush counter state first via updateActiveCounters().
    func select(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].lastOpened = Date()
        activeEntryID = entryID
        save()
    }

    /// Call this whenever counters change so in-memory state stays current.
    func updateActiveCounters(row: Int, stitch: Int, autoReset: Bool) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].rowCount = row
        entries[i].stitchCount = stitch
        entries[i].autoResetStitch = autoReset
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        if activeEntryID == entryID { activeEntryID = nil }
        save()
    }

    func togglePin(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].isPinned.toggle()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PatternEntry].self, from: data) else { return }
        entries = decoded
    }

    @objc private func appWillTerminate() {
        save()
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "CrochetApp/CrochetApp/PatternLibrary.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj"
git commit -m "feat: add PatternLibrary with JSON persistence and security-scoped bookmarks"
```

---

## Task 3: Refactor CounterStore

**Files:**
- Modify: `CrochetApp/CrochetApp/CounterStore.swift`

Replace the entire file with this. Key changes: remove UserDefaults counter keys; add `load(from:)` to restore state from an entry; call `library?.updateActiveCounters(...)` after every mutation so PatternLibrary stays in sync.

- [ ] **Step 1: Replace CounterStore.swift**

```swift
import Foundation
import Combine

class CounterStore: ObservableObject {
    @Published var rowCount: Int = 0
    @Published var stitchCount: Int = 0
    @Published var autoResetStitch: Bool = true

    weak var library: PatternLibrary?

    // MARK: - Load from pattern entry

    func load(from entry: PatternEntry) {
        rowCount = entry.rowCount
        stitchCount = entry.stitchCount
        autoResetStitch = entry.autoResetStitch
    }

    func reset() {
        rowCount = 0
        stitchCount = 0
        sync()
    }

    // MARK: - Row actions

    func incrementRow() {
        rowCount += 1
        if autoResetStitch { stitchCount = 0 }
        sync()
    }

    func decrementRow() {
        guard rowCount > 0 else { return }
        rowCount -= 1
        if autoResetStitch { stitchCount = 0 }
        sync()
    }

    // MARK: - Stitch actions

    func incrementStitch() {
        stitchCount += 1
        sync()
    }

    func decrementStitch() {
        guard stitchCount > 0 else { return }
        stitchCount -= 1
        sync()
    }

    // MARK: - Private

    private func sync() {
        library?.updateActiveCounters(row: rowCount, stitch: stitchCount, autoReset: autoResetStitch)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED` (CounterView still references old resetAll — will be removed in Task 6)

- [ ] **Step 3: Commit**

```bash
git add "CrochetApp/CrochetApp/CounterStore.swift"
git commit -m "refactor: CounterStore delegates persistence to PatternLibrary"
```

---

## Task 4: PatternLibraryView

**Files:**
- Create: `CrochetApp/CrochetApp/PatternLibraryView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct PatternLibraryView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @State private var showFilePicker = false
    @State private var entryToRemove: PatternEntry? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "yarnball")
                    .foregroundColor(.pink)
                Text("Patterns")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.pink)
                .help("Add a pattern file")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if library.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !library.pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(library.pinned) { entry in
                                entryRow(entry)
                            }
                        }
                        sectionHeader("Recent")
                        if library.recent.isEmpty {
                            Text("No recent patterns")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(library.recent) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType.text,
                UTType(filenameExtension: "md") ?? .text,
                UTType(filenameExtension: "markdown") ?? .text
            ],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if let newID = library.add(url: url) {
                    selectEntry(id: newID)
                }
            }
        }
        .confirmationDialog(
            "Remove \"\(entryToRemove?.displayName ?? "")\" from library?",
            isPresented: Binding(
                get: { entryToRemove != nil },
                set: { if !$0 { entryToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let e = entryToRemove { library.remove(entryID: e.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The file will not be deleted from disk.")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.pink.opacity(0.4))
            Text("No Patterns Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Click + to add a Markdown pattern file.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func entryRow(_ entry: PatternEntry) -> some View {
        let isActive = library.activeEntryID == entry.id
        return HStack(spacing: 0) {
            // Active indicator
            Rectangle()
                .fill(isActive ? Color.pink : Color.clear)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .primary)
                    .lineLimit(1)
                HStack {
                    Text(relativeDate(entry.lastOpened))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("R\(entry.rowCount) · S\(entry.stitchCount)")
                        .font(.system(size: 11))
                        .foregroundColor(isActive ? .pink : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(isActive ? Color.pink.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(isActive ? Color.pink.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectEntry(id: entry.id) }
        .contextMenu {
            Button(entry.isPinned ? "Unpin" : "Pin") {
                library.togglePin(entryID: entry.id)
            }
            Divider()
            Button("Remove from Library", role: .destructive) {
                entryToRemove = entry
            }
        }
        Divider().padding(.leading, 13)
    }

    // MARK: - Helpers

    private func selectEntry(id: UUID) {
        library.select(entryID: id)
        if let entry = library.entries.first(where: { $0.id == id }) {
            store.load(from: entry)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "CrochetApp/CrochetApp/PatternLibraryView.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj"
git commit -m "feat: add PatternLibraryView sidebar with pinned/recent sections"
```

---

## Task 5: CounterBarView

**Files:**
- Create: `CrochetApp/CrochetApp/CounterBarView.swift`

This is the compact sticky counter bar that sits pinned to the top of the content pane.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct CounterBarView: View {
    @ObservedObject var store: CounterStore
    @State private var showResetConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            // Row counter pill
            counterPill(
                label: "Row",
                count: store.rowCount,
                color: .pink,
                accentColor: Color(red: 0.71, green: 0.33, blue: 0.49),
                onDecrement: { store.decrementRow() },
                onIncrement: { store.incrementRow() }
            )

            // Stitch counter pill
            counterPill(
                label: "Stitch",
                count: store.stitchCount,
                color: Color.purple,
                accentColor: Color(red: 0.49, green: 0.30, blue: 0.80),
                onDecrement: { store.decrementStitch() },
                onIncrement: { store.incrementStitch() }
            )

            Divider()
                .frame(height: 32)

            // Auto-reset toggle
            HStack(spacing: 6) {
                Toggle("", isOn: $store.autoResetStitch)
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .onChange(of: store.autoResetStitch) { _ in
                        store.library?.updateActiveCounters(
                            row: store.rowCount,
                            stitch: store.stitchCount,
                            autoReset: store.autoResetStitch
                        )
                    }
                Text("Auto-reset")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Keyboard hint
            Text("↑↓ row · ←→ stitch")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))

            Divider()
                .frame(height: 32)

            // Reset button
            Button("Reset") {
                showResetConfirmation = true
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
            .confirmationDialog(
                "Reset counters?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { store.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Row and Stitch counts will be set to 0.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func counterPill(
        label: String,
        count: Int,
        color: Color,
        accentColor: Color,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .foregroundColor(count == 0 ? Color.secondary : accentColor)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)

            Divider().frame(height: 36)

            VStack(spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(accentColor)
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: count)
            }
            .frame(minWidth: 52)
            .padding(.horizontal, 6)

            Divider().frame(height: 36)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.15))
                    .foregroundColor(accentColor)
            }
            .buttonStyle(.plain)
        }
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.25), lineWidth: 1.5)
        )
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "CrochetApp/CrochetApp/CounterBarView.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj"
git commit -m "feat: add compact CounterBarView with pill-shaped − count + controls"
```

---

## Task 6: Wire everything — ContentView, CrochetAppApp, remove CounterView

**Files:**
- Modify: `CrochetApp/CrochetApp/ContentView.swift`
- Modify: `CrochetApp/CrochetApp/CrochetAppApp.swift`
- Delete: `CrochetApp/CrochetApp/CounterView.swift`

- [ ] **Step 1: Replace ContentView.swift**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore

    var body: some View {
        NavigationSplitView {
            PatternLibraryView(library: library, store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Sticky counter bar — always visible
                CounterBarView(store: store)

                // Scrollable markdown viewer
                MarkdownView(fileURL: activeFileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(library.activeEntry?.displayName ?? "Crochet Helper")
        .background(KeyboardShortcutHandler(store: store))
    }

    private var activeFileURL: URL? {
        guard let entry = library.activeEntry else { return nil }
        let url = entry.resolveURL()
        url?.startAccessingSecurityScopedResource()
        return url
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
    ContentView(library: PatternLibrary(), store: CounterStore())
        .frame(width: 960, height: 650)
}
```

- [ ] **Step 2: Replace CrochetAppApp.swift**

```swift
import SwiftUI

@main
struct CrochetAppApp: App {
    @StateObject private var library = PatternLibrary()
    @StateObject private var store = CounterStore()

    var body: some Scene {
        WindowGroup {
            ContentView(library: library, store: store)
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
```

- [ ] **Step 3: Also update MarkdownView — change `@Binding var fileURL: URL?` to `let fileURL: URL?`**

In `MarkdownView.swift`, change the struct declaration from:
```swift
struct MarkdownView: View {
    @Binding var fileURL: URL?
```
to:
```swift
struct MarkdownView: View {
    let fileURL: URL?
```

And change `.onChange(of: fileURL) { newURL in` to `.onChange(of: fileURL) { newURL in` — this stays the same. Also remove the `$` binding call sites (there are none after ContentView is replaced).

- [ ] **Step 4: Delete CounterView.swift and remove it from project.pbxproj**

```bash
rm "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp/CounterView.swift"
```

Then remove all references to `CounterView.swift` from `project.pbxproj` (the `PBXFileReference`, `PBXBuildFile`, group children entry, and sources build phase entry).

- [ ] **Step 5: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire pattern library into 2-column layout with sticky counter bar"
```

---

## Task 7: Smoke test in simulator

- [ ] **Step 1: Launch the app**

Use XcodeBuildMCP `build_run_sim` or open in Xcode and run on Mac.

- [ ] **Step 2: Verify pattern library**
  - Sidebar shows "No Patterns Yet" empty state on first launch
  - Clicking "+" opens file picker; selecting a `.md` file adds it to Recent and opens it
  - Counter bar appears at top of content pane
  - Pattern name shows in window title

- [ ] **Step 3: Verify per-pattern counter persistence**
  - Increment Row to 5, Stitch to 3
  - Add a second pattern file
  - Switch to it — counters reset to 0 (new pattern)
  - Switch back to first pattern — Row 5, Stitch 3 are restored

- [ ] **Step 4: Verify pin / remove**
  - Right-click a pattern → Pin → it moves to Pinned section
  - Right-click → Remove from Library → confirmation dialog → removed

- [ ] **Step 5: Verify keyboard shortcuts still work**
  - Arrow keys and R/r/S/s increment/decrement counters correctly

- [ ] **Step 6: Final commit if any tweaks were made**

```bash
git add -A
git commit -m "fix: post-smoke-test corrections"
```
