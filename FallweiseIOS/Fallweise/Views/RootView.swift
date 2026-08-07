import SwiftUI

struct RootView: View {
    @Environment(LearningStore.self) private var store
    var body: some View {
        VoiceTutorView()
            .sheet(isPresented: Bindable(store).showingJourney) { JourneyView() }
            .background(FallweiseTheme.cream.ignoresSafeArea())
    }
}
