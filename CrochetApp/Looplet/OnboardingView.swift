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
    }

    private let panels: [Panel] = [
        .init(icon: "square.stack.3d.up.fill",
              title: "Welcome to Looplet",
              detail: "Your crochet companion — keep your patterns, counts, and yarn stash in one calm place."),
        .init(icon: "arrow.down.doc.fill",
              title: "Bring in a Pattern",
              detail: "Click the ＋ in the sidebar or drag a file in. Markdown, PDF, and plain text all work."),
        .init(icon: "number.circle.fill",
              title: "Count as You Stitch",
              detail: "Tap the Row and Stitch pills, set goals, and use ↑ ↓ ← → or R/S keys to keep your hands on your hook."),
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
        .frame(width: 460, height: 440)
        .background(Color.surface)
    }

    private func panelView(_ panel: Panel) -> some View {
        VStack(spacing: 20) {
            Image(systemName: panel.icon)
                .font(.system(size: 64))
                .foregroundColor(Color.appAccent)
                .symbolRenderingMode(.hierarchical)
            Text(panel.title)
                .font(.title).fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(panel.detail)
                .font(.title3)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(panels.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.appAccent : Color.textSecondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 16)
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
