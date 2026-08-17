import Foundation

enum PracticeDayStatus: String, Codable, Sendable {
    case none, partial, complete
}

struct PracticeDay: Codable, Hashable, Identifiable, Sendable {
    let day: String
    var attempts: Int
    var correctAttempts: Int
    var lessonSteps: Int
    var completedLessons: Int
    var focusedSeconds: Int

    var id: String { day }
    var status: PracticeDayStatus {
        if completedLessons > 0 || attempts >= 5 { return .complete }
        if attempts > 0 || lessonSteps > 0 { return .partial }
        return .none
    }
    var accuracy: Double { attempts == 0 ? 0 : Double(correctAttempts) / Double(attempts) }
    var focusedMinutes: Int { focusedSeconds == 0 ? 0 : max(1, Int(ceil(Double(focusedSeconds) / 60))) }

    init(day: String, attempts: Int = 0, correctAttempts: Int = 0, lessonSteps: Int = 0,
         completedLessons: Int = 0, focusedSeconds: Int = 0) {
        self.day = day
        self.attempts = max(0, attempts)
        self.correctAttempts = min(max(0, correctAttempts), self.attempts)
        self.lessonSteps = max(0, lessonSteps)
        self.completedLessons = max(0, completedLessons)
        self.focusedSeconds = max(0, focusedSeconds)
    }

    mutating func recordAttempt(correct: Bool, responseMS: Int) {
        attempts += 1
        if correct { correctAttempts += 1 }
        focusedSeconds += min(180, max(10, responseMS / 1_000))
    }

    mutating func recordLessonStep(completed: Bool) {
        lessonSteps += 1
        if completed { completedLessons += 1 }
    }

    /// Daily counters are monotonic. This makes delayed cloud and Watch
    /// acknowledgements safe to apply more than once without losing progress.
    func preferred(over other: PracticeDay?) -> PracticeDay {
        guard let other else { return self }
        return PracticeDay(day: day,
            attempts: max(attempts, other.attempts),
            correctAttempts: max(correctAttempts, other.correctAttempts),
            lessonSteps: max(lessonSteps, other.lessonSteps),
            completedLessons: max(completedLessons, other.completedLessons),
            focusedSeconds: max(focusedSeconds, other.focusedSeconds))
    }
}

enum PracticeCalendarMath {
    static var calendar: Calendar {
        var value = Calendar.autoupdatingCurrent
        value.firstWeekday = 2 // Monday keeps the learning week predictable.
        return value
    }

    static func dayID(for date: Date, calendar: Calendar = calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(for dayID: String, calendar: Calendar = calendar) -> Date? {
        let values = dayID.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2]))
    }

    static func week(containing date: Date = .now, calendar: Calendar = calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func currentStreak(in days: [String: PracticeDay], now: Date = .now, calendar: Calendar = calendar) -> Int {
        var cursor = calendar.startOfDay(for: now)
        if days[dayID(for: cursor, calendar: calendar)]?.status != .complete {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days[dayID(for: cursor, calendar: calendar)]?.status == .complete {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func bestStreak(in days: [String: PracticeDay], calendar: Calendar = calendar) -> Int {
        let dates = days.values.filter { $0.status == .complete }.compactMap { date(for: $0.day, calendar: calendar) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for date in dates {
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 { run += 1 }
            else { run = 1 }
            best = max(best, run)
            previous = date
        }
        return best
    }
}
