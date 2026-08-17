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

    func testEveryLessonAdvancesExactlyOnceAndResumesAtTheNextActivity() throws {
        for lesson in try allLessons() {
            for completedStep in lesson.steps.indices.dropLast() {
                XCTAssertEqual(LessonProgression.after(completedStep, stepCount: lesson.steps.count), .next(completedStep + 1), lesson.id)
                let row = SavedLesson.advancing(lessonID: lesson.id, completedStep: completedStep,
                    totalSteps: lesson.steps.count, complete: false)
                XCTAssertEqual(row.status, "in_progress", lesson.id)
                XCTAssertEqual(row.currentStep, completedStep + 2, lesson.id)
                XCTAssertEqual(row.resumeIndex(stepCount: lesson.steps.count), completedStep + 1, lesson.id)
            }

            let finalStep = lesson.steps.count - 1
            XCTAssertEqual(LessonProgression.after(finalStep, stepCount: lesson.steps.count), .complete, lesson.id)
            let completed = SavedLesson.advancing(lessonID: lesson.id, completedStep: finalStep,
                totalSteps: lesson.steps.count, complete: true)
            XCTAssertEqual(completed.status, "completed", lesson.id)
            XCTAssertEqual(completed.currentStep, lesson.steps.count, lesson.id)
            XCTAssertEqual(completed.resumeIndex(stepCount: lesson.steps.count), 0, lesson.id)
        }
    }

    func testProgressMergeNeverMovesBackwardEvenWhenSavesArriveOutOfOrder() {
        let lessonID = "voice-tutor:A1:01-meet-greet"
        let first = SavedLesson.advancing(lessonID: lessonID, completedStep: 0, totalSteps: 3, complete: false,
            at: Date(timeIntervalSince1970: 300))
        let second = SavedLesson.advancing(lessonID: lessonID, completedStep: 1, totalSteps: 3, complete: false,
            at: Date(timeIntervalSince1970: 200))
        let completed = SavedLesson.advancing(lessonID: lessonID, completedStep: 2, totalSteps: 3, complete: true,
            at: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(second.preferred(over: first).currentStep, 3)
        XCTAssertEqual(first.preferred(over: second).currentStep, 3)
        XCTAssertEqual(completed.preferred(over: second).status, "completed")
        XCTAssertEqual(second.preferred(over: completed).status, "completed")
    }

    func testEveryLessonAndActivityHasStableUniqueIdentityAndUsableContent() throws {
        let lessons = try allLessons()
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
        for lesson in lessons {
            XCTAssertFalse(lesson.steps.isEmpty, lesson.id)
            XCTAssertEqual(Set(lesson.steps.map(\.id)).count, lesson.steps.count, lesson.id)
            for step in lesson.steps {
                XCTAssertFalse(step.id.isEmpty, lesson.id)
                XCTAssertFalse(step.kind.isEmpty, "\(lesson.id):\(step.id)")
                XCTAssertFalse(step.visual.isEmpty, "\(lesson.id):\(step.id)")
                XCTAssertFalse(step.prompt.isEmpty, "\(lesson.id):\(step.id)")
                if !step.answers.isEmpty {
                    XCTAssertTrue(step.answers.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                        "\(lesson.id):\(step.id)")
                }
            }
        }
    }

    func testProgressRoundTripPreservesResumePosition() throws {
        let original = SavedLesson.advancing(lessonID: "voice-tutor:B1:test", completedStep: 4,
            totalSteps: 8, complete: false)
        let data = try JSONEncoder.api.encode(original)
        let restored = try JSONDecoder.api.decode(SavedLesson.self, from: data)
        XCTAssertEqual(restored.lessonID, original.lessonID)
        XCTAssertEqual(restored.status, original.status)
        XCTAssertEqual(restored.mastery, original.mastery)
        XCTAssertEqual(restored.currentStep, original.currentStep)
        XCTAssertEqual(restored.totalSteps, original.totalSteps)
        XCTAssertEqual(restored.lastActivityAt.timeIntervalSince1970, original.lastActivityAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(restored.resumeIndex(stepCount: 8), 5)
    }

    func testWatchPhoneAcknowledgementDoesNotReplaceActiveWordSession() {
        XCTAssertFalse(WatchSessionSyncPolicy.shouldReplaceSession(
            currentLevel: "A1", incomingLevel: "A1", hasActiveWords: true
        ))
        XCTAssertFalse(WatchSessionSyncPolicy.shouldReplaceSession(
            currentLevel: "A1", incomingLevel: nil, hasActiveWords: true
        ))
        XCTAssertTrue(WatchSessionSyncPolicy.shouldReplaceSession(
            currentLevel: "A1", incomingLevel: "A2", hasActiveWords: true
        ))
        XCTAssertTrue(WatchSessionSyncPolicy.shouldReplaceSession(
            currentLevel: "A1", incomingLevel: "A1", hasActiveWords: false
        ))
    }

    func testPracticeDayRequiresMeaningfulEffortForATick() {
        var day = PracticeDay(day: "2026-08-17")
        for _ in 0..<4 { day.recordAttempt(correct: true, responseMS: 12_000) }
        XCTAssertEqual(day.status, .partial)
        day.recordAttempt(correct: false, responseMS: 12_000)
        XCTAssertEqual(day.status, .complete)

        var lessonDay = PracticeDay(day: "2026-08-18")
        lessonDay.recordLessonStep(completed: true)
        XCTAssertEqual(lessonDay.status, .complete)
    }

    func testPracticeHistoryCalculatesCurrentAndBestRhythms() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!
        let complete = { (day: String) in PracticeDay(day: day, attempts: 5) }
        let days = ["2026-08-11", "2026-08-12", "2026-08-13", "2026-08-16", "2026-08-17"]
        let history = Dictionary(uniqueKeysWithValues: days.map { ($0, complete($0)) })
        XCTAssertEqual(PracticeCalendarMath.currentStreak(in: history, now: now, calendar: calendar), 2)
        XCTAssertEqual(PracticeCalendarMath.bestStreak(in: history, calendar: calendar), 3)
    }

    func testPracticeDayMergeNeverLosesCrossDeviceProgress() {
        let phone = PracticeDay(day: "2026-08-17", attempts: 4, correctAttempts: 3, lessonSteps: 2, focusedSeconds: 90)
        let watch = PracticeDay(day: "2026-08-17", attempts: 5, correctAttempts: 4, lessonSteps: 0, focusedSeconds: 50)
        let merged = phone.preferred(over: watch)
        XCTAssertEqual(merged.attempts, 5)
        XCTAssertEqual(merged.correctAttempts, 4)
        XCTAssertEqual(merged.lessonSteps, 2)
        XCTAssertEqual(merged.focusedSeconds, 90)
        XCTAssertEqual(merged.status, .complete)
    }

    private func allLessons() throws -> [VoiceLesson] {
        try CourseLevel.allCases.flatMap { level in
            CurriculumLoader.lessons(from: try CurriculumLoader.loadVocabulary(level: level), level: level)
        }
    }

    private func sampleItem(kind: ReviewKind) -> AdaptiveReviewItem {
        AdaptiveReviewItem(id: "word:A1:zug:\(kind.rawValue)", skillID: "word:A1:zug", level: .A1,
            kind: kind, prompt: "Prompt", cue: "train", expected: ["der Zug"], displayAnswer: "der Zug",
            audioText: "der Zug", hints: [], explanation: "", lessonID: nil, word: nil)
    }
}
