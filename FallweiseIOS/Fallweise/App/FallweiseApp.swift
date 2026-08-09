import SwiftUI

@main
struct FallweiseApp: App {
    @State private var store = LearningStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .transaction { transaction in
                    if ProcessInfo.processInfo.arguments.contains("--uitesting-disable-animations") { transaction.disablesAnimations = true }
                }
                .onAppear { PhoneWatchSyncService.shared.start(store: store) }
        }
    }
}
