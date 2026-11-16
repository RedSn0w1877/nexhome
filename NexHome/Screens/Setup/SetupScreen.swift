import PhotosUI
import SwiftUI

/// Setup: everything about the house in one place, as glass cards over the wallpaper. Name the
/// home, add devices through the setup wizard, manage rooms and devices, run house-wide controls,
/// choose the look of the app and set preferences.
struct SetupScreen: View {
    @Environment(DeviceRepository.self) private var repository
    @Environment(HomeSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showingWizard = false
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SetupHero()
                    AddDeviceBanner { showingWizard = true }
                    RoomsSetupCard()
                    DevicesSetupCard()
                    HouseControlsCard()
                    AppearanceCard(photoItem: $photoItem)
                    PreferencesCard()
                    AboutCard { confirmingReset = true }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .sheet(isPresented: $showingWizard) { AddDeviceWizard() }
            .confirmationDialog(
                "Reset all customizations?",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    repository.resetCustomizations()
                    settings.resetAll()
                }
            } message: {
                Text("Added devices and rooms are deleted, and every rename, move and removal is undone.")
            }
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
        .presentationDetents([.large])
        .presentationBackground {
            AmbientBackdrop(theme: settings.theme, customImage: settings.customImage)
        }
    }
}

// MARK: - Shared rows

/// A navigation row inside a Setup card: Settings-style icon, title, optional value and a chevron.
struct SetupNavRow: View {
    let title: String
    let symbol: String
    var subtitle: String?
    var value: String?
    let accent: Color

    var body: some View {
        GlassSettingRow(title: title, symbol: symbol, subtitle: subtitle, accent: accent) {
            HStack(spacing: 6) {
                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(NexColors.secondary)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NexColors.tertiary)
            }
        }
    }
}

// MARK: - Hero

private struct SetupHero: View {
    @Environment(DeviceRepository.self) private var repository
    @Environment(HomeSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        let favorites = repository.devices.filter(\.isFavorite).count

        GlassPanel(shape: glassRect(32)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    GlassIconOrb(symbol: "house.fill", accent: NexColors.blue, size: 60, glow: 1)
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Home Name", text: $settings.homeName)
                            .font(.title2.bold())
                            .submitLabel(.done)
                            .accessibilityIdentifier("homeNameField")
                        Text("Tap the name to rename your home")
                            .font(.caption)
                            .foregroundStyle(NexColors.tertiary)
                    }
                }
                HStack(spacing: 10) {
                    GlassStatPill(
                        value: "\(repository.roomsWithDevices.count)",
                        label: "rooms",
                        accent: NexColors.indigo,
                        symbol: "square.grid.2x2.fill"
                    )
                    GlassStatPill(
                        value: "\(repository.devices.count)",
                        label: "devices",
                        accent: NexColors.cyan,
                        symbol: "lightbulb.2.fill"
                    )
                    GlassStatPill(
                        value: "\(favorites)",
                        label: "favourites",
                        accent: NexColors.yellow,
                        symbol: "star.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

private struct AddDeviceBanner: View {
    let action: () -> Void

    var body: some View {
        GlassPanel(shape: glassRect(28), glassTint: NexColors.blue, action: action) {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(NexColors.blue)
                    .frame(width: 52, height: 52)
                    .background(.white, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a Device")
                        .font(.title3.bold())
                    Text("Find something new nearby and set it up")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(18)
        }
        .accessibilityIdentifier("addDeviceBanner")
    }
}

// MARK: - Rooms

private struct RoomsSetupCard: View {
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let rooms = repository.roomsWithDevices
        GlassSection(
            title: "Rooms",
            symbol: "square.grid.2x2.fill",
            accent: NexColors.indigo,
            trailing: AnyView(
                Text("\(rooms.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NexColors.secondary)
            )
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(rooms) { room in
                        NavigationLink {
                            RoomEditView(room: room)
                        } label: {
                            RoomMiniTile(room: room, count: repository.devices(in: room).count)
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        AddRoomView()
                    } label: {
                        GlassPanel(shape: glassRect(20)) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(NexColors.indigo)
                                Text("Add Room")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(width: 96, height: 92)
                            .padding(12)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addRoomTile")
                }
            }
            .scrollClipDisabled()

            NavigationLink {
                RoomsSetupView()
            } label: {
                SetupNavRow(
                    title: "Manage Rooms",
                    symbol: "list.bullet",
                    subtitle: "Rename, reorder, change icons, add or remove",
                    accent: NexColors.indigo
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RoomMiniTile: View {
    let room: Room
    let count: Int

    var body: some View {
        GlassPanel(shape: glassRect(20)) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: room.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(roomAccent(room))
                Spacer(minLength: 6)
                Text(room.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(count == 1 ? "1 device" : "\(count) devices")
                    .font(.caption2)
                    .foregroundStyle(NexColors.tertiary)
            }
            .frame(width: 96, height: 92, alignment: .topLeading)
            .padding(12)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Devices

private struct DevicesSetupCard: View {
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let favorites = repository.devices.filter(\.isFavorite).count
        GlassSection(title: "Devices", symbol: "lightbulb.2.fill", accent: NexColors.cyan) {
            NavigationLink {
                ManageDevicesView()
            } label: {
                SetupNavRow(
                    title: "Manage Devices",
                    symbol: "list.bullet.rectangle",
                    subtitle: "Rename, move, favourite or remove",
                    value: "\(repository.devices.count)",
                    accent: NexColors.cyan
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("manageDevicesRow")

            NavigationLink {
                ManageDevicesView(favoritesOnly: true)
            } label: {
                SetupNavRow(
                    title: "Favourites",
                    symbol: "star.fill",
                    subtitle: "Pinned to Featured on Home",
                    value: "\(favorites)",
                    accent: NexColors.yellow
                )
            }
            .buttonStyle(.plain)

            if !repository.removedDevices.isEmpty {
                GlassSettingRow(
                    title: "Restore Removed Devices",
                    symbol: "arrow.uturn.backward",
                    subtitle: "\(repository.removedDevices.count) removed from the original house",
                    accent: NexColors.orange,
                    action: { repository.restoreRemovedDevices() }
                )
            }
        }
    }
}

// MARK: - House controls

private struct HouseControlsCard: View {
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let lights = repository.devices(ofKind: .dimmer)
        let lightsOn = lights.filter(\.isOn).count
        let unlocked = repository.devices(ofKind: .lock).filter { $0.lockState != .locked }.count
        let garagesOpen = repository.devices(ofKind: .garage).filter { $0.garageState != .closed }.count
        let playing = repository.devices(ofKind: .mediaPlayer).filter(\.isPlaying).count
        let plugsOn = repository.countOn(ofKind: .toggle)
        let panel = repository.devices(ofKind: .securityPanel).first
        let armed = panel.map { $0.alarmState != .disarmed } ?? false

        GlassSection(title: "House Controls", symbol: "switch.2", accent: NexColors.orange) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                HouseAction(
                    title: "All Lights Off", symbol: "lightbulb.slash.fill",
                    caption: "\(lightsOn) of \(lights.count) on", accent: NexColors.yellow, id: "lightsOff"
                ) { repository.setAllLights(false) }
                HouseAction(
                    title: "All Lights On", symbol: "lightbulb.max.fill",
                    caption: "\(lights.count - lightsOn) off", accent: NexColors.yellow, id: "lightsOn"
                ) { repository.setAllLights(true) }
                HouseAction(
                    title: "Lock All Doors", symbol: "lock.fill",
                    caption: unlocked == 0 ? "All locked" : "\(unlocked) unlocked", accent: NexColors.teal, id: "lockAll"
                ) { repository.lockAllDoors() }
                HouseAction(
                    title: "Close Garages", symbol: "door.garage.closed",
                    caption: garagesOpen == 0 ? "All closed" : "\(garagesOpen) open", accent: NexColors.indigo, id: "closeGarages"
                ) { repository.closeAllGarages() }
                HouseAction(
                    title: armed ? "Disarm Alarm" : "Arm Away",
                    symbol: armed ? "shield.slash.fill" : "shield.fill",
                    caption: panel.map(alarmStateText) ?? "No panel", accent: NexColors.red, id: "alarm"
                ) { repository.setAlarm(armed ? .disarmed : .armedAway) }
                HouseAction(
                    title: "Stop All Media", symbol: "pause.fill",
                    caption: playing == 0 ? "Nothing playing" : "\(playing) playing", accent: NexColors.purple, id: "stopMedia"
                ) { repository.stopAllMedia() }
                HouseAction(
                    title: "All Plugs Off", symbol: "powerplug.fill",
                    caption: "\(plugsOn) on", accent: NexColors.green, id: "plugsOff"
                ) { repository.setAllPlugs(false) }
                HouseAction(
                    title: "All Plugs On", symbol: "bolt.fill",
                    caption: "\(repository.devices(ofKind: .toggle).count - plugsOn) off", accent: NexColors.green, id: "plugsOn"
                ) { repository.setAllPlugs(true) }
            }

            GlassSettingRow(
                title: "Live Simulation",
                symbol: "waveform.path.ecg",
                subtitle: repository.simulationPaused
                    ? "Paused: the house holds still"
                    : "Devices drift, doors move, cycles count down",
                accent: NexColors.mint
            ) {
                LiquidToggle(isOn: !repository.simulationPaused, accent: NexColors.mint) {
                    repository.simulationPaused = !$0
                }
            }
        }
    }
}

private struct HouseAction: View {
    let title: String
    let symbol: String
    let caption: String
    let accent: Color
    let id: String
    let action: () -> Void

    var body: some View {
        GlassPanel(shape: glassRect(20), action: {
            Haptics.tap()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(NexColors.tertiary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .accessibilityIdentifier("houseAction.\(id)")
    }
}

// MARK: - Appearance

private struct AppearanceCard: View {
    @Binding var photoItem: PhotosPickerItem?
    @Environment(HomeSettings.self) private var settings

    var body: some View {
        GlassSection(title: "Appearance", symbol: "paintbrush.fill", accent: NexColors.pink) {
            WallpaperGrid()

            PhotosPicker(selection: $photoItem, matching: .images) {
                SetupNavRow(
                    title: "Choose a Photo",
                    symbol: "photo.fill",
                    subtitle: "Use your own wallpaper",
                    accent: NexColors.pink
                )
            }
            .buttonStyle(.plain)

            if settings.customImage != nil {
                GlassSettingRow(
                    title: "Remove Photo",
                    symbol: "trash",
                    accent: NexColors.red,
                    action: { settings.setPhoto(nil) }
                )
            }

            NavigationLink {
                HomeLayoutView()
            } label: {
                SetupNavRow(
                    title: "Home Screen",
                    symbol: "square.stack.fill",
                    subtitle: "Choose and order Home's sections",
                    value: "\(settings.visibleSections.count) of \(HomeSection.allCases.count)",
                    accent: NexColors.orange
                )
            }
            .buttonStyle(.plain)
        }
    }
}

/// Wallpaper themes as small previews; the selected one carries a checkmark.
private struct WallpaperGrid: View {
    @Environment(HomeSettings.self) private var settings

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BackgroundTheme.allCases) { theme in
                    let selected = settings.customImage == nil && settings.theme == theme
                    Button {
                        Haptics.tick()
                        settings.setPhoto(nil)
                        settings.theme = theme
                    } label: {
                        VStack(spacing: 6) {
                            AmbientBackdrop(theme: theme)
                                .frame(width: 64, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(selected ? Color.white : .clear, lineWidth: 2.5)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.black, .white)
                                            .font(.system(size: 18))
                                            .padding(5)
                                    }
                                }
                            Text(theme.label)
                                .font(.caption)
                                .foregroundStyle(selected ? NexColors.primary : NexColors.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.label) wallpaper")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Preferences and about

private struct PreferencesCard: View {
    @Environment(HomeSettings.self) private var settings

    var body: some View {
        GlassSection(title: "Preferences", symbol: "slider.horizontal.3", accent: NexColors.purple) {
            GlassSettingRow(
                title: "Haptics",
                symbol: "hand.tap.fill",
                subtitle: "Ticks and taps as you use controls",
                accent: NexColors.purple
            ) {
                LiquidToggle(isOn: settings.hapticsEnabled, accent: NexColors.purple) {
                    settings.hapticsEnabled = $0
                }
            }
            GlassSettingRow(
                title: "Electricity",
                symbol: "bolt.fill",
                subtitle: "Price per kWh for cost estimates",
                accent: NexColors.yellow
            ) {
                LiquidStepper(
                    value: settings.pricePerKwh,
                    range: 0.05...1.0,
                    step: 0.01,
                    format: { String(format: "$%.2f", $0) },
                    accent: NexColors.yellow
                ) { settings.pricePerKwh = $0 }
            }
        }
    }
}

private struct AboutCard: View {
    let onReset: () -> Void
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        GlassSection(title: "About", symbol: "info.circle.fill", accent: NexColors.secondary) {
            VStack(spacing: 10) {
                InfoLine(title: "Version", value: appVersion)
                InfoLine(title: "Rooms", value: "\(repository.roomsWithDevices.count)")
                InfoLine(title: "Devices", value: "\(repository.devices.count)")
            }
            Text("NexHome runs a simulated house: every device and reading is generated on this iPhone.")
                .font(.caption)
                .foregroundStyle(NexColors.tertiary)
            LiquidButton(tint: NexColors.red, action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Reset All Customizations")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct InfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(NexColors.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// A Settings-app row label: a coloured rounded-square icon and a title.
struct SetupLabel: View {
    let title: String
    let symbol: String
    let accent: Color

    init(_ title: String, symbol: String, accent: Color) {
        self.title = title
        self.symbol = symbol
        self.accent = accent
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SettingsIcon(symbol: symbol, accent: accent, size: 28)
        }
    }
}
