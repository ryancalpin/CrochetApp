# Apple Intelligence Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an on-device AI inspector panel to CrochetApp that provides pattern summaries, abbreviation explanations, Q&A, materials extraction, difficulty estimation, US↔UK conversion, stitch count verification, yarn substitution suggestions, and time estimation — all using the Foundation Models framework, gated behind macOS 15.1+.

**Architecture:** A single `PatternAIService` `@MainActor` `ObservableObject` owns all `LanguageModelSession` interactions and caches results per `PatternEntry.id`. `AIPanelView` slides in as a 280pt right inspector inside `ContentView`'s detail pane, toggled via a `@Binding var showAIPanel: Bool` that originates in `ContentView`. Each feature section is rendered by a reusable `AIFeatureSection` disclosure view. Q&A is its own sub-view `PatternQAView` with in-memory history.

**Tech Stack:** SwiftUI (macOS 13+), FoundationModels (macOS 15.1+ only), UserDefaults, `@available(macOS 15.1, *)` guards everywhere AI code appears.

**Build command (run after every task to verify):**
```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

> **Note — adding files to Xcode:** After creating each new `.swift` file, add it to the `CrochetApp` target by editing `CrochetApp.xcodeproj/project.pbxproj`. Each new file needs a `PBXFileReference` entry, a `PBXBuildFile` entry, an entry in the `PBXGroup` children list, and an entry in the `PBXSourcesBuildPhase` files list. Search for `CrochetAppApp.swift` in `project.pbxproj` to see the existing format.

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `CrochetApp/CrochetApp/UserDefaults+CrochetApp.swift` | **Create** | Typed UserDefaults extensions: `rowsPerHour` (default 8), `aiPanelOpen` |
| `CrochetApp/CrochetApp/PatternAIService.swift` | **Create** | `@MainActor ObservableObject`; Foundation Models wrapper; all 9 feature methods; per-pattern cache |
| `CrochetApp/CrochetApp/AIFeatureSection.swift` | **Create** | Reusable `DisclosureGroup` + spinner + "Regenerate" button; generic over result type |
| `CrochetApp/CrochetApp/PatternQAView.swift` | **Create** | Text field input + scrollable in-memory Q&A history list |
| `CrochetApp/CrochetApp/AIPanelView.swift` | **Create** | Right inspector panel; wires all `PatternAIService` feature sections together |
| `CrochetApp/CrochetApp/CounterBarView.swift` | **Modify** | Add `@Binding var showAIPanel: Bool` parameter; add ✦ toolbar button (availability-gated) |
| `CrochetApp/CrochetApp/ContentView.swift` | **Modify** | Add `@State private var showAIPanel`; wrap detail pane in `HStack` with `AIPanelView`; pass binding to `CounterBarView` |

---

## Task 1: UserDefaults+CrochetApp extensions

**Files:**
- Create: `CrochetApp/CrochetApp/UserDefaults+CrochetApp.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

extension UserDefaults {
    private enum Keys {
        static let rowsPerHour = "crochet.rowsPerHour"
        static let aiPanelOpen = "crochet.aiPanelOpen"
    }

    /// Number of rows a user completes per hour. Used for time estimation. Default: 8.
    var rowsPerHour: Int {
        get {
            let stored = integer(forKey: Keys.rowsPerHour)
            return stored == 0 ? 8 : stored
        }
        set { set(newValue, forKey: Keys.rowsPerHour) }
    }

    /// Whether the AI inspector panel was open when the app last closed.
    var aiPanelOpen: Bool {
        get { bool(forKey: Keys.aiPanelOpen) }
        set { set(newValue, forKey: Keys.aiPanelOpen) }
    }
}
```

- [ ] **Step 2: Add file to Xcode project target** (edit `project.pbxproj` — see note at top)

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add "CrochetApp/CrochetApp/UserDefaults+CrochetApp.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj" && \
git commit -m "feat: add UserDefaults extensions for rowsPerHour and aiPanelOpen"
```

---

## Task 2: PatternAIService

**Files:**
- Create: `CrochetApp/CrochetApp/PatternAIService.swift`

`PatternAIService` is decorated `@available(macOS 15.1, *)`. It creates one `LanguageModelSession` per call (or reuses a stored one). Each feature method takes the raw pattern text as a `String`, sends a focused prompt, and returns a structured result. Results are cached in a dictionary keyed by `PatternEntry.id` so re-opening the panel doesn't re-run inference. The cache is cleared when the pattern changes.

- [ ] **Step 1: Create the file**

```swift
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
    let convention: String   // "US", "UK", or "Unknown"
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

// MARK: - Cache Key

private struct CacheKey: Hashable {
    let patternID: UUID
    let feature: String
}

// MARK: - Service

@available(macOS 15.1, *)
@MainActor
final class PatternAIService: ObservableObject {

    // MARK: - Published loading flags

    @Published var isLoadingSummary = false
    @Published var isLoadingAbbreviations = false
    @Published var isLoadingMaterials = false
    @Published var isLoadingDifficulty = false
    @Published var isLoadingConversion = false
    @Published var isLoadingStitchVerifier = false
    @Published var isLoadingYarnSub = false
    @Published var isLoadingTimeEstimate = false

    // MARK: - Cached results (keyed by patternID + feature name)

    private var summaryCache: [UUID: PatternSummary] = [:]
    private var abbreviationCache: [UUID: AbbreviationList] = [:]
    private var materialsCache: [UUID: MaterialsBreakdown] = [:]
    private var difficultyCache: [UUID: String] = [:]
    private var conversionCache: [UUID: String] = [:]
    private var stitchVerifierCache: [UUID: StitchCountResult] = [:]
    private var yarnSubCache: [UUID: String] = [:]
    private var timeEstimateCache: [UUID: String] = [:]

    // MARK: - Cache invalidation

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
        let prompt = """
        You are a crochet expert. Read the following crochet pattern and extract exactly these fields. \
        Reply ONLY with lines in the format "Field: Value". Do not add any other text.

        Fields:
        PatternName: (name of the pattern, or "Unknown")
        SkillLevel: (Beginner, Intermediate, or Advanced)
        Materials: (yarn weight, hook size, yardage — one line summary)
        TotalRows: (number of rows if determinable, otherwise "Unknown")
        EstimatedTime: (use "\(UserDefaults.standard.rowsPerHour) rows/hour" as the pace and calculate hours if TotalRows is known, otherwise "Unknown")
        KeyStitches: (comma-separated list of main stitches used)

        Pattern:
        \(patternText)
        """
        let response = try await session.respond(to: prompt)
        let text = response.content
        let result = PatternSummary(
            patternName: extractField("PatternName", from: text),
            skillLevel: extractField("SkillLevel", from: text),
            materials: extractField("Materials", from: text),
            totalRows: extractField("TotalRows", from: text),
            estimatedTime: extractField("EstimatedTime", from: text),
            keyStitches: extractField("KeyStitches", from: text)
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

        let session = LanguageModelSession()
        let prompt = """
        You are a crochet expert and stitch math checker. Read the following pattern row by row.
        For each row where the resulting stitch count does NOT match the expected count from the prior row, \
        output one line in the format: "Row N: explanation of the discrepancy."
        If you cannot parse a row's math, output: "Row N: Could not verify — pattern too complex to parse automatically."
        If all rows check out, output: "All rows verified."
        Do not add any other text.

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
            // Match "Row N: description"
            if line.lowercased().hasPrefix("row ") {
                let withoutPrefix = String(line.dropFirst(4))
                if let colonRange = withoutPrefix.range(of: ":") {
                    let rowNumStr = String(withoutPrefix[withoutPrefix.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let description = String(withoutPrefix[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if let rowNum = Int(rowNumStr) {
                        issues.append(StitchCountResult.RowIssue(rowNumber: rowNum, description: description))
                    }
                }
            } else if !issues.isEmpty || line.lowercased().contains("could not verify") {
                unverifiableNote = line
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
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("\(field):") {
                return line.dropFirst(field.count + 1).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown"
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add "CrochetApp/CrochetApp/PatternAIService.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj" && \
git commit -m "feat: add PatternAIService with Foundation Models wrapper and all 9 feature methods"
```

---

## Task 3: AIFeatureSection

**Files:**
- Create: `CrochetApp/CrochetApp/AIFeatureSection.swift`

This is a reusable `DisclosureGroup` wrapper. It takes a title, a loading flag, a regenerate action, and a content closure. When `isLoading` is true it shows a `ProgressView`. The "Regenerate" button appears in the header so it doesn't take up content space.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// A disclosure section used in the AI panel. Shows a spinner while loading
/// and a Regenerate button that re-runs inference for this feature.
struct AIFeatureSection<Content: View>: View {
    let title: String
    let isLoading: Bool
    let onRegenerate: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Group {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Generating…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    content()
                        .padding(.top, 4)
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if !isLoading {
                    Button {
                        onRegenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate this section")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add "CrochetApp/CrochetApp/AIFeatureSection.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj" && \
git commit -m "feat: add AIFeatureSection reusable disclosure group with spinner and regenerate"
```

---

## Task 4: PatternQAView

**Files:**
- Create: `CrochetApp/CrochetApp/PatternQAView.swift`

Q&A input at the bottom of its section. History list scrolls above it. All in-memory only. The view owns its question string and history list; the service is passed in for the `answerQuestion` call.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct QAPair: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

@available(macOS 15.1, *)
struct PatternQAView: View {
    let service: PatternAIService
    let patternText: String

    @State private var question: String = ""
    @State private var history: [QAPair] = []
    @State private var isAsking: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // History list
            if !history.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(history) { pair in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pair.question)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(pair.answer)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 200)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Input row
            HStack(spacing: 6) {
                TextField("Ask anything about this pattern…", text: $question)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .onSubmit { askQuestion() }
                    .disabled(isAsking)

                if isAsking {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                } else {
                    Button {
                        askQuestion()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(question.isEmpty ? .secondary : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(question.isEmpty)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func askQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAsking = true
        errorMessage = nil
        let asked = trimmed
        question = ""
        Task {
            do {
                let answer = try await service.answerQuestion(asked, patternText: patternText)
                history.append(QAPair(question: asked, answer: answer))
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isAsking = false
        }
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add "CrochetApp/CrochetApp/PatternQAView.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj" && \
git commit -m "feat: add PatternQAView with in-memory Q&A history"
```

---

## Task 5: AIPanelView

**Files:**
- Create: `CrochetApp/CrochetApp/AIPanelView.swift`

The full right inspector panel. Receives the `PatternEntry` (for `id`, `rowCount`, `rowGoal`) and the raw pattern text. Creates and owns a `PatternAIService` instance. Renders all nine feature sections using `AIFeatureSection`. The panel header includes a close button that sets `showAIPanel = false` via the binding passed in from `ContentView`.

> **Note on `rowGoal`:** By the time this plan executes, `PatternEntry` will have a `rowGoal: Int` property (added in the pattern management plan). Use `entry.rowGoal` directly. If it turns out `PatternEntry` does not yet have `rowGoal`, add a `var rowGoal: Int = 0` property to `PatternEntry.swift` as part of this task's step 1.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

@available(macOS 15.1, *)
struct AIPanelView: View {
    let entry: PatternEntry
    let patternText: String
    @Binding var showAIPanel: Bool

    @StateObject private var service = PatternAIService()

    // Per-feature result state
    @State private var summary: PatternSummary? = nil
    @State private var abbreviations: AbbreviationList? = nil
    @State private var materials: MaterialsBreakdown? = nil
    @State private var difficulty: String? = nil
    @State private var conversion: String? = nil
    @State private var stitchResult: StitchCountResult? = nil
    @State private var yarnSub: String? = nil
    @State private var timeEstimate: String? = nil

    // Per-feature error state
    @State private var summaryError: String? = nil
    @State private var abbreviationsError: String? = nil
    @State private var materialsError: String? = nil
    @State private var difficultyError: String? = nil
    @State private var conversionError: String? = nil
    @State private var stitchError: String? = nil
    @State private var yarnSubError: String? = nil
    @State private var timeError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Assistant")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    showAIPanel = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Close AI panel")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Feature sections
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Summary Card
                    AIFeatureSection(
                        title: "Summary",
                        isLoading: service.isLoadingSummary,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            summary = nil
                            summaryError = nil
                            loadSummary()
                        }
                    ) {
                        if let s = summary {
                            summaryContent(s)
                        } else if let e = summaryError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadSummary() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 2. Abbreviations
                    AIFeatureSection(
                        title: "Abbreviations",
                        isLoading: service.isLoadingAbbreviations,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            abbreviations = nil
                            abbreviationsError = nil
                            loadAbbreviations()
                        }
                    ) {
                        if let a = abbreviations {
                            abbreviationsContent(a)
                        } else if let e = abbreviationsError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadAbbreviations() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 3. Q&A
                    AIFeatureSection(
                        title: "Ask a Question",
                        isLoading: false,
                        onRegenerate: { /* Q&A has no pre-generated content to regenerate */ }
                    ) {
                        PatternQAView(service: service, patternText: patternText)
                    }

                    Divider().padding(.horizontal, 12)

                    // 4. Materials
                    AIFeatureSection(
                        title: "Materials",
                        isLoading: service.isLoadingMaterials,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            materials = nil
                            materialsError = nil
                            loadMaterials()
                        }
                    ) {
                        if let m = materials {
                            materialsContent(m)
                        } else if let e = materialsError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadMaterials() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 5. Difficulty
                    AIFeatureSection(
                        title: "Difficulty",
                        isLoading: service.isLoadingDifficulty,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            difficulty = nil
                            difficultyError = nil
                            loadDifficulty()
                        }
                    ) {
                        if let d = difficulty {
                            Text(d)
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let e = difficultyError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadDifficulty() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 6. US ↔ UK Converter
                    AIFeatureSection(
                        title: "US ↔ UK Conversion",
                        isLoading: service.isLoadingConversion,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            conversion = nil
                            conversionError = nil
                            loadConversion()
                        }
                    ) {
                        if let c = conversion {
                            ScrollView {
                                Text(c)
                                    .font(.system(size: 11, design: .monospaced))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 180)
                        } else if let e = conversionError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadConversion() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 7. Stitch Count Verifier
                    AIFeatureSection(
                        title: "Stitch Count Verifier",
                        isLoading: service.isLoadingStitchVerifier,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            stitchResult = nil
                            stitchError = nil
                            loadStitchVerifier()
                        }
                    ) {
                        if let r = stitchResult {
                            stitchVerifierContent(r)
                        } else if let e = stitchError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadStitchVerifier() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 8. Yarn Substitution
                    AIFeatureSection(
                        title: "Yarn Substitution",
                        isLoading: service.isLoadingYarnSub,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            yarnSub = nil
                            yarnSubError = nil
                            loadYarnSub()
                        }
                    ) {
                        if let y = yarnSub {
                            Text(y)
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let e = yarnSubError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadYarnSub() }
                        }
                    }

                    Divider().padding(.horizontal, 12)

                    // 9. Time Estimate
                    AIFeatureSection(
                        title: "Time Estimate",
                        isLoading: service.isLoadingTimeEstimate,
                        onRegenerate: {
                            service.clearCache(for: entry.id)
                            timeEstimate = nil
                            timeError = nil
                            loadTimeEstimate()
                        }
                    ) {
                        if let t = timeEstimate {
                            Text(t)
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let e = timeError {
                            errorText(e)
                        } else {
                            Color.clear.onAppear { loadTimeEstimate() }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Sub-views

    private func summaryContent(_ s: PatternSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            labeledRow("Pattern", s.patternName)
            labeledRow("Level", s.skillLevel)
            labeledRow("Materials", s.materials)
            labeledRow("Total Rows", s.totalRows)
            labeledRow("Est. Time", s.estimatedTime)
            labeledRow("Key Stitches", s.keyStitches)
        }
    }

    private func abbreviationsContent(_ a: AbbreviationList) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if a.convention != "US" && a.convention != "Unknown" {
                Text("Using \(a.convention) convention")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.bottom, 2)
            }
            ForEach(a.entries) { entry in
                HStack(alignment: .top, spacing: 4) {
                    Text(entry.abbreviation)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("—")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(entry.meaning)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if a.entries.isEmpty {
                Text("No abbreviations detected.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func materialsContent(_ m: MaterialsBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            labeledRow("Yarn", m.yarn)
            labeledRow("Hook", m.hook)
            labeledRow("Notions", m.notions)
        }
    }

    private func stitchVerifierContent(_ r: StitchCountResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if r.issues.isEmpty && r.unverifiableNote == nil {
                Label("All rows verified", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            } else {
                ForEach(r.issues) { issue in
                    HStack(alignment: .top, spacing: 4) {
                        Text("⚠")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Row \(issue.rowNumber)")
                                .font(.system(size: 11, weight: .semibold))
                            Text(issue.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let note = r.unverifiableNote {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("\(label):")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(minWidth: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundColor(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Load actions

    private func loadSummary() {
        Task {
            do { summary = try await service.generateSummary(patternID: entry.id, patternText: patternText) }
            catch { summaryError = error.localizedDescription }
        }
    }

    private func loadAbbreviations() {
        Task {
            do { abbreviations = try await service.generateAbbreviations(patternID: entry.id, patternText: patternText) }
            catch { abbreviationsError = error.localizedDescription }
        }
    }

    private func loadMaterials() {
        Task {
            do { materials = try await service.extractMaterials(patternID: entry.id, patternText: patternText) }
            catch { materialsError = error.localizedDescription }
        }
    }

    private func loadDifficulty() {
        Task {
            do { difficulty = try await service.estimateDifficulty(patternID: entry.id, patternText: patternText) }
            catch { difficultyError = error.localizedDescription }
        }
    }

    private func loadConversion() {
        Task {
            do { conversion = try await service.convertTerminology(patternID: entry.id, patternText: patternText) }
            catch { conversionError = error.localizedDescription }
        }
    }

    private func loadStitchVerifier() {
        Task {
            do { stitchResult = try await service.verifyStitchCounts(patternID: entry.id, patternText: patternText) }
            catch { stitchError = error.localizedDescription }
        }
    }

    private func loadYarnSub() {
        Task {
            do { yarnSub = try await service.suggestYarnSubstitutions(patternID: entry.id, patternText: patternText) }
            catch { yarnSubError = error.localizedDescription }
        }
    }

    private func loadTimeEstimate() {
        Task {
            do {
                timeEstimate = try await service.estimateTime(
                    patternID: entry.id,
                    patternText: patternText,
                    rowGoal: entry.rowGoal,
                    rowCount: entry.rowCount
                )
            }
            catch { timeError = error.localizedDescription }
        }
    }
}
```

- [ ] **Step 2: Add file to Xcode project target**

- [ ] **Step 3: Check whether `PatternEntry` has a `rowGoal` property**

```bash
grep -n "rowGoal" "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp/PatternEntry.swift" 2>/dev/null || echo "rowGoal NOT found — add it in next step"
```

If `rowGoal` is not found, open `PatternEntry.swift` and add `var rowGoal: Int = 0` to the struct's stored properties. Then build:

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add "CrochetApp/CrochetApp/AIPanelView.swift" \
        "CrochetApp/CrochetApp/PatternEntry.swift" \
        "CrochetApp/CrochetApp.xcodeproj/project.pbxproj" && \
git commit -m "feat: add AIPanelView with all 9 AI feature sections"
```

---

## Task 6: Wire AI panel into ContentView + CounterBarView toggle

**Files:**
- Modify: `CrochetApp/CrochetApp/CounterBarView.swift`
- Modify: `CrochetApp/CrochetApp/ContentView.swift`

### CounterBarView changes

Add `@Binding var showAIPanel: Bool` parameter to `CounterBarView`. Add a ✦ button on the trailing side of the bar, availability-gated so it only appears on macOS 15.1+.

- [ ] **Step 1: Read current CounterBarView.swift**

Read the file at `/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp/CounterBarView.swift` to see the current `struct CounterBarView: View {` declaration and its `var body: some View` start, then make the edits below.

- [ ] **Step 2: Add the binding and the ✦ button to CounterBarView.swift**

Change the struct declaration from:
```swift
struct CounterBarView: View {
    @ObservedObject var store: CounterStore
    @State private var showResetConfirmation = false
```
to:
```swift
struct CounterBarView: View {
    @ObservedObject var store: CounterStore
    @Binding var showAIPanel: Bool
    @State private var showResetConfirmation = false
```

In the `HStack` body, after the Reset button's `confirmationDialog` modifier and before the closing `}` of the HStack, add the following block:

```swift
            // AI panel toggle — macOS 15.1+ only
            if #available(macOS 15.1, *) {
                Divider()
                    .frame(height: 32)

                Button {
                    showAIPanel.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text("AI")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(showAIPanel ? .purple : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showAIPanel ? Color.purple.opacity(0.12) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(showAIPanel ? "Close AI panel" : "Open AI panel")
            }
```

Also update any `#Preview` at the bottom of `CounterBarView.swift` that references `CounterBarView` to pass a constant binding:
```swift
#Preview {
    CounterBarView(store: CounterStore(), showAIPanel: .constant(false))
        .frame(width: 700)
        .padding()
}
```

### ContentView changes

- [ ] **Step 3: Modify ContentView.swift to add AI panel state and layout**

Replace the entire `ContentView.swift` with the following. Key changes:
- Add `@State private var showAIPanel = false` (initialized from `UserDefaults.standard.aiPanelOpen`)
- Pass `$showAIPanel` to `CounterBarView`
- Wrap the markdown viewer in an `HStack` with `AIPanelView` when `showAIPanel` is true and a pattern is loaded and macOS 15.1+ is available
- Persist `showAIPanel` changes back to `UserDefaults`

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: PatternLibrary
    @ObservedObject var store: CounterStore
    @State private var showAIPanel: Bool = UserDefaults.standard.aiPanelOpen

    var body: some View {
        NavigationSplitView {
            PatternLibraryView(library: library, store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                // Sticky counter bar with AI toggle
                CounterBarView(store: store, showAIPanel: $showAIPanel)

                // Content area: markdown viewer + optional AI panel
                HStack(spacing: 0) {
                    MarkdownView(fileURL: activeFileURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showAIPanel, let entry = library.activeEntry, let text = loadedPatternText {
                        if #available(macOS 15.1, *) {
                            Divider()
                            AIPanelView(
                                entry: entry,
                                patternText: text,
                                showAIPanel: $showAIPanel
                            )
                            .transition(.move(edge: .trailing))
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAIPanel)
            }
        }
        .navigationTitle(library.activeEntry?.displayName ?? "Crochet Helper")
        .background(KeyboardShortcutHandler(store: store))
        .onChange(of: showAIPanel) { newValue in
            UserDefaults.standard.aiPanelOpen = newValue
        }
    }

    private var activeFileURL: URL? {
        guard let entry = library.activeEntry else { return nil }
        let url = entry.resolveURL()
        url?.startAccessingSecurityScopedResource()
        return url
    }

    /// Reads the pattern text synchronously from the resolved URL for the AI panel.
    private var loadedPatternText: String? {
        guard let url = activeFileURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Keyboard Shortcut Handler

struct KeyboardShortcutHandler: NSViewRepresentable {
    @ObservedObject var store: CounterStore

    func makeNSView(context: Context) -> KeyHandlerView {
        let view = KeyHandlerView()
        view.store = store
        return view
    }

    func updateNSView(_ nsView: KeyHandlerView, context: Context) {
        nsView.store = store
    }
}

class KeyHandlerView: NSView {
    var store: CounterStore?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let store = store else { super.keyDown(with: event); return }
        let mods = event.modifierFlags.intersection([.command, .option, .control])
        guard mods.isEmpty else { super.keyDown(with: event); return }

        switch event.keyCode {
        case 126: store.incrementRow()
        case 125: store.decrementRow()
        case 124: store.incrementStitch()
        case 123: store.decrementStitch()
        default:
            switch event.charactersIgnoringModifiers {
            case "R": store.incrementRow()
            case "r": store.decrementRow()
            case "S": store.incrementStitch()
            case "s": store.decrementStitch()
            default: super.keyDown(with: event)
            }
        }
    }
}

#Preview {
    ContentView(library: PatternLibrary(), store: CounterStore())
        .frame(width: 1100, height: 700)
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add "CrochetApp/CrochetApp/CounterBarView.swift" \
        "CrochetApp/CrochetApp/ContentView.swift" && \
git commit -m "feat: wire AI panel toggle into ContentView and CounterBarView"
```

---

## Task 7: Smoke test

- [ ] **Step 1: Build and run on macOS**

Open the project in Xcode and run on Mac, or use:

```bash
xcodebuild build -scheme CrochetApp \
  -project "/Users/ryancalpin/Documents/App Development/CrochetApp/CrochetApp/CrochetApp.xcodeproj" \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 2: Verify AI panel toggle**

On a Mac running macOS 15.1+:
- Open CrochetApp
- Confirm the "✦ AI" button appears in the counter bar (right side)
- Click it — the AI panel slides in from the right at 280pt width
- Click it again — the panel slides out with spring animation
- Close and reopen the app — panel open/closed state is restored from UserDefaults

On a Mac running macOS 13 or 14:
- Confirm the "✦ AI" button is NOT visible in the counter bar

- [ ] **Step 3: Verify AI features with a loaded pattern**

Open a Markdown crochet pattern file. Open the AI panel.

Check each section:
- **Summary** — spinner appears briefly, then shows Pattern, Level, Materials, Total Rows, Est. Time, Key Stitches fields
- **Abbreviations** — shows a list of `abbr — meaning` rows; if pattern is UK-convention, shows orange "Using UK convention" note
- **Ask a Question** — type "What stitch is used in row 1?" and press Enter; answer appears in history list above input
- **Materials** — shows Yarn, Hook, Notions labeled rows
- **Difficulty** — shows a single line like "Beginner — ..."
- **US ↔ UK Conversion** — shows scrollable converted pattern text beginning with "Converted from US to UK:" or vice versa
- **Stitch Count Verifier** — either "All rows verified" with green checkmark, or ⚠ row issues
- **Yarn Substitution** — shows numbered list of 2–3 generic alternatives
- **Time Estimate** — shows "~X.X hours remaining at your current pace." with optional density note

- [ ] **Step 4: Verify Regenerate buttons**

Click the ↺ (Regenerate) button on any section — spinner re-appears, result is re-fetched and re-displayed.

- [ ] **Step 5: Verify Writing Tools (no implementation needed)**

In any Notes or inline text editor in the app (if TextEditor views exist), select some text and right-click. Confirm the macOS 15+ Writing Tools popover (Proofread, Rewrite, Summarize) appears automatically. This requires no implementation — it is provided free by macOS 15+ in any `TextEditor` or `NSTextView`.

- [ ] **Step 6: Commit any smoke-test fixes**

```bash
cd "/Users/ryancalpin/Documents/App Development/CrochetApp" && \
git add -A && \
git commit -m "fix: post-smoke-test corrections for Apple Intelligence panel"
```
