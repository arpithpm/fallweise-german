import Foundation

struct VocabularyData: Codable {
    let units: [VocabularyUnit]
    let items: [VocabularyItem]
    let count: Int
}

struct VocabularyUnit: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let goal: String
    let items: [VocabularyItem]
}

struct VocabularyItem: Codable, Identifiable, Hashable {
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

    var display: String { article.isEmpty ? de : "\(article) \(de)" }
}

struct LessonStep: Identifiable, Hashable {
    let id: String
    let kind: String
    let visual: String
    let hint: String
    let prompt: String
    let answers: [String]
    let success: String
    let retry: String
    let word: VocabularyItem?
}

struct VoiceLesson: Identifiable, Hashable {
    let id: String
    let title: String
    let type: String
    let goal: String
    let unit: VocabularyUnit?
    let batch: Int?
    let wordStart: Int?
    let steps: [LessonStep]
}

enum CurriculumLoader {
    static func loadVocabulary() throws -> VocabularyData {
        guard let url = Bundle.main.url(forResource: "a1-vocabulary", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(VocabularyData.self, from: Data(contentsOf: url))
    }

    static func lessons(from data: VocabularyData) -> [VoiceLesson] {
        data.units.enumerated().flatMap { unitIndex, unit in
            (0..<4).map { batch in
                let words = Array(unit.items[(batch * 5)..<min(batch * 5 + 5, unit.items.count)])
                let introduction = LessonStep(
                    id: "intro", kind: "INTRODUCE",
                    visual: words.map(\.display).joined(separator: " · "),
                    hint: "Five new words from \(unit.title).",
                    prompt: "Here are five useful words. " + words.map { "\($0.display), \($0.en)" }.joined(separator: ". ") + ". Listen once, then retrieve them.",
                    answers: [], success: "", retry: "", word: nil
                )
                let recall = words.enumerated().map { index, word in
                    LessonStep(
                        id: word.id, kind: "SPOKEN RECALL", visual: "\(word.en) → ?",
                        hint: word.type == "noun" ? "Say the article and noun · word \(index + 1) of 5" : "Say the German · word \(index + 1) of 5",
                        prompt: "How do you say \(word.en) in German?",
                        answers: [word.display, word.de],
                        success: "Richtig. \(word.display) means \(word.en).",
                        retry: "Listen once more: \(word.display). Now say \(word.display).",
                        word: word
                    )
                }
                let use = words[0]
                let sentence = LessonStep(
                    id: "use-\(use.id)", kind: "USE IT", visual: use.example,
                    hint: "Use \(use.display) in a complete thought.",
                    prompt: "Now use one word in context. Repeat: \(use.example)",
                    answers: [use.example], success: "Excellent. \(use.example)",
                    retry: "Say the complete sentence: \(use.example)", word: use
                )
                return VoiceLesson(
                    id: "vocab-\(unit.id)-\(batch + 1)", title: "\(unit.title) · \(batch + 1)/4",
                    type: "VOCAB", goal: unit.goal, unit: unit, batch: batch,
                    wordStart: unitIndex * 20 + batch * 5,
                    steps: [introduction] + recall + [sentence]
                )
            }
        }
    }
}
