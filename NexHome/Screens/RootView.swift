import PhotosUI
import SwiftUI

private enum Screen: Hashable {
    case home
    case rooms
    case roomDevices(Room)
    case cameras
    case security
}

private struct NavTab {
    let label: String
    let symbol: String
}

private let navTabs = [
    NavTab(label: "Home", symbol: "house.fill"),
    NavTab(label: "Rooms", symbol: "square.grid.2x2.fill"),
    NavTab(label: "Cameras", symbol: "video.fill"),
    NavTab(label: "Security", symbol: "shield.fill"),
]

/// The NexHome shell: the wallpaper every glass surface refracts, a floating glass top bar, the
/// current screen, the liquid tab bar, and the full-screen device sheet on top of everything.
struct RootView: View {
    @Environment(DeviceRepository.self) private var repository

    @State private var tabIndex = 0
    @State private var screen: Screen = .home
    @State private var selectedDevice: Device?
    @State private var theme: BackgroundTheme = .nebula
    @State private var customImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingWallpaperMenu = false

    var body: some View {
        ZStack {
            AmbientBackdrop(theme: theme, customImage: customImage)

            Group {
                switch screen {
                case .home:
                    HomeScreen(
                        onRoomTap: { open(room: $0) },
                        onDeviceTap: { selectedDevice = $0 },
                        onSeeAllRooms: { goToTab(1) }
                    )
                case .rooms:
                    RoomsScreen(onRoomTap: { open(room: $0) })
                case .roomDevices(let room):
                    RoomDevicesScreen(
                        room: room,
                        onBack: { leaveRoom() },
                        onDeviceTap: { selectedDevice = $0 }
                    )
                case .cameras:
                    CamerasScreen(onDeviceTap: { selectedDevice = $0 })
                case .security:
                    SecurityScreen(onDeviceTap: { selectedDevice = $0 })
                }
            }
            .id(screen)
            .transition(
                .asymmetric(
                    insertion: .offset(y: 28).combined(with: .opacity),
                    removal: .opacity
                )
            )
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            // The sheet's scrim covers everything, so stop drawing the screen underneath it.
            .opacity(selectedDevice == nil ? 1 : 0)

            if let device = selectedDevice {
                DeviceSheet(device: device) { selectedDevice = nil }
                    .transition(.identity)
            }
        }
        .animation(GlassMotion.enter, value: screen)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    customImage = image
                }
            }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        let onCount = repository.devices.filter { $0.isOn }.count
        return GlassPanel(
            shape: glassCapsule,
            tint: Color.black.opacity(0.22),
            showHighlight: false
        ) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    NexText("NexHome", .title).lineLimit(1)
                    NexText(
                        "\(onCount) of \(repository.devices.count) devices on",
                        .caption,
                        color: NexColors.secondary
                    )
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
                wallpaperButton
            }
            .padding(.leading, 22)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var wallpaperButton: some View {
        Menu {
            Picker("Wallpaper", selection: $theme) {
                ForEach(BackgroundTheme.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .onChange(of: theme) { _, _ in customImage = nil }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose a photo…", systemImage: "photo")
            }

            if customImage != nil {
                Button("Use a gradient", systemImage: "arrow.uturn.backward") {
                    customImage = nil
                }
            }
        } label: {
            GlassPanel(
                shape: glassCircle,
                tint: NexColors.glassTintLight,
                accent: NexColors.violet,
                interactive: true,
                showHighlight: false,
                pressScale: GlassMotion.orbPressScale
            ) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(NexColors.primary)
                    .frame(width: 40, height: 40)
            }
        }
    }

    private var tabBar: some View {
        LiquidTabBar(
            tabs: navTabs.map { ($0.label, $0.symbol) },
            selectedIndex: tabIndex,
            onSelect: { goToTab($0) }
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Navigation

    private func goToTab(_ index: Int) {
        tabIndex = index
        switch index {
        case 0: screen = .home
        case 1: screen = .rooms
        case 2: screen = .cameras
        default: screen = .security
        }
    }

    private func open(room: Room) {
        screen = .roomDevices(room)
    }

    private func leaveRoom() {
        screen = tabIndex == 1 ? .rooms : .home
    }
}

/// The floating glass tab bar: a capsule with a draggable blob you can flick between tabs, kept
/// above the home indicator.
struct LiquidTabBar: View {
    let tabs: [(String, String)]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    private var count: Int { max(tabs.count, 1) }

    @State private var blob: CGFloat = 0
    @State private var dragging = false
    @State private var startBlob: CGFloat = 0
    @State private var lastTick = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let tabWidth = max((width - 10) / CGFloat(count), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NexColors.bar)
                    .glassEffect(.regular, in: Capsule())

                Capsule()
                    .fill(NexColors.cyan.opacity(0.22))
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.8)
                    }
                    .frame(width: tabWidth, height: 56)
                    .scaleEffect(x: dragging ? 1.08 : 1, y: dragging ? 1.05 : 1)
                    .offset(x: 5 + blob * tabWidth)

                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        let on = Int(blob.rounded()) == index
                        VStack(spacing: 2) {
                            Image(systemName: tab.1)
                                .font(.system(size: 20, weight: .semibold))
                            NexText(tab.0, .caption, color: on ? .white : NexColors.secondary)
                                .lineLimit(1)
                        }
                        .foregroundStyle(on ? Color.white : NexColors.secondary)
                        .frame(width: tabWidth, height: 56)
                        .contentShape(Rectangle())
                        .onTapGesture { select(index) }
                    }
                }
                .padding(.horizontal, 5)
            }
            .frame(width: width, height: 66)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            startBlob = blob
                            lastTick = Int(blob.rounded())
                        }
                        let next = clamp(
                            startBlob + value.translation.width / tabWidth,
                            0,
                            CGFloat(count - 1)
                        )
                        blob = next
                        let tick = Int(next.rounded())
                        if tick != lastTick {
                            lastTick = tick
                            Haptics.tick()
                        }
                    }
                    .onEnded { _ in
                        dragging = false
                        let target = clamp(Int(blob.rounded()), 0, count - 1)
                        withAnimation(GlassMotion.blob) { blob = CGFloat(target) }
                        if target != selectedIndex { onSelect(target) }
                    }
            )
        }
        .frame(height: 66)
        .onAppear { blob = CGFloat(selectedIndex) }
        .onChange(of: selectedIndex) { _, newValue in
            guard !dragging else { return }
            withAnimation(GlassMotion.blob) { blob = CGFloat(newValue) }
        }
        .animation(GlassMotion.release, value: dragging)
    }

    private func select(_ index: Int) {
        guard index != selectedIndex else { return }
        Haptics.tick()
        withAnimation(GlassMotion.blob) { blob = CGFloat(index) }
        onSelect(index)
    }
}
