import SwiftUI

// MARK: - Sensors (ControlKind.sensorReadonly)

/// Sensor sheets, one per type: motion gets a radar stage, contact a swinging glass doorway, smoke
/// and CO a breathing air chamber around a read-only level dial with a hold-to-test siren, leak a
/// rising water line with an auto shut-off valve, and climate twin dials plus a comfort map.
struct SensorControls: View {
    @Bindable var device: Device

    var body: some View {
        let accent = deviceAccent(device.type)
        VStack(spacing: 16) {
            switch device.type {
            case .motionSensor: MotionSensorSheet(device: device, accent: accent)
            case .contactSensor: ContactSensorSheet(device: device, accent: accent)
            case .smokeDetector, .coDetector: AlarmDetectorSheet(device: device, accent: accent)
            case .leakSensor: LeakSensorSheet(device: device, accent: accent)
            case .climateSensor: ClimateSensorSheet(device: device, accent: accent)
            default: GenericSensorSheet(device: device, accent: accent)
            }
            SensorHealthSection(device: device, accent: accent)
        }
    }
}

// MARK: - Motion sensor

private struct MotionSensorSheet: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let monitoring = device.isOn
        let motion = monitoring && device.sensorValue == svMotion
        let history = device.sensorHistory
        let total = history.reduce(0, +).rounded0
        let busiest = busiestIndex(history)
        let nowHour = Calendar.current.component(.hour, from: .now)
        let rangeMeters = (4 + 8 * device.sensitivity).rounded0
        let roomLights = repository.devices(in: device.room).filter { $0.controlKind == .dimmer }

        GlassSection(
            title: "Live detection",
            symbol: "dot.radiowaves.left.and.right",
            accent: accent,
            trailing: AnyView(
                StatusBadge(
                    text: !monitoring ? "Paused" : (motion ? "Motion" : "Watching"),
                    color: !monitoring ? NexColors.tertiary : (motion ? accent : NexColors.mint),
                    pulsing: motion
                )
            )
        ) {
            MotionRadarStage(accent: accent, motion: motion, monitoring: monitoring, sensitivity: device.sensitivity)
                .frame(height: 190)
            HStack(spacing: 0) {
                Readout(
                    symbol: "clock.arrow.circlepath",
                    value: sensorAgo(device.lastEventMinutesAgo),
                    label: "Last motion",
                    tint: accent
                )
                Readout(symbol: "chart.bar.fill", value: "\(total)", label: "Events 24h", tint: accent)
                Readout(
                    symbol: "dot.radiowaves.left.and.right",
                    value: "~\(rangeMeters) m",
                    label: "Range",
                    tint: accent
                )
            }
        }

        GlassSection(title: "Sensitivity", symbol: "slider.horizontal.3", accent: accent) {
            LiquidSegmented(
                options: [
                    SegmentOption("Low", "pawprint.fill"),
                    SegmentOption("Medium", "figure.walk"),
                    SegmentOption("High", "figure.run"),
                ],
                selectedIndex: sensitivityPreset(device.sensitivity),
                accent: accent
            ) { device.sensitivity = sensitivityPresets[$0] }
            HStack {
                NexText("Fine tune", .bodyStrong).lineLimit(1)
                Spacer()
                Text("\((device.sensitivity * 100).rounded0)%")
                    .font(NexType.bodyStrong.font.monospacedDigit())
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            LiquidSlider(value: device.sensitivity, accent: accent) {
                device.sensitivity = clamp01($0)
            }
            NexText(sensitivityHint(device.sensitivity), .caption, color: NexColors.tertiary)
        }

        GlassSection(
            title: "Last 24 hours",
            symbol: "chart.bar.fill",
            accent: accent,
            trailing: AnyView(
                NexText("\(total) events", .caption, color: NexColors.tertiary).lineLimit(1)
            )
        ) {
            SensorHourBars(history: history, color: accent, live: motion)
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Busiest hour",
                    value: busiest < 0 ? "—" : sensorHourLabel(nowHour - (history.count - 1 - busiest)),
                    symbol: "chart.line.uptrend.xyaxis",
                    accent: accent
                )
                GlassMetricTile(
                    label: "This hour",
                    value: "\((history.last ?? 0).rounded0)",
                    unit: "events",
                    symbol: "waveform.path.ecg",
                    accent: accent
                )
            }
        }

        GlassSection(title: "Automations", symbol: "sparkles", accent: accent) {
            GlassSettingRow(
                title: "Lights follow motion",
                symbol: "lightbulb.fill",
                subtitle: roomLights.isEmpty
                    ? "No lights in \(device.room.displayName)"
                    : "\(roomLights.count) \(roomLights.count == 1 ? "light" : "lights") in \(device.room.displayName)",
                accent: NexColors.amber
            ) {
                if !roomLights.isEmpty {
                    LiquidToggle(
                        isOn: roomLights.allSatisfy { $0.motionActivated },
                        accent: NexColors.amber
                    ) { on in
                        for light in roomLights { light.motionActivated = on }
                    }
                }
            }
            GlassSettingRow(
                title: "Chime on motion",
                symbol: "bell.badge.fill",
                subtitle: "Soft chime on nearby speakers",
                accent: accent
            ) {
                LiquidToggle(isOn: device.chimeEnabled, accent: accent) { device.chimeEnabled = $0 }
            }
            QuietHoursRows(device: device, mutedWhat: "motion alerts muted")
        }

        if !roomLights.isEmpty {
            GlassSection(
                title: "Lights in \(device.room.displayName)",
                symbol: "lightbulb.fill",
                accent: NexColors.amber
            ) {
                ForEach(roomLights.prefix(4)) { light in
                    GlassSettingRow(
                        title: light.name,
                        symbol: light.type.symbol,
                        subtitle: light.isOn
                            ? "\((light.brightness * 100).rounded0)% · \(light.motionActivated ? "motion armed" : "manual")"
                            : "Off",
                        accent: deviceAccent(light.type)
                    ) {
                        LiquidToggle(isOn: light.isOn, accent: deviceAccent(light.type)) {
                            light.isOn = $0
                        }
                    }
                }
            }
        }

        RecentEventsSection(
            history: history,
            nowHour: nowHour,
            accent: accent,
            symbol: "figure.walk.motion",
            emptyText: "No motion in the last 24 hours.",
            title: { $0 == 1 ? "1 detection" : "\($0) detections" }
        )
    }
}

/// Radar fan with range rings and a sweep while motion is live; reach follows sensitivity.
private struct MotionRadarStage: View {
    let accent: Color
    let motion: Bool
    let monitoring: Bool
    let sensitivity: Double

    var body: some View {
        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.16),
            accent: accent,
            heavy: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: monitoring ? (motion ? 0.6 : 0.18) : 0) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        let origin = CGPoint(x: w / 2, y: h - 18)
                        let reach = h * 0.82
                        let half: Double = 60
                        ZStack {
                            ForEach(1..<4, id: \.self) { ring in
                                Path { path in
                                    path.addArc(
                                        center: origin,
                                        radius: reach * CGFloat(ring) / 3,
                                        startAngle: .degrees(-90 - half),
                                        endAngle: .degrees(-90 + half),
                                        clockwise: false
                                    )
                                }
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            }
                            Path { path in
                                path.move(to: origin)
                                path.addArc(
                                    center: origin,
                                    radius: reach * CGFloat(0.35 + 0.65 * sensitivity),
                                    startAngle: .degrees(-90 - half),
                                    endAngle: .degrees(-90 + half),
                                    clockwise: false
                                )
                                path.closeSubpath()
                            }
                            .fill(accent.opacity(monitoring ? 0.16 : 0.05))
                            .animation(.spring(response: 0.444, dampingFraction: 0.45), value: sensitivity)
                            if monitoring {
                                let a = -90 - half + 2 * half * phase
                                Path { path in
                                    path.move(to: origin)
                                    path.addLine(
                                        to: CGPoint(
                                            x: origin.x + cos(radians(a)) * reach,
                                            y: origin.y + sin(radians(a)) * reach
                                        )
                                    )
                                }
                                .stroke(accent.opacity(motion ? 0.8 : 0.4), lineWidth: 2)
                            }
                            if motion {
                                ForEach(0..<3, id: \.self) { k in
                                    let t = (phase + Double(k) * 0.33).truncatingRemainder(dividingBy: 1)
                                    Circle()
                                        .strokeBorder(accent.opacity(0.5 * (1 - t)), lineWidth: 2)
                                        .frame(width: 24 + CGFloat(t) * reach)
                                        .position(origin)
                                }
                            }
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 10).position(origin)
                        }
                    }
                }
            )
        ) {
            VStack {
                HStack {
                    NexText("120° coverage", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText(
                        monitoring ? (motion ? "Motion now" : "Clear") : "Paused",
                        .caption,
                        color: motion ? accent : NexColors.tertiary
                    )
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
        }
    }
}

// MARK: - Contact sensor

private struct ContactSensorSheet: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let monitoring = device.isOn
        let open = device.sensorValue == svOpen
        let history = device.sensorHistory
        let total = history.reduce(0, +).rounded0
        let busiest = busiestIndex(history)
        let nowHour = Calendar.current.component(.hour, from: .now)
        let panel = repository.devices(ofKind: .securityPanel).first

        GlassSection(
            title: "Contact",
            symbol: "door.left.hand.open",
            accent: accent,
            trailing: AnyView(
                StatusBadge(
                    text: !monitoring ? "Paused" : (open ? "Open" : "Secure"),
                    color: !monitoring ? NexColors.tertiary : (open ? NexColors.amber : NexColors.mint),
                    pulsing: open && monitoring
                )
            )
        ) {
            ContactDoorStage(accent: accent, open: open)
                .frame(height: 170)
            HStack(spacing: 0) {
                Readout(
                    symbol: "clock.arrow.circlepath",
                    value: sensorAgo(device.lastEventMinutesAgo),
                    label: open ? "Opened" : "Closed",
                    tint: accent
                )
                Readout(symbol: "chart.bar.fill", value: "\(total)", label: "Opens 24h", tint: accent)
                Readout(
                    symbol: device.chimeEnabled ? "bell.badge.fill" : "bell.slash.fill",
                    value: device.chimeEnabled ? "On" : "Off",
                    label: "Chime",
                    tint: accent
                )
            }
        }

        GlassSection(title: "Alerts", symbol: "bell.badge.fill", accent: accent) {
            GlassSettingRow(
                title: "Chime when opened",
                symbol: device.chimeEnabled ? "bell.badge.fill" : "bell.slash.fill",
                subtitle: device.chimeEnabled ? "Ding-dong on every opening" : "Silent",
                accent: accent
            ) {
                LiquidToggle(isOn: device.chimeEnabled, accent: accent) { device.chimeEnabled = $0 }
            }
            QuietHoursRows(device: device, mutedWhat: "chime muted")
            if let panel {
                let armed = panel.alarmState != .disarmed
                GlassSettingRow(
                    title: panel.name,
                    symbol: "shield.fill",
                    subtitle: "\(panel.alarmState.displayName) · entry delay \(panel.entryDelaySeconds)s",
                    accent: deviceAccent(panel.type)
                ) {
                    LiquidButton(
                        tint: armed ? deviceAccent(panel.type) : nil,
                        action: { repository.armSecurity(panel, armed ? .disarmed : .armedHome) }
                    ) {
                        NexText(armed ? "Disarm" : "Arm home", .label).lineLimit(1)
                    }
                }
            }
        }

        GlassSection(
            title: "Openings · 24 hours",
            symbol: "chart.bar.fill",
            accent: accent,
            trailing: AnyView(
                NexText("\(total) total", .caption, color: NexColors.tertiary).lineLimit(1)
            )
        ) {
            SensorHourBars(history: history, color: accent, live: open && monitoring)
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Busiest hour",
                    value: busiest < 0 ? "—" : sensorHourLabel(nowHour - (history.count - 1 - busiest)),
                    symbol: "chart.line.uptrend.xyaxis",
                    accent: accent
                )
                GlassMetricTile(
                    label: open ? "Open for" : "Closed for",
                    value: sensorDuration(device.lastEventMinutesAgo),
                    symbol: "waveform.path.ecg",
                    accent: open ? NexColors.amber : accent
                )
            }
        }

        RecentEventsSection(
            history: history,
            nowHour: nowHour,
            accent: accent,
            symbol: "door.left.hand.open",
            emptyText: "No openings in the last 24 hours.",
            title: { $0 == 1 ? "Opened once" : "Opened \($0) times" }
        )
    }
}

/// A glass doorway whose leaf swings with the contact state; magnets link when shut.
private struct ContactDoorStage: View {
    let accent: Color
    let open: Bool

    var body: some View {
        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.14),
            accent: accent,
            heavy: true,
            surface: AnyView(
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let hingeX = w * 0.28
                    let hingeY = h * 0.82
                    let leaf = w * 0.4
                    ZStack {
                        // Frame.
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.2, y: hingeY))
                            path.addLine(to: CGPoint(x: w * 0.8, y: hingeY))
                            path.move(to: CGPoint(x: w * 0.2, y: hingeY))
                            path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.2))
                            path.move(to: CGPoint(x: w * 0.8, y: hingeY))
                            path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.2))
                        }
                        .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                        // The leaf.
                        Capsule()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: leaf, height: 8)
                            .offset(x: leaf / 2)
                            .rotationEffect(.degrees(open ? -58 : 0), anchor: .leading)
                            .position(x: hingeX, y: hingeY)

                        // Magnet pair.
                        ZStack {
                            Circle()
                                .fill(open ? NexColors.amber : NexColors.mint)
                                .frame(width: 10)
                                .offset(x: -6)
                            Circle()
                                .fill(open ? NexColors.amber.opacity(0.5) : NexColors.mint)
                                .frame(width: 10)
                                .offset(x: 6)
                            if !open {
                                Capsule()
                                    .fill(NexColors.mint.opacity(0.7))
                                    .frame(width: 14, height: 3)
                                    .blendMode(.plusLighter)
                            }
                        }
                        .position(x: w * 0.8 - 10, y: hingeY - 30)
                    }
                }
                .animation(.spring(response: 0.574, dampingFraction: 0.45), value: open)
            )
        ) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    NexText(open ? "Contact broken" : "Magnets aligned", .caption, color: NexColors.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
        }
    }
}

// MARK: - Smoke / CO detector

private struct AlarmDetectorSheet: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository
    @State private var testTask: Task<Void, Never>?

    var body: some View {
        let isCo = device.type == .coDetector
        let alarm = device.sensorValue == svSmoke || device.sensorValue == svCo
        let testing = device.sensorValue == svTesting
        let danger = alarm || testing
        let warnAt: Double = isCo ? 35 : 25
        let reading = device.sensorNumeric
        let history = device.sensorHistory
        let peak = history.max() ?? 0
        let average = history.isEmpty ? 0 : history.reduce(0, +) / Double(history.count)
        let statusColor: Color = danger
            ? NexColors.red
            : (reading >= warnAt ? NexColors.amber : NexColors.mint)
        let statusText: String = {
            if testing { return "Testing" }
            if alarm { return isCo ? "CO alarm" : "Smoke alarm" }
            return reading >= warnAt ? "Elevated" : "All clear"
        }()
        let peers = repository.devices(ofKind: .sensorReadonly).filter {
            ($0.type == .smokeDetector || $0.type == .coDetector) && $0.id != device.id
        }

        GlassSection(
            title: isCo ? "Carbon monoxide" : "Smoke",
            symbol: isCo ? "carbon.dioxide.cloud.fill" : "flame.fill",
            accent: accent,
            trailing: AnyView(StatusBadge(text: statusText, color: statusColor, pulsing: danger))
        ) {
            DetectorStage(
                danger: danger,
                testing: testing,
                isCo: isCo,
                reading: reading,
                limit: isCo ? 100 : 50,
                statusColor: statusColor,
                statusText: statusText
            )
            .frame(height: 230)
            HStack(spacing: 0) {
                Readout(
                    symbol: "chart.line.uptrend.xyaxis",
                    value: peak.fixed(1),
                    label: "Peak 24h",
                    tint: accent
                )
                Readout(symbol: "waveform.path.ecg", value: average.fixed(1), label: "Average", tint: accent)
                Readout(
                    symbol: "checkmark.circle.fill",
                    value: testedAgo(device.lastTestedDaysAgo),
                    label: "Last test",
                    tint: accent
                )
            }
        }

        GlassSection(title: "Safety check", symbol: "checkmark.shield.fill", accent: accent) {
            if alarm {
                LiquidHoldOrb(
                    label: "Hold to silence",
                    symbol: "bell.slash.fill",
                    accent: NexColors.red,
                    active: true,
                    size: 120,
                    sublabel: "Ventilate and check every room"
                ) { device.sensorValue = svNormal }
                .frame(maxWidth: .infinity)
            } else {
                LiquidHoldOrb(
                    label: testing ? "Siren sounding…" : "Hold to test",
                    symbol: "speaker.wave.3.fill",
                    accent: accent,
                    active: testing,
                    size: 120,
                    sublabel: "Siren · 85 dB · voice + light ring",
                    enabled: !testing
                ) { startTest(peers: peers) }
                .frame(maxWidth: .infinity)
            }
            let overdue = device.lastTestedDaysAgo > 30
            GlassSettingRow(
                title: "Last tested",
                symbol: "checkmark.circle.fill",
                subtitle: overdue
                    ? "Overdue · test once a month"
                    : "Next test in \(30 - device.lastTestedDaysAgo) days",
                accent: overdue ? NexColors.amber : NexColors.mint
            ) {
                NexText(testedAgo(device.lastTestedDaysAgo), .label, color: NexColors.secondary)
                    .lineLimit(1)
            }
            GlassSettingRow(
                title: "Voice alerts",
                symbol: "speaker.wave.3.fill",
                subtitle: "Announces the room before the siren",
                accent: accent
            ) {
                LiquidToggle(isOn: device.chimeEnabled, accent: accent) { device.chimeEnabled = $0 }
            }
            GlassSettingRow(
                title: isCo ? "Electrochemical cell" : "Photoelectric chamber",
                symbol: "testtube.2",
                subtitle: isCo
                    ? "Self-check passed · 7-year sensor"
                    : "Self-check passed · dust compensated",
                accent: NexColors.violet
            ) {
                NexText(danger ? "Active" : "OK", .label, color: statusColor).lineLimit(1)
            }
        }

        GlassSection(
            title: isCo ? "CO level · 24 hours" : "Particulates · 24 hours",
            symbol: "wind",
            accent: accent
        ) {
            SensorLevelChart(
                history: history,
                low: 0,
                high: max(peak * 1.5, 10),
                color: statusColor,
                guide: warnAt
            )
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Now",
                    value: reading.fixed(1),
                    unit: isCo ? "ppm" : "µg/m³",
                    symbol: "wind",
                    accent: statusColor,
                    history: history
                )
                GlassMetricTile(
                    label: "Alarm at",
                    value: isCo ? "70" : "35",
                    unit: isCo ? "ppm" : "µg/m³",
                    symbol: "exclamationmark.triangle.fill",
                    accent: NexColors.red
                )
            }
        }

        if !peers.isEmpty {
            GlassSection(
                title: "Interconnected alarms",
                symbol: "point.3.connected.trianglepath.dotted",
                accent: accent,
                trailing: AnyView(
                    NexText("\(peers.count + 1) linked", .caption, color: NexColors.tertiary)
                        .lineLimit(1)
                )
            ) {
                ForEach(peers.prefix(6)) { peer in
                    let peerAlert = peer.sensorValue != svNormal
                    GlassSettingRow(
                        title: peer.name,
                        symbol: peer.type == .coDetector ? "carbon.dioxide.cloud.fill" : "flame.fill",
                        subtitle: "\(peer.room.displayName) · tested \(testedAgo(peer.lastTestedDaysAgo))",
                        accent: deviceAccent(peer.type)
                    ) {
                        NexText(
                            peerAlert ? peer.sensorValue : "OK",
                            .label,
                            color: peerAlert ? NexColors.red : NexColors.mint
                        )
                        .lineLimit(1)
                    }
                }
                NexText(
                    "When one alarm sounds, every linked alarm sounds with it.",
                    .caption,
                    color: NexColors.tertiary
                )
            }
        }
    }

    /// A test sounds every interconnected alarm too, then restores them all.
    private func startTest(peers: [Device]) {
        guard testTask == nil else { return }
        let linked = peers.filter { $0.sensorValue == svNormal }
        testTask = Task { @MainActor in
            defer {
                device.sensorValue = svNormal
                device.lastTestedDaysAgo = 0
                for peer in linked where peer.sensorValue == svTesting {
                    peer.sensorValue = svNormal
                    peer.lastTestedDaysAgo = 0
                }
                testTask = nil
            }
            device.sensorValue = svTesting
            try? await Task.sleep(for: .milliseconds(700))
            for peer in linked where peer.sensorValue == svNormal { peer.sensorValue = svTesting }
            try? await Task.sleep(for: .milliseconds(3800))
        }
    }
}

/// Breathing air chamber: drifting motes around a read-only level dial; alarms strobe red.
private struct DetectorStage: View {
    let danger: Bool
    let testing: Bool
    let isCo: Bool
    let reading: Double
    let limit: Double
    let statusColor: Color
    let statusText: String

    var body: some View {
        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.16),
            accent: statusColor,
            heavy: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: danger ? 1.4 : 0.1) { phase in
                    GeometryReader { proxy in
                        let size = proxy.size
                        ZStack {
                            if danger {
                                NexColors.red.opacity(0.18 + 0.22 * (0.5 + 0.5 * sin(phase * 2 * .pi)))
                            }
                            // Drifting motes.
                            ForEach(0..<14, id: \.self) { index in
                                let seed = (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
                                let t = (phase * Double(1 + index % 3) + seed)
                                    .truncatingRemainder(dividingBy: 1)
                                Circle()
                                    .fill(statusColor.opacity(0.1 + 0.25 * sin(t * .pi)))
                                    .frame(width: CGFloat(3 + index % 4))
                                    .position(
                                        x: size.width * CGFloat(0.08 + 0.84 * seed),
                                        y: size.height * CGFloat(0.9 - 0.8 * t)
                                    )
                            }
                        }
                    }
                }
            )
        ) {
            LiquidDial(
                value: min(reading, limit),
                range: 0...limit,
                accent: statusColor,
                readOnly: true,
                size: 190
            ) {
                VStack(spacing: 0) {
                    Text(reading.fixed(1))
                        .font(NexType.numeric.font)
                        .tracking(NexType.numeric.tracking)
                        .foregroundStyle(NexColors.primary)
                        .lineLimit(1)
                    NexText(isCo ? "ppm CO" : "µg/m³", .caption, color: NexColors.secondary)
                        .lineLimit(1)
                    NexText(statusText, .label, color: statusColor).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Leak sensor

private struct LeakSensorSheet: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository
    @State private var testTask: Task<Void, Never>?

    var body: some View {
        let wet = device.sensorValue == svLeak
        let valveClosed = wet && device.autoShutoffValve
        let history = device.sensorHistory
        let peak = history.max() ?? 0
        let stateColor = wet ? NexColors.red : accent
        let peers = repository.devices(ofKind: .sensorReadonly)
            .filter { $0.type == .leakSensor && $0.id != device.id }

        GlassSection(
            title: "Water",
            symbol: "drop.fill",
            accent: accent,
            trailing: AnyView(
                StatusBadge(
                    text: wet ? "Leak" : "Dry",
                    color: wet ? NexColors.red : NexColors.mint,
                    pulsing: wet
                )
            )
        ) {
            LeakStage(level: device.sensorNumeric / 100, stateColor: stateColor, wet: wet)
                .frame(height: 180)
            HStack(spacing: 0) {
                Readout(
                    symbol: "humidity.fill",
                    value: "\(device.sensorNumeric.rounded0)%",
                    label: "Moisture",
                    tint: stateColor
                )
                Readout(
                    symbol: "clock.arrow.circlepath",
                    value: sensorAgo(device.lastEventMinutesAgo),
                    label: "Last event",
                    tint: accent
                )
                Readout(
                    symbol: "spigot.fill",
                    value: valveClosed ? "Closed" : "Open",
                    label: "Main valve",
                    tint: accent
                )
            }
        }

        GlassSection(title: "Protection", symbol: "spigot.fill", accent: accent) {
            ValvePanel(closed: valveClosed, armed: device.autoShutoffValve, accent: accent)
            GlassSettingRow(
                title: "Auto shut-off",
                symbol: "spigot.fill",
                subtitle: device.autoShutoffValve
                    ? "Closes the main valve on a leak"
                    : "Alerts only",
                accent: accent
            ) {
                LiquidToggle(isOn: device.autoShutoffValve, accent: accent) {
                    device.autoShutoffValve = $0
                }
            }
            GlassSettingRow(
                title: "Local siren",
                symbol: "speaker.wave.3.fill",
                subtitle: "Beeps from the sensor when wet",
                accent: accent
            ) {
                LiquidToggle(isOn: device.chimeEnabled, accent: accent) { device.chimeEnabled = $0 }
            }
            if wet {
                LiquidHoldOrb(
                    label: "Hold to mark dry",
                    symbol: "checkmark.circle.fill",
                    accent: NexColors.mint,
                    size: 116,
                    sublabel: valveClosed ? "Reopens the main valve" : "Clears the alert"
                ) { markDry() }
                .frame(maxWidth: .infinity)
            } else {
                LiquidHoldOrb(
                    label: "Hold to test",
                    symbol: "drop.triangle.fill",
                    accent: accent,
                    size: 116,
                    sublabel: "Simulates a leak for 5 seconds"
                ) { runLeakTest() }
                .frame(maxWidth: .infinity)
            }
        }

        GlassSection(title: "Moisture · 24 hours", symbol: "humidity.fill", accent: accent) {
            SensorLevelChart(history: history, low: 0, high: 100, color: stateColor, guide: 60)
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Now",
                    value: "\(device.sensorNumeric.rounded0)",
                    unit: "%",
                    symbol: "drop.fill",
                    accent: stateColor,
                    history: history
                )
                GlassMetricTile(
                    label: "Peak 24h",
                    value: "\(peak.rounded0)",
                    unit: "%",
                    symbol: "chart.line.uptrend.xyaxis",
                    accent: accent
                )
            }
        }

        if !peers.isEmpty {
            GlassSection(
                title: "Other leak sensors",
                symbol: "point.3.connected.trianglepath.dotted",
                accent: accent
            ) {
                ForEach(peers.prefix(5)) { peer in
                    let peerWet = peer.sensorValue == svLeak
                    GlassSettingRow(
                        title: peer.name,
                        symbol: "drop.fill",
                        subtitle: "\(peer.room.displayName) · \(peer.sensorNumeric.rounded0)% moisture",
                        accent: peerWet ? NexColors.red : deviceAccent(peer.type)
                    ) {
                        NexText(
                            peerWet ? "Leak" : "Dry",
                            .label,
                            color: peerWet ? NexColors.red : NexColors.mint
                        )
                        .lineLimit(1)
                    }
                }
            }
        }
    }

    private func runLeakTest() {
        guard testTask == nil else { return }
        let dryReading = min(device.sensorNumeric, 40)
        testTask = Task { @MainActor in
            defer {
                device.sensorValue = svDry
                device.sensorNumeric = dryReading
                testTask = nil
            }
            device.sensorValue = svLeak
            device.sensorNumeric = 92
            device.lastEventMinutesAgo = 0
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func markDry() {
        testTask?.cancel()
        testTask = nil
        device.sensorValue = svDry
        device.sensorNumeric = 6
        device.lastEventMinutesAgo = 0
    }
}

/// Water line rising with moisture; waves speed up and drops fall when wet.
private struct LeakStage: View {
    let level: Double
    let stateColor: Color
    let wet: Bool

    var body: some View {
        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.18),
            accent: stateColor,
            heavy: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: wet ? 0.8 : 0.16) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        let surfaceY = h * CGFloat(1 - clamp01(level))
                        ZStack {
                            wavePath(w: w, h: h, surfaceY: surfaceY, phase: phase, amp: wet ? 6 : 3)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            stateColor.opacity(0.75),
                                            stateColor.opacity(0.35),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            if wet {
                                ForEach(0..<6, id: \.self) { index in
                                    let seed = (Double(index) * 0.618)
                                        .truncatingRemainder(dividingBy: 1)
                                    let t = (phase * Double(1 + index % 2) + seed)
                                        .truncatingRemainder(dividingBy: 1)
                                    Circle()
                                        .fill(Color.white.opacity(0.5 * sin(t * .pi)))
                                        .frame(width: CGFloat(4 + index % 3))
                                        .position(
                                            x: w * CGFloat(0.1 + 0.8 * seed),
                                            y: surfaceY * CGFloat(t)
                                        )
                                }
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.811, dampingFraction: 0.45), value: level)
            )
        ) {
            VStack(spacing: 2) {
                NexText("\((level * 100).rounded0)%", .headline).lineLimit(1)
                NexText(wet ? "Water detected" : "Floor dry", .caption, color: NexColors.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func wavePath(w: CGFloat, h: CGFloat, surfaceY: CGFloat, phase: Double, amp: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: h))
            let steps = 18
            for s in 0...steps {
                let x = w * CGFloat(s) / CGFloat(steps)
                let y = surfaceY
                    + CGFloat(sin((Double(s) / Double(steps) * 1.8 + phase) * 2 * .pi)) * amp
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
        }
    }
}

/// The main shut-off valve: the handle turns 90° when the valve closes.
private struct ValvePanel: View {
    let closed: Bool
    let armed: Bool
    let accent: Color

    var body: some View {
        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintLight,
            surface: AnyView(
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let cy = proxy.size.height / 2
                    ZStack {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: w - 48, height: 10)
                            .position(x: w / 2, y: cy)
                        if !closed {
                            Capsule()
                                .fill(accent.opacity(0.7))
                                .frame(width: w - 48, height: 6)
                                .position(x: w / 2, y: cy)
                        }
                        // The valve body and handle.
                        ZStack {
                            Circle()
                                .fill(closed ? NexColors.red.opacity(0.8) : accent.opacity(0.8))
                                .frame(width: 26)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 24, height: 5)
                                .rotationEffect(.degrees(closed ? 90 : 0))
                        }
                        .position(x: w / 2, y: cy)
                    }
                }
                .animation(.spring(response: 0.574, dampingFraction: 0.5), value: closed)
            )
        ) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    NexText(closed ? "Valve closed" : "Valve open", .label)
                    Spacer()
                    NexText(
                        armed ? "Auto shut-off armed" : "Manual only",
                        .caption,
                        color: NexColors.tertiary
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Climate sensor

private struct ClimateSensorSheet: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let temp = device.currentTempF
        let humidity = device.humidityPercent
        let history = device.sensorHistory
        let low = history.min() ?? temp
        let high = history.max() ?? temp
        let trend = history.count >= 2 ? history[history.count - 1] - history[history.count - 2] : 0
        let comfortText = comfortLabel(temp, humidity)
        let comfort = comfortColor(temp, humidity)
        let climate = repository.devices(ofKind: .thermostatDial)
        let thermostat = climate.first { $0.room == device.room } ?? climate.first

        GlassSection(
            title: "Environment",
            symbol: "thermometer.medium",
            accent: accent,
            trailing: AnyView(StatusBadge(text: comfortText, color: comfort))
        ) {
            ClimateDialStage(temp: temp, humidity: humidity)
            HStack(spacing: 0) {
                Readout(
                    symbol: "humidity.fill",
                    value: "\(dewPointF(temp, humidity).fixed(1))°",
                    label: "Dew point",
                    tint: accent
                )
                Readout(
                    symbol: "thermometer.variable",
                    value: "\((temp + Double(humidity - 45) * 0.05).fixed(1))°",
                    label: "Feels like",
                    tint: accent
                )
                Readout(
                    symbol: "waveform.path.ecg",
                    value: "\(trend >= 0 ? "+" : "−")\(abs(trend).fixed(1))°",
                    label: "Last hour",
                    tint: accent
                )
            }
        }

        GlassSection(title: "Comfort", symbol: "sparkles", accent: accent) {
            ComfortMap(temp: temp, humidity: humidity, color: comfort)
            NexText(comfortAdvice(temp, humidity), .caption, color: NexColors.secondary)
        }

        GlassSection(
            title: "Temperature · 24 hours",
            symbol: "waveform.path.ecg",
            accent: accent,
            trailing: AnyView(
                NexText("\(low.fixed(1))–\(high.fixed(1))°F", .caption, color: NexColors.tertiary)
                    .lineLimit(1)
            )
        ) {
            SensorLevelChart(
                history: history,
                low: low - 1.5,
                high: high + 1.5,
                color: accent,
                guide: thermostat?.targetTempF
            )
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Low",
                    value: low.fixed(1),
                    unit: "°F",
                    symbol: "snowflake",
                    accent: NexColors.blue
                )
                GlassMetricTile(
                    label: "High",
                    value: high.fixed(1),
                    unit: "°F",
                    symbol: "flame.fill",
                    accent: NexColors.orange
                )
            }
        }

        if let thermostat {
            let thermoAccent = deviceAccent(thermostat.type)
            let offset = temp - thermostat.currentTempF
            GlassSection(title: "Room climate", symbol: "thermometer.variable", accent: thermoAccent) {
                GlassSettingRow(
                    title: thermostat.name,
                    symbol: "thermometer.medium",
                    subtitle: "\(thermostat.room.displayName) · \(thermostat.hvacMode.displayName) · now \(thermostat.currentTempF.fixed(1))°",
                    accent: thermoAccent
                )
                ControlRow(
                    title: "Target",
                    subtitle: "This sensor reads \(offset >= 0 ? "+" : "−")\(abs(offset).fixed(1))° vs the thermostat"
                ) {
                    LiquidStepper(
                        value: thermostat.targetTempF,
                        range: 60...82,
                        step: 1,
                        format: { "\($0.rounded0)°" },
                        accent: thermoAccent
                    ) { thermostat.targetTempF = $0 }
                }
                LiquidSegmented(
                    options: [
                        SegmentOption("Heat", "flame.fill"),
                        SegmentOption("Cool", "snowflake"),
                        SegmentOption("Auto", "arrow.triangle.2.circlepath"),
                        SegmentOption("Eco", "leaf.fill"),
                        SegmentOption("Off", "power"),
                    ],
                    selectedIndex: thermostat.hvacMode.rawValue,
                    accent: thermoAccent
                ) { thermostat.hvacMode = HvacMode.allCases[$0] }
            }
        }
    }
}

/// Twin read-only dials (temperature, humidity) over a warm/cool aura.
private struct ClimateDialStage: View {
    let temp: Double
    let humidity: Int

    var body: some View {
        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.14),
            heavy: true,
            surface: AnyView(
                ZStack {
                    LinearGradient(
                        colors: [
                            NexColors.orange.opacity(0.14),
                            .clear,
                            NexColors.cyan.opacity(0.14),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
        ) {
            HStack(spacing: 8) {
                LiquidDial(
                    value: temp,
                    range: 50...90,
                    accent: tempColor(temp),
                    readOnly: true,
                    size: 150
                ) {
                    VStack(spacing: 0) {
                        NexText("\(temp.fixed(1))°", .headline).lineLimit(1)
                        NexText("TEMP", .caption, color: NexColors.secondary)
                    }
                }
                LiquidDial(
                    value: Double(humidity),
                    range: 0...100,
                    accent: NexColors.cyan,
                    readOnly: true,
                    size: 150
                ) {
                    VStack(spacing: 0) {
                        NexText("\(humidity)%", .headline).lineLimit(1)
                        NexText("HUMIDITY", .caption, color: NexColors.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

/// The comfort map: a temperature / humidity field with the current reading plotted on it.
private struct ComfortMap: View {
    let temp: Double
    let humidity: Int
    let color: Color

    var body: some View {
        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintLight,
            surface: AnyView(
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let pad: CGFloat = 16
                    let fx = comfortX(temp)
                    let fy = comfortY(humidity)
                    ZStack {
                        // Comfort zone.
                        RoundedRectangle(cornerRadius: 10)
                            .fill(NexColors.mint.opacity(0.14))
                            .frame(
                                width: (w - pad * 2) * 0.34,
                                height: (h - pad * 2) * 0.42
                            )
                            .position(
                                x: pad + (w - pad * 2) * 0.47,
                                y: h - pad - (h - pad * 2) * 0.47
                            )
                        // Grid.
                        Path { path in
                            for k in 0...3 {
                                let x = pad + (w - pad * 2) * CGFloat(k) / 3
                                path.move(to: CGPoint(x: x, y: pad))
                                path.addLine(to: CGPoint(x: x, y: h - pad))
                                let y = pad + (h - pad * 2) * CGFloat(k) / 3
                                path.move(to: CGPoint(x: pad, y: y))
                                path.addLine(to: CGPoint(x: w - pad, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        // The reading.
                        ZStack {
                            Circle().fill(color.opacity(0.3)).frame(width: 26)
                            Circle().fill(color).frame(width: 10)
                        }
                        .position(
                            x: pad + (w - pad * 2) * CGFloat(fx),
                            y: h - pad - (h - pad * 2) * CGFloat(fy)
                        )
                        .animation(GlassMotion.release, value: temp)
                    }
                }
            )
        ) {
            VStack {
                HStack {
                    NexText("Humid", .caption, color: NexColors.tertiary)
                    Spacer()
                }
                Spacer(minLength: 0)
                HStack {
                    NexText("Cool", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText("Warm", .caption, color: NexColors.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .padding(10)
        }
    }
}

// MARK: - Generic sensor

private struct GenericSensorSheet: View {
    let device: Device
    let accent: Color

    var body: some View {
        GlassSection(title: "Reading", symbol: "sensor.fill", accent: accent) {
            GlassPanel(shape: glassRect(24), tint: Color.black.opacity(0.14), heavy: true) {
                VStack(spacing: 8) {
                    GlassIconOrb(
                        symbol: "sensor.fill",
                        accent: accent,
                        size: 80,
                        glow: 0.4,
                        iconTint: accent
                    )
                    NexText(device.sensorValue, .title)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
            GlassMetricTile(
                label: "Last 24 hours",
                value: device.sensorNumeric.fixed(1),
                symbol: "waveform.path.ecg",
                accent: accent,
                history: device.sensorHistory
            )
        }
    }
}

// MARK: - Shared sensor sections

/// Battery, signal, monitoring, favourite and firmware — common to every sensor.
private struct SensorHealthSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        let battery = clamp(device.batteryPercent, 0, 100)
        let color = batteryColor(battery)
        let lifeSafety = device.type == .smokeDetector || device.type == .coDetector

        GlassSection(title: "Device", symbol: "memorychip.fill", accent: accent) {
            GlassSettingRow(
                title: "Battery",
                symbol: batterySymbol(battery),
                subtitle: battery <= 20
                    ? "Replace soon · CR123A"
                    : "About \(max(Int((Double(battery) * 0.24).rounded()), 1)) months left",
                accent: color
            ) {
                Text("\(battery)%")
                    .font(NexType.bodyStrong.font.monospacedDigit())
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
            }
            GlassLevelBar(fraction: Double(battery) / 100, color: color)
            GlassSettingRow(
                title: "Signal",
                symbol: "cellularbars",
                subtitle: "\(shortSignalLabel(device.signalStrength)) · Thread mesh",
                accent: NexColors.cyan
            ) {
                SignalBars(strength: device.signalStrength, accent: NexColors.cyan)
            }
            if !lifeSafety {
                GlassSettingRow(
                    title: "Monitoring",
                    symbol: device.isOn ? "sensor.fill" : "sensor",
                    subtitle: device.isOn
                        ? "Reporting events live"
                        : "Paused · no events or alerts",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.isOn, accent: accent) { device.isOn = $0 }
                }
            }
            GlassSettingRow(
                title: "Favorite",
                symbol: device.isFavorite ? "star.fill" : "star",
                subtitle: "Pin to Home",
                accent: NexColors.gold
            ) {
                LiquidToggle(isOn: device.isFavorite, accent: NexColors.gold) {
                    device.isFavorite = $0
                }
            }
            GlassSettingRow(
                title: "Firmware",
                symbol: "arrow.down.circle.fill",
                subtitle: "Up to date",
                accent: NexColors.violet
            ) {
                NexText("v\(device.firmwareVersion)", .caption, color: NexColors.tertiary).lineLimit(1)
            }
        }
    }
}

/// Quiet-hours toggle; when enabled, start/end hour steppers appear below it.
private struct QuietHoursRows: View {
    @Bindable var device: Device
    let mutedWhat: String

    var body: some View {
        GlassSettingRow(
            title: "Quiet hours",
            symbol: "moon.stars.fill",
            subtitle: device.scheduleEnabled
                ? "\(sensorHourLabel(device.scheduleOnHour)) – \(sensorHourLabel(device.scheduleOffHour)) · \(mutedWhat)"
                : "Off",
            accent: NexColors.indigo
        ) {
            LiquidToggle(isOn: device.scheduleEnabled, accent: NexColors.indigo) {
                device.scheduleEnabled = $0
            }
        }
        if device.scheduleEnabled {
            GlassSettingRow(
                title: "Starts",
                symbol: "moon.stars.fill",
                accent: NexColors.indigo
            ) {
                LiquidIntStepper(
                    value: device.scheduleOnHour,
                    range: 0...23,
                    format: sensorHourLabel,
                    accent: NexColors.indigo
                ) { device.scheduleOnHour = $0 }
            }
            GlassSettingRow(
                title: "Ends",
                symbol: "bell.badge.fill",
                accent: NexColors.indigo
            ) {
                LiquidIntStepper(
                    value: device.scheduleOffHour,
                    range: 0...23,
                    format: sensorHourLabel,
                    accent: NexColors.indigo
                ) { device.scheduleOffHour = $0 }
            }
        }
    }
}

/// Event-count history turned into "N events · 3 h ago" rows (newest first).
private struct RecentEventsSection: View {
    let history: [Double]
    let nowHour: Int
    let accent: Color
    let symbol: String
    let emptyText: String
    let title: (Int) -> String

    var body: some View {
        let events = recentEventHours(history)
        GlassSection(title: "Recent activity", symbol: "clock.arrow.circlepath", accent: accent) {
            if events.isEmpty {
                NexText(emptyText, .body, color: NexColors.secondary)
            }
            ForEach(Array(events.enumerated()), id: \.offset) { _, entry in
                GlassSettingRow(
                    title: title(entry.1),
                    symbol: symbol,
                    subtitle: entry.0 == 0 ? "This hour" : "\(entry.0) h ago",
                    accent: accent
                ) {
                    NexText(sensorHourLabel(nowHour - entry.0), .caption, color: NexColors.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// 24 h event-count bars inside glass.
private struct SensorHourBars: View {
    let history: [Double]
    let color: Color
    let live: Bool

    var body: some View {
        HourlyUsageBars(history: history, accent: color)
            .frame(height: 120)
    }
}

/// A level chart inside glass with an optional guide line (alarm threshold, thermostat target).
private struct SensorLevelChart: View {
    let history: [Double]
    let low: Double
    let high: Double
    let color: Color
    let guide: Double?

    var body: some View {
        GlassPanel(
            shape: glassRect(22),
            tint: NexColors.glassTintLight,
            interactive: true,
            surface: AnyView(
                GeometryReader { proxy in
                    let size = proxy.size
                    if history.count >= 2, size.width > 40, size.height > 60 {
                        let pad: CGFloat = 14
                        let top: CGFloat = 18
                        let bottom = size.height - 28
                        let span = max(high - low, 0.001)
                        let band = max(bottom - top, 1)
                        let stepX = (size.width - pad * 2) / CGFloat(history.count - 1)
                        let points = history.enumerated().map { index, value in
                            CGPoint(
                                x: pad + stepX * CGFloat(index),
                                y: bottom - CGFloat(clamp01((value - low) / span)) * band
                            )
                        }
                        ZStack {
                            if let guide {
                                let gy = bottom - CGFloat(clamp01((guide - low) / span)) * band
                                Path { path in
                                    path.move(to: CGPoint(x: pad, y: gy))
                                    path.addLine(to: CGPoint(x: size.width - pad, y: gy))
                                }
                                .stroke(
                                    Color.white.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                )
                            }
                            Path { path in
                                guard let first = points.first, let last = points.last else { return }
                                path.move(to: CGPoint(x: first.x, y: bottom))
                                for point in points { path.addLine(to: point) }
                                path.addLine(to: CGPoint(x: last.x, y: bottom))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.32), color.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            Path { path in
                                guard let first = points.first else { return }
                                path.move(to: first)
                                for point in points.dropFirst() { path.addLine(to: point) }
                            }
                            .stroke(
                                color,
                                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                            )
                            if let last = points.last {
                                Circle().fill(Color.white).frame(width: 7).position(last)
                            }
                        }
                    }
                }
            )
        ) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    NexText("24h ago", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText("12h", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText("Now", .caption, color: NexColors.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Sensor helpers

private let svMotion = "Motion detected"
private let svOpen = "Open"
private let svNormal = "Normal"
private let svTesting = "Testing"
private let svSmoke = "Smoke detected"
private let svCo = "CO detected"
private let svLeak = "Leak detected"
private let svDry = "Dry"

private let comfortMinF = 55.0
private let comfortMaxF = 90.0
private let sensitivityPresets: [Double] = [0.3, 0.6, 0.9]

private func sensitivityPreset(_ value: Double) -> Int {
    if value < 0.45 { return 0 }
    if value < 0.75 { return 1 }
    return 2
}

private func sensitivityHint(_ value: Double) -> String {
    if value < 0.45 { return "Ignores pets under 25 kg · fewer false alarms" }
    if value < 0.75 { return "Balanced for people walking through the room" }
    return "Catches small movements · may notice pets"
}

private func sensorAgo(_ minutes: Int) -> String {
    if minutes <= 0 { return "Just now" }
    if minutes < 60 { return "\(minutes) min ago" }
    if minutes < 60 * 24 { return "\(minutes / 60) h ago" }
    return "\(minutes / (60 * 24)) d ago"
}

private func sensorDuration(_ minutes: Int) -> String {
    if minutes <= 0 { return "<1 min" }
    if minutes < 60 { return "\(minutes) min" }
    if minutes < 60 * 24 { return "\(minutes / 60) h \(minutes % 60) m" }
    return "\(minutes / (60 * 24)) days"
}

private func testedAgo(_ days: Int) -> String {
    if days <= 0 { return "Today" }
    if days == 1 { return "Yesterday" }
    return "\(days) d ago"
}

private func sensorHourLabel(_ hour: Int) -> String {
    let h = ((hour % 24) + 24) % 24
    let h12 = h % 12 == 0 ? 12 : h % 12
    return "\(h12) \(h < 12 ? "AM" : "PM")"
}

private func busiestIndex(_ history: [Double]) -> Int {
    var best = -1
    var bestValue = 0.5
    for index in history.indices where history[index] > bestValue {
        bestValue = history[index]
        best = index
    }
    return best
}

/// (hoursAgo, count) for the most recent hours with at least one event, newest first.
private func recentEventHours(_ history: [Double], limit: Int = 5) -> [(Int, Int)] {
    var out: [(Int, Int)] = []
    for index in history.indices.reversed() {
        let count = history[index].rounded0
        if count > 0 {
            out.append((history.count - 1 - index, count))
            if out.count >= limit { break }
        }
    }
    return out
}

private func shortSignalLabel(_ bars: Int) -> String {
    switch bars {
    case 4...: return "Excellent"
    case 3: return "Good"
    case 2: return "Fair"
    default: return "Weak"
    }
}

private func tempColor(_ temp: Double) -> Color {
    if temp < 64 { return NexColors.blue }
    if temp < 68 { return NexColors.cyan }
    if temp <= 76 { return NexColors.mint }
    if temp <= 80 { return NexColors.amber }
    return NexColors.orange
}

private func comfortLabel(_ temp: Double, _ humidity: Int) -> String {
    if temp < 66 { return "Chilly" }
    if temp > 78 { return "Warm" }
    if humidity < 30 { return "Dry air" }
    if humidity > 60 { return "Humid" }
    return "Comfortable"
}

private func comfortColor(_ temp: Double, _ humidity: Int) -> Color {
    if temp < 66 { return NexColors.blue }
    if temp > 78 { return NexColors.orange }
    if humidity < 30 { return NexColors.amber }
    if humidity > 60 { return NexColors.teal }
    return NexColors.mint
}

private func comfortAdvice(_ temp: Double, _ humidity: Int) -> String {
    if temp < 66 { return "A little cool — nudge the thermostat up a degree or two." }
    if temp > 78 { return "Running warm — cooling or a ceiling fan would help." }
    if humidity < 30 { return "Dry air — a humidifier keeps skin and wood floors happy." }
    if humidity > 60 { return "Humid — ventilate or run the bathroom fan to prevent mold." }
    return "Temperature and humidity are right in the comfort zone."
}

private func comfortX(_ temp: Double) -> Double {
    clamp01((temp - comfortMinF) / (comfortMaxF - comfortMinF))
}

private func comfortY(_ humidity: Int) -> Double {
    clamp01((Double(humidity) - 15) / 70)
}

/// Magnus-formula dew point in °F.
private func dewPointF(_ tempF: Double, _ humidity: Int) -> Double {
    let rh = Double(clamp(humidity, 1, 100)) / 100
    let tc = (tempF - 32) * 5 / 9
    let a = 17.62
    let b = 243.12
    let gamma = log(rh) + a * tc / (b + tc)
    let dewC = b * gamma / (a - gamma)
    return dewC * 9 / 5 + 32
}
