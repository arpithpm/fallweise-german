import SwiftUI

struct HomeView: View {
    @Environment(LearningStore.self) private var store
    private var lesson: VoiceLesson { store.recommendedLesson }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("fallweise.").font(.title2.bold())
                        Spacer()
                        Button { store.selectedTab = .progress } label: { Image(systemName: "person.crop.circle") }
                            .buttonStyle(.bordered).accessibilityLabel("Open progress")
                    }
                    HStack(alignment: .top) {
                        AppPageHeader(kicker: greeting, title: "Ready for one win?", subtitle: "A short lesson is enough to keep your German moving.")
                        Text("🇩🇪").font(.largeTitle)
                    }
                    LevelSelector()
                    continueCard
                    todayPlan
                    levelSnapshot
                }.padding(20).padding(.bottom, 16)
            }
            .fallweiseBackground()
        }
    }

    private var continueCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Kicker(text: store.progress[store.lessonID(lesson)] == nil ? "Recommended next" : "Continue where you stopped")
                Spacer(); LessonStatusBadge(lesson: lesson)
            }
            Text(lesson.type).font(.caption.bold()).foregroundStyle(FallweiseTheme.coral)
            Text(lesson.title).font(.system(size: 31, weight: .bold, design: .serif))
            Text(lesson.goal).foregroundStyle(.secondary)
            if let row = store.progress[store.lessonID(lesson)], row.status == "in_progress" {
                ProgressView(value: row.mastery).tint(FallweiseTheme.coral)
            }
            LessonModeButtons(lesson: lesson)
        }
        .padding(22).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(FallweiseTheme.ink.opacity(0.15)))
    }

    private var todayPlan: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text("Today’s plan").font(.title3.bold()); Spacer(); Text("8–12 MIN").font(.caption2.bold()).foregroundStyle(FallweiseTheme.green) }
            planRow("1", "Learn", lesson.title, FallweiseTheme.coral)
            planRow("2", "Recall", "Five useful \(store.selectedLevel.rawValue) words", FallweiseTheme.blue)
            planRow("3", "Say it", "One complete thought with Mia", FallweiseTheme.lime)
        }
        .padding(19).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
    }

    private func planRow(_ number: String, _ title: String, _ detail: String, _ color: Color) -> some View {
        HStack(spacing: 13) {
            Text(number).font(.headline).frame(width: 34, height: 34).background(color, in: Circle())
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.subheadline.bold()); Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }
    }

    private var levelSnapshot: some View {
        Button { store.selectedTab = .progress } label: {
            HStack(spacing: 16) {
                ZStack { Circle().fill(FallweiseTheme.lime); Text(store.selectedLevel.rawValue).font(.title2.bold()) }.frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your \(store.selectedLevel.rawValue) progress").font(.headline)
                    Text("\(store.completedCoreCount)/12 chapters · \(store.learnedCount)/\(store.wordCount) words").font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(store.completedCoreCount), total: 12).tint(FallweiseTheme.green)
                }
                Image(systemName: "chevron.right")
            }
            .padding(17).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Guten Morgen"
        case 12..<18: "Guten Tag"
        default: "Guten Abend"
        }
    }
}
