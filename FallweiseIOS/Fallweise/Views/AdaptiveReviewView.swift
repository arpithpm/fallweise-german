import SwiftUI

struct AdaptiveReviewView: View {
    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pronunciation = PronunciationService()
    @State private var index = 0
    @State private var answer = ""
    @State private var confidence: RecallConfidence = .unsure
    @State private var hintsUsed = 0
    @State private var revealed = false
    @State private var result: AnswerEvaluator.Result?
    @State private var startedAt = Date.now
    @State private var completed = 0
    @State private var correct = 0
    @State private var orderedWords: [String] = []
    @State private var remainingWords: [String] = []

    private var items: [AdaptiveReviewItem] { store.activeReviewItems }
    private var item: AdaptiveReviewItem? { items.indices.contains(index) ? items[index] : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sessionHeader
                if let item { reviewCard(item) }
                else { completionCard }
            }.padding(20).padding(.bottom, 30)
        }
        .fallweiseBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { prepare() }
        .onChange(of: index) { resetItem(); prepare() }
        .onDisappear { pronunciation.stop() }
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Kicker(text: item == nil ? "Session complete" : "Adaptive practice")
                Spacer()
                Text("\(min(index + 1, items.count))/\(items.count)").font(.caption.bold()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(index, items.count)), total: Double(max(1, items.count))).tint(FallweiseTheme.coral)
            Text(item == nil ? "Memory protected" : "Recall before you reveal")
                .font(.system(size: 31, weight: .bold, design: .serif))
            Text("A little difficulty is useful: retrieving strengthens the memory more than rereading.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func reviewCard(_ item: AdaptiveReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Label(item.kind.title, systemImage: icon(for: item.kind)).font(.caption.bold()).foregroundStyle(FallweiseTheme.green)
                Spacer()
                Text(memoryLabel(item)).font(.caption2.bold()).foregroundStyle(.secondary)
            }
            if let word = item.word, revealed { VocabularyMemoryScene(word: word) }
            Text(item.prompt).font(.headline)
            Text(item.cue).font(.system(size: 32, weight: .bold, design: .serif)).minimumScaleFactor(0.65)

            if item.kind == .listening {
                Button { Task { await pronunciation.play(item.audioText) } } label: {
                    Label(pronunciation.state == .playing ? "Playing" : "Play audio", systemImage: "speaker.wave.2.fill")
                }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
            }

            if item.format == .discrimination && !revealed {
                VStack(spacing: 9) {
                    ForEach(ExerciseGenerator.listeningOptions(for: item, vocabulary: store.vocabulary.items), id: \.self) { option in
                        Button(option) { answer = option; check(item) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }
                }
            } else if item.format == .ordering && !revealed {
                orderingExercise(item)
            } else if item.format == .correction && !revealed {
                Text("Incorrect: \(ExerciseGenerator.incorrectSentence(for: item))").font(.headline).foregroundStyle(FallweiseTheme.coral)
                TextField("Type the corrected sentence", text: $answer, axis: .vertical)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                confidencePicker
                Button("Check correction") { check(item) }.buttonStyle(.borderedProminent).tint(FallweiseTheme.green).disabled(answer.isEmpty)
            } else if item.requiresArticleChoice && !revealed {
                HStack {
                    ForEach(["der", "die", "das"], id: \.self) { article in
                        Button(article) { answer = article; check(item) }
                            .buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
                    }
                }
            } else if !revealed {
                TextField(item.isSpeaking ? "Say it, or type to check" : "Type your answer", text: $answer, axis: .vertical)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                confidencePicker
                HStack {
                    Button { useHint(item) } label: { Label(hintsUsed == 0 ? "Give me a hint" : "Another hint", systemImage: "lightbulb") }
                        .buttonStyle(.bordered).disabled(hintsUsed >= item.hints.count)
                    Spacer()
                    Button("Check") { check(item) }.buttonStyle(.borderedProminent).tint(FallweiseTheme.green).disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if hintsUsed > 0 { Text(item.hints[hintsUsed - 1]).font(.subheadline).foregroundStyle(FallweiseTheme.coral) }
                Button("Reveal answer") { reveal(item) }.font(.caption).foregroundStyle(.secondary)
            } else {
                feedback(item)
            }
        }
        .padding(22).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(FallweiseTheme.ink.opacity(0.14)))
    }

    private func orderingExercise(_ item: AdaptiveReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(orderedWords.isEmpty ? "Tap the words in German order" : orderedWords.joined(separator: " "))
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).padding(12)
                .background(FallweiseTheme.lime.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            FlowLayout(spacing: 7) {
                ForEach(Array(remainingWords.enumerated()), id: \.offset) { index, word in
                    Button(word) { orderedWords.append(word); remainingWords.remove(at: index); answer = orderedWords.joined(separator: " ") }.buttonStyle(.bordered)
                }
            }
            HStack {
                Button("Reset") { setUpOrdering(item) }.buttonStyle(.bordered)
                Spacer()
                Button("Check") { check(item) }.buttonStyle(.borderedProminent).tint(FallweiseTheme.green).disabled(!remainingWords.isEmpty)
            }
        }
    }

    private var confidencePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Before checking, how sure are you?").font(.caption.bold())
            Picker("Confidence", selection: $confidence) {
                ForEach(RecallConfidence.allCases, id: \.self) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
        }
    }

    private func feedback(_ item: AdaptiveReviewItem) -> some View {
        let wasCorrect = result?.correct == true
        return VStack(alignment: .leading, spacing: 13) {
            Label(wasCorrect ? "Retrieved" : "Strengthening", systemImage: wasCorrect ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                .font(.headline).foregroundStyle(wasCorrect ? FallweiseTheme.green : FallweiseTheme.coral)
            Text(item.displayAnswer).font(.system(size: 29, weight: .bold, design: .serif))
            Text(result?.feedback ?? item.explanation).font(.subheadline)
            Text(item.explanation).font(.caption).foregroundStyle(.secondary)
            Button { Task { await pronunciation.play(item.audioText) } } label: { Label("Listen", systemImage: "speaker.wave.2.fill") }.buttonStyle(.bordered)
            if wasCorrect {
                Text("How difficult was that retrieval?").font(.caption.bold())
                HStack {
                    ratingButton(.hard, item: item)
                    ratingButton(.good, item: item)
                    ratingButton(.easy, item: item)
                }
            } else {
                Button("Try it again soon") { finish(item, rating: .again) }
                    .buttonStyle(.borderedProminent).tint(FallweiseTheme.ink).frame(maxWidth: .infinity)
            }
        }.padding(16).background((wasCorrect ? FallweiseTheme.lime : FallweiseTheme.coral).opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
    }

    private func ratingButton(_ rating: RecallRating, item: AdaptiveReviewItem) -> some View {
        Button(rating.label) { finish(item, rating: rating) }
            .buttonStyle(.bordered)
            .tint(rating == .good ? FallweiseTheme.green : FallweiseTheme.ink)
            .frame(maxWidth: .infinity)
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "brain.head.profile.fill").font(.system(size: 50)).foregroundStyle(FallweiseTheme.green)
            Text("You strengthened \(completed) memories.").font(.title.bold())
            Text("\(correct) were retrieved independently. Missed items are scheduled to return sooner; strong ones will wait longer.").foregroundStyle(.secondary)
            HStack {
                stat("\(correct)", "retrieved")
                stat("\(max(0, completed - correct))", "relearning")
                stat("\(store.dueReviewCount)", "still due")
            }
            if store.dueReviewCount > 0 {
                Button("Continue strengthening") { store.activeReviewItems = store.makeReviewSession(limit: min(8, store.dueReviewCount)); index = 0; completed = 0; correct = 0 }
                    .buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
            }
            Button("Back to Today") { store.showingLesson = false }.buttonStyle(.bordered)
        }.padding(24).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack { Text(value).font(.title2.bold()); Text(label).font(.caption2) }.frame(maxWidth: .infinity)
    }

    private func useHint(_ item: AdaptiveReviewItem) { if hintsUsed < item.hints.count { hintsUsed += 1 } }
    private func reveal(_ item: AdaptiveReviewItem) { result = .init(correct: false, misconception: "revealed", feedback: "Retrieval did not happen yet, so this memory will return soon."); revealed = true }
    private func check(_ item: AdaptiveReviewItem) { result = AnswerEvaluator.evaluate(answer, expected: item.expected, kind: item.kind); revealed = true }

    private func finish(_ item: AdaptiveReviewItem, rating: RecallRating) {
        let wasCorrect = result?.correct == true
        let response = max(250, Int(Date.now.timeIntervalSince(startedAt) * 1_000))
        store.recordReview(item: item, correct: wasCorrect, confidence: confidence, hintsUsed: hintsUsed, responseMS: response, answer: answer, misconception: result?.misconception, rating: rating)
        completed += 1; if wasCorrect { correct += 1 }
        withAnimation(.snappy) { index += 1 }
    }

    private func resetItem() { answer = ""; confidence = .unsure; hintsUsed = 0; revealed = false; result = nil; startedAt = .now; orderedWords = []; remainingWords = [] }
    private func prepare() { if let item { if item.format == .ordering { setUpOrdering(item) }; pronunciation.prepare(item.audioText); if item.kind == .listening { Task { await pronunciation.play(item.audioText) } } } }
    private func setUpOrdering(_ item: AdaptiveReviewItem) { orderedWords = []; remainingWords = ExerciseGenerator.scrambledWords(for: item); answer = "" }
    private func memoryLabel(_ item: AdaptiveReviewItem) -> String { let memory = store.memory(for: item); return memory.attempts == 0 ? "NEW" : "\(Int(memory.mastery * 100))% MEMORY" }
    private func icon(for kind: ReviewKind) -> String { switch kind { case .meaning: "brain"; case .article: "textformat"; case .listening: "ear"; case .sentence: "text.bubble"; case .grammar: "character.book.closed"; case .speaking: "waveform.and.mic" } }
}
