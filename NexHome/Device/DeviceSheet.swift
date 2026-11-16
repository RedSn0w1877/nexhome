import SwiftUI

/// The device sheet: a system sheet over the owner's wallpaper, with a hero card (icon badge, name,
/// room · type, live status, master power) and the device's controls below. The toolbar holds the
/// standard close button and a menu to favourite, rename, move or remove the device.
struct DeviceSheet: View {
    @Bindable var device: Device

    @Environment(DeviceRepository.self) private var repository
    @Environment(HomeSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmingRemove = false

    private var accent: Color { deviceAccent(device.type) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    DeviceControls(device: device)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("deviceSheet")
            .navigationTitle(device.type.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { manageMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground {
            AmbientBackdrop(theme: settings.theme, customImage: settings.customImage)
        }
        .alert("Rename Device", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { repository.rename(device, to: draftName) }
        }
        .confirmationDialog(
            "Remove \(device.name)?",
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove Device", role: .destructive) {
                repository.remove(device)
                dismiss()
            }
        } message: {
            Text(
                repository.isCustom(device)
                    ? "This device was added by hand and will be deleted."
                    : "You can bring it back from Setup › Manage Devices."
            )
        }
        // Favourites can also be flipped inside the controls; persist whatever it ends up as.
        .onDisappear { repository.setFavorite(device, device.isFavorite) }
    }

    // MARK: - Header

    private var header: some View {
        GlassPanel(shape: glassRect(32)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    GlassIconOrb(
                        symbol: device.type.symbol,
                        accent: accent,
                        size: 64,
                        glow: isDeviceActive(device) ? 1 : 0
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        NexText(device.name, .title).lineLimit(2)
                        NexText(
                            "\(device.room.displayName) · \(device.type.label)",
                            .caption,
                            color: NexColors.tertiary
                        )
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        NexText(
                            sheetStatus(device),
                            .bodyStrong,
                            color: device.isOn ? NexColors.primary : NexColors.secondary
                        )
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("sheetStatus")
                        NexText(
                            device.isOnline
                                ? "Online · signal \(device.signalStrength)/4"
                                : "Offline",
                            .caption,
                            color: NexColors.tertiary
                        )
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if sheetShowsPowerToggle(device.controlKind) {
                        LiquidToggle(isOn: device.isOn, accent: accent) { device.isOn = $0 }
                            .accessibilityIdentifier("powerToggle")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    // MARK: - Manage menu

    private var manageMenu: some View {
        Menu {
            Button(
                device.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: device.isFavorite ? "star.slash" : "star"
            ) {
                repository.setFavorite(device, !device.isFavorite)
            }
            Button("Rename…", systemImage: "pencil") {
                draftName = device.name
                renaming = true
            }
            Menu("Move to Room", systemImage: "arrow.right.square") {
                Picker(
                    "Room",
                    selection: Binding(get: { device.room }, set: { repository.move(device, to: $0) })
                ) {
                    ForEach(Room.allCases) { room in
                        Label(room.displayName, systemImage: room.symbol).tag(room)
                    }
                }
            }
            Divider()
            Button("Remove Device…", systemImage: "trash", role: .destructive) {
                confirmingRemove = true
            }
        } label: {
            Label("Manage", systemImage: "ellipsis")
        }
    }
}

/// Kinds whose sheet header shows the master power toggle.
func sheetShowsPowerToggle(_ kind: ControlKind) -> Bool {
    switch kind {
    case .dimmer, .toggle, .thermostatDial, .waterHeaterDial, .fanSpeed, .mediaPlayer, .cameraFeed:
        return true
    default:
        return false
    }
}

/// One-line live status for the sheet header.
func sheetStatus(_ device: Device) -> String {
    guard device.isOnline else { return "Offline" }
    switch device.controlKind {
    case .dimmer:
        return device.isOn ? "\((device.brightness * 100).rounded0)% brightness" : "Off"
    case .toggle:
        return device.isOn ? "\(device.powerDrawWatts.rounded0) W now" : "Off"
    case .thermostatDial:
        let activity: String
        if !device.isOn {
            activity = "Off"
        } else if device.isHeating {
            activity = "Heating"
        } else if device.isCooling {
            activity = "Cooling"
        } else {
            activity = "Idle"
        }
        return "\(device.currentTempF.rounded0)° inside · \(activity)"
    case .waterHeaterDial:
        return "\(device.currentTempF.rounded0)° · \(device.hotWaterPercent)% hot water"
    case .lock:
        var text = device.lockState == .locked ? "Locked" : "Unlocked"
        if device.doorAjar { text += " · Door ajar" }
        return text
    case .garage:
        switch device.garageState {
        case .moving: return device.garageOpening ? "Opening…" : "Closing…"
        case .open: return "Open"
        case .closed: return "Closed"
        }
    case .cameraFeed:
        if device.privacyMode { return "Privacy mode" }
        if device.motionDetected { return "Motion detected" }
        return device.isRecording ? "Recording" : "Live"
    case .blindsSlider:
        return "\((device.position * 100).rounded0)% open"
    case .mediaPlayer:
        if device.isPlaying { return device.trackTitle.isEmpty ? "Playing" : device.trackTitle }
        return "Paused"
    case .fanSpeed:
        return !device.isOn || device.fanSpeed == 0 ? "Off" : "Speed \(device.fanSpeed)"
    case .applianceCycle:
        return device.applianceMode == .running
            ? "Running · \(device.minutesRemaining) min left"
            : device.applianceMode.displayName
    case .robotVacuum:
        return "\(device.vacuumState.displayName) · \(device.batteryPercent)%"
    case .evCharger:
        if device.type == .poolPump {
            return device.isOn ? "Running · \(device.pumpSpeedRpm) rpm" : "Off"
        }
        if device.isCharging { return "Charging · \(device.chargePercent)%" }
        return "\(device.chargePercent)% · \(device.plugConnected ? "Plugged in" : "Unplugged")"
    case .sprinklerZones:
        return device.activeZones.isEmpty
            ? "Idle"
            : "Watering zone \(device.activeZones.sorted().map(String.init).joined(separator: ", "))"
    case .sensorReadonly:
        return device.sensorValue
    case .securityPanel:
        return device.alarmState == .arming
            ? "Arming · \(device.exitCountdownSeconds)s"
            : device.alarmState.displayName
    }
}

/// Dispatches to the category's controls, purely by `ControlKind`.
struct DeviceControls: View {
    @Bindable var device: Device

    var body: some View {
        switch device.controlKind {
        case .dimmer: DimmerControls(device: device)
        case .toggle: PlugControls(device: device)
        case .thermostatDial: ThermostatControls(device: device)
        case .waterHeaterDial: WaterHeaterControls(device: device)
        case .fanSpeed: FanControls(device: device)
        case .lock: LockControls(device: device)
        case .garage: GarageControls(device: device)
        case .securityPanel: SecurityPanelControls(device: device)
        case .mediaPlayer: MediaControls(device: device)
        case .cameraFeed: CameraControls(device: device)
        case .applianceCycle: ApplianceControls(device: device)
        case .robotVacuum: VacuumControls(device: device)
        case .evCharger: EvChargerControls(device: device)
        case .sprinklerZones: SprinklerControls(device: device)
        case .sensorReadonly: SensorControls(device: device)
        case .blindsSlider: BlindsControls(device: device)
        }
    }
}
