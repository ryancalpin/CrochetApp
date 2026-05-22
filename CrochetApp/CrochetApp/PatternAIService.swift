import Foundation
import FoundationModels

// MARK: - Result Types (Codable for persistence)

struct PatternSummary: Codable {
    let patternName: String
    let skillLevel: String
    let materials: String
    let totalRows: String
    let estimatedTime: String
    let keyStitches: String
}

struct AbbreviationEntry: Identifiable, Codable {
    let id: UUID
    let abbreviation: String
    let meaning: String

    init(abbreviation: String, meaning: String) {
        self.id = UUID()
        self.abbreviation = abbreviation
        self.meaning = meaning
    }
}

struct AbbreviationList: Codable {
    let convention: String
    let entries: [AbbreviationEntry]
}

struct MaterialsBreakdown: Codable {
    let yarn: String
    let hook: String
    let notions: String
}

// MARK: - Service

@available(macOS 26.0, *)
@MainActor
final class PatternAIService: ObservableObject {

    @Published var isLoadingSummary = false
    @Published var isLoadingAbbreviations = false
    @Published var isLoadingMaterials = false
    @Published var isLoadingDifficulty = false
    @Published var isLoadingTimeEstimate = false

    private var summaryCache: [UUID: PatternSummary] = [:]
    private var abbreviationCache: [UUID: AbbreviationList] = [:]
    private var materialsCache: [UUID: MaterialsBreakdown] = [:]
    private var difficultyCache: [UUID: String] = [:]
    private var timeEstimateCache: [UUID: String] = [:]

    func clearCache(for patternID: UUID) {
        summaryCache.removeValue(forKey: patternID)
        abbreviationCache.removeValue(forKey: patternID)
        materialsCache.removeValue(forKey: patternID)
        difficultyCache.removeValue(forKey: patternID)
        timeEstimateCache.removeValue(forKey: patternID)
    }

    // MARK: - Summary Card

    func generateSummary(patternID: UUID, patternText: String) async throws -> PatternSummary {
        if let cached = summaryCache[patternID] { return cached }
        isLoadingSummary = true
        defer { isLoadingSummary = false }

        let session = LanguageModelSession()
        let rowsPerHour = UserDefaults.standard.rowsPerHour
        let prompt = """
        You are a crochet expert. Read this pattern and reply with ONLY these 6 lines. \
        Fill in each value after the colon. Use "Unknown" if you cannot determine a value.

        Pattern: <name of the pattern>
        Level: <Beginner, Intermediate, or Advanced>
        Materials: <yarn weight, hook size — one line>
        Rows: <total row/round count if stated, otherwise Unknown>
        Time: <estimate using \(rowsPerHour) rows/hour if Rows is known, otherwise Unknown>
        Stitches: <comma-separated main stitches used>

        Crochet pattern to analyze:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let text = response.content
        let result = PatternSummary(
            patternName: extractField("Pattern", from: text),
            skillLevel: extractField("Level", from: text),
            materials: extractField("Materials", from: text),
            totalRows: extractField("Rows", from: text),
            estimatedTime: extractField("Time", from: text),
            keyStitches: extractField("Stitches", from: text)
        )
        summaryCache[patternID] = result
        return result
    }

    // MARK: - Abbreviation Explainer

    func generateAbbreviations(patternID: UUID, patternText: String) async throws -> AbbreviationList {
        if let cached = abbreviationCache[patternID] { return cached }
        isLoadingAbbreviations = true
        defer { isLoadingAbbreviations = false }

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. Read the following crochet pattern and list every crochet abbreviation used.
        First line: "Convention: US" or "Convention: UK" (detect which the pattern uses).
        Then for each abbreviation, one line in the format "abbr — meaning".
        Do not add any other text.

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let text = response.content
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var convention = "US"
        var entries: [AbbreviationEntry] = []
        for line in lines {
            if line.lowercased().hasPrefix("convention:") {
                convention = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if line.contains(" — ") {
                let parts = line.components(separatedBy: " — ")
                if parts.count >= 2 {
                    entries.append(AbbreviationEntry(
                        abbreviation: parts[0].trimmingCharacters(in: .whitespaces),
                        meaning: parts[1...].joined(separator: " — ").trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }
        let result = AbbreviationList(convention: convention, entries: entries)
        abbreviationCache[patternID] = result
        return result
    }

    // MARK: - Pattern Q&A

    func answerQuestion(_ question: String, patternText: String) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. Answer the following question about the crochet pattern in 1–3 sentences. \
        Be concise and specific. If the answer cannot be determined from the pattern, say so briefly.

        Pattern:
        \(patternText)

        Question: \(question)
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Materials Extractor

    func extractMaterials(patternID: UUID, patternText: String) async throws -> MaterialsBreakdown {
        if let cached = materialsCache[patternID] { return cached }
        isLoadingMaterials = true
        defer { isLoadingMaterials = false }

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. Extract the materials from the following pattern.
        Reply ONLY with lines in the format "Field: Value". Do not add any other text.

        Fields:
        Yarn: (weight class, fiber if mentioned, color if mentioned, yardage — or "Could not detect a materials section")
        Hook: (size in mm and US letter — or "Not specified")
        Notions: (stitch markers, tapestry needle, buttons, etc. — or "None listed")

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let text = response.content
        let result = MaterialsBreakdown(
            yarn: extractField("Yarn", from: text),
            hook: extractField("Hook", from: text),
            notions: extractField("Notions", from: text)
        )
        materialsCache[patternID] = result
        return result
    }

    // MARK: - Difficulty Estimator

    func estimateDifficulty(patternID: UUID, patternText: String) async throws -> String {
        if let cached = difficultyCache[patternID] { return cached }
        isLoadingDifficulty = true
        defer { isLoadingDifficulty = false }

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. Classify the following pattern as Beginner, Intermediate, or Advanced.
        Reply with exactly one line: the classification followed by a dash and a 1-sentence explanation.
        Example: "Intermediate — Uses bobble stitches and requires joining multiple motifs."
        Do not add any other text.

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        difficultyCache[patternID] = result
        return result
    }

    // MARK: - Project Time Estimator

    func estimateTime(patternID: UUID, patternText: String, rowGoal: Int, rowCount: Int) async throws -> String {
        if let cached = timeEstimateCache[patternID] { return cached }
        isLoadingTimeEstimate = true
        defer { isLoadingTimeEstimate = false }

        let rowsPerHour = UserDefaults.standard.rowsPerHour
        let rowsRemaining = max(0, rowGoal - rowCount)
        let hoursRemaining = Double(rowsRemaining) / Double(rowsPerHour)
        let formatted = String(format: "%.1f", hoursRemaining)

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. The user has \(rowsRemaining) rows remaining at a pace of \(rowsPerHour) rows/hour, \
        which is approximately \(formatted) hours.
        Look at the following pattern and add one short note (1 sentence) if the stitch density suggests the pace \
        should be adjusted (e.g., bobble stitches, colorwork, or complex stitch patterns that typically take longer).
        If the pattern appears to be plain single or double crochet rows, output only: \
        "~\(formatted) hours remaining at your current pace."
        Otherwise output: "~\(formatted) hours remaining at your current pace. [your 1-sentence adjustment note]"
        Do not add any other text.

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        timeEstimateCache[patternID] = result
        return result
    }

    // MARK: - Helpers

    private func extractField(_ field: String, from text: String) -> String {
        let prefix = "\(field):".lowercased()
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.lowercased().hasPrefix(prefix) {
                return line.dropFirst(field.count + 1).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown"
    }
}

// MARK: - Background insight driver

/// Owns the single shared `PatternAIService` and generates a pattern's AI insights
/// in the background as soon as it is imported (or first opened), persisting each
/// result to the library so it never needs to be re-run.
///
/// `ensure(for:in:)` is idempotent: it skips fields already cached on the entry and
/// will not start a second run for a pattern that is already being analyzed. This is
/// what makes "auto-parse on import" safe — opening or re-selecting a pattern never
/// triggers a fresh burst of on-device model calls once its insights are persisted.
@available(macOS 26.0, *)
@MainActor
enum AIInsights {
    /// The one service instance shared by the background driver and the AI panel,
    /// so their in-memory caches stay coherent.
    static let service = PatternAIService()

    /// Patterns currently being analyzed, to avoid overlapping runs.
    private static var inFlight: Set<UUID> = []

    /// Generate any missing insights for `entryID` and persist them. Safe to call on
    /// every import and every selection — it no-ops when the work is already done or
    /// in progress.
    static func ensure(for entryID: UUID, in library: PatternLibrary) {
        guard !inFlight.contains(entryID),
              let entry = library.entries.first(where: { $0.id == entryID }) else { return }

        // Fully analyzed already — nothing to do.
        if entry.aiSummary != nil, entry.aiAbbreviations != nil, entry.aiMaterials != nil,
           entry.aiDifficulty != nil, entry.aiTimeEstimate != nil { return }

        // Read the pattern text once, holding the security scope only for the read.
        guard let url = entry.resolveURL() else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        let text = try? String(contentsOf: url, encoding: .utf8)
        if didAccess { url.stopAccessingSecurityScopedResource() }
        guard let patternText = text, !patternText.isEmpty else { return }

        inFlight.insert(entryID)
        Task {
            defer { inFlight.remove(entryID) }
            func fresh() -> PatternEntry? { library.entries.first { $0.id == entryID } }

            if fresh()?.aiSummary == nil,
               let r = try? await service.generateSummary(patternID: entryID, patternText: patternText) {
                library.updateAICache(for: entryID, summary: r)
            }
            if fresh()?.aiAbbreviations == nil,
               let r = try? await service.generateAbbreviations(patternID: entryID, patternText: patternText) {
                library.updateAICache(for: entryID, abbreviations: r)
            }
            if fresh()?.aiMaterials == nil,
               let r = try? await service.extractMaterials(patternID: entryID, patternText: patternText) {
                library.updateAICache(for: entryID, materials: r)
            }
            if fresh()?.aiDifficulty == nil,
               let r = try? await service.estimateDifficulty(patternID: entryID, patternText: patternText) {
                library.updateAICache(for: entryID, difficulty: r)
            }
            if fresh()?.aiTimeEstimate == nil {
                let e = fresh()
                if let r = try? await service.estimateTime(
                    patternID: entryID, patternText: patternText,
                    rowGoal: e?.rowGoal ?? 0, rowCount: e?.rowCount ?? 0) {
                    library.updateAICache(for: entryID, timeEstimate: r)
                }
            }
        }
    }
}
