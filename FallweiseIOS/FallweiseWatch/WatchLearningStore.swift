import Foundation
import Observation
import WatchKit

@MainActor @Observable
final class WatchLearningStore {
    enum Mode {
        case daily, articleQuiz

        var title: String { self == .daily ? "MEANING PRACTICE" : "ARTICLE PRACTICE" }
        var instruction: String { self == .daily ? "Recall what the German word means" : "Choose der, die, or das" }
    }

    private(set) var vocabulary: [WatchLevel: [WatchWord]] = [:]
    private(set) var learnedWords: Set<String> = []
    private(set) var reviews: [String: WatchReview] = [:]
    private(set) var phoneDueWordIDs: Set<String> = []
    private(set) var practiceDays: [String: WatchPracticeDay] = [:]
    var level: WatchLevel = .A1
    var mode: Mode = .daily
    var index = 0
    var revealed = false
    var dailyWords: [WatchWord] = []
    var articleOptions: [String] = ["der", "die", "das"]
    var selectedArticle: String?
    var answerWasCorrect: Bool?
    private(set) var isTransitioning = false

    private let learnedKey = "fallweise.watch.learned"
    private let reviewsKey = "fallweise.watch.reviews"
    private let levelKey = "fallweise.watch.level"
    private let dayKey = "fallweise.watch.daily-date"
    private let dailyKey = "fallweise.watch.daily-ids"
    private let practiceKey = "fallweise.watch.practice-days"

    init() {
        for level in WatchLevel.allCases {
            if let url = Bundle.main.url(forResource: "\(level.rawValue.lowercased())-vocabulary", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(WatchVocabularyData.self, from: data) {
                vocabulary[level] = decoded.items
            }
        }
        learnedWords = Set(UserDefaults.standard.stringArray(forKey: learnedKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: reviewsKey),
           let saved = try? JSONDecoder().decode([String: WatchReview].self, from: data) { reviews = saved }
        if let data = UserDefaults.standard.data(forKey: practiceKey),
           let saved = try? JSONDecoder().decode([WatchPracticeDay].self, from: data) {
            practiceDays = Dictionary(uniqueKeysWithValues: saved.map { ($0.day, $0) })
        }
        level = WatchLevel(rawValue: UserDefaults.standard.string(forKey: levelKey) ?? "") ?? .A1
        refreshDailyWords()
        WatchSyncService.shared.start(store: self)
    }

    var currentWord: WatchWord? {
        guard !dailyWords.isEmpty else { return nil }
        return dailyWords[min(index, dailyWords.count - 1)]
    }

    var progressLabel: String { "\(min(index + 1, dailyWords.count))/\(dailyWords.count)" }
    var learnedCount: Int { (vocabulary[level] ?? []).filter { learnedWords.contains($0.id) }.count }
    var wordCount: Int { vocabulary[level]?.count ?? 0 }
    var practiceWeek: [(date: Date, day: WatchPracticeDay?)] {
        let calendar = practiceCalendar
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? calendar.startOfDay(for: .now)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (date, practiceDays[practiceDayID(date)])
        }
    }
    var completedPracticeDaysThisWeek: Int { practiceWeek.filter { $0.day?.isComplete == true }.count }

    func selectLevel(_ newLevel: WatchLevel) {
        level = newLevel
        UserDefaults.standard.set(newLevel.rawValue, forKey: levelKey)
        refreshWordsForCurrentMode(force: true)
    }

    func setMode(_ newMode: Mode) {
        mode = newMode
        index = 0
        revealed = false
        selectedArticle = nil
        answerWasCorrect = nil
        refreshWordsForCurrentMode(force: true)
    }

    func reveal() {
        revealed = true
        WKInterfaceDevice.current().play(.click)
    }

    func chooseArticle(_ article: String) {
        guard let word = currentWord, selectedArticle == nil, !isTransitioning else { return }
        selectedArticle = article
        answerWasCorrect = article == word.article
        revealed = true
        WKInterfaceDevice.current().play(article == word.article ? .success : .failure)
    }

    func rate(correct: Bool) {
        guard let word = currentWord, !isTransitioning else { return }
        isTransitioning = true
        var review = reviews[word.id] ?? WatchReview(dueAt: .now, intervalDays: 0, repetitions: 0)
        if correct {
            review.repetitions += 1
            review.intervalDays = review.repetitions == 1 ? 1 : min(max(2, review.intervalDays * 2), 30)
            review.dueAt = Calendar.current.date(byAdding: .minute, value: Int(review.intervalDays * 1_440), to: .now) ?? .now
            learnedWords.insert(word.id)
            WKInterfaceDevice.current().play(.success)
        } else {
            review.repetitions = 0
            review.intervalDays = 0
            review.dueAt = Calendar.current.date(byAdding: .minute, value: 10, to: .now) ?? .now
            WKInterfaceDevice.current().play(.retry)
        }
        reviews[word.id] = review
        let today = practiceDayID(.now)
        var practice = practiceDays[today] ?? WatchPracticeDay(day: today)
        practice.attempts += 1
        if correct { practice.correctAttempts += 1 }
        practice.focusedSeconds += 10
        practiceDays[today] = practice
        persist()
        WatchSyncService.shared.send(wordID: word.id, correct: correct, level: level.rawValue, practiceDay: practice)
        advance()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.isTransitioning = false
        }
    }

    func importProgress(learned: [String], selectedLevel: String?, dueWordIDs: [String] = [], practiceDays incomingDays: [WatchPracticeDay] = []) {
        let shouldReplaceSession = WatchSessionSyncPolicy.shouldReplaceSession(
            currentLevel: level.rawValue, incomingLevel: selectedLevel, hasActiveWords: !dailyWords.isEmpty
        )
        learnedWords.formUnion(learned)
        phoneDueWordIDs = Set(dueWordIDs)
        for day in incomingDays { practiceDays[day.day] = day.preferred(over: practiceDays[day.day]) }
        if let selectedLevel, let value = WatchLevel(rawValue: selectedLevel) { level = value }
        persist()
        if shouldReplaceSession { refreshWordsForCurrentMode(force: true) }
    }

    private func advance() {
        if index + 1 < dailyWords.count { index += 1 }
        else { index = 0; refreshWordsForCurrentMode(force: true) }
        revealed = false
        selectedArticle = nil
        answerWasCorrect = nil
    }

    private func refreshDailyWords(force: Bool = false) {
        let today = ISO8601DateFormatter.day.string(from: .now)
        let savedDay = UserDefaults.standard.string(forKey: dayKey)
        let all = vocabulary[level] ?? []
        if !force, savedDay == today,
           let ids = UserDefaults.standard.stringArray(forKey: dailyKey) {
            let selected = ids.compactMap { id in all.first { $0.id == id } }
            if !selected.isEmpty { dailyWords = selected; return }
        }
        let due = all.filter { phoneDueWordIDs.contains($0.id) || (reviews[$0.id]?.dueAt ?? .distantPast) <= .now }
        let unseen = due.filter { !learnedWords.contains($0.id) }
        let review = due.filter { learnedWords.contains($0.id) }
        dailyWords = Array((unseen.shuffled() + review.shuffled() + all.shuffled()).uniqued().prefix(5))
        index = 0
        UserDefaults.standard.set(today, forKey: dayKey)
        UserDefaults.standard.set(dailyWords.map(\.id), forKey: dailyKey)
    }

    private func refreshWordsForCurrentMode(force: Bool) {
        if mode == .articleQuiz {
            let nouns = (vocabulary[level] ?? []).filter(\.isNoun)
            dailyWords = Array(nouns.shuffled().prefix(5))
            index = 0
        } else {
            refreshDailyWords(force: force)
        }
    }

    private func persist() {
        UserDefaults.standard.set(Array(learnedWords), forKey: learnedKey)
        UserDefaults.standard.set(level.rawValue, forKey: levelKey)
        UserDefaults.standard.set(try? JSONEncoder().encode(reviews), forKey: reviewsKey)
        UserDefaults.standard.set(try? JSONEncoder().encode(Array(practiceDays.values)), forKey: practiceKey)
    }

    private var practiceCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    private func practiceDayID(_ date: Date) -> String {
        let parts = practiceCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

private extension ISO8601DateFormatter {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
