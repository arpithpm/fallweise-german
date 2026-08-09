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

    func testExerciseGeneratorCreatesDeterministicPractice() {
        let item = AdaptiveReviewItem(id: "lesson:A1:test", skillID: "test", level: .A1, kind: .grammar,
            prompt: "", cue: "", expected: ["Der Mann sieht den Hund"], displayAnswer: "Der Mann sieht den Hund",
            audioText: "", hints: [], explanation: "", lessonID: nil, word: nil)
        let words = ExerciseGenerator.scrambledWords(for: item)
        XCTAssertEqual(Set(words), Set(item.displayAnswer.split(separator: " ").map(String.init)))
        XCTAssertNotEqual(words.joined(separator: " "), item.displayAnswer)
        XCTAssertNotEqual(ExerciseGenerator.incorrectSentence(for: item), item.displayAnswer)
    }

    func testTransferChangesContextAndPreservesPattern() {
        let source = AdaptiveReviewItem(id: "sentence", skillID: "travel", level: .A1, kind: .sentence,
            prompt: "", cue: "", expected: ["Ich fahre mit dem Zug"], displayAnswer: "Ich fahre mit dem Zug",
            audioText: "", hints: [], explanation: "", lessonID: nil, word: nil)
        let transfer = ReviewItemFactory.transfer(source)
        XCTAssertEqual(transfer?.displayAnswer, "Ich fahre mit dem Bus")
        XCTAssertEqual(transfer?.kind, .speaking)
    }

    func testRolePlayFilteringRespectsLevelAndGoals() {
        let travel = RolePlayLibrary.available(for: .A1, goals: [.travel])
        XCTAssertEqual(travel.map(\.id), ["station"])
        XCTAssertTrue(RolePlayLibrary.available(for: .B1, goals: [.conversation]).contains { $0.id == "opinion" })
    }

    func testEveryCurriculumLevelBuildsCompleteNavigableLessons() throws {
        let expectedCounts: [CourseLevel: Int] = [.A1: 540, .A2: 500, .B1: 100]
        for level in CourseLevel.allCases {
            let data = try CurriculumLoader.loadVocabulary(level: level)
            XCTAssertEqual(data.count, expectedCounts[level])
            XCTAssertEqual(data.items.count, data.count)
            XCTAssertEqual(data.units.flatMap(\.items).count, data.count)
            XCTAssertTrue(data.items.allSatisfy { !$0.id.isEmpty && !$0.de.isEmpty && !$0.en.isEmpty })

            let lessons = CurriculumLoader.lessons(from: data, level: level)
            XCTAssertEqual(lessons.filter { $0.type == "VOCAB" }.count, data.units.count * 4)
            XCTAssertEqual(lessons.filter { $0.type != "VOCAB" }.count, 12)
            XCTAssertTrue(lessons.allSatisfy { !$0.title.isEmpty && !$0.goal.isEmpty && !$0.steps.isEmpty })

            let taughtWordIDs = lessons.compactMap(\.unit).flatMap { unit in
                // Each unit appears in four five-word lessons; compare unique words below.
                unit.items
            }
            XCTAssertEqual(Set(taughtWordIDs.map(\.id)), Set(data.items.map(\.id)))
        }
    }

    private func sampleItem(kind: ReviewKind) -> AdaptiveReviewItem {
        AdaptiveReviewItem(id: "word:A1:zug:\(kind.rawValue)", skillID: "word:A1:zug", level: .A1,
            kind: kind, prompt: "Prompt", cue: "train", expected: ["der Zug"], displayAnswer: "der Zug",
            audioText: "der Zug", hints: [], explanation: "", lessonID: nil, word: nil)
    }
}
