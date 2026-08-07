import SwiftUI

struct VoiceTutorView: View {
    @Environment(LearningStore.self) private var store
    @StateObject private var voice = VoiceService()
    @State private var stepIndex = 0
    @State private var status = "Ready when you are"
    @State private var transcript = "Mia continues from your next unfinished word."
    @State private var learnerLine = ""
    @State private var running = false
    @State private var processing = false
    @State private var speechID = ""
    @State private var advanceAfterSpeech = false

    private var lesson: VoiceLesson { store.selectedLesson }
    private var step: LessonStep { lesson.steps[min(stepIndex, lesson.steps.count - 1)] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                progressHeader
                miaHeader
                if let message = store.errorMessage {
                    HStack(spacing: 8) { Image(systemName: "icloud.slash"); Text(message); Spacer(); Button("×") { store.errorMessage = nil } }
                        .font(.caption).foregroundStyle(FallweiseTheme.green).padding(12).background(FallweiseTheme.lime.opacity(0.35), in: Capsule())
                }
                lessonCard
                transcriptView
                actionButton
                Text("Your microphone streams securely for transcription. Fallweise stores progress and text answers—not recordings.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .onAppear { resetForSelection(); configureVoice() }
        .onChange(of: store.selectedLessonID) { resetForSelection() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Kicker(text: "Almost hands-free learning")
                Text("fallweise.").font(.title2.bold()).foregroundStyle(FallweiseTheme.ink)
            }
            Spacer()
            Button { store.showingJourney = true } label: {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("A1 JOURNEY").font(.caption2.bold())
                    Text("\(store.learnedCount)/540 words").font(.caption)
                }
            }.buttonStyle(.bordered)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lessonPosition)
                .font(.caption2.bold()).tracking(1.1).foregroundStyle(FallweiseTheme.green)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(FallweiseTheme.coral).frame(width: proxy.size.width * CGFloat(stepIndex + 1) / CGFloat(lesson.steps.count))
                }
            }.frame(height: 6)
        }
    }

    private var lessonPosition: String {
        if let start = lesson.wordStart { return "WORDS \(start + 1)–\(start + 5) OF 540 · ACTIVITY \(stepIndex + 1) OF \(lesson.steps.count)" }
        let chapter = (store.coreLessons.firstIndex(of: lesson) ?? 0) + 1
        return "A1 CHAPTER \(chapter) OF 12 · ACTIVITY \(stepIndex + 1) OF \(lesson.steps.count)"
    }

    private var miaHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(FallweiseTheme.blue).frame(width: 62, height: 62)
                Image(systemName: "person.fill").font(.title).foregroundStyle(FallweiseTheme.ink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Kicker(text: "Mia · your German guide")
                Text(status).font(.title3.bold())
            }
            Spacer()
            Circle().fill(running ? FallweiseTheme.green : Color.gray.opacity(0.4)).frame(width: 12, height: 12)
        }
        .padding(16).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 24))
    }

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Kicker(text: step.kind)
            Text(step.visual).font(.system(size: 35, weight: .bold, design: .serif)).minimumScaleFactor(0.65)
            Text("\(lesson.title) · \(step.hint)").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .padding(24).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(FallweiseTheme.ink.opacity(0.18)))
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transcript).font(.body)
            if !learnerLine.isEmpty { Text("You: \(learnerLine)").font(.body.bold()).foregroundStyle(FallweiseTheme.green) }
            if status == "I’m listening" {
                HStack(spacing: 4) { ForEach(0..<8) { index in Capsule().fill(FallweiseTheme.coral).frame(width: 4, height: CGFloat(8 + (index % 4) * 5)) } }
                    .accessibilityLabel("Listening")
            }
        }.frame(maxWidth: .infinity, minHeight: 65, alignment: .leading)
    }

    private var actionButton: some View {
        Button {
            if running { pause() } else { begin() }
        } label: {
            Label(running ? "Pause lesson" : "Continue with Mia", systemImage: running ? "pause.fill" : "waveform.and.mic")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(SwiftUI.Color.white)
                .background(FallweiseTheme.ink)
                .cornerRadius(22)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func configureVoice() {
        voice.onEvent = { event in
            switch event {
            case .ready: present()
            case .speechStarted: status = "Mia is speaking"
            case .speechFinished(let id): if id == speechID { speechFinished() }
            case .transcript(let text): learnerLine = text; evaluate(text)
            case .state(let value): if value == "speaking" { status = "I can hear you…" }
            case .failure(let message): status = "Voice unavailable"; transcript = message; running = false
            }
        }
    }

    private func begin() { Task { do { running = true; status = "Connecting to Mia"; try await voice.connect() } catch { running = false; status = "Voice unavailable"; transcript = error.localizedDescription } } }
    private func pause() { Task { await voice.interrupt(); running = false; status = "Lesson paused" } }
    private func present() { processing = false; transcript = step.prompt; learnerLine = ""; speak(step.prompt) }
    private func speak(_ text: String) { speechID = "\(lesson.id)-\(stepIndex)-\(UUID().uuidString)"; Task { try? await voice.speak(text, id: speechID) } }

    private func speechFinished() {
        if advanceAfterSpeech { advanceAfterSpeech = false; advance(); return }
        if step.answers.isEmpty { advance() } else { status = "I’m listening"; processing = false }
    }

    private func evaluate(_ answer: String) {
        guard !processing, !step.answers.isEmpty else { return }
        processing = true; status = "Thinking with you"
        let normalized = normalize(answer), correct = step.answers.contains { normalized.contains(normalize($0)) }
        if let word = step.word { store.markWord(word, correct: correct) }
        advanceAfterSpeech = correct
        speak(correct ? step.success : step.retry)
        if !correct { processing = false }
    }

    private func advance() {
        Task {
            if stepIndex == lesson.steps.count - 1 {
                await store.save(lesson: lesson, step: stepIndex, complete: true)
                transcript = "Great work. \(lesson.title) is complete."
                if let next = store.nextLesson() { store.select(next); resetForSelection(); try? await Task.sleep(for: .milliseconds(600)); present() }
                else { status = "A1 journey complete"; running = false; await voice.disconnect() }
            } else {
                await store.save(lesson: lesson, step: stepIndex, complete: false)
                stepIndex += 1; present()
            }
        }
    }

    private func resetForSelection() { stepIndex = store.savedStep(for: lesson); status = running ? "Mia is ready" : "Ready when you are"; transcript = "Next: \(lesson.goal)"; learnerLine = "" }
    private func normalize(_ value: String) -> String { value.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "de")).filter { $0.isLetter || $0.isWhitespace }.split(separator: " ").joined(separator: " ") }
}
