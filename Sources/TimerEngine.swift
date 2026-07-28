import Foundation
import AppKit

enum Phase: Equatable {
    /// Nothing is running: the session has been stopped.
    case idle
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

/// The pomodoro state machine.
///
/// Rules:
///  - Focus for `focusMinutes` (default 30), then a break of `breakMinutes` (default 3).
///  - Skipping a break halves the next focus block and doubles the next break.
///    Skipping again halves/doubles again, clamped by `minFocusMinutes` / `maxBreakMinutes`.
///  - Completing a break clears the escalation and returns to the defaults.
///  - Every `longBreakIntervalMinutes` of accumulated focus time (default 60), the next break
///    is upgraded to a long "stretch your legs" break of `longBreakMinutes` (default 10).
///    The long break stays owed until it is actually taken.
@MainActor
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var isPaused = false
    /// How many breaks have been skipped in a row.
    @Published private(set) var skipStreak = 0

    /// Total duration of the block currently running, for progress rings.
    private(set) var blockDuration: TimeInterval = 0
    /// Focus time banked toward the next long break.
    private var focusBanked: TimeInterval = 0

    private var deadline = Date()
    private var ticker: Timer?
    private let tick: TimeInterval = 0.5
    /// When the Mac slept or the screen locked, if we haven't come back yet.
    private var awaySince: Date?

    var onBreakStarted: ((Phase) -> Void)?
    var onBreakEnded: (() -> Void)?

    private var settings: Settings { .shared }

    private init() {}

    // MARK: - Durations

    /// Focus shrinks by half for each consecutive skipped break, floored at `minFocusMinutes`.
    var currentFocusDuration: TimeInterval {
        let full = Double(settings.focusMinutes) * 60
        let halved = full / pow(2, Double(min(skipStreak, 6)))
        return max(halved, Double(settings.minFocusMinutes) * 60)
    }

    /// Breaks double for each consecutive skipped break, capped at `maxBreakMinutes`.
    /// When a long break is owed, it is never shorter than `longBreakMinutes`.
    var currentBreakDuration: TimeInterval {
        let base = Double(settings.breakMinutes) * 60
        let doubled = min(base * pow(2, Double(min(skipStreak, 6))),
                          Double(settings.maxBreakMinutes) * 60)
        guard isLongBreakDue else { return doubled }
        return max(doubled, Double(settings.longBreakMinutes) * 60)
    }

    var isLongBreakDue: Bool {
        focusBanked >= Double(settings.longBreakIntervalMinutes) * 60
    }

    /// Progress through the current block, 0...1.
    var progress: Double {
        guard blockDuration > 0 else { return 0 }
        return min(max(1 - remaining / blockDuration, 0), 1)
    }

    /// Minutes of focus still to bank before the long break is offered.
    var minutesUntilLongBreak: Int {
        let left = Double(settings.longBreakIntervalMinutes) * 60 - focusBanked
        return max(Int(ceil(left / 60)), 0)
    }

    // MARK: - Lifecycle

    /// Called once at launch: installs the ticker and begins the first focus block.
    func boot() {
        ticker = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
        ticker?.tolerance = 0.1
        observeSleep()
        observeLock()
        startFocus()
    }

    /// Stop the session entirely. Today's stats are kept; the cycle starts clean on the next start.
    func stopSession() {
        if phase.isBreak { onBreakEnded?() }
        phase = .idle
        isPaused = false
        remaining = 0
        blockDuration = 0
        skipStreak = 0
        focusBanked = 0
    }

    func startSession() {
        guard phase == .idle else { return }
        startFocus()
    }

    private func startFocus() {
        phase = .focus
        begin(currentFocusDuration)
    }

    private func begin(_ duration: TimeInterval) {
        blockDuration = duration
        remaining = duration
        deadline = Date().addingTimeInterval(duration)
        isPaused = false
    }

    private func step() {
        guard phase != .idle, !isPaused else { return }
        remaining = max(deadline.timeIntervalSinceNow, 0)

        // A sleeping Mac stops the ticker for us; a locked screen does not. Without this the
        // ledger would charge every minute spent at the lock screen as focused time.
        if phase == .focus, awaySince == nil {
            focusBanked += tick
            Stats.shared.addFocus(tick)
        }

        guard remaining <= 0 else { return }

        if phase == .focus {
            beginBreak()
        } else {
            completeBreak()
        }
    }

    // MARK: - Transitions

    private func beginBreak() {
        phase = isLongBreakDue ? .longBreak : .shortBreak
        begin(currentBreakDuration)
        onBreakStarted?(phase)
    }

    /// The break was seen through to the end: reset the escalation.
    private func completeBreak() {
        if phase == .longBreak { focusBanked = 0 }
        skipStreak = 0
        Stats.shared.recordBreakTaken()
        onBreakEnded?()
        startFocus()
    }

    /// The break was dismissed early: shorten the next focus, lengthen the next break.
    func skipBreak() {
        guard phase.isBreak else { return }
        skipStreak = min(skipStreak + 1, 6)
        Stats.shared.recordBreakSkipped()
        onBreakEnded?()
        startFocus()
    }

    /// Jump straight to a break from the menu bar. Counts as a normal, earned break.
    func breakNow() {
        guard phase == .focus else { return }
        beginBreak()
    }

    func togglePause() {
        guard phase != .idle else { return }
        if isPaused {
            deadline = Date().addingTimeInterval(remaining)
            isPaused = false
        } else {
            remaining = max(deadline.timeIntervalSinceNow, 0)
            isPaused = true
        }
    }

    /// Back to a clean 30-minute focus block with no escalation and no banked hour.
    func resetCycle() {
        guard phase != .idle else { return }
        skipStreak = 0
        focusBanked = 0
        if phase.isBreak { onBreakEnded?() }
        startFocus()
    }

    // MARK: - Sleep and lock handling

    /// If the Mac slept (or you shut the lid) for at least one break's worth of time, you already
    /// had your break — start the focus block over instead of ambushing you on wake.
    private func observeSleep() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(forName: NSWorkspace.willSleepNotification,
                           object: nil, queue: .main) { _ in
            Task { @MainActor in self.leave() }
        }

        center.addObserver(forName: NSWorkspace.didWakeNotification,
                           object: nil, queue: .main) { _ in
            Task { @MainActor in self.returnFromAway() }
        }
    }

    /// A locked screen counts the same way a sleeping Mac does: the block you walked away from
    /// is stale, so unlocking begins a fresh one rather than resuming a half-spent countdown.
    private func observeLock() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(forName: .init("com.apple.screenIsLocked"),
                           object: nil, queue: .main) { _ in
            Task { @MainActor in self.leave() }
        }

        center.addObserver(forName: .init("com.apple.screenIsUnlocked"),
                           object: nil, queue: .main) { _ in
            Task { @MainActor in self.returnFromAway() }
        }
    }

    /// Closing the lid fires sleep *and* lock; only the first one to notice starts the clock, so
    /// the time away is counted once.
    private func leave() {
        guard awaySince == nil else { return }
        awaySince = Date()
    }

    /// Time away that is at least as long as the break you were owed counts as that break: drop
    /// the escalation and begin a clean focus block.
    private func returnFromAway() {
        guard let start = awaySince else { return }
        awaySince = nil
        guard phase != .idle else { return }
        let away = Date().timeIntervalSince(start)
        guard away >= currentBreakDuration else { return }
        skipStreak = 0
        focusBanked = max(focusBanked - away, 0)
        if phase.isBreak { onBreakEnded?() }
        startFocus()
    }
}
