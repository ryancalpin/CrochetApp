import SwiftUI

/// Floating counter cluster used in Focus mode. Caller supplies the pills.
struct GlassHUD<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.dividerToken, lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}
