import SwiftUI

struct AppPageHeader: View {
    let kicker: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Kicker(text: kicker)
            Text(title).font(.system(size: 38, weight: .bold, design: .serif))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LevelSelector: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CourseLevel.allCases) { level in
                Button {
                    withAnimation(.snappy) { store.selectLevel(level) }
                } label: {
                    VStack(spacing: 2) {
                        Text(level.rawValue).font(.headline)
                        Text(level.title).font(.system(size: 9, weight: .semibold)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .foregroundStyle(store.selectedLevel == level ? Color.white : FallweiseTheme.ink)
                    .background(store.selectedLevel == level ? FallweiseTheme.green : FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }
        }
        .padding(5).background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct LessonModeButtons: View {
    @Environment(LearningStore.self) private var store
    let lesson: VoiceLesson

    var body: some View {
        HStack(spacing: 10) {
            Button { store.start(lesson, mode: .selfStudy) } label: {
                Label("Study", systemImage: "book.pages.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(FallweiseTheme.ink)
            Button { store.start(lesson, mode: .voice) } label: {
                Label("Mia", systemImage: "waveform.and.mic").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(FallweiseTheme.green)
        }
    }
}

struct LessonStatusBadge: View {
    @Environment(LearningStore.self) private var store
    let lesson: VoiceLesson

    var body: some View {
        let row = store.progress[store.lessonID(lesson)]
        Group {
            if row?.status == "completed" {
                Label("Done", systemImage: "checkmark.circle.fill").foregroundStyle(FallweiseTheme.green)
            } else if row?.status == "in_progress" {
                Text("\(Int((row?.mastery ?? 0) * 100))%").foregroundStyle(FallweiseTheme.coral)
            } else {
                Text("New").foregroundStyle(.secondary)
            }
        }.font(.caption.bold())
    }
}

struct FallweiseBackground: ViewModifier {
    func body(content: Content) -> some View { content.background(FallweiseTheme.cream.ignoresSafeArea()) }
}

extension View {
    func fallweiseBackground() -> some View { modifier(FallweiseBackground()) }
}
