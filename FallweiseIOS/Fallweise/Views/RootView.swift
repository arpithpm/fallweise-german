import SwiftUI

struct RootView: View {
    @Environment(LearningStore.self) private var store
    var body: some View {
        Group {
            switch store.learningMode {
            case .voice: VoiceTutorView()
            case .selfStudy: SelfStudyView()
            }
        }
            .sheet(isPresented: Bindable(store).showingJourney) { JourneyView() }
            .background(FallweiseTheme.cream.ignoresSafeArea())
    }
}
