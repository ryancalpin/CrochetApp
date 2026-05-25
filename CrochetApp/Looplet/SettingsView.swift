import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var proStore = ProStore.shared
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    /// Platform-appropriate gesture name for overriding per-pattern goals.
    private static let perPatternGoalHint: String = {
        #if os(macOS)
        return "These are applied when adding a new pattern. You can override them per-pattern by right-clicking a counter."
        #else
        return "These are applied when adding a new pattern. You can override them per-pattern by touching and holding a counter."
        #endif
    }()

    // iOS only: which section is shown (replaces TabView, broken in sheets on iOS 26).
    #if os(iOS)
    @State private var settingsSection = 0
    #endif

    var body: some View {
        #if os(macOS)
        settingsTabs
            .frame(width: 520, height: 460)
            .sheet(isPresented: $showPaywall) { PaywallView() }
        #else
        // iOS 26 regression: TabView inside any sheet container gives tab content
        // height=0 (confirmed via AX snapshot). Avoid TabView entirely on iOS.
        // Use a plain VStack with a manual title bar + segmented icon picker instead.
        VStack(spacing: 0) {
            // ── Title bar ──────────────────────────────────────────────────
            ZStack {
                Text("Settings").font(.headline)
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }.bold()
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .overlay(alignment: .bottom) { Divider() }

            // ── Section picker (icon + label tabs, per the design) ─────────
            sectionTabs
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGroupedBackground))

            Divider()

            // ── Selected section content ────────────────────────────────────
            // Each tab is a Form.formStyle(.grouped) — a List-backed view.
            // Lists collapse to height=0 inside ScrollView, so we show the
            // Form directly and let it fill + scroll within its own frame.
            Group {
                switch settingsSection {
                case 1:  paceTab
                case 2:  appearanceTab
                case 3:  aboutTab
                default: countingTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        #endif
    }

    #if os(iOS)
    private struct SectionTab { let icon: String; let label: String }
    private var sectionList: [SectionTab] {
        [
            .init(icon: "list.number", label: "Counting"),
            .init(icon: "sparkles", label: "Pace & AI"),
            .init(icon: "paintbrush", label: "Appearance"),
            .init(icon: "info.circle", label: "About"),
        ]
    }

    /// Icon-over-label segmented tabs (accent tile when active), matching the design.
    private var sectionTabs: some View {
        HStack(spacing: 6) {
            ForEach(Array(sectionList.enumerated()), id: \.offset) { idx, tab in
                let active = settingsSection == idx
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { settingsSection = idx }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon).font(.system(size: 17))
                        Text(tab.label)
                            .font(.system(size: 10, weight: active ? .semibold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .foregroundColor(active ? Color.appAccent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        active ? Color.appAccent.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(active ? Color.appAccent.opacity(0.25) : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    #endif

    // iOS 26 changed TabView rendering: the old `.tabItem` API gives height=0 content
    // when TabView is inside NavigationStack inside a Sheet. The new Tab {} API (iOS 18+)
    // fixes this. The old API is kept as a fallback for iOS 17 devices.
    @ViewBuilder
    private var settingsTabs: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            TabView {
                Tab("Counting", systemImage: "list.number") {
                    ScrollView { countingTab.padding(.bottom, 16) }
                }
                Tab("Pace & AI", systemImage: "sparkles") {
                    ScrollView { paceTab.padding(.bottom, 16) }
                }
                Tab("Appearance", systemImage: "paintbrush") {
                    ScrollView { appearanceTab.padding(.bottom, 16) }
                }
                Tab("About", systemImage: "info.circle") {
                    ScrollView { aboutTab.padding(.bottom, 16) }
                }
                #if os(macOS)
                Tab("Shortcuts", systemImage: "keyboard") {
                    ScrollView { shortcutsTab.padding(.bottom, 16) }
                }
                #endif
            }
        } else {
            // iOS 17 / macOS 13-14 fallback
            TabView {
                ScrollView { countingTab.padding(.bottom, 16) }
                    .tabItem { Label("Counting", systemImage: "list.number") }
                ScrollView { paceTab.padding(.bottom, 16) }
                    .tabItem { Label("Pace & AI", systemImage: "sparkles") }
                ScrollView { appearanceTab.padding(.bottom, 16) }
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                ScrollView { aboutTab.padding(.bottom, 16) }
                    .tabItem { Label("About", systemImage: "info.circle") }
                #if os(macOS)
                ScrollView { shortcutsTab.padding(.bottom, 16) }
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                #endif
            }
        }
    }

    // MARK: - Counting

    private var countingTab: some View {
        Form {
            Section("Row Behavior") {
                Toggle("Auto-reset stitches when incrementing row", isOn: $settings.autoResetStitches)
                    .help("When on, pressing + on ROW resets the stitch counter to 0.")
            }
            Section("Counter Sounds") {
                Toggle("Play counter sounds", isOn: $settings.audioCueEnabled)
                if settings.audioCueEnabled {
                    soundPicker("Row +",    get: { settings.rowUpSound },     set: { settings.rowUpSound = $0 })
                    soundPicker("Row −",    get: { settings.rowDownSound },   set: { settings.rowDownSound = $0 })
                    soundPicker("Stitch +", get: { settings.stitchUpSound },  set: { settings.stitchUpSound = $0 })
                    soundPicker("Stitch −", get: { settings.stitchDownSound }, set: { settings.stitchDownSound = $0 })
                    Text("Pick a sound for each action. Selecting one plays a preview.")
                        .font(.caption).foregroundColor(.secondary)
                }
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
                Text(Self.perPatternGoalHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// A sound picker that previews the chosen sound on selection.
    private func soundPicker(_ label: String,
                             get: @escaping () -> SoundEffect,
                             set: @escaping (SoundEffect) -> Void) -> some View {
        Picker(label, selection: Binding(get: get, set: { newValue in
            set(newValue)
            newValue.play()
        })) {
            ForEach(SoundEffect.allCases) { effect in
                Text(effect.label).tag(effect)
            }
        }
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
                                    .frame(width: 44, height: 44)
                                if settings.appTheme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                } else if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .opacity(locked ? 0.55 : 1)
                            .overlay {
                                if settings.appTheme == theme {
                                    Circle()
                                        .strokeBorder(theme.accentColor, lineWidth: 2.5)
                                        .padding(-4)
                                }
                            }
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
                        openExternalURL(url)
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

    // MARK: - Shortcuts (macOS hardware-keyboard reference)

    #if os(macOS)
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
    #endif
}
