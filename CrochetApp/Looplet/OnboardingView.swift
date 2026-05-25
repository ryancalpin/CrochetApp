import SwiftUI

/// First-launch welcome. A few panels covering the core idea; dismisses by setting
/// `AppSettings.hasSeenOnboarding`. macOS has no paged TabView, so paging is manual.
///
/// Visual treatment matches the Looplet iOS design: a dusk gradient backdrop with two
/// ambient glow orbs, the real app icon on the welcome panel (glow + accent ring), and
/// tinted SF-Symbol tiles on the value-prop panels. Colors are theme-derived so the
/// screen stays coordinated under any of the 8 themes (default Plum matches the mock).
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var index = 0

    private struct Panel: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        /// First panel shows the real app icon instead of an SF Symbol tile.
        var useAppIcon: Bool = false
    }

    private let panels: [Panel] = [
        .init(icon: "square.stack.3d.up.fill",
              title: "Welcome to Looplet",
              detail: "Your crochet companion — keep your patterns, counts, and yarn stash in one calm place.",
              useAppIcon: true),
        .init(icon: "arrow.down.doc.fill",
              title: "Bring in a Pattern",
              detail: "Tap ＋ or drag a file in. Markdown, PDF, and plain text all work — or start with the built-in sample."),
        .init(icon: "number.circle.fill",
              title: "Count as You Stitch",
              detail: "Tap the Row and Stitch pills, set goals, and keep a steady rhythm without losing your place."),
        .init(icon: "sparkles",
              title: "AI Insights",
              detail: "Looplet Pro reads your pattern for a summary, abbreviations, materials, and answers your questions.")
    ]

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                panelView(panels[index])
                    .id(index)
                    .transition(.opacity)
                Spacer(minLength: 0)
                dots
                controls
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 460)
        #endif
    }

    // MARK: - Background (dusk gradient + ambient orbs)

    private var background: some View {
        ZStack {
            // Deep dusk base — darkest at top, easing into the theme surface.
            LinearGradient(
                colors: [Color.surfaceSidebar, Color.surface],
                startPoint: UnitPoint(x: 0.15, y: 0),
                endPoint: UnitPoint(x: 0.85, y: 1)
            )

            // Purple ambient orb, top-left.
            Circle()
                .fill(RadialGradient(
                    colors: [Color.appAccent.opacity(0.18), .clear],
                    center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 380, height: 380)
                .offset(x: -120, y: -300)

            // Rose ambient orb, bottom-right (uses the row counter hue).
            Circle()
                .fill(RadialGradient(
                    colors: [settings.rowColor.opacity(0.13), .clear],
                    center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: 150)
        }
    }

    // MARK: - Panel

    private func panelView(_ panel: Panel) -> some View {
        VStack(spacing: 30) {
            panelIcon(panel)
            VStack(spacing: 14) {
                Text(panel.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                Text(panel.detail)
                    .font(.system(size: 17))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func panelIcon(_ panel: Panel) -> some View {
        if panel.useAppIcon {
            Image("BrandIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.appAccent.opacity(0.5), radius: 32, x: 0, y: 22)
                .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.30), lineWidth: 1.5)
                        .padding(-3)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.appAccent.opacity(0.14))
                    .frame(width: 104, height: 104)
                    .shadow(color: Color.appAccent.opacity(0.20), radius: 32, x: 0, y: 8)
                Image(systemName: panel.icon)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(Color.appAccent)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(panels.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.appAccent : Color.white.opacity(0.18))
                    .frame(width: i == index ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: index)
            }
        }
        .padding(.bottom, 22)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button { finish() } label: {
                Text("Skip")
                    .font(.system(size: 17))
                    .foregroundColor(Color.appAccent)
            }
            .buttonStyle(.plain)

            Spacer()

            if index > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
                } label: {
                    Text("Back")
                        .font(.system(size: 17))
                        .foregroundColor(Color.appAccent)
                        .padding(.vertical, 12).padding(.horizontal, 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Button {
                if index == panels.count - 1 { finish() }
                else { withAnimation(.easeInOut(duration: 0.2)) { index += 1 } }
            } label: {
                Text(index == panels.count - 1 ? "Get Started" : "Next")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 13).padding(.horizontal, index == panels.count - 1 ? 28 : 34)
                    .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .background(
            Color.surfaceRaised
                .overlay(alignment: .top) { Divider().background(Color.dividerToken) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func finish() {
        AppSettings.shared.hasSeenOnboarding = true
        dismiss()
    }
}
