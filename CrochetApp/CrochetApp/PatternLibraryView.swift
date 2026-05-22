import SwiftUI
import UniformTypeIdentifiers

struct PatternLibraryView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @ObservedObject private var settings = AppSettings.shared

    @State private var showFilePicker = false
    @State private var entryToRemove: PatternEntry? = nil
    @State private var importError: String? = nil
    @State private var isDragTargeted = false
    @State private var searchText = ""
    @State private var showYarnStash = true
    @State private var showAddYarn = false
    @State private var showAddTag = false
    @State private var tagTargetID: UUID? = nil

    private var accentColor: Color { settings.rowColor }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            searchBar

            if library.entries.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let pinned = filteredEntries(from: library.pinned)
                        let recent = filteredEntries(from: library.recent)

                        if !pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(pinned) { entry in entryRow(entry) }
                        }

                        sectionHeader(searchText.isEmpty ? "Recent" : "Results")
                        if recent.isEmpty {
                            Text(searchText.isEmpty ? "No recent patterns" : "No matches")
                                .font(.caption).foregroundColor(.secondary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                        } else {
                            ForEach(recent) { entry in entryRow(entry) }
                        }

                        yarnStashSection
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                .pdf, .text,
                UTType(filenameExtension: "md") ?? .text,
                UTType(filenameExtension: "markdown") ?? .text,
                .rtf, .plainText
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if let newID = library.add(url: url) { selectEntry(id: newID) }
                    else { importError = "Could not import \"\(url.lastPathComponent)\"." }
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: { Text(importError ?? "") }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    let allowedExt: Set<String> = ["md", "markdown", "txt", "text", "rtf", "pdf"]
                    guard allowedExt.contains(url.pathExtension.lowercased()) else {
                        DispatchQueue.main.async {
                            importError = "\"\(url.lastPathComponent)\" isn't a supported file type. Drop a Markdown, PDF, RTF, or text file."
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        if let newID = library.add(url: url) { selectEntry(id: newID) }
                    }
                }
            }
            return true
        }
        .overlay(alignment: .center) {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc").font(.system(size: 28)).foregroundColor(accentColor)
                            Text("Drop to add pattern").font(.callout).foregroundColor(accentColor)
                        }
                    )
                    .background(accentColor.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(8)
            }
        }
        .confirmationDialog(
            "Remove \"\(entryToRemove?.displayName ?? "")\" from library?",
            isPresented: Binding(get: { entryToRemove != nil }, set: { if !$0 { entryToRemove = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let e = entryToRemove { library.remove(entryID: e.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The file will not be deleted from disk.") }
        .sheet(isPresented: $showAddYarn) { AddYarnSheet(library: library) }
        .sheet(isPresented: $showAddTag) {
            if let id = tagTargetID, let entry = library.entries.first(where: { $0.id == id }) {
                AddTagSheet(entry: entry, library: library)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "doc.text").foregroundColor(accentColor)
            Text("Patterns").font(.headline).fontWeight(.bold)
            Spacer()
            Button { showFilePicker = true } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain).foregroundColor(accentColor).help("Add a pattern file")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.surfaceRaised)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.secondary)
            TextField("Search patterns or tags…", text: $searchText)
                .textFieldStyle(.plain).font(.system(size: 12))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.surfaceRaised)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Filtering

    private func filteredEntries(from list: [PatternEntry]) -> [PatternEntry] {
        guard !searchText.isEmpty else { return list }
        let q = searchText.lowercased()
        return list.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text").font(.system(size: 40)).foregroundColor(accentColor.opacity(0.4))
            Text("No Patterns Yet").font(.headline).foregroundColor(.secondary)
            Text("Click + or drag a file here.\nSupports Markdown, PDF, and plain text.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)
    }

    // MARK: - Entry row

    private func entryRow(_ entry: PatternEntry) -> some View {
        let isActive = library.activeEntryID == entry.id
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isActive ? accentColor : Color.clear)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundColor(.primary).lineLimit(1)

                    HStack {
                        Text(relativeDate(entry.lastOpened))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                        Spacer()
                        Text("R\(entry.rowCount) · S\(entry.stitchCount)")
                            .font(.system(size: 11))
                            .foregroundColor(isActive ? accentColor : .secondary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(isActive ? accentColor.opacity(0.12) : Color.surfaceRaised)
                            .cornerRadius(8)
                    }

                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(entry.tags, id: \.self) { tag in
                                    tagChip(tag, color: tagColor(tag))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .background(isActive ? accentColor.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { selectEntry(id: entry.id) }
            .contextMenu {
                Button(entry.isPinned ? "Unpin" : "Pin") { library.togglePin(entryID: entry.id) }
                Divider()
                Button("Add Tag…") {
                    tagTargetID = entry.id
                    showAddTag = true
                }
                if !entry.tags.isEmpty {
                    Menu("Remove Tag") {
                        ForEach(entry.tags, id: \.self) { tag in
                            Button(tag) { library.removeTag(tag, from: entry.id) }
                        }
                    }
                }
                Divider()
                Button("Export Notes…") { exportNotes(for: entry) }
                Divider()
                Button("Remove from Library", role: .destructive) { entryToRemove = entry }
            }
            Divider().padding(.leading, 13)
        }
    }

    private func tagChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Yarn stash section

    private var yarnStashSection: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showYarnStash.toggle() }
            } label: {
                HStack {
                    Image(systemName: "tray.full").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("YARN STASH")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        .tracking(0.8)
                    Spacer()
                    Text("\(library.yarnStash.count)").font(.system(size: 10)).foregroundColor(.secondary)
                    Image(systemName: showYarnStash ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showYarnStash {
                VStack(spacing: 0) {
                    ForEach(library.yarnStash) { yarn in
                        yarnRow(yarn)
                    }
                    Button {
                        showAddYarn = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle").font(.system(size: 11))
                            Text("Add yarn").font(.system(size: 11))
                        }
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func yarnRow(_ yarn: YarnEntry) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: yarn.colorHex) ?? .gray)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(yarn.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text("\(yarn.weight) · \(yarn.yardage) yds")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .contextMenu {
            Button("Remove", role: .destructive) { library.removeYarn(id: yarn.id) }
        }
    }

    // MARK: - Tag color assignment

    private static let tagPalette: [Color] = [
        Color(red: 0.71, green: 0.33, blue: 0.49),
        Color(red: 0.49, green: 0.30, blue: 0.80),
        Color(red: 0.18, green: 0.49, blue: 0.29),
        Color(red: 0.88, green: 0.38, blue: 0.13),
        Color(red: 0.00, green: 0.48, blue: 0.80),
    ]

    private func tagColor(_ tag: String) -> Color {
        let idx = abs(tag.hashValue) % Self.tagPalette.count
        return Self.tagPalette[idx]
    }

    // MARK: - Helpers

    private func selectEntry(id: UUID) {
        library.select(entryID: id)
        if let entry = library.entries.first(where: { $0.id == id }) {
            store.load(from: entry)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; return f
    }()

    private func relativeDate(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "Just now" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func exportNotes(for entry: PatternEntry) {
        var lines: [String] = []
        lines.append("# Notes — \(entry.displayName)")
        lines.append("Exported \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))")
        lines.append("")
        lines.append("**Progress:** Row \(entry.rowCount)\(entry.rowGoal.map { " / \($0)" } ?? "") · Stitch \(entry.stitchCount)")
        if !entry.tags.isEmpty { lines.append("**Tags:** \(entry.tags.joined(separator: ", "))") }
        lines.append("")
        if entry.annotations.isEmpty {
            lines.append("No notes recorded.")
        } else {
            lines.append("## Notes")
            for (key, note) in entry.annotations.sorted(by: { $0.key < $1.key }) {
                lines.append("- **\"\(key.prefix(50))...\"** — \(note)")
            }
        }
        let content = lines.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.title = "Export Notes"
        panel.nameFieldStringValue = "\(entry.displayName) Notes.md"
        panel.allowedContentTypes = [.text, UTType(filenameExtension: "md") ?? .text]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Add Tag Sheet

struct AddTagSheet: View {
    let entry: PatternEntry
    @ObservedObject var library: PatternLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var tagText = ""
    @FocusState private var focused: Bool

    private let suggestions = ["hat", "blanket", "shawl", "amigurumi", "accessories", "baby", "cardigan", "socks", "advanced", "beginner", "intermediate"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Tag to \"\(entry.displayName)\"").font(.headline)
            TextField("e.g. hat, blanket, advanced…", text: $tagText)
                .textFieldStyle(.roundedBorder).focused($focused).onSubmit { save() }
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggestions:").font(.caption).foregroundColor(.secondary)
                FlowLayout(spacing: 4) {
                    ForEach(suggestions.filter { !entry.tags.contains($0) }, id: \.self) { s in
                        Button(s) { tagText = s }
                            .buttonStyle(.bordered).controlSize(.mini)
                    }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Add") { save() }.buttonStyle(.borderedProminent).disabled(tagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20).frame(width: 300)
        .onAppear { focused = true }
    }

    private func save() {
        library.addTag(tagText, to: entry.id)
        dismiss()
    }
}

// MARK: - Add Yarn Sheet

struct AddYarnSheet: View {
    @ObservedObject var library: PatternLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var weight = "Worsted"
    @State private var colorHex = "#9B8ED4"
    @State private var yardage = ""
    @FocusState private var focused: Bool

    private let weights = ["Fingering", "Sport", "DK", "Worsted", "Aran", "Bulky", "Super Bulky"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Yarn Stash").font(.headline)
            TextField("Yarn name", text: $name).textFieldStyle(.roundedBorder).focused($focused)
            Picker("Weight", selection: $weight) {
                ForEach(weights, id: \.self) { Text($0).tag($0) }
            }
            HStack {
                TextField("Color hex (e.g. #9B8ED4)", text: $colorHex).textFieldStyle(.roundedBorder)
                Circle().fill(Color(hex: colorHex) ?? .gray).frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
            }
            TextField("Yardage (optional)", text: $yardage).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Add") { save() }.buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20).frame(width: 320)
        .onAppear { focused = true }
    }

    private func save() {
        let yarn = YarnEntry(
            name: name.trimmingCharacters(in: .whitespaces),
            weight: weight,
            colorHex: colorHex.isEmpty ? "#888888" : colorHex,
            yardage: Int(yardage) ?? 0
        )
        library.addYarn(yarn)
        dismiss()
    }
}

// MARK: - FlowLayout (for tag suggestions)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? 0,
            height: rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? CGFloat.infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxWidth && !rows.last!.isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows.filter { !$0.isEmpty }
    }
}

