import Foundation
import Observation

enum LearningMode: String {
    case voice
    case selfStudy
    case adaptiveReview
    case adaptiveVoice
}

enum SessionLength: Int, Codable, CaseIterable, Identifiable {
    case rescue = 2, normal = 8, deep = 15
    var id: Int { rawValue }
    var title: String { switch self { case .rescue: "Rescue"; case .normal: "Normal"; case .deep: "Deep" } }
    var itemLimit: Int { switch self { case .rescue: 5; case .normal: 12; case .deep: 22 } }
}

enum AppTab: Hashable {
    case home, learn, words, mia, progress
}

struct SavedLesson: Codable, Hashable {
    let userID: String?
    let lessonID: String
    let status: String
    let mastery: Double
    let currentStep: Int
    let totalSteps: Int
    let lastActivityAt: Date
    let completedAt: Date?

    init(lessonID: String, status: String, mastery: Double, currentStep: Int, totalSteps: Int, lastActivityAt: Date = .now, completedAt: Date? = nil) {
        userID = nil; self.lessonID = lessonID; self.status = status; self.mastery = mastery
        self.currentStep = currentStep; self.totalSteps = totalSteps; self.lastActivityAt = lastActivityAt; self.completedAt = completedAt
    }
}

@MainActor @Observable
final class LearningStore {
    private(set) var vocabularies: [CourseLevel: VocabularyData]
    private(set) var allLessons: [VoiceLesson]
    private(set) var progress: [String: SavedLesson] = [:]
    private(set) var learnedWords: Set<String> = []
    private(set) var memories: [String: MemoryRecord] = [:]
    private(set) var recentOutcomes: [ReviewOutcome] = []
    var selectedLevel: CourseLevel
    var selectedLessonID: String
    var learningMode: LearningMode
    var selectedTab: AppTab = .home
    var showingLesson = false
    var activeReviewItems: [AdaptiveReviewItem] = []
    var sessionLength: SessionLength
    var weeklyGoalMinutes: Int
    var errorMessage: String?

    private let progressKey = "fallweise.ios.lesson-progress"
    private let wordsKey = "fallweise.ios.learned-words"
    private let selectedKey = "fallweise.ios.selected-lesson"
    private let modeKey = "fallweise.ios.learning-mode"
    private let levelKey = "fallweise.ios.selected-level"
    private let memoriesKey = "fallweise.ios.memories.v2"
    private let outcomesKey = "fallweise.ios.review-outcomes.v2"
    private let sessionLengthKey = "fallweise.ios.session-length"
    private let weeklyGoalKey = "fallweise.ios.weekly-goal-minutes"

    init() {
        var loaded: [CourseLevel: VocabularyData] = [:]
        for level in CourseLevel.allCases {
            loaded[level] = (try? CurriculumLoader.loadVocabulary(level: level)) ?? VocabularyData(units: [], items: [], count: 0)
        }
        let generated = CourseLevel.allCases.flatMap { CurriculumLoader.lessons(from: loaded[$0]!, level: $0) }
        let initialLevel = CourseLevel(rawValue: UserDefaults.standard.string(forKey: levelKey) ?? "") ?? .A1
        let savedID = UserDefaults.standard.string(forKey: selectedKey)
        vocabularies = loaded
        allLessons = generated
        selectedLevel = initialLevel
        selectedLessonID = generated.first(where: { $0.id == savedID && $0.level == initialLevel })?.id
            ?? generated.first(where: { $0.level == initialLevel })?.id ?? ""
        learningMode = LearningMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .voice
        sessionLength = SessionLength(rawValue: UserDefaults.standard.integer(forKey: sessionLengthKey)) ?? .normal
        weeklyGoalMinutes = max(10, UserDefaults.standard.integer(forKey: weeklyGoalKey) == 0 ? 35 : UserDefaults.standard.integer(forKey: weeklyGoalKey))
        loadLocal()
        migrateLearnedWords()
        Task { await sync() }
    }

    var vocabulary: VocabularyData { vocabularies[selectedLevel]! }
    var lessons: [VoiceLesson] { allLessons.filter { $0.level == selectedLevel } }
    var selectedLesson: VoiceLesson { allLessons.first(where: { $0.id == selectedLessonID }) ?? lessons[0] }
    var selectedIndex: Int { lessons.firstIndex(where: { $0.id == selectedLessonID }) ?? 0 }
    var learnedCount: Int { vocabulary.items.filter { learnedWords.contains($0.id) }.count }
    var wordCount: Int { vocabulary.count }
    var completedCount: Int { lessons.filter { progress[lessonID($0)]?.status == "completed" }.count }
    var coreLessons: [VoiceLesson] { lessons.filter { $0.unit == nil } }
    var vocabularyLessons: [VoiceLesson] { lessons.filter { $0.unit != nil } }
    var completedCoreCount: Int { coreLessons.filter { progress[lessonID($0)]?.status == "completed" }.count }

    var recommendedLesson: VoiceLesson {
        lessons.first { progress[lessonID($0)]?.status == "in_progress" }
            ?? lessons.first { progress[lessonID($0)]?.status != "completed" }
            ?? lessons.first!
    }

    var totalLearnedCount: Int { vocabularies.values.flatMap(\.items).filter { learnedWords.contains($0.id) }.count }
    var totalWordCount: Int { vocabularies.values.reduce(0) { $0 + $1.count } }
    var totalCompletedCount: Int { allLessons.filter { progress[lessonID($0)]?.status == "completed" }.count }
    var dueReviewCount: Int { reviewCatalog.filter { isDue($0) }.count }
    var fragileCount: Int { memories.values.filter { $0.attempts > 0 && $0.mastery < 0.62 }.count }
    var strongMemoryCount: Int { memories.values.filter { $0.mastery >= 0.82 && $0.stabilityDays >= 7 }.count }
    var averageRetention: Double {
        let values = memories.values.filter { $0.attempts > 0 }.map { $0.retrievability() }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
    var practicedMinutesThisWeek: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        let outcomes = recentOutcomes.filter { $0.attemptedAt >= start }
        return Int(ceil(Double(outcomes.reduce(0) { $0 + max(10_000, $1.responseMS) }) / 60_000))
    }

    var reviewCatalog: [AdaptiveReviewItem] {
        let words = vocabulary.items.flatMap { word -> [AdaptiveReviewItem] in
            var kinds: [ReviewKind] = [.meaning, .listening, .sentence]
            if !word.article.isEmpty { kinds.insert(.article, at: 1) }
            return kinds.map { ReviewItemFactory.vocabulary(word, level: selectedLevel, kind: $0) }
        }
        let grammar = coreLessons.flatMap { lesson in lesson.steps.compactMap { ReviewItemFactory.grammar($0, lesson: lesson) } }
        return words + grammar
    }

    func memory(for item: AdaptiveReviewItem) -> MemoryRecord { memories[item.id] ?? .new(for: item) }

    func isDue(_ item: AdaptiveReviewItem, at date: Date = .now) -> Bool {
        guard let memory = memories[item.id] else { return false }
        return memory.dueAt <= date
    }

    func beginAdaptiveSession(length: SessionLength? = nil, withMia: Bool = false) {
        if let length { setSessionLength(length) }
        activeReviewItems = makeReviewSession(limit: sessionLength.itemLimit)
        learningMode = withMia ? .adaptiveVoice : .adaptiveReview
        UserDefaults.standard.set(learningMode.rawValue, forKey: modeKey)
        showingLesson = true
    }

    func makeReviewSession(limit: Int) -> [AdaptiveReviewItem] {
        let catalog = reviewCatalog
        let due = catalog.filter { isDue($0) }.sorted { memory(for: $0).dueAt < memory(for: $1).dueAt }
        let weak = catalog.filter { item in
            let memory = memories[item.id]
            return memory != nil && !isDue(item) && memory!.mastery < 0.65
        }.sorted { memory(for: $0).mastery < memory(for: $1).mastery }
        let unseen = catalog.filter { item in
            guard memories[item.id] == nil else { return false }
            if item.kind == .meaning { return true }
            guard let word = item.word else { return false }
            return learnedWords.contains(word.id)
        }
        let dueLimit = min(due.count, max(1, Int(Double(limit) * 0.55)))
        let weakLimit = min(weak.count, max(1, Int(Double(limit) * 0.2)))
        let newLimit = max(0, limit - dueLimit - weakLimit)
        var result = Array(due.prefix(dueLimit)) + Array(weak.prefix(weakLimit)) + Array(unseen.prefix(newLimit))
        if result.count < limit {
            let existing = Set(result.map(\.id))
            result += catalog.filter { !existing.contains($0.id) }.prefix(limit - result.count)
        }
        return interleaved(result)
    }

    @discardableResult
    func recordReview(item: AdaptiveReviewItem, correct: Bool, confidence: RecallConfidence, hintsUsed: Int, responseMS: Int, answer: String, misconception: String? = nil, rating explicitRating: RecallRating? = nil) -> MemoryRecord {
        let rating = explicitRating ?? AdaptiveScheduler.inferredRating(correct: correct, confidence: confidence, hints: hintsUsed, responseMS: responseMS)
        let outcome = ReviewOutcome(itemID: item.id, skillID: item.skillID, lessonID: item.lessonID, level: item.level, kind: item.kind, correct: correct, rating: rating, confidence: confidence, hintsUsed: hintsUsed, responseMS: responseMS, answer: answer, misconception: misconception, attemptedAt: .now)
        let updated = AdaptiveScheduler.update(memories[item.id], item: item, outcome: outcome)
        memories[item.id] = updated
        recentOutcomes.append(outcome)
        recentOutcomes = Array(recentOutcomes.suffix(2_000))
        if correct, let word = item.word { learnedWords.insert(word.id) }
        saveLearningState()
        PhoneWatchSyncService.shared.sendProgress()
        Task { try? await SupabaseService.shared.saveLearning(memory: updated, outcome: outcome) }
        return updated
    }

    func setSessionLength(_ length: SessionLength) {
        sessionLength = length
        UserDefaults.standard.set(length.rawValue, forKey: sessionLengthKey)
    }

    func setWeeklyGoal(_ minutes: Int) {
        weeklyGoalMinutes = min(140, max(10, minutes))
        UserDefaults.standard.set(weeklyGoalMinutes, forKey: weeklyGoalKey)
    }

    func mastery(for word: VocabularyItem) -> Double {
        let prefix = "word:\(selectedLevel.rawValue):\(word.id):"
        let values = memories.filter { $0.key.hasPrefix(prefix) }.map(\.value.mastery)
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    func weakSkills(limit: Int = 5) -> [MemoryRecord] {
        memories.values.filter { $0.attempts > 0 }.sorted {
            if $0.mastery == $1.mastery { return $0.dueAt < $1.dueAt }
            return $0.mastery < $1.mastery
        }.prefix(limit).map { $0 }
    }

    func learnedCount(for level: CourseLevel) -> Int {
        (vocabularies[level]?.items ?? []).filter { learnedWords.contains($0.id) }.count
    }

    func completedCoreCount(for level: CourseLevel) -> Int {
        allLessons.filter { $0.level == level && $0.unit == nil && progress[lessonID($0)]?.status == "completed" }.count
    }

    func completedSessionCount(for level: CourseLevel) -> Int {
        allLessons.filter { $0.level == level && progress[lessonID($0)]?.status == "completed" }.count
    }

    func start(_ lesson: VoiceLesson, mode: LearningMode) {
        select(lesson, mode: mode)
        showingLesson = true
    }

    func continueLearning(mode: LearningMode) {
        start(recommendedLesson, mode: mode)
    }

    func leaveLesson(for tab: AppTab) {
        showingLesson = false
        selectedTab = tab
    }

    func select(_ lesson: VoiceLesson, mode: LearningMode? = nil) {
        if lesson.level != selectedLevel { selectLevel(lesson.level) }
        selectedLessonID = lesson.id
        UserDefaults.standard.set(lesson.id, forKey: selectedKey)
        if let mode { setMode(mode) }
    }

    func setMode(_ mode: LearningMode) {
        learningMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    func selectLevel(_ level: CourseLevel) {
        selectedLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: levelKey)
        let currentValid = allLessons.contains { $0.id == selectedLessonID && $0.level == level }
        if !currentValid {
            let levelLessons = allLessons.filter { $0.level == level }
            let next = levelLessons.first { progress[lessonID($0)]?.status == "in_progress" }
                ?? levelLessons.first { progress[lessonID($0)]?.status != "completed" }
                ?? levelLessons.first
            selectedLessonID = next?.id ?? ""
            UserDefaults.standard.set(selectedLessonID, forKey: selectedKey)
        }
    }

    func nextLesson() -> VoiceLesson? {
        lessons.dropFirst(selectedIndex + 1).first { progress[lessonID($0)]?.status != "completed" }
            ?? lessons.first { progress[lessonID($0)]?.status != "completed" }
    }

    func savedStep(for lesson: VoiceLesson) -> Int {
        guard progress[lessonID(lesson)]?.status == "in_progress" else { return 0 }
        return max(0, min((progress[lessonID(lesson)]?.currentStep ?? 1) - 1, lesson.steps.count - 1))
    }

    func markWord(_ word: VocabularyItem, correct: Bool) {
        markWord(id: word.id, correct: correct)
    }

    func markWord(id: String, correct: Bool) {
        if correct { learnedWords.insert(id) }
        UserDefaults.standard.set(Array(learnedWords), forKey: wordsKey)
        PhoneWatchSyncService.shared.sendProgress()
    }

    func save(lesson: VoiceLesson, step: Int, complete: Bool) async {
        let row = SavedLesson(lessonID: lessonID(lesson), status: complete ? "completed" : "in_progress", mastery: Double(step + 1) / Double(lesson.steps.count), currentStep: step + 1, totalSteps: lesson.steps.count, completedAt: complete ? .now : nil)
        progress[row.lessonID] = row
        saveLocal()
        do { try await SupabaseService.shared.saveLesson(row) } catch { errorMessage = "Saved on this iPhone. Cloud sync will retry later." }
    }

    func lessonID(_ lesson: VoiceLesson) -> String { "voice-tutor:\(lesson.level.rawValue):\(lesson.id)" }

    private func loadLocal() {
        if let data = UserDefaults.standard.data(forKey: progressKey), let rows = try? JSONDecoder.api.decode([SavedLesson].self, from: data) { progress = Dictionary(uniqueKeysWithValues: rows.map { ($0.lessonID, $0) }) }
        learnedWords = Set(UserDefaults.standard.stringArray(forKey: wordsKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: memoriesKey), let saved = try? JSONDecoder.api.decode([String: MemoryRecord].self, from: data) { memories = saved }
        if let data = UserDefaults.standard.data(forKey: outcomesKey), let saved = try? JSONDecoder.api.decode([ReviewOutcome].self, from: data) { recentOutcomes = saved }
    }

    private func saveLocal() { UserDefaults.standard.set(try? JSONEncoder.api.encode(Array(progress.values)), forKey: progressKey) }

    private func saveLearningState() {
        UserDefaults.standard.set(Array(learnedWords), forKey: wordsKey)
        UserDefaults.standard.set(try? JSONEncoder.api.encode(memories), forKey: memoriesKey)
        UserDefaults.standard.set(try? JSONEncoder.api.encode(recentOutcomes), forKey: outcomesKey)
    }

    private func migrateLearnedWords() {
        var changed = false
        for level in CourseLevel.allCases {
            for word in vocabularies[level]?.items ?? [] where learnedWords.contains(word.id) {
                let item = ReviewItemFactory.vocabulary(word, level: level, kind: .meaning)
                guard memories[item.id] == nil else { continue }
                var memory = MemoryRecord.new(for: item)
                memory.stabilityDays = 1
                memory.dueAt = .now
                memory.attempts = 1
                memory.correctAttempts = 1
                memories[item.id] = memory
                changed = true
            }
        }
        if changed { saveLearningState() }
    }

    private func interleaved(_ items: [AdaptiveReviewItem]) -> [AdaptiveReviewItem] {
        var buckets = Dictionary(grouping: items, by: \.kind)
        var result: [AdaptiveReviewItem] = []
        while !buckets.isEmpty {
            for kind in ReviewKind.allCases {
                if var bucket = buckets[kind], !bucket.isEmpty {
                    result.append(bucket.removeFirst())
                    if bucket.isEmpty { buckets.removeValue(forKey: kind) } else { buckets[kind] = bucket }
                }
            }
        }
        return result
    }

    private func sync() async {
        do {
            async let lessonRows = SupabaseService.shared.fetchVoiceLessons()
            async let memoryRows = SupabaseService.shared.fetchMemories()
            let rows = try await lessonRows
            for row in rows {
                let local = progress[row.lessonID]
                if local == nil || row.status == "completed" || row.lastActivityAt > local!.lastActivityAt { progress[row.lessonID] = row }
            }
            for memory in try await memoryRows {
                let local = memories[memory.itemID]
                if local == nil || (memory.lastReviewedAt ?? .distantPast) > (local?.lastReviewedAt ?? .distantPast) {
                    memories[memory.itemID] = memory
                }
            }
            saveLocal()
            saveLearningState()
        } catch { errorMessage = "Offline mode · progress stays on this iPhone" }
    }
}
