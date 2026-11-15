import SwiftUI

/// The NexHome app: the simulated house, the owner's settings and the navigation state, injected
/// into the environment for every screen.
@main
@MainActor
struct NexHomeApp: App {
    @State private var repository = DeviceRepository()
    @State private var settings = HomeSettings()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(repository)
                .environment(settings)
                .environment(router)
                .preferredColorScheme(.dark)
                .task { repository.startAmbientSimulation() }
        }
    }
}
