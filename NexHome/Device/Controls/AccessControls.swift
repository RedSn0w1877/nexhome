import SwiftUI

// MARK: - Shared access pieces

/// Battery, connection, firmware and favourite rows, shared by the lock, garage and panel sheets.
struct DeviceCareRows: View {
    @Bindable var device: Device
    var showBattery: Bool

    var body: some View {
        if showBattery {
            let percent = device.batteryPercent
            let color = batteryColor(percent)
            GlassSettingRow(
                title: "Battery",
                symbol: batterySymbol(percent),
                subtitle: percent <= 20
                    ? "Replace soon · about \(max(percent / 5, 1)) weeks left"
                    : "About \(max(Int((Double(percent) / 9).rounded()), 1)) months left",
                accent: color
            ) {
                Text("\(percent)%")
                    .font(NexType.bodyStrong.font.monospacedDigit())
                    .foregroundStyle(NexColors.primary)
                    .lineLimit(1)
            }
            GlassLevelBar(fraction: Double(percent) / 100, color: color)
        }
        GlassSettingRow(
            title: "Connection",
            symbol: "wifi",
            subtitle: device.isOnline ? signalLabel(device.signalStrength) : "Offline",
            accent: NexColors.cyan
        ) {
            SignalBars(strength: device.signalStrength, accent: NexColors.cyan)
        }
        GlassSettingRow(
            title: "Firmware",
            symbol: "arrow.down.circle.fill",
            subtitle: "Up to date",
            accent: NexColors.violet
        ) {
            NexText("v\(device.firmwareVersion)", .caption, color: NexColors.tertiary).lineLimit(1)
        }
        GlassSettingRow(
            title: "Favorite",
            symbol: "star.fill",
            subtitle: "Pin to the Home screen",
            accent: NexColors.gold
        ) {
            LiquidToggle(isOn: device.isFavorite, accent: NexColors.gold) { device.isFavorite = $0 }
        }
    }
}

/// Newest-first activity rows.
struct ActivityTimeline: View {
    let events: [ActivityEvent]
    let symbolFor: (ActivityEvent) -> String
    let colorFor: (ActivityEvent) -> Color

    var body: some View {
        if events.isEmpty {
            NexText("No activity yet", .label, color: NexColors.secondary)
        } else {
            ForEach(events.prefix(6)) { event in
                GlassSettingRow(
                    title: event.label,
                    symbol: symbolFor(event),
                    subtitle: event.detail,
                    accent: colorFor(event)
                ) {
                    NexText(agoLabel(event.minutesAgo), .caption, color: NexColors.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// A titled glass section that can be washed red while the alarm is triggered.
struct AlarmSection<Content: View>: View {
    let title: String
    let symbol: String
    let accent: Color
    var wash: Double = 0
    var pulse: Double = 0
    var trailing: AnyView?
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassPanel(
            shape: glassRect(28),
            tint: NexColors.glassTintDark,
            heavy: true,
            surface: AnyView(NexColors.red.opacity(wash * (0.1 + 0.22 * pulse)))
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                    NexText(title.uppercased(), .caption, color: NexColors.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if let trailing { trailing }
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .overlay {
            if wash > 0.02 {
                glassRect(28)
                    .stroke(
                        NexColors.red.opacity(0.5 * wash * (0.4 + 0.6 * pulse)),
                        lineWidth: lerp(1, 4, CGFloat(wash * pulse))
                    )
                    .clipShape(glassRect(28))
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Door lock / interior door (ControlKind.lock)

/// Lock sheet: a glass stage with a shackle that lifts out when unlocking and slams back in when
/// locking, the auto-lock countdown as a ring around the hold orb, a live top-down door plan
/// (leaf swing + deadbolt), auto-lock settings, guest codes, an activity timeline and device care.
struct LockControls: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let accent = deviceAccent(device.type)
        let locked = device.lockState == .locked
        let ajar = device.doorAjar
        let stateColor = lockColor(locked: locked, ajar: ajar, accent: accent)
        let counting = !locked && device.autoLockEnabled && !ajar

        VStack(spacing: 16) {
            GlassSection(
                title: device.type == .entryLock ? "Door lock" : "Interior door",
                symbol: locked ? "lock.fill" : "lock.open.fill",
                accent: stateColor,
                trailing: AnyView(
                    StatusBadge(
                        text: lockBadge(locked: locked, ajar: ajar),
                        color: stateColor,
                        pulsing: ajar || counting
                    )
                )
            ) {
                HeroStage {
                    LockScene(color: stateColor, unlatch: locked ? 0 : 1, ajar: ajar)
                        .animation(.spring(response: 0.456, dampingFraction: 0.38), value: locked)
                } content: {
                    VStack(spacing: 18) {
                        Spacer().frame(height: 72)
                        LiquidHoldOrb(
                            label: locked ? "Hold to unlock" : "Hold to lock",
                            symbol: locked ? "lock.fill" : "lock.open.fill",
                            accent: locked ? accent : (ajar ? ajarColor : unlockedColor),
                            active: locked,
                            size: 132,
                            sublabel: lockSublabel(device, counting: counting)
                        ) {
                            repository.setLocked(device, device.lockState != .locked)
                        }
                        HStack(spacing: 0) {
                            Readout(
                                symbol: batterySymbol(device.batteryPercent),
                                value: "\(device.batteryPercent)%",
                                label: "Battery",
                                tint: batteryColor(device.batteryPercent)
                            )
                            Readout(
                                symbol: ajar ? "door.left.hand.open" : "door.left.hand.closed",
                                value: ajar ? "Ajar" : "Closed",
                                label: "Door",
                                tint: ajar ? ajarColor : NexColors.cyan
                            )
                            Readout(
                                symbol: "lock.badge.clock",
                                value: device.autoLockEnabled
                                    ? durationLabel(device.autoLockSeconds)
                                    : "Off",
                                label: "Auto-lock",
                                tint: accent
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                NexText(lockStatusLine(device), .label, color: NexColors.secondary)
            }

            // Door sensor.
            GlassSection(title: "Door sensor", symbol: "door.left.hand.open", accent: accent) {
                GlassPanel(
                    shape: glassRect(22),
                    tint: NexColors.glassTintLight,
                    surface: AnyView(
                        DoorPlan(color: stateColor, unlatch: locked ? 0 : 1, swing: ajar ? 1 : 0)
                            .animation(.spring(response: 0.574, dampingFraction: 0.45), value: ajar)
                    )
                ) {
                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            NexText(
                                ajar ? "Door ajar" : "Door closed",
                                .bodyStrong,
                                color: ajar ? ajarColor : NexColors.primary
                            )
                            .lineLimit(1)
                            NexText(
                                locked ? "Deadbolt extended" : "Deadbolt retracted",
                                .caption,
                                color: NexColors.secondary
                            )
                            .lineLimit(1)
                            NexText("Contact sensor · live", .caption, color: NexColors.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(height: 132)
                    .padding(.trailing, 18)
                }
                if ajar {
                    GlassSettingRow(
                        title: "Door left open",
                        symbol: "exclamationmark.triangle.fill",
                        subtitle: "Auto-lock waits until the door closes",
                        accent: ajarColor
                    ) {
                        LiquidButton(tint: ajarColor, action: { device.doorAjar = false }) {
                            NexText("It's closed", .label).lineLimit(1)
                        }
                    }
                }
            }

            // Auto-lock.
            GlassSection(title: "Auto-lock", symbol: "lock.badge.clock", accent: accent) {
                GlassSettingRow(
                    title: "Auto-lock",
                    symbol: "timer",
                    subtitle: device.autoLockEnabled
                        ? "Locks \(durationLabel(device.autoLockSeconds)) after unlocking"
                        : "Stays unlocked until you lock it",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.autoLockEnabled, accent: accent) {
                        device.autoLockEnabled = $0
                    }
                }
                if device.autoLockEnabled {
                    GlassSettingRow(
                        title: "Lock after",
                        symbol: "hourglass",
                        subtitle: "Paused while the door is ajar",
                        accent: accent
                    ) {
                        LiquidIntStepper(
                            value: device.autoLockSeconds,
                            range: 15...600,
                            step: 15,
                            format: durationLabel,
                            accent: accent
                        ) { device.autoLockSeconds = $0 }
                    }
                    LiquidChipRow {
                        ForEach([30, 60, 120, 300], id: \.self) { seconds in
                            LiquidChip(
                                label: durationLabel(seconds),
                                selected: device.autoLockSeconds == seconds,
                                accent: accent
                            ) { device.autoLockSeconds = seconds }
                        }
                    }
                }
            }

            if device.type == .entryLock {
                GuestAccessSection(device: device, accent: accent)
            }

            // Activity.
            GlassSection(title: "Activity", symbol: "clock.arrow.circlepath", accent: accent) {
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Unlocks today",
                        value: "\(device.lockActivity.filter { $0.label == "Unlocked" && $0.minutesAgo < 1440 }.count)",
                        symbol: "lock.open.fill",
                        accent: unlockedColor
                    )
                    GlassMetricTile(
                        label: "Events logged",
                        value: "\(device.lockActivity.count)",
                        symbol: "clock.arrow.circlepath",
                        accent: accent
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                ActivityTimeline(
                    events: device.lockActivity,
                    symbolFor: lockEventSymbol,
                    colorFor: { lockEventColor($0, accent) }
                )
            }

            GlassSection(title: "Device", symbol: "slider.horizontal.3", accent: accent) {
                DeviceCareRows(device: device, showBattery: true)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.autoLockEnabled)
        .animation(.easeInOut(duration: 0.3), value: ajarKey)
    }

    private var ajarKey: Bool { device.doorAjar }
}

private struct GuestAccessSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        let guests = device.guestAccess
        let available = guestPresets.filter { !guests.contains($0) }

        GlassSection(
            title: "Guest access",
            symbol: "key.fill",
            accent: accent,
            trailing: AnyView(
                NexText(
                    guests.isEmpty ? "None" : "\(guests.count) active",
                    .caption,
                    color: NexColors.tertiary
                )
                .lineLimit(1)
            )
        ) {
            if guests.isEmpty {
                NexText("No guest codes. Add one below.", .label, color: NexColors.secondary)
            }
            ForEach(guests, id: \.self) { entry in
                GlassSettingRow(
                    title: String(entry.split(separator: " · ").first ?? ""),
                    symbol: guestSymbol(entry),
                    subtitle: entry.contains(" · ")
                        ? String(entry.split(separator: " · ").dropFirst().joined(separator: " · "))
                        : "Always",
                    accent: accent
                ) {
                    LiquidButton(
                        surfaceColor: Color.white.opacity(0.08),
                        action: { device.guestAccess.removeAll { $0 == entry } }
                    ) {
                        NexText("Revoke", .label).lineLimit(1)
                    }
                }
            }
            if !available.isEmpty {
                NexText("Quick add", .caption, color: NexColors.tertiary)
                LiquidChipRow {
                    ForEach(available, id: \.self) { preset in
                        LiquidChip(
                            label: String(preset.split(separator: " · ").first ?? ""),
                            symbol: "person.badge.plus",
                            selected: false,
                            accent: accent
                        ) { device.guestAccess.append(preset) }
                    }
                }
            }
        }
    }
}

/// The lock stage: a padlock shackle that lifts out of the body as the bolt retracts.
private struct LockScene: View {
    let color: Color
    let unlatch: Double
    let ajar: Bool

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let cx = w / 2
            let bodyTop: CGFloat = 62
            let lift = CGFloat(unlatch) * 22
            ZStack {
                RadialGradient(
                    colors: [color.opacity(0.22), .clear],
                    center: UnitPoint(x: 0.5, y: 0.22),
                    startRadius: 0,
                    endRadius: w * 0.55
                )
                .blendMode(.plusLighter)

                // Shackle.
                Path { path in
                    path.addArc(
                        center: CGPoint(x: cx, y: bodyTop - lift),
                        radius: 26,
                        startAngle: .degrees(200),
                        endAngle: .degrees(340),
                        clockwise: false
                    )
                }
                .stroke(
                    Color.white.opacity(0.85).lerp(to: color, unlatch),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(unlatch * 12), anchor: .center)
                .offset(y: -CGFloat(unlatch) * 4)

                // Body.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(color.opacity(0.75), lineWidth: 1.5)
                    }
                    .frame(width: 64, height: 46)
                    .position(x: cx, y: bodyTop + 24)

                if ajar {
                    Circle()
                        .strokeBorder(ajarColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 96)
                        .position(x: cx, y: bodyTop + 10)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Top-down door plan: the leaf swings open as the contact sensor reports ajar, and the deadbolt
/// slides out of the jamb as the lock engages.
private struct DoorPlan: View {
    let color: Color
    let unlatch: Double
    let swing: Double

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let hingeX = w * 0.16
            let hingeY = h * 0.78
            let length = w * 0.42
            let angle = -swing * 62

            ZStack {
                // Wall and frame.
                Path { path in
                    path.move(to: CGPoint(x: w * 0.06, y: hingeY))
                    path.addLine(to: CGPoint(x: hingeX, y: hingeY))
                    path.move(to: CGPoint(x: hingeX + length, y: hingeY))
                    path.addLine(to: CGPoint(x: w * 0.72, y: hingeY))
                }
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // Swing guide.
                Path { path in
                    path.addArc(
                        center: CGPoint(x: hingeX, y: hingeY),
                        radius: length,
                        startAngle: .degrees(-62),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(
                    Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )

                // The leaf.
                Capsule()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: length, height: 7)
                    .offset(x: length / 2)
                    .rotationEffect(.degrees(angle), anchor: .leading)
                    .position(x: hingeX, y: hingeY)

                // Deadbolt sliding into the jamb.
                Capsule()
                    .fill(color)
                    .frame(width: 20, height: 5)
                    .position(
                        x: hingeX + length + 4 + CGFloat(1 - unlatch) * 10,
                        y: hingeY - 14
                    )

                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 7)
                    .position(x: hingeX, y: hingeY)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Garage door (ControlKind.garage)

/// Garage sheet: a glass house-front stage whose roll-up door slats follow the live door position,
/// a car and a warm ceiling light inside, a photo-eye beam that flares red on an obstruction, a hold
/// orb that opens, closes or reverses, then safety, automation, activity and device care.
struct GarageControls: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository
    @State private var lastAutoClose = 10

    var body: some View {
        let accent = deviceAccent(device.type)
        let moving = device.garageState == .moving
        let obstructed = device.obstructionDetected
        let stateColor = garageColor(device, accent)

        VStack(spacing: 16) {
            GlassSection(
                title: "Garage door",
                symbol: "door.garage.closed",
                accent: stateColor,
                trailing: AnyView(
                    StatusBadge(
                        text: garageBadge(device),
                        color: stateColor,
                        pulsing: moving || obstructed
                    )
                )
            ) {
                HeroStage {
                    GarageScene(
                        color: stateColor,
                        door: device.doorPosition,
                        light: device.garageLightOn ? 1 : 0,
                        obstructed: obstructed,
                        moving: moving
                    )
                    .animation(.spring(response: 0.531, dampingFraction: 1), value: device.doorPosition)
                    .animation(.spring(response: 0.662, dampingFraction: 1), value: device.garageLightOn)
                } content: {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 196)
                        garageHoldOrb(accent: accent)
                        HStack(spacing: 0) {
                            Readout(
                                symbol: "arrow.up.arrow.down",
                                value: "\((device.doorPosition * 100).rounded0)%",
                                label: "Open",
                                tint: stateColor
                            )
                            Readout(
                                symbol: "lightbulb.fill",
                                value: device.garageLightOn ? "On" : "Off",
                                label: "Light",
                                tint: device.garageLightOn ? garageLightColor : NexColors.tertiary
                            )
                            Readout(
                                symbol: "timer",
                                value: device.autoCloseMinutes > 0
                                    ? "\(device.autoCloseMinutes) min"
                                    : "Off",
                                label: "Auto-close",
                                tint: accent
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }
                NexText(garageStatusLine(device), .label, color: NexColors.secondary)
            }

            // Safety.
            GlassSection(title: "Safety", symbol: "sensor.fill", accent: accent) {
                GlassSettingRow(
                    title: "Photo-eye sensor",
                    symbol: "sensor.fill",
                    subtitle: obstructed
                        ? "Beam blocked · a closing door reverses"
                        : "Beam clear · tap Test to simulate a block",
                    accent: obstructed ? NexColors.red : NexColors.mint
                ) {
                    if obstructed {
                        LiquidButton(
                            tint: NexColors.red,
                            action: { device.obstructionDetected = false }
                        ) {
                            NexText("Clear", .label).lineLimit(1)
                        }
                    } else {
                        LiquidButton(
                            surfaceColor: Color.white.opacity(0.08),
                            action: { device.obstructionDetected = true }
                        ) {
                            NexText("Test", .label).lineLimit(1)
                        }
                    }
                }
                GlassSettingRow(
                    title: "Door travel",
                    symbol: "arrow.up.arrow.down",
                    subtitle: "Full open or close in about 9 s",
                    accent: accent
                ) {
                    Text("\((device.doorPosition * 100).rounded0)%")
                        .font(NexType.bodyStrong.font.monospacedDigit())
                        .foregroundStyle(NexColors.primary)
                        .lineLimit(1)
                }
            }

            // Automation.
            GlassSection(title: "Automation", symbol: "clock.fill", accent: accent) {
                GlassSettingRow(
                    title: "Auto-close",
                    symbol: "timer",
                    subtitle: device.autoCloseMinutes > 0
                        ? "Closes \(device.autoCloseMinutes) min after opening"
                        : "The door stays open until you close it",
                    accent: accent
                ) {
                    LiquidToggle(isOn: device.autoCloseMinutes > 0, accent: accent) { on in
                        device.autoCloseMinutes = on ? lastAutoClose : 0
                    }
                }
                if device.autoCloseMinutes > 0 {
                    LiquidSegmented(
                        options: autoCloseMinutes.map { SegmentOption("\($0) min") },
                        selectedIndex: nearestIndex(autoCloseMinutes, device.autoCloseMinutes),
                        accent: accent
                    ) { index in
                        lastAutoClose = autoCloseMinutes[index]
                        device.autoCloseMinutes = autoCloseMinutes[index]
                    }
                }
                GlassSettingRow(
                    title: "Garage light",
                    symbol: "lightbulb.fill",
                    subtitle: device.garageLightOn ? "On · ceiling light" : "Off",
                    accent: garageLightColor
                ) {
                    LiquidToggle(isOn: device.garageLightOn, accent: garageLightColor) {
                        device.garageLightOn = $0
                    }
                }
            }

            // Activity.
            GlassSection(title: "Activity", symbol: "clock.arrow.circlepath", accent: accent) {
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Opens today",
                        value: "\(device.garageActivity.filter { $0.label == "Opened" && $0.minutesAgo < 1440 }.count)",
                        symbol: "chevron.up.2",
                        accent: accent
                    )
                    GlassMetricTile(
                        label: "Power",
                        value: "\(device.powerDrawWatts.rounded0)",
                        unit: "W",
                        symbol: "bolt.fill",
                        accent: garageLightColor,
                        history: device.powerHistory
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                ActivityTimeline(
                    events: device.garageActivity,
                    symbolFor: garageEventSymbol,
                    colorFor: { garageEventColor($0, accent) }
                )
            }

            GlassSection(title: "Device", symbol: "slider.horizontal.3", accent: accent) {
                DeviceCareRows(device: device, showBattery: false)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: device.autoCloseMinutes > 0)
        .task { if device.autoCloseMinutes > 0 { lastAutoClose = device.autoCloseMinutes } }
    }

    private func garageHoldOrb(accent: Color) -> some View {
        let state = device.garageState
        let moving = state == .moving
        let opensNext = state == .closed || (moving && !device.garageOpening)
        return LiquidHoldOrb(
            label: moving
                ? (opensNext ? "Hold to reverse up" : "Hold to reverse down")
                : (opensNext ? "Hold to open" : "Hold to close"),
            symbol: moving
                ? (opensNext ? "arrow.up" : "arrow.down")
                : (opensNext ? "chevron.up.2" : "chevron.down.2"),
            accent: device.obstructionDetected ? NexColors.red : accent,
            active: state != .closed,
            holdMillis: 700,
            size: 120,
            sublabel: garageSublabel(device)
        ) {
            toggleGarage(repository, device)
        }
    }
}

/// The garage stage: a house front with roll-up slats, a car, a ceiling light and the photo-eye.
private struct GarageScene: View {
    let color: Color
    let door: Double
    let light: Double
    let obstructed: Bool
    let moving: Bool

    var body: some View {
        PhaseTimeline(cyclesPerSecond: obstructed ? 1.3 : (moving ? 1.1 : 0)) { phase in
            GeometryReader { proxy in
                let w = proxy.size.width
                let openingWidth = w * 0.62
                let left = (w - openingWidth) / 2
                let top: CGFloat = 26
                let openingHeight: CGFloat = 120
                let open = CGFloat(clamp01(door))

                ZStack(alignment: .topLeading) {
                    // Dark opening with a warm interior light.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: openingWidth, height: openingHeight)
                        .overlay {
                            if light > 0.01 {
                                RadialGradient(
                                    colors: [
                                        garageLightColor.opacity(0.5 * light),
                                        garageLightColor.opacity(0.05 * light),
                                        .clear,
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.1),
                                    startRadius: 0,
                                    endRadius: openingWidth * 0.8
                                )
                                .blendMode(.plusLighter)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            // A car silhouette, visible once the door lifts.
                            CarSilhouette()
                                .fill(Color.white.opacity(0.22 + 0.25 * Double(open)))
                                .frame(width: openingWidth * 0.66, height: 34)
                                .padding(.bottom, 6)
                        }
                        .offset(x: left, y: top)
                        .clipped()

                    // Roll-up slats: they stack toward the lintel as the door opens.
                    VStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    slatColor
                                        .opacity(0.9)
                                        .lerp(to: color, moving ? 0.25 + 0.2 * sin(phase * 2 * .pi) : 0.08)
                                )
                                .frame(height: 20)
                        }
                    }
                    .frame(width: openingWidth)
                    .scaleEffect(y: 1 - open, anchor: .top)
                    .offset(x: left, y: top)

                    // Lintel and frame.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                        .frame(width: openingWidth, height: openingHeight)
                        .offset(x: left, y: top)

                    // Driveway.
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: openingWidth + 24, height: 4)
                        .offset(x: left - 12, y: top + openingHeight + 8)

                    // Photo-eye beam.
                    let beamY = top + openingHeight - 6
                    Capsule()
                        .fill(
                            obstructed
                                ? NexColors.red.opacity(0.5 + 0.5 * sin(phase * 2 * .pi))
                                : NexColors.mint.opacity(0.4)
                        )
                        .frame(width: openingWidth, height: 2)
                        .offset(x: left, y: beamY)
                        .blendMode(.plusLighter)
                    if obstructed {
                        Circle()
                            .fill(NexColors.red.opacity(0.8))
                            .frame(width: 10)
                            .offset(x: left + openingWidth / 2 - 5, y: beamY - 4)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct CarSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let w = rect.width
            let h = rect.height
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: h * 0.55))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.28, y: h * 0.2),
                control: CGPoint(x: w * 0.1, y: h * 0.3)
            )
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.2))
            path.addQuadCurve(
                to: CGPoint(x: w, y: h * 0.55),
                control: CGPoint(x: w * 0.9, y: h * 0.3)
            )
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
        }
    }
}

// MARK: - Security panel (ControlKind.securityPanel)

/// Security panel sheet: a radar stage around a hold orb that arms, cancels, disarms or silences.
/// The stage sweeps while armed, runs the exit countdown as a ring and plots every zone as a dot.
/// When triggered, every section on the sheet washes red and pulses. Below: mode selector, zones
/// with bypass, delays, siren and chime, a panic hold orb and system care.
struct SecurityPanelControls: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository
    @State private var preferredMode = 2
    @State private var pulse: Double = 0

    var body: some View {
        let state = device.alarmState
        let triggered = state == .triggered
        let accent = deviceAccent(device.type)
        let wash: Double = triggered ? 1 : 0
        let openZones = device.securityZones.filter { $0.isOpen && !$0.bypassed }.count

        VStack(spacing: 16) {
            securityHero(wash: wash, openZones: openZones)

            zonesSection(accent: accent, wash: wash)

            AlarmSection(
                title: "Delays",
                symbol: "timer",
                accent: accent,
                wash: wash,
                pulse: pulse
            ) {
                GlassSettingRow(
                    title: "Exit delay",
                    symbol: "hourglass",
                    subtitle: "Time to leave after arming",
                    accent: NexColors.violet
                ) {
                    LiquidIntStepper(
                        value: device.exitDelaySeconds,
                        range: 0...120,
                        step: 15,
                        format: { $0 == 0 ? "None" : "\($0)s" },
                        accent: NexColors.violet
                    ) { device.exitDelaySeconds = $0 }
                }
                GlassSettingRow(
                    title: "Entry delay",
                    symbol: "door.left.hand.open",
                    subtitle: "Time to disarm after coming in",
                    accent: NexColors.cyan
                ) {
                    LiquidIntStepper(
                        value: device.entryDelaySeconds,
                        range: 15...60,
                        step: 15,
                        format: { "\($0)s" },
                        accent: NexColors.cyan
                    ) { device.entryDelaySeconds = $0 }
                }
            }

            sirenSection(accent: accent, wash: wash)

            AlarmSection(
                title: "Emergency",
                symbol: "exclamationmark.triangle.fill",
                accent: NexColors.red,
                wash: wash,
                pulse: pulse
            ) {
                HStack(spacing: 16) {
                    LiquidHoldOrb(
                        label: "Panic",
                        symbol: "sos",
                        accent: NexColors.red,
                        active: triggered,
                        holdMillis: 1500,
                        size: 104,
                        sublabel: "Hold 1.5 s"
                    ) {
                        repository.armSecurity(device, .triggered)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        NexText("Panic alarm", .bodyStrong).lineLimit(1)
                        NexText(
                            "Sounds the siren right away, skipping every delay. Hold the alarm orb to silence it.",
                            .caption,
                            color: NexColors.secondary
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            AlarmSection(
                title: "System",
                symbol: "slider.horizontal.3",
                accent: accent,
                wash: wash,
                pulse: pulse
            ) {
                HStack(spacing: 12) {
                    GlassMetricTile(
                        label: "Backup battery",
                        value: "\(device.batteryPercent)",
                        unit: "%",
                        symbol: batterySymbol(device.batteryPercent),
                        accent: batteryColor(device.batteryPercent)
                    )
                    GlassMetricTile(
                        label: "Power",
                        value: "\(device.powerDrawWatts.rounded0)",
                        unit: "W",
                        symbol: "bolt.fill",
                        accent: accent,
                        history: device.powerHistory
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                DeviceCareRows(device: device, showBattery: false)
            }
        }
        .task(id: triggered) {
            guard triggered else {
                withAnimation(GlassMotion.glow) { pulse = 0 }
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.42)) { pulse = 1 }
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.52)) { pulse = 0.25 }
                try? await Task.sleep(for: .milliseconds(520))
            }
        }
        // A test siren (not an alarm) switches itself off after a few seconds.
        .task(id: device.sirenOn) {
            guard device.sirenOn, !triggered else { return }
            try? await Task.sleep(for: .seconds(4))
            if device.alarmState != .triggered { device.sirenOn = false }
        }
    }

    // MARK: Hero

    private func securityHero(wash: Double, openZones: Int) -> some View {
        let state = device.alarmState
        let triggered = state == .triggered
        let arming = state == .arming
        let armed = state == .armedHome || state == .armedAway || state == .armedNight
        let stateColor = alarmColor(state, device.armingTarget)
        let modeIndex = alarmModeIndex(state, device.armingTarget)
        let preferredTarget = modeTargets[clamp(preferredMode, 1, modeTargets.count - 1)]
        let countdownFraction = arming
            ? clamp01(Double(device.exitCountdownSeconds) / Double(max(device.exitDelaySeconds, 1)))
            : 0

        return AlarmSection(
            title: "Alarm",
            symbol: state == .disarmed ? "lock.open.fill" : "shield.fill",
            accent: stateColor,
            wash: wash,
            pulse: pulse,
            trailing: AnyView(
                StatusBadge(
                    text: alarmBadge(device),
                    color: stateColor,
                    pulsing: arming || triggered
                )
            )
        ) {
            HeroStage {
                ShieldScene(
                    zones: device.securityZones,
                    color: stateColor,
                    armed: state == .disarmed ? 0 : 1,
                    sweepRate: triggered ? 0.9 : (arming ? 0.55 : (armed ? 0.2 : 0)),
                    countdown: countdownFraction,
                    alarm: wash,
                    openZones: openZones
                )
                .animation(.spring(response: 0.751, dampingFraction: 1), value: state)
            } content: {
                VStack(spacing: 14) {
                    Spacer().frame(height: 30)
                    LiquidHoldOrb(
                        label: {
                            if triggered { return "Hold to silence" }
                            if arming { return "Hold to cancel" }
                            if armed { return "Hold to disarm" }
                            return "Hold to arm \(modeName(preferredTarget))"
                        }(),
                        symbol: {
                            if triggered { return "bell.slash.fill" }
                            if arming { return "xmark.circle.fill" }
                            if armed { return "lock.open.fill" }
                            return "shield.fill"
                        }(),
                        accent: state == .disarmed
                            ? alarmColor(preferredTarget, nil)
                            : stateColor,
                        active: state != .disarmed,
                        size: 140,
                        sublabel: alarmSublabel(device, openZones: openZones)
                    ) {
                        if device.alarmState == .disarmed {
                            repository.armSecurity(device, preferredTarget)
                        } else {
                            repository.armSecurity(device, .disarmed)
                        }
                    }
                    if arming {
                        VStack(spacing: 0) {
                            Text("\(device.exitCountdownSeconds)")
                                .font(NexType.numeric.font)
                                .tracking(NexType.numeric.tracking)
                                .foregroundStyle(stateColor)
                                .lineLimit(1)
                            NexText("seconds to leave", .caption, color: NexColors.secondary)
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 0) {
                        Readout(
                            symbol: "dot.radiowaves.left.and.right",
                            value: "\(device.securityZones.count - openZones)/\(device.securityZones.count)",
                            label: "Secure",
                            tint: openZones > 0 ? NexColors.amber : NexColors.mint
                        )
                        Readout(
                            symbol: "hourglass",
                            value: "\(device.exitDelaySeconds)s",
                            label: "Exit",
                            tint: NexColors.violet
                        )
                        Readout(
                            symbol: "door.left.hand.open",
                            value: "\(device.entryDelaySeconds)s",
                            label: "Entry",
                            tint: NexColors.cyan
                        )
                    }
                    .padding(.horizontal, 12)
                }
            }

            LiquidSegmented(
                options: modeOptions,
                selectedIndex: modeIndex ?? preferredMode,
                accent: stateColor
            ) { index in
                if index > 0 { preferredMode = index }
                repository.armSecurity(device, modeTargets[index])
            }
            NexText(alarmStatusLine(device, openZones: openZones), .label, color: NexColors.secondary)
            if triggered {
                GlassSettingRow(
                    title: "Intrusion alarm",
                    symbol: "exclamationmark.triangle.fill",
                    subtitle: device.sirenOn
                        ? "Siren sounding at \((device.sirenVolume * 100).rounded0)%"
                        : "Siren muted · system still triggered",
                    accent: NexColors.red
                ) {
                    LiquidToggle(isOn: device.sirenOn, accent: NexColors.red) { device.sirenOn = $0 }
                }
            }
        }
    }

    // MARK: Zones

    private func zonesSection(accent: Color, wash: Double) -> some View {
        let zones = device.securityZones
        let open = zones.filter { $0.isOpen }
        let bypassedCount = zones.filter { $0.bypassed }.count
        let allOpenBypassed = !open.isEmpty && open.allSatisfy { $0.bypassed }

        return AlarmSection(
            title: "Zones",
            symbol: "sensor.fill",
            accent: accent,
            wash: wash,
            pulse: pulse,
            trailing: AnyView(
                NexText(
                    "\(open.count) open · \(bypassedCount) bypassed",
                    .caption,
                    color: NexColors.tertiary
                )
                .lineLimit(1)
            )
        ) {
            LiquidChipRow {
                LiquidChip(
                    label: "Bypass open zones",
                    symbol: "shield.slash.fill",
                    selected: allOpenBypassed,
                    accent: NexColors.amber
                ) {
                    let target = !allOpenBypassed
                    for zone in device.securityZones where zone.isOpen { zone.bypassed = target }
                }
                LiquidChip(
                    label: "Clear bypasses",
                    symbol: "checkmark.shield.fill",
                    selected: false,
                    accent: NexColors.mint
                ) {
                    for zone in device.securityZones { zone.bypassed = false }
                }
            }
            ForEach(zones) { zone in
                ZoneRow(zone: zone)
            }
            NexText(
                "Switch on to bypass a zone. Bypassed zones are ignored while the system is armed.",
                .caption,
                color: NexColors.tertiary
            )
        }
    }

    // MARK: Siren

    private func sirenSection(accent: Color, wash: Double) -> some View {
        AlarmSection(
            title: "Siren & chime",
            symbol: "speaker.wave.3.fill",
            accent: accent,
            wash: wash,
            pulse: pulse
        ) {
            VStack(spacing: 8) {
                HStack {
                    NexText("Siren volume", .bodyStrong).lineLimit(1)
                    Spacer()
                    Text("\((device.sirenVolume * 100).rounded0)%")
                        .font(NexType.bodyStrong.font.monospacedDigit())
                        .foregroundStyle(NexColors.secondary)
                        .lineLimit(1)
                }
                LiquidSlider(
                    value: device.sirenVolume,
                    accent: NexColors.red
                ) { device.sirenVolume = $0 }
            }
            GlassSettingRow(
                title: "Test siren",
                symbol: "speaker.wave.3.fill",
                subtitle: device.sirenOn
                    ? "Sounding · stops by itself"
                    : "Sounds the siren for a few seconds",
                accent: NexColors.red
            ) {
                LiquidToggle(isOn: device.sirenOn, accent: NexColors.red) { device.sirenOn = $0 }
            }
            GlassSettingRow(
                title: "Chime on open",
                symbol: "bell.badge.fill",
                subtitle: "A soft chime when a door or window opens while disarmed",
                accent: NexColors.cyan
            ) {
                LiquidToggle(isOn: device.chimeOnOpen, accent: NexColors.cyan) {
                    device.chimeOnOpen = $0
                }
            }
        }
    }
}

private struct ZoneRow: View {
    @Bindable var zone: SecurityZone

    var body: some View {
        let open = zone.isOpen
        let bypassed = zone.bypassed
        let motionZone = zone.name.contains("Motion")
        let tint: Color = bypassed ? idleColor : (open ? NexColors.amber : NexColors.mint)

        GlassSettingRow(
            title: zone.name,
            symbol: zoneSymbol(zone.name),
            subtitle: {
                if bypassed { return open ? "Open · bypassed" : "Bypassed" }
                if open { return motionZone ? "Motion detected" : "Open" }
                return motionZone ? "No motion" : "Closed"
            }(),
            accent: tint
        ) {
            HStack(spacing: 8) {
                if open && !bypassed {
                    StatusBadge(
                        text: motionZone ? "Motion" : "Open",
                        color: NexColors.amber,
                        pulsing: true
                    )
                }
                LiquidToggle(isOn: zone.bypassed, accent: NexColors.amber) { zone.bypassed = $0 }
            }
        }
    }
}

/// The alarm stage: a radar sweep, the exit-countdown ring and every zone plotted as a dot.
private struct ShieldScene: View {
    let zones: [SecurityZone]
    let color: Color
    let armed: Double
    let sweepRate: Double
    let countdown: Double
    let alarm: Double
    let openZones: Int

    var body: some View {
        PhaseTimeline(cyclesPerSecond: sweepRate) { phase in
            GeometryReader { proxy in
                let w = proxy.size.width
                let center = CGPoint(x: w / 2, y: 112)
                let radius: CGFloat = 96

                ZStack {
                    RadialGradient(
                        colors: [color.opacity(0.22 * armed), .clear],
                        center: UnitPoint(x: 0.5, y: center.y / max(proxy.size.height, 1)),
                        startRadius: 0,
                        endRadius: radius * 1.8
                    )
                    .blendMode(.plusLighter)

                    // Radar rings.
                    ForEach(1..<4, id: \.self) { ring in
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                            .frame(width: radius * 2 * CGFloat(ring) / 3)
                            .position(center)
                    }

                    // Sweep.
                    if sweepRate > 0.01 {
                        Circle()
                            .trim(from: 0, to: 0.12)
                            .rotation(.degrees(phase * 360))
                            .stroke(
                                color.opacity(0.65),
                                style: StrokeStyle(lineWidth: radius, lineCap: .butt)
                            )
                            .frame(width: radius)
                            .position(center)
                            .mask(Circle().frame(width: radius * 2).position(center))
                            .opacity(0.35)
                    }

                    // Exit-countdown ring.
                    if countdown > 0.001 {
                        Circle()
                            .trim(from: 0, to: CGFloat(countdown))
                            .rotation(.degrees(-90))
                            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: radius * 2 - 8)
                            .position(center)
                    }

                    // Zone dots on a 240° arc.
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        let count = max(zones.count - 1, 1)
                        let angle = radians(150 + 240 * Double(index) / Double(count))
                        let dotColor: Color = zone.bypassed
                            ? idleColor
                            : (zone.isOpen ? NexColors.amber : NexColors.mint)
                        Circle()
                            .fill(dotColor)
                            .frame(width: zone.isOpen && !zone.bypassed ? 9 : 6)
                            .position(
                                x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius
                            )
                    }

                    // Shock rings while triggered.
                    if alarm > 0.02 {
                        ForEach(0..<2, id: \.self) { k in
                            let t = (phase + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .strokeBorder(
                                    NexColors.red.opacity(0.5 * (1 - t) * alarm),
                                    lineWidth: 2
                                )
                                .frame(width: radius + CGFloat(t) * radius * 1.8)
                                .position(center)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Access helpers

private let ajarColor = NexColors.orange
private let unlockedColor = NexColors.amber
private let garageLightColor = Color(hex: 0xFFC46F)
private let slatColor = Color(hex: 0xDDE3F0)

private let autoCloseMinutes = [5, 10, 15, 30]
private let modeTargets: [AlarmState] = [.disarmed, .armedHome, .armedAway, .armedNight]
private let modeOptions = [
    SegmentOption("Off", "lock.open.fill"),
    SegmentOption("Home", "house.fill"),
    SegmentOption("Away", "figure.walk.departure"),
    SegmentOption("Night", "moon.stars.fill"),
]
private let guestPresets = [
    "Dog walker · Weekdays 12–1 PM",
    "House cleaner · Thursdays 9 AM–1 PM",
    "Babysitter · Fri & Sat evenings",
    "Delivery · Today 9 AM–5 PM",
    "Grandma · Always",
]

func durationLabel(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    if seconds % 60 == 0 { return "\(seconds / 60) min" }
    return "\(seconds / 60)m \(seconds % 60)s"
}

func agoLabel(_ minutes: Int) -> String {
    if minutes <= 0 { return "Just now" }
    if minutes < 60 { return "\(minutes)m ago" }
    if minutes < 1440 { return "\(minutes / 60)h ago" }
    return "\(minutes / 1440)d ago"
}

func nearestIndex(_ values: [Int], _ value: Int) -> Int {
    var best = 0
    for index in values.indices where abs(values[index] - value) < abs(values[best] - value) {
        best = index
    }
    return best
}

func signalLabel(_ bars: Int) -> String {
    switch bars {
    case 4: return "Excellent signal"
    case 3: return "Good signal"
    case 2: return "Fair signal"
    default: return "Weak signal · move the hub closer"
    }
}

func batterySymbol(_ percent: Int) -> String {
    if percent >= 80 { return "battery.100" }
    if percent >= 45 { return "battery.75" }
    if percent > 20 { return "battery.25" }
    return "battery.0"
}

func batteryColor(_ percent: Int) -> Color {
    if percent <= 20 { return NexColors.red }
    if percent <= 40 { return NexColors.amber }
    return NexColors.mint
}

private func lockColor(locked: Bool, ajar: Bool, accent: Color) -> Color {
    if ajar { return ajarColor }
    return locked ? accent : unlockedColor
}

private func lockBadge(locked: Bool, ajar: Bool) -> String {
    if ajar { return "Door ajar" }
    return locked ? "Secured" : "Unlocked"
}

private func lockSublabel(_ device: Device, counting: Bool) -> String {
    if device.doorAjar { return "Door ajar · close it to lock" }
    if counting { return "Auto-locks after \(durationLabel(device.autoLockSeconds))" }
    if device.lockState == .unlocked { return "Auto-lock is off" }
    if let last = device.lockActivity.first { return "\(last.label) · \(last.detail)" }
    return "Secured"
}

private func lockStatusLine(_ device: Device) -> String {
    let guests = device.guestAccess.count
    let base = device.lockState == .locked ? "Deadbolt thrown" : "Deadbolt open"
    if device.doorAjar { return "\(base) · the door is standing open" }
    if device.type == .entryLock, guests > 0 {
        return "\(base) · \(guests) guest \(guests == 1 ? "code" : "codes") active"
    }
    return "\(base) · battery \(device.batteryPercent)%"
}

private func lockEventSymbol(_ event: ActivityEvent) -> String {
    if event.label.hasPrefix("Auto") { return "lock.badge.clock" }
    if event.label.hasPrefix("Unlock") {
        if event.detail.contains("Fingerprint") { return "touchid" }
        if event.detail.contains("Keypad") { return "circle.grid.3x3.fill" }
        if event.detail.contains("Guest") { return "key.fill" }
        return "lock.open.fill"
    }
    if event.label.hasPrefix("Lock") { return "lock.fill" }
    return "door.left.hand.open"
}

private func lockEventColor(_ event: ActivityEvent, _ accent: Color) -> Color {
    if event.label.hasPrefix("Auto") { return NexColors.violet }
    if event.label.hasPrefix("Unlock") { return unlockedColor }
    if event.label.hasPrefix("Lock") { return accent }
    return NexColors.cyan
}

private func guestSymbol(_ entry: String) -> String {
    let lower = entry.lowercased()
    if lower.contains("dog") { return "pawprint.fill" }
    if lower.contains("clean") { return "sparkles" }
    if lower.contains("babysitter") { return "figure.and.child.holdinghands" }
    if lower.contains("delivery") { return "shippingbox.fill" }
    return "person.2.fill"
}

private func garageColor(_ device: Device, _ accent: Color) -> Color {
    if device.obstructionDetected { return NexColors.red }
    if device.garageState == .open { return garageLightColor }
    return accent
}

private func garageBadge(_ device: Device) -> String {
    if device.obstructionDetected { return "Obstructed" }
    switch device.garageState {
    case .moving: return device.garageOpening ? "Opening" : "Closing"
    case .open: return "Open"
    case .closed: return "Closed"
    }
}

private func garageSublabel(_ device: Device) -> String {
    if device.obstructionDetected { return "Obstruction · closing will reverse" }
    if device.garageState == .moving { return "Moving · hold again to reverse" }
    if device.garageState == .open, device.autoCloseMinutes > 0 {
        return "Auto-closes after \(device.autoCloseMinutes) min"
    }
    if device.garageState == .open { return "Open · auto-close off" }
    return "Opens in about 9 s"
}

private func garageStatusLine(_ device: Device) -> String {
    let light = device.garageLightOn ? "light on" : "light off"
    guard let last = device.garageActivity.first else {
        return "No recent activity · \(light)"
    }
    return "\(last.label) · \(last.detail) · \(light)"
}

private func garageEventSymbol(_ event: ActivityEvent) -> String {
    if event.label.hasPrefix("Reversed") { return "exclamationmark.triangle.fill" }
    if event.label.hasPrefix("Light") { return "lightbulb.fill" }
    if event.label.lowercased().contains("open") { return "chevron.up.2" }
    return "chevron.down.2"
}

private func garageEventColor(_ event: ActivityEvent, _ accent: Color) -> Color {
    if event.label.hasPrefix("Reversed") { return NexColors.red }
    if event.label.hasPrefix("Light") { return garageLightColor }
    if event.label.hasPrefix("Auto") { return NexColors.violet }
    return accent
}

private func alarmColor(_ state: AlarmState, _ target: AlarmState?) -> Color {
    switch state {
    case .disarmed: return NexColors.mint
    case .armedHome: return NexColors.cyan
    case .armedAway: return NexColors.violet
    case .armedNight: return NexColors.indigo
    case .triggered: return NexColors.red
    case .arming: return alarmColor(target ?? .armedAway, nil)
    }
}

private func alarmModeIndex(_ state: AlarmState, _ target: AlarmState?) -> Int? {
    switch state {
    case .disarmed: return 0
    case .armedHome: return 1
    case .armedAway: return 2
    case .armedNight: return 3
    case .arming: return modeTargets.firstIndex(of: target ?? .armedAway) ?? 2
    case .triggered: return nil
    }
}

private func modeName(_ state: AlarmState) -> String {
    switch state {
    case .armedHome: return "Home"
    case .armedNight: return "Night"
    default: return "Away"
    }
}

private func alarmBadge(_ device: Device) -> String {
    switch device.alarmState {
    case .disarmed: return "Disarmed"
    case .arming: return "Arming · \(device.exitCountdownSeconds)s"
    case .triggered: return "Alarm!"
    default: return "Armed · \(modeName(device.alarmState))"
    }
}

private func alarmSublabel(_ device: Device, openZones: Int) -> String {
    switch device.alarmState {
    case .triggered: return "Silences the siren and disarms"
    case .arming: return "Arming \(modeName(device.armingTarget ?? .armedAway))"
    case .disarmed:
        return openZones > 0
            ? "\(openZones) \(openZones == 1 ? "zone" : "zones") open"
            : "All zones secure"
    default: return "Entry delay \(device.entryDelaySeconds)s"
    }
}

private func alarmStatusLine(_ device: Device, openZones: Int) -> String {
    let zones = device.securityZones
    let bypassed = zones.filter { $0.bypassed }.count
    switch device.alarmState {
    case .disarmed:
        return openZones > 0
            ? "\(openZones) open · close or bypass before you leave"
            : "Ready to arm · exit delay \(device.exitDelaySeconds)s"
    case .arming:
        return "Leave now · arming \(modeName(device.armingTarget ?? .armedAway)) in \(device.exitCountdownSeconds)s"
    case .triggered:
        return "Intrusion detected · hold the orb to silence and disarm"
    default:
        let base = "Monitoring \(zones.count - bypassed) zones"
        return bypassed > 0 ? "\(base) · \(bypassed) bypassed" : base
    }
}

private func zoneSymbol(_ name: String) -> String {
    if name.contains("Motion") { return "sensor.fill" }
    if name.contains("Garage") { return "door.garage.closed" }
    if name.contains("Slider") { return "door.sliding.left.hand.closed" }
    if name.contains("Window") { return "window.vertical.closed" }
    if name.contains("Door") { return "door.left.hand.closed" }
    return "shield.fill"
}
