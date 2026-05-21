import Foundation
import FoundationModels

// MARK: - Result Types

struct PatternSummary {
    let patternName: String
    let skillLevel: String
    let materials: String
    let totalRows: String
    let estimatedTime: String
    let keyStitches: String
}

struct AbbreviationEntry: Identifiable {
    let id = UUID()
    let abbreviation: String
    let meaning: String
}

struct AbbreviationList {
    let convention: String
    let entries: [AbbreviationEntry]
}

struct MaterialsBreakdown {
    let yarn: String
    let hook: String
    let notions: String
}

struct StitchCountResult {
    struct RowIssue: Identifiable {
        let id = UUID()
        let rowNumber: Int
        let description: String
    }
    let issues: [RowIssue]
    let unverifiableNote: String?
}

// MARK: - Service

@available(macOS 26.0, *)
@MainActor
final class PatternAIService: ObservableObject {

    @Published var isLoadingSummary = false
    @Published var isLoadingAbbreviations = false
    @Published var isLoadingMaterials = false
    @Published var isLoadingDifficulty = false
    @Published var isLoadingConversion = false
    @Published var isLoadingStitchVerifier = false
    @Published var isLoadingYarnSub = false
    @Published var isLoadingTimeEstimate = false

    private var summaryCache: [UUID: PatternSummary] = [:]
    private var abbreviationCache: [UUID: AbbreviationList] = [:]
    private var materialsCache: [UUID: MaterialsBreakdown] = [:]
    private var difficultyCache: [UUID: String] = [:]
    private var conversionCache: [UUID: String] = [:]
    private var stitchVerifierCache: [UUID: StitchCountResult] = [:]
    private var yarnSubCache: [UUID: String] = [:]
    private var timeEstimateCache: [UUID: String] = [:]

    func clearCache(for patternID: UUID) {
        summaryCache.removeValue(forKey: patternID)
        abbreviationCache.removeValue(forKey: patternID)
        materialsCache.removeValue(forKey: patternID)
        difficultyCache.removeValue(forKey: patternID)
        conversionCache.removeValue(forKey: patternID)
        stitchVerifierCache.removeValue(forKey: patternID)
        yarnSubCache.removeValue(forKey: patternID)
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

    // MARK: - US ↔ UK Converter

    func convertTerminology(patternID: UUID, patternText: String) async throws -> String {
        if let cached = conversionCache[patternID] { return cached }
        isLoadingConversion = true
        defer { isLoadingConversion = false }

        let maxChars = 6000
        guard patternText.count <= maxChars else {
            let result = "Pattern is too long for full conversion (\(patternText.count) characters). Try a shorter pattern or paste just the stitch instructions."
            conversionCache[patternID] = result
            return result
        }

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. The following pattern uses crochet terminology.
        First, detect whether it uses US or UK conventions.
        Then rewrite the entire pattern with all stitch terms converted to the opposite convention.
        Use these mappings (US→UK): sc→dc, dc→tr, hdc→htr, tr→dtr, skip→miss, yarn over→yarn round hook.
        Reverse the mappings for UK→US patterns.
        Begin your reply with "Converted from [US/UK] to [UK/US]:" on its own line, then the full converted pattern text.

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        conversionCache[patternID] = result
        return result
    }

    // MARK: - Stitch Count Verifier

    func verifyStitchCounts(patternID: UUID, patternText: String) async throws -> StitchCountResult {
        if let cached = stitchVerifierCache[patternID] { return cached }
        isLoadingStitchVerifier = true
        defer { isLoadingStitchVerifier = false }

        let maxChars = 6000
        guard patternText.count <= maxChars else {
            let result = StitchCountResult(
                issues: [],
                unverifiableNote: "Pattern is too long to verify (\(patternText.count) characters). Try pasting just the row-by-row instructions."
            )
            stitchVerifierCache[patternID] = result
            return result
        }

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert and stitch math checker. Read the following pattern row by row and verify stitch counts.
        Rules:
        - If a row's stitch count is correct, skip it silently.
        - If a row's stitch count does NOT match the expected count from the prior row, output one line like:
          "Row 3: Expected 18 stitches (6 sc + 6×2-into-1 increases from Row 2's 12), but instructions produce 15."
        - If a row's math cannot be parsed (ambiguous instructions, complex stitch combos, etc.), output:
          "Row 5: Cannot verify — stitch math is ambiguous here."
        - If every row checks out, output exactly: "All rows verified."
        Output nothing else — no headers, no explanations outside the rows listed.

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let text = response.content
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var issues: [StitchCountResult.RowIssue] = []
        var unverifiableNote: String? = nil

        if lines.first == "All rows verified." {
            let result = StitchCountResult(issues: [], unverifiableNote: nil)
            stitchVerifierCache[patternID] = result
            return result
        }

        for line in lines {
            if line.lowercased().hasPrefix("row ") {
                let withoutPrefix = String(line.dropFirst(4))
                if let colonRange = withoutPrefix.range(of: ":") {
                    let rowNumStr = String(withoutPrefix[withoutPrefix.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let description = String(withoutPrefix[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if let rowNum = Int(rowNumStr) {
                        issues.append(StitchCountResult.RowIssue(rowNumber: rowNum, description: description))
                    }
                }
            }
        }

        let result = StitchCountResult(issues: issues, unverifiableNote: unverifiableNote)
        stitchVerifierCache[patternID] = result
        return result
    }

    // MARK: - Yarn Substitution Suggester

    func suggestYarnSubstitutions(patternID: UUID, patternText: String) async throws -> String {
        if let cached = yarnSubCache[patternID] { return cached }
        isLoadingYarnSub = true
        defer { isLoadingYarnSub = false }

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert. Based on the yarn specification in the following pattern, \
        suggest 2–3 alternative yarn characteristics that would work as substitutes.
        Do NOT recommend specific brand names. Stay generic (e.g., "any worsted-weight superwash wool or acrylic blend").
        Format as a numbered list. Keep each item to one sentence.

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        yarnSubCache[patternID] = result
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
