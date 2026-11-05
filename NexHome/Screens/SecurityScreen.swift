import SwiftUI

private let modeTargets: [AlarmState] = [.disarmed, .armedHome, .armedAway, .armedNight]

/// Security: a heavy glass alarm hero (state, open zones, a draggable arm-mode selector; the glass
/// washes red and pulses while triggered), stat pills, then grids of lock/garage and sensor cards.
struct SecurityScreen: View {
    let onDeviceTap: (Device) -> Void

    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let panel = repository.devices(ofKind: .securityPanel).first
        let access = repository.devices(ofKind: .lock) + repository.devices(ofKind: .garage)
        let sensors = repository.devices(ofKind: .sensorReadonly)
        let secured = access.filter {
            $0.controlKind == .garage ? $0.garageState == .closed : $0.lockState == .locked
        }.count
        let alertCount = sensors.filter { alertSensorTexts.contains($0.sensorValue) }.count
            + access.filter { $0.doorAjar || $0.obstructionDetected }.count
        let openZones = panel?.securityZones.filter { $0.isOpen && !$0.bypassed }.count ?? 0

        ScrollView {
            LazyVStack(spacing: 12) {
                ScreenTitle("Security", subtitle: "\(access.count) doors · \(sensors.count) sensors")

                if let panel {
                    SecurityHero(panel: panel, onOpen: { onDeviceTap(panel) })
                }

                HStack(spacing: 10) {
                    GlassStatPill(
                        value: "\(secured)/\(access.count)",
                        label: "secured",
                        accent: NexColors.mint,
                        symbol: "lock.fill"
                    )
                    GlassStatPill(
                        value: "\(alertCount)",
                        label: "alerts",
                        accent: alertCount > 0 ? NexColors.red : NexColors.cyan,
                        symbol: "bell.badge.fill"
                    )
                    GlassStatPill(
                        value: "\(openZones)",
                        label: "open zones",
                        accent: NexColors.amber,
                        symbol: "door.left.hand.open"
                    )
                }

                ScreenSectionLabel(title: "Locks & doors")

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(access) { device in
                        DeviceCard(device: device, showRoom: true) { onDeviceTap(device) }
                    }
                }

                ScreenSectionLabel(title: "Sensors")

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(sensors) { device in
                        DeviceCard(device: device, showRoom: true) { onDeviceTap(device) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct SecurityHero: View {
    @Bindable var panel: Device
    let onOpen: () -> Void

    @Environment(DeviceRepository.self) private var repository
    @State private var pulse: Double = 0

    var body: some View {
        let accent = deviceAccent(ControlKind.securityPanel)
        let state = panel.alarmState
        let armed = state != .disarmed
        let triggered = state == .triggered
        let openZones = panel.securityZones.filter(\.isOpen).count

        GlassPanel(
            shape: glassRect(32),
            tint: NexColors.glassTintDark,
            heavy: true,
            surface: AnyView(
                ZStack {
                    AccentWash(
                        color: accent,
                        center: UnitPoint(x: 0.15, y: 0.2),
                        radiusFraction: 1,
                        amount: armed ? 0.3 : 0
                    )
                    NexColors.red.opacity(0.34 * pulse)
                }
                .animation(GlassMotion.glow, value: armed)
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    GlassIconOrb(
                        symbol: armed ? "shield.fill" : "shield.lefthalf.filled",
                        accent: accent,
                        size: 56,
                        glow: max(armed ? 1 : 0, pulse),
                        iconTint: .white
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        NexText(
                            alarmStateText(panel),
                            .title,
                            color: triggered ? NexColors.red : NexColors.primary
                        )
                        .lineLimit(1)
                        NexText(
                            "\(panel.room.displayName) · \(openZones) open zones · entry \(panel.entryDelaySeconds)s",
                            .caption,
                            color: NexColors.secondary
                        )
                        .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    LiquidButton(action: onOpen) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NexColors.primary)
                    }
                }

                LiquidSegmented(
                    options: [
                        SegmentOption("Off", "lock.open.fill"),
                        SegmentOption("Home", "house.fill"),
                        SegmentOption("Away", "figure.walk.departure"),
                        SegmentOption("Night", "moon.stars.fill"),
                    ],
                    selectedIndex: modeIndex,
                    accent: accent
                ) { index in
                    repository.armSecurity(panel, modeTargets[index])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .task(id: triggered) {
            guard triggered else {
                withAnimation(GlassMotion.glow) { pulse = 0 }
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.52)) { pulse = 1 }
                try? await Task.sleep(for: .milliseconds(520))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.68)) { pulse = 0.25 }
                try? await Task.sleep(for: .milliseconds(680))
            }
        }
    }

    private var modeIndex: Int {
        switch panel.alarmState {
        case .disarmed: return 0
        case .armedHome: return 1
        case .armedAway, .triggered: return 2
        case .armedNight: return 3
        case .arming:
            guard let target = panel.armingTarget,
                  let index = modeTargets.firstIndex(of: target) else { return 2 }
            return index
        }
    }
}
