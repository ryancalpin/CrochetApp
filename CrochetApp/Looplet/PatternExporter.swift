import AppKit
import UniformTypeIdentifiers

/// Builds and exports a Markdown document combining a pattern's metadata, its
/// persisted AI insights, the user's notes, and the raw pattern text. Reads only
/// already-stored data — it never triggers AI generation.
enum PatternExporter {

    // MARK: - Markdown generation

    /// Build a Markdown document combining the pattern's metadata, AI insights, and notes.
    /// Sections whose data is nil/empty are omitted; never crashes on missing insights.
    static func markdown(for entry: PatternEntry) -> String {
        var out: [String] = []

        out.append("# \(entry.displayName)")
        out.append("")

        // MARK: Metadata block (one line per known field)
        var meta: [String] = []
        if let s = entry.aiSummary {
            if !s.skillLevel.isEmpty { meta.append("**Skill Level:** \(s.skillLevel)") }
            if !s.materials.isEmpty { meta.append("**Materials:** \(s.materials)") }
            if !s.totalRows.isEmpty { meta.append("**Total Rows:** \(s.totalRows)") }
            if !s.estimatedTime.isEmpty { meta.append("**Estimated Time:** \(s.estimatedTime)") }
            if !s.keyStitches.isEmpty { meta.append("**Key Stitches:** \(s.keyStitches)") }
        }
        if let difficulty = entry.aiDifficulty, !difficulty.isEmpty {
            meta.append("**Difficulty:** \(difficulty)")
        }
        if let estimate = entry.aiTimeEstimate, !estimate.isEmpty {
            meta.append("**Time Remaining:** \(estimate)")
        }
        meta.append("**Progress:** Row \(entry.rowCount)\(entry.rowGoal.map { " / \($0)" } ?? "") · Stitch \(entry.stitchCount)")
        if !entry.tags.isEmpty {
            meta.append("**Tags:** \(entry.tags.joined(separator: ", "))")
        }
        if !meta.isEmpty {
            out.append(contentsOf: meta)
            out.append("")
        }

        // MARK: Materials breakdown
        if let m = entry.aiMaterials {
            var lines: [String] = []
            if !m.yarn.isEmpty { lines.append("- Yarn: \(m.yarn)") }
            if !m.hook.isEmpty { lines.append("- Hook: \(m.hook)") }
            if !m.notions.isEmpty { lines.append("- Notions: \(m.notions)") }
            if !lines.isEmpty {
                out.append("## Materials")
                out.append(contentsOf: lines)
                out.append("")
            }
        }

        // MARK: Abbreviations
        if let abbr = entry.aiAbbreviations, !abbr.entries.isEmpty {
            let conv = abbr.convention.isEmpty ? "" : " (\(abbr.convention))"
            out.append("## Abbreviations\(conv)")
            for e in abbr.entries {
                out.append("- **\(e.abbreviation)** — \(e.meaning)")
            }
            out.append("")
        }

        // MARK: Notes (user annotations)
        if !entry.annotations.isEmpty {
            out.append("## Notes")
            for (_, note) in entry.annotations.sorted(by: { $0.key < $1.key }) {
                out.append("- \(note)")
            }
            out.append("")
        }

        // MARK: Pattern text (read with balanced security scope)
        out.append("## Pattern")
        out.append(patternText(for: entry))
        out.append("")

        return out.joined(separator: "\n")
    }

    /// Read the full pattern text via the entry's bookmark, holding the security scope
    /// only for the duration of the read. Returns a placeholder if it can't be read.
    private static func patternText(for entry: PatternEntry) -> String {
        guard let url = entry.resolveURL() else { return "_(pattern file unavailable)_" }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "_(pattern file unavailable)_"
        }
        return text
    }

    // MARK: - Export to file

    /// Present an NSSavePanel to save the markdown as a .md file.
    @MainActor static func exportToFile(_ entry: PatternEntry) {
        let content = markdown(for: entry)
        let panel = NSSavePanel()
        panel.title = "Export Pattern Insights"
        panel.nameFieldStringValue = "\(entry.displayName).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSLog("PatternExporter: failed to write export to \(url.path): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Share sheet

    /// Present the macOS share sheet anchored to a view, sharing the markdown text.
    /// When `view` is nil, anchors to the key window's content view.
    @MainActor static func share(_ entry: PatternEntry, from view: NSView?) {
        let content = markdown(for: entry)
        let picker = NSSharingServicePicker(items: [content])
        // Anchor: prefer the provided view; otherwise fall back to the key window's
        // content view. (No view ref is passed from the SwiftUI menus, so this anchors
        // to the window's content view with a small rect near the top-trailing corner.)
        guard let anchor = view ?? NSApp.keyWindow?.contentView else {
            NSLog("PatternExporter: no view available to anchor share sheet")
            return
        }
        let bounds = anchor.bounds
        let rect = NSRect(x: bounds.maxX - 1, y: bounds.maxY - 1, width: 1, height: 1)
        picker.show(relativeTo: rect, of: anchor, preferredEdge: .minY)
    }
}
