import SwiftUI

struct PatternStatsBannerView: View {
    let entry: PatternEntry
    @ObservedObject var store: CounterStore
    var aiDifficulty: String? = nil
    var aiTotalRows: String? = nil

    @ObservedObject private var settings = AppSettings.shared
    private var rowColor: Color { settings.rowColor }

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let difficulty = parsedDifficulty {
                difficultyBadge(difficulty)
            } else {
                aiLoadingChip(label: "Difficulty")
            }

            if let goal = entry.rowGoal, goal > 0 {
                rowProgress(current: store.rowCount, goal: goal)
            } else {
                statChip(label: "Rows", value: "\(store.rowCount)")
            }

            if let total = aiTotalRows {
                statChip(label: "Total", value: total)
            } else {
                aiLoadingChip(label: "Total rows")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Subviews

    private func difficultyBadge(_ level: DifficultyLevel) -> some View {
        HStack(spacing: 4) {
            Circle().fill(level.color).frame(width: 6, height: 6)
            Text(level.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(level.color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(level.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func aiLoadingChip(label: String) -> some View {
        HStack(spacing: 4) {
            ProgressView().scaleEffect(0.45).frame(width: 10, height: 10)
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .opacity(0.6)
    }

    private func rowProgress(current: Int, goal: Int) -> some View {
        let fraction = min(Double(current) / Double(goal), 1.0)
        let pct = Int(fraction * 100)
        return HStack(spacing: 6) {
            Text("Row \(current)/\(goal)").font(.system(size: 11)).foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(rowColor.opacity(0.2)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(rowColor)
                        .frame(width: geo.size.width * fraction, height: 5)
                }
            }
            .frame(width: 60, height: 5)
            Text("\(pct)%").font(.system(size: 11, weight: .medium)).foregroundColor(rowColor)
        }
    }

    private func statChip(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
        }
    }

    // MARK: - Difficulty parsing

    private var parsedDifficulty: DifficultyLevel? {
        guard let d = aiDifficulty else { return nil }
        let lower = d.lowercased()
        if lower.hasPrefix("beginner") { return .beginner }
        if lower.hasPrefix("intermediate") { return .intermediate }
        if lower.hasPrefix("advanced") { return .advanced }
        return nil
    }

    enum DifficultyLevel {
        case beginner, intermediate, advanced

        var label: String {
            switch self { case .beginner: return "Beginner"; case .intermediate: return "Intermediate"; case .advanced: return "Advanced" }
        }

        var color: Color {
            switch self { case .beginner: return .green; case .intermediate: return .orange; case .advanced: return .red }
        }
    }
}
