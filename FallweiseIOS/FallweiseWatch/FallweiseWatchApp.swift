import SwiftUI

@main
struct FallweiseWatchApp: App {
    @State private var store = WatchLearningStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(store)
        }
    }
}
