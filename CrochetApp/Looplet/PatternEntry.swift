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
    var repeatCount: Int
    var showRepeatCounter: Bool

    // MARK: - Goals
    var rowGoal: Int?
    var stitchGoal: Int?

    // MARK: - Tags
    var tags: [String]

    // MARK: - Annotations
    // Key: first 64 chars of block text (fingerprint) — stable across paragraph index changes
    var annotations: [String: String]

    // MARK: - AI Cache
    /// Bump when the AI generation logic changes so stale cached insights are
    /// invalidated and regenerated. v1 = FoundationModels guided generation
    /// (replaced the old free-text parsing that produced "Unknown" fields).
    static let currentAISchemaVersion = 1

    var aiSummary: PatternSummary?
    var aiAbbreviations: AbbreviationList?
    var aiMaterials: MaterialsBreakdown?
    var aiDifficulty: String?
    var aiTimeEstimate: String?
    /// Schema version that produced the cached AI insights above (0 = legacy/unknown).
    var aiSchemaVersion: Int

    init(url: URL) throws {
        self.id = UUID()
        self.displayName = url.deletingPathExtension().lastPathComponent
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
        self.repeatCount = 0
        self.showRepeatCounter = false
        self.rowGoal = nil
        self.stitchGoal = nil
        self.tags = []
        self.annotations = [:]
        self.aiSummary = nil
        self.aiAbbreviations = nil
        self.aiMaterials = nil
        self.aiDifficulty = nil
        self.aiTimeEstimate = nil
        self.aiSchemaVersion = Self.currentAISchemaVersion
    }

    // Custom decode to handle optional new fields gracefully
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        bookmark = try c.decode(Data.self, forKey: .bookmark)
        lastOpened = try c.decode(Date.self, forKey: .lastOpened)
        isPinned = try c.decode(Bool.self, forKey: .isPinned)
        rowCount = try c.decode(Int.self, forKey: .rowCount)
        stitchCount = try c.decode(Int.self, forKey: .stitchCount)
        autoResetStitch = try c.decodeIfPresent(Bool.self, forKey: .autoResetStitch) ?? true
        repeatCount = try c.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 0
        showRepeatCounter = try c.decodeIfPresent(Bool.self, forKey: .showRepeatCounter) ?? false
        rowGoal = try c.decodeIfPresent(Int.self, forKey: .rowGoal)
        stitchGoal = try c.decodeIfPresent(Int.self, forKey: .stitchGoal)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        // Annotations stored as [String: String]; old Int-keyed data decodes fine (keys were "0","1" etc.)
        annotations = try c.decodeIfPresent([String: String].self, forKey: .annotations) ?? [:]
        aiSummary = try c.decodeIfPresent(PatternSummary.self, forKey: .aiSummary)
        aiAbbreviations = try c.decodeIfPresent(AbbreviationList.self, forKey: .aiAbbreviations)
        aiMaterials = try c.decodeIfPresent(MaterialsBreakdown.self, forKey: .aiMaterials)
        aiDifficulty = try c.decodeIfPresent(String.self, forKey: .aiDifficulty)
        aiTimeEstimate = try c.decodeIfPresent(String.self, forKey: .aiTimeEstimate)
        aiSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .aiSchemaVersion) ?? 0
    }

    func resolveURL() -> URL? {
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return url
        }
        return try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
