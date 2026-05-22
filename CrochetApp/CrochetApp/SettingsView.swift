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
        .frame(width: 520, height: 440)
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
                LabeledContent("Rows per hour") {
                    Stepper("\(settings.rowsPerHour)", value: $settings.rowsPerHour, in: 1...300)
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
            Section("Counter Bar") {
                Toggle("Show session timer", isOn: $settings.showTimer)
            }

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

            Section("Counter Colors") {
                ColorPicker("Row counter", selection: Binding(
                    get: { settings.rowColor },
                    set: { settings.rowColor = $0 }
                ), supportsOpacity: false)

                ColorPicker("Stitch counter", selection: Binding(
                    get: { settings.stitchColor },
                    set: { settings.stitchColor = $0 }
                ), supportsOpacity: false)

                ColorPicker("Repeat counter", selection: Binding(
                    get: { settings.repeatColor },
                    set: { settings.repeatColor = $0 }
                ), supportsOpacity: false)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(AppSettings.colorPresets) { preset in
                            presetButton(preset)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .formStyle(.grouped)
    }

    private func presetButton(_ preset: AppSettings.ColorPreset) -> some View {
        let rowC    = Color(hex: preset.rowHex)    ?? .pink
        let stitchC = Color(hex: preset.stitchHex) ?? .purple
        let repeatC = Color(hex: preset.repeatHex) ?? .teal
        let isActive = settings.rowColorHex == preset.rowHex
                    && settings.stitchColorHex == preset.stitchHex

        return Button {
            settings.rowColorHex    = preset.rowHex
            settings.stitchColorHex = preset.stitchHex
            settings.repeatColorHex = preset.repeatHex
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4).fill(rowC).frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4).fill(stitchC).frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4).fill(repeatC).frame(width: 18, height: 18)
                }
                Text(preset.name)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isActive ? rowC.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? rowC.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help("Apply \(preset.name) preset")
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
                .background(Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
}
