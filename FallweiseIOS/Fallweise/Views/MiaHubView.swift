import SwiftUI

struct MiaHubView: View {
    @Environment(LearningStore.self) private var store
    private var lesson: VoiceLesson { store.recommendedLesson }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    AppPageHeader(kicker: "Hands-free tutor", title: "Learn with Mia", subtitle: "Mia explains, listens, responds, and saves your place.")
                    LevelSelector()
                    miaCard
                    controls
                    privacy
                }.padding(20).padding(.bottom, 16)
            }
            .navigationTitle("Mia")
            .navigationBarTitleDisplayMode(.inline)
            .fallweiseBackground()
        }
    }

    private var miaCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 15) {
                ZStack { Circle().fill(FallweiseTheme.blue); Image(systemName: "person.fill").font(.largeTitle) }.frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) { Kicker(text: "Mia · German guide"); Text("Ready when you are").font(.title2.bold()) }
            }
            Divider()
            HStack { Kicker(text: "Recommended lesson"); Spacer(); LessonStatusBadge(lesson: lesson) }
            Text(lesson.title).font(.system(size: 30, weight: .bold, design: .serif))
            Text(lesson.goal).foregroundStyle(.secondary)
            Button { store.start(lesson, mode: .voice) } label: {
                Label("Start voice lesson", systemImage: "waveform.and.mic").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 11)
            }.buttonStyle(.borderedProminent).tint(FallweiseTheme.ink)
            Button { store.selectedTab = .learn } label: { Label("Choose another chapter", systemImage: "map") }.buttonStyle(.plain).foregroundStyle(FallweiseTheme.green)
        }.padding(22).background(FallweiseTheme.paper, in: RoundedRectangle(cornerRadius: 28))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You stay in control").font(.headline)
            feature("pause.fill", "Pause whenever you need")
            feature("book.pages", "Switch to self-study on the same lesson")
            feature("arrow.triangle.2.circlepath", "Progress is shared across both modes")
        }.padding(18).background(FallweiseTheme.blue.opacity(0.24), in: RoundedRectangle(cornerRadius: 22))
    }

    private func feature(_ icon: String, _ text: String) -> some View { Label(text, systemImage: icon).font(.subheadline) }

    private var privacy: some View {
        Label("The microphone starts only after you begin a voice lesson. Audio is transcribed securely; recordings are not saved.", systemImage: "lock.shield.fill")
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
    }
}
