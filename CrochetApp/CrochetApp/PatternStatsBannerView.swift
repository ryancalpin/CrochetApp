import SwiftUI

struct PatternStatsBannerView: View {
    let entry: PatternEntry
    @ObservedObject var store: CounterStore

    var body: some View {
        HStack(spacing: 16) {
            // Pattern name
            Text(entry.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Row progress
            if let goal = entry.rowGoal, goal > 0 {
                rowProgress(current: store.rowCount, goal: goal)
            } else {
                statChip(label: "Rows", value: "\(store.rowCount)")
            }

            // Stitch count
            statChip(label: "Stitches", value: "\(store.stitchCount)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func rowProgress(current: Int, goal: Int) -> some View {
        let fraction = min(Double(current) / Double(goal), 1.0)
        let pct = Int(fraction * 100)
        return HStack(spacing: 6) {
            Text("Row \(current)/\(goal)")
                .font(.system(size: 11)).foregroundColor(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.pink.opacity(0.2)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(Color.pink)
                        .frame(width: geo.size.width * fraction, height: 5)
                }
            }
            .frame(width: 70, height: 5)
            Text("\(pct)%")
                .font(.system(size: 11, weight: .medium)).foregroundColor(.pink)
        }
    }

    private func statChip(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
        }
    }
}
