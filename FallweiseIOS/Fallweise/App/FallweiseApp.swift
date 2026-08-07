import SwiftUI

@main
struct FallweiseApp: App {
    @State private var store = LearningStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
