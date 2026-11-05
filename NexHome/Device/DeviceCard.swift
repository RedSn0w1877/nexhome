import SwiftUI

/// A liquid-glass device card: a glass accent orb that glows while the device is active, the name,
/// a live status line, an inline quick control fitting the device's kind, and a slim live progress
/// bar drawn inside the glass. The card swells, jellies and glides its highlight under the finger
/// and shines its accent onto neighbouring glass while held.
struct DeviceCard: View {
    @Bindable var device: Device
    var showRoom: Bool = false
    let action: () -> Void

    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let accent = deviceAccent(device.type)
        let active = isDeviceActive(device)
        let alert = isDeviceAlert(device)
        let progress = deviceProgress(device)

        GlassPanel(
            shape: glassRect(26),
            tint: NexColors.glassTint,
            accent: accent,
            action: action,
            surface: AnyView(
                AccentWash(
                    color: accent,
                    center: UnitPoint(x: 0.18, y: 0.22),
                    radiusFraction: 1.125,
                    amount: active ? 0.12 : 0
                )
                .animation(GlassMotion.glow, value: active)
            ),
            front: progress >= 0
                ? AnyView(GlassFillBar(fraction: progress, accent: accent, inset: 14))
                : nil
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    GlassIconOrb(
                        symbol: device.type.symbol,
                        accent: accent,
                        size: 42,
                        glow: active ? 1 : 0,
                        iconTint: active ? .white : accent
                    )
                    Spacer(minLength: 0)
                    QuickControl(device: device, accent: accent)
                }
                Spacer().frame(height: 12)
                NexText(device.name, .bodyStrong).lineLimit(1)
                Spacer().frame(height: 2)
                NexText(
                    showRoom ? "\(device.room.displayName) · \(deviceStatusText(device))" : deviceStatusText(device),
                    .caption,
                    color: alert ? NexColors.red : (active ? NexColors.secondary : NexColors.tertiary)
                )
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
    }
}

/// The inline control on the card's top-right, chosen per `ControlKind`.
private struct QuickControl: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        switch device.controlKind {
        case .dimmer, .toggle:
            LiquidToggle(isOn: device.isOn, accent: accent) { device.isOn = $0 }

        case .fanSpeed:
            LiquidToggle(isOn: device.isOn, accent: accent) { on in
                device.isOn = on
                if on && device.fanSpeed == 0 { device.fanSpeed = 2 }
            }

        case .thermostatDial, .waterHeaterDial:
            GlassPill(
                text: "\(device.currentTempF.rounded0)°",
                accent: accent,
                lit: device.isOn && (device.isHeating || device.isCooling)
            )

        case .lock:
            let locked = device.lockState == .locked
            GlassQuickOrb(
                symbol: locked ? "lock.fill" : "lock.open.fill",
                accent: accent,
                lit: locked
            ) {
                repository.setLocked(device, !locked)
            }

        case .garage:
            GlassQuickOrb(
                symbol: "door.garage.closed",
                accent: accent,
                lit: device.garageState != .closed
            ) {
                toggleGarage(repository, device)
            }

        case .blindsSlider:
            GlassQuickOrb(
                symbol: "window.shade.closed",
                accent: accent,
                lit: device.position > 0.02
            ) {
                device.position = device.position > 0.5 ? 0 : 1
            }

        case .mediaPlayer:
            let playing = device.isOn && device.isPlaying
            GlassQuickOrb(
                symbol: playing ? "pause.fill" : "play.fill",
                accent: accent,
                lit: playing
            ) {
                if playing {
                    device.isPlaying = false
                } else {
                    device.isOn = true
                    device.isPlaying = true
                }
            }

        case .cameraFeed:
            GlassPill(
                text: device.privacyMode ? "Private" : (device.motionDetected ? "Motion" : "Live"),
                accent: accent,
                lit: !device.privacyMode
            )

        case .applianceCycle:
            if device.type == .fridge {
                GlassPill(text: "\(device.fridgeTempF.rounded0)°", accent: accent, lit: device.isOn)
            } else {
                let running = device.applianceMode == .running
                GlassQuickOrb(
                    symbol: running ? "pause.fill" : "play.fill",
                    accent: accent,
                    lit: running
                ) {
                    toggleAppliance(device, running)
                }
            }

        case .robotVacuum:
            let cleaning = device.vacuumState == .cleaning
            GlassQuickOrb(
                symbol: cleaning ? "house.fill" : "play.fill",
                accent: accent,
                lit: cleaning || device.vacuumState == .returning
            ) {
                if cleaning {
                    device.vacuumState = .returning
                } else {
                    if device.vacuumState == .docked { device.cleaningProgress = 0 }
                    device.vacuumState = .cleaning
                }
            }

        case .evCharger:
            if device.type == .poolPump {
                LiquidToggle(isOn: device.isOn, accent: accent) { device.isOn = $0 }
            } else {
                GlassQuickOrb(symbol: "bolt.fill", accent: accent, lit: device.isCharging) {
                    device.isCharging.toggle()
                }
            }

        case .sprinklerZones:
            let watering = !device.activeZones.isEmpty
            GlassQuickOrb(symbol: "drop.fill", accent: accent, lit: watering) {
                repository.runAllZones(device, !watering)
            }

        case .sensorReadonly:
            GlassPill(
                text: sensorShortText(device),
                accent: isDeviceAlert(device) ? NexColors.red : accent,
                lit: isDeviceAlert(device)
            )

        case .securityPanel:
            GlassPill(
                text: panelShortText(device),
                accent: device.alarmState == .triggered ? NexColors.red : accent,
                lit: device.alarmState != .disarmed
            )
        }
    }
}

// MARK: - Shared device state helpers

@MainActor
func toggleGarage(_ repository: DeviceRepository, _ device: Device) {
    let closedOrClosing = device.garageState == .closed
        || (device.garageState == .moving && !device.garageOpening)
    if closedOrClosing {
        repository.openGarage(device)
    } else {
        repository.closeGarage(device)
    }
}

func toggleAppliance(_ device: Device, _ running: Bool) {
    if running {
        device.applianceMode = .paused
    } else {
        device.isOn = true
        if device.program.isEmpty {
            device.program = programs(for: device.type).first ?? ""
        }
        device.applianceMode = .running
    }
}

/// Whether the device is doing its "thing" right now (lights the orb and the accent wash).
func isDeviceActive(_ device: Device) -> Bool {
    switch device.controlKind {
    case .dimmer, .toggle, .waterHeaterDial: return device.isOn
    case .fanSpeed: return device.isOn && device.fanSpeed > 0
    case .thermostatDial: return device.isOn && device.hvacMode != .off
    case .lock: return device.lockState == .locked
    case .garage: return device.garageState != .closed
    case .cameraFeed: return !device.privacyMode
    case .blindsSlider: return device.position > 0.02
    case .mediaPlayer: return device.isOn && device.isPlaying
    case .applianceCycle:
        return device.applianceMode == .running || (device.type == .fridge && device.isOn)
    case .robotVacuum:
        return device.vacuumState == .cleaning || device.vacuumState == .returning
    case .evCharger: return device.type == .poolPump ? device.isOn : device.isCharging
    case .sprinklerZones: return !device.activeZones.isEmpty
    case .sensorReadonly: return isDeviceAlert(device)
    case .securityPanel: return device.alarmState != .disarmed
    }
}

let alertSensorTexts: Set<String> = [
    "Motion detected", "Open", "Leak detected", "Smoke detected", "CO detected",
]

func isDeviceAlert(_ device: Device) -> Bool {
    switch device.controlKind {
    case .sensorReadonly: return alertSensorTexts.contains(device.sensorValue)
    case .cameraFeed: return device.motionDetected && !device.privacyMode
    case .securityPanel: return device.alarmState == .triggered
    case .garage: return device.obstructionDetected
    case .lock: return device.doorAjar
    default: return false
    }
}

/// 0...1 live progress shown as the card's bottom bar, or -1 for none.
func deviceProgress(_ device: Device) -> Double {
    switch device.controlKind {
    case .dimmer: return device.isOn ? device.brightness : 0
    case .blindsSlider: return device.position
    case .mediaPlayer: return device.isOn ? device.trackProgress : 0
    case .fanSpeed: return device.isOn ? Double(device.fanSpeed) / 4 : 0
    case .garage: return device.doorPosition
    case .waterHeaterDial: return Double(device.hotWaterPercent) / 100
    case .robotVacuum: return Double(device.batteryPercent) / 100
    case .evCharger:
        return device.type == .poolPump ? -1 : Double(device.chargePercent) / 100
    case .applianceCycle:
        return device.applianceMode == .running || device.applianceMode == .paused
            ? device.cycleProgress
            : -1
    default: return -1
    }
}

func sensorShortText(_ device: Device) -> String {
    device.type == .climateSensor
        ? "\(device.currentTempF.rounded0)°"
        : String(device.sensorValue.split(separator: " ").first ?? "")
}

func panelShortText(_ device: Device) -> String {
    switch device.alarmState {
    case .disarmed: return "Off"
    case .armedHome: return "Home"
    case .armedAway: return "Away"
    case .armedNight: return "Night"
    case .arming: return "\(device.exitCountdownSeconds)s"
    case .triggered: return "Alarm"
    }
}

/// One-line live status for a card.
func deviceStatusText(_ device: Device) -> String {
    guard device.isOnline else { return "Offline" }
    switch device.controlKind {
    case .dimmer:
        return device.isOn ? "\((device.brightness * 100).rounded0)% brightness" : "Off"
    case .toggle:
        return device.isOn ? "\(device.powerDrawWatts.rounded0) W" : "Off"
    case .thermostatDial:
        if !device.isOn || device.hvacMode == .off { return "Off" }
        if device.isHeating { return "Heating to \(device.targetTempF.rounded0)°" }
        if device.isCooling { return "Cooling to \(device.targetTempF.rounded0)°" }
        return "Holding \(device.targetTempF.rounded0)°"
    case .waterHeaterDial:
        return "\(device.hotWaterPercent)% hot water"
    case .lock:
        if device.doorAjar { return "Door ajar" }
        return device.lockState == .locked ? "Locked" : "Unlocked"
    case .garage:
        if device.obstructionDetected { return "Obstruction" }
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
        if device.isOn && device.isPlaying {
            return device.trackTitle.isEmpty ? "Playing" : device.trackTitle
        }
        return "Paused"
    case .fanSpeed:
        return !device.isOn || device.fanSpeed == 0 ? "Off" : "Speed \(device.fanSpeed)"
    case .applianceCycle:
        if device.type == .fridge { return "Freezer \(device.freezerTempF.rounded0)°" }
        if device.applianceMode == .running { return "\(device.minutesRemaining) min left" }
        return device.applianceMode.displayName
    case .robotVacuum:
        return "\(device.vacuumState.displayName) · \(device.batteryPercent)%"
    case .evCharger:
        if device.type == .poolPump { return device.isOn ? "\(device.pumpSpeedRpm) rpm" : "Off" }
        if device.isCharging { return "Charging · \(device.chargePercent)%" }
        return "\(device.chargePercent)% charged"
    case .sprinklerZones:
        return device.activeZones.isEmpty
            ? "Idle · \(device.soilMoisturePercent)% soil"
            : "Watering \(device.activeZones.count)/\(device.totalZones)"
    case .sensorReadonly:
        return device.sensorValue
    case .securityPanel:
        if device.alarmState == .arming { return "Arming · \(device.exitCountdownSeconds)s" }
        return device.alarmState.displayName
    }
}
