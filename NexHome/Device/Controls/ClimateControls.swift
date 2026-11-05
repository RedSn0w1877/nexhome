import SwiftUI

// MARK: - Thermostat / AC (ControlKind.thermostatDial)

/// Thermostat and AC sheet: a set-point dial on a live thermal stage (the aura warms or cools and
/// drifts particles while the equipment runs), HVAC and fan mode selectors, a 24 h temperature
/// timeline, comfort metrics, eco + schedule and filter care.
struct ThermostatControls: View {
    @Bindable var device: Device

    var body: some View {
        let isAc = device.type == .acUnit
        let accent = deviceAccent(device.type)
        let modes = isAc ? acModes : thermostatModes
        let range: ClosedRange<Double> = isAc ? 60...86 : 60...84
        let off = !device.isOn || device.hvacMode == .off
        let active = device.isHeating || device.isCooling
        let modeColor = climateColor(device, isAc)
        let setback = (isAc || device.hvacMode == .cool)
            ? device.targetTempF + 4
            : device.targetTempF - 6

        VStack(spacing: 16) {
            // Hero: dial on the thermal stage.
            GlassSection(
                title: isAc ? "Cooling" : "Temperature",
                symbol: isAc ? "snowflake" : "thermometer.medium",
                accent: modeColor,
                trailing: AnyView(
                    StatusBadge(text: climateBadge(device), color: modeColor, pulsing: active)
                )
            ) {
                HeroStage {
                    ThermalAura(
                        color: modeColor,
                        glow: active ? 1 : (off ? 0 : 0.3),
                        rising: !device.isCooling
                    )
                    .animation(.spring(response: 0.993, dampingFraction: 1), value: active)
                } content: {
                    VStack(spacing: 14) {
                        LiquidDial(
                            value: device.targetTempF,
                            range: range,
                            accent: modeColor,
                            detents: 1,
                            size: 248,
                            onChange: { setTarget($0, isAc: isAc) }
                        ) {
                            VStack(spacing: 0) {
                                NexText(climateDialCaption(device), .caption, color: NexColors.secondary)
                                    .lineLimit(1)
                                Text("\(device.targetTempF.rounded0)°")
                                    .font(NexType.numeric.font)
                                    .tracking(NexType.numeric.tracking)
                                    .foregroundStyle(NexColors.primary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: trendSymbol)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(modeColor)
                                    NexText(
                                        "Now \(device.currentTempF.fixed(1))°",
                                        .label,
                                        color: NexColors.secondary
                                    )
                                    .lineLimit(1)
                                }
                            }
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "thermometer.medium",
                                value: "\(device.currentTempF.fixed(1))°",
                                label: "Indoor",
                                tint: modeColor
                            )
                            Readout(
                                symbol: "humidity.fill",
                                value: "\(device.humidityPercent)%",
                                label: "Humidity",
                                tint: NexColors.cyan
                            )
                            Readout(
                                symbol: "sun.max.fill",
                                value: "\(device.outdoorTempF.rounded0)°",
                                label: "Outside",
                                tint: NexColors.amber
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }

                LiquidSegmented(
                    options: modes.map(\.1),
                    selectedIndex: max(
                        modes.firstIndex { $0.0 == (device.isOn ? device.hvacMode : .off) } ?? 0,
                        0
                    ),
                    accent: accent
                ) { index in
                    setMode(modes[index].0, isAc: isAc)
                }
                NexText(climateStatusLine(device), .label, color: NexColors.secondary)
            }

            // Blower fan.
            GlassSection(title: "Fan", symbol: "wind", accent: accent) {
                LiquidSegmented(
                    options: fanModeOptions,
                    selectedIndex: device.fanMode.rawValue,
                    accent: accent
                ) { index in
                    device.fanMode = FanMode.allCases[index]
                }
                NexText(
                    {
                        switch device.fanMode {
                        case .auto: return "Runs only while heating or cooling"
                        case .on: return "Circulates air continuously for even comfort"
                        case .circulate: return "Runs 15 minutes every hour to mix rooms"
                        }
                    }(),
                    .label,
                    color: NexColors.secondary
                )
            }

            // Insights.
            GlassSection(title: "Last 24 hours", symbol: "clock.arrow.circlepath", accent: accent) {
                TemperatureTimeline(
                    history: device.tempHistory,
                    target: device.targetTempF,
                    color: modeColor,
                    title: "Indoor temperature",
                    live: active
                )
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Power",
                        value: "\(device.powerDrawWatts.rounded0)",
                        unit: "W",
                        symbol: "bolt.fill",
                        accent: accent,
                        history: device.powerHistory
                    )
                    GlassMetricTile(
                        label: "Today · $\((device.energyTodayKwh * costPerKwh).fixed(2))",
                        value: device.energyTodayKwh.fixed(2),
                        unit: "kWh",
                        symbol: "leaf.fill",
                        accent: ecoColor
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            // Efficiency and schedule.
            GlassSection(title: "Schedule", symbol: "clock.fill", accent: accent) {
                GlassSettingRow(
                    title: "Eco mode",
                    symbol: "leaf.fill",
                    subtitle: device.ecoEnabled
                        ? "Wider comfort band · saves ~12%"
                        : "Precise comfort",
                    accent: ecoColor
                ) {
                    LiquidToggle(isOn: device.ecoEnabled, accent: ecoColor) { on in
                        device.ecoEnabled = on
                        if !on && device.hvacMode == .eco {
                            device.hvacMode = isAc ? .cool : .auto
                            DeviceGenerator.updateClimateFlags(device)
                        }
                    }
                }
                GlassSettingRow(
                    title: "Smart schedule",
                    symbol: "clock.fill",
                    subtitle: device.scheduleEnabled
                        ? "Comfort \(hourLabel(device.scheduleOnHour))–\(hourLabel(device.scheduleOffHour))"
                        : "Holds the dial setting all day",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.scheduleEnabled, accent: accent) {
                        device.scheduleEnabled = $0
                    }
                }
                if device.scheduleEnabled {
                    ScheduleStrip(
                        onHour: device.scheduleOnHour,
                        offHour: device.scheduleOffHour,
                        color: modeColor,
                        comfortLabel: "Comfort \(device.targetTempF.rounded0)°",
                        setbackLabel: "Setback \(setback.rounded0)°"
                    )
                    StepperRow(
                        title: "Comfort from",
                        value: device.scheduleOnHour,
                        format: hourLabel,
                        accent: accent
                    ) { device.scheduleOnHour = $0 }
                    StepperRow(
                        title: "Setback from",
                        subtitle: "\(setback.rounded0)° asleep or away",
                        value: device.scheduleOffHour,
                        format: hourLabel,
                        accent: NexColors.indigo
                    ) { device.scheduleOffHour = $0 }
                }
            }

            // Maintenance.
            GlassSection(
                title: "Maintenance",
                symbol: "line.3.horizontal.decrease.circle.fill",
                accent: accent
            ) {
                FilterCare(device: device)
                FirmwareRow(device: device)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.scheduleEnabled)
        // The header power toggle only flips isOn: resume a sensible mode when it turns on.
        .onChange(of: device.isOn) { _, on in
            if on && device.hvacMode == .off {
                device.hvacMode = device.type == .acUnit ? .cool : .auto
            }
            DeviceGenerator.updateClimateFlags(device)
        }
    }

    private var trendSymbol: String {
        if device.currentTempF < device.targetTempF - 0.4 { return "arrow.up.right" }
        if device.currentTempF > device.targetTempF + 0.4 { return "arrow.down.right" }
        return "thermometer.medium"
    }

    private func setTarget(_ value: Double, isAc: Bool) {
        device.targetTempF = value
        if device.hvacMode == .off { device.hvacMode = isAc ? .cool : .auto }
        if !device.isOn { device.isOn = true }
        DeviceGenerator.updateClimateFlags(device)
    }

    private func setMode(_ mode: HvacMode, isAc: Bool) {
        device.hvacMode = mode
        device.isOn = mode != .off
        if mode == .eco { device.ecoEnabled = true }
        DeviceGenerator.updateClimateFlags(device)
    }
}

// MARK: - Water heater / pool heater (ControlKind.waterHeaterDial)

/// Water heater / pool heater sheet: a set-point dial on a heat-shimmer stage, Eco / Performance /
/// Vacation modes, a live glass hot-water tank (or rippling pool surface) whose water level, colour
/// and bubbles follow the simulation, a hold-to-boost orb, usage timeline and time-of-use scheduling.
struct WaterHeaterControls: View {
    @Bindable var device: Device

    var body: some View {
        let isPool = device.type == .poolHeater
        let accent = deviceAccent(device.type)
        let range: ClosedRange<Double> = isPool ? 70...95 : 100...140
        let vacation = device.waterHeaterMode == .vacation
        let effectiveTarget = vacation ? device.targetTempF - 20 : device.targetTempF
        let coldReference: Double = isPool ? 60 : 70
        let heat = clamp01(
            (device.currentTempF - coldReference) / max(effectiveTarget - coldReference, 1)
        )
        let heating = device.isOn && device.isHeating
        let heatColorValue: Color = {
            if !device.isOn { return idleColor }
            if device.boostActive { return NexColors.red }
            if heating { return isPool ? NexColors.orange : accent }
            return isPool ? accent : NexColors.amber
        }()

        VStack(spacing: 16) {
            GlassSection(
                title: "Set point",
                symbol: isPool ? "figure.pool.swim" : "flame.fill",
                accent: heatColorValue,
                trailing: AnyView(
                    StatusBadge(
                        text: {
                            if !device.isOn { return "Off" }
                            if device.boostActive { return "Boosting" }
                            return heating ? "Heating" : "Ready"
                        }(),
                        color: heatColorValue,
                        pulsing: heating
                    )
                )
            ) {
                HeroStage {
                    ThermalAura(color: heatColorValue, glow: heating ? 1 : (device.isOn ? 0.3 : 0), rising: true)
                        .animation(.spring(response: 0.993, dampingFraction: 1), value: heating)
                } content: {
                    VStack(spacing: 14) {
                        LiquidDial(
                            value: device.targetTempF,
                            range: range,
                            accent: heatColorValue,
                            detents: 1,
                            size: 240,
                            onChange: { value in
                                device.targetTempF = value
                                if !device.isOn { device.isOn = true }
                            }
                        ) {
                            VStack(spacing: 0) {
                                NexText(
                                    {
                                        if !device.isOn { return "HEATER OFF" }
                                        if vacation { return "VACATION HOLD" }
                                        return heating ? "HEATING TO" : "READY AT"
                                    }(),
                                    .caption,
                                    color: NexColors.secondary
                                )
                                .lineLimit(1)
                                Text("\(effectiveTarget.rounded0)°")
                                    .font(NexType.numeric.font)
                                    .tracking(NexType.numeric.tracking)
                                    .foregroundStyle(NexColors.primary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(heatColorValue)
                                    NexText(
                                        "Water \(device.currentTempF.fixed(1))°",
                                        .label,
                                        color: NexColors.secondary
                                    )
                                    .lineLimit(1)
                                }
                            }
                        }
                        HStack(spacing: 0) {
                            if isPool {
                                Readout(
                                    symbol: "figure.pool.swim",
                                    value: "\(device.currentTempF.fixed(1))°",
                                    label: "Water",
                                    tint: accent
                                )
                            } else {
                                Readout(
                                    symbol: "shower.fill",
                                    value: "\(device.hotWaterPercent)%",
                                    label: "Tank",
                                    tint: accent
                                )
                            }
                            Readout(
                                symbol: "speedometer",
                                value: heaterModeName(device.waterHeaterMode, isPool),
                                label: "Mode",
                                tint: NexColors.violet
                            )
                            Readout(
                                symbol: "bolt.fill",
                                value: heaterKw(device) > 0 ? "\(heaterKw(device).fixed(1)) kW" : "Idle",
                                label: "Element",
                                tint: heatColorValue
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }

                LiquidSegmented(
                    options: [
                        SegmentOption("Eco", "leaf.fill"),
                        SegmentOption(isPool ? "Fast heat" : "Performance", "bolt.fill"),
                        SegmentOption("Vacation", "suitcase.fill"),
                    ],
                    selectedIndex: device.waterHeaterMode.rawValue,
                    accent: accent
                ) { index in
                    device.waterHeaterMode = WaterHeaterMode.allCases[index]
                }
                NexText(
                    {
                        switch device.waterHeaterMode {
                        case .eco: return "Heat-pump first · lowest running cost"
                        case .performance: return "All elements on · recovers ~65% faster"
                        case .vacation: return "Holds \(effectiveTarget.rounded0)° to save energy while away"
                        }
                    }(),
                    .label,
                    color: NexColors.secondary
                )
            }

            // Water visual and boost.
            if isPool {
                GlassSection(
                    title: "Pool water",
                    symbol: "figure.pool.swim",
                    accent: accent,
                    trailing: AnyView(
                        NexText(heatUpText(device, effectiveTarget), .caption, color: NexColors.secondary)
                            .lineLimit(1)
                    )
                ) {
                    PoolSurface(
                        temperature: "\(device.currentTempF.fixed(1))°",
                        caption: heating
                            ? "Warming toward \(effectiveTarget.rounded0)°"
                            : "Holding temperature",
                        heat: heat,
                        heating: heating,
                        accent: accent
                    )
                    .frame(height: 150)
                    HStack(spacing: 16) {
                        boostOrb(size: 104)
                        VStack(alignment: .leading, spacing: 4) {
                            NexText("HEAT-UP", .caption, color: NexColors.secondary)
                            NexText(heatUpText(device, effectiveTarget), .title)
                            NexText(
                                "Fast heat and boost warm the pool quicker",
                                .caption,
                                color: NexColors.tertiary
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                GlassSection(
                    title: "Hot water",
                    symbol: "shower.fill",
                    accent: accent,
                    trailing: AnyView(
                        NexText(tankRefillText(device), .caption, color: NexColors.secondary).lineLimit(1)
                    )
                ) {
                    HStack(spacing: 16) {
                        HotWaterTank(
                            percent: device.hotWaterPercent,
                            heat: heat,
                            heating: heating,
                            boost: device.boostActive,
                            on: device.isOn,
                            accent: accent
                        )
                        .frame(width: 112, height: 236)
                        VStack(spacing: 12) {
                            boostOrb(size: 116)
                            NexText(
                                "≈ \((Double(device.hotWaterPercent) / 20).rounded0) showers ready",
                                .label,
                                color: NexColors.secondary
                            )
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            GlassSection(title: "Usage", symbol: "clock.arrow.circlepath", accent: accent) {
                TemperatureTimeline(
                    history: device.tempHistory,
                    target: effectiveTarget,
                    color: heatColorValue,
                    title: isPool ? "Water temperature" : "Tank temperature",
                    live: heating
                )
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Power",
                        value: "\(device.powerDrawWatts.rounded0)",
                        unit: "W",
                        symbol: "bolt.fill",
                        accent: accent,
                        history: device.powerHistory
                    )
                    GlassMetricTile(
                        label: "Today · $\((device.energyTodayKwh * costPerKwh).fixed(2))",
                        value: device.energyTodayKwh.fixed(2),
                        unit: "kWh",
                        symbol: "leaf.fill",
                        accent: ecoColor
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            GlassSection(title: "Schedule", symbol: "clock.fill", accent: accent) {
                GlassSettingRow(
                    title: isPool ? "Heating window" : "Time-of-use heating",
                    symbol: "clock.fill",
                    subtitle: device.scheduleEnabled
                        ? "\(hourLabel(device.scheduleOnHour))–\(hourLabel(device.scheduleOffHour)) · off-peak savings"
                        : "Heats whenever needed",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.scheduleEnabled, accent: accent) {
                        device.scheduleEnabled = $0
                    }
                }
                if device.scheduleEnabled {
                    ScheduleStrip(
                        onHour: device.scheduleOnHour,
                        offHour: device.scheduleOffHour,
                        color: heatColorValue,
                        comfortLabel: "Heating \(effectiveTarget.rounded0)°",
                        setbackLabel: "Standby"
                    )
                    StepperRow(
                        title: "Heat from",
                        value: device.scheduleOnHour,
                        format: hourLabel,
                        accent: accent
                    ) { device.scheduleOnHour = $0 }
                    StepperRow(
                        title: "Heat until",
                        value: device.scheduleOffHour,
                        format: hourLabel,
                        accent: accent
                    ) { device.scheduleOffHour = $0 }
                }
                GlassSettingRow(
                    title: "Vacation hold",
                    symbol: "suitcase.fill",
                    subtitle: "Keeps \((device.targetTempF - 20).rounded0)° while you're away",
                    accent: NexColors.violet
                ) {
                    LiquidToggle(
                        isOn: device.waterHeaterMode == .vacation,
                        accent: NexColors.violet
                    ) { on in
                        device.waterHeaterMode = on ? .vacation : .eco
                    }
                }
                FirmwareRow(device: device)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.scheduleEnabled)
    }

    private func boostOrb(size: CGFloat) -> some View {
        LiquidHoldOrb(
            label: device.boostActive ? "Boosting" : "Hold to boost",
            symbol: "bolt.fill",
            accent: NexColors.red,
            active: device.boostActive,
            size: size,
            sublabel: device.boostActive ? "Hold again to stop" : "Max heat until full"
        ) {
            device.isOn = true
            device.boostActive.toggle()
        }
    }
}

/// Glass hot-water tank: sloshing water level, cold→hot gradient, rising bubbles while heating.
private struct HotWaterTank: View {
    let percent: Int
    let heat: Double
    let heating: Bool
    let boost: Bool
    let on: Bool
    let accent: Color

    var body: some View {
        let hot: Color = !on ? idleColor : (boost ? NexColors.red : accent)
        let topColor = coldWater.lerp(to: hot, heat)
        let rate: Double = boost && heating ? 0.8 : (heating ? 0.35 : 0)

        GlassPanel(
            shape: glassRect(30),
            tint: Color.black.opacity(0.088),
            heavy: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: rate) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        let f = clamp01(Double(percent) / 100)
                        let inset: CGFloat = 4
                        let surfaceY = inset + (h - inset * 2) * CGFloat(1 - f)
                        let amp: CGFloat = 2 + (heating ? 3 : 0)
                        ZStack {
                            waterShape(w: w, h: h, surfaceY: surfaceY, amp: amp, phase: phase)
                                .fill(
                                    LinearGradient(
                                        colors: [topColor, deepWater.lerp(to: topColor, 0.35)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            meniscus(w: w, surfaceY: surfaceY, amp: amp, phase: phase)
                                .stroke(
                                    Color.white.opacity(0.45),
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                                )
                            if heating {
                                ForEach(0..<6, id: \.self) { index in
                                    let t = (phase * Double(2 + index % 2) + Double(index) * 0.167)
                                        .truncatingRemainder(dividingBy: 1)
                                    let y = h - inset - CGFloat(t) * (h - inset - surfaceY)
                                    let seed = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
                                    let x = w * CGFloat(0.18 + 0.64 * seed)
                                    Circle()
                                        .fill(Color.white.opacity(0.55 * sin(t * .pi)))
                                        .frame(width: CGFloat(3 + index % 3))
                                        .position(x: x, y: y)
                                }
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.811, dampingFraction: 0.45), value: percent)
            ),
            front: AnyView(
                GeometryReader { proxy in
                    ForEach(1..<4, id: \.self) { k in
                        let y = proxy.size.height * (1 - CGFloat(k) / 4)
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 10, height: 1)
                            .position(x: proxy.size.width - 13, y: y)
                    }
                }
            )
        ) {
            VStack(spacing: 0) {
                NexText("\(percent)%", .title).lineLimit(1)
                NexText("HOT WATER", .caption, color: NexColors.secondary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 18)
        }
    }

    private func waterShape(w: CGFloat, h: CGFloat, surfaceY: CGFloat, amp: CGFloat, phase: Double) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: h))
            let steps = 16
            for s in 0...steps {
                let x = w * CGFloat(s) / CGFloat(steps)
                let y = surfaceY
                    + CGFloat(sin((Double(s) / Double(steps) * 1.5 + phase) * 2 * .pi)) * amp
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
        }
    }

    private func meniscus(w: CGFloat, surfaceY: CGFloat, amp: CGFloat, phase: Double) -> Path {
        Path { path in
            let steps = 16
            for s in 0...steps {
                let x = w * CGFloat(s) / CGFloat(steps)
                let y = surfaceY
                    + CGFloat(sin((Double(s) / Double(steps) * 1.5 + phase) * 2 * .pi)) * amp
                if s == 0 { path.move(to: CGPoint(x: x, y: y)) } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

/// Glass pool surface: caustic ripples and rising steam while heating, water warms in colour.
private struct PoolSurface: View {
    let temperature: String
    let caption: String
    let heat: Double
    let heating: Bool
    let accent: Color

    var body: some View {
        let surface = poolCool.lerp(to: accent.lerp(to: NexColors.orange, 0.45), heat)

        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.048),
            heavy: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: heating ? 0.3 : 0) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        ZStack {
                            LinearGradient(
                                colors: [surface.opacity(0.65), deepWater.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            ForEach(0..<6, id: \.self) { k in
                                caustic(w: w, h: h, k: k, phase: phase)
                                    .stroke(
                                        Color.white.opacity(0.1 + 0.05 * Double(k % 2)),
                                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                                    )
                            }
                            if heating {
                                ForEach(0..<6, id: \.self) { index in
                                    let t = (phase * Double(1 + index % 2) + Double(index) * 0.167)
                                        .truncatingRemainder(dividingBy: 1)
                                    let seed = (Double(index) * 0.618)
                                        .truncatingRemainder(dividingBy: 1)
                                    Circle()
                                        .fill(Color.white.opacity(0.4 * sin(t * .pi)))
                                        .frame(width: CGFloat(4 + index % 3) * 1.2)
                                        .position(
                                            x: w * CGFloat(0.06 + 0.88 * seed),
                                            y: h * CGFloat(0.9 - 0.8 * t)
                                        )
                                        .blendMode(.plusLighter)
                                }
                            }
                        }
                    }
                }
            )
        ) {
            VStack(spacing: 0) {
                NexText(temperature, .headline).lineLimit(1)
                NexText(caption, .caption, color: NexColors.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func caustic(w: CGFloat, h: CGFloat, k: Int, phase: Double) -> Path {
        Path { path in
            let base = h * CGFloat(0.14 + 0.15 * Double(k))
            let direction: Double = k % 2 == 0 ? 1 : -1
            for s in 0...20 {
                let x = w * CGFloat(s) / 20
                let y = base + CGFloat(
                    sin((Double(s) / 20 * (2 + Double(k) * 0.35) + phase * direction) * 2 * .pi)
                ) * 4
                if s == 0 { path.move(to: CGPoint(x: x, y: y)) } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - Fans / purifier / humidity (ControlKind.fanSpeed)

/// Fan sheet for ceiling fans, standing fans, air purifiers and bathroom humidity control: a big
/// glass orb with live blades (spin speed, direction, gusts and oscillation follow the device), a
/// speed selector, a per-type section, a sleep timer and energy stats.
struct FanControls: View {
    @Bindable var device: Device

    var body: some View {
        let type = device.type
        let accent = deviceAccent(type)
        let on = device.isOn && device.fanSpeed > 0
        let speed = clamp(device.fanSpeed, 0, 4)
        let labels = fanSpeedLabels(type)
        let text = fanOrbText(device, on: on, speed: speed)

        VStack(spacing: 16) {
            GlassSection(
                title: {
                    switch type {
                    case .ceilingFan: return "Ceiling fan"
                    case .standingFan: return "Fan"
                    case .airPurifier: return "Purifier"
                    default: return "Exhaust fan"
                    }
                }(),
                symbol: {
                    switch type {
                    case .standingFan: return "fan.desk.fill"
                    case .bathroomHumidity: return "shower.fill"
                    default: return "wind"
                    }
                }(),
                accent: accent,
                trailing: AnyView(
                    StatusBadge(
                        text: on ? labels[speed] : "Off",
                        color: on ? accent : idleColor,
                        pulsing: on
                    )
                )
            ) {
                HeroStage {
                    FanAura(accent: accent, activity: on ? Double(speed) / 4 : 0, speed: speed)
                } content: {
                    VStack(spacing: 12) {
                        FanOrb(device: device, accent: accent, diameter: 208) {
                            if on { device.isOn = false } else { turnOn() }
                        }
                        VStack(spacing: 0) {
                            NexText(text.0, .title).lineLimit(1)
                            NexText(text.1, .caption, color: NexColors.secondary).lineLimit(1)
                        }
                    }
                }
                LiquidSegmented(
                    options: labels.map { SegmentOption($0) },
                    selectedIndex: device.isOn ? speed : 0,
                    accent: accent
                ) { index in
                    device.fanSpeed = index
                    device.isOn = index > 0
                }
            }

            // Per-type section.
            switch type {
            case .ceilingFan:
                GlassSection(title: "Direction", symbol: "arrow.up.arrow.down", accent: accent) {
                    LiquidSegmented(
                        options: [
                            SegmentOption("Summer", "sun.max.fill"),
                            SegmentOption("Winter", "snowflake"),
                        ],
                        selectedIndex: device.reverseDirection ? 1 : 0,
                        accent: accent
                    ) { device.reverseDirection = $0 == 1 }
                    NexText(
                        device.reverseDirection
                            ? "Clockwise updraft pushes warm ceiling air down the walls"
                            : "Counter-clockwise downdraft creates a cooling breeze",
                        .label,
                        color: NexColors.secondary
                    )
                }

            case .standingFan:
                GlassSection(title: "Airflow", symbol: "fan.desk.fill", accent: accent) {
                    GlassSettingRow(
                        title: "Oscillate",
                        symbol: "arrow.triangle.2.circlepath",
                        subtitle: "Sweeps side to side",
                        accent: accent
                    ) {
                        LiquidToggle(isOn: device.isOscillating, accent: accent) {
                            device.isOscillating = $0
                        }
                    }
                    GlassSettingRow(
                        title: "Natural breeze",
                        symbol: "wind",
                        subtitle: "Gusts rise and fall like wind",
                        accent: NexColors.teal
                    ) {
                        LiquidToggle(isOn: device.breezeMode, accent: NexColors.teal) {
                            device.breezeMode = $0
                        }
                    }
                }

            case .airPurifier:
                let aqi = device.airQualityIndex
                let airColor = aqiColor(aqi)
                GlassSection(
                    title: "Air quality",
                    symbol: "aqi.medium",
                    accent: airColor,
                    trailing: AnyView(StatusBadge(text: aqiLabel(aqi), color: airColor))
                ) {
                    LiquidDial(
                        value: Double(aqi),
                        range: 0...150,
                        accent: airColor,
                        readOnly: true,
                        size: 200
                    ) {
                        VStack(spacing: 0) {
                            Text("\(aqi)")
                                .font(NexType.numeric.font)
                                .tracking(NexType.numeric.tracking)
                                .foregroundStyle(NexColors.primary)
                                .lineLimit(1)
                            NexText("US AQI", .caption, color: NexColors.secondary).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    NexText(
                        {
                            if !on { return "Paused · air slowly returns to room levels" }
                            if aqi <= 20 { return "Crisp, clean air · holding steady" }
                            return "Scrubbing the room · higher speeds clean faster"
                        }(),
                        .label,
                        color: NexColors.secondary
                    )
                    HStack(spacing: 12) {
                        GlassMetricTile(
                            label: "PM2.5",
                            value: (Double(aqi) * 0.3).fixed(1),
                            unit: "µg/m³",
                            symbol: "aqi.low",
                            accent: airColor
                        )
                        GlassMetricTile(
                            label: "Clean air",
                            value: "\(purifierCadr[speed])",
                            unit: "CFM",
                            symbol: "wind",
                            accent: accent
                        )
                    }
                    FilterCare(device: device)
                }

            default:
                GlassSection(title: "Humidity", symbol: "humidity.fill", accent: accent) {
                    LiquidDial(
                        value: Double(device.humidityTarget),
                        range: 30...70,
                        accent: accent,
                        detents: 5,
                        size: 220,
                        onChange: { value in
                            device.humidityTarget = value.rounded0
                            if !on { turnOn() }
                        }
                    ) {
                        VStack(spacing: 0) {
                            NexText("TARGET", .caption, color: NexColors.secondary).lineLimit(1)
                            Text("\(device.humidityTarget)%")
                                .font(NexType.numeric.font)
                                .tracking(NexType.numeric.tracking)
                                .foregroundStyle(NexColors.primary)
                                .lineLimit(1)
                            NexText("Now \(device.humidityPercent)%", .label, color: NexColors.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    NexText(
                        {
                            if !on { return "Fan off · humidity drifts toward ~62%" }
                            if device.humidityPercent > device.humidityTarget {
                                return "Venting · \(device.humidityPercent - device.humidityTarget)% above target"
                            }
                            return "At target · fan keeps the air fresh"
                        }(),
                        .label,
                        color: NexColors.secondary
                    )
                }
            }

            // Sleep timer.
            GlassSection(
                title: "Sleep timer",
                symbol: "timer",
                accent: accent,
                trailing: AnyView(
                    NexText(
                        device.fanTimerMinutes > 0
                            ? "Off at \(offAtText(device.fanTimerMinutes))"
                            : "Not set",
                        .caption,
                        color: NexColors.secondary
                    )
                    .lineLimit(1)
                )
            ) {
                StepperRow(
                    title: "Turn off after",
                    subtitle: device.fanTimerMinutes > 0
                        ? "\(timerLabel(device.fanTimerMinutes)) left"
                        : "No timer",
                    value: device.fanTimerMinutes,
                    range: 0...480,
                    step: 15,
                    format: timerLabel,
                    accent: accent
                ) { device.fanTimerMinutes = $0 }
                LiquidChipRow {
                    ForEach([30, 60, 120, 240], id: \.self) { minutes in
                        LiquidChip(
                            label: timerLabel(minutes),
                            symbol: "moon.stars.fill",
                            selected: device.fanTimerMinutes == minutes,
                            accent: accent
                        ) {
                            if device.fanTimerMinutes == minutes {
                                device.fanTimerMinutes = 0
                            } else {
                                device.fanTimerMinutes = minutes
                                if !on { turnOn() }
                            }
                        }
                    }
                }
            }

            // Energy and stats.
            GlassSection(title: "Energy", symbol: "bolt.fill", accent: accent) {
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Power",
                        value: "\(device.powerDrawWatts.rounded0)",
                        unit: "W",
                        symbol: "bolt.fill",
                        accent: accent,
                        history: device.powerHistory
                    )
                    GlassMetricTile(
                        label: "Today · $\((device.energyTodayKwh * costPerKwh).fixed(2))",
                        value: device.energyTodayKwh.fixed(2),
                        unit: "kWh",
                        symbol: "leaf.fill",
                        accent: ecoColor
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    switch type {
                    case .airPurifier:
                        GlassMetricTile(
                            label: "Filter",
                            value: "\(device.filterLifePercent)",
                            unit: "%",
                            symbol: "line.3.horizontal.decrease.circle.fill",
                            accent: filterColor(device.filterLifePercent)
                        )
                        GlassMetricTile(
                            label: "Room",
                            value: "\(device.humidityPercent)",
                            unit: "% RH",
                            symbol: "humidity.fill",
                            accent: NexColors.cyan
                        )
                    case .bathroomHumidity:
                        GlassMetricTile(
                            label: "Humidity",
                            value: "\(device.humidityPercent)",
                            unit: "%",
                            symbol: "humidity.fill",
                            accent: accent
                        )
                        GlassMetricTile(
                            label: "Target",
                            value: "\(device.humidityTarget)",
                            unit: "%",
                            symbol: "drop.fill",
                            accent: NexColors.cyan
                        )
                    default:
                        GlassMetricTile(
                            label: "Airflow",
                            value: "\(fanCfm[on ? speed : 0])",
                            unit: "CFM",
                            symbol: "wind",
                            accent: accent
                        )
                        GlassMetricTile(
                            label: "Room",
                            value: "\(device.humidityPercent)",
                            unit: "% RH",
                            symbol: "humidity.fill",
                            accent: NexColors.cyan
                        )
                    }
                }
                FirmwareRow(device: device)
            }
        }
        // The header power toggle only flips isOn: give a fan at speed 0 something to do.
        .onChange(of: device.isOn) { _, isOn in
            if isOn && device.fanSpeed == 0 { device.fanSpeed = 2 }
        }
    }

    private func turnOn() {
        device.isOn = true
        if device.fanSpeed == 0 { device.fanSpeed = 2 }
    }

    private func offAtText(_ minutes: Int) -> String {
        let date = Date.now.addingTimeInterval(Double(minutes) * 60)
        return date.formatted(.dateTime.hour().minute())
    }
}

/// Expanding rings behind the fan orb while it runs.
private struct FanAura: View {
    let accent: Color
    let activity: Double
    let speed: Int

    var body: some View {
        PhaseTimeline(cyclesPerSecond: activity > 0.01 ? 0.2 + 0.1 * Double(speed) : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                if activity > 0.01 {
                    let orbRadius: CGFloat = 104
                    let center = CGPoint(x: size.width / 2, y: 18 + orbRadius)
                    ZStack {
                        RadialGradient(
                            colors: [accent.opacity(0.26 * activity), .clear],
                            center: UnitPoint(
                                x: 0.5,
                                y: size.height > 0 ? center.y / size.height : 0.5
                            ),
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 0.6
                        )
                        .blendMode(.plusLighter)
                        ForEach(0..<3, id: \.self) { k in
                            let t = (phase + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .strokeBorder(
                                    accent.opacity((1 - t) * 0.3 * activity),
                                    lineWidth: 1.5
                                )
                                .frame(
                                    width: (orbRadius + CGFloat(t) * max(size.width, size.height) * 0.45) * 2
                                )
                                .position(center)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// The fan hero: a big round glass orb with live blades. Spin rate follows the device speed, blades
/// reverse for winter mode, gust in breeze mode and sway while oscillating. Tapping toggles power.
private struct FanOrb: View {
    let device: Device
    let accent: Color
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        let on = device.isOn && device.fanSpeed > 0
        let speed = clamp(device.fanSpeed, 0, 4)
        let activity = on ? Double(speed) / 4 : 0
        let direction: Double = device.reverseDirection && device.type == .ceilingFan ? -1 : 1
        let cycles = on ? (0.22 + 0.5 * Double(speed)) * direction : 0

        GlassPanel(
            shape: glassCircle,
            tint: Color.black.opacity(0.072),
            accent: accent,
            heavy: true,
            pressScale: GlassMotion.orbPressScale,
            action: action,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: abs(cycles)) { phase in
                    let angle = (cycles < 0 ? -phase : phase) * 360
                    switch device.type {
                    case .airPurifier:
                        PurifierVortex(angle: angle, activity: activity, air: aqiColor(device.airQualityIndex))
                    case .bathroomHumidity:
                        HumiditySteam(
                            phase: phase,
                            activity: activity,
                            level: Double(device.humidityPercent) / 100,
                            accent: accent
                        )
                    default:
                        FanBlades(
                            angle: angle,
                            activity: activity,
                            accent: accent,
                            oscillating: device.isOscillating && device.type == .standingFan
                        )
                    }
                }
            )
        ) {
            Color.clear.frame(width: diameter, height: diameter)
        }
    }
}

private struct FanBlades: View {
    let angle: Double
    let activity: Double
    let accent: Color
    let oscillating: Bool

    var body: some View {
        GeometryReader { proxy in
            let r = min(proxy.size.width, proxy.size.height) / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: r * 1.8)
                    .position(center)
                // Motion ghosts, then the blades themselves.
                ForEach(Array((0..<(activity > 0.2 ? 3 : 1)).reversed()), id: \.self) { ghost in
                    let a = angle - Double(ghost) * 12 * activity
                    let alpha = ghost == 0 ? 0.7 : 0.18 / Double(ghost)
                    ForEach(0..<3, id: \.self) { index in
                        Ellipse()
                            .fill(Color.white.opacity(alpha))
                            .frame(width: r * 0.36, height: r * 0.6)
                            .offset(y: -r * 0.44)
                            .rotationEffect(.degrees(a + Double(index) * 120))
                            .position(center)
                    }
                }
                Circle().fill(Color.white.opacity(0.9)).frame(width: r * 0.28).position(center)
                Circle().fill(accent).frame(width: r * 0.12).position(center)
            }
            .rotationEffect(
                .degrees(oscillating ? sin(angle / 180 * .pi) * 10 : 0),
                anchor: .center
            )
        }
        .allowsHitTesting(false)
    }
}

private struct PurifierVortex: View {
    let angle: Double
    let activity: Double
    let air: Color

    var body: some View {
        GeometryReader { proxy in
            let r = min(proxy.size.width, proxy.size.height) / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let strength = 0.35 + 0.65 * activity
            ZStack {
                Circle()
                    .strokeBorder(air.opacity(0.55), lineWidth: 1.5)
                    .frame(width: r * 1.8)
                    .position(center)
                ForEach(0..<3, id: \.self) { arm in
                    ForEach(0..<14, id: \.self) { j in
                        let t = Double(j) / 13
                        let rad = radians(angle + Double(arm) * 120 + t * 250)
                        let rr = r * CGFloat(0.14 + 0.72 * t)
                        Circle()
                            .fill(
                                Color.white.lerp(to: air, t)
                                    .opacity((0.2 + 0.6 * (1 - t)) * strength)
                            )
                            .frame(width: CGFloat(2.4 + 5.6 * (1 - t)))
                            .position(
                                x: center.x + cos(rad) * rr,
                                y: center.y + sin(rad) * rr
                            )
                    }
                }
                Circle().fill(Color.white.opacity(0.85)).frame(width: r * 0.2).position(center)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HumiditySteam: View {
    let phase: Double
    let activity: Double
    let level: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let r = min(w, h) / 2
            let top = h * CGFloat(1 - level)
            let strength = 0.2 + 0.8 * activity
            ZStack(alignment: .topLeading) {
                accent.opacity(0.22)
                    .frame(width: w, height: h - top)
                    .offset(y: top)
                Color.white.opacity(0.25)
                    .frame(width: w, height: 1.5)
                    .offset(y: top)
                ForEach(0..<8, id: \.self) { index in
                    let t = (phase * Double(1 + index % 2) + Double(index) * 0.125)
                        .truncatingRemainder(dividingBy: 1)
                    let seed = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .fill(Color.white.opacity(sin(t * .pi) * 0.55 * strength))
                        .frame(width: r * CGFloat(0.05 + 0.024 * Double(index % 3)))
                        .position(
                            x: w / 2 + CGFloat(seed - 0.5) * r * 1.2,
                            y: h / 2 + r * 0.75 - CGFloat(t) * r * 1.5
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Climate helpers

private let coldWater = Color(hex: 0x3D7BFF)
private let deepWater = Color(hex: 0x12306A)
private let poolCool = Color(hex: 0x1B9FE0)
private let simTickSeconds = 2.5

private let thermostatModes: [(HvacMode, SegmentOption)] = [
    (.heat, SegmentOption("Heat", "flame.fill")),
    (.cool, SegmentOption("Cool", "snowflake")),
    (.auto, SegmentOption("Auto", "arrow.triangle.2.circlepath")),
    (.eco, SegmentOption("Eco", "leaf.fill")),
    (.off, SegmentOption("Off", "power")),
]

private let acModes: [(HvacMode, SegmentOption)] = [
    (.cool, SegmentOption("Cool", "snowflake")),
    (.auto, SegmentOption("Auto", "arrow.triangle.2.circlepath")),
    (.eco, SegmentOption("Eco", "leaf.fill")),
    (.off, SegmentOption("Off", "power")),
]

private let fanModeOptions = [
    SegmentOption("Auto", "arrow.triangle.2.circlepath"),
    SegmentOption("On", "wind"),
    SegmentOption("Circulate", "tornado"),
]

private let fanSpeedNames = ["Off", "Low", "Med", "High", "Max"]
private let purifierSpeedNames = ["Off", "Sleep", "Low", "High", "Turbo"]
private let humiditySpeedNames = ["Off", "Quiet", "Low", "High", "Boost"]
private let ceilingRpm = [0, 90, 140, 190, 240]
private let standingRpm = [0, 450, 700, 950, 1200]
private let fanCfm = [0, 1800, 3200, 4600, 6000]
private let purifierCadr = [0, 60, 130, 210, 300]

private func climateColor(_ device: Device, _ isAc: Bool) -> Color {
    if !device.isOn || device.hvacMode == .off { return idleColor }
    if device.isHeating { return heatColor }
    if device.isCooling { return coolColor }
    if device.hvacMode == .eco { return ecoColor }
    if device.hvacMode == .heat { return heatColor }
    if device.hvacMode == .cool || isAc { return coolColor }
    return NexColors.teal
}

private func climateBadge(_ device: Device) -> String {
    if !device.isOn || device.hvacMode == .off { return "Off" }
    if device.isHeating { return "Heating" }
    if device.isCooling { return "Cooling" }
    if device.hvacMode == .eco { return "Eco" }
    return "Idle"
}

private func climateDialCaption(_ device: Device) -> String {
    if !device.isOn || device.hvacMode == .off { return "SYSTEM OFF" }
    if device.isHeating { return "HEATING TO" }
    if device.isCooling { return "COOLING TO" }
    return "HOLDING"
}

private func climateStatusLine(_ device: Device) -> String {
    let target = device.targetTempF.rounded0
    let eta = max(Int((abs(device.targetTempF - device.currentTempF) / 2.9).rounded(.up)), 1)
    if !device.isOn || device.hvacMode == .off { return "System off · turn the dial to resume" }
    if device.isHeating { return "Heating to \(target)° · about \(eta) min" }
    if device.isCooling { return "Cooling to \(target)° · about \(eta) min" }
    if device.hvacMode == .eco { return "Eco hold · wider comfort band around \(target)°" }
    return "Holding \(target)° · equipment idle"
}

private func heaterModeName(_ mode: WaterHeaterMode, _ isPool: Bool) -> String {
    switch mode {
    case .eco: return "Eco"
    case .performance: return isPool ? "Fast" : "Perform."
    case .vacation: return "Vacation"
    }
}

/// Element draw in kW from live state (mirrors the simulation's power model).
private func heaterKw(_ device: Device) -> Double {
    if !device.isOn { return 0 }
    if device.boostActive { return 5.5 }
    if device.isHeating { return device.type == .poolHeater ? 3.2 : 4.5 }
    return 0
}

private func heaterRate(_ device: Device) -> Double {
    if device.boostActive { return 0.9 }
    if device.waterHeaterMode == .performance { return 0.5 }
    return 0.3
}

private func heatUpText(_ device: Device, _ effectiveTarget: Double) -> String {
    guard device.isOn else { return "Heater off" }
    let gap = effectiveTarget - device.currentTempF
    if gap <= 1 && !device.boostActive { return "At temperature" }
    let seconds = max(gap, 0) / heaterRate(device) * simTickSeconds
    return seconds < 60 ? "Ready in <1 min" : "Ready in ~\((seconds / 60).rounded0) min"
}

private func tankRefillText(_ device: Device) -> String {
    if device.hotWaterPercent >= 100 { return "Tank full" }
    guard device.isOn else { return "Heater off" }
    guard device.isHeating else { return "Topping up soon" }
    let seconds = Double(100 - device.hotWaterPercent) * simTickSeconds
        / (device.boostActive ? 3 : 1)
    return seconds < 60 ? "Full in <1 min" : "Full in ~\((seconds / 60).rounded0) min"
}

private func fanSpeedLabels(_ type: DeviceType) -> [String] {
    switch type {
    case .airPurifier: return purifierSpeedNames
    case .bathroomHumidity: return humiditySpeedNames
    default: return fanSpeedNames
    }
}

private func fanOrbText(_ device: Device, on: Bool, speed: Int) -> (String, String) {
    switch device.type {
    case .ceilingFan:
        return (
            on ? "\(ceilingRpm[speed]) RPM" : "Tap to start",
            on
                ? "\(device.reverseDirection ? "Winter updraft" : "Summer downdraft") · \(fanCfm[speed]) CFM"
                : "Blades at rest"
        )
    case .standingFan:
        var parts = [device.isOscillating ? "Oscillating" : "Fixed"]
        if device.breezeMode { parts.append("Natural breeze") }
        return (on ? "\(standingRpm[speed]) RPM" : "Tap to start", parts.joined(separator: " · "))
    case .airPurifier:
        return (
            "AQI \(device.airQualityIndex)",
            on
                ? "\(aqiLabel(device.airQualityIndex)) · \(purifierCadr[speed]) CFM clean air"
                : "Paused · tap to purify"
        )
    default:
        return (
            "\(device.humidityPercent)% humidity",
            on ? "Venting to \(device.humidityTarget)%" : "Tap to vent"
        )
    }
}

func aqiColor(_ aqi: Int) -> Color {
    if aqi <= 50 { return NexColors.mint }
    if aqi <= 100 { return NexColors.gold }
    if aqi <= 150 { return NexColors.orange }
    return NexColors.red
}

func aqiLabel(_ aqi: Int) -> String {
    if aqi <= 50 { return "Good" }
    if aqi <= 100 { return "Moderate" }
    if aqi <= 150 { return "Sensitive" }
    return "Unhealthy"
}
