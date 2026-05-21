import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            countingTab
                .tabItem { Label("Counting", systemImage: "list.number") }
            paceTab
                .tabItem { Label("Pace & AI", systemImage: "sparkles") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 400, height: 300)
    }

    // MARK: - Counting

    private var countingTab: some View {
        Form {
            Section("Row Behavior") {
                Toggle("Auto-reset stitches when incrementing row", isOn: $settings.autoResetStitches)
                    .help("When on, pressing + on ROW resets the stitch counter to 0.")
            }
            Section("Default Goals for New Patterns") {
                HStack {
                    Text("Row goal")
                    Spacer()
                    TextField("None", value: $settings.defaultRowGoal, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Stitch goal")
                    Spacer()
                    TextField("None", value: $settings.defaultStitchGoal, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Pace & AI

    private var paceTab: some View {
        Form {
            Section("AI Time Estimation") {
                HStack {
                    Text("Rows per hour")
                    Spacer()
                    Stepper("\(settings.rowsPerHour)", value: $settings.rowsPerHour, in: 1...300)
                        .fixedSize()
                }
                Text("Used by the AI panel to estimate how long your project will take. Adjust based on your typical pace for the stitch complexity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section("Counter Display") {
                Picker("Counter size", selection: Binding(
                    get: { settings.counterSize },
                    set: { settings.counterSize = $0 }
                )) {
                    ForEach(AppSettings.CounterSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section("Counter Controls") {
                shortcutRow("↑  or  R", "Increment row")
                shortcutRow("↓  or  r", "Decrement row")
                shortcutRow("→  or  S", "Increment stitch")
                shortcutRow("←  or  s", "Decrement stitch")
                shortcutRow("Space", "Increment stitch")
                shortcutRow("Return", "End row (always resets stitch)")
            }
            Section("App") {
                shortcutRow("⌘ ,", "Open Settings")
                shortcutRow("⌘ ⌫", "Reset all counters")
                shortcutRow("⌘ O", "Open pattern file")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ key: String, _ description: String) -> some View {
        HStack {
            Text(description)
            Spacer()
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
}
