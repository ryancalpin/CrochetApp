import Foundation
import Combine

class CounterStore: ObservableObject {
    @Published var rowCount: Int = 0
    @Published var stitchCount: Int = 0
    @Published var autoResetStitch: Bool = true

    weak var library: PatternLibrary?

    // MARK: - Load from pattern entry

    func load(from entry: PatternEntry) {
        rowCount = entry.rowCount
        stitchCount = entry.stitchCount
        autoResetStitch = entry.autoResetStitch
    }

    func reset() {
        rowCount = 0
        stitchCount = 0
        sync()
    }

    // MARK: - Row actions

    func incrementRow() {
        rowCount += 1
        if autoResetStitch { stitchCount = 0 }
        sync()
    }

    func decrementRow() {
        guard rowCount > 0 else { return }
        rowCount -= 1
        if autoResetStitch { stitchCount = 0 }
        sync()
    }

    // MARK: - Stitch actions

    func incrementStitch() {
        stitchCount += 1
        if let goal = library?.activeEntry?.stitchGoal, goal > 0, stitchCount >= goal {
            rowCount += 1
            stitchCount = 0
        }
        sync()
    }

    func decrementStitch() {
        guard stitchCount > 0 else { return }
        stitchCount -= 1
        sync()
    }

    // MARK: - Private

    private func sync() {
        library?.updateActiveCounters(row: rowCount, stitch: stitchCount, autoReset: autoResetStitch)
    }
}
