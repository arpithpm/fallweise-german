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
                    NavigationLink { PracticeCalendarView() } label: { WeeklyPracticeCard() }
                        .buttonStyle(.plain)
                    memoryCard
                    continueCard
                    todayPlan
                    levelSnapshot
                }.padding(20).padding(.bottom, 16)
            }
            .fallweiseBackground()
        }
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Kicker(text: "Today · memory first")
                Spacer()
                Text("\(store.sessionLength.rawValue) MIN").font(.caption2.bold()).foregroundStyle(FallweiseTheme.green)
            }
            Text(store.dueReviewCount == 0 ? "Build a few new memories" : "\(store.dueReviewCount) memories need you")
                .font(.system(size: 30, weight: .bold, design: .serif))
            Text("Due recall, fragile knowledge, a little new material, and one useful speaking challenge.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(SessionLength.allCases) { length in
                    sessionButton(length)
                }
            }
            Button { store.beginAdaptiveSession() } label: {
                Label(store.dueReviewCount > 0 ? "Strengthen today’s memories" : "Start adaptive practice", systemImage: "brain.head.profile")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
            HStack {
                Label("\(store.fragileCount) fragile", systemImage: "leaf")
                Spacer()
                Label("\(store.strongMemoryCount) strong", systemImage: "shield.checkered")
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(22).background(FallweiseTheme.lime.opacity(0.27), in: RoundedRectangle(cornerRadius: 28))
    }

    @ViewBuilder private func sessionButton(_ length: SessionLength) -> some View {
        if store.sessionLength == length {
            Button("\(length.rawValue)m") { store.setSessionLength(length) }
                .buttonStyle(.borderedProminent).tint(FallweiseTheme.green)
        } else {
            Button("\(length.rawValue)m") { store.setSessionLength(length) }
                .buttonStyle(.bordered).tint(FallweiseTheme.green)
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
            HStack { Text("Today’s plan").font(.title3.bold()); Spacer(); Text("ADAPTIVE").font(.caption2.bold()).foregroundStyle(FallweiseTheme.green) }
            planRow("1", "Recall", "Due memories before seeing answers", FallweiseTheme.coral)
            planRow("2", "Mix", "Listening, words, grammar and context", FallweiseTheme.blue)
            planRow("3", "Transfer", "One complete thought without hints", FallweiseTheme.lime)
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
