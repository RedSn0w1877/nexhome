import SwiftUI

// MARK: - Appliances (ControlKind.applianceCycle)

/// Kitchen and laundry appliances, tailored per device type:
/// - fridge: frosty compartments with temperature steppers, door seal, ice bin, modes;
/// - oven / grill: temperature dial on a heat stage, preheat ring, modes or programs, timer, probe;
/// - microwave: spinning glass turntable with cook ring, power level, timer, quick presets;
/// - dishwasher / washer / dryer: read-only progress dial with time left, phase timeline,
///   programs, temperature / spin / dryness, delay start, detergent.
struct ApplianceControls: View {
    @Bindable var device: Device

    var body: some View {
        switch device.type {
        case .fridge: FridgeSheet(device: device)
        case .oven: OvenSheet(device: device)
        case .microwave: MicrowaveSheet(device: device)
        case .grill: GrillSheet(device: device)
        default: LaundrySheet(device: device)
        }
    }
}

// MARK: - Shared appliance pieces

private let applianceIdle = Color(hex: 0x8A94A6)

private func applianceStateColor(_ device: Device, _ accent: Color) -> Color {
    switch device.applianceMode {
    case .running: return device.delayStartMinutes > 0 ? NexColors.indigo : accent
    case .paused: return NexColors.amber
    case .done: return NexColors.mint
    case .off: return applianceIdle
    }
}

private func applianceStateBadge(_ device: Device) -> String {
    switch device.applianceMode {
    case .running: return device.delayStartMinutes > 0 ? "Delayed" : "Running"
    case .paused: return "Paused"
    case .done: return "Done"
    case .off: return "Idle"
    }
}

/// "45 min", "1 h 05 min".
private func applianceDuration(_ minutes: Int) -> String {
    if minutes <= 0 { return "0 min" }
    if minutes < 60 { return "\(minutes) min" }
    return String(format: "%d h %02d min", minutes / 60, minutes % 60)
}

/// "2h 30m" / "45m".
private func applianceShortDuration(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes)m" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return "\(minutes / 60)h \(minutes % 60)m"
}

/// "m:ss" under an hour, else "h:mm".
private func applianceClock(_ totalSeconds: Int) -> String {
    let s = max(totalSeconds, 0)
    if s < 3600 { return String(format: "%d:%02d", s / 60, s % 60) }
    return String(format: "%d:%02d", s / 3600, (s % 3600) / 60)
}

private func applianceSecondsLeft(_ device: Device) -> Int {
    Int(Double(device.cycleTotalMinutes) * 60 * (1 - clamp01(device.cycleProgress)))
}

/// Deterministic 0...1 noise for seeded history rows.
private func applianceHash01(_ i: Int) -> Double {
    let v = sin(Double(i) * 12.9898 + 1.7) * 43758.547
    return abs(v - floor(v))
}

private struct ApplianceLogEntry {
    let symbol: String
    let title: String
    let detail: String
    let whenText: String
}

/// Program chips for an appliance.
private struct ProgramChips: View {
    let programs: [String]
    let selected: String
    let accent: Color
    var symbolFor: (String) -> String? = { _ in nil }
    let onPick: (String) -> Void

    var body: some View {
        LiquidChipRow {
            ForEach(programs, id: \.self) { program in
                LiquidChip(
                    label: program,
                    symbol: symbolFor(program),
                    selected: program == selected,
                    accent: accent
                ) { onPick(program) }
            }
        }
    }
}

/// Live power (with the 24 h sparkline), energy today and its cost.
private struct ApplianceEnergySection: View {
    let device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let watts = repository.liveWatts(device)
        GlassSection(
            title: "Energy",
            symbol: "bolt.fill",
            accent: accent,
            trailing: AnyView(NexText("Today", .caption, color: NexColors.tertiary))
        ) {
            GlassMetricTile(
                label: "Power",
                value: watts >= 1000 ? (watts / 1000).fixed(1) : "\(Int(watts))",
                unit: watts >= 1000 ? "kW" : "W",
                symbol: "bolt.fill",
                accent: accent,
                history: device.powerHistory
            )
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Used",
                    value: device.energyTodayKwh.fixed(2),
                    unit: "kWh",
                    symbol: "leaf.fill",
                    accent: NexColors.mint
                )
                GlassMetricTile(
                    label: "Cost",
                    value: "$\((device.energyTodayKwh * costPerKwh).fixed(2))",
                    symbol: "creditcard.fill",
                    accent: NexColors.gold
                )
            }
        }
    }
}

private struct ApplianceHistorySection: View {
    let title: String
    let entries: [ApplianceLogEntry]
    let accent: Color

    var body: some View {
        GlassSection(title: title, symbol: "clock.arrow.circlepath", accent: accent) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                GlassSettingRow(
                    title: entry.title,
                    symbol: entry.symbol,
                    subtitle: entry.detail,
                    accent: accent
                ) {
                    NexText(entry.whenText, .caption, color: NexColors.tertiary).lineLimit(1)
                }
            }
        }
    }
}

/// Wi-Fi signal, firmware and the favourite toggle.
private struct ApplianceInfoSection: View {
    @Bindable var device: Device
    let accent: Color

    private static let labels = ["No signal", "Weak", "Fair", "Good", "Excellent"]

    var body: some View {
        GlassSection(title: "Device", symbol: "wifi.router.fill", accent: accent) {
            GlassSettingRow(
                title: "Wi-Fi",
                symbol: "wifi",
                subtitle: "\(Self.labels[clamp(device.signalStrength, 0, 4)]) · Firmware \(device.firmwareVersion)",
                accent: accent
            ) {
                SignalBars(strength: device.signalStrength, accent: accent)
            }
            GlassSettingRow(
                title: "Favorite",
                symbol: "heart.fill",
                subtitle: "Pin to the home screen",
                accent: NexColors.rose
            ) {
                LiquidToggle(isOn: device.isFavorite, accent: NexColors.rose) { device.isFavorite = $0 }
            }
        }
    }
}

/// A glass ring showing progress with a centre readout.
private struct ProgressRing<Center: View>: View {
    let progress: Double
    let color: Color
    @ViewBuilder var center: () -> Center

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: Color.black.opacity(0.064),
            heavy: true,
            front: AnyView(
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 7)
                        .padding(8)
                    Circle()
                        .inset(by: 11.5)
                        .trim(from: 0, to: clamp01(progress))
                        .rotation(.degrees(-90))
                        .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .animation(GlassMotion.release, value: progress)
                }
            )
        ) {
            center().frame(width: 116, height: 116)
        }
        .shadow(color: color.opacity(0.3 * progress), radius: 18)
    }
}

/// A warm heat shimmer behind the oven / grill dial.
private struct HeatAura: View {
    let color: Color
    let glow: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: glow > 0.05 ? 0.28 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    RadialGradient(
                        colors: [color.opacity(0.3 * glow), .clear],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.65
                    )
                    .blendMode(.plusLighter)
                    ForEach(0..<10, id: \.self) { index in
                        let seed = applianceHash01(index)
                        let t = (phase * (1 + Double(index % 2)) + seed).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .fill(color.opacity(sin(t * .pi) * 0.45 * glow))
                            .frame(width: CGFloat(3 + index % 3))
                            .position(
                                x: size.width * CGFloat(0.1 + 0.8 * applianceHash01(index + 100)),
                                y: size.height * CGFloat(0.95 - 0.85 * t)
                            )
                            .blendMode(.plusLighter)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Fridge

private struct FridgeSheet: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        let doorOpen = device.doorOpen

        VStack(spacing: 16) {
            GlassSection(
                title: "Cooling",
                symbol: "snowflake",
                accent: accent,
                trailing: AnyView(
                    StatusBadge(
                        text: doorOpen ? "Door open" : "Sealed",
                        color: doorOpen ? NexColors.amber : NexColors.mint,
                        pulsing: doorOpen
                    )
                )
            ) {
                GlassPanel(
                    shape: glassRect(24),
                    tint: Color.black.opacity(0.048),
                    heavy: true,
                    surface: AnyView(FrostAura(warm: doorOpen ? 1 : 0))
                ) {
                    HStack(spacing: 12) {
                        FridgeCompartment(
                            label: "Fridge",
                            symbol: "refrigerator.fill",
                            temp: device.fridgeTempF,
                            range: 33...42,
                            color: NexColors.cyan,
                            open: doorOpen
                        )
                        FridgeCompartment(
                            label: "Freezer",
                            symbol: "snowflake",
                            temp: device.freezerTempF,
                            range: -8...5,
                            color: NexColors.blue,
                            open: false
                        )
                    }
                    .padding(14)
                }
                GlassSettingRow(
                    title: "Fridge",
                    symbol: "refrigerator.fill",
                    subtitle: fridgeHint(device.fridgeTempF),
                    accent: NexColors.cyan
                ) {
                    LiquidStepper(
                        value: device.fridgeTempF,
                        range: 33...42,
                        step: 1,
                        format: { "\($0.rounded0)°" },
                        accent: NexColors.cyan
                    ) {
                        device.fridgeTempF = $0
                        device.program = "Normal"
                    }
                }
                GlassSettingRow(
                    title: "Freezer",
                    symbol: "snowflake",
                    subtitle: "Recommended 0°F",
                    accent: NexColors.blue
                ) {
                    LiquidStepper(
                        value: device.freezerTempF,
                        range: -8...5,
                        step: 1,
                        format: { "\($0.rounded0)°" },
                        accent: NexColors.blue
                    ) {
                        device.freezerTempF = $0
                        device.program = "Normal"
                    }
                }
                GlassSettingRow(
                    title: "Door",
                    symbol: "door.left.hand.closed",
                    subtitle: doorOpen
                        ? "Open · close it to keep food cold"
                        : "Closed · seal is tight",
                    accent: doorOpen ? NexColors.amber : accent
                ) {
                    LiquidToggle(isOn: !doorOpen, accent: NexColors.mint) { device.doorOpen = !$0 }
                }
            }

            GlassSection(title: "Ice & water", symbol: "cup.and.saucer.fill", accent: NexColors.cyan) {
                IceBin(on: device.iceMakerOn)
                GlassSettingRow(
                    title: "Ice maker",
                    symbol: "cube.fill",
                    subtitle: device.iceMakerOn ? "Making ice · ~3 lb a day" : "Off",
                    accent: NexColors.cyan
                ) {
                    LiquidToggle(isOn: device.iceMakerOn, accent: NexColors.cyan) {
                        device.iceMakerOn = $0
                    }
                }
            }

            GlassSection(title: "Mode", symbol: "slider.horizontal.3", accent: accent) {
                ProgramChips(
                    programs: programs(for: device.type),
                    selected: device.program,
                    accent: accent,
                    symbolFor: fridgeModeSymbol
                ) { applyFridgeMode($0) }
                NexText(fridgeModeLine(device.program), .label, color: NexColors.secondary)
            }

            ApplianceEnergySection(device: device, accent: accent)
            ApplianceInfoSection(device: device, accent: accent)
        }
    }

    private func applyFridgeMode(_ mode: String) {
        device.program = mode
        switch mode {
        case "Party Chill":
            device.fridgeTempF = 34
            device.freezerTempF = -4
            device.iceMakerOn = true
        case "Vacation":
            device.fridgeTempF = 40
            device.freezerTempF = 2
            device.iceMakerOn = false
        case "Sabbath":
            device.fridgeTempF = 37
            device.freezerTempF = 0
            device.iceMakerOn = false
        default:
            device.fridgeTempF = 37
            device.freezerTempF = 0
        }
    }
}

/// One compartment: symbol, big set point and a thermometer column that springs with the value.
private struct FridgeCompartment: View {
    let label: String
    let symbol: String
    let temp: Double
    let range: ClosedRange<Double>
    let color: Color
    let open: Bool

    var body: some View {
        let fraction = clamp01((temp - range.lowerBound) / (range.upperBound - range.lowerBound))
        GlassPanel(
            shape: glassRect(20),
            tint: color.opacity(open ? 0.05 : 0.12),
            surface: AnyView(
                GeometryReader { proxy in
                    let h = proxy.size.height
                    VStack {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(color.opacity(0.75))
                            .frame(width: 6, height: max((h - 30) * CGFloat(fraction), 6))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
                    .animation(GlassMotion.release, value: temp)
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                    NexText(label.uppercased(), .caption, color: NexColors.secondary)
                }
                Spacer(minLength: 0)
                Text("\(temp.rounded0)°")
                    .font(NexType.display.font.monospacedDigit())
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
                NexText(open ? "Warming" : "Holding", .caption, color: open ? NexColors.amber : NexColors.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 150)
            .padding(14)
        }
    }
}

private struct FrostAura: View {
    let warm: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: warm > 0.5 ? 0.22 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0xBFE9FF).opacity(0.14), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    ForEach(0..<14, id: \.self) { index in
                        let seed = applianceHash01(index)
                        let t = (phase + seed).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .fill(Color.white.opacity(0.22 * (1 - t)))
                            .frame(width: CGFloat(2 + 3 * seed))
                            .position(
                                x: size.width * CGFloat(applianceHash01(index + 100)),
                                y: size.height * CGFloat(t)
                            )
                    }
                    if warm > 0.005 {
                        NexColors.amber.opacity(0.16 * warm).blendMode(.plusLighter)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Ice bin: cubes stacked in glass, one dropping in while the ice maker runs.
private struct IceBin: View {
    let on: Bool

    var body: some View {
        GlassPanel(
            shape: glassRect(20),
            tint: Color.black.opacity(0.064),
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: on ? 0.45 : 0) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        ZStack {
                            ForEach(0..<9, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.35))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(NexColors.cyan.opacity(0.5), lineWidth: 1)
                                    }
                                    .frame(width: 20, height: 18)
                                    .rotationEffect(.degrees(applianceHash01(index) * 30 - 15))
                                    .position(
                                        x: w * 0.5 + CGFloat(index % 5 - 2) * 22,
                                        y: h - 16 - CGFloat(index / 5) * 16
                                    )
                            }
                            if on {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.5 * (1 - phase)))
                                    .frame(width: 20, height: 18)
                                    .position(x: w * 0.5, y: 10 + CGFloat(phase) * (h - 50))
                            }
                        }
                    }
                }
            )
        ) {
            HStack {
                NexText(on ? "Bin filling" : "Bin idle", .caption, color: NexColors.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 90, alignment: .top)
            .padding(12)
        }
    }
}

private func fridgeHint(_ temp: Double) -> String {
    if temp < 35 { return "Extra cold · drinks & party trays" }
    if temp <= 38 { return "Ideal for fresh food" }
    return "Warm side · energy saver"
}

private func fridgeModeSymbol(_ mode: String) -> String? {
    switch mode {
    case "Party Chill": return "party.popper.fill"
    case "Vacation": return "timer"
    case "Sabbath": return "fork.knife"
    default: return "refrigerator.fill"
    }
}

private func fridgeModeLine(_ mode: String) -> String {
    switch mode {
    case "Party Chill": return "Rapid chill for 6 hours, extra ice production."
    case "Vacation": return "Holds a gentle chill and pauses the ice maker to save energy."
    case "Sabbath": return "Lights, alarms and the ice maker stay off."
    default: return "Balanced cooling for everyday use."
    }
}

// MARK: - Oven

private struct OvenSheet: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        let running = device.applianceMode == .running
        let preheat = clamp01(device.cycleProgress)
        let atTemp = running && preheat >= 1
        let stateColor = atTemp ? NexColors.mint : applianceStateColor(device, accent)
        let residual = clamp01((device.applianceTempF - 70) / 330)

        VStack(spacing: 16) {
            GlassSection(
                title: "Oven",
                symbol: "oven.fill",
                accent: accent,
                trailing: AnyView(
                    StatusBadge(
                        text: atTemp ? "At temp" : (running ? "Preheating" : applianceStateBadge(device)),
                        color: stateColor,
                        pulsing: running && !atTemp
                    )
                )
            ) {
                HeroStage {
                    HeatAura(color: accent, glow: running ? 0.55 + 0.45 * preheat : residual * 0.6)
                } content: {
                    VStack(spacing: 14) {
                        LiquidDial(
                            value: device.targetApplianceTempF,
                            range: 170...550,
                            accent: accent,
                            detents: 5,
                            size: 232,
                            onChange: { device.targetApplianceTempF = $0 }
                        ) {
                            VStack(spacing: 0) {
                                NexText(device.ovenMode.displayName.uppercased(), .caption, color: NexColors.secondary)
                                    .lineLimit(1)
                                Text("\(device.targetApplianceTempF.rounded0)°")
                                    .font(NexType.numeric.font)
                                    .tracking(NexType.numeric.tracking)
                                    .foregroundStyle(NexColors.primary)
                                    .lineLimit(1)
                                NexText(
                                    "Now \(device.applianceTempF.rounded0)°F",
                                    .label,
                                    color: NexColors.secondary
                                )
                                .lineLimit(1)
                            }
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "thermometer.medium",
                                value: "\(device.applianceTempF.rounded0)°",
                                label: "Cavity",
                                tint: accent
                            )
                            Readout(
                                symbol: "flame.fill",
                                value: "\((preheat * 100).rounded0)%",
                                label: "Preheat",
                                tint: stateColor
                            )
                            Readout(
                                symbol: "timer",
                                value: cookTimerText(device),
                                label: "Timer",
                                tint: NexColors.cyan
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                CookControlRow(
                    device: device,
                    accent: accent,
                    ringColor: stateColor,
                    startLabel: "Hold to preheat",
                    stopLabel: "Hold to turn off",
                    ringCaption: atTemp ? "Ready" : "Preheat"
                )
            }

            GlassSection(title: "Mode", symbol: "slider.horizontal.3", accent: accent) {
                LiquidSegmented(
                    options: [
                        SegmentOption("Bake", "birthday.cake.fill"),
                        SegmentOption("Convect", "tornado"),
                        SegmentOption("Broil", "flame.fill"),
                        SegmentOption("Air fry", "wind"),
                        SegmentOption("Warm", "cup.and.saucer.fill"),
                    ],
                    selectedIndex: device.ovenMode.rawValue,
                    accent: accent
                ) { device.ovenMode = OvenMode.allCases[$0] }
                NexText(ovenModeLine(device.ovenMode), .label, color: NexColors.secondary)
            }

            CookTimerAndProbeSection(device: device, accent: accent)

            GlassSection(title: "Recipes", symbol: "fork.knife", accent: accent) {
                ProgramChips(
                    programs: programs(for: device.type),
                    selected: device.program,
                    accent: accent,
                    symbolFor: ovenRecipeSymbol
                ) { applyOvenRecipe($0) }
                NexText("Recipes set the mode, temperature and timer.", .label, color: NexColors.secondary)
            }

            ApplianceEnergySection(device: device, accent: accent)
            ApplianceInfoSection(device: device, accent: accent)
        }
    }

    private func applyOvenRecipe(_ recipe: String) {
        device.program = recipe
        let preset: (OvenMode, Double, Int)
        switch recipe {
        case "Pizza": preset = (.convection, 475, 12)
        case "Roast Chicken": preset = (.convection, 425, 75)
        case "Cookies": preset = (.bake, 350, 11)
        case "Bread": preset = (.bake, 375, 35)
        case "Dehydrate": preset = (.convection, 170, 240)
        default: preset = (device.ovenMode, device.targetApplianceTempF, device.timerMinutes)
        }
        device.ovenMode = preset.0
        device.targetApplianceTempF = preset.1
        device.timerMinutes = preset.2
        device.minutesRemaining = preset.2
    }
}

private func ovenModeLine(_ mode: OvenMode) -> String {
    switch mode {
    case .bake: return "Top and bottom elements for even, classic baking."
    case .convection: return "Fan-forced heat browns faster — about 25°F lower works."
    case .broil: return "Intense top heat for searing and melting."
    case .airFry: return "High-speed hot air for crispy results without oil."
    case .keepWarm: return "Holds finished dishes at serving temperature."
    }
}

private func ovenRecipeSymbol(_ recipe: String) -> String? {
    switch recipe {
    case "Pizza": return "circle.grid.cross.fill"
    case "Roast Chicken": return "fork.knife"
    case "Cookies": return "circle.hexagongrid.fill"
    case "Bread": return "birthday.cake.fill"
    case "Dehydrate": return "wind"
    default: return "slider.horizontal.3"
    }
}

// MARK: - Grill

private struct GrillSheet: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        let running = device.applianceMode == .running
        let preheat = clamp01(device.cycleProgress)
        let atTemp = running && preheat >= 1
        let stateColor = atTemp ? NexColors.mint : applianceStateColor(device, accent)
        let residual = clamp01((device.applianceTempF - 70) / 400)

        VStack(spacing: 16) {
            GlassSection(
                title: "Grill",
                symbol: "flame.fill",
                accent: accent,
                trailing: AnyView(
                    StatusBadge(
                        text: atTemp ? "At temp" : (running ? "Heating" : applianceStateBadge(device)),
                        color: stateColor,
                        pulsing: running && !atTemp
                    )
                )
            ) {
                HeroStage {
                    HeatAura(color: Color(hex: 0xFF7A3D), glow: running ? 0.6 + 0.4 * preheat : residual * 0.6)
                } content: {
                    VStack(spacing: 14) {
                        LiquidDial(
                            value: device.targetApplianceTempF,
                            range: 180...600,
                            accent: accent,
                            detents: 5,
                            size: 232,
                            onChange: { device.targetApplianceTempF = $0 }
                        ) {
                            VStack(spacing: 0) {
                                NexText("GRATE", .caption, color: NexColors.secondary).lineLimit(1)
                                Text("\(device.targetApplianceTempF.rounded0)°")
                                    .font(NexType.numeric.font)
                                    .tracking(NexType.numeric.tracking)
                                    .foregroundStyle(NexColors.primary)
                                    .lineLimit(1)
                                NexText(
                                    "Now \(device.applianceTempF.rounded0)°F",
                                    .label,
                                    color: NexColors.secondary
                                )
                                .lineLimit(1)
                            }
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "flame.fill",
                                value: "\(device.applianceTempF.rounded0)°",
                                label: "Grate",
                                tint: accent
                            )
                            Readout(
                                symbol: "thermometer.medium",
                                value: "\(device.probeTempF.rounded0)°",
                                label: "Probe",
                                tint: NexColors.rose
                            )
                            Readout(
                                symbol: "timer",
                                value: cookTimerText(device),
                                label: "Timer",
                                tint: NexColors.cyan
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                CookControlRow(
                    device: device,
                    accent: accent,
                    ringColor: stateColor,
                    startLabel: "Hold to ignite",
                    stopLabel: "Hold to shut down",
                    ringCaption: atTemp ? "Ready" : "Heat up"
                )
            }

            CookTimerAndProbeSection(device: device, accent: accent)

            GlassSection(title: "Programs", symbol: "fork.knife", accent: accent) {
                ProgramChips(
                    programs: programs(for: device.type),
                    selected: device.program,
                    accent: accent,
                    symbolFor: grillProgramSymbol
                ) { applyGrillProgram($0) }
                NexText(grillProgramLine(device.program), .label, color: NexColors.secondary)
            }

            ApplianceEnergySection(device: device, accent: accent)
            ApplianceInfoSection(device: device, accent: accent)
        }
    }

    private func applyGrillProgram(_ program: String) {
        device.program = program
        let preset: (Double, Int)
        switch program {
        case "Sear": preset = (550, 10)
        case "Smoke": preset = (225, 180)
        case "Low & Slow": preset = (250, 240)
        case "Roast": preset = (375, 60)
        case "Bake": preset = (350, 30)
        default: preset = (device.targetApplianceTempF, device.timerMinutes)
        }
        device.targetApplianceTempF = preset.0
        device.timerMinutes = preset.1
        device.minutesRemaining = preset.1
    }
}

private func grillProgramSymbol(_ program: String) -> String? {
    switch program {
    case "Sear": return "flame.fill"
    case "Smoke": return "smoke.fill"
    case "Low & Slow": return "timer"
    case "Roast": return "fork.knife"
    case "Bake": return "birthday.cake.fill"
    default: return nil
    }
}

private func grillProgramLine(_ program: String) -> String {
    switch program {
    case "Sear": return "Blazing grate for crust and grill marks."
    case "Smoke": return "Low, smoky heat — keep the lid closed."
    case "Low & Slow": return "Gentle heat for ribs and brisket."
    case "Roast": return "Indirect heat for whole cuts."
    case "Bake": return "Closed-lid baking for pizza and bread."
    default: return "Pick a program to set the grate temperature and timer."
    }
}

// MARK: - Shared oven / grill pieces

/// Hold-to-start orb beside the glass preheat ring.
private struct CookControlRow: View {
    @Bindable var device: Device
    let accent: Color
    let ringColor: Color
    let startLabel: String
    let stopLabel: String
    let ringCaption: String

    var body: some View {
        let running = device.applianceMode == .running
        let preheat = running ? clamp01(device.cycleProgress) : 0

        HStack {
            Spacer()
            LiquidHoldOrb(
                label: running ? stopLabel : startLabel,
                symbol: running ? "power" : "flame.fill",
                accent: accent,
                active: running,
                size: 116,
                sublabel: "\(device.targetApplianceTempF.rounded0)°F · \(device.program.isEmpty ? device.ovenMode.displayName : device.program)"
            ) {
                if running { stopHeating() } else { startHeating() }
            }
            Spacer()
            VStack(spacing: 6) {
                ProgressRing(progress: preheat, color: ringColor) {
                    VStack(spacing: 0) {
                        NexText("\((preheat * 100).rounded0)%", .title).lineLimit(1)
                        NexText(ringCaption, .caption, color: NexColors.secondary).lineLimit(1)
                    }
                }
                NexText(
                    running && preheat < 1
                        ? "≈ \(preheatMinutesLeft()) min to temp"
                        : "Preheat ring",
                    .caption,
                    color: NexColors.tertiary
                )
                .lineLimit(1)
            }
            Spacer()
        }
    }

    private func startHeating() {
        device.isOn = true
        device.minutesRemaining = device.timerMinutes
        if device.program.isEmpty { device.program = programs(for: device.type).first ?? "" }
        device.applianceMode = .running
    }

    private func stopHeating() {
        device.applianceMode = .off
        device.cycleProgress = 0
        device.minutesRemaining = 0
    }

    /// Cavity climbs ~2.5 °F per 120 ms tick ≈ 21 °F/s; one sim minute ≈ 1.44 s.
    private func preheatMinutesLeft() -> Int {
        let left = max(device.targetApplianceTempF - device.applianceTempF, 0)
        return max(((left / 21) / 1.44).rounded0, 1)
    }
}

/// Cook timer stepper + meat probe gauge with doneness marks.
private struct CookTimerAndProbeSection: View {
    @Bindable var device: Device
    let accent: Color

    private static let marks: [(String, Int)] = [("Rare", 125), ("Med", 145), ("Well", 160), ("Safe", 165)]

    var body: some View {
        let probe = device.probeTempF
        GlassSection(title: "Timer & probe", symbol: "timer", accent: accent) {
            GlassSettingRow(
                title: "Cook timer",
                symbol: "timer",
                subtitle: device.timerMinutes > 0
                    ? "Counts down once preheated · ends the cook"
                    : "No timer",
                accent: NexColors.cyan
            ) {
                LiquidIntStepper(
                    value: device.timerMinutes,
                    range: 0...240,
                    step: 5,
                    format: { $0 == 0 ? "Off" : "\($0) min" },
                    accent: NexColors.cyan
                ) { minutes in
                    device.timerMinutes = minutes
                    device.minutesRemaining = minutes
                }
            }
            GlassSettingRow(
                title: "Meat probe",
                symbol: "thermometer.medium",
                subtitle: "\(probe.rounded0)°F · \(donenessLabel(probe))",
                accent: NexColors.rose
            )
            GlassLevelBar(fraction: clamp01((probe - 70) / 95), color: donenessColor(probe))
            HStack {
                ForEach(Self.marks, id: \.0) { mark in
                    NexText(
                        "\(mark.0) \(mark.1)°",
                        .caption,
                        color: probe >= Double(mark.1) ? NexColors.primary : NexColors.tertiary
                    )
                    .lineLimit(1)
                    if mark.0 != Self.marks.last?.0 { Spacer() }
                }
            }
        }
    }

    private func donenessLabel(_ temp: Double) -> String {
        if temp < 115 { return "Warming up" }
        if temp < 130 { return "Rare" }
        if temp < 140 { return "Medium rare" }
        if temp < 150 { return "Medium" }
        if temp < 165 { return "Well done" }
        return "Safe for poultry"
    }

    private func donenessColor(_ temp: Double) -> Color {
        if temp < 130 { return NexColors.rose }
        if temp < 150 { return NexColors.orange }
        return NexColors.mint
    }
}

private func cookTimerText(_ device: Device) -> String {
    device.timerMinutes > 0 ? applianceDuration(device.timerMinutes) : "Off"
}

// MARK: - Microwave

private struct MicrowaveSheet: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        let running = device.applianceMode == .running
        let paused = device.applianceMode == .paused
        let stateColor = applianceStateColor(device, accent)
        let timeText = running || paused
            ? applianceClock(applianceSecondsLeft(device))
            : "\(max(device.timerMinutes, 1)):00"

        VStack(spacing: 16) {
            GlassSection(
                title: "Cooking",
                symbol: "microwave.fill",
                accent: accent,
                trailing: AnyView(
                    StatusBadge(text: applianceStateBadge(device), color: stateColor, pulsing: running)
                )
            ) {
                HeroStage {
                    MicrowaveWaves(color: accent, glow: running ? 1 : (paused ? 0.35 : 0))
                } content: {
                    VStack(spacing: 14) {
                        GlassPanel(
                            shape: glassCircle,
                            tint: Color.black.opacity(0.056),
                            accent: accent,
                            heavy: true,
                            interactive: true,
                            pressScale: GlassMotion.orbPressScale,
                            surface: AnyView(
                                Turntable(
                                    color: accent,
                                    spinning: running,
                                    progress: running || paused ? device.cycleProgress : 0
                                )
                            )
                        ) {
                            VStack(spacing: 0) {
                                Text(timeText)
                                    .font(NexType.numeric.font)
                                    .tracking(NexType.numeric.tracking)
                                    .foregroundStyle(NexColors.primary)
                                    .lineLimit(1)
                                NexText(
                                    running || paused
                                        ? (device.program.isEmpty ? "Cooking" : device.program)
                                        : "Ready",
                                    .caption,
                                    color: NexColors.secondary
                                )
                                .lineLimit(1)
                            }
                            .frame(width: 208, height: 208)
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "bolt.fill",
                                value: "\(device.microwavePower * 10)%",
                                label: "Power",
                                tint: accent
                            )
                            Readout(
                                symbol: "timer",
                                value: applianceDuration(max(device.timerMinutes, 1)),
                                label: "Timer",
                                tint: NexColors.cyan
                            )
                            Readout(
                                symbol: "door.left.hand.closed",
                                value: device.doorOpen ? "Open" : "Closed",
                                label: "Door",
                                tint: device.doorOpen ? NexColors.amber : NexColors.mint
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: running || paused ? "Hold to stop" : "Hold to start",
                        symbol: running || paused ? "stop.fill" : "play.fill",
                        accent: accent,
                        active: running,
                        size: 116,
                        sublabel: device.doorOpen
                            ? "Close the door"
                            : "\(device.microwavePower * 10)% power",
                        enabled: !device.doorOpen || running || paused
                    ) {
                        if running || paused { stopMicrowave() } else { startMicrowave() }
                    }
                    VStack(spacing: 10) {
                        LiquidButton(tint: accent.opacity(0.5), action: addMinute) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NexColors.primary)
                            NexText("1 min", .bodyStrong)
                        }
                        LiquidButton(action: {
                            if running {
                                device.applianceMode = .paused
                            } else if paused {
                                device.applianceMode = .running
                            }
                        }) {
                            let ink = running || paused ? NexColors.primary : NexColors.quaternary
                            Image(systemName: running ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ink)
                            NexText(running ? "Pause" : "Resume", .bodyStrong, color: ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            GlassSection(title: "Settings", symbol: "slider.horizontal.3", accent: accent) {
                GlassSettingRow(
                    title: "Power level",
                    symbol: "bolt.fill",
                    subtitle: microwavePowerName(device.microwavePower),
                    accent: accent
                ) {
                    LiquidIntStepper(
                        value: device.microwavePower,
                        range: 1...10,
                        format: { "P\($0)" },
                        accent: accent
                    ) { device.microwavePower = $0 }
                }
                GlassLevelBar(fraction: Double(device.microwavePower) / 10, color: accent)
                GlassSettingRow(
                    title: "Cook time",
                    symbol: "timer",
                    subtitle: "Counts down while cooking",
                    accent: NexColors.cyan
                ) {
                    LiquidIntStepper(
                        value: clamp(device.timerMinutes, 1, 30),
                        range: 1...30,
                        format: { "\($0) min" },
                        accent: NexColors.cyan
                    ) { device.timerMinutes = $0 }
                }
            }

            GlassSection(title: "Quick presets", symbol: "fork.knife", accent: accent) {
                ProgramChips(
                    programs: programs(for: device.type),
                    selected: device.program,
                    accent: accent
                ) { preset in
                    device.program = preset
                    let values = microwavePreset(preset)
                    device.microwavePower = values.0
                    device.timerMinutes = values.1
                }
                NexText(
                    "Presets set power and time — hold the orb to start.",
                    .label,
                    color: NexColors.secondary
                )
            }

            ApplianceEnergySection(device: device, accent: accent)
            ApplianceInfoSection(device: device, accent: accent)
        }
    }

    private func startMicrowave() {
        if device.timerMinutes <= 0 { device.timerMinutes = 1 }
        device.isOn = true
        device.cycleTotalMinutes = device.timerMinutes
        device.cycleProgress = 0
        device.minutesRemaining = device.timerMinutes
        device.applianceMode = .running
    }

    private func stopMicrowave() {
        device.applianceMode = .off
        device.cycleProgress = 0
        device.minutesRemaining = 0
    }

    /// Adds a minute: while cooking the elapsed part is kept, so the ring re-scales.
    private func addMinute() {
        let cooking = device.applianceMode == .running || device.applianceMode == .paused
        if cooking && device.cycleProgress > 0 {
            let elapsed = Double(device.cycleTotalMinutes) * device.cycleProgress
            let total = device.cycleTotalMinutes + 1
            device.cycleTotalMinutes = total
            device.cycleProgress = clamp(elapsed / Double(total), 0.0001, 0.999)
        } else {
            device.timerMinutes = clamp(device.timerMinutes + 1, 1, 30)
        }
    }

    private func microwavePreset(_ preset: String) -> (Int, Int) {
        switch preset {
        case "Reheat": return (8, 2)
        case "Defrost": return (3, 6)
        case "Popcorn": return (10, 3)
        case "Potato": return (10, 5)
        case "Beverage": return (8, 1)
        case "Steam Veggies": return (9, 4)
        default: return (10, 1)
        }
    }

    private func microwavePowerName(_ power: Int) -> String {
        if power <= 2 { return "Warm" }
        if power <= 4 { return "Defrost" }
        if power <= 6 { return "Simmer" }
        if power <= 8 { return "Medium high" }
        return "High"
    }
}

/// Concentric microwave rings pulsing out from the turntable while cooking.
private struct MicrowaveWaves: View {
    let color: Color
    let glow: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: glow > 0.5 ? 0.9 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: 18 + 104)
                ZStack {
                    RadialGradient(
                        colors: [color.opacity(0.2 * glow), .clear],
                        center: UnitPoint(x: 0.5, y: center.y / max(size.height, 1)),
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.6
                    )
                    .blendMode(.plusLighter)
                    if glow > 0.5 {
                        ForEach(0..<3, id: \.self) { k in
                            let t = (phase + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .strokeBorder(color.opacity(0.3 * (1 - t)), lineWidth: 1.5)
                                .frame(width: 208 + CGFloat(t) * size.width * 0.6)
                                .position(center)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// A turntable plate with a cook-progress ring.
private struct Turntable: View {
    let color: Color
    let spinning: Bool
    let progress: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: spinning ? 0.22 : 0) { phase in
            GeometryReader { proxy in
                let r = min(proxy.size.width, proxy.size.height) / 2
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: r * 1.5)
                        .position(center)
                    ForEach(0..<3, id: \.self) { spoke in
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 3, height: r * 1.4)
                            .rotationEffect(.degrees(phase * 360 + Double(spoke) * 60))
                            .position(center)
                    }
                    Circle()
                        .inset(by: 6)
                        .trim(from: 0, to: clamp01(progress))
                        .rotation(.degrees(-90))
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: r * 2, height: r * 2)
                        .position(center)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Dishwasher / washer / dryer

private struct LaundryPhase {
    let label: String
    let weight: Double
}

private func laundryPhases(_ type: DeviceType) -> [LaundryPhase] {
    switch type {
    case .dryer:
        return [
            LaundryPhase(label: "Heat", weight: 0.15),
            LaundryPhase(label: "Tumble", weight: 0.7),
            LaundryPhase(label: "Cool down", weight: 0.15),
        ]
    case .dishwasher:
        return [
            LaundryPhase(label: "Pre-wash", weight: 0.15),
            LaundryPhase(label: "Wash", weight: 0.4),
            LaundryPhase(label: "Rinse", weight: 0.2),
            LaundryPhase(label: "Dry", weight: 0.25),
        ]
    default:
        return [
            LaundryPhase(label: "Fill", weight: 0.1),
            LaundryPhase(label: "Wash", weight: 0.45),
            LaundryPhase(label: "Rinse", weight: 0.25),
            LaundryPhase(label: "Spin", weight: 0.2),
        ]
    }
}

private func laundryPhaseIndex(_ phases: [LaundryPhase], _ progress: Double) -> Int {
    var start = 0.0
    for (index, phase) in phases.enumerated() {
        start += phase.weight
        if progress < start { return index }
    }
    return phases.count - 1
}

private func laundryTempOptions(_ type: DeviceType) -> [SegmentOption] {
    switch type {
    case .dryer:
        return [
            SegmentOption("Air", "snowflake"), SegmentOption("Low", "leaf.fill"),
            SegmentOption("Medium", "flame"), SegmentOption("High", "flame.fill"),
        ]
    case .dishwasher:
        return [
            SegmentOption("Eco", "leaf.fill"), SegmentOption("Normal", "drop.fill"),
            SegmentOption("Hot", "flame"), SegmentOption("Sanitize", "flame.fill"),
        ]
    default:
        return [
            SegmentOption("Cold", "snowflake"), SegmentOption("Warm", "drop.fill"),
            SegmentOption("Hot", "flame"), SegmentOption("X-Hot", "flame.fill"),
        ]
    }
}

private func laundryProgramMinutes(_ type: DeviceType, _ program: String) -> Int {
    switch type {
    case .washingMachine:
        switch program {
        case "Delicates": return 40
        case "Heavy Duty": return 75
        case "Quick Wash": return 25
        case "Bulky": return 65
        case "Sanitize": return 90
        default: return 55
        }
    case .dryer:
        switch program {
        case "Delicates": return 45
        case "Heavy Duty": return 80
        case "Towels": return 70
        case "Air Fluff": return 30
        case "Wrinkle Release": return 20
        default: return 60
        }
    case .dishwasher:
        switch program {
        case "Auto": return 120
        case "Heavy": return 150
        case "Eco": return 170
        case "Quick": return 45
        case "Rinse Only": return 15
        default: return 110
        }
    default:
        return 45
    }
}

private struct LaundrySheet: View {
    @Bindable var device: Device

    var body: some View {
        let type = device.type
        let accent = deviceAccent(type)
        let mode = device.applianceMode
        let delayed = mode == .running && device.delayStartMinutes > 0
        let running = mode == .running && !delayed
        let paused = mode == .paused
        let active = mode == .running || paused
        let done = mode == .done
        let stateColor = applianceStateColor(device, accent)
        let progress = active ? clamp01(device.cycleProgress) : (done ? 1 : 0)
        let phases = laundryPhases(type)
        let phaseIndex = laundryPhaseIndex(phases, progress)
        let tempOptions = laundryTempOptions(type)

        VStack(spacing: 16) {
            GlassSection(
                title: type == .dryer ? "Drying" : (type == .dishwasher ? "Wash cycle" : "Laundry"),
                symbol: type.symbol,
                accent: accent,
                trailing: AnyView(
                    StatusBadge(
                        text: applianceStateBadge(device),
                        color: stateColor,
                        pulsing: running || delayed
                    )
                )
            ) {
                HeroStage {
                    LaundryAura(type: type, color: stateColor, running: running)
                } content: {
                    VStack(spacing: 14) {
                        LiquidDial(
                            value: progress * 100,
                            range: 0...100,
                            accent: stateColor,
                            readOnly: true,
                            size: 232
                        ) {
                            laundryDialCenter(
                                active: active,
                                delayed: delayed,
                                done: done,
                                phaseLabel: phases[phaseIndex].label
                            )
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "slider.horizontal.3",
                                value: device.program.isEmpty ? "Normal" : device.program,
                                label: "Program",
                                tint: accent
                            )
                            Readout(
                                symbol: "thermometer.medium",
                                value: tempOptions[clamp(device.washTempLevel, 0, 3)].label,
                                label: type == .dryer ? "Heat" : "Water temp",
                                tint: NexColors.orange
                            )
                            Readout(
                                symbol: "clock.fill",
                                value: laundryEndsAt(),
                                label: active ? "Ends" : "Would end",
                                tint: NexColors.cyan
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                PhaseStrip(phases: phases, progress: progress, color: stateColor, running: running)
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: active ? "Hold to stop" : "Hold to start",
                        symbol: active ? "stop.fill" : "play.fill",
                        accent: accent,
                        active: mode == .running,
                        size: 116,
                        sublabel: active
                            ? "\(device.program) · \(applianceDuration(device.cycleTotalMinutes))"
                            : applianceDuration(laundryProgramMinutes(type, device.program))
                    ) {
                        if active { stop() } else { start() }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        LiquidButton(tint: paused ? NexColors.amber.opacity(0.5) : nil, action: {
                            if mode == .running {
                                device.applianceMode = .paused
                            } else if paused {
                                device.applianceMode = .running
                            }
                        }) {
                            let ink = active ? NexColors.primary : NexColors.quaternary
                            Image(systemName: paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ink)
                            NexText(paused ? "Resume" : "Pause", .bodyStrong, color: ink)
                        }
                        NexText(statusLine(delayed: delayed, done: done), .label, color: NexColors.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassSection(title: "Programs", symbol: "slider.horizontal.3", accent: accent) {
                ProgramChips(
                    programs: programs(for: type),
                    selected: device.program,
                    accent: accent
                ) { pick(program: $0) }
                NexText(
                    active
                        ? "Program changes apply to the next cycle."
                        : "\(device.program.isEmpty ? "Normal" : device.program) · \(applianceDuration(laundryProgramMinutes(type, device.program)))",
                    .label,
                    color: NexColors.secondary
                )
            }

            GlassSection(title: "Options", symbol: "thermometer.medium", accent: accent) {
                NexText(
                    (type == .dryer ? "Heat" : "Water temp").uppercased(),
                    .caption,
                    color: NexColors.tertiary
                )
                LiquidSegmented(
                    options: tempOptions,
                    selectedIndex: clamp(device.washTempLevel, 0, 3),
                    accent: NexColors.orange
                ) { device.washTempLevel = $0 }
                if type != .dishwasher {
                    NexText(type == .dryer ? "DRYNESS" : "SPIN", .caption, color: NexColors.tertiary)
                    LiquidSegmented(
                        options: (type == .dryer
                            ? ["Damp", "Less", "Normal", "More", "Very"]
                            : ["None", "Low", "Med", "High", "Max"]).map { SegmentOption($0) },
                        selectedIndex: clamp(device.spinLevel, 0, 4),
                        accent: accent
                    ) { device.spinLevel = $0 }
                }
                GlassSettingRow(
                    title: "Delay start",
                    symbol: "clock.fill",
                    subtitle: device.delayStartMinutes > 0
                        ? "Starts in \(applianceDuration(device.delayStartMinutes))"
                        : "Starts right away",
                    accent: NexColors.indigo
                ) {
                    LiquidIntStepper(
                        value: device.delayStartMinutes,
                        range: 0...720,
                        step: 30,
                        format: { $0 == 0 ? "Off" : applianceShortDuration($0) },
                        accent: NexColors.indigo
                    ) { device.delayStartMinutes = $0 }
                }
            }

            if type != .dryer {
                let pct = clamp(device.detergentPercent, 0, 100)
                GlassSection(title: "Detergent", symbol: "bubbles.and.sparkles.fill", accent: NexColors.teal) {
                    GlassSettingRow(
                        title: type == .dishwasher ? "Auto-dose pods" : "Auto-dose tank",
                        symbol: "drop.fill",
                        subtitle: "\(pct)% · ~\(max(pct / 5, 0)) \(type == .dishwasher ? "washes" : "loads") left",
                        accent: NexColors.teal
                    ) {
                        LiquidButton(
                            tint: NexColors.teal.opacity(0.45),
                            action: { device.detergentPercent = 100 }
                        ) {
                            NexText("Refill", .label)
                        }
                    }
                    GlassLevelBar(
                        fraction: Double(pct) / 100,
                        color: pct < 20 ? NexColors.amber : NexColors.teal
                    )
                }
            }

            ApplianceEnergySection(device: device, accent: accent)
            ApplianceHistorySection(title: "Recent cycles", entries: laundryHistory(), accent: accent)
            ApplianceInfoSection(device: device, accent: accent)
        }
    }

    @ViewBuilder
    private func laundryDialCenter(active: Bool, delayed: Bool, done: Bool, phaseLabel: String) -> some View {
        VStack(spacing: 0) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(NexColors.mint)
                NexText("Done", .headline).lineLimit(1)
                NexText("Cycle finished", .caption, color: NexColors.secondary).lineLimit(1)
            } else if delayed {
                NexText("STARTS IN", .caption, color: NexColors.secondary).lineLimit(1)
                NexText(applianceShortDuration(device.delayStartMinutes), .headline).lineLimit(1)
                NexText("Delay start", .caption, color: NexColors.tertiary).lineLimit(1)
            } else if active {
                NexText(phaseLabel.uppercased(), .caption, color: NexColors.secondary).lineLimit(1)
                Text("\(max(device.minutesRemaining, 0))")
                    .font(NexType.numeric.font)
                    .tracking(NexType.numeric.tracking)
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
                NexText(
                    "min left · \((device.cycleProgress * 100).rounded0)%",
                    .caption,
                    color: NexColors.secondary
                )
                .lineLimit(1)
            } else {
                Image(systemName: "tornado")
                    .font(.system(size: 22))
                    .foregroundStyle(NexColors.tertiary)
                Text("\(laundryProgramMinutes(device.type, device.program))")
                    .font(NexType.numeric.font)
                    .tracking(NexType.numeric.tracking)
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
                NexText("min cycle", .caption, color: NexColors.secondary).lineLimit(1)
            }
        }
    }

    private func pick(program: String) {
        let active = device.applianceMode == .running || device.applianceMode == .paused
        device.program = program
        if !active { device.cycleTotalMinutes = laundryProgramMinutes(device.type, program) }
        switch program {
        case "Delicates":
            device.washTempLevel = device.type == .dryer ? 1 : 0
            device.spinLevel = 1
        case "Heavy Duty", "Heavy":
            device.washTempLevel = 2
            device.spinLevel = 3
        case "Sanitize", "Towels":
            device.washTempLevel = 3
            device.spinLevel = 3
        case "Quick Wash", "Quick":
            device.washTempLevel = 1
            device.spinLevel = 4
        case "Eco", "Air Fluff":
            device.washTempLevel = 0
        default:
            break
        }
    }

    private func start() {
        device.isOn = true
        if device.program.isEmpty { device.program = programs(for: device.type).first ?? "" }
        device.cycleTotalMinutes = laundryProgramMinutes(device.type, device.program)
        device.cycleProgress = 0
        device.minutesRemaining = device.cycleTotalMinutes
        device.applianceMode = .running
    }

    private func stop() {
        device.applianceMode = .off
        device.cycleProgress = 0
        device.minutesRemaining = 0
        device.delayStartMinutes = 0
    }

    private func laundryEndsAt() -> String {
        let active = device.applianceMode == .running || device.applianceMode == .paused
        let minutes = (active ? device.minutesRemaining : laundryProgramMinutes(device.type, device.program))
            + device.delayStartMinutes
        return Date.now.addingTimeInterval(Double(minutes) * 60).formatted(.dateTime.hour().minute())
    }

    private func statusLine(delayed: Bool, done: Bool) -> String {
        if delayed { return "Waiting · starts in \(applianceShortDuration(device.delayStartMinutes))" }
        if done {
            switch device.type {
            case .dryer: return "Dry · unload soon to avoid wrinkles"
            case .dishwasher: return "Clean · ready to unload"
            default: return "Washed · move it to the dryer"
            }
        }
        if device.applianceMode == .paused { return "Paused · \(device.minutesRemaining) min left" }
        if device.applianceMode == .running { return "Ends at \(laundryEndsAt())" }
        return "Ready · \(device.program.isEmpty ? "Normal" : device.program)"
    }

    /// Three plausible past cycles, seeded from the device id so they stay stable.
    private func laundryHistory() -> [ApplianceLogEntry] {
        let list = programs(for: device.type)
        guard !list.isEmpty else { return [] }
        let seed = abs(device.id.hashValue) & 0xFFFF
        let kw: Double = device.type == .dryer ? 2.4 : (device.type == .dishwasher ? 1.1 : 0.6)
        return ["Yesterday", "2 days ago", "4 days ago"].enumerated().map { index, whenText in
            let program = list[clamp(Int(applianceHash01(seed + index * 7) * Double(list.count)), 0, list.count - 1)]
            let minutes = laundryProgramMinutes(device.type, program)
            return ApplianceLogEntry(
                symbol: "checkmark.circle.fill",
                title: program,
                detail: "\(applianceDuration(minutes)) · \((Double(minutes) / 60 * kw).fixed(1)) kWh",
                whenText: whenText
            )
        }
    }
}

/// Tumbling suds / spray behind the progress dial while the cycle runs.
private struct LaundryAura: View {
    let type: DeviceType
    let color: Color
    let running: Bool

    var body: some View {
        let rate: Double = type == .dryer ? 0.55 : (type == .dishwasher ? 0.5 : 0.7)
        PhaseTimeline(cyclesPerSecond: running ? rate : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: 18 + 116)
                ZStack {
                    RadialGradient(
                        colors: [color.opacity(running ? 0.24 : 0.06), .clear],
                        center: UnitPoint(x: 0.5, y: center.y / max(size.height, 1)),
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.6
                    )
                    .blendMode(.plusLighter)
                    if running {
                        ForEach(0..<12, id: \.self) { index in
                            let angle = radians(phase * 360 + Double(index) * 30)
                            let radius = 140 + 14 * sin(phase * 2 * .pi + Double(index))
                            Circle()
                                .fill(Color.white.opacity(0.18 + 0.12 * Double(index % 2)))
                                .frame(width: CGFloat(5 + index % 4))
                                .position(
                                    x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius
                                )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Glass phase timeline: one segment per phase filling with the cycle progress.
private struct PhaseStrip: View {
    let phases: [LaundryPhase]
    let progress: Double
    let color: Color
    let running: Bool

    var body: some View {
        VStack(spacing: 6) {
            GlassPanel(shape: glassCapsule, tint: Color.black.opacity(0.088)) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    HStack(spacing: 3) {
                        ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                            let start = phases.prefix(index).reduce(0) { $0 + $1.weight }
                            let fill = clamp01((progress - start) / phase.weight)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(color)
                                    .frame(width: max((width * CGFloat(phase.weight) - 3) * CGFloat(fill), 0))
                            }
                            .frame(width: max(width * CGFloat(phase.weight) - 3, 4))
                        }
                    }
                    .animation(GlassMotion.release, value: progress)
                }
                .frame(height: 12)
                .padding(4)
            }
            HStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    NexText(
                        phase.label,
                        .caption,
                        color: index == laundryPhaseIndex(phases, progress) && running
                            ? color
                            : NexColors.tertiary
                    )
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Robot vacuum (ControlKind.robotVacuum)

/// The four rooms of the stylised floor plan (also the room chips); the dock sits bottom-left.
private struct MapRoom {
    let room: Room
    let rect: CGRect
}

private let vacuumMapRooms = [
    MapRoom(room: .kitchen, rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.45)),
    MapRoom(room: .livingRoom, rect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.55)),
    MapRoom(room: .diningRoom, rect: CGRect(x: 0, y: 0.45, width: 0.5, height: 0.55)),
    MapRoom(room: .hallway, rect: CGRect(x: 0.5, y: 0.55, width: 0.5, height: 0.45)),
]

/// Robot vacuum sheet: a glass floor map with the robot gliding along its live route,
/// hold-to-clean / dock, suction, rooms, mop & bin, battery and run metrics.
struct VacuumControls: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        let state = device.vacuumState
        let cleaning = state == .cleaning
        let paused = state == .paused
        let returning = state == .returning
        let active = cleaning || paused
        let charging = state == .docked && device.batteryPercent < 100
        let stateColor: Color = cleaning
            ? accent
            : (returning ? NexColors.cyan : (paused ? NexColors.amber : (charging ? NexColors.mint : applianceIdle)))
        let badge = cleaning
            ? "Cleaning"
            : (returning ? "Returning" : (paused ? "Paused" : (charging ? "Charging" : "Docked")))
        let canStart = !device.binFull && device.batteryPercent >= 15
        let allRooms = Set(vacuumMapRooms.map(\.room))
        let batteryTint = vacuumBatteryColor()

        VStack(spacing: 16) {
            GlassSection(
                title: "Floor map",
                symbol: "map.fill",
                accent: accent,
                trailing: AnyView(
                    StatusBadge(text: badge, color: stateColor, pulsing: cleaning || returning)
                )
            ) {
                VacuumMap(device: device, accent: accent)
                    .frame(height: 240)
                HStack(spacing: 0) {
                    Readout(
                        symbol: "square.dashed",
                        value: "\(device.cleanedAreaSqFt) ft²",
                        label: "Cleaned",
                        tint: accent
                    )
                    Readout(
                        symbol: "timer",
                        value: "\(device.cleaningMinutes) min",
                        label: "Runtime",
                        tint: NexColors.cyan
                    )
                    Readout(
                        symbol: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        value: "\((device.cleaningProgress * 100).rounded0)%",
                        label: "Route",
                        tint: stateColor
                    )
                    Readout(
                        symbol: "battery.100.bolt",
                        value: "\(device.batteryPercent)%",
                        label: "Battery",
                        tint: batteryTint
                    )
                }
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: active ? "Hold to dock" : "Hold to clean",
                        symbol: active ? "house.fill" : "sparkles",
                        accent: accent,
                        active: cleaning,
                        size: 116,
                        sublabel: {
                            if active { return "\((device.cleaningProgress * 100).rounded0)% of route" }
                            if device.binFull { return "Empty the bin first" }
                            if device.batteryPercent < 15 { return "Charging…" }
                            return roomsLabel()
                        }(),
                        enabled: active || canStart
                    ) { toggle() }
                    VStack(alignment: .leading, spacing: 10) {
                        LiquidButton(tint: paused ? NexColors.amber.opacity(0.5) : nil, action: {
                            if cleaning {
                                device.vacuumState = .paused
                            } else if paused {
                                device.vacuumState = .cleaning
                            }
                        }) {
                            let ink = active ? NexColors.primary : NexColors.quaternary
                            Image(systemName: paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ink)
                            NexText(paused ? "Resume" : "Pause", .bodyStrong, color: ink)
                        }
                        NexText(statusLine(), .label, color: NexColors.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassSection(title: "Suction", symbol: "wind", accent: accent) {
                LiquidSegmented(
                    options: [
                        SegmentOption("Quiet", "speaker.wave.1.fill"),
                        SegmentOption("Standard", "wind"),
                        SegmentOption("Turbo", "speedometer"),
                        SegmentOption("Max", "tornado"),
                    ],
                    selectedIndex: device.suction.rawValue,
                    accent: accent
                ) { device.suction = SuctionLevel.allCases[$0] }
                NexText(suctionLine(device.suction), .label, color: NexColors.secondary)
            }

            GlassSection(title: "Rooms", symbol: "door.left.hand.open", accent: accent) {
                LiquidChipRow {
                    LiquidChip(
                        label: "Whole home",
                        symbol: "square.grid.2x2.fill",
                        selected: device.selectedRooms.isSuperset(of: allRooms),
                        accent: accent
                    ) {
                        device.selectedRooms = device.selectedRooms.isSuperset(of: allRooms) ? [] : allRooms
                    }
                    ForEach(vacuumMapRooms, id: \.room) { mapRoom in
                        let on = device.selectedRooms.contains(mapRoom.room)
                        LiquidChip(
                            label: mapRoom.room.displayName,
                            symbol: mapRoom.room.symbol,
                            selected: on,
                            accent: accent
                        ) {
                            if on {
                                device.selectedRooms.remove(mapRoom.room)
                            } else {
                                device.selectedRooms.insert(mapRoom.room)
                            }
                        }
                    }
                }
                NexText(roomsLabel(), .label, color: NexColors.secondary)
            }

            GlassSection(title: "Mop & bin", symbol: "sparkles", accent: accent) {
                GlassSettingRow(
                    title: "Mop pad",
                    symbol: "drop.fill",
                    subtitle: device.mopEnabled ? "Vacuum + mop · avoids rugs" : "Vacuum only",
                    accent: NexColors.cyan
                ) {
                    LiquidToggle(isOn: device.mopEnabled, accent: NexColors.cyan) { device.mopEnabled = $0 }
                }
                GlassSettingRow(
                    title: "Dust bin",
                    symbol: "trash.fill",
                    subtitle: device.binFull ? "Full · empty it before the next run" : "Plenty of room",
                    accent: device.binFull ? NexColors.amber : accent
                ) {
                    if device.binFull {
                        LiquidButton(tint: NexColors.amber.opacity(0.5), action: { device.binFull = false }) {
                            NexText("Emptied", .label)
                        }
                    } else {
                        NexText("OK", .bodyStrong, color: NexColors.mint)
                    }
                }
                GlassLevelBar(
                    fraction: device.binFull ? 1 : clamp(Double(device.cleanedAreaSqFt) / 900, 0.08, 0.85),
                    color: device.binFull ? NexColors.amber : accent
                )
            }

            GlassSection(title: "Battery", symbol: "battery.100.bolt", accent: batteryTint) {
                HStack(spacing: 14) {
                    LiquidDial(
                        value: Double(device.batteryPercent),
                        range: 0...100,
                        accent: batteryTint,
                        readOnly: true,
                        size: 150
                    ) {
                        VStack(spacing: 0) {
                            NexText("\(device.batteryPercent)%", .headline).lineLimit(1)
                            NexText(
                                charging ? "Charging" : "~\(device.batteryPercent * 3 / 2) min",
                                .caption,
                                color: NexColors.secondary
                            )
                            .lineLimit(1)
                        }
                    }
                    VStack(spacing: 10) {
                        GlassMetricTile(
                            label: "Area",
                            value: "\(device.cleanedAreaSqFt)",
                            unit: "ft²",
                            symbol: "square.dashed",
                            accent: accent
                        )
                        GlassMetricTile(
                            label: "Runtime",
                            value: "\(device.cleaningMinutes)",
                            unit: "min",
                            symbol: "timer",
                            accent: NexColors.cyan
                        )
                    }
                }
            }

            ApplianceEnergySection(device: device, accent: accent)
            ApplianceHistorySection(title: "Recent runs", entries: vacuumHistory(), accent: accent)
            ApplianceInfoSection(device: device, accent: accent)
        }
    }

    private func toggle() {
        if device.vacuumState == .cleaning || device.vacuumState == .paused {
            device.vacuumState = .returning
        } else {
            device.isOn = true
            if device.selectedRooms.isEmpty { device.selectedRooms = Set(vacuumMapRooms.map(\.room)) }
            device.cleaningProgress = 0
            device.vacuumState = .cleaning
        }
    }

    private func vacuumBatteryColor() -> Color {
        if device.batteryPercent < 20 { return NexColors.rose }
        if device.vacuumState == .docked && device.batteryPercent < 100 { return NexColors.mint }
        return NexColors.lime
    }

    private func roomsLabel() -> String {
        let n = device.selectedRooms.filter { room in vacuumMapRooms.contains { $0.room == room } }.count
        if n == 0 { return "No rooms picked · runs the whole home" }
        let minutes = n * 18 * (device.mopEnabled ? 5 : 4) / 4
        return "\(n) \(n == 1 ? "room" : "rooms") · about \(minutes) min"
    }

    private func statusLine() -> String {
        switch device.vacuumState {
        case .cleaning: return "\(device.suction.displayName) suction\(device.mopEnabled ? " · mopping" : "")"
        case .paused: return "Paused mid-route"
        case .returning: return "Heading back to the dock"
        case .docked: return device.batteryPercent < 100 ? "Charging on the dock" : "Ready on the dock"
        }
    }

    private func suctionLine(_ level: SuctionLevel) -> String {
        switch level {
        case .quiet: return "Whisper-quiet for calls and naps."
        case .standard: return "Balanced power for daily cleaning."
        case .turbo: return "Extra lift for rugs and pet hair."
        case .max: return "Full power — shorter runtime."
        }
    }

    private func vacuumHistory() -> [ApplianceLogEntry] {
        let seed = abs(device.id.hashValue) & 0xFFFF
        return ["Today", "Yesterday", "3 days ago"].enumerated().map { index, whenText in
            let r = applianceHash01(seed + index * 11)
            let room = vacuumMapRooms[clamp(Int(r * Double(vacuumMapRooms.count)), 0, vacuumMapRooms.count - 1)].room
            let area = 180 + Int(r * 420)
            return ApplianceLogEntry(
                symbol: "sparkles",
                title: index == 0 ? "Whole home" : room.displayName,
                detail: "\(area) ft² · \(area / 12) min",
                whenText: whenText
            )
        }
    }
}

/// The floor map: rooms (selected ones glow), the planned lawnmower route, the cleaned swath, the
/// dock and the robot puck gliding to the live position.
private struct VacuumMap: View {
    let device: Device
    let accent: Color

    // Mirrors the repository's lawnmower path so the trail lines up with robotX / robotY.
    private let dock = CGPoint(x: 0.1, y: 0.9)
    private let pathLeft = 0.1
    private let pathRight = 0.9
    private let pathTop = 0.15
    private let pathBottom = 0.8
    private let pathRows = 6

    var body: some View {
        let cleaning = device.vacuumState == .cleaning
        GlassPanel(shape: glassRect(24), tint: Color.black.opacity(0.08), heavy: true) {
            GeometryReader { proxy in
                let inset: CGFloat = 14
                let w = proxy.size.width - inset * 2
                let h = proxy.size.height - inset * 2
                let toPoint = { (x: Double, y: Double) in
                    CGPoint(x: inset + w * CGFloat(x), y: inset + h * CGFloat(y))
                }
                ZStack {
                    ForEach(vacuumMapRooms, id: \.room) { mapRoom in
                        let selected = device.selectedRooms.contains(mapRoom.room)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected ? accent.opacity(0.14) : Color.white.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            }
                            .overlay(alignment: .topLeading) {
                                NexText(mapRoom.room.displayName, .caption, color: NexColors.tertiary)
                                    .lineLimit(1)
                                    .padding(6)
                            }
                            .frame(width: w * mapRoom.rect.width - 4, height: h * mapRoom.rect.height - 4)
                            .position(
                                x: inset + w * (mapRoom.rect.midX),
                                y: inset + h * (mapRoom.rect.midY)
                            )
                    }

                    // Planned route.
                    routePath(upTo: 1, toPoint: toPoint)
                        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    // Cleaned swath.
                    if device.cleaningProgress > 0 {
                        routePath(upTo: device.cleaningProgress, toPoint: toPoint)
                            .stroke(
                                accent.opacity(0.35),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                            )
                    }

                    // Dock.
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NexColors.mint.opacity(0.7))
                        .frame(width: 18, height: 10)
                        .position(toPoint(dock.x, dock.y + 0.05))

                    // Robot puck.
                    PhaseTimeline(cyclesPerSecond: cleaning ? 1.2 : 0) { phase in
                        ZStack {
                            if cleaning {
                                Circle()
                                    .fill(accent.opacity(0.3 * (1 - phase)))
                                    .frame(width: 22 + 22 * CGFloat(phase))
                            }
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .overlay { Circle().strokeBorder(accent, lineWidth: 3) }
                                .frame(width: 22, height: 22)
                                .glassEffect(.regular, in: Circle())
                        }
                    }
                    .position(toPoint(device.robotX, device.robotY))
                    .animation(.linear(duration: 0.12), value: device.robotX)
                    .animation(.linear(duration: 0.12), value: device.robotY)
                }
            }
        }
    }

    /// The boustrophedon route up to fraction `t`.
    private func routePath(upTo t: Double, toPoint: (Double, Double) -> CGPoint) -> Path {
        Path { path in
            let rowGap = (pathBottom - pathTop) / Double(pathRows - 1)
            let width = pathRight - pathLeft
            let total = Double(pathRows) * width + Double(pathRows - 1) * rowGap
            var remaining = clamp01(t) * total
            var point = (pathLeft, pathBottom)
            path.move(to: toPoint(point.0, point.1))
            for row in 0..<pathRows {
                let leftToRight = row % 2 == 0
                let y = pathBottom - Double(row) * rowGap
                let run = min(remaining, width)
                point = (leftToRight ? pathLeft + run : pathRight - run, y)
                path.addLine(to: toPoint(point.0, point.1))
                remaining -= run
                if remaining <= 0 || row == pathRows - 1 { break }
                let climb = min(remaining, rowGap)
                point = (point.0, y - climb)
                path.addLine(to: toPoint(point.0, point.1))
                remaining -= climb
                if remaining <= 0 { break }
            }
        }
    }
}

// MARK: - Blinds / shades (ControlKind.blindsSlider)

/// Blinds and shades: a position fader with preset chips and the sunset automation.
struct BlindsControls: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        VStack(spacing: 16) {
            GlassSection(title: "Position", symbol: device.type.symbol, accent: accent) {
                HStack(spacing: 20) {
                    LiquidFader(
                        value: device.position,
                        accent: accent,
                        symbol: device.type.symbol,
                        label: "open"
                    ) { device.position = $0 }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach([("Open", 1.0), ("Half", 0.5), ("Closed", 0.0)], id: \.0) { preset in
                            LiquidChip(
                                label: preset.0,
                                selected: abs(device.position - preset.1) < 0.02,
                                accent: accent
                            ) {
                                withAnimation(GlassMotion.release) { device.position = preset.1 }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            GlassSection(title: "Automation") {
                GlassSettingRow(
                    title: "Close at sunset",
                    symbol: "sun.horizon.fill",
                    subtitle: "Lowers automatically every evening",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.sunsetSchedule, accent: accent) {
                        device.sunsetSchedule = $0
                    }
                }
            }
            DeviceInfoSection(device: device, accent: accent)
        }
    }
}
