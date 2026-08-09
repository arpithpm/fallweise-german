import SwiftUI

struct RootView: View {
    @Environment(LearningStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            HomeView().tag(AppTab.home).tabItem { Label("Home", systemImage: "house.fill") }
            LearnView().tag(AppTab.learn).tabItem { Label("Learn", systemImage: "map.fill") }
            WordsView().tag(AppTab.words).tabItem { Label("Words", systemImage: "character.book.closed.fill") }
            MiaHubView().tag(AppTab.mia).tabItem { Label("Mia", systemImage: "waveform.and.mic") }
            ProgressViewScreen().tag(AppTab.progress).tabItem { Label("Progress", systemImage: "chart.bar.fill") }
        }
        .tint(FallweiseTheme.green)
        .fullScreenCover(isPresented: $store.showingLesson) {
            NavigationStack {
                Group {
                    switch store.learningMode {
                    case .voice: VoiceTutorView()
                    case .selfStudy: SelfStudyView()
                    case .adaptiveReview: AdaptiveReviewView()
                    case .adaptiveVoice: AdaptiveVoiceReviewView()
                    case .rolePlay: RolePlayView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { store.showingLesson = false } label: { Label("Close", systemImage: "xmark") }
                            .accessibilityIdentifier("Close lesson")
                    }
                }
            }
        }
        .background(FallweiseTheme.cream.ignoresSafeArea())
    }
}
