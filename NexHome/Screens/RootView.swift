import PhotosUI
import SwiftUI

/// The NexHome shell: the system tab bar (Liquid Glass), a navigation stack per tab with large
/// titles and glass toolbar buttons, and system sheets for device controls and Setup.
struct RootView: View {
    @Environment(DeviceRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    @State private var homePath: [Room] = []
    @State private var roomsPath: [Room] = []

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $homePath) {
                    HomeScreen(
                        onRoomTap: { homePath.append($0) },
                        onDeviceTap: { router.open($0) },
                        onSeeAllRooms: { router.tab = .rooms }
                    )
                    .navigationDestination(for: Room.self) { room in
                        RoomDevicesScreen(room: room, onDeviceTap: { router.open($0) })
                    }
                }
            }

            Tab("Rooms", systemImage: "square.grid.2x2.fill", value: AppTab.rooms) {
                NavigationStack(path: $roomsPath) {
                    RoomsScreen(onRoomTap: { roomsPath.append($0) })
                        .navigationDestination(for: Room.self) { room in
                            RoomDevicesScreen(room: room, onDeviceTap: { router.open($0) })
                        }
                }
            }

            Tab("Cameras", systemImage: "video.fill", value: AppTab.cameras) {
                NavigationStack {
                    CamerasScreen(onDeviceTap: { router.open($0) })
                }
            }

            Tab("Security", systemImage: "shield.fill", value: AppTab.security) {
                NavigationStack {
                    SecurityScreen(onDeviceTap: { router.open($0) })
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $router.selectedDevice) { device in
            DeviceSheet(device: device)
        }
        .sheet(isPresented: $router.showingSetup) {
            SetupScreen()
        }
        .sheet(isPresented: $router.showingAddDevice) {
            AddDeviceWizard(preferredRoom: router.addDeviceRoom)
        }
        // Testing hooks (launch arguments land in UserDefaults), so CI can screenshot screens
        // without touching the simulator:
        //   -startTab rooms|cameras|security   -openKind THERMOSTAT_DIAL   -openSetup YES
        //   -openAddDevice YES
        .task {
            let defaults = UserDefaults.standard
            switch defaults.string(forKey: "startTab") {
            case "rooms": router.tab = .rooms
            case "cameras": router.tab = .cameras
            case "security": router.tab = .security
            default: break
            }
            if let key = defaults.string(forKey: "openKind"),
               let kind = ControlKind.allCases.first(where: { $0.key == key }) {
                let candidates = repository.devices(ofKind: kind)
                router.selectedDevice = candidates.first { $0.isOn } ?? candidates.first
            } else if defaults.bool(forKey: "openSetup") {
                router.showingSetup = true
            } else if defaults.bool(forKey: "openAddDevice") {
                router.addDevice()
            }
        }
    }
}

/// The toolbar every top-level screen shares: add a device, the wallpaper menu and Setup, grouped
/// into one glass capsule by the system.
struct HomeToolbar: ToolbarContent {
    @Environment(AppRouter.self) private var router

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Add Device", systemImage: "plus") {
                router.addDevice()
            }
            WallpaperMenu()
            Button("Setup", systemImage: "gearshape") {
                router.showingSetup = true
            }
        }
    }
}

/// Wallpaper picker: the gradient themes, or a photo from the library.
struct WallpaperMenu: View {
    @Environment(HomeSettings.self) private var settings
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        @Bindable var settings = settings

        Menu {
            Picker("Wallpaper", selection: $settings.theme) {
                ForEach(BackgroundTheme.allCases) { option in
                    Text(option.label).tag(option)
                }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose a Photo…", systemImage: "photo")
            }

            if settings.customImage != nil {
                Button("Use a Gradient", systemImage: "arrow.uturn.backward") {
                    settings.setPhoto(nil)
                }
            }
        } label: {
            Label("Wallpaper", systemImage: "photo.on.rectangle.angled")
        }
        .onChange(of: settings.theme) { _, _ in settings.setPhoto(nil) }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    settings.setPhoto(image)
                }
                photoItem = nil
            }
        }
    }
}
