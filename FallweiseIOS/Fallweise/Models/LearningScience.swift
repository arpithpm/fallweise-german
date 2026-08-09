import Foundation

enum ReviewKind: String, Codable, CaseIterable {
    case meaning, article, listening, sentence, grammar, speaking

    var title: String {
        switch self {
        case .meaning: "Recall"
        case .article: "Article"
        case .listening: "Listening"
        case .sentence: "Use it"
        case .grammar: "Grammar"
        case .speaking: "Say it"
        }
    }

    var domain: String {
        switch self {
        case .meaning, .article: "vocabulary"
        case .listening: "listening"
        case .sentence, .grammar: "grammar"
        case .speaking: "speaking"
        }
    }
}

enum ExerciseFormat: String, Codable, CaseIterable {
    case recall, dictation, ordering, correction, discrimination, transfer

    var title: String {
        switch self {
        case .recall: "Recall"
        case .dictation: "Dictation"
        case .ordering: "Build the sentence"
        case .correction: "Spot and fix"
        case .discrimination: "Hear the difference"
        case .transfer: "New context"
        }
    }
}

enum RecallRating: String, Codable, CaseIterable {
    case again, hard, good, easy

    var label: String {
        switch self { case .again: "Again"; case .hard: "Hard"; case .good: "Good"; case .easy: "Easy" }
    }
}

enum RecallConfidence: Int, Codable, CaseIterable {
    case guessing = 1, unsure = 2, certain = 3

    var label: String {
        switch self { case .guessing: "Guessing"; case .unsure: "Somewhat sure"; case .certain: "Certain" }
    }
}

struct MemoryRecord: Codable, Hashable, Identifiable {
    let itemID: String
    let skillID: String
    let level: CourseLevel
    let kind: ReviewKind
    var stabilityDays: Double
    var difficulty: Double
    var repetitions: Int
    var lapses: Int
    var dueAt: Date
    var lastReviewedAt: Date?
    var attempts: Int
    var correctAttempts: Int
    var currentStreak: Int
    var averageResponseMS: Int?
    var lastConfidence: RecallConfidence?
    var lastMisconception: String?

    var id: String { itemID }
    var mastery: Double {
        guard attempts > 0 else { return 0 }
        let accuracy = Double(correctAttempts) / Double(attempts)
        let durability = min(1, log2(max(1, stabilityDays) + 1) / 6)
        return min(1, accuracy * 0.65 + durability * 0.35)
    }

    func retrievability(at date: Date = .now) -> Double {
        guard let lastReviewedAt else { return 0 }
        let elapsedDays = max(0, date.timeIntervalSince(lastReviewedAt) / 86_400)
        return exp(-elapsedDays / max(0.15, stabilityDays))
    }

    static func new(for item: AdaptiveReviewItem) -> MemoryRecord {
        MemoryRecord(
            itemID: item.id, skillID: item.skillID, level: item.level, kind: item.kind,
            stabilityDays: 0, difficulty: 5, repetitions: 0, lapses: 0,
            dueAt: .now, lastReviewedAt: nil, attempts: 0, correctAttempts: 0,
            currentStreak: 0, averageResponseMS: nil, lastConfidence: nil,
            lastMisconception: nil
        )
    }
}

struct ReviewOutcome: Codable, Hashable {
    let itemID: String
    let skillID: String
    let lessonID: String?
    let level: CourseLevel
    let kind: ReviewKind
    let correct: Bool
    let rating: RecallRating
    let confidence: RecallConfidence
    let hintsUsed: Int
    let responseMS: Int
    let answer: String
    let misconception: String?
    let attemptedAt: Date
    let format: ExerciseFormat?

    init(itemID: String, skillID: String, lessonID: String?, level: CourseLevel, kind: ReviewKind,
         correct: Bool, rating: RecallRating, confidence: RecallConfidence, hintsUsed: Int,
         responseMS: Int, answer: String, misconception: String?, attemptedAt: Date,
         format: ExerciseFormat? = nil) {
        self.itemID = itemID; self.skillID = skillID; self.lessonID = lessonID; self.level = level; self.kind = kind
        self.correct = correct; self.rating = rating; self.confidence = confidence; self.hintsUsed = hintsUsed
        self.responseMS = responseMS; self.answer = answer; self.misconception = misconception
        self.attemptedAt = attemptedAt; self.format = format
    }
}

struct AdaptiveReviewItem: Identifiable, Hashable {
    let id: String
    let skillID: String
    let level: CourseLevel
    let kind: ReviewKind
    let prompt: String
    let cue: String
    let expected: [String]
    let displayAnswer: String
    let audioText: String
    let hints: [String]
    let explanation: String
    let lessonID: String?
    let word: VocabularyItem?

    var requiresArticleChoice: Bool { kind == .article }
    var isSpeaking: Bool { kind == .speaking }
    var format: ExerciseFormat {
        if kind == .listening { return id.hashValue.isMultiple(of: 2) ? .dictation : .discrimination }
        if kind == .sentence { return id.hashValue.isMultiple(of: 2) ? .ordering : .transfer }
        if kind == .grammar { return id.hashValue.isMultiple(of: 2) ? .correction : .ordering }
        if kind == .speaking { return .transfer }
        return .recall
    }
}

enum AdaptiveScheduler {
    static func update(_ existing: MemoryRecord?, item: AdaptiveReviewItem, outcome: ReviewOutcome, now: Date = .now, calibration: Double = 1) -> MemoryRecord {
        var memory = existing ?? .new(for: item)
        memory.attempts += 1
        memory.lastReviewedAt = now
        memory.lastConfidence = outcome.confidence
        memory.lastMisconception = outcome.misconception
        if let average = memory.averageResponseMS {
            memory.averageResponseMS = Int(Double(average) * 0.75 + Double(outcome.responseMS) * 0.25)
        } else {
            memory.averageResponseMS = outcome.responseMS
        }

        if outcome.correct {
            memory.correctAttempts += 1
            memory.currentStreak += 1
            memory.repetitions += 1
            let confidenceAdjustment = outcome.confidence == .certain ? 0.88 : outcome.confidence == .guessing ? 1.1 : 1
            let hintPenalty = 1 + Double(outcome.hintsUsed) * 0.15
            memory.difficulty = min(10, max(1, memory.difficulty * confidenceAdjustment * hintPenalty))
            let base = memory.stabilityDays == 0 ? 1.0 : memory.stabilityDays
            let growth: Double
            switch outcome.rating {
            case .again: growth = 0.2
            case .hard: growth = 1.25
            case .good: growth = 2.25 + Double(memory.currentStreak) * 0.08
            case .easy: growth = 3.4 + Double(memory.currentStreak) * 0.12
            }
            memory.stabilityDays = min(3_650, max(0.25, base * growth * (11 - memory.difficulty) / 6 * min(1.25, max(0.7, calibration))))
            let interval = memory.stabilityDays * (outcome.rating == .hard ? 0.55 : 0.9)
            memory.dueAt = now.addingTimeInterval(max(4 * 3_600, interval * 86_400))
        } else {
            memory.currentStreak = 0
            memory.repetitions = 0
            memory.lapses += 1
            memory.difficulty = min(10, memory.difficulty + 0.7)
            memory.stabilityDays = max(0.12, memory.stabilityDays * 0.28)
            memory.dueAt = now.addingTimeInterval(outcome.hintsUsed > 1 ? 5 * 60 : 10 * 60)
        }
        return memory
    }

    static func inferredRating(correct: Bool, confidence: RecallConfidence, hints: Int, responseMS: Int) -> RecallRating {
        guard correct else { return .again }
        if hints > 0 || confidence == .guessing || responseMS > 12_000 { return .hard }
        if confidence == .certain && responseMS < 4_500 { return .easy }
        return .good
    }
}

enum AnswerEvaluator {
    struct Result: Hashable {
        let correct: Bool
        let misconception: String?
        let feedback: String
    }

    static func evaluate(_ answer: String, expected: [String], kind: ReviewKind = .grammar) -> Result {
        let answerTokens = tokens(answer)
        let candidates = expected.map(tokens)
        if candidates.contains(answerTokens) || candidates.contains(where: { containsPhrase(answerTokens, $0) }) {
            return Result(correct: true, misconception: nil, feedback: "Exactly right.")
        }

        guard let target = candidates.min(by: { distance(answerTokens, $0) < distance(answerTokens, $1) }), !target.isEmpty else {
            return Result(correct: false, misconception: "no_answer", feedback: "Give the complete German answer.")
        }
        let articles = Set(["der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer"])
        let answerArticle = answerTokens.first(where: articles.contains)
        let targetArticle = target.first(where: articles.contains)
        if answerArticle != targetArticle, targetArticle != nil {
            return Result(correct: false, misconception: "article_or_case", feedback: "The meaning is close. Check the article or case: use \(targetArticle!).")
        }
        if Set(answerTokens) == Set(target), answerTokens != target {
            return Result(correct: false, misconception: "word_order", feedback: "You have the right words. Put them in this order: \(target.joined(separator: " ")).")
        }
        if distance(answerTokens, target) <= 1 {
            return Result(correct: false, misconception: "form", feedback: "Almost. One form needs changing: \(target.joined(separator: " ")).")
        }
        let label = kind == .speaking ? "Say the complete thought" : "Build it once more"
        return Result(correct: false, misconception: "meaning_or_form", feedback: "\(label): \(target.joined(separator: " ")).")
    }

    static func normalize(_ value: String) -> String { tokens(value).joined(separator: " ") }

    private static func tokens(_ value: String) -> [String] {
        let germanNormalized = value.lowercased().replacingOccurrences(of: "ß", with: "ss")
        let folded = germanNormalized.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de"))
        let cleaned = String(folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : Character(" ")
        })
        return cleaned.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }

    private static func containsPhrase(_ source: [String], _ target: [String]) -> Bool {
        guard source.count >= target.count else { return false }
        return (0...(source.count - target.count)).contains { Array(source[$0..<($0 + target.count)]) == target }
    }

    private static func distance(_ lhs: [String], _ rhs: [String]) -> Int {
        var row = Array(0...rhs.count)
        for (i, left) in lhs.enumerated() {
            var next = [i + 1] + Array(repeating: 0, count: rhs.count)
            for (j, right) in rhs.enumerated() {
                next[j + 1] = min(next[j] + 1, row[j + 1] + 1, row[j] + (left == right ? 0 : 1))
            }
            row = next
        }
        return row[rhs.count]
    }
}

enum ReviewItemFactory {
    static func vocabulary(_ word: VocabularyItem, level: CourseLevel, kind: ReviewKind) -> AdaptiveReviewItem {
        let prefix = "word:\(level.rawValue):\(word.id)"
        switch kind {
        case .article:
            return AdaptiveReviewItem(id: "\(prefix):article", skillID: "\(prefix):article", level: level, kind: kind,
                prompt: "Which article belongs to this noun?", cue: word.de, expected: [word.article], displayAnswer: word.display,
                audioText: word.display, hints: [genderHint(word.article), "It begins with \(word.article.prefix(1))."],
                explanation: "Learn the article as part of the noun: \(word.display).", lessonID: nil, word: word)
        case .listening:
            return AdaptiveReviewItem(id: "\(prefix):listening", skillID: "\(prefix):listening", level: level, kind: kind,
                prompt: "Listen, then type the German you heard.", cue: "Audio only", expected: [word.display, word.de], displayAnswer: word.display,
                audioText: word.display, hints: [word.en, "The German begins with \(word.de.prefix(1))."],
                explanation: "Connect the sound directly to its meaning: \(word.en).", lessonID: nil, word: word)
        case .sentence, .speaking:
            return AdaptiveReviewItem(id: "\(prefix):\(kind.rawValue)", skillID: "\(prefix):sentence", level: level, kind: kind,
                prompt: kind == .speaking ? "Say this complete thought in German." : "Write this complete thought in German.", cue: word.exampleEn,
                expected: [word.example], displayAnswer: word.example, audioText: word.example,
                hints: ["Use \(word.display).", firstWords(word.example)], explanation: "The word is easier to retrieve inside a useful sentence.",
                lessonID: nil, word: word)
        default:
            return AdaptiveReviewItem(id: "\(prefix):meaning", skillID: "\(prefix):meaning", level: level, kind: .meaning,
                prompt: "Recall the German before revealing it.", cue: word.en, expected: [word.display, word.de], displayAnswer: word.display,
                audioText: word.display, hints: [word.type == "noun" ? "Include the article." : "Think of the scene where you use it.", "It begins with \(word.de.prefix(1))."],
                explanation: word.type == "noun" ? "Say the article and noun as one memory." : "Retrieve the German without choices.", lessonID: nil, word: word)
        }
    }

    static func grammar(_ step: LessonStep, lesson: VoiceLesson) -> AdaptiveReviewItem? {
        guard !step.answers.isEmpty else { return nil }
        let kind: ReviewKind = step.kind.contains("SPEAK") || step.kind.contains("TRANSFER") ? .speaking : .grammar
        return AdaptiveReviewItem(
            id: "lesson:\(lesson.level.rawValue):\(lesson.id):\(step.id)", skillID: "lesson:\(lesson.level.rawValue):\(lesson.id)",
            level: lesson.level, kind: kind, prompt: step.prompt, cue: step.visual, expected: step.answers,
            displayAnswer: step.answers.first ?? step.visual, audioText: step.answers.first ?? step.visual,
            hints: [step.hint, "Model: \(step.answers.first ?? step.visual)"], explanation: lesson.goal,
            lessonID: lesson.id, word: step.word
        )
    }

    static func transfer(_ source: AdaptiveReviewItem) -> AdaptiveReviewItem? {
        let swaps: [(String, String)] = [
            ("Berlin", "Hamburg"), ("Zug", "Bus"), ("Hund", "Mann"), ("Frau", "Mutter"),
            ("Mann", "Vater"), ("Buch", "Haus"), ("Auto", "Fahrrad"), ("Kaffee", "Tee"),
            ("Montag", "Dienstag"), ("zehn", "elf"), ("Morgen", "Nachmittag"), ("Abend", "Morgen")
        ]
        guard let swap = swaps.first(where: { source.displayAnswer.localizedCaseInsensitiveContains($0.0) }) else { return nil }
        let answer = source.displayAnswer.replacingOccurrences(of: swap.0, with: swap.1, options: .caseInsensitive)
        guard answer != source.displayAnswer else { return nil }
        return AdaptiveReviewItem(
            id: source.id + ":transfer:\(swap.1.lowercased())", skillID: source.skillID,
            level: source.level, kind: .speaking, prompt: "Use the same pattern in a new context.",
            cue: "Change \(swap.0) to \(swap.1).", expected: [answer], displayAnswer: answer,
            audioText: answer, hints: ["Keep the structure; replace only \(swap.0).", "Model begins: \(answer.split(separator: " ").prefix(2).joined(separator: " ")) …"],
            explanation: "Changing one detail shows that you understand the pattern rather than memorising one sentence.",
            lessonID: source.lessonID, word: source.word
        )
    }

    private static func genderHint(_ article: String) -> String {
        switch article { case "der": "Use the masculine memory character."; case "die": "Use the feminine memory character."; default: "Use the neuter memory character." }
    }

    private static func firstWords(_ sentence: String) -> String {
        "It begins: " + sentence.split(separator: " ").prefix(2).joined(separator: " ") + " …"
    }
}

enum ExerciseGenerator {
    static func scrambledWords(for item: AdaptiveReviewItem) -> [String] {
        let words = item.displayAnswer.split(separator: " ").map(String.init)
        guard words.count > 2 else { return words.reversed() }
        let pivot = max(1, words.count / 2)
        return Array(words[pivot...]) + Array(words[..<pivot])
    }

    static func incorrectSentence(for item: AdaptiveReviewItem) -> String {
        var words = item.displayAnswer.split(separator: " ").map(String.init)
        let articleSwaps = ["der": "die", "die": "das", "das": "der", "den": "der", "dem": "den"]
        if let index = words.firstIndex(where: { articleSwaps[$0.lowercased()] != nil }), let replacement = articleSwaps[words[index].lowercased()] {
            words[index] = replacement
        } else if words.count > 2 {
            words.swapAt(0, 1)
        }
        return words.joined(separator: " ")
    }

    static func listeningOptions(for item: AdaptiveReviewItem, vocabulary: [VocabularyItem]) -> [String] {
        let distractors = vocabulary.filter { $0.id != item.word?.id && $0.type == item.word?.type }.prefix(2).map(\.display)
        return ([item.displayAnswer] + distractors).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
