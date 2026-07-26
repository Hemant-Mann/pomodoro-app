import Foundation

/// Focus time and break counts, for today and for all time.
/// Today's numbers roll over automatically when the date changes.
@MainActor
final class Stats: ObservableObject {
    static let shared = Stats()

    private enum Key {
        static let day = "statsDay"
        static let todayFocus = "todayFocusSeconds"
        static let todayTaken = "todayBreaksTaken"
        static let todaySkipped = "todayBreaksSkipped"
        static let allFocus = "allFocusSeconds"
        static let allTaken = "allBreaksTaken"
        static let allSkipped = "allBreaksSkipped"
    }

    @Published private(set) var todayFocus: TimeInterval = 0
    @Published private(set) var todayTaken = 0
    @Published private(set) var todaySkipped = 0
    @Published private(set) var allFocus: TimeInterval = 0
    @Published private(set) var allTaken = 0
    @Published private(set) var allSkipped = 0

    private let store = UserDefaults.standard
    private var day: String

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static var currentDay: String { dayFormatter.string(from: Date()) }

    private init() {
        day = store.string(forKey: Key.day) ?? Stats.currentDay
        allFocus = store.double(forKey: Key.allFocus)
        allTaken = store.integer(forKey: Key.allTaken)
        allSkipped = store.integer(forKey: Key.allSkipped)

        if day == Stats.currentDay {
            todayFocus = store.double(forKey: Key.todayFocus)
            todayTaken = store.integer(forKey: Key.todayTaken)
            todaySkipped = store.integer(forKey: Key.todaySkipped)
        } else {
            day = Stats.currentDay
            persist()
        }
    }

    // MARK: - Recording

    func addFocus(_ seconds: TimeInterval) {
        rollOverIfNeeded()
        todayFocus += seconds
        allFocus += seconds
        persist()
    }

    func recordBreakTaken() {
        rollOverIfNeeded()
        todayTaken += 1
        allTaken += 1
        persist()
    }

    func recordBreakSkipped() {
        rollOverIfNeeded()
        todaySkipped += 1
        allSkipped += 1
        persist()
    }

    func resetToday() {
        todayFocus = 0
        todayTaken = 0
        todaySkipped = 0
        day = Stats.currentDay
        persist()
    }

    private func rollOverIfNeeded() {
        guard day != Stats.currentDay else { return }
        day = Stats.currentDay
        todayFocus = 0
        todayTaken = 0
        todaySkipped = 0
    }

    private func persist() {
        store.set(day, forKey: Key.day)
        store.set(todayFocus, forKey: Key.todayFocus)
        store.set(todayTaken, forKey: Key.todayTaken)
        store.set(todaySkipped, forKey: Key.todaySkipped)
        store.set(allFocus, forKey: Key.allFocus)
        store.set(allTaken, forKey: Key.allTaken)
        store.set(allSkipped, forKey: Key.allSkipped)
    }

    // MARK: - Formatting

    /// "2h 45m", or "45m" under an hour.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
