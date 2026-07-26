import Foundation

/// User-tunable durations, persisted in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    private enum Key {
        static let focus = "focusMinutes"
        static let shortBreak = "breakMinutes"
        static let longBreak = "longBreakMinutes"
        static let longBreakInterval = "longBreakIntervalMinutes"
    }

    private let store = UserDefaults.standard

    private init() {
        store.register(defaults: [
            Key.focus: 30,
            Key.shortBreak: 3,
            Key.longBreak: 10,
            Key.longBreakInterval: 60,
        ])
    }

    @Published var focusMinutes: Int = Settings.load(Key.focus) {
        didSet { store.set(focusMinutes, forKey: Key.focus) }
    }

    @Published var breakMinutes: Int = Settings.load(Key.shortBreak) {
        didSet { store.set(breakMinutes, forKey: Key.shortBreak) }
    }

    @Published var longBreakMinutes: Int = Settings.load(Key.longBreak) {
        didSet { store.set(longBreakMinutes, forKey: Key.longBreak) }
    }

    /// Minutes of accumulated focus time that earn a long "stretch your legs" break.
    @Published var longBreakIntervalMinutes: Int = Settings.load(Key.longBreakInterval) {
        didSet { store.set(longBreakIntervalMinutes, forKey: Key.longBreakInterval) }
    }

    /// Focus never shrinks below this, no matter how many breaks are skipped.
    let minFocusMinutes = 5
    /// A short break never grows past this, no matter how many breaks are skipped.
    let maxBreakMinutes = 15

    private static func load(_ key: String) -> Int {
        let defaults: [String: Int] = [
            Key.focus: 30, Key.shortBreak: 3, Key.longBreak: 10, Key.longBreakInterval: 60,
        ]
        let stored = UserDefaults.standard.integer(forKey: key)
        return stored > 0 ? stored : (defaults[key] ?? 1)
    }
}
