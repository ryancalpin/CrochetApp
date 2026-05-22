import SwiftUI

struct CounterBarView: View {

    @ObservedObject var store: CounterStore
    @ObservedObject var timer: SessionTimer
    @Binding var entry: PatternEntry?
    @Binding var showAIPanel: Bool

    @ObservedObject private var settings = AppSettings.shared

    @Environment(\.colorScheme) private var colorScheme

    @State private var showRowGoalPopover    = false
    @State private var showStitchGoalPopover = false
    @State private var rowGoalInput:    String = ""
    @State private var stitchGoalInput: String = ""
    @State private var showResetConfirmation = false
    @State private var showRepeatResetConfirmation = false

    // Width below which secondary controls collapse into the ⋯ menu.
    private let compactBreakpoint: CGFloat = 500

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < compactBreakpoint
            HStack(spacing: 10) {
                rowPill
                stitchPill
                if entry?.showRepeatCounter == true {
                    repeatPill
                }

                if !compact, let goal = entry?.rowGoal, goal > 0 {
                    rowProgressBar(current: store.rowCount, goal: goal)
                }

                Spacer(minLength: 4)

                if compact {
                    overflowMenu
                } else {
                    audioCueButton
                    if settings.showTimer {
                        Divider().frame(height: 30)
                        timerView
                    }
                    Divider().frame(height: 30)
                    resetButton
                    if #available(macOS 26.0, *) {
                        Divider().frame(height: 30)
                        aiToggleButton
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: pillHeight + 16)
        .background(Color.surface)
        .overlay(alignment: .bottom) { Divider() }
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
        .confirmationDialog(
            "Reset repeat counter?",
            isPresented: $showRepeatResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { store.resetRepeat() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Repeat count will be set to 0.")
        }
    }

    private var pillHeight: CGFloat { settings.counterSize.pillHeight }

    // MARK: - Row Pill

    private var rowPill: some View {
        CounterPill(
            label: "ROW",
            value: store.rowCount,
            goal: entry?.rowGoal,
            color: settings.rowColor.legible(in: colorScheme),
            size: settings.counterSize,
            onDecrement: { store.decrementRow() },
            onIncrement: { store.incrementRow() }
        )
        .help("Rows — right-click to set goal")
        .popover(isPresented: $showRowGoalPopover, arrowEdge: .bottom) {
            GoalInputPopover(
                title: "Row Goal",
                currentGoal: entry?.rowGoal,
                inputText: $rowGoalInput,
                onConfirm: { entry?.rowGoal = $0; showRowGoalPopover = false },
                onClear: { entry?.rowGoal = nil; showRowGoalPopover = false },
                onDismiss: { showRowGoalPopover = false }
            )
        }
        .contextMenu {
            Button("Set Row Goal…") {
                rowGoalInput = entry?.rowGoal.map { "\($0)" } ?? ""
                showRowGoalPopover = true
            }
            if entry?.rowGoal != nil {
                Button("Clear Row Goal") { entry?.rowGoal = nil }
            }
            Divider()
            if entry?.showRepeatCounter == true {
                Button("Hide Repeat Counter") {
                    guard let e = entry else { return }
                    store.resetRepeat()
                    entry?.showRepeatCounter = false
                    // persist via library binding
                    _ = e
                }
            } else {
                Button("Add Repeat Counter") { entry?.showRepeatCounter = true }
            }
        }
    }

    // MARK: - Repeat Pill

    private var repeatPill: some View {
        CounterPill(
            label: "REPEAT",
            value: store.repeatCount,
            goal: nil,
            color: settings.repeatColor.legible(in: colorScheme),
            size: settings.counterSize,
            onDecrement: { store.decrementRepeat() },
            onIncrement: { store.incrementRepeat() }
        )
        .help("Repeat counter — right-click to reset or hide")
        .contextMenu {
            Button("Reset Repeat") { showRepeatResetConfirmation = true }
            Button("Hide Repeat Counter") {
                store.resetRepeat()
                entry?.showRepeatCounter = false
            }
        }
    }

    // MARK: - Stitch Pill

    private var stitchPill: some View {
        CounterPill(
            label: "STITCH",
            value: store.stitchCount,
            goal: entry?.stitchGoal,
            color: settings.stitchColor.legible(in: colorScheme),
            size: settings.counterSize,
            onDecrement: { store.decrementStitch() },
            onIncrement: { store.incrementStitch() }
        )
        .help("Stitches — right-click to set goal")
        .popover(isPresented: $showStitchGoalPopover, arrowEdge: .bottom) {
            GoalInputPopover(
                title: "Stitch Goal",
                currentGoal: entry?.stitchGoal,
                inputText: $stitchGoalInput,
                onConfirm: { entry?.stitchGoal = $0; showStitchGoalPopover = false },
                onClear: { entry?.stitchGoal = nil; showStitchGoalPopover = false },
                onDismiss: { showStitchGoalPopover = false }
            )
        }
        .contextMenu {
            Button("Set Stitch Goal…") {
                stitchGoalInput = entry?.stitchGoal.map { "\($0)" } ?? ""
                showStitchGoalPopover = true
            }
            if entry?.stitchGoal != nil {
                Button("Clear Stitch Goal") { entry?.stitchGoal = nil }
            }
        }
    }

    // MARK: - Progress bar

    @ViewBuilder
    private func rowProgressBar(current: Int, goal: Int) -> some View {
        let fraction = min(Double(current) / Double(goal), 1.0)
        let fill = settings.rowColor.legible(in: colorScheme)
        VStack(alignment: .leading, spacing: 2) {
            Text("\(current) / \(goal) rows")
                .font(.system(size: 10)).foregroundColor(.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(fill.opacity(0.2)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(fill)
                        .frame(width: geo.size.width * fraction, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 6)
        }
        .frame(minWidth: 70, maxWidth: 140)
    }

    // MARK: - Timer

    private var timerView: some View {
        HStack(spacing: 5) {
            Image(systemName: timer.isRunning ? "timer" : "pause.circle")
                .font(.system(size: 11)).foregroundColor(.secondary)
            Text(timer.displayString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .animation(nil, value: timer.displayString)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.surfaceRaised))
        .help(timer.isRunning ? "Click to pause" : "Click to resume")
        .onTapGesture { timer.togglePause() }
        .contextMenu {
            Button(timer.isRunning ? "Pause" : "Resume") { timer.togglePause() }
            Button("Reset Timer") { timer.reset() }
        }
    }

    // MARK: - Audio cue button

    private var audioCueButton: some View {
        Button { settings.audioCueEnabled.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.audioCueEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                    .font(.system(size: 11))
                Text("Row Cue").font(.system(size: 11))
            }
            .foregroundColor(settings.audioCueEnabled ? rowColor : .secondary)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(settings.audioCueEnabled ? rowColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(settings.audioCueEnabled ? "Row audio cue on — click to disable" : "Row audio cue off — click to enable")
        .accessibilityLabel("Row audio cue")
        .accessibilityValue(settings.audioCueEnabled ? "On" : "Off")
    }

    // MARK: - Reset button

    private var resetButton: some View {
        Button("Reset") { showResetConfirmation = true }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
    }

    // MARK: - AI toggle

    @available(macOS 26.0, *)
    private var aiToggleButton: some View {
        Button { showAIPanel.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold))
                Text("AI").font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(showAIPanel ? .purple : .secondary)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(showAIPanel ? Color.purple.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(showAIPanel ? "Close AI panel" : "Open AI panel")
        .accessibilityLabel("Toggle AI assistant")
        .accessibilityValue(showAIPanel ? "Open" : "Closed")
    }

    // MARK: - Overflow menu (compact)

    private var overflowMenu: some View {
        Menu {
            Label(timer.displayString, systemImage: "timer")
            Divider()
            Button(timer.isRunning ? "Pause Timer" : "Resume Timer") { timer.togglePause() }
            Button("Reset Timer") { timer.reset() }
            Divider()
            Button(settings.audioCueEnabled ? "Disable Row Cue" : "Enable Row Cue") { settings.audioCueEnabled.toggle() }
            Divider()
            Button("Reset Counters…") { showResetConfirmation = true }
            if #available(macOS 26.0, *) {
                Divider()
                Button(showAIPanel ? "Close AI Panel" : "Open AI Panel") { showAIPanel.toggle() }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Colors

    private var rowColor: Color { settings.rowColor.legible(in: colorScheme) }
}

// MARK: - GoalInputPopover

private struct GoalInputPopover: View {
    let title: String
    let currentGoal: Int?
    @Binding var inputText: String
    let onConfirm: (Int) -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextField(currentGoal.map { "\($0)" } ?? "e.g. 60", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .focused($focused)
                .onSubmit { confirm() }
            HStack {
                if currentGoal != nil {
                    Button("Clear", role: .destructive, action: onClear).buttonStyle(.bordered)
                }
                Spacer()
                Button("Cancel", action: onDismiss).buttonStyle(.bordered)
                Button("Set") { confirm() }
                    .buttonStyle(.borderedProminent)
                    .disabled(Int(inputText) == nil)
            }
        }
        .padding(16)
        .frame(width: 200)
        .onAppear { focused = true }
    }

    private func confirm() {
        if let v = Int(inputText), v > 0 { onConfirm(v) }
    }
}
