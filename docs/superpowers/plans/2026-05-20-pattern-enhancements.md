# Pattern Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add row/stitch goals with a progress bar, inline pattern annotations via JS-injected WKWebView, a session timer, and two new keyboard shortcuts (Space / Return) on top of the already-implemented pattern-management layer.

**Architecture:** `PatternEntry` (from the pattern-management plan) gains three new fields. A new `SessionTimer` `ObservableObject` owned by `CrochetAppApp` drives a timer display in `CounterBarView`. Inline annotations are bridged from JavaScript running inside the existing `WKWebView` through a `WKScriptMessageHandler` (`AnnotationBridge`) that writes back to `PatternLibrary`. `CounterStore` gains stitch-goal auto-advance logic. The existing `KeyHandlerView` in `ContentView.swift` gains Space and Return key handlers.

**Tech Stack:** SwiftUI, AppKit (`NSView`, `WKWebView`, `WKScriptMessageHandler`), Combine (`Timer.publish`), macOS 13+

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `CrochetApp/CrochetApp/PatternEntry.swift` | **Modify** (exists after pattern-management plan) | Add `rowGoal`, `stitchGoal`, `annotations` fields |
| `CrochetApp/CrochetApp/SessionTimer.swift` | **Create** | Elapsed-time `ObservableObject`, pause/resume, reset |
| `CrochetApp/CrochetApp/CounterBarView.swift` | **Create** | Inline counter bar with progress bar, timer display, goal popovers |
| `CrochetApp/CrochetApp/CounterStore.swift` | **Modify** | Add `library` weak ref + stitch-goal auto-advance in `incrementStitch()` |
| `CrochetApp/CrochetApp/ContentView.swift` | **Modify** | Add Space (keyCode 49) and Return (keyCode 36) to `KeyHandlerView.keyDown` |
| `CrochetApp/CrochetApp/MarkdownView.swift` | **Modify** | Wire `AnnotationBridge` into `WKWebView` config; inject JS bootstrap after load |
| `CrochetApp/CrochetApp/AnnotationBridge.swift` | **Create** | `WKScriptMessageHandler` that relays JS messages to `PatternLibrary` |
| `CrochetApp/CrochetApp/CrochetAppApp.swift` | **Modify** | Own `SessionTimer`; pass it to `ContentView` |

---

## Prerequisites

This plan runs **after** the pattern-management plan. Before starting, confirm the following symbols exist and compile:
- `PatternEntry` (struct/class with `id`, `displayName`, `bookmark`, `lastOpened`, `isPinned`, `rowCount`, `stitchCount`, `autoResetStitch`)
- `PatternLibrary` (ObservableObject with `activeEntry: PatternEntry?`)
- `PatternLibraryView`
- `CounterBarView` — **does NOT exist yet**; this plan creates it

Build command used throughout:
```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

---

## Task 1: Extend PatternEntry

**Files:**
- Modify: `CrochetApp/CrochetApp/PatternEntry.swift`

This task adds three new stored properties to the `PatternEntry` model that the rest of the plan depends on. Do this first because every subsequent task references `rowGoal`, `stitchGoal`, and `annotations`.

- [ ] **Step 1: Open PatternEntry.swift and add the three new fields**

Locate the property block in `PatternEntry` (after the existing fields like `rowCount`, `stitchCount`, `autoResetStitch`) and add:

```swift
// MARK: - Goals
var rowGoal: Int?        // nil = no goal, no progress bar
var stitchGoal: Int?     // nil = no auto-advance

// MARK: - Annotations
// Key: paragraph index (0-based order of <p> and <li> in rendered HTML)
// Value: note text
var annotations: [Int: String]
```

Also update the `PatternEntry` initializer to include default values for all three:
```swift
// Add these parameters with defaults to the existing init:
rowGoal: Int? = nil,
stitchGoal: Int? = nil,
annotations: [Int: String] = [:]
```

And assign them in the body:
```swift
self.rowGoal = rowGoal
self.stitchGoal = stitchGoal
self.annotations = annotations
```

- [ ] **Step 2: Add `updateNote` to PatternLibrary**

In `PatternLibrary.swift`, add a method that the `AnnotationBridge` will call:

```swift
/// Called from AnnotationBridge when JS saves or deletes a note.
func updateNote(index: Int, text: String?) {
    guard let i = entries.firstIndex(where: { $0.id == activeEntry?.id }) else { return }
    if let text = text, !text.isEmpty {
        entries[i].annotations[index] = text
    } else {
        entries[i].annotations.removeValue(forKey: index)
    }
    // Persist the change (call whatever persistence method PatternLibrary already uses)
    save()
}
```

> Note: `save()` refers to whatever persistence method exists in `PatternLibrary`. If none exists yet, add a no-op stub — it can be wired later.

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/PatternEntry.swift CrochetApp/CrochetApp/PatternLibrary.swift && \
git commit -m "feat: add rowGoal, stitchGoal, annotations to PatternEntry"
```

---

## Task 2: SessionTimer

**Files:**
- Create: `CrochetApp/CrochetApp/SessionTimer.swift`

`SessionTimer` is a self-contained `ObservableObject`. It owns a repeating 1-second `Timer.publish`, exposes `elapsed: TimeInterval`, and pauses when `NSApplication` loses focus.

- [ ] **Step 1: Create SessionTimer.swift**

```swift
import Foundation
import Combine
import AppKit

/// Tracks elapsed session time. Not persisted — resets on app relaunch.
/// Owned by CrochetAppApp and injected via environment or direct pass-through.
final class SessionTimer: ObservableObject {

    // MARK: - Published

    /// Total elapsed seconds since last reset (or app launch).
    @Published private(set) var elapsed: TimeInterval = 0

    /// Whether the timer is currently running.
    @Published private(set) var isRunning: Bool = false

    // MARK: - Private

    private var timerCancellable: AnyCancellable?
    private var appObservers: [NSObjectProtocol] = []

    // MARK: - Init

    init() {
        startTimer()
        observeAppFocus()
    }

    deinit {
        appObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Public API

    /// Toggle pause/resume.
    func togglePause() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    /// Reset elapsed time to zero. Does not stop the timer.
    func reset() {
        elapsed = 0
    }

    // MARK: - Private

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsed += 1
            }
    }

    private func pauseTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func observeAppFocus() {
        let resign = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseTimer()
        }

        let activate = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Only auto-resume if the timer was running before losing focus
            // (isRunning is already false when we get here, so we always restart)
            self?.startTimer()
        }

        appObservers = [resign, activate]
    }
}

// MARK: - Formatting Helper

extension SessionTimer {
    /// Formats elapsed time as "m:ss" (under 1 hour) or "h:mm:ss" (1 hour+).
    var displayString: String {
        let total = Int(elapsed)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/SessionTimer.swift && \
git commit -m "feat: add SessionTimer ObservableObject"
```

---

## Task 3: CounterBarView

**Files:**
- Create: `CrochetApp/CrochetApp/CounterBarView.swift`

`CounterBarView` is a horizontal bar that sits at the bottom of the window (or top of the detail pane) showing:
1. Row pill (pink) with count + optional "Set Row Goal…" context menu
2. Stitch pill (purple) with count + optional "Set Stitch Goal…" context menu  
3. Progress bar (shown only when `rowGoal != nil`)
4. Session timer display with tap-to-pause and right-click reset

This view reads from `CounterStore` and `SessionTimer`. Goal values are written back to `PatternEntry` via `PatternLibrary`.

- [ ] **Step 1: Create CounterBarView.swift**

```swift
import SwiftUI

/// Horizontal counter bar shown at the bottom of the window.
/// Displays Row pill, Stitch pill, optional row-goal progress bar, and session timer.
struct CounterBarView: View {

    @ObservedObject var store: CounterStore
    @ObservedObject var timer: SessionTimer
    /// The active PatternEntry. Passed in so this view can read/write rowGoal, stitchGoal.
    @Binding var entry: PatternEntry?

    // MARK: - Local state for goal popovers

    @State private var showRowGoalPopover = false
    @State private var showStitchGoalPopover = false
    @State private var rowGoalInput: String = ""
    @State private var stitchGoalInput: String = ""

    // MARK: - Row flash state (triggered by stitch-goal auto-advance)
    @State private var rowFlash = false

    var body: some View {
        HStack(spacing: 12) {

            // ── Row Pill ──────────────────────────────────────────
            rowPill

            // ── Stitch Pill ───────────────────────────────────────
            stitchPill

            // ── Progress Bar (conditional) ────────────────────────
            if let goal = entry?.rowGoal, goal > 0 {
                rowProgressBar(current: store.rowCount, goal: goal)
            }

            Spacer()

            // ── Session Timer ─────────────────────────────────────
            timerView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - Row Pill

    private var rowPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right.to.line")
                .font(.system(size: 11, weight: .semibold))
            Text("\(store.rowCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.rowCount)
            if let goal = entry?.rowGoal {
                Text("/ \(goal)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowFlash ? Color.pink.opacity(0.5) : Color.pink)
                .animation(.easeInOut(duration: 0.15), value: rowFlash)
        )
        .help("Rows — right-click to set goal")
        .popover(isPresented: $showRowGoalPopover, arrowEdge: .bottom) {
            GoalInputPopover(
                title: "Row Goal",
                currentGoal: entry?.rowGoal,
                inputText: $rowGoalInput,
                onConfirm: { newGoal in
                    entry?.rowGoal = newGoal
                    showRowGoalPopover = false
                },
                onClear: {
                    entry?.rowGoal = nil
                    showRowGoalPopover = false
                }
            )
        }
        .contextMenu {
            Button("Set Row Goal…") {
                rowGoalInput = entry?.rowGoal.map { "\($0)" } ?? ""
                showRowGoalPopover = true
            }
            if entry?.rowGoal != nil {
                Button("Clear Row Goal") {
                    entry?.rowGoal = nil
                }
            }
        }
    }

    // MARK: - Stitch Pill

    private var stitchPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.grid.3x3")
                .font(.system(size: 11, weight: .semibold))
            Text("\(store.stitchCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.stitchCount)
            if let goal = entry?.stitchGoal {
                Text("/ \(goal)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple)
        )
        .help("Stitches — right-click to set goal")
        .popover(isPresented: $showStitchGoalPopover, arrowEdge: .bottom) {
            GoalInputPopover(
                title: "Stitch Goal",
                currentGoal: entry?.stitchGoal,
                inputText: $stitchGoalInput,
                onConfirm: { newGoal in
                    entry?.stitchGoal = newGoal
                    showStitchGoalPopover = false
                },
                onClear: {
                    entry?.stitchGoal = nil
                    showStitchGoalPopover = false
                }
            )
        }
        .contextMenu {
            Button("Set Stitch Goal…") {
                stitchGoalInput = entry?.stitchGoal.map { "\($0)" } ?? ""
                showStitchGoalPopover = true
            }
            if entry?.stitchGoal != nil {
                Button("Clear Stitch Goal") {
                    entry?.stitchGoal = nil
                }
            }
        }
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private func rowProgressBar(current: Int, goal: Int) -> some View {
        let fraction = min(Double(current) / Double(goal), 1.0)
        VStack(alignment: .leading, spacing: 2) {
            Text("\(current) / \(goal) rows")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.pink.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.pink)
                        .frame(width: geo.size.width * fraction, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 6)
        }
        .frame(minWidth: 80, maxWidth: 160)
    }

    // MARK: - Timer View

    private var timerView: some View {
        HStack(spacing: 5) {
            Image(systemName: timer.isRunning ? "timer" : "pause.circle")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(timer.displayString)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .animation(nil, value: timer.displayString)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .help(timer.isRunning ? "Session timer — click to pause" : "Session timer — click to resume")
        .onTapGesture {
            timer.togglePause()
        }
        .contextMenu {
            Button("Reset Timer") {
                timer.reset()
            }
            Divider()
            if timer.isRunning {
                Button("Pause") { timer.togglePause() }
            } else {
                Button("Resume") { timer.togglePause() }
            }
        }
    }

    // MARK: - Row Flash (called by CounterStore on auto-advance)

    /// Trigger a brief color flash on the Row pill to acknowledge auto-advance.
    func flashRow() {
        rowFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            rowFlash = false
        }
    }
}

// MARK: - GoalInputPopover

/// Small popover for entering an integer goal value.
private struct GoalInputPopover: View {
    let title: String
    let currentGoal: Int?
    @Binding var inputText: String
    let onConfirm: (Int) -> Void
    let onClear: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField(currentGoal.map { "\($0)" } ?? "e.g. 60", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .focused($fieldFocused)
                .onSubmit { confirm() }

            HStack {
                if currentGoal != nil {
                    Button("Clear", role: .destructive, action: onClear)
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button("Cancel") { onClear() /* dismiss without saving */ }
                    .buttonStyle(.bordered)
                Button("Set") { confirm() }
                    .buttonStyle(.borderedProminent)
                    .disabled(Int(inputText) == nil)
            }
        }
        .padding(16)
        .frame(width: 200)
        .onAppear { fieldFocused = true }
    }

    private func confirm() {
        if let value = Int(inputText), value > 0 {
            onConfirm(value)
        }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

> If you get "cannot find type 'PatternEntry' in scope" errors, confirm the pattern-management plan has been fully implemented first.

- [ ] **Step 3: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/CounterBarView.swift && \
git commit -m "feat: add CounterBarView with progress bar, timer display, and goal popovers"
```

---

## Task 4: CounterStore — Stitch-Goal Auto-Advance

**Files:**
- Modify: `CrochetApp/CrochetApp/CounterStore.swift`

`CounterStore` needs to check `stitchGoal` after every stitch increment. When the stitch count reaches the goal, it calls `incrementRow()` (which already resets stitchCount if `autoResetStitch` is true) and always resets stitchCount to 0.

The store needs a reference to `PatternLibrary` to read `activeEntry?.stitchGoal`. Use a weak `var library: PatternLibrary?` that callers inject after construction.

- [ ] **Step 1: Add library weak reference to CounterStore**

In `CounterStore.swift`, add this property below the `@Published` properties block:

```swift
/// Injected by the owner (CrochetAppApp or ContentView) after init.
/// Weak to avoid a retain cycle — PatternLibrary may hold the store indirectly.
weak var library: PatternLibrary?
```

> `PatternLibrary` must be a `class` (AnyObject-conforming) for `weak` to work. If it's a struct, change this to `var library: PatternLibrary?` (non-weak) and accept the copy semantics — but the pattern-management plan should have made it a class since it's an `ObservableObject`.

- [ ] **Step 2: Update incrementStitch() to auto-advance**

Replace the existing `incrementStitch()` body:

```swift
func incrementStitch() {
    stitchCount += 1
    // Auto-advance: if a stitch goal is set and we've hit it, end the row
    if let goal = library?.activeEntry?.stitchGoal, goal > 0, stitchCount >= goal {
        rowCount += 1
        stitchCount = 0
        // Note: we always reset stitchCount on goal-advance regardless of autoResetStitch
    }
}
```

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/CounterStore.swift && \
git commit -m "feat: stitch-goal auto-advance in CounterStore.incrementStitch"
```

---

## Task 5: KeyHandlerView — Space and Return Shortcuts

**Files:**
- Modify: `CrochetApp/CrochetApp/ContentView.swift`

The existing `KeyHandlerView.keyDown` switch handles arrow keys and `R/r/S/s` characters. Add:
- **Space** (keyCode 49): `store.incrementStitch()`  
- **Return** (keyCode 36): `store.rowCount += 1` then `store.stitchCount = 0` — this is an explicit "end of row" that always resets stitch regardless of `autoResetStitch`.

Also update `KeyboardShortcutGuide` in `CounterView.swift` to list the two new shortcuts.

- [ ] **Step 1: Add Space and Return to KeyHandlerView.keyDown**

In `ContentView.swift`, locate the `switch event.keyCode` block and add two cases before `default`:

```swift
case 49: // Space — increment stitch
    store.incrementStitch()
case 36: // Return — end of row: increment row + always reset stitch
    store.rowCount += 1
    store.stitchCount = 0
```

The full updated switch should look like:

```swift
switch event.keyCode {
case 126: // Up arrow
    store.incrementRow()
case 125: // Down arrow
    store.decrementRow()
case 124: // Right arrow
    store.incrementStitch()
case 123: // Left arrow
    store.decrementStitch()
case 49: // Space — increment stitch
    store.incrementStitch()
case 36: // Return — end of row: increment row + always reset stitch
    store.rowCount += 1
    store.stitchCount = 0
default:
    // Character-based shortcuts
    switch event.charactersIgnoringModifiers {
    case "R":
        store.incrementRow()
    case "r":
        store.decrementRow()
    case "S":
        store.incrementStitch()
    case "s":
        store.decrementStitch()
    default:
        super.keyDown(with: event)
    }
}
```

- [ ] **Step 2: Update KeyboardShortcutGuide in CounterView.swift**

Locate the `VStack` containing `ShortcutRow` calls inside `KeyboardShortcutGuide` and add two new rows:

```swift
ShortcutRow(key: "Space", description: "Stitch +1")
ShortcutRow(key: "Return", description: "End row (row +1, stitch reset)")
```

Place them before the existing `⌘O` line so the full block reads:

```swift
VStack(spacing: 4) {
    ShortcutRow(key: "↑ / R", description: "Row +1")
    ShortcutRow(key: "↓ / r", description: "Row -1")
    ShortcutRow(key: "→ / S", description: "Stitch +1")
    ShortcutRow(key: "← / s", description: "Stitch -1")
    ShortcutRow(key: "Space", description: "Stitch +1")
    ShortcutRow(key: "Return", description: "End row (row +1, stitch reset)")
    ShortcutRow(key: "⌘O", description: "Open pattern file")
    ShortcutRow(key: "⌘⌫", description: "Reset all")
}
```

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/ContentView.swift CrochetApp/CrochetApp/CounterView.swift && \
git commit -m "feat: add Space and Return keyboard shortcuts"
```

---

## Task 6: AnnotationBridge + WKWebView JS Injection

**Files:**
- Create: `CrochetApp/CrochetApp/AnnotationBridge.swift`
- Modify: `CrochetApp/CrochetApp/MarkdownView.swift`

`AnnotationBridge` is the Swift side of the JS↔Swift bridge. It implements `WKScriptMessageHandler` and receives `{ action, index, text }` messages from JavaScript running in the WKWebView. It calls `PatternLibrary.updateNote(index:text:)` to persist changes.

`MarkdownView.swift` needs two changes:
1. Accept `annotations: [Int: String]` as input
2. Register `AnnotationBridge` as a `userContentController` message handler named `"AnnotationBridge"`
3. After the HTML loads, call `evaluateJavaScript` with a bootstrap script that wires up double-click listeners and renders existing notes

- [ ] **Step 1: Create AnnotationBridge.swift**

```swift
import WebKit

/// Receives messages from the annotation JavaScript running in WKWebView.
/// Message format: { "action": "save" | "delete", "index": Int, "text": String }
final class AnnotationBridge: NSObject, WKScriptMessageHandler {

    /// Weak reference to the library so we can call updateNote without creating a retain cycle.
    weak var library: PatternLibrary?

    init(library: PatternLibrary) {
        self.library = library
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "AnnotationBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              let index = body["index"] as? Int
        else { return }

        switch action {
        case "save":
            let text = (body["text"] as? String) ?? ""
            library?.updateNote(index: index, text: text.isEmpty ? nil : text)
        case "delete":
            library?.updateNote(index: index, text: nil)
        default:
            break
        }
    }
}
```

- [ ] **Step 2: Update MarkdownWebView to accept annotations and register the bridge**

`MarkdownWebView` currently takes only `htmlContent: String`. Change its signature and wiring:

Replace the entire `MarkdownWebView` struct in `MarkdownView.swift` with:

```swift
// MARK: - WKWebView Wrapper
struct MarkdownWebView: NSViewRepresentable {
    let htmlContent: String
    let annotations: [Int: String]
    let bridge: AnnotationBridge

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Register the Swift message handler
        config.userContentController.add(bridge, name: "AnnotationBridge")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingAnnotations = annotations
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(annotations: annotations)
    }

    // MARK: - Coordinator (WKNavigationDelegate)

    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingAnnotations: [Int: String]

        init(annotations: [Int: String]) {
            self.pendingAnnotations = annotations
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectAnnotationJS(into: webView, annotations: pendingAnnotations)
        }

        private func injectAnnotationJS(into webView: WKWebView, annotations: [Int: String]) {
            // Serialize existing annotations as JSON for the bootstrap
            let annotationsJSON: String
            if let data = try? JSONSerialization.data(withJSONObject: annotations.mapKeys { "\($0)" }),
               let str = String(data: data, encoding: .utf8) {
                annotationsJSON = str
            } else {
                annotationsJSON = "{}"
            }

            let js = """
            (function() {
              var AMBER = '#e8b84b';
              var existingNotes = \(annotationsJSON);

              // Collect all annotatable blocks (p and li elements, 0-based index)
              var blocks = Array.from(document.querySelectorAll('p, li'));

              // Render existing notes
              blocks.forEach(function(block, idx) {
                var key = String(idx);
                if (existingNotes[key]) {
                  insertNoteElement(block, idx, existingNotes[key]);
                }
              });

              // Wire double-click to create/edit a note
              blocks.forEach(function(block, idx) {
                block.addEventListener('dblclick', function(e) {
                  e.stopPropagation();
                  openEditor(block, idx);
                });
              });

              function noteId(idx) { return 'ann-note-' + idx; }
              function editorId(idx) { return 'ann-editor-' + idx; }

              function insertNoteElement(block, idx, text) {
                var existing = document.getElementById(noteId(idx));
                if (existing) { existing.remove(); }
                var div = document.createElement('div');
                div.id = noteId(idx);
                div.setAttribute('data-ann-idx', idx);
                div.style.cssText = [
                  'border-left: 2px solid ' + AMBER,
                  'padding-left: 10px',
                  'margin: 4px 0 8px 0',
                  'font-style: italic',
                  'color: #999',
                  'font-size: 11px',
                  'cursor: pointer'
                ].join(';');
                div.textContent = text;
                div.addEventListener('click', function(e) {
                  e.stopPropagation();
                  openEditor(block, idx, text);
                });
                block.insertAdjacentElement('afterend', div);
              }

              function openEditor(block, idx, existingText) {
                // Remove any open editor first
                var openEditors = document.querySelectorAll('[id^="ann-editor-"]');
                openEditors.forEach(function(el) { el.remove(); });

                var container = document.createElement('div');
                container.id = editorId(idx);
                container.style.cssText = [
                  'border-left: 2px solid ' + AMBER,
                  'padding-left: 10px',
                  'margin: 4px 0 8px 0',
                  'display: flex',
                  'align-items: center',
                  'gap: 8px'
                ].join(';');

                var input = document.createElement('input');
                input.type = 'text';
                input.value = existingText || '';
                input.placeholder = 'Add a note…';
                input.style.cssText = [
                  'flex: 1',
                  'border: none',
                  'border-bottom: 1px solid ' + AMBER,
                  'background: transparent',
                  'font-style: italic',
                  'color: #999',
                  'font-size: 11px',
                  'outline: none',
                  'padding: 2px 0'
                ].join(';');

                input.addEventListener('keydown', function(e) {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    saveNote(idx, input.value, container);
                  } else if (e.key === 'Escape') {
                    container.remove();
                  }
                });

                container.appendChild(input);

                // Delete link (only shown when editing an existing note)
                if (existingText) {
                  var del = document.createElement('a');
                  del.textContent = 'Delete';
                  del.href = '#';
                  del.style.cssText = 'color: #999; font-size: 10px; text-decoration: none;';
                  del.addEventListener('click', function(e) {
                    e.preventDefault();
                    deleteNote(idx, container);
                  });
                  container.appendChild(del);
                }

                block.insertAdjacentElement('afterend', container);
                input.focus();
              }

              function saveNote(idx, text, container) {
                container.remove();
                var block = blocks[idx];
                var noteEl = document.getElementById(noteId(idx));
                if (noteEl) { noteEl.remove(); }
                if (text.trim()) {
                  insertNoteElement(block, idx, text.trim());
                  window.webkit.messageHandlers.AnnotationBridge.postMessage({
                    action: 'save', index: idx, text: text.trim()
                  });
                } else {
                  window.webkit.messageHandlers.AnnotationBridge.postMessage({
                    action: 'delete', index: idx, text: ''
                  });
                }
              }

              function deleteNote(idx, container) {
                container.remove();
                var noteEl = document.getElementById(noteId(idx));
                if (noteEl) { noteEl.remove(); }
                window.webkit.messageHandlers.AnnotationBridge.postMessage({
                  action: 'delete', index: idx, text: ''
                });
              }
            })();
            """

            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[AnnotationJS] Error injecting JS: \\(error)")
                }
            }
        }
    }
}
```

> Note: `mapKeys` is not a standard Swift method on `Dictionary`. Replace that line with:
> ```swift
> var stringKeyedAnnotations: [String: String] = [:]
> for (k, v) in annotations { stringKeyedAnnotations["\(k)"] = v }
> let data = try? JSONSerialization.data(withJSONObject: stringKeyedAnnotations)
> ```

- [ ] **Step 3: Update MarkdownView to pass annotations and bridge to MarkdownWebView**

`MarkdownView` now needs a reference to `PatternLibrary` (or the active entry's annotations). The cleanest approach is to pass `PatternLibrary` in and let `MarkdownView` create the `AnnotationBridge` as a `@StateObject`-equivalent private property.

Replace the `MarkdownView` struct declaration and properties:

```swift
struct MarkdownView: View {
    @Binding var fileURL: URL?
    /// Library reference used to create the AnnotationBridge.
    @ObservedObject var library: PatternLibrary

    @State private var markdownContent: String = ""
    @State private var htmlContent: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Lazily created bridge — held as a stored let so it's stable across redraws.
    // We create it once in init and hold it here.
    private let bridge: AnnotationBridge

    init(fileURL: Binding<URL?>, library: PatternLibrary) {
        self._fileURL = fileURL
        self.library = library
        self.bridge = AnnotationBridge(library: library)
    }
```

And update the `MarkdownWebView` call site inside the `body`:

```swift
MarkdownWebView(
    htmlContent: htmlContent,
    annotations: library.activeEntry?.annotations ?? [:],
    bridge: bridge
)
```

Update all call sites of `MarkdownView(fileURL:)` → `MarkdownView(fileURL:library:)` in `ContentView.swift`.

- [ ] **Step 4: Fix the mapKeys issue**

In `MarkdownWebView.Coordinator.injectAnnotationJS`, replace:

```swift
if let data = try? JSONSerialization.data(withJSONObject: annotations.mapKeys { "\($0)" }),
   let str = String(data: data, encoding: .utf8) {
    annotationsJSON = str
} else {
    annotationsJSON = "{}"
}
```

with:

```swift
var stringKeyed: [String: String] = [:]
for (k, v) in annotations { stringKeyed["\(k)"] = v }
if let data = try? JSONSerialization.data(withJSONObject: stringKeyed),
   let str = String(data: data, encoding: .utf8) {
    annotationsJSON = str
} else {
    annotationsJSON = "{}"
}
```

- [ ] **Step 5: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/AnnotationBridge.swift CrochetApp/CrochetApp/MarkdownView.swift && \
git commit -m "feat: AnnotationBridge + WKWebView JS annotation injection"
```

---

## Task 7: Wire SessionTimer into CrochetAppApp + ContentView

**Files:**
- Modify: `CrochetApp/CrochetApp/CrochetAppApp.swift`
- Modify: `CrochetApp/CrochetApp/ContentView.swift`

`SessionTimer` must be owned at the app level so it survives window navigation. `CrochetAppApp` creates it as a `@StateObject` and passes it down to `ContentView`. `ContentView` passes it to `CounterBarView`.

`ContentView` must also be updated to:
1. Accept `SessionTimer` from the environment or direct injection
2. Embed `CounterBarView` at the bottom of the window layout
3. Pass `library` to `MarkdownView`

- [ ] **Step 1: Update CrochetAppApp.swift to own SessionTimer**

Replace the entire `CrochetAppApp` struct body:

```swift
import SwiftUI

@main
struct CrochetAppApp: App {
    @StateObject private var sessionTimer = SessionTimer()

    var body: some Scene {
        WindowGroup {
            ContentView(sessionTimer: sessionTimer)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" command since we use "Open"
            }

            CommandGroup(after: .newItem) {
                Button("Open Pattern…") {
                    NotificationCenter.default.post(name: .openPatternFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

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

// MARK: - Notification Names
extension Notification.Name {
    static let openPatternFile = Notification.Name("CrochetApp.openPatternFile")
    static let resetAllCounters = Notification.Name("CrochetApp.resetAllCounters")
}
```

- [ ] **Step 2: Update ContentView to accept SessionTimer and embed CounterBarView**

Replace the `ContentView` struct in `ContentView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = CounterStore()
    /// PatternLibrary from the pattern-management plan.
    @StateObject private var library = PatternLibrary()
    @ObservedObject var sessionTimer: SessionTimer

    @State private var showFilePicker = false
    @State private var showResetConfirmation = false

    init(sessionTimer: SessionTimer) {
        self.sessionTimer = sessionTimer
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                // Sidebar: Counter Panel
                CounterView(store: store)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
            } detail: {
                // Detail: Markdown Preview
                MarkdownView(fileURL: $store.openedFileURL, library: library)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(store.openedFileURL?.deletingPathExtension().lastPathComponent ?? "Crochet Helper")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Open Pattern", systemImage: "doc.badge.plus")
                    }
                    .help("Open a Markdown pattern file (⌘O)")

                    if store.openedFileURL != nil {
                        Button {
                            store.openedFileURL = nil
                        } label: {
                            Label("Close Pattern", systemImage: "xmark.circle")
                        }
                        .help("Close the current pattern file")
                    }
                }
            }

            // ── Counter Bar ──────────────────────────────────────────
            CounterBarView(
                store: store,
                timer: sessionTimer,
                entry: Binding(
                    get: { library.activeEntry },
                    set: { library.activeEntry = $0 }
                )
            )
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.text, UTType(filenameExtension: "md") ?? .text, UTType(filenameExtension: "markdown") ?? .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.openedFileURL = url
                }
            case .failure(let error):
                print("File picker error: \(error.localizedDescription)")
            }
        }
        .background(KeyboardShortcutHandler(store: store, showFilePicker: $showFilePicker))
        .onAppear {
            store.library = library
        }
    }
}
```

> If `PatternLibrary` exposes `activeEntry` as a computed var backed by the entries array (not a direct `@Published var`), the `Binding` above needs adjustment. A simple workaround is to add `@Published var activeEntry: PatternEntry?` directly on `PatternLibrary` and keep it in sync.

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add CrochetApp/CrochetApp/CrochetAppApp.swift CrochetApp/CrochetApp/ContentView.swift && \
git commit -m "feat: wire SessionTimer and CounterBarView into app root"
```

---

## Task 8: Smoke Test

This task manually verifies all six features end-to-end using the macOS Simulator.

- [ ] **Step 1: Build and launch**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Open the built app at `~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/CrochetApp.app` or run via Xcode.

- [ ] **Step 2: Verify SessionTimer**

On launch, the counter bar at the bottom should show `⏱ 0:00` (or similar). After ~5 seconds the number should tick up. Click the timer display — it should pause (icon changes). Click again — it should resume. Right-click → "Reset Timer" should reset to `0:00`.

- [ ] **Step 3: Verify Row Goal + Progress Bar**

Right-click the pink Row pill in the counter bar. A context menu should appear with "Set Row Goal…". Click it. A small popover should appear with a text field. Enter `10` and press "Set". The bar should disappear/appear (needs a row value > 0 to show). Increment the row a few times using `↑` — the progress bar should fill proportionally. Right-click the Row pill → "Clear Row Goal" — the bar should disappear.

- [ ] **Step 4: Verify Stitch Goal Auto-Advance**

Right-click the purple Stitch pill → "Set Stitch Goal…" → enter `3`. Press `Space` three times. On the third press, the stitch count should reset to 0 and the row count should increment by 1.

- [ ] **Step 5: Verify Space and Return shortcuts**

With the app focused (click the window), press `Space` — stitch count should increase by 1. Press `Return` — row count should increase by 1 AND stitch count should reset to 0 (regardless of auto-reset toggle).

- [ ] **Step 6: Verify Inline Annotations**

Open a Markdown pattern file (⌘O). Double-click any paragraph in the rendered markdown — an inline input field with an amber left border should appear. Type a note and press Return — the note should appear as italic grey text below the paragraph. Click the note text — it should become editable again with a "Delete" link. Click Delete — the note should disappear.

- [ ] **Step 7: Final commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add -p && \
git commit -m "feat: pattern enhancements — goals, annotations, timer, keyboard shortcuts"
```

---

## Spec Coverage Checklist

| Spec Requirement | Task |
|-----------------|------|
| `rowGoal: Int?` on PatternEntry | Task 1 |
| `stitchGoal: Int?` on PatternEntry | Task 1 |
| `annotations: [Int: String]` on PatternEntry | Task 1 |
| Progress bar hidden when rowGoal is nil | Task 3 (CounterBarView — `if let goal`) |
| Progress bar pink, "12 / 60 rows" label | Task 3 |
| Row goal set via right-click popover | Task 3 |
| Clearing goal hides bar | Task 3 |
| Stitch goal set via right-click on Stitch pill | Task 3 |
| SessionTimer ObservableObject, elapsed TimeInterval | Task 2 |
| Timer pauses on app resign | Task 2 (`didResignActiveNotification`) |
| Timer display in counter bar | Task 3 |
| Tap timer to pause/resume | Task 3 |
| Right-click timer → Reset Timer | Task 3 |
| `h:mm:ss` / `m:ss` format | Task 2 (`displayString`) |
| Space key → increment stitch | Task 5 |
| Return key → row +1, stitch reset to 0 | Task 5 |
| Stitch-goal auto-advance in incrementStitch | Task 4 |
| Row flash on auto-advance | Task 3 (`flashRow`) |
| Double-click paragraph → inline input | Task 6 (JS `dblclick`) |
| Return saves note, Escape cancels | Task 6 (JS `keydown`) |
| Click existing note to edit | Task 6 (JS `click` on note div) |
| Delete link removes note | Task 6 (JS `deleteNote`) |
| Notes render italic grey with amber left rule | Task 6 (JS `insertNoteElement`) |
| `WKScriptMessageHandler` "AnnotationBridge" | Task 6 |
| JS → Swift → `PatternLibrary.updateNote` | Task 6 |
| SessionTimer owned by CrochetAppApp | Task 7 |
| CounterBarView shown in ContentView | Task 7 |
