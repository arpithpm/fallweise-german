import SwiftUI

struct AdaptiveVoiceReviewView: View {
    @Environment(LearningStore.self) private var store
    @StateObject private var voice = VoiceService()
    @State private var index = 0
    @State private var status = "Ready when you are"
    @State private var transcript = "Mia will mix the memories that need you most."
    @State private var learnerLine = ""
    @State private var running = false
    @State private var processing = false
    @State private var speechID = ""
    @State private var attempts = 0
    @State private var correctCount = 0
    @State private var startedAt = Date.now
    @State private var advanceAfterSpeech = false

    private var items: [AdaptiveReviewItem] { store.activeReviewItems }
    private var item: AdaptiveReviewItem? { items.indices.contains(index) ? items[index] : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                progress
                miaHeader
                if let item { memoryCard(item); transcriptCard; controlButton }
                else { completionCard }
                Text("Your microphone streams for transcription. Audio recordings are not saved.")
                    .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
            }.padding(20).padding(.bottom, 30)
        }
        .fallweiseBackground()
        .navigationTitle("Mia · Today")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { configureVoice() }
        .onDisappear { Task { await voice.disconnect() } }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { Kicker(text: "Hands-free adaptive practice"); Text("fallweise.").font(.title2.bold()) }
            Spacer()
            Button { store.setMode(.adaptiveReview) } label: { Image(systemName: "keyboard") }.buttonStyle(.bordered).accessibilityLabel("Switch to typed practice")
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(item == nil ? "COMPLETE" : "MEMORY \(index + 1) OF \(items.count)").font(.caption2.bold()).tracking(1); Spacer(); Text("\(correctCount) retrieved").font(.caption) }
            ProgressView(value: Double(index), total: Double(max(1, items.count))).tint(FallweiseTheme.coral)
        }.foregroundStyle(FallweiseTheme.green)
    }

    private var miaHeader: some View {
        HStack(spacing: 13) {
            ZStack { Circle().fill(FallweiseTheme.blue); Image(systemName: "person.fill").font(.title) }.frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) { Kicker(text: "Mia · your German guide"); Text(status).font(.headline) }
            Spacer(); Circle().fill(running ? FallweiseTheme.green : .gray.opacity(0.35)).frame(width: 11, height: 11)
        }.padding(15).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22))
    }

    private func memoryCard(_ item: AdaptiveReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(item.kind.title, systemImage: item.kind == .listening ? "ear" : "brain").font(.caption.bold()).foregroundStyle(FallweiseTheme.green)
            Text(item.cue).font(.system(size: 34, weight: .bold, design: .serif)).minimumScaleFactor(0.65)
            Text(item.prompt).font(.subheadline).foregroundStyle(.secondary)
            if attempts > 0 { Text(item.hints[min(attempts - 1, item.hints.count - 1)]).font(.caption.bold()).foregroundStyle(FallweiseTheme.coral) }
        }.frame(maxWidth: .infinity, minHeight: 175, alignment: .leading).padding(22)
            .background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(FallweiseTheme.ink.opacity(0.14)))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transcript)
            if !learnerLine.isEmpty { Text("You: \(learnerLine)").fontWeight(.bold).foregroundStyle(FallweiseTheme.green) }
            if status == "I’m listening" { HStack(spacing: 4) { ForEach(0..<8) { i in Capsule().fill(FallweiseTheme.coral).frame(width: 4, height: CGFloat(8 + i % 4 * 5)) } } }
        }.font(.body).frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
    }

    private var controlButton: some View {
        Button { running ? pause() : begin() } label: {
            Label(running ? "Pause" : "Continue with Mia", systemImage: running ? "pause.fill" : "waveform.and.mic")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
        }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: "brain.head.profile.fill").font(.system(size: 48)).foregroundStyle(FallweiseTheme.green)
            Text("Memory protected").font(.title.bold())
            Text("You retrieved \(correctCount) of \(items.count) memories. Mia has scheduled each one according to how difficult it felt.").foregroundStyle(.secondary)
            Button("Back to Today") { store.showingLesson = false }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
        }.padding(24).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
    }

    private func configureVoice() {
        voice.onEvent = { event in
            switch event {
            case .ready: present()
            case .speechStarted: status = "Mia is speaking"
            case .speechFinished(let id): if id == speechID { speechFinished() }
            case .transcript(let text): learnerLine = text; evaluate(text)
            case .state(let state): if state == "speaking" { status = "I can hear you…" }
            case .failure(let message): status = "Voice unavailable"; transcript = message; running = false
            }
        }
    }

    private func begin() { Task { do { running = true; status = "Connecting to Mia"; try await voice.connect() } catch { running = false; status = "Voice unavailable"; transcript = error.localizedDescription } } }
    private func pause() { Task { await voice.interrupt(); running = false; status = "Practice paused" } }
    private func speak(_ text: String) { speechID = "adaptive-\(index)-\(UUID().uuidString)"; Task { try? await voice.speak(text, id: speechID) } }

    private func present() {
        guard let item else { return }
        processing = false; attempts = 0; learnerLine = ""; startedAt = .now
        let prompt = item.kind == .listening ? "Listen carefully: \(item.audioText). Now repeat what you heard." : "\(item.prompt) \(item.cue)"
        transcript = prompt; speak(prompt)
    }

    private func speechFinished() {
        if advanceAfterSpeech { advanceAfterSpeech = false; advance(); return }
        status = "I’m listening"; processing = false
    }

    private func evaluate(_ answer: String) {
        guard !processing, let item else { return }
        processing = true
        let evaluation = AnswerEvaluator.evaluate(answer, expected: item.expected, kind: .speaking)
        let responseMS = max(250, Int(Date.now.timeIntervalSince(startedAt) * 1_000))
        store.recordReview(item: item, correct: evaluation.correct, confidence: attempts == 0 ? .certain : .unsure,
            hintsUsed: attempts, responseMS: responseMS, answer: answer, misconception: evaluation.misconception)
        if evaluation.correct {
            correctCount += 1; advanceAfterSpeech = true
            let response = "Exactly. \(item.displayAnswer). I’ll bring it back when your memory needs it."
            transcript = response; speak(response)
        } else {
            attempts += 1
            if attempts >= 2 {
                advanceAfterSpeech = true
                let response = "The answer is \(item.displayAnswer). Say it once with me. \(item.displayAnswer)."
                transcript = response; speak(response)
            } else {
                processing = false; startedAt = .now
                let response = "\(evaluation.feedback) Here is a clue: \(item.hints.first ?? item.explanation) Try once more."
                transcript = response; speak(response)
            }
        }
    }

    private func advance() {
        index += 1; processing = false; learnerLine = ""
        if item == nil { status = "Session complete"; running = false; Task { await voice.disconnect() } }
        else { present() }
    }
}
