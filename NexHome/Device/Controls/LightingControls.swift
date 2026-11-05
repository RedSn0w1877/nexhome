import SwiftUI

// MARK: - Lights (ControlKind.dimmer)

/// Lights: ceiling lights, lamps, light strips, wall sconces and outdoor lights.
///
/// Hero: a brightness fader filled in the light's live colour next to a glass "stage" that renders
/// the fixture type (ceiling cone, lampshade, LED strip chase, sconce up/down wash, outdoor beam
/// with motion radar) glowing with the animated brightness and colour. Then colour temperature or
/// hue/saturation spectrum sliders, scenes, fade time, automation, energy and device info.
struct DimmerControls: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        let liveColor = lightColorOf(device)

        VStack(spacing: 16) {
            LightHeroSection(device: device, accent: accent, liveColor: liveColor)
            LightColorSection(device: device, accent: accent, liveColor: liveColor)
            LightScenesSection(device: device, accent: accent)
            LightAutomationSection(device: device, accent: accent)
            LightEnergySection(device: device, accent: accent)
            DeviceInfoSection(device: device, accent: accent)
        }
        // Switching on from the header at 0 % would look broken: restore a comfortable level.
        .onChange(of: device.isOn) { _, isOn in
            if isOn && device.brightness < 0.01 { device.brightness = 0.6 }
        }
    }
}

private struct LightHeroSection: View {
    @Bindable var device: Device
    let accent: Color
    let liveColor: Color

    var body: some View {
        let percent = (device.brightness * 100).rounded0
        let colorMode = device.supportsColor && device.lightColorMode == .color

        GlassSection(
            title: "Brightness",
            symbol: "sun.max.fill",
            accent: accent,
            trailing: AnyView(
                NexText(
                    device.isOn ? "\(percent)%" : "Off",
                    .caption,
                    color: device.isOn ? liveColor : NexColors.tertiary
                )
            )
        ) {
            HStack(alignment: .center, spacing: 14) {
                LiquidFader(
                    value: device.isOn ? device.brightness : 0,
                    accent: liveColor,
                    symbol: device.type.symbol,
                    label: "Level",
                    width: 92,
                    height: 248
                ) { value in
                    device.brightness = value
                    device.isOn = value > 0.01
                    device.activeScene = ""
                }

                VStack(alignment: .leading, spacing: 12) {
                    LightStage(device: device, liveColor: liveColor)
                        .frame(height: 180)
                    VStack(alignment: .leading, spacing: 2) {
                        NexText(device.isOn ? "\(percent)%" : "Off", .headline).lineLimit(1)
                        NexText(
                            "\(DeviceGenerator.estimateWatts(device).fixed(1)) W · "
                                + (colorMode
                                    ? "Hue \(device.hue.rounded0)° · \((device.saturation * 100).rounded0)% sat"
                                    : "\(device.colorTempK) K · \(warmthName(device.colorTempK))"),
                            .caption,
                            color: NexColors.tertiary
                        )
                        .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The fixture "stage": a glass panel whose surface renders the device type lit by the animated
/// brightness and colour. Party/Relax scenes, LED strips and armed outdoor sensors animate a phase.
private struct LightStage: View {
    let device: Device
    let liveColor: Color

    var body: some View {
        let level = device.isOn ? clamp01(device.brightness) : 0
        let scene = device.activeScene
        let party = device.isOn && scene == "Party"
        let relax = device.isOn && scene == "Relax"
        let motionArmed = device.type == .outdoorLight && device.motionActivated
        let animate = (device.isOn && (device.type == .lightStrip || party || relax)) || motionArmed
        let period: Double = party ? 1.5 : (relax ? 3.6 : 2.6)

        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.08),
            accent: liveColor,
            heavy: true,
            interactive: true,
            surface: AnyView(
                LightStageCanvas(
                    type: device.type,
                    level: level,
                    color: liveColor,
                    party: party,
                    relax: relax,
                    motionArmed: motionArmed,
                    animating: animate,
                    period: period
                )
                .animation(
                    .spring(
                        response: 0.287 * (1 + Double(max(device.fadeSeconds, 0)) * 1.4).squareRoot(),
                        dampingFraction: 0.62
                    ),
                    value: level
                )
            )
        ) {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The lit fixture itself. Redrawn from a timeline only while something is animating, so an idle
/// stage costs nothing.
private struct LightStageCanvas: View {
    let type: DeviceType
    let level: Double
    let color: Color
    let party: Bool
    let relax: Bool
    let motionArmed: Bool
    let animating: Bool
    let period: Double

    var body: some View {
        if animating {
            TimelineView(.animation) { context in
                let phase = (context.date.timeIntervalSinceReferenceDate / period)
                    .truncatingRemainder(dividingBy: 1)
                stage(phase: phase)
            }
        } else {
            stage(phase: 0)
        }
    }

    @ViewBuilder
    private func stage(phase: Double) -> some View {
        let tau = 2 * Double.pi
        let flicker: Double = {
            guard animating else { return 1 }
            if relax { return 0.9 + 0.1 * sin(phase * tau * 3) }
            if party { return 0.78 + 0.22 * sin(phase * tau * 2) }
            return 1
        }()
        let g = clamp01(level * flicker)
        let bright = color.lerp(to: .white, 0.35)
        let fixture = Color.white.opacity(0.3).lerp(to: bright, g)

        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                // The "room": darker when the light is off, washed in its colour when lit.
                Color.black.opacity(0.3 * (1 - level))
                if g > 0.005 {
                    color.opacity(0.1 * g).blendMode(.plusLighter)
                }

                switch type {
                case .lightStrip:
                    stripStage(w: w, h: h, g: g, phase: phase)
                case .lamp:
                    lampStage(w: w, h: h, g: g, bright: bright)
                case .wallSconce:
                    sconceStage(w: w, h: h, g: g, fixture: fixture)
                case .outdoorLight:
                    outdoorStage(w: w, h: h, g: g, bright: bright, fixture: fixture, phase: phase)
                default:
                    ceilingStage(w: w, h: h, g: g, bright: bright, fixture: fixture)
                }
            }
        }
    }

    // MARK: Fixtures

    @ViewBuilder
    private func stripStage(w: CGFloat, h: CGFloat, g: Double, phase: Double) -> some View {
        let y = h * 0.7
        let left = w * 0.1
        let right = w * 0.9
        let tau = 2 * Double.pi
        ZStack {
            if g > 0.005 {
                RadialGradient(
                    colors: [color.opacity(0.25 * g), .clear],
                    center: UnitPoint(x: 0.5, y: 0.7),
                    startRadius: 0,
                    endRadius: w * 0.78
                )
                .blendMode(.plusLighter)
            }
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: right - left + 12, height: 10)
                .position(x: w / 2, y: y)
            ForEach(0..<8, id: \.self) { index in
                let t = Double(index) / 7
                let x = left + (right - left) * t
                let ledColor = party && animating
                    ? Color(hue: ((t + phase).truncatingRemainder(dividingBy: 1)), saturation: 0.85, brightness: 1)
                    : color
                let shimmer = animating ? 0.6 + 0.4 * sin((t * 1.5 - phase) * tau) : 1
                let a = clamp01(g * shimmer)
                ZStack {
                    Circle()
                        .fill(ledColor.opacity(0.2 * a))
                        .frame(width: 24, height: 24)
                        .blur(radius: 5)
                        .blendMode(.plusLighter)
                    Circle()
                        .fill(Color.white.opacity(0.25).lerp(to: ledColor.lerp(to: .white, 0.4), a))
                        .frame(width: 7, height: 7)
                }
                .position(x: x, y: y)
            }
        }
    }

    @ViewBuilder
    private func lampStage(w: CGFloat, h: CGFloat, g: Double, bright: Color) -> some View {
        ZStack {
            if g > 0.005 {
                RadialGradient(
                    colors: [bright.opacity(0.38 * g), .clear],
                    center: UnitPoint(x: 0.5, y: 0.46),
                    startRadius: 0,
                    endRadius: w * 0.75
                )
                .blendMode(.plusLighter)
                RadialGradient(
                    colors: [color.opacity(0.23 * g), .clear],
                    center: UnitPoint(x: 0.5, y: 0.92),
                    startRadius: 0,
                    endRadius: w * 0.625
                )
                .blendMode(.plusLighter)
            }
            Path { path in
                path.move(to: CGPoint(x: w / 2, y: h * 0.46))
                path.addLine(to: CGPoint(x: w / 2, y: h * 0.86))
            }
            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: w * 0.2, height: 4)
                .position(x: w / 2, y: h * 0.86 + 2)
            // Lampshade.
            Path { path in
                path.move(to: CGPoint(x: w * 0.38, y: h * 0.22))
                path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.22))
                path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.46))
                path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.46))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.16).lerp(to: bright.opacity(0.92), g))
        }
    }

    @ViewBuilder
    private func sconceStage(w: CGFloat, h: CGFloat, g: Double, fixture: Color) -> some View {
        ZStack {
            if g > 0.005 {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.45, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w * 0.8, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.2, y: 0))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [.clear, color.opacity(0.3 * g)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.45, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.74, y: h))
                    path.addLine(to: CGPoint(x: w * 0.26, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.5 * g), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: w * 0.18, height: h * 0.28)
                .position(x: w * 0.5, y: h * 0.5)
            RoundedRectangle(cornerRadius: 4)
                .fill(fixture)
                .frame(width: w * 0.1, height: h * 0.18)
                .position(x: w * 0.5, y: h * 0.5)
        }
    }

    @ViewBuilder
    private func outdoorStage(
        w: CGFloat, h: CGFloat, g: Double, bright: Color, fixture: Color, phase: Double
    ) -> some View {
        let lamp = CGPoint(x: w * 0.17, y: h * 0.21)
        ZStack {
            if g > 0.005 {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.12, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w * 0.3, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.6 * g), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
                RadialGradient(
                    colors: [color.opacity(0.4 * g), .clear],
                    center: UnitPoint(x: 0.64, y: 1),
                    startRadius: 0,
                    endRadius: w * 0.45
                )
                .blendMode(.plusLighter)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [bright.opacity(0.9 * g), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.22
                        )
                    )
                    .frame(width: w * 0.44, height: w * 0.44)
                    .position(lamp)
                    .blendMode(.plusLighter)
            }
            if motionArmed && animating {
                ForEach(0..<2, id: \.self) { k in
                    let p = (phase + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.32 * (1 - p)), lineWidth: 1.5)
                        .frame(width: 20 + CGFloat(p) * w * 1.1, height: 20 + CGFloat(p) * w * 1.1)
                        .position(lamp)
                }
            }
            Circle()
                .fill(fixture)
                .frame(width: 14, height: 14)
                .position(lamp)
        }
    }

    @ViewBuilder
    private func ceilingStage(
        w: CGFloat, h: CGFloat, g: Double, bright: Color, fixture: Color
    ) -> some View {
        let top = h * 0.12
        ZStack {
            if g > 0.005 {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.3, y: top))
                    path.addLine(to: CGPoint(x: w * 0.7, y: top))
                    path.addLine(to: CGPoint(x: w * 0.98, y: h))
                    path.addLine(to: CGPoint(x: w * 0.02, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.55 * g), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)
                RadialGradient(
                    colors: [color.opacity(0.4 * g), .clear],
                    center: UnitPoint(x: 0.5, y: 1),
                    startRadius: 0,
                    endRadius: w * 0.6
                )
                .blendMode(.plusLighter)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [bright.opacity(0.85 * g), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.45
                        )
                    )
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w / 2, y: top)
                    .blendMode(.plusLighter)
            }
            Capsule()
                .fill(fixture)
                .frame(width: w * 0.4, height: 6)
                .position(x: w / 2, y: top)
        }
    }
}

private struct LightColorSection: View {
    @Bindable var device: Device
    let accent: Color
    let liveColor: Color

    var body: some View {
        let colorMode = device.supportsColor && device.lightColorMode == .color

        GlassSection(
            title: device.supportsColor ? "Color" : "Color temperature",
            symbol: colorMode ? "paintpalette.fill" : "lightbulb.max.fill",
            accent: liveColor,
            trailing: AnyView(
                NexText(
                    colorMode ? "Hue \(device.hue.rounded0)°" : "\(device.colorTempK) K",
                    .caption,
                    color: NexColors.secondary
                )
            )
        ) {
            if device.supportsColor {
                LiquidSegmented(
                    options: [
                        SegmentOption("White", "lightbulb.max.fill"),
                        SegmentOption("Color", "paintpalette.fill"),
                    ],
                    selectedIndex: device.lightColorMode.rawValue,
                    accent: accent
                ) { index in
                    device.lightColorMode = index == 0 ? .white : .color
                    device.activeScene = ""
                    if !device.isOn { device.isOn = true }
                }
            }

            if !colorMode {
                LiquidSpectrumSlider(
                    fraction: Double(device.colorTempK - kelvinMin) / Double(kelvinMax - kelvinMin),
                    colors: kelvinColors,
                    thumbColor: kelvinRampColor(device.colorTempK)
                ) { f in
                    let kelvin = Int((Double(kelvinMin) + f * Double(kelvinMax - kelvinMin)) / 50) * 50
                    device.colorTempK = clamp(kelvin, kelvinMin, kelvinMax)
                    device.activeScene = ""
                }
                HStack {
                    NexText("Warm · 2200 K", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText("6500 K · Cool", .caption, color: NexColors.tertiary)
                }
                LiquidChipRow {
                    ForEach(whitePresets, id: \.0) { preset in
                        LiquidChip(
                            label: preset.0,
                            selected: abs(device.colorTempK - preset.1) < 60,
                            accent: kelvinRampColor(preset.1)
                        ) {
                            device.colorTempK = preset.1
                            device.lightColorMode = .white
                            device.activeScene = ""
                            if !device.isOn { device.isOn = true }
                        }
                    }
                }
            } else {
                LiquidColorOrbs(
                    colors: orbColors,
                    selectedIndex: orbHues.firstIndex {
                        hueDistance($0, device.hue) < 2 && abs(device.saturation - orbSaturation) < 0.05
                    } ?? -1
                ) { index in
                    device.hue = orbHues[index]
                    device.saturation = orbSaturation
                    device.activeScene = ""
                    if !device.isOn { device.isOn = true }
                }
                NexText("Hue", .caption, color: NexColors.secondary)
                LiquidSpectrumSlider(
                    fraction: device.hue / 360,
                    colors: rainbowColors,
                    thumbColor: Color(hue: clamp01(device.hue / 360), saturation: 1, brightness: 1)
                ) { f in
                    device.hue = clamp(f * 360, 0, 360)
                    device.activeScene = ""
                }
                NexText("Saturation", .caption, color: NexColors.secondary)
                LiquidSpectrumSlider(
                    fraction: device.saturation,
                    colors: [
                        .white,
                        Color(hue: clamp01(device.hue / 360), saturation: 1, brightness: 1),
                    ],
                    thumbColor: liveColor
                ) { f in
                    device.saturation = f
                    device.activeScene = ""
                }
            }
        }
    }
}

private struct LightScenesSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        let active = lightScenePresets.first { $0.name == device.activeScene }

        GlassSection(
            title: "Scenes",
            symbol: "slider.horizontal.3",
            accent: accent,
            trailing: AnyView(
                NexText(
                    active?.name ?? "Custom",
                    .caption,
                    color: active?.tint ?? NexColors.tertiary
                )
            )
        ) {
            LiquidChipRow {
                ForEach(lightScenePresets, id: \.name) { scene in
                    LiquidChip(
                        label: scene.name,
                        symbol: scene.symbol,
                        selected: device.activeScene == scene.name,
                        accent: scene.tint
                    ) {
                        if device.activeScene == scene.name {
                            device.activeScene = ""
                        } else {
                            apply(scene: scene, to: device)
                        }
                    }
                }
            }
            NexText(
                active?.detail ?? "Tap a scene to set brightness and color in one go.",
                .caption,
                color: NexColors.tertiary
            )
            StepperRow(
                title: "Fade time",
                subtitle: device.fadeSeconds == 0
                    ? "Changes snap instantly"
                    : "Changes glide over \(device.fadeSeconds) s",
                value: device.fadeSeconds,
                range: 0...10,
                format: { $0 == 0 ? "Instant" : "\($0)s" },
                accent: accent
            ) { device.fadeSeconds = $0 }
        }
    }
}

private struct LightAutomationSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        let outdoor = device.type == .outdoorLight
        GlassSection(title: "Automation", symbol: "timer", accent: accent) {
            GlassSettingRow(
                title: "Motion activated",
                symbol: "sensor.fill",
                subtitle: {
                    switch device.type {
                    case .outdoorLight: return "Lights the path when someone approaches"
                    case .wallSconce: return "Glows softly as you walk by"
                    default: return "Turns on when the room is occupied"
                    }
                }(),
                accent: accent
            ) {
                LiquidToggle(isOn: device.motionActivated, accent: accent) {
                    device.motionActivated = $0
                }
            }
            GlassSettingRow(
                title: outdoor ? "Dusk to dawn" : "On at sunset",
                symbol: "sun.horizon.fill",
                subtitle: outdoor ? "On at sunset, off at sunrise" : "Turns on as daylight fades",
                accent: accent
            ) {
                LiquidToggle(isOn: device.sunsetSchedule, accent: accent) {
                    device.sunsetSchedule = $0
                }
            }
        }
    }
}

private struct LightEnergySection: View {
    let device: Device
    let accent: Color

    var body: some View {
        let watts = DeviceGenerator.estimateWatts(device)
        let kwh = device.energyTodayKwh

        GlassSection(
            title: "Energy",
            symbol: "bolt.fill",
            accent: accent,
            trailing: AnyView(NexText("Today", .caption, color: NexColors.tertiary))
        ) {
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Now",
                    value: watts.fixed(1),
                    unit: "W",
                    symbol: "bolt.fill",
                    accent: accent,
                    history: device.powerHistory
                )
                GlassMetricTile(
                    label: "Used today",
                    value: kwh.fixed(2),
                    unit: "kWh",
                    symbol: "chart.line.uptrend.xyaxis",
                    accent: accent
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Cost today",
                    value: "$" + (kwh * energyRate).fixed(2),
                    symbol: "dollarsign.circle.fill",
                    accent: accent
                )
                GlassMetricTile(
                    label: "Month est.",
                    value: "$" + (kwh * 30 * energyRate).fixed(2),
                    symbol: "calendar",
                    accent: accent
                )
            }
            HourlyUsageBars(history: device.powerHistory, accent: accent)
                .frame(height: 120)
            GlassSettingRow(
                title: device.isOn
                    ? "Dimming saves ≈ \(((1 - device.brightness) * 100).rounded0)%"
                    : "Standby draw 0.3 W",
                symbol: "leaf.fill",
                subtitle: device.isOn
                    ? "Compared with running at full brightness"
                    : "The light is off",
                accent: accent
            )
        }
    }
}

// MARK: - Plugs / outlets (ControlKind.toggle)

/// Plugs and outlets.
///
/// Hero: a hold-to-switch orb (longer hold while the child lock is on) beside a live AC-waveform
/// glass panel whose amplitude follows the load. Then usage metrics with the power sparkline, a 24 h
/// schedule timeline with on/off steppers, safety (child lock, overload protection with a load
/// gauge) and device info.
struct PlugControls: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        VStack(spacing: 16) {
            PlugPowerSection(device: device, accent: accent)
            PlugUsageSection(device: device, accent: accent)
            PlugScheduleSection(device: device, accent: accent)
            PlugSafetySection(device: device, accent: accent)
            DeviceInfoSection(device: device, accent: accent)
        }
        // A plug switched on with no recorded load gets a plausible one.
        .onChange(of: device.isOn) { _, isOn in
            if isOn && device.powerDrawWatts < 2 { device.powerDrawWatts = 36 }
        }
    }
}

private struct PlugPowerSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        GlassSection(title: "Power", symbol: "powerplug.fill", accent: accent) {
            HStack(spacing: 14) {
                LiquidHoldOrb(
                    label: device.isOn ? "Hold to switch off" : "Hold to switch on",
                    symbol: "power",
                    accent: accent,
                    active: device.isOn,
                    holdMillis: device.childLock ? 1600 : 700,
                    size: 118,
                    sublabel: device.childLock ? "Child lock · long hold" : nil
                ) {
                    setPlugPower(device, !device.isOn)
                }
                PowerWavePanel(device: device, accent: accent, maxWatts: plugMaxWatts(device))
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Live AC-waveform glass panel: amplitude follows the load with a bouncy spring, flat when off.
private struct PowerWavePanel: View {
    let device: Device
    let accent: Color
    let maxWatts: Int

    var body: some View {
        let on = device.isOn
        let watts = on ? device.powerDrawWatts : 0
        let amplitude = on ? clamp01(0.22 + 0.78 * (watts / 180)) : 0

        GlassPanel(
            shape: glassRect(24),
            tint: NexColors.glassTintDark,
            accent: accent,
            heavy: true,
            interactive: true,
            surface: AnyView(
                PowerWave(amplitude: amplitude, accent: accent, animating: on)
                    .animation(GlassMotion.release, value: amplitude)
            )
        ) {
            VStack(alignment: .leading, spacing: 2) {
                NexText("LIVE DRAW", .caption, color: NexColors.tertiary).lineLimit(1)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    NexText(watts.fixed(1), .headline).lineLimit(1)
                    NexText("W", .label, color: NexColors.tertiary)
                }
                NexText(
                    on
                        ? "\((watts / Double(maxWatts) * 100).fixed(1))% of \(maxWatts) W"
                        : "Standby · 0.4 W",
                    .caption,
                    color: NexColors.secondary
                )
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
        }
    }
}

private struct PowerWave: View {
    let amplitude: Double
    let accent: Color
    let animating: Bool

    var body: some View {
        if animating {
            TimelineView(.animation) { context in
                wave(phase: (context.date.timeIntervalSinceReferenceDate / 1.1)
                    .truncatingRemainder(dividingBy: 1))
            }
        } else {
            wave(phase: 0)
        }
    }

    @ViewBuilder
    private func wave(phase: Double) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let left: CGFloat = 14
            let right = w - left
            let span = right - left
            let midY = h * 0.78
            let maxAmp = h * 0.12
            let tau = 2 * Double.pi
            let path = Path { path in
                let steps = 56
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    let x = left + span * CGFloat(t)
                    let envelope = sin(Double.pi * t)
                    let y = midY - CGFloat(sin((t * 3 - phase) * tau) * Double(maxAmp) * amplitude * envelope)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: left, y: midY))
                    p.addLine(to: CGPoint(x: right, y: midY))
                }
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                path
                    .stroke(
                        accent.opacity(0.3 * clamp01(amplitude)),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                    )
                    .blendMode(.plusLighter)
                path.stroke(
                    Color.white.opacity(0.35).lerp(to: accent, clamp01(amplitude)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PlugUsageSection: View {
    let device: Device
    let accent: Color

    var body: some View {
        let watts = device.isOn ? device.powerDrawWatts : 0
        let kwh = device.energyTodayKwh
        let history = device.powerHistory
        let average = history.isEmpty ? 0 : history.reduce(0, +) / Double(history.count)
        let peak = history.max() ?? 0

        GlassSection(
            title: "Usage",
            symbol: "chart.line.uptrend.xyaxis",
            accent: accent,
            trailing: AnyView(NexText("Last 24 h", .caption, color: NexColors.tertiary))
        ) {
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Power",
                    value: watts.fixed(0),
                    unit: "W",
                    symbol: "bolt.fill",
                    accent: accent,
                    history: history
                )
                GlassMetricTile(
                    label: "Today",
                    value: kwh.fixed(2),
                    unit: "kWh",
                    symbol: "chart.line.uptrend.xyaxis",
                    accent: accent
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "24 h avg",
                    value: average.fixed(0),
                    unit: "W",
                    symbol: "clock.arrow.circlepath",
                    accent: accent
                )
                GlassMetricTile(
                    label: "Peak",
                    value: peak.fixed(0),
                    unit: "W",
                    symbol: "speedometer",
                    accent: accent
                )
            }
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Cost today",
                    value: "$" + (kwh * energyRate).fixed(2),
                    symbol: "dollarsign.circle.fill",
                    accent: accent
                )
                GlassMetricTile(
                    label: "Month est.",
                    value: "$" + (kwh * 30 * energyRate).fixed(2),
                    symbol: "calendar",
                    accent: accent
                )
            }
        }
    }
}

private struct PlugScheduleSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        GlassSection(title: "Schedule", symbol: "clock.fill", accent: accent) {
            GlassSettingRow(
                title: "Daily schedule",
                symbol: "calendar.badge.clock",
                subtitle: "On \(hourLabel(device.scheduleOnHour)) · Off \(hourLabel(device.scheduleOffHour))",
                accent: accent
            ) {
                LiquidToggle(isOn: device.scheduleEnabled, accent: accent) {
                    device.scheduleEnabled = $0
                }
            }
            ScheduleTimeline(
                onHour: device.scheduleOnHour,
                offHour: device.scheduleOffHour,
                enabled: device.scheduleEnabled,
                accent: accent
            )
            StepperRow(
                title: "Turn on",
                subtitle: "Power returns",
                value: device.scheduleOnHour,
                range: 0...23,
                format: hourLabel,
                accent: accent
            ) { device.scheduleOnHour = $0 }
            StepperRow(
                title: "Turn off",
                subtitle: "Power cuts",
                value: device.scheduleOffHour,
                range: 0...23,
                format: hourLabel,
                accent: accent
            ) { device.scheduleOffHour = $0 }
        }
    }
}

private struct PlugSafetySection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        let maxWatts = plugMaxWatts(device)
        GlassSection(title: "Safety", symbol: "shield.fill", accent: accent) {
            GlassSettingRow(
                title: "Child lock",
                symbol: "figure.and.child.holdinghands",
                subtitle: device.childLock
                    ? "Button disabled · long hold in app"
                    : "Physical button works normally",
                accent: accent
            ) {
                LiquidToggle(isOn: device.childLock, accent: accent) { device.childLock = $0 }
            }
            GlassSettingRow(
                title: "Overload protection",
                symbol: "checkmark.shield.fill",
                subtitle: "Cuts power above \(maxWatts) W",
                accent: accent
            ) {
                LiquidToggle(isOn: device.overloadProtection, accent: accent) {
                    device.overloadProtection = $0
                }
            }
            LoadGauge(device: device, accent: accent, maxWatts: maxWatts)
        }
    }
}

/// Glass capsule gauge of the live load (square-root scale so small loads stay visible).
private struct LoadGauge: View {
    let device: Device
    let accent: Color
    let maxWatts: Int

    var body: some View {
        let watts = device.isOn ? device.powerDrawWatts : 0
        let fraction = (clamp01(watts / Double(maxWatts))).squareRoot()

        GlassPanel(
            shape: glassCapsule,
            tint: NexColors.glassTintDark,
            accent: accent,
            interactive: true,
            surface: AnyView(
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    ZStack(alignment: .leading) {
                        NexColors.red.opacity(device.overloadProtection ? 0.24 : 0.08)
                            .frame(width: w * 0.14, height: h)
                            .offset(x: w * 0.86)
                        if fraction > 0.001 {
                            accent.opacity(0.5).frame(width: w * CGFloat(fraction), height: h)
                            Color.white.opacity(0.4)
                                .frame(width: 2, height: h)
                                .offset(x: w * CGFloat(fraction) - 2)
                                .blendMode(.plusLighter)
                        }
                    }
                }
                .animation(GlassMotion.release, value: fraction)
            )
        ) {
            HStack {
                NexText("Load \(watts.fixed(0)) W", .label).lineLimit(1)
                Spacer()
                NexText(
                    device.overloadProtection ? "Cutoff \(maxWatts) W" : "Unprotected",
                    .caption,
                    color: device.overloadProtection ? NexColors.secondary : NexColors.red
                )
                .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
    }
}

@MainActor
private func setPlugPower(_ device: Device, _ on: Bool) {
    if on && device.powerDrawWatts < 2 { device.powerDrawWatts = 36 }
    device.isOn = on
}

private func plugMaxWatts(_ device: Device) -> Int {
    device.type == .smartOutlet ? 1800 : 1500
}

// MARK: - Light palettes and scenes

private let kelvinMin = 2200
private let kelvinMax = 6500
private let kelvinStops = [2200, 2700, 3200, 4000, 5000, 6500]
private let kelvinColors: [Color] = [
    Color(hex: 0xFF8E3C),
    Color(hex: 0xFFAC5C),
    Color(hex: 0xFFC98E),
    Color(hex: 0xFFE3C4),
    Color(hex: 0xF3F1FF),
    Color(hex: 0xC4DBFF),
]
private let whitePresets: [(String, Int)] = [
    ("Candle", 2200), ("Warm", 2700), ("Soft", 3200),
    ("Neutral", 4000), ("Daylight", 5000), ("Cool", 6500),
]
private let rainbowColors: [Color] = [0.0, 60, 120, 180, 240, 300, 360].map {
    Color(hue: $0 / 360, saturation: 1, brightness: 1)
}
private let orbSaturation = 0.85
private let orbHues: [Double] = [0, 24, 45, 110, 165, 195, 225, 265, 300, 330]
private let orbColors: [Color] = orbHues.map {
    Color(hue: $0 / 360, saturation: orbSaturation, brightness: 1)
}

struct LightScenePreset {
    let name: String
    let symbol: String
    let detail: String
    let brightness: Double
    let kelvin: Int
    let hue: Double?
    let tint: Color
}

let lightScenePresets: [LightScenePreset] = [
    LightScenePreset(
        name: "Read", symbol: "book.fill",
        detail: "Crisp neutral white at 85% for reading.",
        brightness: 0.85, kelvin: 4000, hue: nil, tint: Color(hex: 0xFFE3C4)
    ),
    LightScenePreset(
        name: "Relax", symbol: "sofa.fill",
        detail: "Warm, softly breathing glow at 45%.",
        brightness: 0.45, kelvin: 2700, hue: nil, tint: Color(hex: 0xFFAC5C)
    ),
    LightScenePreset(
        name: "Focus", symbol: "scope",
        detail: "Bright daylight at full power.",
        brightness: 1, kelvin: 5000, hue: nil, tint: Color(hex: 0xC4DBFF)
    ),
    LightScenePreset(
        name: "Night", symbol: "moon.stars.fill",
        detail: "Candle-dim 8% for late hours.",
        brightness: 0.08, kelvin: 2200, hue: nil, tint: Color(hex: 0xFF8E3C)
    ),
    LightScenePreset(
        name: "Party", symbol: "party.popper.fill",
        detail: "Vivid magenta that pulses with the room.",
        brightness: 0.9, kelvin: 3200, hue: 305, tint: Color(hex: 0xFF7EDB)
    ),
]

/// Applies a light scene preset (colour scenes fall back to warm white without colour support).
@MainActor
private func apply(scene: LightScenePreset, to device: Device) {
    device.isOn = true
    device.brightness = scene.brightness
    device.colorTempK = scene.kelvin
    if let hue = scene.hue, device.supportsColor {
        device.lightColorMode = .color
        device.hue = hue
        device.saturation = 0.95
    } else {
        device.lightColorMode = .white
    }
    device.activeScene = scene.name
}

/// The light's live colour: hue/saturation in colour mode, otherwise its white colour temperature.
func lightColorOf(_ device: Device) -> Color {
    if device.supportsColor && device.lightColorMode == .color {
        return Color(
            hue: clamp01(device.hue / 360),
            saturation: clamp01(device.saturation),
            brightness: 1
        )
    }
    return kelvinRampColor(device.colorTempK)
}

/// Interpolates the kelvin ramp used by the colour-temperature slider and chips.
func kelvinRampColor(_ kelvin: Int) -> Color {
    let k = clamp(kelvin, kelvinStops.first ?? 2200, kelvinStops.last ?? 6500)
    for index in 1..<kelvinStops.count where k <= kelvinStops[index] {
        let span = Double(kelvinStops[index] - kelvinStops[index - 1])
        let f = span > 0 ? Double(k - kelvinStops[index - 1]) / span : 0
        return kelvinColors[index - 1].lerp(to: kelvinColors[index], f)
    }
    return kelvinColors[kelvinColors.count - 1]
}

func warmthName(_ kelvin: Int) -> String {
    switch kelvin {
    case ..<2500: return "Candle"
    case ..<3000: return "Warm"
    case ..<3600: return "Soft white"
    case ..<4500: return "Neutral"
    case ..<5600: return "Daylight"
    default: return "Cool"
    }
}

private func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return d > 180 ? 360 - d : d
}
