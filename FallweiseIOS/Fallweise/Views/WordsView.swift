import SwiftUI

struct WordsView: View {
    @Environment(LearningStore.self) private var store
    @State private var search = ""
    @State private var expanded: Set<String> = []

    private var units: [VocabularyUnit] {
        guard !search.isEmpty else { return store.vocabulary.units }
        let query = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return store.vocabulary.units.filter { unit in
            "\(unit.title) \(unit.goal) \(unit.items.map { "\($0.de) \($0.en)" }.joined(separator: " "))"
                .folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppPageHeader(kicker: "Visual vocabulary", title: "Remember words", subtitle: "Browse by topic, then learn in five-word illustrated sets.")
                    LevelSelector()
                    progressCard
                    LazyVStack(spacing: 11) {
                        ForEach(units) { unit in unitCard(unit) }
                    }
                    if units.isEmpty { ContentUnavailableView.search(text: search) }
                }.padding(20).padding(.bottom, 16)
            }
            .navigationTitle("Words")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "German or English word")
            .onChange(of: store.selectedLevel) { expanded.removeAll(); search = "" }
            .fallweiseBackground()
        }
    }

    private var progressCard: some View {
        HStack(spacing: 15) {
            ZStack { Circle().fill(FallweiseTheme.blue); Text("\(store.learnedCount)").font(.title2.bold()) }.frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(store.learnedCount) of \(store.wordCount) encountered").font(.headline)
                ProgressView(value: Double(store.strongMemoryCount), total: Double(max(1, store.wordCount))).tint(FallweiseTheme.green)
                Text("\(store.strongMemoryCount) durable memories · \(store.dueReviewCount) reviews due").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(17).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
    }

    private func unitCard(_ unit: VocabularyUnit) -> some View {
        let sessions = store.vocabularyLessons.filter { $0.unit?.id == unit.id }
        let learned = unit.items.filter { store.learnedWords.contains($0.id) }.count
        return VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    if expanded.contains(unit.id) { expanded.remove(unit.id) } else { expanded.insert(unit.id) }
                }
            } label: {
                HStack(spacing: 13) {
                    Text(unit.icon).font(.title).frame(width: 42, height: 42).background(.white, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(unit.title).font(.headline)
                        Text(unit.goal).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(learned)/\(unit.items.count)").font(.caption.bold()).foregroundStyle(FallweiseTheme.green)
                        Image(systemName: expanded.contains(unit.id) ? "chevron.up" : "chevron.down").font(.caption)
                    }
                }.padding(16)
            }.buttonStyle(.plain)
            if expanded.contains(unit.id) {
                VStack(spacing: 9) {
                    ForEach(sessions) { lesson in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("SET \((lesson.batch ?? 0) + 1) · WORDS \((lesson.batch ?? 0) * 5 + 1)–\((lesson.batch ?? 0) * 5 + 5)").font(.caption2.bold()).foregroundStyle(FallweiseTheme.coral)
                                    Text(setPreview(lesson)).font(.caption).lineLimit(2)
                                }
                                Spacer(); LessonStatusBadge(lesson: lesson)
                            }
                            LessonModeButtons(lesson: lesson)
                        }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    }
                }.padding(10)
            }
        }
        .background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(FallweiseTheme.ink.opacity(0.1)))
    }

    private func setPreview(_ lesson: VoiceLesson) -> String {
        lesson.steps.compactMap(\.word).map(\.display).prefix(5).joined(separator: " · ")
    }
}
