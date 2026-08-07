import Foundation
import Observation

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
    private(set) var vocabulary: VocabularyData
    private(set) var lessons: [VoiceLesson]
    private(set) var progress: [String: SavedLesson] = [:]
    private(set) var learnedWords: Set<String> = []
    var selectedLessonID: String
    var showingJourney = false
    var errorMessage: String?

    private let progressKey = "fallweise.ios.lesson-progress"
    private let wordsKey = "fallweise.ios.learned-words"
    private let selectedKey = "fallweise.ios.selected-lesson"

    init() {
        let loaded = (try? CurriculumLoader.loadVocabulary()) ?? VocabularyData(units: [], items: [], count: 0)
        vocabulary = loaded
        let generated = CurriculumLoader.lessons(from: loaded)
        lessons = generated
        selectedLessonID = UserDefaults.standard.string(forKey: selectedKey) ?? generated.first?.id ?? ""
        loadLocal()
        Task { await sync() }
    }

    var selectedLesson: VoiceLesson { lessons.first(where: { $0.id == selectedLessonID }) ?? lessons[0] }
    var selectedIndex: Int { lessons.firstIndex(where: { $0.id == selectedLessonID }) ?? 0 }
    var learnedCount: Int { learnedWords.count }
    var completedCount: Int { progress.values.filter { $0.status == "completed" }.count }
    var coreLessons: [VoiceLesson] { lessons.filter { $0.unit == nil } }
    var vocabularyLessons: [VoiceLesson] { lessons.filter { $0.unit != nil } }
    var completedCoreCount: Int { coreLessons.filter { progress[lessonID($0)]?.status == "completed" }.count }

    func select(_ lesson: VoiceLesson) {
        selectedLessonID = lesson.id
        UserDefaults.standard.set(lesson.id, forKey: selectedKey)
        showingJourney = false
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
        if correct { learnedWords.insert(word.id) }
        UserDefaults.standard.set(Array(learnedWords), forKey: wordsKey)
    }

    func save(lesson: VoiceLesson, step: Int, complete: Bool) async {
        let row = SavedLesson(lessonID: lessonID(lesson), status: complete ? "completed" : "in_progress", mastery: Double(step + 1) / Double(lesson.steps.count), currentStep: step + 1, totalSteps: lesson.steps.count, completedAt: complete ? .now : nil)
        progress[row.lessonID] = row
        saveLocal()
        do { try await SupabaseService.shared.saveLesson(row) } catch { errorMessage = "Saved on this iPhone. Cloud sync will retry later." }
    }

    func lessonID(_ lesson: VoiceLesson) -> String { "voice-tutor:A1:\(lesson.id)" }

    private func loadLocal() {
        if let data = UserDefaults.standard.data(forKey: progressKey), let rows = try? JSONDecoder.api.decode([SavedLesson].self, from: data) { progress = Dictionary(uniqueKeysWithValues: rows.map { ($0.lessonID, $0) }) }
        learnedWords = Set(UserDefaults.standard.stringArray(forKey: wordsKey) ?? [])
    }

    private func saveLocal() { UserDefaults.standard.set(try? JSONEncoder.api.encode(Array(progress.values)), forKey: progressKey) }

    private func sync() async {
        do {
            let rows = try await SupabaseService.shared.fetchVoiceLessons()
            for row in rows {
                let local = progress[row.lessonID]
                if local == nil || row.status == "completed" || row.lastActivityAt > local!.lastActivityAt { progress[row.lessonID] = row }
            }
            saveLocal()
        } catch { errorMessage = "Offline mode · progress stays on this iPhone" }
    }
}
