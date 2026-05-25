import Foundation
import Combine

// MARK: - Yarn Stash Model

struct YarnEntry: Codable, Identifiable {
    let id: UUID
    var name: String
    var weight: String   // e.g. "Worsted", "DK", "Bulky"
    var colorHex: String // e.g. "#9B8ED4"
    var yardage: Int     // total yards in stash

    init(name: String, weight: String = "Worsted", colorHex: String = "#888888", yardage: Int = 0) {
        self.id = UUID()
        self.name = name
        self.weight = weight
        self.colorHex = colorHex
        self.yardage = yardage
    }
}

class PatternLibrary: ObservableObject {
    @Published var entries: [PatternEntry] = []
    @Published var activeEntryID: UUID? = nil
    @Published var yarnStash: [YarnEntry] = []

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Looplet", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("patterns.json")
    }()

    private let yarnURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Looplet/yarn.json")
    }()

    // MARK: - iCloud sync state

    private let localStampKey = "cloud.localStamp"

    /// Timestamp (Unix epoch seconds) of when local data last changed.
    /// Used for last-writer-wins reconciliation against the iCloud KVS stamp.
    private var localStamp: TimeInterval {
        get { UserDefaults.standard.double(forKey: localStampKey) }
        set { UserDefaults.standard.set(newValue, forKey: localStampKey) }
    }

    /// While `true`, `save()`/`saveYarn()` still write local JSON but skip the
    /// cloud push and the localStamp bump. This prevents a pull-then-push
    /// ping-pong when applying a remote change.
    private var isApplyingRemote = false

    // MARK: - Computed

    var pinned: [PatternEntry] {
        entries.filter(\.isPinned).sorted { $0.lastOpened > $1.lastOpened }
    }

    var recent: [PatternEntry] {
        entries.filter { !$0.isPinned }
            .sorted { $0.lastOpened > $1.lastOpened }
    }

    var activeEntry: PatternEntry? {
        entries.first { $0.id == activeEntryID }
    }

    // MARK: - Init

    init() {
        migrateLegacySupportDirIfNeeded()
        load()
        migrateAICacheIfNeeded()
        loadYarn()
        // Pull any newer data already sitting in iCloud, then watch for
        // other-device changes. Both are no-ops if iCloud is unavailable.
        syncFromCloudIfNeeded()
        CloudSync.shared.startObserving { [weak self] in
            self?.syncFromCloudIfNeeded()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: .appWillPersistState,
            object: nil
        )
    }

    /// Move data from the pre-rename "CrochetApp" support folder into "Looplet" once,
    /// so existing patterns/yarn survive the app rename. No-op if already migrated.
    private func migrateLegacySupportDirIfNeeded() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldDir = support.appendingPathComponent("CrochetApp", isDirectory: true)
        let newDir = support.appendingPathComponent("Looplet", isDirectory: true)
        guard fm.fileExists(atPath: oldDir.path) else { return }
        try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)
        for name in ["patterns.json", "yarn.json"] {
            let src = oldDir.appendingPathComponent(name)
            let dst = newDir.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    // MARK: - Public API

    @discardableResult
    func add(url: URL) -> UUID? {
        if let existing = entries.first(where: { $0.resolveURL() == url }) {
            return existing.id
        }
        guard var entry = try? PatternEntry(url: url) else { return nil }
        let s = AppSettings.shared
        if s.defaultRowGoal > 0 { entry.rowGoal = s.defaultRowGoal }
        if s.defaultStitchGoal > 0 { entry.stitchGoal = s.defaultStitchGoal }
        entries.append(entry)
        save()
        return entry.id
    }

    /// Seed the bundled sample pattern. Writes the markdown into our own support directory
    /// (a writable, always-accessible location) and imports it like a normal file. If the
    /// sample is already in the library, returns the existing entry instead of duplicating.
    @discardableResult
    func addSamplePattern() -> UUID? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("Looplet/Samples", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(SampleContent.fileName)

        if !fm.fileExists(atPath: fileURL.path) {
            guard (try? SampleContent.patternMarkdown.write(to: fileURL, atomically: true, encoding: .utf8)) != nil else {
                return nil
            }
        }
        if let existing = entries.first(where: { $0.resolveURL() == fileURL }) {
            return existing.id
        }
        return add(url: fileURL)
    }

    func select(entryID: UUID) {
        activeEntryID = entryID
    }

    func updateActiveCounters(row: Int, stitch: Int, repeat repeatCount: Int, autoReset: Bool) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let changed = entries[i].rowCount != row || entries[i].stitchCount != stitch || entries[i].repeatCount != repeatCount
        entries[i].rowCount = row
        entries[i].stitchCount = stitch
        entries[i].repeatCount = repeatCount
        entries[i].autoResetStitch = autoReset
        if changed { entries[i].lastOpened = Date() }
        save()
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        if activeEntryID == entryID { activeEntryID = nil }
        save()
    }

    func rename(entryID: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        guard entries[i].displayName != trimmed else { return }
        entries[i].displayName = trimmed
        save()
    }

    func togglePin(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].isPinned.toggle()
        save()
    }

    func toggleRepeatCounter(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].showRepeatCounter.toggle()
        if !entries[i].showRepeatCounter { entries[i].repeatCount = 0 }
        save()
    }

    /// Called from AnnotationBridge when JS saves or deletes a note.
    /// Key is a text fingerprint (first 64 chars of block text).
    func updateNote(key: String, text: String?) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if let text = text, !text.isEmpty {
            entries[i].annotations[key] = text
        } else {
            entries[i].annotations.removeValue(forKey: key)
        }
        save()
    }

    // MARK: - Tags

    func addTag(_ tag: String, to entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let cleaned = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleaned.isEmpty, !entries[i].tags.contains(cleaned) else { return }
        entries[i].tags.append(cleaned)
        save()
    }

    func removeTag(_ tag: String, from entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].tags.removeAll { $0 == tag }
        save()
    }

    // MARK: - Yarn Stash

    func addYarn(_ yarn: YarnEntry) {
        yarnStash.append(yarn)
        saveYarn()
    }

    func removeYarn(id: UUID) {
        yarnStash.removeAll { $0.id == id }
        saveYarn()
    }

    func updateYarn(_ yarn: YarnEntry) {
        guard let i = yarnStash.firstIndex(where: { $0.id == yarn.id }) else { return }
        yarnStash[i] = yarn
        saveYarn()
    }

    /// Persist AI analysis results for a pattern so they don't need to be re-run on next launch.
    func updateAICache(
        for entryID: UUID,
        summary: PatternSummary? = nil,
        abbreviations: AbbreviationList? = nil,
        materials: MaterialsBreakdown? = nil,
        difficulty: String? = nil,
        timeEstimate: String? = nil
    ) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        if let v = summary { entries[i].aiSummary = v }
        if let v = abbreviations { entries[i].aiAbbreviations = v }
        if let v = materials { entries[i].aiMaterials = v }
        if let v = difficulty { entries[i].aiDifficulty = v }
        if let v = timeEstimate { entries[i].aiTimeEstimate = v }
        entries[i].aiSchemaVersion = PatternEntry.currentAISchemaVersion
        save()
    }

    /// Invalidate AI insights cached by an older generation schema so they are
    /// regenerated by the current logic (e.g. old "Unknown"-filled summaries).
    private func migrateAICacheIfNeeded() {
        var changed = false
        for i in entries.indices where entries[i].aiSchemaVersion < PatternEntry.currentAISchemaVersion {
            entries[i].aiSummary = nil
            entries[i].aiAbbreviations = nil
            entries[i].aiMaterials = nil
            entries[i].aiDifficulty = nil
            entries[i].aiTimeEstimate = nil
            entries[i].aiSchemaVersion = PatternEntry.currentAISchemaVersion
            changed = true
        }
        if changed { save() }
    }

    func clearAICache(for entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].aiSummary = nil
        entries[i].aiAbbreviations = nil
        entries[i].aiMaterials = nil
        entries[i].aiDifficulty = nil
        entries[i].aiTimeEstimate = nil
        save()
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
        // Mirror to iCloud unless we're in the middle of applying a remote pull.
        guard !isApplyingRemote else { return }
        // iCloud sync is a Pro feature.
        guard Pro.isUnlocked else { return }
        guard let yarnData = try? JSONEncoder().encode(yarnStash) else { return }
        localStamp = Date().timeIntervalSince1970
        CloudSync.shared.push(entries: data, yarn: yarnData)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PatternEntry].self, from: data) else { return }
        entries = decoded
    }

    private func saveYarn() {
        guard let data = try? JSONEncoder().encode(yarnStash) else { return }
        try? data.write(to: yarnURL, options: .atomic)
        // Mirror to iCloud unless we're in the middle of applying a remote pull.
        guard !isApplyingRemote else { return }
        // iCloud sync is a Pro feature.
        guard Pro.isUnlocked else { return }
        guard let entriesData = try? JSONEncoder().encode(entries) else { return }
        localStamp = Date().timeIntervalSince1970
        CloudSync.shared.push(entries: entriesData, yarn: data)
    }

    /// Pull data from iCloud KVS when it is newer than the local copy
    /// (last-writer-wins by timestamp). Every step is guarded; on any failure
    /// the local data is left completely untouched.
    func syncFromCloudIfNeeded() {
        // iCloud sync is a Pro feature.
        guard Pro.isUnlocked else { return }
        guard let (e, y) = CloudSync.shared.pullIfNewer(localStamp: localStamp) else { return }
        guard let decodedEntries = try? JSONDecoder().decode([PatternEntry].self, from: e),
              let decodedYarn = try? JSONDecoder().decode([YarnEntry].self, from: y) else { return }

        isApplyingRemote = true
        entries = decodedEntries
        yarnStash = decodedYarn
        // Persist the pulled data locally (these saves skip the cloud push).
        save()
        saveYarn()
        isApplyingRemote = false

        // Align local stamp with the remote one so pullIfNewer won't re-fire
        // and we don't ping-pong a push back to iCloud.
        localStamp = CloudSync.shared.remoteStamp
    }

    private func loadYarn() {
        guard let data = try? Data(contentsOf: yarnURL),
              let decoded = try? JSONDecoder().decode([YarnEntry].self, from: data) else { return }
        yarnStash = decoded
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillTerminate() {
        save()
        saveYarn()
    }
}
