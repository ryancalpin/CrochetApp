import Foundation

struct PatternEntry: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var bookmark: Data
    var lastOpened: Date
    var isPinned: Bool
    var rowCount: Int
    var stitchCount: Int
    var autoResetStitch: Bool

    // MARK: - Goals
    var rowGoal: Int?        // nil = no goal, no progress bar
    var stitchGoal: Int?     // nil = no auto-advance

    // MARK: - Annotations
    // Key: paragraph index (0-based order of <p> and <li> in rendered HTML)
    // Value: note text
    var annotations: [Int: String]

    init(url: URL) throws {
        self.id = UUID()
        self.displayName = url.deletingPathExtension().lastPathComponent
        // Prefer security-scoped bookmark (sandboxed builds); fall back to minimal (dev/unsigned builds).
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            self.bookmark = data
        } else {
            self.bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        self.lastOpened = Date()
        self.isPinned = false
        self.rowCount = 0
        self.stitchCount = 0
        self.autoResetStitch = true
        self.rowGoal = nil
        self.stitchGoal = nil
        self.annotations = [:]
    }

    func resolveURL() -> URL? {
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return url
        }
        return try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
