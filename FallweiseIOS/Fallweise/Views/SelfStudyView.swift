import SwiftUI

struct SelfStudyView: View {
    @Environment(LearningStore.self) private var store
    @StateObject private var pronunciation = PronunciationService()
    @State private var stepIndex = 0
    @State private var revealed = false
    @State private var finished = false

    private var lesson: VoiceLesson { store.selectedLesson }
    private var step: LessonStep { lesson.steps[min(stepIndex, lesson.steps.count - 1)] }
    private var needsRecall: Bool { !step.answers.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                progress
                if finished { completionCard } else { studyCard }
            }
            .padding(20)
        }
        .onAppear { resetForSelection(); pronunciation.prepare(pronunciationTexts) }
        .onChange(of: store.selectedLessonID) { resetForSelection(); pronunciation.prepare(pronunciationTexts) }
        .onChange(of: stepIndex) { pronunciation.prepare(pronunciationTexts) }
        .onChange(of: revealed) { pronunciation.prepare(pronunciationTexts) }
        .onDisappear { pronunciation.stop() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: "Study myself · \(store.selectedLevel.rawValue)")
                Text("fallweise.").font(.title2.bold())
            }
            Spacer()
            Button { store.setMode(.voice) } label: { Image(systemName: "waveform.and.mic") }
                .buttonStyle(.bordered).accessibilityLabel("Learn this lesson with Mia")
            Button { store.leaveLesson(for: .learn) } label: { Image(systemName: "map") }
                .buttonStyle(.bordered).accessibilityLabel("Open \(store.selectedLevel.rawValue) curriculum")
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(positionLabel).font(.caption2.bold()).tracking(1).foregroundStyle(FallweiseTheme.green)
                Spacer()
                Text("\(stepIndex + 1)/\(lesson.steps.count)").font(.caption.bold()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(stepIndex + 1), total: Double(lesson.steps.count)).tint(FallweiseTheme.coral)
            Text(lesson.title).font(.title.bold())
            Text(lesson.goal).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var studyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Kicker(text: step.kind)
                Spacer()
                Button { playPronunciation() } label: {
                    Label(audioLabel, systemImage: pronunciation.state == .playing ? "waveform" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .disabled(pronunciation.state == .loading)
            }

            if let audioError = pronunciation.errorMessage {
                Label(audioError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let word = step.word {
                VocabularyMemoryScene(word: word)
            }

            Text(step.visual)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
            Text(step.hint).font(.body).foregroundStyle(.secondary)

            if needsRecall {
                Text(step.prompt).font(.headline)
                if revealed {
                    VStack(alignment: .leading, spacing: 7) {
                        Kicker(text: "Answer")
                        Text(step.answers.first ?? "")
                            .font(.system(size: 27, weight: .bold, design: .serif))
                            .foregroundStyle(FallweiseTheme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18).background(FallweiseTheme.lime.opacity(0.32), in: RoundedRectangle(cornerRadius: 18))
                    HStack {
                        Button("Still learning") { recordAndAdvance(correct: false) }.buttonStyle(.bordered)
                        Button("I knew it") { recordAndAdvance(correct: true) }
                            .buttonStyle(.borderedProminent).tint(FallweiseTheme.green)
                    }.frame(maxWidth: .infinity)
                } else {
                    Button { withAnimation { revealed = true } } label: {
                        Label("Reveal answer", systemImage: "eye.fill").frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
                }
            } else {
                Text(step.prompt).font(.body)
                Button { advance() } label: {
                    Label("Continue", systemImage: "arrow.right").frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
            }

            if stepIndex > 0 {
                Button { goBack() } label: { Label("Previous activity", systemImage: "arrow.left") }
                    .font(.subheadline).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(FallweiseTheme.ink.opacity(0.16)))
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(FallweiseTheme.green)
            Kicker(text: "Lesson complete")
            Text("You finished \(lesson.title)").font(.system(size: 30, weight: .bold, design: .serif))
            Text("Your progress is saved here and synced to your Fallweise account.").foregroundStyle(.secondary)
            if let next = store.nextLesson() {
                Button { store.select(next, mode: .selfStudy); resetForSelection() } label: {
                    Label("Next: \(next.title)", systemImage: "arrow.right").frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
            }
            Button("Choose another chapter") { store.leaveLesson(for: .learn) }.buttonStyle(.bordered)
            Button("Continue with Mia") { store.setMode(.voice) }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
    }

    private var positionLabel: String {
        if let start = lesson.wordStart { return "\(lesson.level.rawValue) WORDS \(start + 1)–\(start + 5) OF \(store.wordCount)" }
        return "\(lesson.level.rawValue) CHAPTER \((store.coreLessons.firstIndex(of: lesson) ?? 0) + 1) OF 12"
    }

    private func resetForSelection() {
        stepIndex = store.savedStep(for: lesson)
        revealed = false
        // Opening a completed lesson is an intentional review, so begin again
        // instead of trapping the learner on its completion screen.
        finished = false
        pronunciation.stop()
    }

    private func goBack() {
        guard stepIndex > 0 else { return }
        stepIndex -= 1
        revealed = false
    }

    private func recordAndAdvance(correct: Bool) {
        if let word = step.word { store.markWord(word, correct: correct) }
        advance()
    }

    private func advance() {
        Task {
            let isLast = stepIndex == lesson.steps.count - 1
            await store.save(lesson: lesson, step: stepIndex, complete: isLast)
            if isLast { withAnimation { finished = true } }
            else { stepIndex += 1; revealed = false }
        }
    }

    private var pronunciationTexts: [String] {
        if revealed, let answer = step.answers.first { return [answer] }
        if step.id == "intro", let unit = lesson.unit, let batch = lesson.batch {
            let start = batch * 5
            return Array(unit.items[start..<min(start + 5, unit.items.count)]).map(\.display)
        }
        if step.kind == "USE IT" { return [step.visual] }
        if let word = step.word { return [word.display] }
        return [step.visual.replacingOccurrences(of: "→", with: ". ").replacingOccurrences(of: "·", with: ". ")]
    }

    private var audioLabel: String {
        switch pronunciation.state {
        case .idle: "Listen"
        case .loading: "Loading"
        case .playing: "Playing"
        case .failed: "Retry"
        }
    }

    private func playPronunciation() {
        if pronunciation.state == .playing { pronunciation.stop() }
        else { Task { await pronunciation.play(pronunciationTexts) } }
    }
}
