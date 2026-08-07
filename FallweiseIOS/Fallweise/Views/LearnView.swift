import SwiftUI

struct LearnView: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppPageHeader(kicker: "Complete course", title: "Choose your chapter", subtitle: "Follow the route or jump directly to what you need today.")
                    LevelSelector()
                    HStack {
                        Text("\(store.selectedLevel.rawValue) · 12 chapters").font(.headline)
                        Spacer()
                        Text("\(store.completedCoreCount)/12 complete").font(.caption.bold()).foregroundStyle(FallweiseTheme.green)
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(Array(store.coreLessons.enumerated()), id: \.element.id) { index, lesson in
                            chapterCard(lesson, index: index)
                        }
                    }
                }.padding(20).padding(.bottom, 16)
            }
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .fallweiseBackground()
        }
    }

    private func chapterCard(_ lesson: VoiceLesson, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", index + 1))
                    .font(.title2.bold()).foregroundStyle(FallweiseTheme.coral).frame(width: 40, height: 40)
                    .background(FallweiseTheme.coral.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Kicker(text: lesson.type)
                    Text(lesson.title).font(.title3.bold())
                    Text(lesson.goal).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(); LessonStatusBadge(lesson: lesson)
            }
            LessonModeButtons(lesson: lesson)
        }
        .padding(17).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(FallweiseTheme.ink.opacity(0.1)))
    }
}
