import Foundation

enum WatchLevel: String, Codable, CaseIterable, Identifiable {
    case A1, A2, B1
    var id: String { rawValue }
}

struct WatchVocabularyData: Codable {
    let units: [WatchUnit]
    let items: [WatchWord]
    let count: Int
}

struct WatchUnit: Codable {
    let id: String
    let title: String
    let icon: String
    let goal: String
    let items: [WatchWord]
}

struct WatchWord: Codable, Identifiable, Hashable {
    let id: String
    let unit: String
    let de: String
    let en: String
    let type: String
    let article: String
    let plural: String
    let example: String
    let exampleEn: String
    let unitTitle: String?
    let symbol: String?

    var display: String { article.isEmpty ? de : "\(article) \(de)" }
    var isNoun: Bool { type == "noun" && ["der", "die", "das"].contains(article) }
}

struct WatchReview: Codable {
    var dueAt: Date
    var intervalDays: Double
    var repetitions: Int
}

struct WatchPracticeDay: Codable, Hashable, Identifiable {
    let day: String
    var attempts: Int
    var correctAttempts: Int
    var lessonSteps: Int
    var completedLessons: Int
    var focusedSeconds: Int

    var id: String { day }
    var isComplete: Bool { completedLessons > 0 || attempts >= 5 }
    var isPartial: Bool { !isComplete && (attempts > 0 || lessonSteps > 0) }

    init(day: String, attempts: Int = 0, correctAttempts: Int = 0, lessonSteps: Int = 0,
         completedLessons: Int = 0, focusedSeconds: Int = 0) {
        self.day = day; self.attempts = attempts; self.correctAttempts = correctAttempts
        self.lessonSteps = lessonSteps; self.completedLessons = completedLessons; self.focusedSeconds = focusedSeconds
    }

    func preferred(over other: WatchPracticeDay?) -> WatchPracticeDay {
        guard let other else { return self }
        return WatchPracticeDay(day: day, attempts: max(attempts, other.attempts),
            correctAttempts: max(correctAttempts, other.correctAttempts), lessonSteps: max(lessonSteps, other.lessonSteps),
            completedLessons: max(completedLessons, other.completedLessons), focusedSeconds: max(focusedSeconds, other.focusedSeconds))
    }
}
