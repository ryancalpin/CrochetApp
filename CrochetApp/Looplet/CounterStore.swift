import Foundation
import Combine
import AppKit

class CounterStore: ObservableObject {
    @Published var rowCount: Int = 0
    @Published var stitchCount: Int = 0
    @Published var repeatCount: Int = 0

    weak var library: PatternLibrary?

    private var autoReset: Bool { AppSettings.shared.autoResetStitches }

    // MARK: - Load from pattern entry

    func load(from entry: PatternEntry) {
        rowCount = entry.rowCount
        stitchCount = entry.stitchCount
        repeatCount = entry.repeatCount
    }

    func reset() {
        rowCount = 0
        stitchCount = 0
        repeatCount = 0
        sync()
    }

    // MARK: - Row actions

    func incrementRow() {
        rowCount += 1
        if autoReset { stitchCount = 0 }
        if AppSettings.shared.audioCueEnabled {
            NSSound(named: "Tink")?.play()
        }
        sync()
    }

    func endRow() {
        rowCount += 1
        stitchCount = 0
        sync()
    }

    func decrementRow() {
        guard rowCount > 0 else { return }
        rowCount -= 1
        if autoReset { stitchCount = 0 }
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

    // MARK: - Repeat actions

    func incrementRepeat() {
        repeatCount += 1
        sync()
    }

    func decrementRepeat() {
        guard repeatCount > 0 else { return }
        repeatCount -= 1
        sync()
    }

    func resetRepeat() {
        repeatCount = 0
        sync()
    }

    // MARK: - Private

    private func sync() {
        library?.updateActiveCounters(row: rowCount, stitch: stitchCount, repeat: repeatCount, autoReset: autoReset)
    }
}
