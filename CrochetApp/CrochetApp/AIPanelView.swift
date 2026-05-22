import SwiftUI

@available(macOS 26.0, *)
struct AIPanelView: View {
    let entry: PatternEntry
    let patternText: String
    @ObservedObject var library: PatternLibrary
    @Binding var showAIPanel: Bool
    @Binding var abbreviationDict: [String: String]
    @Binding var bannerDifficulty: String?
    @Binding var bannerTotalRows: String?

    @StateObject private var service = PatternAIService()

    @State private var summary: PatternSummary? = nil
    @State private var abbreviationList: AbbreviationList? = nil
    @State private var materials: MaterialsBreakdown? = nil
    @State private var difficulty: String? = nil
    @State private var timeEstimate: String? = nil

    @State private var summaryError: String? = nil
    @State private var abbreviationsError: String? = nil
    @State private var materialsError: String? = nil
    @State private var difficultyError: String? = nil
    @State private var timeError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AIFeatureSection(title: "Ask a Question", isLoading: false, onRegenerate: {}) {
                        PatternQAView(service: service, patternText: patternText)
                    }
                    Divider().padding(.horizontal, 12)
                    AIFeatureSection(title: "Summary", isLoading: service.isLoadingSummary, onRegenerate: regenSummary) {
                        if let s = summary { summaryContent(s) }
                        else if let e = summaryError { errorText(e) }
                        else { loadingPlaceholder }
                    }
                    Divider().padding(.horizontal, 12)
                    AIFeatureSection(title: "Abbreviations", isLoading: service.isLoadingAbbreviations, onRegenerate: regenAbbreviations) {
                        if let a = abbreviationList { abbreviationsContent(a) }
                        else if let e = abbreviationsError { errorText(e) }
                        else { loadingPlaceholder }
                    }
                    Divider().padding(.horizontal, 12)
                    AIFeatureSection(title: "Materials", isLoading: service.isLoadingMaterials, onRegenerate: regenMaterials) {
                        if let m = materials { materialsContent(m) }
                        else if let e = materialsError { errorText(e) }
                        else { loadingPlaceholder }
                    }
                    Divider().padding(.horizontal, 12)
                    AIFeatureSection(title: "Difficulty", isLoading: service.isLoadingDifficulty, onRegenerate: regenDifficulty) {
                        if let d = difficulty { Text(d).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true) }
                        else if let e = difficultyError { errorText(e) }
                        else { loadingPlaceholder }
                    }
                    Divider().padding(.horizontal, 12)
                    AIFeatureSection(title: "Time Estimate", isLoading: service.isLoadingTimeEstimate, onRegenerate: regenTime) {
                        if let t = timeEstimate { Text(t).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true) }
                        else if let e = timeError { errorText(e) }
                        else { loadingPlaceholder }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color.surfaceRaised)
        .task(id: entry.id) {
            resetAll()
            loadAll()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "sparkles").foregroundColor(.purple)
            Text("AI Assistant").font(.system(size: 13, weight: .semibold))
            Spacer()
            Button { showAIPanel = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary).font(.system(size: 16))
            }
            .buttonStyle(.plain).help("Close AI panel")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.surface)
    }

    private var loadingPlaceholder: some View {
        ProgressView().scaleEffect(0.6).frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reset / load

    private func resetAll() {
        summary = nil; abbreviationList = nil; materials = nil; difficulty = nil; timeEstimate = nil
        summaryError = nil; abbreviationsError = nil; materialsError = nil; difficultyError = nil; timeError = nil
        abbreviationDict = [:]
        bannerDifficulty = nil
        bannerTotalRows = nil
    }

    private func loadAll() {
        // Always read the freshest copy from the library to avoid a stale value-type snapshot.
        // entry.id is stable; library.entries has the authoritative persisted cache.
        let e = library.entries.first(where: { $0.id == entry.id }) ?? entry

        if let s = e.aiSummary {
            summary = s
            bannerTotalRows = s.totalRows == "Unknown" ? nil : s.totalRows
        } else {
            loadSummary()
        }

        if let a = e.aiAbbreviations {
            abbreviationList = a
            abbreviationDict = Dictionary(uniqueKeysWithValues: a.entries.map { ($0.abbreviation, $0.meaning) })
        } else {
            loadAbbreviations()
        }

        if let m = e.aiMaterials {
            materials = m
        } else {
            loadMaterials()
        }

        if let d = e.aiDifficulty {
            difficulty = d
            bannerDifficulty = d
        } else {
            loadDifficulty()
        }

        if let t = e.aiTimeEstimate {
            timeEstimate = t
        } else {
            loadTimeEstimate()
        }
    }

    private func regenSummary() {
        service.clearCache(for: entry.id)
        library.clearAICache(for: entry.id)
        summary = nil; summaryError = nil; bannerTotalRows = nil
        loadSummary()
    }
    private func regenAbbreviations() {
        service.clearCache(for: entry.id)
        library.clearAICache(for: entry.id)
        abbreviationList = nil; abbreviationsError = nil; abbreviationDict = [:]
        loadAbbreviations()
    }
    private func regenMaterials() {
        service.clearCache(for: entry.id)
        library.clearAICache(for: entry.id)
        materials = nil; materialsError = nil
        loadMaterials()
    }
    private func regenDifficulty() {
        service.clearCache(for: entry.id)
        library.clearAICache(for: entry.id)
        difficulty = nil; difficultyError = nil; bannerDifficulty = nil
        loadDifficulty()
    }
    private func regenTime() {
        service.clearCache(for: entry.id)
        library.clearAICache(for: entry.id)
        timeEstimate = nil; timeError = nil
        loadTimeEstimate()
    }

    // MARK: - Content renderers

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
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.orange).padding(.bottom, 2)
            }
            ForEach(a.entries) { abbr in
                HStack(alignment: .top, spacing: 4) {
                    Text(abbr.abbreviation).font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text("—").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(abbr.meaning).font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if a.entries.isEmpty {
                Text("No abbreviations detected.").font(.system(size: 11)).foregroundColor(.secondary)
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

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("\(label):")
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                .frame(minWidth: 70, alignment: .trailing)
            Text(value).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message).font(.system(size: 11)).foregroundColor(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Load actions

    private func loadSummary() {
        Task { do {
            let result = try await service.generateSummary(patternID: entry.id, patternText: patternText)
            summary = result
            bannerTotalRows = result.totalRows == "Unknown" ? nil : result.totalRows
            library.updateAICache(for: entry.id, summary: result)
        } catch { summaryError = error.localizedDescription } }
    }
    private func loadAbbreviations() {
        Task { do {
            let result = try await service.generateAbbreviations(patternID: entry.id, patternText: patternText)
            abbreviationList = result
            abbreviationDict = Dictionary(uniqueKeysWithValues: result.entries.map { ($0.abbreviation, $0.meaning) })
            library.updateAICache(for: entry.id, abbreviations: result)
        } catch { abbreviationsError = error.localizedDescription } }
    }
    private func loadMaterials() {
        Task { do {
            let result = try await service.extractMaterials(patternID: entry.id, patternText: patternText)
            materials = result
            library.updateAICache(for: entry.id, materials: result)
        } catch { materialsError = error.localizedDescription } }
    }
    private func loadDifficulty() {
        Task { do {
            let result = try await service.estimateDifficulty(patternID: entry.id, patternText: patternText)
            difficulty = result
            bannerDifficulty = result
            library.updateAICache(for: entry.id, difficulty: result)
        } catch { difficultyError = error.localizedDescription } }
    }
    private func loadTimeEstimate() {
        Task { do {
            let result = try await service.estimateTime(
                patternID: entry.id, patternText: patternText,
                rowGoal: entry.rowGoal ?? 0, rowCount: entry.rowCount)
            timeEstimate = result
            library.updateAICache(for: entry.id, timeEstimate: result)
        } catch { timeError = error.localizedDescription } }
    }
}
