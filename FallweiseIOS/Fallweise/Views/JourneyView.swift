import SwiftUI

struct JourneyView: View {
    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<String> = []
    @State private var section = 0
    @State private var pendingLesson: VoiceLesson?
    @State private var showingModeChoice = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Kicker(text: "Your A1 journey")
                    Text("\(store.learnedCount) of 540 words learned").font(.system(size: 34, weight: .bold, design: .serif))
                    ProgressView(value: Double(store.learnedCount), total: 540).tint(FallweiseTheme.green)
                    Text("\(store.completedCount) of \(store.lessons.count) voice sessions complete").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Curriculum", selection: $section) {
                        Text("A1 Course").tag(0)
                        Text("540 Words").tag(1)
                    }.pickerStyle(.segmented)
                    LazyVStack(spacing: 10) {
                        if section == 0 {
                            ForEach(Array(store.coreLessons.enumerated()), id: \.element.id) { index, lesson in
                                coreCard(lesson, index: index)
                            }
                        } else {
                            ForEach(store.vocabulary.units) { unit in
                                unitCard(unit)
                            }
                        }
                    }
                }.padding(20)
            }
            .background(FallweiseTheme.cream)
            .navigationTitle("Complete A1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.large])
        .confirmationDialog(
            pendingLesson?.title ?? "Choose how to learn",
            isPresented: $showingModeChoice,
            titleVisibility: .visible
        ) {
            Button("Learn with Mia") { begin(.voice) }
            Button("Study myself") { begin(.selfStudy) }
            Button("Cancel", role: .cancel) { pendingLesson = nil }
        } message: {
            Text("You can switch modes at any time. Both save to the same A1 progress.")
        }
    }

    private func coreCard(_ lesson: VoiceLesson, index: Int) -> some View {
        Button { chooseMode(for: lesson) } label: {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index + 1)).font(.title2.bold()).foregroundStyle(FallweiseTheme.coral).frame(width: 38)
                VStack(alignment: .leading, spacing: 5) { Kicker(text: lesson.type); Text(lesson.title).font(.headline); Text(lesson.goal).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                Spacer()
                if store.progress[store.lessonID(lesson)]?.status == "completed" { Image(systemName: "checkmark.circle.fill").foregroundStyle(FallweiseTheme.green) }
                else { Image(systemName: "arrow.up.right") }
            }.padding(16).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.1)))
        }.buttonStyle(.plain)
    }

    private func unitCard(_ unit: VocabularyUnit) -> some View {
        let sessions = store.lessons.filter { $0.unit?.id == unit.id }
        let learned = unit.items.filter { store.learnedWords.contains($0.id) }.count
        return VStack(spacing: 0) {
            Button { withAnimation { if expanded.contains(unit.id) { expanded.remove(unit.id) } else { expanded.insert(unit.id) } } } label: {
                HStack(spacing: 12) {
                    Text(unit.icon).font(.title)
                    VStack(alignment: .leading, spacing: 4) { Kicker(text: "Unit \((store.vocabulary.units.firstIndex(of: unit) ?? 0) + 1)"); Text(unit.title).font(.headline) }
                    Spacer()
                    Text("\(learned)/20").font(.caption.bold()).foregroundStyle(FallweiseTheme.green)
                    Image(systemName: expanded.contains(unit.id) ? "chevron.up" : "chevron.down")
                }.padding(16)
            }.buttonStyle(.plain)
            if expanded.contains(unit.id) {
                VStack(spacing: 8) {
                    ForEach(sessions) { lesson in
                        Button { chooseMode(for: lesson) } label: {
                            HStack {
                                VStack(alignment: .leading) { Text("SET \((lesson.batch ?? 0) + 1) · WORDS \((lesson.batch ?? 0) * 5 + 1)–\((lesson.batch ?? 0) * 5 + 5)").font(.caption2.bold()); Text(lesson.title).font(.subheadline.bold()) }
                                Spacer()
                                if store.progress[store.lessonID(lesson)]?.status == "completed" { Image(systemName: "checkmark.circle.fill").foregroundStyle(FallweiseTheme.green) }
                                else { Image(systemName: "arrow.up.right") }
                            }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain)
                    }
                }.padding(10)
            }
        }.background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.1)))
    }

    private func chooseMode(for lesson: VoiceLesson) {
        pendingLesson = lesson
        showingModeChoice = true
    }

    private func begin(_ mode: LearningMode) {
        guard let lesson = pendingLesson else { return }
        store.select(lesson, mode: mode)
        pendingLesson = nil
        dismiss()
    }
}
