import SwiftUI

/// Horizontal counter bar shown at the top of the content pane.
/// Displays Row pill, Stitch pill, optional row-goal progress bar, and session timer.
struct CounterBarView: View {

    @ObservedObject var store: CounterStore
    @ObservedObject var timer: SessionTimer
    /// The active PatternEntry. Passed in so this view can read/write rowGoal, stitchGoal.
    @Binding var entry: PatternEntry?
    @Binding var showAIPanel: Bool

    // MARK: - Local state for goal popovers

    @State private var showRowGoalPopover = false
    @State private var showStitchGoalPopover = false
    @State private var rowGoalInput: String = ""
    @State private var stitchGoalInput: String = ""
    @State private var showResetConfirmation = false

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

            // ── Auto-reset toggle ─────────────────────────────────
            HStack(spacing: 6) {
                Toggle("", isOn: $store.autoResetStitch)
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .onChange(of: store.autoResetStitch) { newValue in
                        store.library?.updateActiveCounters(
                            row: store.rowCount,
                            stitch: store.stitchCount,
                            autoReset: newValue
                        )
                    }
                Text("Auto-reset")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider().frame(height: 32)

            // ── Keyboard hint ─────────────────────────────────────
            Text("↑↓ row · ←→ stitch")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))

            Divider().frame(height: 32)

            // ── Session Timer ─────────────────────────────────────
            timerView

            Divider().frame(height: 32)

            // ── Reset button ──────────────────────────────────────
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

            // ── AI panel toggle — macOS 26+ only ─────────────────────
            if #available(macOS 26.0, *) {
                Divider().frame(height: 32)
                Button {
                    showAIPanel.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text("AI")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(showAIPanel ? .purple : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showAIPanel ? Color.purple.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(showAIPanel ? "Close AI panel" : "Open AI panel")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Row Pill

    private var rowPill: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation { store.decrementRow() } }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.pink.opacity(0.15))
                    .foregroundColor(store.rowCount == 0 ? Color.secondary : Color(red: 0.71, green: 0.33, blue: 0.49))
            }
            .buttonStyle(.plain)
            .disabled(store.rowCount == 0)

            Divider().frame(height: 36)

            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    Text("ROW")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.71, green: 0.33, blue: 0.49))
                    if let goal = entry?.rowGoal {
                        Text("/ \(goal)")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.71, green: 0.33, blue: 0.49).opacity(0.7))
                    }
                }
                Text("\(store.rowCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.71, green: 0.33, blue: 0.49))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.rowCount)
            }
            .frame(minWidth: 52)
            .padding(.horizontal, 6)

            Divider().frame(height: 36)

            Button(action: { withAnimation { store.incrementRow() } }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.pink.opacity(0.15))
                    .foregroundColor(Color(red: 0.71, green: 0.33, blue: 0.49))
            }
            .buttonStyle(.plain)
        }
        .background(Color.pink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.pink.opacity(0.25), lineWidth: 1.5)
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
                onDismiss: { showRowGoalPopover = false }
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
        HStack(spacing: 0) {
            Button(action: { withAnimation { store.decrementStitch() } }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(store.stitchCount == 0 ? Color.secondary : Color(red: 0.49, green: 0.30, blue: 0.80))
            }
            .buttonStyle(.plain)
            .disabled(store.stitchCount == 0)

            Divider().frame(height: 36)

            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    Text("STITCH")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.49, green: 0.30, blue: 0.80))
                    if let goal = entry?.stitchGoal {
                        Text("/ \(goal)")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.49, green: 0.30, blue: 0.80).opacity(0.7))
                    }
                }
                Text("\(store.stitchCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.49, green: 0.30, blue: 0.80))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.stitchCount)
            }
            .frame(minWidth: 52)
            .padding(.horizontal, 6)

            Divider().frame(height: 36)

            Button(action: { withAnimation { store.incrementStitch() } }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(Color(red: 0.49, green: 0.30, blue: 0.80))
            }
            .buttonStyle(.plain)
        }
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1.5)
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
                onDismiss: { showStitchGoalPopover = false }
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
            Button("Reset Timer") { timer.reset() }
            Divider()
            if timer.isRunning {
                Button("Pause") { timer.togglePause() }
            } else {
                Button("Resume") { timer.togglePause() }
            }
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
    let onDismiss: () -> Void

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
                    Button("Clear", role: .destructive, action: onDismiss)
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button("Cancel", action: onDismiss)
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
