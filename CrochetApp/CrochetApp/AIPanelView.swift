import SwiftUI

@available(macOS 26.0, *)
struct AIPanelView: View {
    let entry: PatternEntry
    let patternText: String
    @Binding var showAIPanel: Bool

    @StateObject private var service = PatternAIService()

    @State private var summary: PatternSummary? = nil
    @State private var abbreviations: AbbreviationList? = nil
    @State private var materials: MaterialsBreakdown? = nil
    @State private var difficulty: String? = nil
    @State private var conversion: String? = nil
    @State private var stitchResult: StitchCountResult? = nil
    @State private var yarnSub: String? = nil
    @State private var timeEstimate: String? = nil

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

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AIFeatureSection(title: "Summary", isLoading: service.isLoadingSummary, onRegenerate: {
                        service.clearCache(for: entry.id); summary = nil; summaryError = nil; loadSummary()
                    }) {
                        if let s = summary { summaryContent(s) }
                        else if let e = summaryError { errorText(e) }
                        else { Color.clear.onAppear { loadSummary() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Abbreviations", isLoading: service.isLoadingAbbreviations, onRegenerate: {
                        service.clearCache(for: entry.id); abbreviations = nil; abbreviationsError = nil; loadAbbreviations()
                    }) {
                        if let a = abbreviations { abbreviationsContent(a) }
                        else if let e = abbreviationsError { errorText(e) }
                        else { Color.clear.onAppear { loadAbbreviations() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Ask a Question", isLoading: false, onRegenerate: {}) {
                        PatternQAView(service: service, patternText: patternText)
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Materials", isLoading: service.isLoadingMaterials, onRegenerate: {
                        service.clearCache(for: entry.id); materials = nil; materialsError = nil; loadMaterials()
                    }) {
                        if let m = materials { materialsContent(m) }
                        else if let e = materialsError { errorText(e) }
                        else { Color.clear.onAppear { loadMaterials() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Difficulty", isLoading: service.isLoadingDifficulty, onRegenerate: {
                        service.clearCache(for: entry.id); difficulty = nil; difficultyError = nil; loadDifficulty()
                    }) {
                        if let d = difficulty {
                            Text(d).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        } else if let e = difficultyError { errorText(e) }
                        else { Color.clear.onAppear { loadDifficulty() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "US ↔ UK Conversion", isLoading: service.isLoadingConversion, onRegenerate: {
                        service.clearCache(for: entry.id); conversion = nil; conversionError = nil; loadConversion()
                    }) {
                        if let c = conversion {
                            ScrollView {
                                Text(c).font(.system(size: 11, design: .monospaced))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 180)
                        } else if let e = conversionError { errorText(e) }
                        else { Color.clear.onAppear { loadConversion() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Stitch Count Verifier", isLoading: service.isLoadingStitchVerifier, onRegenerate: {
                        service.clearCache(for: entry.id); stitchResult = nil; stitchError = nil; loadStitchVerifier()
                    }) {
                        if let r = stitchResult { stitchVerifierContent(r) }
                        else if let e = stitchError { errorText(e) }
                        else { Color.clear.onAppear { loadStitchVerifier() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Yarn Substitution", isLoading: service.isLoadingYarnSub, onRegenerate: {
                        service.clearCache(for: entry.id); yarnSub = nil; yarnSubError = nil; loadYarnSub()
                    }) {
                        if let y = yarnSub {
                            Text(y).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        } else if let e = yarnSubError { errorText(e) }
                        else { Color.clear.onAppear { loadYarnSub() } }
                    }

                    Divider().padding(.horizontal, 12)

                    AIFeatureSection(title: "Time Estimate", isLoading: service.isLoadingTimeEstimate, onRegenerate: {
                        service.clearCache(for: entry.id); timeEstimate = nil; timeError = nil; loadTimeEstimate()
                    }) {
                        if let t = timeEstimate {
                            Text(t).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        } else if let e = timeError { errorText(e) }
                        else { Color.clear.onAppear { loadTimeEstimate() } }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.bottom, 2)
            }
            ForEach(a.entries) { abbr in
                HStack(alignment: .top, spacing: 4) {
                    Text(abbr.abbreviation)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text("—").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(abbr.meaning)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if a.entries.isEmpty {
                Text("No abbreviations detected.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
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
                    .foregroundColor(.green).font(.system(size: 12))
            } else {
                ForEach(r.issues) { issue in
                    HStack(alignment: .top, spacing: 4) {
                        Text("⚠")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Row \(issue.rowNumber)").font(.system(size: 11, weight: .semibold))
                            Text(issue.description).font(.system(size: 11)).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let note = r.unverifiableNote {
                    Text(note).font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        Task { do { summary = try await service.generateSummary(patternID: entry.id, patternText: patternText) }
        catch { summaryError = error.localizedDescription } }
    }
    private func loadAbbreviations() {
        Task { do { abbreviations = try await service.generateAbbreviations(patternID: entry.id, patternText: patternText) }
        catch { abbreviationsError = error.localizedDescription } }
    }
    private func loadMaterials() {
        Task { do { materials = try await service.extractMaterials(patternID: entry.id, patternText: patternText) }
        catch { materialsError = error.localizedDescription } }
    }
    private func loadDifficulty() {
        Task { do { difficulty = try await service.estimateDifficulty(patternID: entry.id, patternText: patternText) }
        catch { difficultyError = error.localizedDescription } }
    }
    private func loadConversion() {
        Task { do { conversion = try await service.convertTerminology(patternID: entry.id, patternText: patternText) }
        catch { conversionError = error.localizedDescription } }
    }
    private func loadStitchVerifier() {
        Task { do { stitchResult = try await service.verifyStitchCounts(patternID: entry.id, patternText: patternText) }
        catch { stitchError = error.localizedDescription } }
    }
    private func loadYarnSub() {
        Task { do { yarnSub = try await service.suggestYarnSubstitutions(patternID: entry.id, patternText: patternText) }
        catch { yarnSubError = error.localizedDescription } }
    }
    private func loadTimeEstimate() {
        Task { do { timeEstimate = try await service.estimateTime(
            patternID: entry.id, patternText: patternText,
            rowGoal: entry.rowGoal ?? 0, rowCount: entry.rowCount)
        } catch { timeError = error.localizedDescription } }
    }
}
