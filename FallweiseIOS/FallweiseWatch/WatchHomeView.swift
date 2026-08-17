import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchLearningStore.self) private var store
    @StateObject private var audio = WatchPronunciationService()

    var body: some View {
        NavigationStack {
            TabView {
                ReviewPage(audio: audio)
                WatchMenuView()
            }
            .tabViewStyle(.verticalPage)
            .containerBackground(WatchPalette.color(for: store.currentWord).gradient, for: .navigation)
            .onChange(of: store.index) { audio.stop() }
        }
    }
}

private struct ReviewPage: View {
    @Environment(WatchLearningStore.self) private var store
    @ObservedObject var audio: WatchPronunciationService

    var body: some View {
        ScrollView {
            if let word = store.currentWord {
                VStack(spacing: 9) {
                    HStack {
                        Text(store.mode.title)
                            .font(.system(size: 10, weight: .black)).tracking(0.8)
                        Spacer()
                        Text(store.progressLabel).font(.caption2.bold())
                    }
                    Text(store.mode.instruction)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(word.symbol ?? WatchPalette.symbol(for: word)).font(.system(size: 34))
                    if store.mode == .daily { DailyWordView(word: word, audio: audio) }
                    else { ArticleQuizView(word: word, audio: audio) }
                }
                .padding(.horizontal, 8)
            } else {
                Text("Words unavailable").foregroundStyle(.secondary)
            }
        }
    }
}

private struct DailyWordView: View {
    @Environment(WatchLearningStore.self) private var store
    let word: WatchWord
    @ObservedObject var audio: WatchPronunciationService

    var body: some View {
        VStack(spacing: 8) {
            Text(store.revealed ? word.display : word.de)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center).minimumScaleFactor(0.65)
            if store.revealed { answer }
            else {
                Text("What does it mean?").font(.caption).foregroundStyle(.secondary)
                Button("Show meaning") { store.reveal() }
                    .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
            }
        }
    }

    private var answer: some View {
        VStack(spacing: 8) {
            Text("MEANING").font(.system(size: 9, weight: .black)).tracking(0.8).foregroundStyle(.secondary)
            Text(word.en).font(.headline).foregroundStyle(.secondary)
            HStack(spacing: 7) {
                WatchAudioButton(text: word.display, audio: audio)
                Button { store.rate(correct: false) } label: {
                    VStack(spacing: 1) { Image(systemName: "arrow.counterclockwise"); Text("Again").font(.system(size: 8, weight: .bold)) }
                }
                    .tint(.orange).accessibilityLabel("Again").disabled(store.isTransitioning)
                Button { store.rate(correct: true) } label: {
                    VStack(spacing: 1) { Image(systemName: "checkmark"); Text("Got it").font(.system(size: 8, weight: .bold)) }
                }
                    .tint(.green).accessibilityLabel("Got it").disabled(store.isTransitioning)
            }.buttonStyle(.borderedProminent)
            Text(word.example).font(.caption2).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}

private struct ArticleQuizView: View {
    @Environment(WatchLearningStore.self) private var store
    let word: WatchWord
    @ObservedObject var audio: WatchPronunciationService

    var body: some View {
        VStack(spacing: 8) {
            Text("CHOOSE THE ARTICLE").font(.system(size: 9, weight: .black)).tracking(0.7).foregroundStyle(.secondary)
            Text(word.de).font(.system(size: 25, weight: .bold, design: .rounded)).minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                ForEach(store.articleOptions, id: \.self) { article in
                    Button(article) { store.chooseArticle(article) }
                        .buttonStyle(.borderedProminent)
                        .tint(tint(for: article))
                        .disabled(store.selectedArticle != nil || store.isTransitioning)
                }
            }
            if let correct = store.answerWasCorrect {
                Text(correct ? "Richtig! \(word.display)" : "It’s \(word.display)")
                    .font(.caption.bold()).multilineTextAlignment(.center)
                HStack {
                    WatchAudioButton(text: word.display, audio: audio)
                    Button { store.rate(correct: correct) } label: { Label("Next word", systemImage: "arrow.right") }
                        .buttonStyle(.borderedProminent).disabled(store.isTransitioning)
                }
            }
        }
    }

    private func tint(for article: String) -> Color {
        guard let selected = store.selectedArticle else { return .white.opacity(0.2) }
        if article == word.article { return .green }
        return article == selected ? .red : .gray.opacity(0.35)
    }
}

private struct WatchAudioButton: View {
    let text: String
    @ObservedObject var audio: WatchPronunciationService

    var body: some View {
        Button {
            if audio.isPlaying { audio.stop() }
            else { Task { await audio.play(text) } }
        } label: {
            Image(systemName: audio.isLoading ? "ellipsis" : audio.isPlaying ? "waveform" : "speaker.wave.2.fill")
        }
        .disabled(audio.isLoading).accessibilityLabel("Listen")
    }
}

private struct WatchMenuView: View {
    @Environment(WatchLearningStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("fallweise.").font(.headline)
                Text("One-minute German").font(.caption).foregroundStyle(.secondary)
                Picker("Level", selection: levelBinding) {
                    ForEach(WatchLevel.allCases) { level in Text(level.rawValue).tag(level) }
                }
                Button { store.setMode(.daily) } label: { Label("Daily five", systemImage: "sparkles") }
                Button { store.setMode(.articleQuiz) } label: { Label("Article quiz", systemImage: "questionmark.circle") }
                Text("\(store.learnedCount)/\(store.wordCount) words learned").font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 8)
        }
    }

    private var levelBinding: Binding<WatchLevel> {
        Binding(get: { store.level }, set: { store.selectLevel($0) })
    }
}

private enum WatchPalette {
    static func color(for word: WatchWord?) -> Color {
        switch word?.article {
        case "der": Color(red: 0.12, green: 0.34, blue: 0.58)
        case "die": Color(red: 0.65, green: 0.20, blue: 0.30)
        case "das": Color(red: 0.15, green: 0.42, blue: 0.31)
        default: Color(red: 0.32, green: 0.24, blue: 0.52)
        }
    }

    static func symbol(for word: WatchWord) -> String {
        switch word.article { case "der": "👨"; case "die": "👩"; case "das": "🧸"; default: "💬" }
    }
}
