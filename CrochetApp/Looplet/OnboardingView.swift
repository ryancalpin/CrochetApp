import SwiftUI

/// First-launch welcome. A few panels covering the core idea; dismisses by setting
/// `AppSettings.hasSeenOnboarding`. macOS has no paged TabView, so paging is manual.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
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
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            panelView(panels[index])
                .id(index)
                .transition(.opacity)
            Spacer(minLength: 0)
            dots
            controls
        }
        #if os(macOS)
        .frame(width: 460, height: 440)
        #endif
        .background(Color.surface)
    }

    private func panelView(_ panel: Panel) -> some View {
        VStack(spacing: 28) {
            panelIcon(panel)
            VStack(spacing: 12) {
                Text(panel.title)
                    .font(.largeTitle).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(panel.detail)
                    .font(.title3)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
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
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.appAccent.opacity(0.14))
                    .frame(width: 104, height: 104)
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
                    .fill(i == index ? Color.appAccent : Color.textSecondary.opacity(0.25))
                    .frame(width: i == index ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: index)
            }
        }
        .padding(.bottom, 20)
    }

    private var controls: some View {
        HStack {
            Button("Skip") { finish() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
            Spacer()
            if index > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
                }
                .buttonStyle(.bordered)
            }
            Button(index == panels.count - 1 ? "Get Started" : "Next") {
                if index == panels.count - 1 { finish() }
                else { withAnimation(.easeInOut(duration: 0.2)) { index += 1 } }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .background(Color.surfaceRaised)
        // Tint buttons/links with the app's theme accent (otherwise borderedProminent
        // and .link fall back to the system/asset accent — purple — off-theme).
        .tint(Color.appAccent)
    }

    private func finish() {
        AppSettings.shared.hasSeenOnboarding = true
        dismiss()
    }
}
