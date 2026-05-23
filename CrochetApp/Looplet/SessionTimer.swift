import Foundation
import Combine
import AppKit

/// Tracks elapsed session time. Not persisted — resets on app relaunch.
/// Owned by LoopletApp and injected via direct pass-through.
final class SessionTimer: ObservableObject {

    // MARK: - Published

    /// Total elapsed seconds since last reset (or app launch).
    @Published private(set) var elapsed: TimeInterval = 0

    /// Whether the timer is currently running.
    @Published private(set) var isRunning: Bool = false

    // MARK: - Private

    private var timerCancellable: AnyCancellable?
    private var appObservers: [NSObjectProtocol] = []
    private var userPaused = false

    // MARK: - Init

    init() {
        startTimer()
        observeAppFocus()
    }

    deinit {
        appObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Public API

    /// Toggle pause/resume.
    func togglePause() {
        if isRunning {
            userPaused = true
            pauseTimer()
        } else {
            userPaused = false
            startTimer()
        }
    }

    /// Reset elapsed time to zero. Does not stop the timer.
    func reset() {
        elapsed = 0
    }

    // MARK: - Private

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsed += 1
            }
    }

    private func pauseTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func observeAppFocus() {
        let resign = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseTimer()
        }

        let activate = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.userPaused else { return }
            self.startTimer()
        }

        appObservers = [resign, activate]
    }
}

// MARK: - Formatting Helper

extension SessionTimer {
    /// Formats elapsed time as "m:ss" (under 1 hour) or "h:mm:ss" (1 hour+).
    var displayString: String {
        let total = Int(elapsed)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
