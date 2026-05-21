import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            ScrollView { countingTab.padding(.bottom, 16) }
                .tabItem { Label("Counting", systemImage: "list.number") }
            ScrollView { paceTab.padding(.bottom, 16) }
                .tabItem { Label("Pace & AI", systemImage: "sparkles") }
            ScrollView { appearanceTab.padding(.bottom, 16) }
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            ScrollView { shortcutsTab.padding(.bottom, 16) }
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 400)
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
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Stitch goal")
                    Spacer()
                    TextField("None", value: $settings.defaultStitchGoal, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                }
                Text("These are applied when adding a new pattern. You can override them per-pattern via right-click on a counter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    Stepper("\(settings.rowsPerHour) rows/hr", value: $settings.rowsPerHour, in: 1...300)
                        .fixedSize()
                }
                Text("Used by the AI panel to estimate how long your project will take. Adjust based on your typical pace for the current stitch complexity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section("Counter Display Size") {
                Picker("Size", selection: Binding(
                    get: { settings.counterSize },
                    set: { settings.counterSize = $0 }
                )) {
                    ForEach(AppSettings.CounterSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Color Scheme") {
                HStack(spacing: 10) {
                    ForEach(AppSettings.PillColorScheme.allCases, id: \.self) { scheme in
                        colorSwatch(scheme)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }

    private func colorSwatch(_ scheme: AppSettings.PillColorScheme) -> some View {
        let isSelected = settings.pillColorScheme == scheme
        return Button {
            settings.pillColorScheme = scheme
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scheme.rowColor)
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scheme.stitchColor)
                        .frame(width: 24, height: 24)
                }
                Text(scheme.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(7)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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
