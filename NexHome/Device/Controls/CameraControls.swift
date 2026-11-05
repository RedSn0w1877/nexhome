import SwiftUI

// MARK: - Cameras (ControlKind.cameraFeed)

/// Camera sheet: a live-view hero with glass badges over the processed picture, PTZ (glass joystick
/// + zoom fader + view presets), night vision, push-to-talk with spotlight and siren deterrence, a
/// motion-detection radar driven by sensitivity, insights, an event timeline whose rows replay into
/// the hero feed, and camera settings.
struct CameraControls: View {
    @Bindable var device: Device

    @State private var replay: CameraEvent?
    @State private var flash: Double = 0
    @State private var speakingReply: String?
    @State private var filter: EventFilter = .all
    @State private var radarWake = 0

    var body: some View {
        let accent = deviceAccent(device.type)
        let profile = cameraProfile(device.type)

        VStack(spacing: 16) {
            liveViewSection(accent: accent, profile: profile)
            panZoomSection(accent: accent, profile: profile)
            nightVisionSection(profile: profile)
            talkSection(accent: accent, profile: profile)
            detectionSection(accent: accent, profile: profile)
            insightsSection(accent: accent, profile: profile)
            eventsSection(accent: accent)
            settingsSection(accent: accent, profile: profile)
        }
        // A camera siren is a deterrent burst, not a latch: it silences itself.
        .task(id: device.sirenOn) {
            guard device.sirenOn else { return }
            try? await Task.sleep(for: .seconds(30))
            device.sirenOn = false
        }
    }

    // MARK: 1. Live view

    private func liveViewSection(accent: Color, profile: CameraProfile) -> some View {
        let night = isNightNow()
        let nightAmount: Double = {
            switch device.nightVisionMode {
            case .on: return 1
            case .off: return 0
            case .auto: return night ? 1 : 0
            }
        }()
        let shutterOn = device.privacyMode || !device.isOn
        let motionVisible = device.motionDetected && replay == nil && !shutterOn
        let latest = device.cameraEvents.first
        let live = device.isRecording && !shutterOn && replay == nil
        let zoomed = device.zoom > 1.03

        return GlassSection(
            title: replay != nil ? "Replay" : "Live view",
            symbol: replay != nil ? "clock.arrow.circlepath" : "video.fill",
            accent: accent,
            trailing: AnyView(
                NexText(
                    device.isRecording ? "\(profile.resolution) · REC" : profile.resolution,
                    .caption,
                    color: device.isRecording ? NexColors.red : NexColors.tertiary
                )
                .lineLimit(1)
            )
        ) {
            ZStack {
                CameraFeed(
                    seed: replay?.seed ?? device.cameraSeed,
                    cornerRadius: 20,
                    cycling: replay == nil && !shutterOn,
                    zoom: device.zoom,
                    panX: device.panX,
                    panY: device.panY,
                    overscan: 1.25,
                    nightVision: nightAmount,
                    privacy: shutterOn ? 1 : 0,
                    spotlight: device.spotlightOn ? 1 : 0,
                    alarm: device.sirenOn ? 1 : 0,
                    onSeedTick: { if replay == nil { device.cameraSeed = $0 } }
                )
                .animation(.spring(response: 0.39, dampingFraction: 0.7), value: device.zoom)
                .animation(.spring(response: 0.39, dampingFraction: 0.7), value: device.panX)
                .animation(.spring(response: 0.39, dampingFraction: 0.7), value: device.panY)

                if motionVisible {
                    MotionReticle(seed: latest?.seed ?? device.cameraSeed, color: NexColors.red)
                }

                if flash > 0.01 {
                    Color.white.opacity(0.85 * clamp01(flash)).blendMode(.plusLighter)
                }

                // Chrome.
                VStack {
                    HStack(alignment: .top) {
                        FeedChip {
                            if live {
                                PulsingDot(color: NexColors.red)
                            } else {
                                Circle().fill(NexColors.tertiary).frame(width: 7)
                            }
                            NexText(liveBadgeText(shutterOn: shutterOn), .caption, color: .white)
                                .lineLimit(1)
                        }
                        Spacer()
                        FeedChip {
                            if let replay {
                                NexText(agoText(replay.minutesAgo), .caption, color: .white).lineLimit(1)
                            } else {
                                LiveClockText()
                            }
                        }
                    }
                    if device.talkActive && !shutterOn {
                        FeedChip(tint: accent.opacity(0.4)) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                            NexText("Speaking", .caption, color: .white).lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        if motionVisible {
                            FeedChip(tint: NexColors.red.opacity(0.42)) {
                                Image(systemName: category(of: latest?.label ?? "Motion").symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                NexText(latest?.label ?? "Motion", .caption, color: .white).lineLimit(1)
                            }
                        }
                        Spacer()
                        if zoomed {
                            FeedChip {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                NexText(formatZoom(device.zoom), .caption, color: .white).lineLimit(1)
                            }
                            .onTapGesture { centerView() }
                        }
                    }
                }
                .padding(10)

                if shutterOn {
                    VStack(spacing: 6) {
                        GlassIconOrb(
                            symbol: device.privacyMode ? "eye.slash.fill" : "video.slash.fill",
                            accent: NexColors.violet,
                            size: 56,
                            glow: 0.6,
                            iconTint: .white
                        )
                        NexText(device.privacyMode ? "Privacy mode" : "Camera off", .bodyStrong)
                            .lineLimit(1)
                        NexText("Video, audio & alerts paused", .caption, color: NexColors.secondary)
                            .lineLimit(1)
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .aspectRatio(profile.aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .animation(GlassMotion.release, value: motionVisible)
            .animation(GlassMotion.release, value: shutterOn)

            LiquidChipRow {
                if replay != nil {
                    LiquidChip(
                        label: "Back to live",
                        symbol: "tv.badge.wifi",
                        selected: true,
                        accent: accent
                    ) { replay = nil }
                }
                LiquidChip(label: "Snapshot", symbol: "camera.fill", selected: false, accent: accent) {
                    snapshot()
                }
                LiquidChip(
                    label: device.isRecording ? "Recording" : "Record",
                    symbol: "circle.fill",
                    selected: device.isRecording,
                    accent: NexColors.red
                ) { device.isRecording.toggle() }
                LiquidChip(label: "Center view", symbol: "scope", selected: false, accent: accent) {
                    centerView()
                }
            }
        }
    }

    private func liveBadgeText(shutterOn: Bool) -> String {
        if replay != nil { return "REPLAY" }
        if !device.isOn { return "OFF" }
        if device.privacyMode { return "PRIVATE" }
        return device.isRecording ? "LIVE · REC" : "LIVE"
    }

    private func snapshot() {
        flash = 1
        withAnimation(.spring(response: 0.811, dampingFraction: 1)) { flash = 0 }
        device.cameraEvents = Array(
            ([CameraEvent(label: "Snapshot saved", minutesAgo: 0, seed: device.cameraSeed)]
                + device.cameraEvents).prefix(12)
        )
    }

    private func centerView() {
        withAnimation(.spring(response: 0.574, dampingFraction: 0.62)) {
            device.panX = 0
            device.panY = 0
            device.zoom = 1
        }
    }

    // MARK: 2. Pan and zoom

    private func panZoomSection(accent: Color, profile: CameraProfile) -> some View {
        GlassSection(
            title: "Pan & zoom",
            symbol: "arrow.up.and.down.and.arrow.left.and.right",
            accent: accent,
            trailing: AnyView(
                Text("\((device.panX * 170).rounded0)° pan · \((-device.panY * 45).rounded0)° tilt")
                    .font(NexType.caption.font.monospacedDigit())
                    .foregroundStyle(NexColors.tertiary)
                    .lineLimit(1)
            )
        ) {
            HStack(spacing: 14) {
                PtzJoystick(device: device, accent: accent)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                LiquidFader(
                    value: clamp01((device.zoom - 1) / 3),
                    accent: accent,
                    symbol: "scope",
                    label: "Zoom",
                    valueText: { formatZoom(1 + $0 * 3) },
                    width: 84,
                    height: 196
                ) { device.zoom = 1 + $0 * 3 }
            }
            NexText(
                "Push the stick to steer · drag the zoom fader to magnify",
                .caption,
                color: NexColors.tertiary
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            LiquidChipRow {
                ForEach(profile.presets, id: \.label) { preset in
                    let selected = abs(device.panX - preset.panX) < 0.05
                        && abs(device.panY - preset.panY) < 0.05
                        && abs(device.zoom - preset.zoom) < 0.08
                    LiquidChip(
                        label: preset.label,
                        symbol: preset.symbol,
                        selected: selected,
                        accent: accent
                    ) {
                        withAnimation(.spring(response: 0.574, dampingFraction: 0.62)) {
                            device.panX = preset.panX
                            device.panY = preset.panY
                            device.zoom = preset.zoom
                        }
                    }
                }
            }
        }
    }

    // MARK: 3. Night vision

    private func nightVisionSection(profile: CameraProfile) -> some View {
        let night = isNightNow()
        let infraredActive = device.nightVisionMode == .on
            || (device.nightVisionMode == .auto && night)

        return GlassSection(
            title: "Night vision",
            symbol: "moon.stars.fill",
            accent: nightVisionGreen,
            trailing: AnyView(
                NexText(
                    {
                        switch device.nightVisionMode {
                        case .auto: return night ? "Auto · IR active" : "Auto · Daylight"
                        case .on: return "Infrared on"
                        case .off: return "Off"
                        }
                    }(),
                    .caption,
                    color: infraredActive ? nightVisionGreen : NexColors.tertiary
                )
                .lineLimit(1)
            )
        ) {
            LiquidSegmented(
                options: [
                    SegmentOption("Auto", "circle.lefthalf.filled"),
                    SegmentOption("On", "moon.fill"),
                    SegmentOption("Off", "sun.max.fill"),
                ],
                selectedIndex: device.nightVisionMode.rawValue,
                accent: nightVisionGreen
            ) { device.nightVisionMode = NightVisionMode.allCases[$0] }
            NexText(
                {
                    switch device.nightVisionMode {
                    case .auto: return "Switches to 850 nm infrared when the scene gets dark."
                    case .on: return "Infrared illuminators stay on — sharp black & white up to 30 ft."
                    case .off: return "Color only. Low-light scenes may look dark or grainy."
                    }
                }(),
                .caption,
                color: NexColors.secondary
            )
            if profile.hasSpotlight {
                GlassSettingRow(
                    title: "Color night vision",
                    symbol: "flashlight.on.fill",
                    subtitle: "Spotlight lights the scene in full color",
                    accent: NexColors.gold
                ) {
                    LiquidToggle(isOn: device.spotlightOn, accent: NexColors.gold) {
                        device.spotlightOn = $0
                    }
                }
            }
        }
    }

    // MARK: 4. Talk and deterrence

    private func talkSection(accent: Color, profile: CameraProfile) -> some View {
        GlassSection(title: profile.talkTitle, symbol: "mic.fill", accent: accent) {
            PushToTalkOrb(device: device, accent: accent, idleLabel: profile.talkIdle)
                .frame(maxWidth: .infinity)
            LiquidChipRow {
                if profile.hasSpotlight {
                    LiquidChip(
                        label: "Spotlight",
                        symbol: "flashlight.on.fill",
                        selected: device.spotlightOn,
                        accent: NexColors.gold
                    ) { device.spotlightOn.toggle() }
                }
                LiquidChip(
                    label: device.sirenOn ? "Siren on" : "Siren",
                    symbol: "speaker.wave.3.fill",
                    selected: device.sirenOn,
                    accent: NexColors.red
                ) { device.sirenOn.toggle() }
                LiquidChip(
                    label: "Privacy",
                    symbol: "eye.slash.fill",
                    selected: device.privacyMode,
                    accent: NexColors.violet
                ) { device.privacyMode.toggle() }
            }
            if device.sirenOn {
                NexText(
                    "Siren sounding · silences automatically in 30 s",
                    .caption,
                    color: NexColors.red
                )
            }
            if !profile.quickReplies.isEmpty {
                NexText("QUICK REPLIES", .caption, color: NexColors.secondary)
                LiquidChipRow {
                    ForEach(profile.quickReplies, id: \.self) { reply in
                        LiquidChip(
                            label: reply,
                            symbol: "waveform",
                            selected: speakingReply == reply,
                            accent: accent
                        ) { play(reply: reply) }
                    }
                }
            }
        }
    }

    private func play(reply: String) {
        speakingReply = reply
        device.talkActive = true
        device.cameraEvents = Array(
            ([CameraEvent(label: "Quick reply · \(reply)", minutesAgo: 0, seed: device.cameraSeed)]
                + device.cameraEvents).prefix(12)
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            device.talkActive = false
            speakingReply = nil
        }
    }

    // MARK: 5. Detection

    private func detectionSection(accent: Color, profile: CameraProfile) -> some View {
        let sensitivityPercent = (device.motionSensitivity * 100).rounded0
        let rangeFeet = (8 + 22 * device.motionSensitivity).rounded0

        return GlassSection(
            title: "Motion detection",
            symbol: "figure.walk.motion",
            accent: accent,
            trailing: AnyView(
                NexText(
                    device.motionSensitivity < 0.34
                        ? "Low"
                        : (device.motionSensitivity < 0.67 ? "Medium" : "High"),
                    .caption,
                    color: accent
                )
                .lineLimit(1)
            )
        ) {
            DetectionRadar(
                device: device,
                accent: accent,
                fieldOfView: profile.fieldOfView,
                wake: radarWake
            )
            .frame(height: 150)
            HStack {
                NexText("Sensitivity", .bodyStrong).lineLimit(1)
                Spacer()
                Text("\(sensitivityPercent)% · ~\(rangeFeet) ft")
                    .font(NexType.label.font.monospacedDigit())
                    .foregroundStyle(NexColors.secondary)
                    .lineLimit(1)
            }
            LiquidSlider(value: device.motionSensitivity, accent: accent) { value in
                device.motionSensitivity = value
                radarWake += 1
            }
            HStack {
                NexText("Pets & leaves", .caption, color: NexColors.tertiary).lineLimit(1)
                Spacer()
                NexText("Every movement", .caption, color: NexColors.tertiary).lineLimit(1)
            }
        }
    }

    // MARK: 6. Insights

    private func insightsSection(accent: Color, profile: CameraProfile) -> some View {
        var buckets = [Double](repeating: 0, count: 24)
        for event in device.cameraEvents {
            let hoursAgo = event.minutesAgo / 60
            if hoursAgo >= 0, hoursAgo <= 23 { buckets[23 - hoursAgo] += 1 }
        }
        let today = device.cameraEvents.filter { $0.minutesAgo < 24 * 60 }.count

        return GlassSection(title: "Insights", symbol: "chart.line.uptrend.xyaxis", accent: accent) {
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Events",
                    value: "\(today)",
                    unit: "today",
                    symbol: "figure.walk.motion",
                    accent: accent,
                    history: buckets
                )
                GlassMetricTile(
                    label: "Power",
                    value: "\(device.powerDrawWatts.rounded0)",
                    unit: "W",
                    symbol: "bolt.fill",
                    accent: NexColors.gold,
                    history: device.powerHistory
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                if profile.batteryPowered {
                    GlassMetricTile(
                        label: "Battery",
                        value: "\(device.batteryPercent)",
                        unit: "%",
                        symbol: batterySymbol(device.batteryPercent),
                        accent: batteryColor(device.batteryPercent)
                    )
                } else {
                    GlassMetricTile(
                        label: "Clips",
                        value: "\(device.cameraEvents.count)",
                        unit: "saved",
                        symbol: "icloud.and.arrow.up.fill",
                        accent: NexColors.blue
                    )
                }
                GlassMetricTile(
                    label: "Energy",
                    value: device.energyTodayKwh.fixed(2),
                    unit: "kWh",
                    symbol: "bolt.fill",
                    accent: NexColors.lime
                )
            }
        }
    }

    // MARK: 7. Event timeline

    private func eventsSection(accent: Color) -> some View {
        let events = device.cameraEvents
        let present = Set(events.map { category(of: $0.label) })
        let categories = EventFilter.allCases.filter { $0 == .all || present.contains($0) }
        let filtered = filter == .all ? events : events.filter { category(of: $0.label) == filter }

        return GlassSection(
            title: "Recent events",
            symbol: "clock.arrow.circlepath",
            accent: accent,
            trailing: AnyView(
                NexText("\(events.count) clips", .caption, color: NexColors.tertiary).lineLimit(1)
            )
        ) {
            if categories.count > 2 {
                LiquidChipRow {
                    ForEach(categories, id: \.self) { item in
                        LiquidChip(
                            label: item.label,
                            symbol: item.symbol,
                            selected: filter == item,
                            accent: item.color ?? accent
                        ) { filter = item }
                    }
                }
            }
            if filtered.isEmpty {
                NexText("No events to show", .body, color: NexColors.secondary)
            }
            ForEach(filtered.prefix(8)) { event in
                EventRow(
                    event: event,
                    playing: replay?.id == event.id,
                    accent: accent,
                    room: device.room.displayName
                ) {
                    replay = replay?.id == event.id ? nil : event
                }
            }
            NexText("Tap an event to replay it in the live view", .caption, color: NexColors.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: 8. Settings

    private func settingsSection(accent: Color, profile: CameraProfile) -> some View {
        GlassSection(title: "Camera", symbol: "slider.horizontal.3", accent: accent) {
            GlassSettingRow(
                title: "Continuous recording",
                symbol: "icloud.and.arrow.up.fill",
                subtitle: device.isRecording
                    ? "Saving 24/7 · 30-day cloud history"
                    : "Clips saved on events only",
                accent: NexColors.red
            ) {
                LiquidToggle(isOn: device.isRecording, accent: NexColors.red) {
                    device.isRecording = $0
                }
            }
            GlassSettingRow(
                title: "Privacy mode",
                symbol: "eye.slash.fill",
                subtitle: "Pauses video, audio and motion alerts",
                accent: NexColors.violet
            ) {
                LiquidToggle(isOn: device.privacyMode, accent: NexColors.violet) {
                    device.privacyMode = $0
                }
            }
            if profile.batteryPowered {
                let battery = device.batteryPercent
                GlassSettingRow(
                    title: "Battery",
                    symbol: batterySymbol(battery),
                    subtitle: battery < 20
                        ? "Low — recharge soon"
                        : "About \((Double(battery) * 0.9).rounded0) days remaining",
                    accent: battery < 20 ? NexColors.red : NexColors.mint
                ) {
                    Text("\(battery)%")
                        .font(NexType.bodyStrong.font.monospacedDigit())
                        .foregroundStyle(NexColors.primary)
                        .lineLimit(1)
                }
            }
            GlassSettingRow(
                title: "Wi-Fi",
                symbol: "wifi",
                subtitle: {
                    switch device.signalStrength {
                    case 4: return "Excellent connection"
                    case 3: return "Good connection"
                    case 2: return "Fair — streams may drop to SD"
                    default: return "Weak — move the router closer"
                    }
                }(),
                accent: NexColors.cyan
            ) {
                NexText("\(device.signalStrength)/4", .label, color: NexColors.secondary).lineLimit(1)
            }
            GlassSettingRow(
                title: "Video",
                symbol: "4k.tv.fill",
                subtitle: "\(profile.resolution) · \(profile.fieldOfView)° lens",
                accent: accent
            ) {
                NexText("15 fps", .label, color: NexColors.secondary).lineLimit(1)
            }
            GlassSettingRow(
                title: "Firmware",
                symbol: "memorychip.fill",
                subtitle: "Up to date",
                accent: NexColors.mint
            ) {
                NexText(device.firmwareVersion, .label, color: NexColors.secondary).lineLimit(1)
            }
        }
    }
}

// MARK: - Camera pieces

/// A recording dot that breathes.
struct PulsingDot: View {
    let color: Color

    var body: some View {
        PhaseTimeline(cyclesPerSecond: 0.8) { phase in
            ZStack {
                Circle()
                    .fill(color.opacity(0.5 * (1 - phase)))
                    .frame(width: 7 + 10 * CGFloat(phase))
                Circle().fill(color).frame(width: 7)
            }
            .frame(width: 17, height: 17)
        }
    }
}

/// The live clock over the feed.
private struct LiveClockText: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(context.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second()))
                .font(NexType.caption.font.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

/// Motion "lock-on" corner brackets that pop in and breathe.
private struct MotionReticle: View {
    let seed: Int
    let color: Color

    var body: some View {
        PhaseTimeline(cyclesPerSecond: 0.8) { phase in
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let sx = ((seed % 37) + 37) % 37
                let sy = (((seed / 37) % 29) + 29) % 29
                let cx = w * CGFloat(0.32 + Double(sx) / 36 * 0.36)
                let cy = h * CGFloat(0.36 + Double(sy) / 28 * 0.3)
                let breathe = 1 + 0.05 * sin(phase * 2 * .pi)
                let hw = w * 0.15 * CGFloat(breathe)
                let hh = h * 0.21 * CGFloat(breathe)
                let arm = min(hw, hh) * 0.45
                ZStack {
                    Path { path in
                        let left = cx - hw
                        let right = cx + hw
                        let top = cy - hh
                        let bottom = cy + hh
                        for corner in [
                            (CGPoint(x: left, y: top), arm, arm),
                            (CGPoint(x: right, y: top), -arm, arm),
                            (CGPoint(x: left, y: bottom), arm, -arm),
                            (CGPoint(x: right, y: bottom), -arm, -arm),
                        ] {
                            path.move(to: corner.0)
                            path.addLine(to: CGPoint(x: corner.0.x + corner.1, y: corner.0.y))
                            path.move(to: corner.0)
                            path.addLine(to: CGPoint(x: corner.0.x, y: corner.0.y + corner.2))
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    Circle()
                        .fill(color.opacity(0.55))
                        .frame(width: 6)
                        .position(x: cx, y: cy)
                }
            }
        }
        .allowsHitTesting(false)
        .transition(.scale.combined(with: .opacity))
    }
}

/// A round glass joystick well with a draggable knob. Deflection is a rate: while held, the camera
/// pans and tilts continuously. On release the knob springs home with a bouncy overshoot.
private struct PtzJoystick: View {
    @Bindable var device: Device
    let accent: Color

    @State private var knob: CGSize = .zero
    @State private var dragging = false
    @State private var steer: Task<Void, Never>?
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: Color.black.opacity(0.22),
            heavy: true,
            surface: AnyView(JoystickWell(device: device, accent: accent))
        ) {
            GeometryReader { proxy in
                let travel = max(min(proxy.size.width, proxy.size.height) / 2 - 34, 1)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(dragging ? 0.35 : 0.85))
                        .overlay {
                            Circle()
                                .strokeBorder(accent.opacity(dragging ? 0.9 : 0.4), lineWidth: 2)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())
                        .frame(width: 56, height: 56)
                        .scaleEffect(dragging ? 1.12 : 1)
                        .offset(knob)
                        .shadow(color: accent.opacity(dragging ? 0.5 : 0.2), radius: 12)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                            var vx = (value.location.x - center.x) / travel
                            var vy = (value.location.y - center.y) / travel
                            let length = (vx * vx + vy * vy).squareRoot()
                            if length > 1 {
                                // Rubber band past the rim.
                                let scaled = 1 + 0.18 * rubberBand(length - 1)
                                vx = vx / length * scaled
                                vy = vy / length * scaled
                            }
                            withAnimation(.spring(response: 0.209, dampingFraction: 0.62)) {
                                knob = CGSize(width: vx * travel, height: vy * travel)
                            }
                            if !dragging {
                                dragging = true
                                light?.begin(
                                    token,
                                    at: CGPoint(x: frame.midX, y: frame.midY),
                                    color: accent
                                )
                                startSteering()
                            }
                            light?.move(
                                token,
                                to: CGPoint(
                                    x: frame.midX + vx * travel,
                                    y: frame.midY + vy * travel
                                )
                            )
                        }
                        .onEnded { _ in
                            dragging = false
                            steer?.cancel()
                            steer = nil
                            light?.end(token)
                            withAnimation(GlassMotion.release) { knob = .zero }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }

    /// While held, the deflection is applied as a pan/tilt rate at ~30 Hz.
    private func startSteering() {
        steer?.cancel()
        steer = Task { @MainActor in
            while !Task.isCancelled {
                let travel = max(frame.width / 2 - 34, 1)
                let vx = clamp(knob.width / travel, -1, 1)
                let vy = clamp(knob.height / travel, -1, 1)
                if abs(vx) > 0.08 {
                    device.panX = clamp(device.panX + Double(vx) * 0.02, -1, 1)
                }
                if abs(vy) > 0.08 {
                    device.panY = clamp(device.panY + Double(vy) * 0.02, -1, 1)
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }
}

/// The joystick well's live viewport minimap: the full field of view with the current crop inside.
private struct JoystickWell: View {
    let device: Device
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let r = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let frameW = r * 1.1
            let frameH = frameW * 0.6
            let crop = 1 / max(device.zoom, 1)
            ZStack {
                ForEach(1..<3, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: r * 2 * CGFloat(ring) / 3)
                        .position(center)
                }
                Path { path in
                    path.move(to: CGPoint(x: center.x - r * 0.9, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + r * 0.9, y: center.y))
                    path.move(to: CGPoint(x: center.x, y: center.y - r * 0.9))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + r * 0.9))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                // Field of view and the current crop.
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    .frame(width: frameW, height: frameH)
                    .position(center)
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(accent, lineWidth: 1.5)
                    .frame(width: frameW * CGFloat(crop), height: frameH * CGFloat(crop))
                    .position(
                        x: center.x + CGFloat(device.panX) * frameW * (1 - CGFloat(crop)) / 2,
                        y: center.y + CGFloat(device.panY) * frameH * (1 - CGFloat(crop)) / 2
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Push-to-talk glass orb: while held, `talkActive` is true, the orb floods with `accent` and a
/// live voice ring of bars dances inside the rim.
private struct PushToTalkOrb: View {
    @Bindable var device: Device
    let accent: Color
    let idleLabel: String

    @State private var holding = false
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    var body: some View {
        VStack(spacing: 10) {
            GlassPanel(
                shape: glassCircle,
                tint: Color.black.opacity(0.16),
                accent: accent,
                heavy: true,
                interactive: true,
                pressScale: GlassMotion.orbPressScale,
                surface: AnyView(accent.opacity(holding ? 0.4 : 0)),
                front: AnyView(VoiceRing(active: holding, accent: accent))
            ) {
                Image(systemName: holding ? "waveform" : "mic.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 132)
            }
            .scaleEffect(holding ? 1.06 : 1)
            .shadow(color: accent.opacity(holding ? 0.6 : 0.15), radius: holding ? 36 : 16)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !holding else { return }
                        holding = true
                        device.talkActive = true
                        Haptics.tap()
                        light?.begin(
                            token,
                            at: CGPoint(x: frame.midX, y: frame.midY),
                            color: accent
                        )
                    }
                    .onEnded { _ in
                        holding = false
                        device.talkActive = false
                        light?.end(token)
                    }
            )
            NexText(holding ? "Speaking…" : idleLabel, .bodyStrong).lineLimit(1)
            NexText(
                holding ? "Release to stop" : "Two-way audio",
                .caption,
                color: NexColors.tertiary
            )
            .lineLimit(1)
        }
        .animation(GlassMotion.release, value: holding)
    }
}

private struct VoiceRing: View {
    let active: Bool
    let accent: Color

    var body: some View {
        PhaseTimeline(cyclesPerSecond: active ? 1.2 : 0) { phase in
            GeometryReader { proxy in
                let r = min(proxy.size.width, proxy.size.height) / 2
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                if active {
                    ForEach(0..<36, id: \.self) { index in
                        let angle = radians(Double(index) * 10)
                        let wave = 0.5 + 0.5 * sin(Double(index) * 0.7 + phase * 2 * .pi * 3)
                        let length = r * CGFloat(0.06 + 0.1 * wave)
                        Capsule()
                            .fill(Color.white.opacity(0.4 + 0.5 * wave))
                            .frame(width: 2, height: length)
                            .offset(y: -(r * 0.86 - length / 2))
                            .rotationEffect(.radians(angle + .pi / 2))
                            .position(center)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Glass radar panel: the camera's field-of-view fan with range rings, a detection zone whose reach
/// follows sensitivity, recent events as blips, and a sweep while motion is live.
private struct DetectionRadar: View {
    let device: Device
    let accent: Color
    let fieldOfView: Int
    let wake: Int

    var body: some View {
        let paused = device.privacyMode || !device.isOn
        let scanning = !paused && device.motionDetected
        let blips = device.cameraEvents.prefix(10).map { event -> (Double, Double, Double, Color) in
            let s = ((event.seed % 9999) + 9999) % 9999
            return (
                Double((s * 7919) % 1000) / 1000,
                0.25 + Double((s * 104729) % 1000) / 1000 * 0.7,
                clamp(1 - Double(event.minutesAgo) / 240, 0.18, 1),
                category(of: event.label).color ?? accent
            )
        }

        GlassPanel(
            shape: glassRect(22),
            tint: NexColors.glassTintLight,
            accent: accent,
            interactive: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: scanning ? 0.4 : 0) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        let origin = CGPoint(x: w / 2, y: h - 14)
                        let reach = h * 0.86
                        let half = Double(fieldOfView) / 2
                        ZStack {
                            // Range rings.
                            ForEach(1..<4, id: \.self) { ring in
                                let rr = reach * CGFloat(ring) / 3
                                Path { path in
                                    path.addArc(
                                        center: origin,
                                        radius: rr,
                                        startAngle: .degrees(-90 - half),
                                        endAngle: .degrees(-90 + half),
                                        clockwise: false
                                    )
                                }
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            }
                            // The detection zone.
                            Path { path in
                                path.move(to: origin)
                                path.addArc(
                                    center: origin,
                                    radius: reach * CGFloat(0.35 + 0.65 * device.motionSensitivity),
                                    startAngle: .degrees(-90 - half),
                                    endAngle: .degrees(-90 + half),
                                    clockwise: false
                                )
                                path.closeSubpath()
                            }
                            .fill(accent.opacity(paused ? 0.06 : 0.16))
                            .animation(
                                .spring(response: 0.444, dampingFraction: 0.45),
                                value: device.motionSensitivity
                            )
                            // Sweep.
                            if scanning {
                                let a = -90 - half + (2 * half) * phase
                                Path { path in
                                    path.move(to: origin)
                                    path.addLine(
                                        to: CGPoint(
                                            x: origin.x + cos(radians(a)) * reach,
                                            y: origin.y + sin(radians(a)) * reach
                                        )
                                    )
                                }
                                .stroke(accent.opacity(0.7), lineWidth: 2)
                            }
                            // Blips.
                            ForEach(Array(blips.enumerated()), id: \.offset) { _, blip in
                                let a = -90 - half + 2 * half * blip.0
                                Circle()
                                    .fill(blip.3.opacity(blip.2))
                                    .frame(width: 7)
                                    .position(
                                        x: origin.x + cos(radians(a)) * reach * CGFloat(blip.1),
                                        y: origin.y + sin(radians(a)) * reach * CGFloat(blip.1)
                                    )
                            }
                            // The camera itself.
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 10)
                                .position(origin)
                        }
                    }
                }
            )
        ) {
            VStack {
                HStack {
                    NexText("\(fieldOfView)° field of view", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText(
                        paused ? "Paused" : (device.motionDetected ? "Motion now" : "Clear"),
                        .caption,
                        color: device.motionDetected && !paused ? accent : NexColors.tertiary
                    )
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
        }
    }
}

/// One timeline row: a glass-framed thumbnail with a play orb, label and time.
private struct EventRow: View {
    let event: CameraEvent
    let playing: Bool
    let accent: Color
    let room: String
    let action: () -> Void

    var body: some View {
        let item = category(of: event.label)
        let color = item.color ?? accent

        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintLight,
            accent: color,
            action: action,
            surface: AnyView(color.opacity(playing ? 0.18 : 0))
        ) {
            HStack(spacing: 12) {
                ZStack {
                    AsyncImage(url: URL(string: "https://picsum.photos/seed/nexhome\(event.seed)/240/160")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color(hex: 0x12181F)
                        }
                    }
                    .frame(width: 72, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                }
                VStack(alignment: .leading, spacing: 2) {
                    NexText(event.label, .bodyStrong).lineLimit(1)
                    NexText("\(room) · \(eventTime(event.minutesAgo))", .caption, color: NexColors.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                    NexText(agoText(event.minutesAgo), .caption, color: NexColors.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func eventTime(_ minutesAgo: Int) -> String {
        let date = Date.now.addingTimeInterval(-Double(minutesAgo) * 60)
        return date.formatted(.dateTime.hour().minute())
    }
}

// MARK: - Camera profiles and helpers

private let nightVisionGreen = Color(hex: 0x7CFF8A)

struct ViewPreset {
    let label: String
    let symbol: String
    let panX: Double
    let panY: Double
    let zoom: Double
}

struct CameraProfile {
    let aspectRatio: Double
    let fieldOfView: Int
    let hasSpotlight: Bool
    let batteryPowered: Bool
    let resolution: String
    let talkTitle: String
    let talkIdle: String
    let presets: [ViewPreset]
    let quickReplies: [String]
}

private func cameraProfile(_ type: DeviceType) -> CameraProfile {
    switch type {
    case .doorbellCamera:
        return CameraProfile(
            aspectRatio: 4.0 / 5.0,
            fieldOfView: 160,
            hasSpotlight: true,
            batteryPowered: true,
            resolution: "1536p head-to-toe",
            talkTitle: "Answer the door",
            talkIdle: "Hold to answer",
            presets: [
                ViewPreset(label: "Wide", symbol: "mountain.2.fill", panX: 0, panY: 0, zoom: 1),
                ViewPreset(label: "Visitor", symbol: "face.smiling", panX: 0, panY: -0.45, zoom: 1.9),
                ViewPreset(label: "Package", symbol: "shippingbox.fill", panX: 0, panY: 0.85, zoom: 2.4),
                ViewPreset(label: "Walkway", symbol: "figure.walk", panX: 0.55, panY: 0.2, zoom: 1.6),
            ],
            quickReplies: [
                "Be right there", "Leave it at the door", "We can't come to the door",
            ]
        )
    case .outdoorCamera:
        return CameraProfile(
            aspectRatio: 16.0 / 9.0,
            fieldOfView: 110,
            hasSpotlight: true,
            batteryPowered: true,
            resolution: "2K HDR",
            talkTitle: "Talk & deter",
            talkIdle: "Hold to talk",
            presets: [
                ViewPreset(label: "Wide", symbol: "mountain.2.fill", panX: 0, panY: 0, zoom: 1),
                ViewPreset(label: "Driveway", symbol: "car.fill", panX: -0.6, panY: 0.35, zoom: 2.2),
                ViewPreset(label: "Gate", symbol: "fence", panX: 0.8, panY: -0.1, zoom: 2.6),
                ViewPreset(label: "Yard", symbol: "leaf.fill", panX: 0.2, panY: 0.6, zoom: 1.5),
            ],
            quickReplies: []
        )
    default:
        return CameraProfile(
            aspectRatio: 16.0 / 10.0,
            fieldOfView: 130,
            hasSpotlight: false,
            batteryPowered: false,
            resolution: "1080p",
            talkTitle: "Talk & deter",
            talkIdle: "Hold to talk",
            presets: [
                ViewPreset(label: "Overview", symbol: "house.fill", panX: 0, panY: 0, zoom: 1),
                ViewPreset(label: "Doorway", symbol: "door.left.hand.closed", panX: -0.7, panY: 0, zoom: 1.8),
                ViewPreset(label: "Window", symbol: "window.vertical.closed", panX: 0.75, panY: -0.3, zoom: 2),
                ViewPreset(label: "Floor", symbol: "pawprint.fill", panX: 0, panY: 0.8, zoom: 1.6),
            ],
            quickReplies: []
        )
    }
}

private func isNightNow() -> Bool {
    let hour = Calendar.current.component(.hour, from: .now)
    return hour >= 19 || hour < 7
}

private func formatZoom(_ zoom: Double) -> String { zoom.fixed(1) + "×" }

private func agoText(_ minutes: Int) -> String {
    if minutes < 1 { return "now" }
    if minutes < 60 { return "\(minutes)m ago" }
    if minutes < 60 * 24 { return "\(minutes / 60)h ago" }
    return "\(minutes / (60 * 24))d ago"
}

enum EventFilter: CaseIterable, Hashable {
    case all, people, vehicles, animals, packages, rings, sound, motion, actions

    var label: String {
        switch self {
        case .all: return "All"
        case .people: return "People"
        case .vehicles: return "Vehicles"
        case .animals: return "Animals"
        case .packages: return "Packages"
        case .rings: return "Rings"
        case .sound: return "Sound"
        case .motion: return "Motion"
        case .actions: return "Actions"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "clock.arrow.circlepath"
        case .people: return "person.fill"
        case .vehicles: return "car.fill"
        case .animals: return "pawprint.fill"
        case .packages: return "shippingbox.fill"
        case .rings: return "bell.fill"
        case .sound: return "ear.fill"
        case .motion: return "figure.walk.motion"
        case .actions: return "camera.fill"
        }
    }

    var color: Color? {
        switch self {
        case .all: return nil
        case .people: return NexColors.red
        case .vehicles: return NexColors.amber
        case .animals: return NexColors.mint
        case .packages: return NexColors.gold
        case .rings: return NexColors.orange
        case .sound: return NexColors.violet
        case .motion: return NexColors.cyan
        case .actions: return NexColors.blue
        }
    }
}

private func category(of label: String) -> EventFilter {
    let lower = label.lowercased()
    if lower.contains("person") { return .people }
    if lower.contains("vehicle") { return .vehicles }
    if lower.contains("animal") || lower.contains("pet") { return .animals }
    if lower.contains("package") { return .packages }
    if lower.contains("doorbell") { return .rings }
    if lower.contains("sound") { return .sound }
    if lower.contains("snapshot") || lower.contains("reply") { return .actions }
    return .motion
}
