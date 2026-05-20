import SwiftUI
import UniformTypeIdentifiers

struct PatternLibraryView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @State private var showFilePicker = false
    @State private var entryToRemove: PatternEntry? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.pink)
                Text("Patterns")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.pink)
                .help("Add a pattern file")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if library.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !library.pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(library.pinned) { entry in
                                entryRow(entry)
                            }
                        }
                        sectionHeader("Recent")
                        if library.recent.isEmpty {
                            Text("No recent patterns")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(library.recent) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType.text,
                UTType(filenameExtension: "md") ?? .text,
                UTType(filenameExtension: "markdown") ?? .text
            ],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if let newID = library.add(url: url) {
                    selectEntry(id: newID)
                }
            }
        }
        .confirmationDialog(
            "Remove \"\(entryToRemove?.displayName ?? "")\" from library?",
            isPresented: Binding(
                get: { entryToRemove != nil },
                set: { if !$0 { entryToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let e = entryToRemove { library.remove(entryID: e.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The file will not be deleted from disk.")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.pink.opacity(0.4))
            Text("No Patterns Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Click + to add a Markdown pattern file.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func entryRow(_ entry: PatternEntry) -> some View {
        let isActive = library.activeEntryID == entry.id
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Active indicator
                Rectangle()
                    .fill(isActive ? Color.pink : Color.clear)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack {
                        Text(relativeDate(entry.lastOpened))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("R\(entry.rowCount) · S\(entry.stitchCount)")
                            .font(.system(size: 11))
                            .foregroundColor(isActive ? .pink : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(isActive ? Color.pink.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(isActive ? Color.pink.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { selectEntry(id: entry.id) }
            .contextMenu {
                Button(entry.isPinned ? "Unpin" : "Pin") {
                    library.togglePin(entryID: entry.id)
                }
                Divider()
                Button("Remove from Library", role: .destructive) {
                    entryToRemove = entry
                }
            }
            Divider().padding(.leading, 13)
        }
    }

    // MARK: - Helpers

    private func selectEntry(id: UUID) {
        library.select(entryID: id)
        if let entry = library.entries.first(where: { $0.id == id }) {
            store.load(from: entry)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func relativeDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
