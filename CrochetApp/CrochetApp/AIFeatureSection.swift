import SwiftUI

/// A disclosure section used in the AI panel. Shows a spinner while loading
/// and a Regenerate button that re-runs inference for this feature.
struct AIFeatureSection<Content: View>: View {
    let title: String
    let isLoading: Bool
    let onRegenerate: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Group {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Generating…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    content()
                        .padding(.top, 4)
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if !isLoading {
                    Button {
                        onRegenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate this section")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
