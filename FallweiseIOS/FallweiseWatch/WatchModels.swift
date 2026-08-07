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
