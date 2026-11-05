import SwiftUI

// MARK: - EV charger / pool pump (ControlKind.evCharger)

/// EV chargers get a read-only charge dial over a live energy stream, a glass battery pack with the
/// limit marker, hold-to-charge, limit and current settings, off-peak scheduling and session
/// history. Pool pumps get a spinning glass impeller over rippling water, speed presets,
/// hold-to-run, a daily run window and energy.
struct EvChargerControls: View {
    @Bindable var device: Device

    var body: some View {
        if device.type == .poolPump {
            PoolPumpSheet(device: device)
        } else {
            EvChargerSheet(device: device)
        }
    }
}

private struct EvChargerSheet: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository
    @State private var limitDraft: Double = 80

    var body: some View {
        let accent = deviceAccent(device.type)
        let charging = device.isCharging
        let plugged = device.plugConnected
        let stateColor = evStateColor(device, accent)

        VStack(spacing: 16) {
            // Hero: charge dial on the energy stream.
            GlassSection(
                title: "Charging",
                symbol: "ev.charger.fill",
                accent: stateColor,
                trailing: AnyView(
                    StatusBadge(text: evBadge(device), color: stateColor, pulsing: charging)
                )
            ) {
                HeroStage {
                    ChargeAura(
                        color: stateColor,
                        glow: charging ? 1 : (plugged ? 0.35 : 0),
                        flowing: charging
                    )
                } content: {
                    VStack(spacing: 14) {
                        LiquidDial(
                            value: Double(device.chargePercent),
                            range: 0...100,
                            accent: stateColor,
                            readOnly: true,
                            size: 232
                        ) {
                            VStack(spacing: 0) {
                                NexText(evDialCaption(device), .caption, color: NexColors.secondary)
                                    .lineLimit(1)
                                Text("\(device.chargePercent)%")
                                    .font(NexType.numeric.font)
                                    .tracking(NexType.numeric.tracking)
                                    .foregroundStyle(NexColors.primary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(stateColor)
                                    NexText(evEta(device), .label, color: NexColors.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "bolt.fill",
                                value: "\((charging ? device.chargeRateKw : Double(device.chargeAmps) * kwPerAmp).fixed(1)) kW",
                                label: charging ? "Rate" : "Max rate",
                                tint: stateColor
                            )
                            Readout(
                                symbol: "battery.100.bolt",
                                value: "\(device.sessionKwh.fixed(1)) kWh",
                                label: "Added",
                                tint: accent
                            )
                            Readout(
                                symbol: "road.lanes",
                                value: "\((device.sessionKwh * milesPerKwh).rounded0) mi",
                                label: "Range",
                                tint: NexColors.cyan
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                BatteryPack(
                    charge: device.chargePercent,
                    limit: device.chargeLimitPercent,
                    color: stateColor,
                    charging: charging
                )
                NexText(evStatusLine(device), .label, color: NexColors.secondary)
            }

            // Session.
            GlassSection(
                title: "Session",
                symbol: "car.fill",
                accent: accent,
                trailing: AnyView(
                    NexText(
                        device.vehicleName.isEmpty ? "Your EV" : device.vehicleName,
                        .caption,
                        color: NexColors.tertiary
                    )
                    .lineLimit(1)
                )
            ) {
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: charging ? "Hold to stop" : "Hold to charge",
                        symbol: charging ? "stop.fill" : "bolt.fill",
                        accent: accent,
                        active: charging,
                        size: 116,
                        sublabel: {
                            if charging { return "\(device.chargeAmps) A session" }
                            if device.chargePercent >= 100 { return "Battery full" }
                            if device.chargePercent >= device.chargeLimitPercent {
                                return "Raises limit +10%"
                            }
                            return "To \(device.chargeLimitPercent)%"
                        }(),
                        enabled: charging || device.chargePercent < 100
                    ) { toggleCharging() }
                    VStack(alignment: .leading, spacing: 12) {
                        SessionFact(
                            symbol: "cable.connector",
                            value: plugged ? "Plugged in" : "Unplugged",
                            label: "Connector",
                            tint: plugged ? accent : NexColors.tertiary
                        )
                        SessionFact(
                            symbol: "timer",
                            value: evEta(device),
                            label: "To \(device.chargeLimitPercent)%",
                            tint: NexColors.cyan
                        )
                        SessionFact(
                            symbol: "creditcard.fill",
                            value: "$\(device.sessionCost.fixed(2))",
                            label: device.offPeakScheduling ? "Off-peak rate" : "Standard rate",
                            tint: NexColors.gold
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Power",
                        value: (repository.liveWatts(device) / 1000).fixed(1),
                        unit: "kW",
                        symbol: "bolt.fill",
                        accent: accent,
                        history: device.powerHistory
                    )
                    GlassMetricTile(
                        label: "Today",
                        value: device.energyTodayKwh.fixed(2),
                        unit: "kWh",
                        symbol: "leaf.fill",
                        accent: NexColors.mint
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Session",
                        value: device.sessionKwh.fixed(1),
                        unit: "kWh",
                        symbol: "battery.100.bolt",
                        accent: accent
                    )
                    GlassMetricTile(
                        label: "Cost",
                        value: "$\(device.sessionCost.fixed(2))",
                        symbol: "creditcard.fill",
                        accent: NexColors.gold
                    )
                }
            }

            // Charge limit and current.
            GlassSection(
                title: "Charge limit",
                symbol: "battery.100.bolt",
                accent: accent,
                trailing: AnyView(
                    NexText("\(device.chargeLimitPercent)%", .title, color: accent).lineLimit(1)
                )
            ) {
                LiquidSlider(value: limitDraft, range: 50...100, accent: accent) { value in
                    limitDraft = value
                    device.chargeLimitPercent = clamp(value.rounded0, 50, 100)
                }
                HStack {
                    NexText("50%", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText(
                        "≈ \((Double(device.chargeLimitPercent) / 100 * evBatteryKwh * milesPerKwh).rounded0) mi of range",
                        .caption,
                        color: NexColors.secondary
                    )
                    Spacer()
                    NexText("100%", .caption, color: NexColors.tertiary)
                }
                LiquidChipRow {
                    ForEach(evLimitPresets, id: \.percent) { preset in
                        LiquidChip(
                            label: "\(preset.label) · \(preset.percent)%",
                            symbol: preset.symbol,
                            selected: device.chargeLimitPercent == preset.percent,
                            accent: accent
                        ) {
                            device.chargeLimitPercent = preset.percent
                            limitDraft = Double(preset.percent)
                        }
                    }
                }
                GlassSettingRow(
                    title: "Charging current",
                    symbol: "bolt.horizontal.fill",
                    subtitle: "\((Double(device.chargeAmps) * kwPerAmp).fixed(1)) kW · \(ampsLabel(device.chargeAmps))",
                    accent: accent
                ) {
                    LiquidIntStepper(
                        value: device.chargeAmps,
                        range: 8...48,
                        step: 4,
                        format: { "\($0) A" },
                        accent: accent
                    ) { amps in
                        device.chargeAmps = amps
                        device.chargeRateKw = Double(amps) * kwPerAmp
                    }
                }
                GlassLevelBar(
                    fraction: Double(device.chargeAmps - 8) / 40,
                    color: device.chargeAmps >= 40 ? NexColors.orange : accent
                )
            }

            // Smart charging.
            GlassSection(title: "Smart charging", symbol: "clock.fill", accent: accent) {
                GlassSettingRow(
                    title: "Off-peak charging",
                    symbol: "moon.stars.fill",
                    subtitle: device.offPeakScheduling
                        ? "Waits for 11 PM–7 AM · $0.14/kWh"
                        : "Charges right away · $0.28/kWh",
                    accent: offPeakColor
                ) {
                    LiquidToggle(isOn: device.offPeakScheduling, accent: offPeakColor) {
                        device.offPeakScheduling = $0
                    }
                }
                HourTimeline(
                    bands: [
                        HourBand(from: 16, to: 21, color: NexColors.orange.opacity(0.55)),
                        HourBand(
                            from: 23,
                            to: 31,
                            color: offPeakColor.opacity(device.offPeakScheduling ? 0.8 : 0.3)
                        ),
                    ],
                    marker: device.scheduleEnabled ? Double(device.scheduleOnHour) : nil,
                    markerColor: accent
                )
                HStack(spacing: 14) {
                    LegendDot(color: NexColors.orange, label: "Peak 4–9 PM")
                    LegendDot(color: offPeakColor, label: "Off-peak")
                    if device.scheduleEnabled { LegendDot(color: accent, label: "Ready by") }
                }
                GlassSettingRow(
                    title: "Ready by departure",
                    symbol: "car.side.and.exclamationmark",
                    subtitle: device.scheduleEnabled
                        ? "\(device.chargeLimitPercent)% by \(hourLabel(device.scheduleOnHour))"
                        : "No departure time set",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.scheduleEnabled, accent: accent) {
                        device.scheduleEnabled = $0
                    }
                }
                if device.scheduleEnabled {
                    GlassSettingRow(
                        title: "Departure",
                        subtitle: "Finishes just before you leave",
                        accent: accent
                    ) {
                        LiquidIntStepper(
                            value: device.scheduleOnHour,
                            range: 0...23,
                            format: hourLabel,
                            accent: accent
                        ) { device.scheduleOnHour = $0 }
                    }
                }
                let saved = device.sessionKwh * (peakRate - offPeakRate)
                NexText(
                    device.offPeakScheduling
                        ? "Off-peak saved $\(saved.fixed(2)) on this session"
                        : "Switching to off-peak would save $\(saved.fixed(2)) on this session",
                    .label,
                    color: NexColors.secondary
                )
            }

            // Vehicle and charger.
            GlassSection(title: "Vehicle", symbol: "car.fill", accent: accent) {
                GlassSettingRow(
                    title: device.vehicleName.isEmpty ? "Your EV" : device.vehicleName,
                    symbol: "car.fill",
                    subtitle: device.plugConnected
                        ? "Connected · ≈ \((Double(device.chargePercent) / 100 * evBatteryKwh * milesPerKwh).rounded0) mi range"
                        : "Cable not connected",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.plugConnected, accent: accent) { plug in
                        if plug && !device.plugConnected {
                            device.sessionKwh = 0
                            device.sessionCost = 0
                        }
                        device.plugConnected = plug
                        if !plug { device.isCharging = false }
                    }
                }
                SignalRow(device: device, accent: accent)
                NexText("RECENT SESSIONS", .caption, color: NexColors.tertiary)
                ForEach(pastSessions(for: device), id: \.day) { session in
                    let rate = session.offPeak ? offPeakRate : peakRate
                    GlassSettingRow(
                        title: "\(session.kwh.fixed(1)) kWh · $\((session.kwh * rate).fixed(2))",
                        symbol: "clock.arrow.circlepath",
                        subtitle: "\(session.day) · \(session.offPeak ? "Off-peak" : "Peak") · \(shortDuration(session.minutes))",
                        accent: session.offPeak ? offPeakColor : NexColors.orange
                    ) {
                        NexText(
                            "+\((session.kwh * milesPerKwh).rounded0) mi",
                            .caption,
                            color: NexColors.tertiary
                        )
                        .lineLimit(1)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.scheduleEnabled)
        .task { limitDraft = Double(device.chargeLimitPercent) }
    }

    private func toggleCharging() {
        if device.isCharging {
            device.isCharging = false
        } else {
            if device.chargePercent >= device.chargeLimitPercent {
                device.chargeLimitPercent = clamp(((device.chargePercent + 10) / 5) * 5, 50, 100)
                limitDraft = Double(device.chargeLimitPercent)
            }
            if !device.plugConnected {
                device.plugConnected = true
                device.sessionKwh = 0
                device.sessionCost = 0
            }
            device.chargeRateKw = Double(device.chargeAmps) * kwPerAmp
            device.isCharging = true
        }
    }
}

/// Energy flowing up the stage while the car charges.
private struct ChargeAura: View {
    let color: Color
    let glow: Double
    let flowing: Bool

    var body: some View {
        PhaseTimeline(cyclesPerSecond: flowing ? 0.45 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    RadialGradient(
                        colors: [color.opacity(0.24 * glow), .clear],
                        center: UnitPoint(x: 0.5, y: 0.32),
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.62
                    )
                    .blendMode(.plusLighter)
                    if flowing {
                        ForEach(0..<18, id: \.self) { index in
                            let seed = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
                            let t = (phase * Double(1 + index % 3) + seed)
                                .truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(color.opacity(sin(t * .pi) * 0.5))
                                .frame(width: CGFloat(3 + index % 3))
                                .position(
                                    x: size.width * CGFloat(0.08 + 0.84 * seed),
                                    y: size.height * CGFloat(1 - t)
                                )
                                .blendMode(.plusLighter)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// A glass battery pack with the charge fill and the limit marker.
private struct BatteryPack: View {
    let charge: Int
    let limit: Int
    let color: Color
    let charging: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                NexText("BATTERY", .caption, color: NexColors.tertiary)
                Spacer()
                NexText("Limit \(limit)%", .caption, color: NexColors.secondary)
            }
            GlassPanel(
                shape: glassRect(14),
                tint: Color.black.opacity(0.24),
                surface: AnyView(
                    PhaseTimeline(cyclesPerSecond: charging ? 0.6 : 0) { phase in
                        GeometryReader { proxy in
                            let w = proxy.size.width
                            let h = proxy.size.height
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color.opacity(0.85))
                                    .frame(width: w * CGFloat(clamp01(Double(charge) / 100)), height: h)
                                if charging {
                                    // A travelling highlight along the fill.
                                    LinearGradient(
                                        colors: [.clear, Color.white.opacity(0.35), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(width: w * 0.25, height: h)
                                    .offset(x: CGFloat(phase) * w * 1.2 - w * 0.25)
                                    .blendMode(.plusLighter)
                                }
                                Rectangle()
                                    .fill(Color.white.opacity(0.75))
                                    .frame(width: 2, height: h)
                                    .offset(x: w * CGFloat(clamp01(Double(limit) / 100)) - 1)
                            }
                            .animation(GlassMotion.release, value: charge)
                        }
                    }
                )
            ) {
                Color.clear.frame(height: 28)
            }
        }
    }
}

// MARK: - Pool pump

private struct PoolPumpSheet: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository
    @State private var rpmDraft: Double = 2400

    var body: some View {
        let accent = deviceAccent(device.type)
        let running = device.isOn
        let rpm = device.pumpSpeedRpm
        let speedFraction = clamp01(Double(rpm) / maxPumpRpm)
        let color = running ? accent : idleColor
        let hours = device.pumpScheduleHours
        let gpm = (maxFlowGpm * speedFraction).rounded0
        let turnovers = Double(gpm) * 60 * Double(hours) / poolVolumeGal
        let dailyKwh = maxPumpWatts * speedFraction * Double(hours) / 1000

        VStack(spacing: 16) {
            GlassSection(
                title: "Circulation",
                symbol: "water.waves",
                accent: color,
                trailing: AnyView(
                    StatusBadge(text: pumpBadge(device), color: color, pulsing: running)
                )
            ) {
                HeroStage {
                    PoolWaterAura(color: color, running: running, speed: speedFraction)
                } content: {
                    VStack(spacing: 14) {
                        PumpImpeller(
                            rpm: rpm,
                            running: running,
                            color: color,
                            speed: speedFraction
                        )
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "drop.fill",
                                value: running ? "\(gpm) gpm" : "0 gpm",
                                label: "Flow",
                                tint: color
                            )
                            Readout(
                                symbol: "bolt.fill",
                                value: "\(repository.liveWatts(device).rounded0) W",
                                label: "Power",
                                tint: NexColors.gold
                            )
                            Readout(
                                symbol: "arrow.triangle.2.circlepath",
                                value: "\(turnovers.fixed(1))×",
                                label: "Turnovers",
                                tint: NexColors.mint
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                LiquidSegmented(
                    options: ["Eco", "Low", "Med", "High", "Max"].map { SegmentOption($0) },
                    selectedIndex: pumpPresets.indices.min {
                        abs(pumpPresets[$0] - rpm) < abs(pumpPresets[$1] - rpm)
                    } ?? 0,
                    accent: accent
                ) { index in
                    device.pumpSpeedRpm = pumpPresets[index]
                    rpmDraft = Double(pumpPresets[index])
                }
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NexColors.secondary)
                    NexText("Fine tune", .label, color: NexColors.secondary)
                    Spacer()
                    Text("\(rpm) RPM")
                        .font(NexType.bodyStrong.font.monospacedDigit())
                        .foregroundStyle(NexColors.primary)
                        .lineLimit(1)
                }
                LiquidSlider(
                    value: rpmDraft,
                    range: Double(pumpPresets[0])...Double(pumpPresets[pumpPresets.count - 1]),
                    accent: accent
                ) { value in
                    rpmDraft = value
                    device.pumpSpeedRpm = clamp(
                        Int((value / 50).rounded()) * 50,
                        pumpPresets[0],
                        pumpPresets[pumpPresets.count - 1]
                    )
                }
                NexText(
                    pumpStatusLine(device, gpm: gpm, turnovers: turnovers),
                    .label,
                    color: NexColors.secondary
                )
            }

            GlassSection(title: "Pump", symbol: "power", accent: accent) {
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: running ? "Hold to stop" : "Hold to start",
                        symbol: running ? "stop.fill" : "power",
                        accent: accent,
                        active: running,
                        size: 116,
                        sublabel: {
                            if running { return "\(rpm) RPM" }
                            if device.scheduleEnabled {
                                return "Auto at \(hourLabel(device.scheduleOnHour))"
                            }
                            return "Manual mode"
                        }()
                    ) { device.isOn.toggle() }
                    VStack(alignment: .leading, spacing: 12) {
                        SessionFact(
                            symbol: "timer",
                            value: "\(hours) h / day",
                            label: "Daily runtime",
                            tint: NexColors.cyan
                        )
                        SessionFact(
                            symbol: "humidity.fill",
                            value: "\((Double(gpm) * 60 * Double(hours) / 1000).fixed(1))k gal",
                            label: "Filtered daily",
                            tint: accent
                        )
                        SessionFact(
                            symbol: "creditcard.fill",
                            value: "$\((dailyKwh * peakRate).fixed(2))",
                            label: "Est. cost / day",
                            tint: NexColors.gold
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassSection(title: "Schedule", symbol: "calendar", accent: accent) {
                LiquidChipRow {
                    ForEach(pumpPrograms, id: \.label) { program in
                        LiquidChip(
                            label: program.label,
                            symbol: program.symbol,
                            selected: device.scheduleEnabled
                                && rpm == program.rpm
                                && hours == program.hours,
                            accent: accent
                        ) {
                            device.pumpSpeedRpm = program.rpm
                            device.pumpScheduleHours = program.hours
                            device.scheduleEnabled = true
                            rpmDraft = Double(program.rpm)
                        }
                    }
                }
                GlassSettingRow(
                    title: "Daily schedule",
                    symbol: "clock.fill",
                    subtitle: device.scheduleEnabled
                        ? "\(hourLabel(device.scheduleOnHour)) – \(hourLabel(device.scheduleOnHour + hours))"
                        : "Runs only when started manually",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.scheduleEnabled, accent: accent) {
                        device.scheduleEnabled = $0
                    }
                }
                HourTimeline(
                    bands: [
                        HourBand(
                            from: Double(device.scheduleOnHour),
                            to: Double(device.scheduleOnHour + hours),
                            color: device.scheduleEnabled
                                ? accent.opacity(0.8)
                                : Color.white.opacity(0.22)
                        ),
                    ],
                    marker: nil,
                    markerColor: accent
                )
                GlassSettingRow(title: "Start time", accent: accent) {
                    LiquidIntStepper(
                        value: device.scheduleOnHour,
                        range: 0...23,
                        format: hourLabel,
                        accent: accent
                    ) { device.scheduleOnHour = $0 }
                }
                GlassSettingRow(
                    title: "Run hours",
                    subtitle: "\(turnovers.fixed(1)) turnovers / day",
                    accent: accent
                ) {
                    LiquidIntStepper(
                        value: hours,
                        range: 1...24,
                        format: { "\($0) h" },
                        accent: accent
                    ) { device.pumpScheduleHours = $0 }
                }
            }

            GlassSection(title: "Energy", symbol: "chart.line.uptrend.xyaxis", accent: accent) {
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Power",
                        value: "\(repository.liveWatts(device).rounded0)",
                        unit: "W",
                        symbol: "bolt.fill",
                        accent: accent,
                        history: device.powerHistory
                    )
                    GlassMetricTile(
                        label: "Today",
                        value: device.energyTodayKwh.fixed(2),
                        unit: "kWh",
                        symbol: "leaf.fill",
                        accent: NexColors.mint
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Per day",
                        value: dailyKwh.fixed(1),
                        unit: "kWh",
                        symbol: "calendar.badge.clock",
                        accent: NexColors.gold
                    )
                    GlassMetricTile(
                        label: "vs. max speed",
                        value: "−\(((1 - speedFraction) * 100).rounded0)",
                        unit: "%",
                        symbol: "leaf.fill",
                        accent: NexColors.mint
                    )
                }
                NexText(
                    "Lower speeds for longer hours filter the same water for less energy.",
                    .label,
                    color: NexColors.secondary
                )
            }

            GlassSection(title: "Device", symbol: "wifi", accent: accent) {
                SignalRow(device: device, accent: accent)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.scheduleEnabled)
        .task { rpmDraft = Double(device.pumpSpeedRpm) }
    }
}

private struct PoolWaterAura: View {
    let color: Color
    let running: Bool
    let speed: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: running ? 0.12 + 0.3 * speed : 0) { phase in
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                ZStack {
                    LinearGradient(
                        colors: [color.opacity(running ? 0.18 : 0.06), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    ForEach(0..<5, id: \.self) { k in
                        Path { path in
                            let base = h * CGFloat(0.55 + 0.09 * Double(k))
                            for s in 0...20 {
                                let x = w * CGFloat(s) / 20
                                let y = base + CGFloat(
                                    sin((Double(s) / 20 * (2 + Double(k) * 0.4)
                                        + phase * (k % 2 == 0 ? 1 : -1)) * 2 * .pi)
                                ) * 5
                                if s == 0 { path.move(to: CGPoint(x: x, y: y)) } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.white.opacity(0.08 + 0.04 * Double(k % 2)), lineWidth: 1.5)
                    }
                    if running {
                        ForEach(0..<10, id: \.self) { index in
                            let seed = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
                            let t = (phase * Double(1 + index % 2) + seed)
                                .truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(Color.white.opacity(sin(t * .pi) * 0.4))
                                .frame(width: CGFloat(3 + index % 3))
                                .position(
                                    x: w * CGFloat(0.08 + 0.84 * seed),
                                    y: h * CGFloat(0.92 - 0.6 * t)
                                )
                                .blendMode(.plusLighter)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Round glass impeller: blades spin inside the glass; a centre hub shows the RPM.
private struct PumpImpeller: View {
    let rpm: Int
    let running: Bool
    let color: Color
    let speed: Double

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: Color.black.opacity(0.16),
            accent: color,
            heavy: true,
            interactive: true,
            pressScale: GlassMotion.orbPressScale,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: running ? 0.35 + 1.6 * speed : 0) { phase in
                    GeometryReader { proxy in
                        let r = min(proxy.size.width, proxy.size.height) / 2
                        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        ZStack {
                            Circle()
                                .strokeBorder(color.opacity(0.4), lineWidth: 1.5)
                                .frame(width: r * 1.75)
                                .position(center)
                            ForEach(0..<6, id: \.self) { blade in
                                BladeShape()
                                    .fill(Color.white.opacity(running ? 0.55 : 0.25))
                                    .frame(width: r * 0.36, height: r * 0.8)
                                    .offset(y: -r * 0.42)
                                    .rotationEffect(
                                        .degrees(phase * 360 + Double(blade) * 60)
                                    )
                                    .position(center)
                            }
                        }
                    }
                }
            )
        ) {
            GlassPanel(shape: glassCircle, tint: Color.black.opacity(0.14), heavy: true) {
                VStack(spacing: 0) {
                    Text("\(rpm)")
                        .font(NexType.title.font.monospacedDigit())
                        .foregroundStyle(NexColors.primary)
                        .lineLimit(1)
                    NexText(running ? "RPM" : "IDLE", .caption, color: NexColors.tertiary)
                        .lineLimit(1)
                }
                .frame(width: 92, height: 92)
            }
            .frame(width: 196, height: 196)
        }
    }
}

private struct BladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.midY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.midY)
            )
            path.closeSubpath()
        }
    }
}

// MARK: - Sprinklers (ControlKind.sprinklerZones)

/// Sprinkler sheet: a glass zone grid over a misty yard stage (tap a tile to water that zone;
/// running tiles fill with rippling water), a run-all sequence bar and hold orb, per-zone run
/// times, rain delay and smart skip with a soil-moisture gauge, and a weekly water-use chart.
struct SprinklerControls: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let accent = deviceAccent(device.type)
        let zones = device.sprinklerZones
        let runningIndex = zones.firstIndex { $0.running } ?? -1
        let watering = runningIndex >= 0
        let delayed = device.rainDelayHours > 0
        let statusColor: Color = watering ? accent : (delayed ? rainColor : idleColor)
        let totalMinutes = zones.reduce(0) { $0 + $1.durationMinutes }

        VStack(spacing: 16) {
            GlassSection(
                title: "Zones",
                symbol: "leaf.fill",
                accent: statusColor,
                trailing: AnyView(
                    StatusBadge(
                        text: sprinklerBadge(device, runningIndex: runningIndex),
                        color: statusColor,
                        pulsing: watering
                    )
                )
            ) {
                if zones.isEmpty {
                    NexText("No zones configured on this controller.", .body, color: NexColors.secondary)
                } else {
                    GlassPanel(
                        shape: glassRect(24),
                        tint: Color.black.opacity(0.14),
                        heavy: true,
                        surface: AnyView(MistAura(color: statusColor, watering: watering))
                    ) {
                        VStack(spacing: 10) {
                            ForEach(Array(stride(from: 0, to: zones.count, by: 2)), id: \.self) { start in
                                HStack(spacing: 10) {
                                    ForEach(start..<min(start + 2, zones.count), id: \.self) { index in
                                        ZoneTile(
                                            zone: zones[index],
                                            index: index,
                                            accent: accent
                                        ) {
                                            repository.setZoneRunning(
                                                device,
                                                index: index,
                                                running: !zones[index].running
                                            )
                                        }
                                    }
                                    if min(start + 2, zones.count) - start == 1 {
                                        Color.clear.frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                    HStack {
                        NexText(
                            device.sprinklerRunAll ? "RUN-ALL SEQUENCE" : "ZONE LENGTHS",
                            .caption,
                            color: NexColors.tertiary
                        )
                        Spacer()
                        NexText("\(totalMinutes) min", .caption, color: NexColors.secondary)
                    }
                    SequenceBar(zones: zones, runAll: device.sprinklerRunAll, accent: accent)
                }
                NexText(
                    sprinklerStatusLine(device, runningIndex: runningIndex, totalMinutes: totalMinutes),
                    .label,
                    color: NexColors.secondary
                )
            }

            GlassSection(title: "Watering", symbol: "drop.fill", accent: accent) {
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: watering ? "Hold to stop" : "Hold to run all",
                        symbol: watering ? "stop.fill" : "drop.fill",
                        accent: accent,
                        active: watering,
                        size: 116,
                        sublabel: {
                            if watering && device.sprinklerRunAll {
                                return "Sequence · zone \(runningIndex + 1)/\(zones.count)"
                            }
                            if watering { return "Zone \(runningIndex + 1) on" }
                            return "\(zones.count) zones · \(totalMinutes) min"
                        }(),
                        enabled: !zones.isEmpty
                    ) {
                        repository.runAllZones(device, !watering)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SessionFact(
                            symbol: "timer",
                            value: "\(totalMinutes) min",
                            label: "Full cycle",
                            tint: NexColors.cyan
                        )
                        SessionFact(
                            symbol: "drop.fill",
                            value: "≈ \((Double(totalMinutes) * gallonsPerMinute).rounded0) gal",
                            label: "Per cycle",
                            tint: accent
                        )
                        SessionFact(
                            symbol: "clock.fill",
                            value: {
                                if delayed { return "Paused \(device.rainDelayHours) h" }
                                if device.scheduleEnabled { return hourLabel(device.scheduleOnHour) }
                                return "Manual"
                            }(),
                            label: "Next run",
                            tint: delayed ? rainColor : NexColors.mint
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassSettingRow(
                    title: "Daily schedule",
                    symbol: "calendar",
                    subtitle: device.scheduleEnabled
                        ? "Every day at \(hourLabel(device.scheduleOnHour))"
                        : "Water only when started",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.scheduleEnabled, accent: accent) {
                        device.scheduleEnabled = $0
                    }
                }
                if device.scheduleEnabled {
                    GlassSettingRow(
                        title: "Start time",
                        subtitle: "Before sunrise cuts evaporation",
                        accent: accent
                    ) {
                        LiquidIntStepper(
                            value: device.scheduleOnHour,
                            range: 0...23,
                            format: hourLabel,
                            accent: accent
                        ) { device.scheduleOnHour = $0 }
                    }
                }
            }

            if !zones.isEmpty {
                GlassSection(
                    title: "Run times",
                    symbol: "timer",
                    accent: accent,
                    trailing: AnyView(
                        NexText("\(totalMinutes) min total", .caption, color: NexColors.tertiary)
                            .lineLimit(1)
                    )
                ) {
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        let remaining = Int(
                            (Double(zone.durationMinutes) * (1 - zone.progress)).rounded(.up)
                        )
                        GlassSettingRow(
                            title: zone.name,
                            subtitle: zone.running
                                ? "Watering · \(remaining)m left"
                                : "Zone \(index + 1) · ≈ \((Double(zone.durationMinutes) * gallonsPerMinute).rounded0) gal",
                            accent: accent
                        ) {
                            LiquidIntStepper(
                                value: zone.durationMinutes,
                                range: 1...60,
                                format: { "\($0) min" },
                                accent: accent
                            ) { zone.durationMinutes = $0 }
                        }
                    }
                }
            }

            GlassSection(title: "Weather", symbol: "cloud.fill", accent: rainColor) {
                NexText("Rain delay", .label, color: NexColors.secondary)
                LiquidSegmented(
                    options: [
                        SegmentOption("Off", "sun.max.fill"),
                        SegmentOption("24h", "umbrella.fill"),
                        SegmentOption("48h", "cloud.fill"),
                        SegmentOption("72h", "cloud.bolt.rain.fill"),
                    ],
                    selectedIndex: max(rainDelaySteps.firstIndex(of: device.rainDelayHours) ?? 0, 0),
                    accent: rainColor
                ) { index in
                    device.rainDelayHours = rainDelaySteps[index]
                    if rainDelaySteps[index] > 0,
                       device.sprinklerZones.contains(where: { $0.running }) {
                        repository.runAllZones(device, false)
                    }
                }
                NexText(
                    delayed
                        ? "Scheduled watering paused for \(device.rainDelayHours) hours"
                        : "Watering follows the schedule",
                    .label,
                    color: NexColors.secondary
                )
                GlassSettingRow(
                    title: "Smart weather skip",
                    symbol: "cloud.bolt.rain.fill",
                    subtitle: device.smartWeatherSkip
                        ? "Skips runs when rain or frost is forecast"
                        : "Always runs on schedule",
                    accent: rainColor
                ) {
                    LiquidToggle(isOn: device.smartWeatherSkip, accent: rainColor) {
                        device.smartWeatherSkip = $0
                    }
                }
                SoilMoistureGauge(percent: device.soilMoisturePercent)
            }

            let usage = device.waterUsageHistory
            let week = usage.reduce(0, +)
            let today = usage.last ?? 0
            let average = usage.isEmpty ? 0 : week / Double(usage.count)
            GlassSection(title: "Water use", symbol: "chart.line.uptrend.xyaxis", accent: accent) {
                HourlyUsageBars(history: usage, accent: accent)
                    .frame(height: 120)
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "This week",
                        value: "\(week.rounded0)",
                        unit: "gal",
                        symbol: "drop.fill",
                        accent: accent,
                        history: usage
                    )
                    GlassMetricTile(
                        label: "Today",
                        value: "\(today.rounded0)",
                        unit: "gal",
                        symbol: "drop.fill",
                        accent: rainColor
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Daily avg",
                        value: "\(average.rounded0)",
                        unit: "gal",
                        symbol: "calendar.badge.clock",
                        accent: NexColors.cyan
                    )
                    GlassMetricTile(
                        label: "Est. saved",
                        value: "\(device.smartWeatherSkip ? (week * 0.18).rounded0 : 0)",
                        unit: "gal",
                        symbol: "leaf.fill",
                        accent: NexColors.mint
                    )
                }
            }

            GlassSection(title: "Controller", symbol: "wifi", accent: accent) {
                SignalRow(device: device, accent: accent)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.scheduleEnabled)
    }
}

private struct MistAura: View {
    let color: Color
    let watering: Bool

    var body: some View {
        PhaseTimeline(cyclesPerSecond: watering ? 0.9 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    RadialGradient(
                        colors: [color.opacity(watering ? 0.2 : 0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.7
                    )
                    .blendMode(.plusLighter)
                    if watering {
                        ForEach(0..<16, id: \.self) { index in
                            let seed = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
                            let t = (phase * Double(1 + index % 3) + seed)
                                .truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(Color.white.opacity(sin(t * .pi) * 0.3))
                                .frame(width: CGFloat(4 + index % 4))
                                .position(
                                    x: size.width * CGFloat(0.06 + 0.88 * seed),
                                    y: size.height * CGFloat(1 - t)
                                )
                                .blendMode(.plusLighter)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// One zone as a glass tile. Running tiles fill with rippling water to the zone's progress.
private struct ZoneTile: View {
    @Bindable var zone: SprinklerZone
    let index: Int
    let accent: Color
    let action: () -> Void

    var body: some View {
        let running = zone.running
        let remaining = Int((Double(zone.durationMinutes) * (1 - zone.progress)).rounded(.up))

        GlassPanel(
            shape: glassRect(22),
            tint: NexColors.glassTintLight,
            accent: accent,
            action: action,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: running ? 0.9 : 0) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        if running {
                            let level = h * CGFloat(1 - clamp01(zone.progress))
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: h))
                                for s in 0...14 {
                                    let x = w * CGFloat(s) / 14
                                    let y = level + CGFloat(
                                        sin((Double(s) / 14 * 1.8 + phase + Double(index) * 0.3) * 2 * .pi)
                                    ) * 4
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                path.addLine(to: CGPoint(x: w, y: h))
                                path.closeSubpath()
                            }
                            .fill(accent.opacity(0.45))
                        }
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: running ? "drop.fill" : "leaf.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(running ? .white : accent)
                    Spacer()
                    if running {
                        NexText("\(remaining)m", .caption, color: .white).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                NexText(zone.name, .bodyStrong).lineLimit(1)
                NexText(
                    running ? "Watering" : "\(zone.durationMinutes) min",
                    .caption,
                    color: running ? .white : NexColors.tertiary
                )
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 124)
            .padding(12)
        }
    }
}

/// The run-all sequence: each zone's share of the cycle, the running one lit.
private struct SequenceBar: View {
    let zones: [SprinklerZone]
    let runAll: Bool
    let accent: Color

    var body: some View {
        let total = max(zones.reduce(0) { $0 + $1.durationMinutes }, 1)
        GlassPanel(shape: glassCapsule, tint: Color.black.opacity(0.22)) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(zones) { zone in
                        Rectangle()
                            .fill(
                                zone.running
                                    ? accent
                                    : (runAll ? accent.opacity(0.3) : Color.white.opacity(0.14))
                            )
                            .frame(
                                width: max(
                                    proxy.size.width * CGFloat(Double(zone.durationMinutes) / Double(total)) - 2,
                                    2
                                )
                            )
                    }
                }
                .frame(height: 20)
            }
            .frame(height: 20)
        }
    }
}

/// Soil moisture with the ideal band marked.
private struct SoilMoistureGauge: View {
    let percent: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "humidity.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(moistureColor(percent))
                NexText("Soil moisture", .label, color: NexColors.secondary)
                Spacer()
                Text("\(percent)% · \(moistureLabel(percent))")
                    .font(NexType.bodyStrong.font.monospacedDigit())
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
            }
            GlassPanel(
                shape: glassCapsule,
                tint: Color.black.opacity(0.22),
                surface: AnyView(
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        ZStack(alignment: .leading) {
                            // Ideal band.
                            Rectangle()
                                .fill(NexColors.mint.opacity(0.22))
                                .frame(width: w * CGFloat(idealHigh - idealLow), height: h)
                                .offset(x: w * CGFloat(idealLow))
                            Capsule()
                                .fill(moistureColor(percent))
                                .frame(width: w * CGFloat(clamp01(Double(percent) / 100)), height: h * 0.55)
                                .offset(y: h * 0.22)
                        }
                        .animation(GlassMotion.release, value: percent)
                    }
                )
            ) {
                Color.clear.frame(height: 20)
            }
        }
    }
}

// MARK: - Shared outdoor pieces

struct HourBand {
    let from: Double
    let to: Double
    let color: Color
}

/// A 24 h strip with coloured bands (peak, off-peak, run window) and an optional marker.
struct HourTimeline: View {
    let bands: [HourBand]
    let marker: Double?
    let markerColor: Color

    private static let labels = ["12a", "6a", "12p", "6p", "12a"]

    var body: some View {
        GlassPanel(
            shape: glassRect(18),
            tint: NexColors.glassTintDark,
            surface: AnyView(
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let pad: CGFloat = 14
                    let span = max(w - pad * 2, 1)
                    let top: CGFloat = 14
                    let barHeight: CGFloat = 12
                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: span, height: barHeight)
                            .offset(x: pad, y: top)
                        ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                            // Bands may wrap past midnight (to > 24).
                            let from = band.from / 24
                            let to = min(band.to, 24) / 24
                            if to > from {
                                Capsule()
                                    .fill(band.color)
                                    .frame(width: span * CGFloat(to - from), height: barHeight)
                                    .offset(x: pad + span * CGFloat(from), y: top)
                            }
                            if band.to > 24 {
                                let wrapped = (band.to - 24) / 24
                                Capsule()
                                    .fill(band.color)
                                    .frame(width: span * CGFloat(wrapped), height: barHeight)
                                    .offset(x: pad, y: top)
                            }
                        }
                        if let marker {
                            Capsule()
                                .fill(markerColor)
                                .frame(width: 2.5, height: barHeight + 10)
                                .offset(x: pad + span * CGFloat(marker / 24) - 1, y: top - 5)
                        }
                    }
                }
            )
        ) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    ForEach(Self.labels, id: \.self) { label in
                        NexText(label, .caption, color: NexColors.tertiary).lineLimit(1)
                        if label != Self.labels.last { Spacer() }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9)
            NexText(label, .caption, color: NexColors.secondary).lineLimit(1)
        }
    }
}

/// Icon + value/label pair placed beside hold orbs.
struct SessionFact: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(NexType.bodyStrong.font.monospacedDigit())
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
                NexText(label, .caption, color: NexColors.tertiary).lineLimit(1)
            }
        }
    }
}

struct SignalRow: View {
    let device: Device
    let accent: Color

    private static let labels = ["No signal", "Weak", "Fair", "Good", "Excellent"]

    var body: some View {
        GlassSettingRow(
            title: "Connection",
            symbol: "wifi",
            subtitle: device.isOnline
                ? "\(Self.labels[clamp(device.signalStrength, 0, 4)]) · \(device.firmwareVersion)"
                : "Offline",
            accent: accent
        ) {
            SignalBars(strength: device.signalStrength, accent: accent)
        }
    }
}

// MARK: - Outdoor helpers

private let offPeakColor = NexColors.indigo
private let rainColor = Color(hex: 0x7FB8FF)
private let dryColor = NexColors.amber
private let wetColor = Color(hex: 0x7FB8FF)
private let idealColor = NexColors.mint

private let kwPerAmp = 0.24
private let evBatteryKwh = 75.0
private let peakRate = 0.28
private let offPeakRate = 0.14
private let gallonsPerMinute = 2.5
private let milesPerKwh = 3.6
private let maxPumpRpm = 3450.0
private let maxPumpWatts = 1100.0
private let maxFlowGpm = 80.0
private let poolVolumeGal = 20000.0
private let idealLow = 0.35
private let idealHigh = 0.65

private let pumpPresets = [1200, 1800, 2400, 3000, 3450]
private let rainDelaySteps = [0, 24, 48, 72]

private struct EvLimitPreset {
    let percent: Int
    let label: String
    let symbol: String
}

private let evLimitPresets = [
    EvLimitPreset(percent: 70, label: "Battery care", symbol: "leaf.fill"),
    EvLimitPreset(percent: 80, label: "Daily", symbol: "car.side.and.exclamationmark"),
    EvLimitPreset(percent: 90, label: "Road trip", symbol: "road.lanes"),
    EvLimitPreset(percent: 100, label: "Full", symbol: "battery.100.bolt"),
]

private struct PumpProgram {
    let label: String
    let rpm: Int
    let hours: Int
    let symbol: String
}

private let pumpPrograms = [
    PumpProgram(label: "Eco · 10 h", rpm: 1200, hours: 10, symbol: "leaf.fill"),
    PumpProgram(label: "Balanced · 8 h", rpm: 2400, hours: 8, symbol: "arrow.triangle.2.circlepath"),
    PumpProgram(label: "Deep clean · 6 h", rpm: 3450, hours: 6, symbol: "speedometer"),
    PumpProgram(label: "Night quiet · 12 h", rpm: 1800, hours: 12, symbol: "moon.stars.fill"),
]

private struct PastSession {
    let day: String
    let kwh: Double
    let offPeak: Bool
    let minutes: Int
}

private func pastSessions(for device: Device) -> [PastSession] {
    var random = SeededRandom(seed: UInt64(bitPattern: Int64(device.id.hashValue)))
    return ["Yesterday", "2 days ago", "4 days ago"].map { day in
        let kwh = 8 + random.nextDouble() * 34
        return PastSession(
            day: day,
            kwh: kwh,
            offPeak: random.chance(0.6),
            minutes: (kwh / 7.7 * 60).rounded0
        )
    }
}

private func shortDuration(_ minutes: Int) -> String {
    if minutes <= 0 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return "\(minutes / 60)h \(minutes % 60)m"
}

private func evStateColor(_ device: Device, _ accent: Color) -> Color {
    if device.isCharging { return accent }
    if !device.plugConnected { return idleColor }
    if device.chargePercent >= device.chargeLimitPercent { return NexColors.cyan }
    return NexColors.amber
}

private func evBadge(_ device: Device) -> String {
    if device.isCharging { return "Charging" }
    if !device.plugConnected { return "Unplugged" }
    if device.chargePercent >= device.chargeLimitPercent { return "Complete" }
    if device.offPeakScheduling { return "Waiting" }
    return "Plugged in"
}

private func evDialCaption(_ device: Device) -> String {
    if device.isCharging { return "CHARGING TO \(device.chargeLimitPercent)%" }
    if !device.plugConnected { return "NOT CONNECTED" }
    if device.chargePercent >= device.chargeLimitPercent { return "LIMIT REACHED" }
    return "READY TO CHARGE"
}

private func evEta(_ device: Device) -> String {
    let remaining = max(device.chargeLimitPercent - device.chargePercent, 0)
    if remaining == 0 { return "At limit" }
    let kw = max(Double(device.chargeAmps) * kwPerAmp, 0.1)
    let hours = Double(remaining) / 100 * evBatteryKwh / kw
    return shortDuration((hours * 60).rounded0)
}

private func evStatusLine(_ device: Device) -> String {
    let kw = Double(device.chargeAmps) * kwPerAmp
    if !device.plugConnected {
        let name = device.vehicleName.isEmpty ? "your EV" : device.vehicleName
        return "Plug in \(name) to start a session"
    }
    if device.isCharging {
        return "Adding ≈ \((kw * milesPerKwh).rounded0) mi of range per hour"
    }
    if device.chargePercent >= device.chargeLimitPercent {
        return "Charged to your \(device.chargeLimitPercent)% limit"
    }
    if device.offPeakScheduling { return "Waiting for off-peak rates at 11 PM" }
    return "Ready · hold the orb to start charging"
}

private func ampsLabel(_ amps: Int) -> String {
    if amps <= 16 { return "gentle" }
    if amps <= 32 { return "standard" }
    return "fast"
}

private func pumpBadge(_ device: Device) -> String {
    if device.isOn { return "Running" }
    return device.scheduleEnabled ? "Scheduled" : "Off"
}

private func pumpStatusLine(_ device: Device, gpm: Int, turnovers: Double) -> String {
    if device.isOn {
        return "Circulating \(gpm) gpm · filters the pool \(turnovers.fixed(1))× a day"
    }
    if device.scheduleEnabled {
        return "Off · next run at \(hourLabel(device.scheduleOnHour)) for \(device.pumpScheduleHours) h"
    }
    return "Off · manual mode"
}

private func sprinklerBadge(_ device: Device, runningIndex: Int) -> String {
    if runningIndex >= 0 { return "Zone \(runningIndex + 1)" }
    if device.rainDelayHours > 0 { return "Rain delay" }
    return "Idle"
}

private func sprinklerStatusLine(_ device: Device, runningIndex: Int, totalMinutes: Int) -> String {
    if device.sprinklerZones.indices.contains(runningIndex) {
        let zone = device.sprinklerZones[runningIndex]
        let left = Int((Double(zone.durationMinutes) * (1 - zone.progress)).rounded(.up))
        let base = "Watering \(zone.name) · \(left)m left"
        return device.sprinklerRunAll ? base + " · sequence running" : base
    }
    if device.rainDelayHours > 0 {
        return "Paused by a \(device.rainDelayHours) h rain delay · tap a zone to water anyway"
    }
    return "Tap a zone to water it · a full cycle takes \(totalMinutes) min"
}

private func moistureColor(_ percent: Int) -> Color {
    if Double(percent) < idealLow * 100 { return dryColor }
    if Double(percent) > idealHigh * 100 { return wetColor }
    return idealColor
}

private func moistureLabel(_ percent: Int) -> String {
    if Double(percent) < idealLow * 100 { return "Dry" }
    if Double(percent) > idealHigh * 100 { return "Wet" }
    return "Ideal"
}
