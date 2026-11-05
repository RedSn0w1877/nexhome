import SwiftUI

/// The NexHome app shell.
///
/// Root state: the single `DeviceRepository` (the simulated house plus its ambient simulation) and
/// the shared `GlassLight` that carries the "hold one control and its colour shines onto its
/// neighbours" spill across the whole window. Both are injected into the environment so any glass
/// surface can read them.
@main
@MainActor
struct NexHomeApp: App {
    @State private var repository = DeviceRepository()
    @State private var light = GlassLight()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(repository)
                .environment(light)
                .preferredColorScheme(.dark)
                .task { repository.startAmbientSimulation() }
        }
    }
}
