import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var proStore = ProStore.shared
    @State private var showPaywall = false

    var body: some View {
        TabView {
            ScrollView { countingTab.padding(.bottom, 16) }
                .tabItem { Label("Counting", systemImage: "list.number") }
            ScrollView { paceTab.padding(.bottom, 16) }
                .tabItem { Label("Pace & AI", systemImage: "sparkles") }
            ScrollView { appearanceTab.padding(.bottom, 16) }
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            ScrollView { aboutTab.padding(.bottom, 16) }
                .tabItem { Label("About", systemImage: "info.circle") }
            ScrollView { shortcutsTab.padding(.bottom, 16) }
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 460)
        .sheet(isPresented: $showPaywall) { PaywallView() }
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
            Section("Appearance") {
                Picker("Appearance", selection: Binding(
                    get: { settings.appearanceMode },
                    set: { settings.appearanceMode = $0 }
                )) {
                    ForEach(AppSettings.AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("App Theme") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                    ForEach(AppTheme.allCases) { theme in
                        let locked = !proStore.isPro && !Pro.freeThemes.contains(theme)
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 28, height: 28)
                                if settings.appTheme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .opacity(locked ? 0.55 : 1)
                            .overlay(
                                Circle().strokeBorder(
                                    Color.appAccent,
                                    lineWidth: settings.appTheme == theme ? 3 : 0
                                )
                            )
                            Text(theme.label)
                                .font(.caption)
                                .foregroundColor(settings.appTheme == theme ? .primary : .secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if locked { showPaywall = true } else { settings.appTheme = theme }
                        }
                        .help(locked ? "\(theme.label) is a Pro theme" : "Use the \(theme.label) theme")
                        .accessibilityLabel("\(theme.label) theme")
                        .accessibilityAddTraits(settings.appTheme == theme ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                Text("Sets the app's accent and palette for chrome (selection, buttons, links, AI, and the document). Counter pills coordinate with the theme by default — customize them below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
                if proStore.isPro {
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

                    HStack {
                        Text(settings.counterColorsCustomized
                             ? "Using custom colors."
                             : "Pills follow the \(settings.appTheme.label) theme.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Match Theme") { settings.resetCounterColorsToTheme() }
                            .controlSize(.small)
                            .disabled(!settings.counterColorsCustomized)
                            .help("Reset the counter pills to this theme's coordinated colors")
                    }
                    .padding(.top, 2)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Counter pills follow the \(settings.appTheme.label) theme.")
                            Text("Unlock Pro to set custom counter colors.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Unlock") { showPaywall = true }
                            .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About / Pro / Feedback

    private var aboutTab: some View {
        Form {
            Section("Looplet Pro") {
                if proStore.isPro {
                    Label("Pro unlocked — thank you!", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock AI insights, iCloud sync, unlimited patterns, and all themes with a one-time purchase.")
                            .font(.callout).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Unlock Looplet Pro") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                            Button("Restore Purchase") { Task { await proStore.restore() } }
                        }
                    }
                }
            }

            Section("Feedback") {
                Button {
                    if let url = URL(string: AppSettings.feedbackURLString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Send Feedback & Suggestions…", systemImage: "paperplane")
                }
                Text("Found a bug or have an idea? We'd love to hear it.")
                    .font(.caption).foregroundColor(.secondary)
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
                shortcutRow("⌃⌘F", "Toggle Focus Mode")
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
