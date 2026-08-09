import SwiftUI

struct RolePlayView: View {
    @Environment(LearningStore.self) private var store
    @StateObject private var voice = VoiceService()
    @State private var turnIndex = 0
    @State private var status = "Ready to enter the scene"
    @State private var transcript = ""
    @State private var learnerLine = ""
    @State private var running = false
    @State private var processing = false
    @State private var speechID = ""
    @State private var retrying = false
    @State private var advanceAfterSpeech = false
    @State private var results: [(RolePlayTurn, Bool, String?)] = []

    private var scenario: RolePlayScenario? { store.selectedRolePlay }
    private var turn: RolePlayTurn? { scenario?.turns.indices.contains(turnIndex) == true ? scenario?.turns[turnIndex] : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let scenario, let turn {
                    sceneCard(scenario, turn)
                    conversation
                    control
                } else if let scenario { report(scenario) }
                else { ContentUnavailableView("Scenario unavailable", systemImage: "bubble.left.and.exclamationmark.bubble.right") }
            }.padding(20).padding(.bottom, 30)
        }.fallweiseBackground().navigationTitle("Role-play").navigationBarTitleDisplayMode(.inline)
            .onAppear { configureVoice() }.onDisappear { Task { await voice.disconnect() } }
    }

    private var header: some View {
        HStack { VStack(alignment: .leading, spacing: 3) { Kicker(text: "Structured real-world practice"); Text("Mia stays in character").font(.title2.bold()) }; Spacer(); Text(scenario?.icon ?? "💬").font(.largeTitle) }
    }

    private func sceneCard(_ scenario: RolePlayScenario, _ turn: RolePlayTurn) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text(scenario.title).font(.title.bold()); Spacer(); Text("\(turnIndex + 1)/\(scenario.turns.count)").font(.caption.bold()) }
            Text(scenario.setting).foregroundStyle(.secondary)
            Divider()
            Kicker(text: "Your communication goal")
            Text(turn.cue).font(.headline)
        }.padding(22).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) { Image(systemName: "person.fill").foregroundStyle(FallweiseTheme.green); Text(transcript.isEmpty ? "Mia will begin when you press Start." : transcript) }
            if !learnerLine.isEmpty { HStack(alignment: .top) { Image(systemName: "person.crop.circle"); Text(learnerLine).fontWeight(.semibold) } }
            if status == "I’m listening" { Label(status, systemImage: "waveform").foregroundStyle(FallweiseTheme.coral) } else { Text(status).font(.caption.bold()).foregroundStyle(.secondary) }
        }.padding(18).background(FallweiseTheme.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))
    }

    private var control: some View {
        Button { running ? pause() : begin() } label: { Label(running ? "Pause role-play" : "Enter the scene", systemImage: running ? "pause.fill" : "theatermasks.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14) }
            .buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
    }

    private func report(_ scenario: RolePlayScenario) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(FallweiseTheme.green)
            Text("Conversation complete").font(.title.bold())
            Text("You completed \(scenario.title). Here is the useful evidence from the exchange.").foregroundStyle(.secondary)
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                HStack(alignment: .top) {
                    Image(systemName: result.1 ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath").foregroundStyle(result.1 ? FallweiseTheme.green : FallweiseTheme.coral)
                    VStack(alignment: .leading) { Text(result.0.model).font(.headline); if let issue = result.2 { Text(issue.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption).foregroundStyle(.secondary) } }
                }
            }
            Button("Try this scene again") { turnIndex = 0; results = []; transcript = ""; learnerLine = "" }.buttonStyle(.bordered)
            Button("Back to Mia") { store.showingLesson = false }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
        }.padding(22).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
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
    private func pause() { Task { await voice.interrupt(); running = false; status = "Role-play paused" } }
    private func speak(_ text: String) { speechID = "role-\(turnIndex)-\(UUID().uuidString)"; Task { try? await voice.speak(text, id: speechID) } }
    private func present() { guard let turn else { return }; processing = false; retrying = false; learnerLine = ""; transcript = turn.mia; speak(turn.mia + " " + turn.cue) }
    private func speechFinished() { if advanceAfterSpeech { advanceAfterSpeech = false; advance() } else { status = "I’m listening"; processing = false } }

    private func evaluate(_ answer: String) {
        guard !processing, let turn, let scenario else { return }
        processing = true
        let evaluation = AnswerEvaluator.evaluate(answer, expected: turn.accepted, kind: .speaking)
        let item = AdaptiveReviewItem(id: "role:\(scenario.id):\(turn.id)", skillID: "role:\(scenario.id)", level: scenario.level, kind: .speaking,
            prompt: turn.cue, cue: turn.mia, expected: turn.accepted, displayAnswer: turn.model, audioText: turn.model,
            hints: [turn.correction], explanation: scenario.setting, lessonID: nil, word: nil)
        store.recordReview(item: item, correct: evaluation.correct, confidence: retrying ? .unsure : .certain, hintsUsed: retrying ? 1 : 0, responseMS: 5_000, answer: answer, misconception: evaluation.misconception)
        if evaluation.correct || retrying {
            results.append((turn, evaluation.correct, evaluation.misconception)); advanceAfterSpeech = true
            let response = evaluation.correct ? "That works naturally. \(turn.model)" : "Keep this model: \(turn.model)"
            transcript = response; speak(response)
        } else {
            retrying = true; processing = false
            let response = "\(evaluation.feedback) \(turn.correction) Try again."
            transcript = response; speak(response)
        }
    }

    private func advance() { turnIndex += 1; learnerLine = ""; processing = false; if turn == nil { status = "Scene complete"; running = false; Task { await voice.disconnect() } } else { present() } }
}
