import Foundation
import Combine
import AppKit

class PatternLibrary: ObservableObject {
    @Published var entries: [PatternEntry] = []
    @Published var activeEntryID: UUID? = nil

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("CrochetApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("patterns.json")
    }()

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
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
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

    func select(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].lastOpened = Date()
        activeEntryID = entryID
        save()
    }

    func updateActiveCounters(row: Int, stitch: Int, autoReset: Bool) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].rowCount = row
        entries[i].stitchCount = stitch
        entries[i].autoResetStitch = autoReset
        save()
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        if activeEntryID == entryID { activeEntryID = nil }
        save()
    }

    func togglePin(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].isPinned.toggle()
        save()
    }

    /// Called from AnnotationBridge when JS saves or deletes a note.
    func updateNote(index: Int, text: String?) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if let text = text, !text.isEmpty {
            entries[i].annotations[index] = text
        } else {
            entries[i].annotations.removeValue(forKey: index)
        }
        save()
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PatternEntry].self, from: data) else { return }
        entries = decoded
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillTerminate() {
        save()
    }
}
