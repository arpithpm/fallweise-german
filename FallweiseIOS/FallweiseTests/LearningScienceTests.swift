import XCTest
@testable import Fallweise

final class LearningScienceTests: XCTestCase {
    func testCorrectConfidentRecallExpandsInterval() {
        let item = sampleItem(kind: .meaning)
        let outcome = ReviewOutcome(itemID: item.id, skillID: item.skillID, lessonID: nil, level: .A1,
            kind: .meaning, correct: true, rating: .good, confidence: .certain, hintsUsed: 0,
            responseMS: 2_000, answer: "der Zug", misconception: nil, attemptedAt: .now)
        let memory = AdaptiveScheduler.update(nil, item: item, outcome: outcome)
        XCTAssertGreaterThan(memory.stabilityDays, 1)
        XCTAssertGreaterThan(memory.dueAt, Date.now.addingTimeInterval(20 * 3_600))
        XCTAssertEqual(memory.correctAttempts, 1)
    }

    func testLapseReturnsSoonAndRaisesDifficulty() {
        let item = sampleItem(kind: .article)
        var existing = MemoryRecord.new(for: item)
        existing.stabilityDays = 12
        existing.difficulty = 4
        let outcome = ReviewOutcome(itemID: item.id, skillID: item.skillID, lessonID: nil, level: .A1,
            kind: .article, correct: false, rating: .again, confidence: .certain, hintsUsed: 0,
            responseMS: 3_000, answer: "die", misconception: "article_or_case", attemptedAt: .now)
        let now = Date.now
        let memory = AdaptiveScheduler.update(existing, item: item, outcome: outcome, now: now)
        XCTAssertLessThan(memory.stabilityDays, existing.stabilityDays)
        XCTAssertGreaterThan(memory.difficulty, existing.difficulty)
        XCTAssertLessThan(memory.dueAt, now.addingTimeInterval(11 * 60))
        XCTAssertEqual(memory.lapses, 1)
    }

    func testEvaluatorDiagnosesArticleAndWordOrder() {
        let article = AnswerEvaluator.evaluate("der Hund", expected: ["den Hund"])
        XCTAssertFalse(article.correct)
        XCTAssertEqual(article.misconception, "article_or_case")

        let order = AnswerEvaluator.evaluate("Deutsch ich lerne", expected: ["Ich lerne Deutsch"])
        XCTAssertFalse(order.correct)
        XCTAssertEqual(order.misconception, "word_order")
    }

    func testEvaluatorAcceptsDiacriticsAndPunctuation() {
        let result = AnswerEvaluator.evaluate("Ich heiße Mia!", expected: ["ich heisse mia"])
        XCTAssertTrue(result.correct)
    }

    private func sampleItem(kind: ReviewKind) -> AdaptiveReviewItem {
        AdaptiveReviewItem(id: "word:A1:zug:\(kind.rawValue)", skillID: "word:A1:zug", level: .A1,
            kind: kind, prompt: "Prompt", cue: "train", expected: ["der Zug"], displayAnswer: "der Zug",
            audioText: "der Zug", hints: [], explanation: "", lessonID: nil, word: nil)
    }
}
