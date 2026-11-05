import SwiftUI

/// The universal full-screen device sheet.
///
/// - Backdrop: the app wallpaper blurred and dimmed, blooming in. Every glass surface in the sheet
///   refracts that scrim rather than the raw wallpaper, which is what gave the Android build its
///   layered look.
/// - Hero header: a glass panel with a glowing icon orb, the name, room · type, the live status and
///   a master power toggle for the kinds that have one.
/// - Body: the category's controls in a vertical scroll view.
/// - Swipe down when scrolled to the top: the sheet follows the finger with rubber banding and
///   dismisses past a threshold, otherwise springs back.
struct DeviceSheet: View {
    @Bindable var device: Device
    let onClose: () -> Void

    @State private var enter: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var atTop = true
    @State private var dismissing = false

    private var accent: Color { deviceAccent(device.type) }

    var body: some View {
        GeometryReader { proxy in
            let height = max(proxy.size.height, 1)
            let fade = clamp01(1 - Double(dragOffset) / (Double(height) * 0.7)) * enter

            ZStack(alignment: .top) {
                // Blurred, dimmed wallpaper scrim.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(fade)
                    .overlay(Color.black.opacity(0.12 * fade))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        DeviceControls(device: device)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 64)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    atTop = offset <= 1
                }

                closeButton
            }
            .offset(y: dragOffset + CGFloat(1 - enter) * 96)
            .opacity(enter)
            .simultaneousGesture(sheetDrag(height: height))
        }
        .task {
            withAnimation(GlassMotion.enter) { enter = 1 }
        }
        // Swallow every touch that lands on the sheet so nothing reaches the screen behind.
        .contentShape(Rectangle())
    }

    // MARK: - Header

    private var header: some View {
        GlassPanel(
            shape: glassRect(32),
            tint: NexColors.glassTintDark,
            heavy: true,
            surface: AnyView(
                AccentWash(
                    color: accent,
                    center: UnitPoint(x: 0.16, y: 0.18),
                    radiusFraction: 0.85,
                    amount: device.isOn ? 0.12 : 0
                )
                .animation(GlassMotion.glow, value: device.isOn)
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    GlassIconOrb(
                        symbol: device.type.symbol,
                        accent: accent,
                        size: 64,
                        glow: device.isOn ? 1 : 0,
                        iconTint: .white
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
                .padding(.trailing, 52)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        NexText(
                            sheetStatus(device),
                            .bodyStrong,
                            color: device.isOn ? NexColors.primary : NexColors.secondary
                        )
                        .lineLimit(1)
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
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            LiquidButton(surfaceColor: Color.white.opacity(0.08), action: { dismiss(velocity: 0) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(NexColors.primary)
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 20)
    }

    // MARK: - Swipe to dismiss

    private func sheetDrag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard atTop, !dismissing, value.translation.height > 0 else { return }
                let rubberRange = height * 0.5
                dragOffset = rubberRange * rubberBand(value.translation.height / rubberRange)
            }
            .onEnded { value in
                guard !dismissing else { return }
                if dragOffset > 120 || value.predictedEndTranslation.height > 400 {
                    dismiss(velocity: value.predictedEndTranslation.height)
                } else {
                    withAnimation(.spring(response: 0.363, dampingFraction: 0.55)) { dragOffset = 0 }
                }
            }
    }

    private func dismiss(velocity: CGFloat) {
        guard !dismissing else { return }
        dismissing = true
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = 900
            enter = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            onClose()
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
