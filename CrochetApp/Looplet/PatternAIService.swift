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

// MARK: - Guided-generation types
//
// These @Generable mirrors are used ONLY for the on-device model call so it returns
// typed, structured output directly (instead of free text we fragile-parse). They map
// to the plain Codable structs above, which stay OS-agnostic for persistence.

@available(macOS 26.0, *)
@Generable
struct GeneratedSummary {
    @Guide(description: "The pattern's name or title")
    var patternName: String
    @Guide(description: "Overall skill level", .anyOf(["Beginner", "Intermediate", "Advanced"]))
    var skillLevel: String
    @Guide(description: "Yarn weight and hook size as one short phrase")
    var materials: String
    @Guide(description: "Total number of rows or rounds if the pattern states one; otherwise the word Unknown")
    var totalRows: String
    @Guide(description: "Comma-separated list of the main stitches used")
    var keyStitches: String
}

@available(macOS 26.0, *)
@Generable
struct GeneratedMaterials {
    @Guide(description: "Yarn: weight class, fiber, color, and yardage if mentioned")
    var yarn: String
    @Guide(description: "Crochet hook size in mm and US letter")
    var hook: String
    @Guide(description: "Notions such as stitch markers, tapestry needle, safety eyes, buttons")
    var notions: String
}

@available(macOS 26.0, *)
@Generable
struct GeneratedAbbreviation {
    @Guide(description: "The abbreviation token exactly as written, e.g. sc")
    var abbreviation: String
    @Guide(description: "The full meaning, e.g. single crochet")
    var meaning: String
}

@available(macOS 26.0, *)
@Generable
struct GeneratedAbbreviations {
    @Guide(description: "Terminology convention the pattern follows", .anyOf(["US", "UK"]))
    var convention: String
    @Guide(description: "Every crochet abbreviation that appears in the pattern, with its meaning")
    var entries: [GeneratedAbbreviation]
}

@available(macOS 26.0, *)
@Generable
struct GeneratedDifficulty {
    @Guide(description: "Difficulty classification", .anyOf(["Beginner", "Intermediate", "Advanced"]))
    var level: String
    @Guide(description: "One short sentence explaining why")
    var reason: String
}

/// User-facing error when on-device AI can't run.
enum AIServiceError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "Apple Intelligence isn't available on this Mac. Enable it in System Settings → Apple Intelligence & Siri to use AI insights."
    }
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

    /// Per-pattern Q&A conversation history, kept here (not in the panel view) so it
    /// survives the AI panel being closed/reopened and switching between patterns.
    @Published var qaHistory: [UUID: [QAPair]] = [:]

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

    /// Throw a clear, user-facing error if on-device AI can't run, instead of letting
    /// a raw session failure surface.
    private func ensureAvailable() throws {
        guard case .available = SystemLanguageModel.default.availability else {
            throw AIServiceError.unavailable
        }
    }

    /// Deterministically derive an estimated time from a stated row/round count and the
    /// user's rows-per-hour setting, so the figure is consistent rather than guessed.
    static func estimatedTime(fromRows rows: String, rowsPerHour: Int) -> String {
        let digits = rows.filter(\.isNumber)
        guard let count = Int(digits), count > 0, rowsPerHour > 0 else { return "Unknown" }
        let hours = Double(count) / Double(rowsPerHour)
        if hours < 1 { return "About \(Int((hours * 60).rounded())) min" }
        let rounded = (hours * 10).rounded() / 10
        return "About \(rounded.formatted(.number.precision(.fractionLength(0...1)))) hr"
    }

    // MARK: - Summary Card

    func generateSummary(patternID: UUID, patternText: String) async throws -> PatternSummary {
        if let cached = summaryCache[patternID] { return cached }
        try ensureAvailable()
        isLoadingSummary = true
        defer { isLoadingSummary = false }

        let session = LanguageModelSession {
            "You are a crochet expert who extracts accurate, structured metadata from crochet patterns."
        }
        let g = try await session.respond(
            to: "Analyze this crochet pattern and extract its summary. If a value is genuinely not present, use the word Unknown.\n\nPattern:\n\(patternText)",
            generating: GeneratedSummary.self
        ).content

        let rowsPerHour = UserDefaults.standard.rowsPerHour
        let result = PatternSummary(
            patternName: g.patternName,
            skillLevel: g.skillLevel,
            materials: g.materials,
            totalRows: g.totalRows,
            estimatedTime: Self.estimatedTime(fromRows: g.totalRows, rowsPerHour: rowsPerHour),
            keyStitches: g.keyStitches
        )
        summaryCache[patternID] = result
        return result
    }

    // MARK: - Abbreviation Explainer

    func generateAbbreviations(patternID: UUID, patternText: String) async throws -> AbbreviationList {
        if let cached = abbreviationCache[patternID] { return cached }
        try ensureAvailable()
        isLoadingAbbreviations = true
        defer { isLoadingAbbreviations = false }

        let session = LanguageModelSession {
            "You are a crochet expert who identifies every crochet abbreviation in a pattern and its full meaning."
        }
        let g = try await session.respond(
            to: "List every crochet abbreviation used in this pattern with its meaning, and detect whether it uses US or UK terminology.\n\nPattern:\n\(patternText)",
            generating: GeneratedAbbreviations.self
        ).content

        let result = AbbreviationList(
            convention: g.convention,
            entries: g.entries.map { AbbreviationEntry(abbreviation: $0.abbreviation, meaning: $0.meaning) }
        )
        abbreviationCache[patternID] = result
        return result
    }

    // MARK: - Pattern Q&A

    func answerQuestion(_ question: String, patternText: String) async throws -> String {
        try ensureAvailable()
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
        try ensureAvailable()
        isLoadingMaterials = true
        defer { isLoadingMaterials = false }

        let session = LanguageModelSession {
            "You are a crochet expert who extracts the materials list from a pattern."
        }
        let g = try await session.respond(
            to: "Extract the materials from this pattern. If a field isn't listed, say so briefly (e.g. \"Not specified\").\n\nPattern:\n\(patternText)",
            generating: GeneratedMaterials.self
        ).content

        let result = MaterialsBreakdown(yarn: g.yarn, hook: g.hook, notions: g.notions)
        materialsCache[patternID] = result
        return result
    }

    // MARK: - Difficulty Estimator

    func estimateDifficulty(patternID: UUID, patternText: String) async throws -> String {
        if let cached = difficultyCache[patternID] { return cached }
        try ensureAvailable()
        isLoadingDifficulty = true
        defer { isLoadingDifficulty = false }

        let session = LanguageModelSession {
            "You are a crochet expert who rates pattern difficulty."
        }
        let g = try await session.respond(
            to: "Classify this pattern's difficulty and explain why in one short sentence.\n\nPattern:\n\(patternText)",
            generating: GeneratedDifficulty.self
        ).content

        let result = "\(g.level) — \(g.reason)"
        difficultyCache[patternID] = result
        return result
    }

    // MARK: - Project Time Estimator

    func estimateTime(patternID: UUID, patternText: String, rowGoal: Int, rowCount: Int) async throws -> String {
        if let cached = timeEstimateCache[patternID] { return cached }
        try ensureAvailable()
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
                // Per product decision, always rename the library entry to the
                // AI-extracted pattern name (skip empty / "unknown" results).
                let name = r.patternName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, name.lowercased() != "unknown" {
                    library.rename(entryID: entryID, to: name)
                }
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
