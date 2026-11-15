import Observation
import SwiftUI
import UIKit

/// A section of the Home screen, which the owner can reorder and hide in Setup.
enum HomeSection: String, CaseIterable, Codable, Identifiable {
    case alerts, controlCenter, scenes, rooms, energy, featured

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alerts: return "Alerts"
        case .controlCenter: return "Control Center"
        case .scenes: return "Scenes"
        case .rooms: return "Rooms"
        case .energy: return "Energy"
        case .featured: return "Featured"
        }
    }

    var symbol: String {
        switch self {
        case .alerts: return "bell.badge.fill"
        case .controlCenter: return "switch.2"
        case .scenes: return "sparkles"
        case .rooms: return "square.grid.2x2.fill"
        case .energy: return "bolt.fill"
        case .featured: return "star.fill"
        }
    }

    var accent: Color {
        switch self {
        case .alerts: return NexColors.red
        case .controlCenter: return NexColors.blue
        case .scenes: return NexColors.yellow
        case .rooms: return NexColors.indigo
        case .energy: return NexColors.orange
        case .featured: return NexColors.pink
        }
    }
}

/// The owner's preferences from Setup: home name, wallpaper, Home screen layout, haptics and the
/// electricity price. Saved to UserDefaults (the wallpaper photo to the app's documents folder).
@MainActor
@Observable
final class HomeSettings {
    var homeName: String { didSet { save() } }
    var theme: BackgroundTheme { didSet { save() } }
    private(set) var customImage: UIImage?
    var sectionOrder: [HomeSection] { didSet { save() } }
    var hiddenSections: Set<HomeSection> { didSet { save() } }
    var hapticsEnabled: Bool {
        didSet {
            Haptics.enabled = hapticsEnabled
            save()
        }
    }
    var pricePerKwh: Double {
        didSet {
            energyRate = pricePerKwh
            save()
        }
    }

    /// Home screen sections in display order, without the hidden ones.
    var visibleSections: [HomeSection] {
        sectionOrder.filter { !hiddenSections.contains($0) }
    }

    private struct Stored: Codable {
        var homeName = "NexHome"
        var theme = BackgroundTheme.nebula.rawValue
        var sectionOrder = HomeSection.allCases
        var hiddenSections: Set<HomeSection> = []
        var hapticsEnabled = true
        var pricePerKwh = 0.28
    }

    @ObservationIgnored private let key = "nexhome.settings"
    @ObservationIgnored private var loading = true

    init() {
        let stored = UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()
        homeName = stored.homeName
        theme = BackgroundTheme(rawValue: stored.theme) ?? .nebula
        // Sections added in a later version are appended rather than lost.
        sectionOrder = stored.sectionOrder + HomeSection.allCases.filter { !stored.sectionOrder.contains($0) }
        hiddenSections = stored.hiddenSections
        hapticsEnabled = stored.hapticsEnabled
        pricePerKwh = stored.pricePerKwh
        customImage = (try? Data(contentsOf: Self.photoURL)).flatMap(UIImage.init(data:))
        Haptics.enabled = hapticsEnabled
        energyRate = pricePerKwh
        loading = false
    }

    func setPhoto(_ image: UIImage?) {
        customImage = image
        if let image, let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: Self.photoURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.photoURL)
        }
    }

    func resetLayout() {
        sectionOrder = HomeSection.allCases
        hiddenSections = []
    }

    func resetAll() {
        homeName = "NexHome"
        theme = .nebula
        setPhoto(nil)
        resetLayout()
        hapticsEnabled = true
        pricePerKwh = 0.28
    }

    private func save() {
        guard !loading else { return }
        let stored = Stored(
            homeName: homeName,
            theme: theme.rawValue,
            sectionOrder: sectionOrder,
            hiddenSections: hiddenSections,
            hapticsEnabled: hapticsEnabled,
            pricePerKwh: pricePerKwh
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static var photoURL: URL {
        URL.documentsDirectory.appending(path: "wallpaper.jpg")
    }
}

/// App-wide navigation state: the open device sheet, the Setup sheet and the selected tab.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var selectedDevice: Device?
    var showingSetup = false

    func open(_ device: Device) { selectedDevice = device }
}

enum AppTab: Hashable {
    case home, rooms, cameras, security
}

/// The wallpaper behind a screen, from the owner's settings.
private struct WallpaperBackground: ViewModifier {
    @Environment(HomeSettings.self) private var settings

    func body(content: Content) -> some View {
        content.background {
            AmbientBackdrop(theme: settings.theme, customImage: settings.customImage)
        }
    }
}

extension View {
    func wallpaperBackground() -> some View {
        modifier(WallpaperBackground())
    }
}
