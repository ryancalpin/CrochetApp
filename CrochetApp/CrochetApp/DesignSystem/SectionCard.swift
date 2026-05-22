import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let isLoading: Bool
    let onRegenerate: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Group {
                if isLoading {
                    HStack { ProgressView().scaleEffect(0.7); Text("Generating…").font(Typo.metadata).foregroundColor(.textSecondary) }
                        .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    content().padding(.top, 4)
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Text(title).font(Typo.sectionTitle).foregroundColor(.textPrimary)
                Spacer()
                if !isLoading, let onRegenerate {
                    Button(action: onRegenerate) {
                        Image(systemName: "arrow.clockwise").imageScale(.small).foregroundColor(.textSecondary)
                    }.buttonStyle(.plain).help("Regenerate this section")
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }
}
