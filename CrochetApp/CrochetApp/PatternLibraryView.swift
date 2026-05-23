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
    @State private var renameTarget: PatternEntry? = nil
    @State private var renameText: String = ""
    @State private var sidebarTab: SidebarTab = .patterns
    @State private var hoveredEntryID: UUID? = nil

    @Environment(\.colorScheme) private var colorScheme

    enum SidebarTab: String, CaseIterable { case patterns = "Patterns", yarn = "Yarn" }

    private var accentColor: Color { settings.rowColor }
    private var legibleAccent: Color { accentColor.legible(in: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            tabPicker

            switch sidebarTab {
            case .patterns: patternsContent
            case .yarn: yarnContent
            }
        }
        .background(Color.surfaceSidebar)
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
            if isDragTargeted && sidebarTab == .patterns {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(legibleAccent, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 32))
                                .foregroundColor(legibleAccent)
                            Text("Drop to add pattern")
                                .font(.callout)
                                .foregroundColor(legibleAccent)
                        }
                    )
                    .background(legibleAccent.opacity(0.05))
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
        .sheet(item: $renameTarget) { entry in
            RenameSheet(entry: entry, text: $renameText, library: library)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: sidebarTab == .yarn ? "tray.full" : "doc.text")
                .foregroundColor(legibleAccent)
            Text("Library").font(.system(.headline))
            Spacer()
            Button {
                if sidebarTab == .yarn { showAddYarn = true } else { showFilePicker = true }
            } label: {
                Image(systemName: "plus").font(.system(.body, weight: .medium))
            }
            .buttonStyle(.plain).foregroundColor(legibleAccent)
            .help(sidebarTab == .yarn ? "Add yarn to stash" : "Add a pattern file")
            .accessibilityLabel(sidebarTab == .yarn ? "Add yarn" : "Add pattern")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.surfaceSidebar)
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        Picker("", selection: $sidebarTab) {
            ForEach(SidebarTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.surfaceSidebar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Patterns content

    private var patternsContent: some View {
        VStack(spacing: 0) {
            searchBar

            if library.entries.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        let pinned = filteredEntries(from: library.pinned)
                        let recent = filteredEntries(from: library.recent)

                        if !pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(pinned) { entry in entryRow(entry) }
                        }

                        sectionHeader(searchText.isEmpty ? "Recent" : "Results")
                        if recent.isEmpty {
                            Text(searchText.isEmpty ? "No recent patterns" : "No matches")
                                .font(Typo.metadata).foregroundColor(.textSecondary)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                        } else {
                            ForEach(recent) { entry in entryRow(entry) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Yarn content

    @ViewBuilder
    private var yarnContent: some View {
        if library.yarnStash.isEmpty {
            yarnEmptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    yarnStashSection
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var yarnEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.full")
                .font(.system(size: 36))
                .foregroundColor(.textSecondary.opacity(0.4))
            VStack(spacing: 6) {
                Text("No Yarn Yet")
                    .font(.headline).foregroundColor(.textSecondary)
                Text("Track your stash here.\nTap + to add a skein.")
                    .font(.callout).foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showAddYarn = true
            } label: {
                Label("Add Yarn", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.callout).foregroundColor(.textSecondary)
            TextField("Search patterns or tags…", text: $searchText)
                .textFieldStyle(.plain).font(.callout)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.callout).foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.surfaceSidebar)
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
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(.textSecondary.opacity(0.4))
            VStack(spacing: 6) {
                Text("No Patterns Yet")
                    .font(.headline).foregroundColor(.textSecondary)
                Text("Click + or drag a file here.\nSupports Markdown, PDF, and plain text.")
                    .font(.callout).foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Typo.sectionLabel).foregroundColor(.textSecondary)
            .tracking(0.6)
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
    }

    // MARK: - Entry row

    private func entryRow(_ entry: PatternEntry) -> some View {
        let isActive = library.activeEntryID == entry.id
        let isHovered = hoveredEntryID == entry.id
        let rowBackground: Color = {
            if isActive { return legibleAccent.opacity(0.15) }
            if isHovered { return Color.textSecondary.opacity(0.08) }
            return .clear
        }()
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.text")
                .font(.body)
                .foregroundColor(isActive ? legibleAccent : .textSecondary)
                .frame(width: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(Typo.rowTitle)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1).truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(relativeDate(entry.lastOpened))
                        .font(Typo.metadata).foregroundColor(.textSecondary)
                    Spacer(minLength: 4)
                    Text("R\(entry.rowCount) · S\(entry.stitchCount)")
                        .font(Typo.metadata)
                        .foregroundColor(isActive ? legibleAccent : .textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(isActive ? legibleAccent.opacity(0.15) : Color.surfaceRaised)
                        .cornerRadius(6)
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
        }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .onHover { hovering in hoveredEntryID = hovering ? entry.id : (hoveredEntryID == entry.id ? nil : hoveredEntryID) }
            .onTapGesture { selectEntry(id: entry.id) }
            .contextMenu {
                Button(entry.isPinned ? "Unpin" : "Pin") { library.togglePin(entryID: entry.id) }
                Button("Rename…") {
                    renameText = entry.displayName
                    renameTarget = entry
                }
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
                Button("Export Insights…") { PatternExporter.exportToFile(entry) }
                Button("Export Notes…") { exportNotes(for: entry) }
                Divider()
                Button("Remove from Library", role: .destructive) { entryToRemove = entry }
            }
    }

    private func tagChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(Typo.chip)
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Yarn stash section

    private var yarnStashSection: some View {
        VStack(spacing: 2) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showYarnStash.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tray.full").font(.caption).foregroundColor(.textSecondary)
                    Text("YARN STASH")
                        .font(Typo.sectionLabel).foregroundColor(.textSecondary)
                        .tracking(0.6)
                    Spacer()
                    Text("\(library.yarnStash.count)").font(Typo.metadata).foregroundColor(.textSecondary)
                    Image(systemName: showYarnStash ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showYarnStash {
                VStack(spacing: 2) {
                    ForEach(library.yarnStash) { yarn in
                        yarnRow(yarn)
                    }
                    Button {
                        showAddYarn = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle").font(.callout)
                            Text("Add yarn").font(.callout)
                        }
                        .foregroundColor(legibleAccent)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func yarnRow(_ yarn: YarnEntry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: yarn.colorHex) ?? .gray)
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(yarn.name).font(Typo.rowTitle).foregroundColor(.textPrimary).lineLimit(1)
                Text("\(yarn.weight) · \(yarn.yardage) yds")
                    .font(Typo.metadata).foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
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

// MARK: - Rename Sheet

struct RenameSheet: View {
    let entry: PatternEntry
    @Binding var text: String
    @ObservedObject var library: PatternLibrary
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename Pattern").font(.headline)
            TextField("Pattern name", text: $text)
                .textFieldStyle(.roundedBorder).focused($focused).onSubmit { save() }
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20).frame(width: 300)
        .onAppear { focused = true }
    }

    private func save() {
        library.rename(entryID: entry.id, to: text)
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

