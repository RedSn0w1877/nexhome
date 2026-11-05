import SwiftUI

/// Home: a greeting hero with glass stat pills, an alerts strip, a Control-Center module grid built
/// from the kit (whole-home lights fader, climate dial, security hold orb), scene hold orbs, a
/// rooms carousel, the whole-home energy panel with a 24 h sparkline and featured device cards.
struct HomeScreen: View {
    let onRoomTap: (Room) -> Void
    let onDeviceTap: (Device) -> Void
    let onSeeAllRooms: () -> Void

    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                GreetingHero(alertCount: repository.alerts().count)
                    .padding(.horizontal, 20)

                let alerts = repository.alerts()
                if !alerts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(alerts) { device in
                                AlertPill(device: device) { onDeviceTap(device) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()
                }

                ScreenSectionLabel(title: "Control Center")
                    .padding(.horizontal, 24)

                ControlCenterGrid(onDeviceTap: onDeviceTap)
                    .padding(.horizontal, 20)

                ScenesSection()
                    .padding(.horizontal, 20)

                ScreenSectionLabel(title: "Rooms", action: "See all", onAction: onSeeAllRooms)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(repository.roomsWithDevices) { room in
                            RoomCarouselTile(room: room) { onRoomTap(room) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                }
                .scrollClipDisabled()

                EnergyPanel()
                    .padding(.horizontal, 20)

                ScreenSectionLabel(title: "Featured")
                    .padding(.horizontal, 24)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(featuredDevices(repository)) { device in
                        DeviceCard(device: device, showRoom: true) { onDeviceTap(device) }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Hero and alerts

private struct GreetingHero: View {
    let alertCount: Int
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let onCount = repository.devices.filter { $0.isOn }.count
        let watts = repository.totalPowerWatts()
        let scene = repository.activeScene

        GlassPanel(
            shape: glassRect(32),
            tint: NexColors.glassTintDark,
            heavy: true,
            surface: AnyView(
                ZStack {
                    AccentWash(
                        color: NexColors.violet,
                        center: UnitPoint(x: 0.08, y: 0.05),
                        radiusFraction: 1,
                        amount: 0.26
                    )
                    AccentWash(
                        color: NexColors.cyan,
                        center: UnitPoint(x: 0.95, y: 0.95),
                        radiusFraction: 0.8,
                        amount: 0.16
                    )
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 4) {
                NexText(dateText.uppercased(), .caption, color: NexColors.tertiary).lineLimit(1)
                NexText(greetingForNow(), .headline).lineLimit(1)
                NexText(
                    scene.map { "\($0.label) scene · \($0.detail)" }
                        ?? "Watching over \(repository.roomsWithDevices.count) rooms and \(repository.devices.count) devices",
                    .body,
                    color: NexColors.secondary
                )
                .lineLimit(2)

                Spacer().frame(height: 12)

                HStack(spacing: 10) {
                    GlassStatPill(
                        value: "\(onCount)",
                        label: "on now",
                        accent: NexColors.mint,
                        symbol: "power"
                    )
                    GlassStatPill(
                        value: powerValueText(watts),
                        label: "\(powerUnitText(watts)) now",
                        accent: NexColors.amber,
                        symbol: "bolt.fill"
                    )
                    GlassStatPill(
                        value: "\(alertCount)",
                        label: alertCount == 1 ? "alert" : "alerts",
                        accent: alertCount > 0 ? NexColors.red : NexColors.cyan,
                        symbol: "bell.badge.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var dateText: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private struct AlertPill: View {
    let device: Device
    let action: () -> Void

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: NexColors.red.opacity(0.12),
            accent: NexColors.red,
            pressScale: 1.1,
            action: action
        ) {
            HStack(spacing: 10) {
                GlassIconOrb(
                    symbol: device.type.symbol,
                    accent: NexColors.red,
                    size: 36,
                    glow: 0.7,
                    iconTint: .white
                )
                VStack(alignment: .leading, spacing: 0) {
                    NexText(device.name, .label).lineLimit(1)
                    NexText(alertLabel(device), .caption, color: NexColors.red).lineLimit(1)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 18)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Control Center modules

private struct ControlCenterGrid: View {
    let onDeviceTap: (Device) -> Void
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let lights = repository.devices(ofKind: .dimmer)
        let climate = repository.devices(ofKind: .thermostatDial)
        let thermostat = climate.first { $0.type == .thermostat } ?? climate.first
        let panel = repository.devices(ofKind: .securityPanel).first

        HStack(spacing: 14) {
            LightsModule(lights: lights)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 14) {
                ClimateModule(device: thermostat, onOpen: onDeviceTap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                SecurityModule(panel: panel, onOpen: onDeviceTap)
                    .frame(height: 158)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 372)
    }
}

/// A heavy glass module panel; controls inside it refract it.
private struct ModulePanel<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassPanel(shape: glassRect(30), tint: NexColors.glassTintDark, heavy: true) {
            VStack(spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(padding)
        }
    }
}

private struct ModuleHeader: View {
    let title: String
    let caption: String
    let symbol: String
    let accent: Color
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 0) {
                NexText(title, .bodyStrong).lineLimit(1)
                NexText(caption, .caption, color: NexColors.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let onOpen { ModuleOpenButton(action: onOpen) }
        }
    }
}

private struct ModuleOpenButton: View {
    let action: () -> Void

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: NexColors.glassTintLight,
            pressScale: GlassMotion.orbPressScale,
            action: action
        ) {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NexColors.primary)
                .frame(width: 30, height: 30)
        }
    }
}

private struct LightsModule: View {
    let lights: [Device]

    var body: some View {
        let accent = deviceAccent(ControlKind.dimmer)
        let onCount = lights.filter { $0.isOn }.count
        let level = lights.isEmpty
            ? 0
            : lights.reduce(0.0) { $0 + ($1.isOn ? $1.brightness : 0) } / Double(lights.count)

        ModulePanel {
            ModuleHeader(
                title: "Lights",
                caption: "\(onCount) of \(lights.count) on",
                symbol: "lightbulb.fill",
                accent: accent
            )
            Spacer(minLength: 0)
            LiquidFader(
                value: level,
                accent: accent,
                symbol: "sun.max.fill",
                label: "Whole home",
                width: 104,
                height: 268
            ) { value in
                for light in lights {
                    light.brightness = value
                    light.isOn = value > 0.01
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ClimateModule: View {
    let device: Device?
    let onOpen: (Device) -> Void

    var body: some View {
        let accent = device.map { deviceAccent($0.type) } ?? deviceAccent(ControlKind.thermostatDial)
        ModulePanel(padding: 12) {
            if let device {
                ModuleHeader(
                    title: "Climate",
                    caption: climateCaption(device),
                    symbol: "thermometer.medium",
                    accent: accent,
                    onOpen: { onOpen(device) }
                )
                Spacer(minLength: 0)
                LiquidDial(
                    value: device.targetTempF,
                    range: 60...82,
                    accent: accent,
                    detents: 1,
                    size: 128,
                    onChange: { device.targetTempF = $0 }
                ) {
                    VStack(spacing: 0) {
                        NexText("\(device.targetTempF.rounded0)°", .title).lineLimit(1)
                        NexText("now \(device.currentTempF.rounded0)°", .caption, color: NexColors.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            } else {
                ModuleHeader(
                    title: "Climate",
                    caption: "No thermostat",
                    symbol: "thermometer.medium",
                    accent: accent
                )
                Spacer(minLength: 0)
            }
        }
    }
}

private struct SecurityModule: View {
    let panel: Device?
    let onOpen: (Device) -> Void
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let accent = deviceAccent(ControlKind.securityPanel)
        ModulePanel(padding: 10) {
            if let panel {
                ZStack(alignment: .topTrailing) {
                    let armed = panel.alarmState != .disarmed
                    LiquidHoldOrb(
                        label: panel.alarmState == .triggered
                            ? "Hold to silence"
                            : (armed ? "Hold to disarm" : "Hold to arm"),
                        symbol: armed ? "shield.fill" : "shield.lefthalf.filled",
                        accent: accent,
                        active: armed,
                        size: 72,
                        sublabel: alarmStateText(panel)
                    ) {
                        repository.armSecurity(panel, armed ? .disarmed : .armedAway)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ModuleOpenButton(action: { onOpen(panel) })
                }
            } else {
                NexText("No security panel", .caption, color: NexColors.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Scenes, rooms, energy

private struct ScenesSection: View {
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let active = repository.activeScene
        GlassSection(
            title: "Scenes",
            symbol: "sparkles",
            accent: NexColors.gold,
            spacing: 18,
            trailing: AnyView(
                NexText(
                    active?.label ?? "Hold to apply",
                    .caption,
                    color: active.map(sceneAccent) ?? NexColors.tertiary
                )
                .lineLimit(1)
            )
        ) {
            ForEach(Array(stride(from: 0, to: HomeScene.allCases.count, by: 2)), id: \.self) { start in
                HStack(spacing: 8) {
                    ForEach(HomeScene.allCases[start..<min(start + 2, HomeScene.allCases.count)]) { scene in
                        LiquidHoldOrb(
                            label: scene.label,
                            symbol: scene.symbol,
                            accent: sceneAccent(scene),
                            active: active == scene,
                            holdMillis: 700,
                            size: 76,
                            sublabel: scene.detail
                        ) {
                            repository.apply(scene: scene)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct RoomCarouselTile: View {
    let room: Room
    let action: () -> Void
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let devices = repository.devices(in: room)
        let onCount = devices.filter { $0.isOn }.count
        let total = Double(max(devices.count, 1))
        let accent = roomAccent(room)

        GlassPanel(
            shape: glassRect(26),
            tint: NexColors.glassTint,
            accent: accent,
            action: action,
            front: AnyView(
                GlassFillBar(fraction: Double(onCount) / total, accent: accent, inset: 14)
            )
        ) {
            VStack(alignment: .leading, spacing: 0) {
                GlassIconOrb(
                    symbol: room.symbol,
                    accent: accent,
                    size: 40,
                    glow: Double(onCount) / total,
                    iconTint: .white
                )
                Spacer(minLength: 8)
                NexText(room.displayName, .bodyStrong).lineLimit(1)
                NexText("\(onCount) of \(devices.count) on", .caption, color: NexColors.secondary)
                    .lineLimit(1)
            }
            .frame(width: 156, height: 138, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .frame(width: 184, height: 172)
    }
}

private struct EnergyPanel: View {
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let accent = NexColors.amber
        let watts = repository.totalPowerWatts()
        let todayKwh = repository.devices.reduce(0.0) { $0 + $1.energyTodayKwh }
        let history = repository.homeEnergyHistory
        let peak = history.max() ?? 0

        GlassPanel(shape: glassRect(30), tint: NexColors.glassTintDark, heavy: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    GlassIconOrb(
                        symbol: "bolt.fill",
                        accent: accent,
                        size: 42,
                        glow: 0.55,
                        iconTint: .white
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        NexText("Energy", .title).lineLimit(1)
                        NexText("Whole home · last 24 hours", .caption, color: NexColors.tertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            NexText(powerValueText(watts), .title, color: accent).lineLimit(1)
                            NexText(powerUnitText(watts), .label, color: NexColors.secondary)
                                .lineLimit(1)
                        }
                        NexText("live", .caption, color: NexColors.tertiary).lineLimit(1)
                    }
                }

                // Chart well: the sparkline is drawn inside its own glass surface.
                GlassPanel(
                    shape: glassRect(22),
                    tint: Color.black.opacity(0.16),
                    interactive: true,
                    pressScale: 1.03,
                    surface: AnyView(
                        EnergyChart(history: history, accent: accent)
                    )
                ) {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            NexText("24h ago", .caption, color: NexColors.tertiary)
                            Spacer()
                            NexText("12h", .caption, color: NexColors.tertiary)
                            Spacer()
                            NexText("Now", .caption, color: accent)
                        }
                    }
                    .frame(height: 132)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                HStack(spacing: 10) {
                    GlassMetricTile(label: "Today kWh", value: todayKwh.fixed(1), accent: accent)
                    GlassMetricTile(
                        label: "Est. cost",
                        value: "$" + (todayKwh * 0.28).fixed(2),
                        accent: NexColors.mint
                    )
                    GlassMetricTile(label: "Peak kW", value: peak.fixed(1), accent: NexColors.rose)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

/// Smooth 24 h energy sparkline with grid lines and a live dot.
private struct EnergyChart: View {
    let history: [Double]
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if history.count >= 2, size.width > 40, size.height > 50 {
                let top: CGFloat = 18
                let bottom = size.height - 32
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        let y = top + (bottom - top) * CGFloat(index) / 2
                        Path { path in
                            path.move(to: CGPoint(x: 14, y: y))
                            path.addLine(to: CGPoint(x: size.width - 14, y: y))
                        }
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
                    Sparkline(
                        values: history,
                        accent: accent,
                        bandHeight: bottom - top,
                        horizontalInset: 18,
                        smooth: true
                    )
                    .frame(height: bottom)
                    .frame(height: size.height, alignment: .top)
                    LiveDot(history: history, accent: accent, top: top, bottom: bottom)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LiveDot: View {
    let history: [Double]
    let accent: Color
    let top: CGFloat
    let bottom: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let minV = history.min() ?? 0
            let maxV = history.max() ?? 1
            let span = (maxV - minV) > 1e-4 ? (maxV - minV) : 1
            let last = history.last ?? 0
            let x = size.width - 18
            let y = bottom - CGFloat((last - minV) / span) * (bottom - top)
            ZStack {
                Circle().fill(accent.opacity(0.3)).frame(width: 18, height: 18)
                Circle().fill(Color.white).frame(width: 7, height: 7)
            }
            .position(x: x, y: y)
        }
    }
}

// MARK: - Helpers

private let featuredKinds: [ControlKind] = [
    .thermostatDial, .lock, .mediaPlayer, .cameraFeed, .robotVacuum, .evCharger, .garage,
    .applianceCycle,
]

@MainActor
func featuredDevices(_ repository: DeviceRepository) -> [Device] {
    let favorites = repository.devices.filter { $0.isFavorite }
    let picks = featuredKinds.compactMap { repository.devices(ofKind: $0).first }
    var seen = Set<String>()
    var result: [Device] = []
    for device in favorites + picks where !seen.contains(device.id) {
        seen.insert(device.id)
        result.append(device)
        if result.count == 12 { break }
    }
    return result
}

func greetingForNow() -> String {
    let hour = Calendar.current.component(.hour, from: .now)
    switch hour {
    case 5...11: return "Good morning"
    case 12...16: return "Good afternoon"
    case 17...20: return "Good evening"
    default: return "Good night"
    }
}

func climateCaption(_ device: Device) -> String {
    let activity: String
    if !device.isOn || device.hvacMode == .off {
        activity = "Off"
    } else if device.isHeating {
        activity = "Heating"
    } else if device.isCooling {
        activity = "Cooling"
    } else {
        activity = "Idle"
    }
    return "\(device.room.displayName) · \(activity)"
}

func alertLabel(_ device: Device) -> String {
    switch device.controlKind {
    case .cameraFeed: return "Motion · \(device.room.displayName)"
    case .securityPanel: return "Alarm triggered"
    case .garage: return "Obstruction detected"
    case .lock: return "Door ajar"
    default: return "\(device.sensorValue) · \(device.room.displayName)"
    }
}

func sceneAccent(_ scene: HomeScene) -> Color {
    switch scene {
    case .morning: return NexColors.gold
    case .away: return NexColors.indigo
    case .movie: return NexColors.pink
    case .bedtime: return NexColors.blue
    }
}
