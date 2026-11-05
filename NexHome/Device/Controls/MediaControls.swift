import SwiftUI

// MARK: - Media (ControlKind.mediaPlayer)

/// Speaker / TV / soundbar sheet: a live artwork hero that beats with the track, transport orbs, a
/// waveform scrubber, a TV remote with an app grid and D-pad, a volume fader with an LED level
/// meter, sources with stations / apps / inputs, an EQ curve with bass and treble, speaker grouping,
/// the up-next queue and device info. Everything animates from one clock that only runs while the
/// device is actually playing.
struct MediaControls: View {
    @Bindable var device: Device
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let kind = mediaKind(device.type)
        let accent = deviceAccent(device.type)
        let trackColor = mediaHueColor(device.artworkHue, 0.62, 1)
        let active = device.isOn && device.isPlaying

        VStack(spacing: 16) {
            nowPlayingSection(kind: kind, trackColor: trackColor, active: active)
            if kind == .tv { MediaRemoteSection(device: device, accent: accent) }
            MediaVolumeSection(device: device, trackColor: trackColor, active: active)
            MediaSourceSection(device: device, kind: kind, accent: accent)
            MediaSoundSection(device: device, kind: kind, accent: accent, active: active)
            if kind != .tv { MediaGroupSection(device: device, accent: accent) }
            MediaUpNextSection(device: device, kind: kind, accent: accent)
            MediaDeviceSection(device: device, kind: kind, accent: accent)
        }
        // Playing with no source (e.g. switched on from the header) picks a sensible one.
        .onChange(of: active) { _, isActive in
            if isActive && device.mediaSource == .off {
                device.mediaSource = mediaDefaultSource(kind)
            }
        }
    }

    // MARK: Now playing

    private func nowPlayingSection(kind: MediaKind, trackColor: Color, active: Bool) -> some View {
        let tv = kind == .tv
        let elapsed = Int(device.trackProgress * Double(device.trackDurationSec))
        let duration = device.trackDurationSec

        return GlassSection(
            title: tv ? "Now watching" : "Now playing",
            symbol: tv ? "tv.badge.wifi" : "waveform",
            accent: trackColor,
            trailing: AnyView(
                NexText(
                    device.isOn ? mediaSourceName(device.mediaSource, kind) : "Standby",
                    .caption,
                    color: device.isOn ? trackColor : NexColors.tertiary
                )
                .lineLimit(1)
            )
        ) {
            MediaArtwork(device: device, kind: kind, active: active) {
                mediaTogglePlay(device, repository, kind)
            }
            .aspectRatio(tv ? 16.0 / 9.0 : 1.12, contentMode: .fit)

            HStack(spacing: 12) {
                MediaTrackTitle(title: device.trackTitle, subtitle: device.trackArtist)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MediaOrb(
                    symbol: device.isFavorite ? "heart.fill" : "heart",
                    size: 44,
                    accent: NexColors.pink,
                    lit: device.isFavorite,
                    tint: device.isFavorite ? NexColors.pink : .white
                ) {
                    device.isFavorite.toggle()
                }
            }

            VStack(spacing: 2) {
                MediaScrubber(device: device, trackColor: trackColor, active: active)
                HStack {
                    Text(mediaDuration(elapsed))
                        .font(NexType.caption.font.monospacedDigit())
                        .foregroundStyle(NexColors.secondary)
                    Spacer()
                    Text("-" + mediaDuration(max(0, duration - elapsed)))
                        .font(NexType.caption.font.monospacedDigit())
                        .foregroundStyle(NexColors.tertiary)
                }
            }

            HStack {
                Spacer()
                MediaOrb(symbol: "gobackward.10", size: 42, accent: trackColor) {
                    mediaSeek(device, by: -10)
                }
                Spacer()
                MediaOrb(symbol: "backward.end.fill", size: 54, accent: trackColor) {
                    repository.previousTrack(device)
                }
                Spacer()
                MediaOrb(
                    symbol: active ? "pause.fill" : "play.fill",
                    size: 80,
                    accent: trackColor,
                    lit: active,
                    pulsing: active
                ) {
                    mediaTogglePlay(device, repository, kind)
                }
                Spacer()
                MediaOrb(symbol: "forward.end.fill", size: 54, accent: trackColor) {
                    repository.nextTrack(device)
                }
                Spacer()
                MediaOrb(symbol: "goforward.10", size: 42, accent: trackColor) {
                    mediaSeek(device, by: 10)
                }
                Spacer()
            }

            LiquidChipRow {
                LiquidChip(
                    label: "Shuffle",
                    symbol: "shuffle",
                    selected: device.shuffle,
                    accent: trackColor
                ) { device.shuffle.toggle() }
                LiquidChip(
                    label: device.repeatMode.displayName,
                    symbol: device.repeatMode.symbol,
                    selected: device.repeatMode != .off,
                    accent: trackColor
                ) {
                    let next = (device.repeatMode.rawValue + 1) % RepeatMode.allCases.count
                    device.repeatMode = RepeatMode.allCases[next]
                }
                LiquidChip(
                    label: device.muted ? "Muted" : "Sound on",
                    symbol: device.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    selected: device.muted,
                    accent: NexColors.rose
                ) { device.muted.toggle() }
            }
        }
    }
}

/// Title + artist that rise and bounce in whenever the track changes.
private struct MediaTrackTitle: View {
    let title: String
    let subtitle: String
    @State private var enter: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            NexText(title.isEmpty ? "Nothing playing" : title, .title).lineLimit(1)
            NexText(subtitle, .body, color: NexColors.secondary).lineLimit(1)
        }
        .opacity(enter)
        .offset(y: (1 - enter) * 16)
        .task(id: title) {
            enter = 0
            withAnimation(GlassMotion.release) { enter = 1 }
        }
    }
}

/// The hero artwork: glass over a drifting gradient in the track's hue, with vinyl grooves and a
/// beat visualiser (audio) or scanlines and a progress rail (TV). Tap toggles play.
private struct MediaArtwork: View {
    let device: Device
    let kind: MediaKind
    let active: Bool
    let action: () -> Void

    var body: some View {
        let tv = kind == .tv
        let hue = device.artworkHue
        let glow = mediaHueColor(hue, 0.6, 1)
        let level = device.muted ? 0.15 : 0.35 + 0.65 * device.volume

        GlassPanel(
            shape: glassRect(tv ? 22 : 30),
            tint: .clear,
            accent: glow,
            heavy: true,
            pressScale: 1.04,
            action: action,
            surface: AnyView(
                ZStack {
                    // The "artwork": a drifting two-stop gradient in the track hue.
                    LinearGradient(
                        colors: [
                            mediaHueColor(hue - 28, 0.8, 0.95),
                            mediaHueColor(hue + 34, 0.9, 0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .animation(.spring(response: 0.811, dampingFraction: 0.85), value: hue)

                    MediaArtDetail(tv: tv, active: active, level: level, glow: glow, progress: device.trackProgress)

                    if !device.isOn {
                        Color.black.opacity(0.45)
                    }
                }
            )
        ) {
            ZStack {
                if tv {
                    VStack {
                        HStack(alignment: .top) {
                            MediaBadge(text: active ? "LIVE" : "PAUSED", dot: active ? NexColors.red : nil)
                            Spacer()
                            MediaBadge(text: "4K · HDR")
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                GlassIconOrb(
                    symbol: active ? (tv ? "pause.fill" : "waveform") : "play.fill",
                    accent: .white,
                    size: tv ? 64 : 76,
                    glow: active ? 0.4 : 0,
                    iconTint: .white
                )
                .opacity(tv && active ? 0.25 : 1)
                .offset(y: tv ? 0 : -12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Vinyl grooves and a beat visualiser, or TV scanlines and a progress rail.
private struct MediaArtDetail: View {
    let tv: Bool
    let active: Bool
    let level: Double
    let glow: Color
    let progress: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: active ? 1 / 2.4 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                let beat = mediaBeat(phase) * (active ? 1 : 0)
                ZStack {
                    if tv {
                        // Scanlines and a light sweep.
                        Canvas { canvas, canvasSize in
                            var y: CGFloat = 0
                            while y < canvasSize.height {
                                canvas.fill(
                                    Path(CGRect(x: 0, y: y, width: canvasSize.width, height: 1)),
                                    with: .color(.white.opacity(0.04))
                                )
                                y += 4
                            }
                        }
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: size.width * 0.4)
                        .offset(x: CGFloat(phase) * size.width * 1.4 - size.width * 0.5)
                        .blendMode(.plusLighter)
                        // Progress rail.
                        VStack {
                            Spacer()
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.18)).frame(height: 3)
                                Rectangle()
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: size.width * CGFloat(clamp01(progress)), height: 3)
                            }
                        }
                    } else {
                        // Vinyl grooves with a rotating sheen.
                        ForEach(1..<7, id: \.self) { ring in
                            Circle()
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                .frame(width: size.minSide * CGFloat(ring) / 7)
                        }
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.clear, Color.white.opacity(0.16), .clear, .clear],
                                    center: .center,
                                    angle: .degrees(phase * 360)
                                )
                            )
                            .frame(width: size.minSide * 0.95)
                            .blendMode(.plusLighter)
                        // Beat visualiser ring.
                        Circle()
                            .strokeBorder(
                                glow.opacity(0.35 + 0.4 * beat),
                                lineWidth: 2 + 5 * CGFloat(beat * level)
                            )
                            .frame(width: size.minSide * (0.62 + 0.05 * CGFloat(beat * level)))
                            .blendMode(.plusLighter)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private extension CGSize {
    var minSide: CGFloat { min(width, height) }
}

/// Small glass capsule label (optionally with a coloured status dot).
private struct MediaBadge: View {
    let text: String
    var dot: Color?

    var body: some View {
        GlassPanel(shape: glassCapsule, tint: Color.black.opacity(0.112)) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7)
                }
                NexText(text, .caption, color: .white).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
}

/// A round glass transport button that floods with `accent` while lit and pulses to the beat.
struct MediaOrb: View {
    let symbol: String
    var size: CGFloat = 50
    var accent: Color
    var lit: Bool = false
    var pulsing: Bool = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        PhaseTimeline(cyclesPerSecond: pulsing ? 1 / 2.4 : 0) { phase in
            let beat = pulsing ? mediaBeat(phase) : 0
            GlassPanel(
                shape: glassCircle,
                tint: Color.black.opacity(0.064),
                accent: accent,
                pressScale: GlassMotion.buttonPressScale,
                action: action,
                surface: AnyView(accent.opacity(lit ? 0.45 : 0))
            ) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
            }
            .scaleEffect(1 + 0.05 * beat)
            .shadow(color: accent.opacity(lit ? 0.45 : 0), radius: 14)
        }
    }
}

/// Waveform scrubber: a glass capsule whose surface draws the track's waveform (played bars in the
/// track colour, bars near the playhead swelling to the beat). Drag to scrub, tap to seek.
private struct MediaScrubber: View {
    @Bindable var device: Device
    let trackColor: Color
    let active: Bool

    @State private var dragging = false
    @State private var startProgress: Double = 0

    var body: some View {
        let bars = mediaWaveform(device.trackTitle)
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            GlassPanel(
                shape: glassCapsule,
                tint: Color.black.opacity(0.088),
                accent: trackColor,
                interactive: true,
                surface: AnyView(
                    MediaWaveform(
                        bars: bars,
                        progress: device.trackProgress,
                        color: trackColor,
                        active: active,
                        press: dragging ? 1 : 0
                    )
                )
            ) {
                Color.clear.frame(height: 44)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            startProgress = device.trackProgress
                            Haptics.tick()
                        }
                        device.trackProgress = clamp01(
                            startProgress + Double(value.translation.width / width)
                        )
                    }
                    .onEnded { value in
                        if abs(value.translation.width) < 3 {
                            device.trackProgress = clamp01(Double(value.location.x / width))
                        }
                        dragging = false
                    }
            )
        }
        .frame(height: 44)
    }
}

private struct MediaWaveform: View {
    let bars: [Double]
    let progress: Double
    let color: Color
    let active: Bool
    let press: Double

    var body: some View {
        PhaseTimeline(cyclesPerSecond: active ? 1 / 2.4 : 0) { phase in
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let n = bars.count
                let inset = h * 0.5
                let gap: CGFloat = 2
                let barW = (w - inset * 2 - gap * CGFloat(n - 1)) / CGFloat(n)
                if barW > 0 {
                    let beat = mediaBeat(phase) * (active ? 1 : 0)
                    let maxH = h * (0.56 + 0.16 * press)
                    let prog = clamp01(progress)
                    ForEach(0..<n, id: \.self) { index in
                        let f = (Double(index) + 0.5) / Double(n)
                        let near = clamp01(1 - abs(f - prog) * 8)
                        let live = 1 + 0.3 * beat * abs(sin(Double(index) * 0.9 + phase * 12.566))
                        let bh = max(barW, maxH * CGFloat(bars[index] * live * (1 + 0.25 * near)))
                        Capsule()
                            .fill(f <= prog ? color : Color.white.opacity(0.3))
                            .frame(width: barW, height: bh)
                            .position(
                                x: inset + CGFloat(index) * (barW + gap) + barW / 2,
                                y: h / 2
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - TV remote

private struct MediaRemoteSection: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository
    @State private var focus = 0

    var body: some View {
        let active = device.isOn && device.isPlaying
        let percent = (device.volume * 100).rounded0

        GlassSection(
            title: "Remote",
            symbol: "av.remote.fill",
            accent: accent,
            trailing: AnyView(
                NexText(mediaTvApps[focus % mediaTvApps.count].label, .caption, color: accent)
                    .lineLimit(1)
            )
        ) {
            MediaTvHome(focus: focus, accent: accent) { index in
                focus = index
                mediaLaunchApp(device, repository, index)
            }
            MediaDpad(accent: accent, onMove: { dx, dy in
                let col = focus % mediaTvColumns + dx
                let row = focus / mediaTvColumns + dy
                let rows = mediaTvApps.count / mediaTvColumns
                if col >= 0, col < mediaTvColumns, row >= 0, row < rows {
                    focus = row * mediaTvColumns + col
                    Haptics.tick()
                }
            }, onOk: {
                Haptics.confirm()
                mediaLaunchApp(device, repository, focus)
            })
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                MediaOrb(symbol: "chevron.backward", size: 50, accent: accent) {
                    device.isPlaying = false
                }
                Spacer()
                MediaOrb(symbol: "house.fill", size: 50, accent: accent) { focus = 0 }
                Spacer()
                MediaOrb(
                    symbol: active ? "pause.fill" : "play.fill",
                    size: 50,
                    accent: accent,
                    lit: active
                ) {
                    mediaTogglePlay(device, repository, .tv)
                }
                Spacer()
                MediaOrb(
                    symbol: device.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    size: 50,
                    accent: NexColors.rose,
                    lit: device.muted
                ) {
                    device.muted.toggle()
                }
                Spacer()
            }

            GlassSettingRow(
                title: "Volume",
                symbol: "speaker.wave.2.fill",
                subtitle: device.muted ? "Muted" : "TV speakers · \(percent)%",
                accent: accent
            ) {
                LiquidIntStepper(value: percent, range: 0...100, step: 5, accent: accent) { value in
                    device.volume = Double(value) / 100
                    device.muted = false
                }
            }
        }
        .task { focus = mediaTrackIndex(device) % mediaTvApps.count }
    }
}

/// The TV home screen: a glass app grid with a focus ring that springs between tiles.
private struct MediaTvHome: View {
    let focus: Int
    let accent: Color
    let onPick: (Int) -> Void

    var body: some View {
        let rows = mediaTvApps.count / mediaTvColumns
        GlassPanel(shape: glassRect(22), tint: Color.black.opacity(0.096), heavy: true) {
            GeometryReader { proxy in
                let gap: CGFloat = 10
                let pad: CGFloat = 12
                let tileW = (proxy.size.width - pad * 2 - gap * CGFloat(mediaTvColumns - 1))
                    / CGFloat(mediaTvColumns)
                let tileH: CGFloat = 64
                ZStack(alignment: .topLeading) {
                    // Focus ring.
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent, lineWidth: 2)
                        .frame(width: tileW, height: tileH)
                        .offset(
                            x: pad + CGFloat(focus % mediaTvColumns) * (tileW + gap),
                            y: pad + CGFloat(focus / mediaTvColumns) * (tileH + gap)
                        )
                        .shadow(color: accent.opacity(0.6), radius: 10)
                        .animation(.spring(response: 0.322, dampingFraction: 0.55), value: focus)

                    ForEach(Array(mediaTvApps.enumerated()), id: \.offset) { index, app in
                        let col = index % mediaTvColumns
                        let row = index / mediaTvColumns
                        VStack(spacing: 3) {
                            Image(systemName: app.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            NexText(app.label, .caption, color: NexColors.secondary).lineLimit(1)
                        }
                        .frame(width: tileW, height: tileH)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(mediaHueColor(app.hue, 0.5, 0.45).opacity(0.5))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onPick(index) }
                        .offset(
                            x: pad + CGFloat(col) * (tileW + gap),
                            y: pad + CGFloat(row) * (tileH + gap)
                        )
                    }
                }
            }
            .frame(height: 12 * 2 + CGFloat(rows) * 64 + CGFloat(rows - 1) * 10)
        }
    }
}

/// A glass D-pad: four directional pads around a centre OK orb.
private struct MediaDpad: View {
    let accent: Color
    let onMove: (Int, Int) -> Void
    let onOk: () -> Void

    var body: some View {
        GlassPanel(shape: glassCircle, tint: Color.black.opacity(0.08), heavy: true) {
            ZStack {
                DpadArrow(symbol: "chevron.up", accent: accent) { onMove(0, -1) }
                    .offset(y: -78)
                DpadArrow(symbol: "chevron.down", accent: accent) { onMove(0, 1) }
                    .offset(y: 78)
                DpadArrow(symbol: "chevron.left", accent: accent) { onMove(-1, 0) }
                    .offset(x: -78)
                DpadArrow(symbol: "chevron.right", accent: accent) { onMove(1, 0) }
                    .offset(x: 78)
                MediaOrb(symbol: "circle.circle", size: 76, accent: accent, lit: true, action: onOk)
            }
            .frame(width: 236, height: 236)
        }
    }
}

private struct DpadArrow: View {
    let symbol: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: Color.white.opacity(0.08),
            accent: accent,
            pressScale: GlassMotion.buttonPressScale,
            action: action
        ) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
        }
    }
}

// MARK: - Volume

private struct MediaVolumeSection: View {
    @Bindable var device: Device
    let trackColor: Color
    let active: Bool

    var body: some View {
        let percent = (device.volume * 100).rounded0

        GlassSection(
            title: "Volume",
            symbol: "speaker.wave.2.fill",
            accent: trackColor,
            trailing: AnyView(
                NexText(
                    device.muted ? "Muted" : "\(percent)%",
                    .caption,
                    color: device.muted ? NexColors.rose : trackColor
                )
                .lineLimit(1)
            )
        ) {
            HStack(spacing: 14) {
                LiquidFader(
                    value: device.muted ? 0 : device.volume,
                    accent: trackColor,
                    symbol: volumeSymbol,
                    label: "Level",
                    width: 92,
                    height: 240
                ) { value in
                    device.volume = value
                    if value > 0.005 { device.muted = false }
                }
                VStack(alignment: .leading, spacing: 12) {
                    MediaLevelMeter(device: device, active: active)
                        .frame(height: 112)
                    VStack(alignment: .leading, spacing: 2) {
                        NexText(device.muted ? "Muted" : "\(percent)%", .headline).lineLimit(1)
                        NexText(
                            "\(mediaLoudnessName(device.volume)) · \(active ? "Live output" : "Idle")",
                            .caption,
                            color: NexColors.tertiary
                        )
                        .lineLimit(2)
                    }
                    HStack(spacing: 10) {
                        MediaOrb(symbol: "speaker.wave.1.fill", size: 46, accent: trackColor) {
                            device.volume = clamp01(device.volume - 0.05)
                            device.muted = false
                        }
                        MediaOrb(symbol: "speaker.wave.3.fill", size: 46, accent: trackColor) {
                            device.volume = clamp01(device.volume + 0.05)
                            device.muted = false
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            LiquidChipRow {
                ForEach(mediaVolumePresets, id: \.label) { preset in
                    LiquidChip(
                        label: preset.label,
                        symbol: preset.symbol,
                        selected: !device.muted && abs(device.volume - preset.level) < 0.03,
                        accent: trackColor
                    ) {
                        device.volume = preset.level
                        device.muted = false
                    }
                }
            }
        }
    }

    private var volumeSymbol: String {
        if device.muted || device.volume < 0.01 { return "speaker.slash.fill" }
        if device.volume < 0.45 { return "speaker.wave.1.fill" }
        return "speaker.wave.3.fill"
    }
}

/// A 16-segment LED level meter that dances to the beat while playing.
private struct MediaLevelMeter: View {
    let device: Device
    let active: Bool

    var body: some View {
        GlassPanel(
            shape: glassRect(20),
            tint: Color.black.opacity(0.096),
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: active ? 1 / 2.4 : 0) { phase in
                    GeometryReader { proxy in
                        let w = proxy.size.width
                        let h = proxy.size.height
                        let segments = 16
                        let padX: CGFloat = 14
                        let gap: CGFloat = 3
                        let segW = (w - padX * 2 - gap * CGFloat(segments - 1)) / CGFloat(segments)
                        let vol = device.muted || !device.isOn ? 0 : device.volume
                        let beat = mediaBeat(phase) * (active ? 1 : 0)
                        ForEach(0..<segments, id: \.self) { index in
                            let t = Double(index) / Double(segments - 1)
                            let envelope = vol * (1 + 0.45 * beat * sin(Double(index) * 0.8 + phase * 9))
                            let on = t <= clamp01(envelope)
                            let color: Color = t > 0.84
                                ? NexColors.red
                                : (t > 0.62 ? NexColors.amber : NexColors.mint)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(on ? color : Color.white.opacity(0.1))
                                .frame(width: segW, height: h * 0.52 * CGFloat(0.4 + 0.6 * t))
                                .position(
                                    x: padX + CGFloat(index) * (segW + gap) + segW / 2,
                                    y: h * 0.58
                                )
                        }
                    }
                }
            )
        ) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    NexText("L/R", .caption, color: NexColors.tertiary)
                    Spacer()
                    NexText(mediaDb(device.volume * 2 - 1), .caption, color: NexColors.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Source

private struct MediaSourceSection: View {
    @Bindable var device: Device
    let kind: MediaKind
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let sources = mediaSources(for: kind)
        let selected = sources.firstIndex { $0.source == device.mediaSource } ?? 0
        let picks = mediaPicks(for: device.mediaSource, kind: kind)
        let pick = picks.isEmpty ? -1 : mediaTrackIndex(device) % picks.count
        let live = device.isOn && device.isPlaying

        GlassSection(
            title: kind == .tv ? "Inputs & apps" : "Source",
            symbol: "app.connected.to.app.below.fill",
            accent: accent,
            trailing: AnyView(
                NexText(mediaSourceName(device.mediaSource, kind), .caption, color: accent)
                    .lineLimit(1)
            )
        ) {
            LiquidSegmented(
                options: sources.map(\.option),
                selectedIndex: selected,
                accent: accent
            ) { index in
                mediaSelectSource(device, repository, sources[index].source)
            }

            if picks.isEmpty {
                GlassSettingRow(
                    title: "No source",
                    symbol: "link.badge.plus",
                    subtitle: "Pick a source above to start playing",
                    accent: accent
                )
            } else if device.mediaSource == .radio || device.mediaSource == .streaming {
                LiquidChipRow {
                    ForEach(Array(picks.enumerated()), id: \.offset) { index, item in
                        LiquidChip(
                            label: item.label,
                            symbol: item.symbol,
                            selected: index == pick && device.isOn,
                            accent: accent
                        ) {
                            mediaPickTrack(device, repository, pick: index, count: picks.count)
                        }
                    }
                }
                let current = picks[max(pick, 0)]
                GlassSettingRow(
                    title: current.label,
                    symbol: current.symbol,
                    subtitle: "\(current.detail) · \(device.trackTitle)",
                    accent: accent
                ) {
                    MediaPickDot(selected: live, accent: accent)
                }
            } else {
                ForEach(Array(picks.enumerated()), id: \.offset) { index, item in
                    let chosen = index == pick && device.isOn
                    GlassSettingRow(
                        title: item.label,
                        symbol: item.symbol,
                        subtitle: chosen ? "\(item.detail) · Active" : item.detail,
                        accent: accent,
                        action: { mediaPickTrack(device, repository, pick: index, count: picks.count) }
                    ) {
                        MediaPickDot(selected: chosen, accent: accent)
                    }
                }
            }
        }
    }
}

/// Selection marker: a glass orb that floods with accent and shows a live EQ glyph when chosen.
private struct MediaPickDot: View {
    let selected: Bool
    let accent: Color

    var body: some View {
        GlassIconOrb(
            symbol: selected ? "waveform" : "circle.fill",
            accent: accent,
            size: 30,
            glow: selected ? 1 : 0,
            iconTint: selected ? .white : NexColors.quaternary
        )
        .animation(GlassMotion.glow, value: selected)
    }
}

// MARK: - Sound

private struct MediaSoundSection: View {
    @Bindable var device: Device
    let kind: MediaKind
    let accent: Color
    let active: Bool

    var body: some View {
        let presets = kind == .speaker ? mediaSpeakerPresets : mediaTheaterPresets
        let activePreset = presets.first {
            abs(device.bass - $0.bass) < 0.05 && abs(device.treble - $0.treble) < 0.05
        }

        GlassSection(
            title: "Sound",
            symbol: "slider.vertical.3",
            accent: accent,
            trailing: AnyView(
                NexText(activePreset?.label ?? "Custom", .caption, color: accent).lineLimit(1)
            )
        ) {
            MediaEqCurve(bass: device.bass, treble: device.treble, accent: accent, active: active)
                .frame(height: 136)
            MediaToneSlider(
                label: "Bass",
                symbol: "waveform",
                value: device.bass,
                accent: accent
            ) { device.bass = $0 }
            MediaToneSlider(
                label: "Treble",
                symbol: "slider.horizontal.3",
                value: device.treble,
                accent: accent
            ) { device.treble = $0 }
            LiquidChipRow {
                ForEach(presets, id: \.label) { preset in
                    LiquidChip(
                        label: preset.label,
                        symbol: preset.symbol,
                        selected: preset.label == activePreset?.label,
                        accent: accent
                    ) {
                        device.bass = preset.bass
                        device.treble = preset.treble
                    }
                }
            }
        }
    }
}

/// Live EQ response curve: bass and treble shelves with a grid, gradient fill and handles.
private struct MediaEqCurve: View {
    let bass: Double
    let treble: Double
    let accent: Color
    let active: Bool

    private static let labels = ["60 Hz", "250 Hz", "1 kHz", "4 kHz", "16 kHz"]

    var body: some View {
        GlassPanel(
            shape: glassRect(22),
            tint: NexColors.glassTintLight,
            accent: accent,
            interactive: true,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: active ? 1 / 2.4 : 0) { phase in
                    EqCanvas(bass: bass, treble: treble, accent: accent, active: active, phase: phase)
                }
                .animation(GlassMotion.release, value: bass)
                .animation(GlassMotion.release, value: treble)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

/// The EQ curve itself, drawn with Canvas so the response path and its fill are built once.
private struct EqCanvas: View {
    let bass: Double
    let treble: Double
    let accent: Color
    let active: Bool
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 16
            let right = size.width - 16
            let top: CGFloat = 14
            let bottom = size.height - 30
            guard right > left, bottom > top else { return }
            let mid = (top + bottom) / 2
            let amp = (bottom - top) / 2 * 0.86
            let beat = mediaBeat(phase) * (active ? 1 : 0)

            // Grid.
            var grid = Path()
            grid.move(to: CGPoint(x: left, y: mid))
            grid.addLine(to: CGPoint(x: right, y: mid))
            context.stroke(grid, with: .color(.white.opacity(0.16)), lineWidth: 1)
            var verticals = Path()
            for k in 0..<5 {
                let x = left + (right - left) * CGFloat(k) / 4
                verticals.move(to: CGPoint(x: x, y: top))
                verticals.addLine(to: CGPoint(x: x, y: bottom))
            }
            context.stroke(verticals, with: .color(.white.opacity(0.08)), lineWidth: 1)

            // Response curve.
            var curve = Path()
            let steps = 48
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let gain = bass * (1 - eqSmooth(0.12, 0.46, t))
                    + treble * eqSmooth(0.54, 0.9, t)
                    + (0.05 + 0.08 * beat) * (active ? 1 : 0) * sin(t * 18 + phase * 4 * .pi)
                let x = left + (right - left) * CGFloat(t)
                let y = mid - CGFloat(clamp(gain, -1.15, 1.15)) * amp
                if i == 0 { curve.move(to: CGPoint(x: x, y: y)) } else {
                    curve.addLine(to: CGPoint(x: x, y: y))
                }
            }

            var filled = curve
            filled.addLine(to: CGPoint(x: right, y: bottom))
            filled.addLine(to: CGPoint(x: left, y: bottom))
            filled.closeSubpath()
            context.fill(
                filled,
                with: .linearGradient(
                    Gradient(colors: [accent.opacity(0.42), accent.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: top),
                    endPoint: CGPoint(x: 0, y: bottom)
                )
            )
            context.stroke(
                curve,
                with: .color(accent),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )

            // Handles.
            for (index, value) in [bass, treble].enumerated() {
                let x = left + (right - left) * (index == 0 ? 0.1 : 0.9)
                let y = mid - CGFloat(clamp(value, -1, 1)) * amp
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 11, y: y - 11, width: 22, height: 22)),
                    with: .color(accent.opacity(0.3))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                    with: .color(.white)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func eqSmooth(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }
}

private struct MediaToneSlider: View {
    let label: String
    let symbol: String
    let value: Double
    let accent: Color
    let onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                NexText(label, .bodyStrong).lineLimit(1)
                Spacer()
                NexText(mediaDb(value), .label, color: NexColors.secondary).lineLimit(1)
            }
            LiquidSlider(value: value, range: -1...1, accent: accent, onChange: onChange)
        }
    }
}

// MARK: - Grouping

private struct MediaGroupSection: View {
    @Bindable var device: Device
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let peers = Array(
            repository.devices(ofKind: .mediaPlayer)
                .filter { $0.id != device.id && $0.type != .tv }
                .prefix(6)
        )
        let grouped = peers.filter { device.groupedWith.contains($0.id) }.count

        GlassSection(
            title: "Speaker group",
            symbol: "hifispeaker.2.fill",
            accent: accent,
            trailing: AnyView(
                NexText(
                    grouped == 0 ? "Solo" : "\(grouped + 1) in sync",
                    .caption,
                    color: grouped == 0 ? NexColors.tertiary : accent
                )
                .lineLimit(1)
            )
        ) {
            if peers.isEmpty {
                GlassSettingRow(
                    title: "No other speakers",
                    symbol: "homepod.fill",
                    subtitle: "Add a speaker to play in sync",
                    accent: accent
                )
            } else {
                MediaConstellation(device: device, peers: peers, accent: accent)
                    .frame(height: 172)
                LiquidChipRow {
                    LiquidChip(
                        label: "Everywhere",
                        symbol: "hifispeaker.2.fill",
                        selected: grouped == peers.count,
                        accent: accent
                    ) {
                        for peer in peers { mediaSetGrouped(device, peer, true, repository) }
                    }
                    LiquidChip(
                        label: "Just this one",
                        symbol: "homepod.fill",
                        selected: grouped == 0,
                        accent: accent
                    ) {
                        for peer in peers { mediaSetGrouped(device, peer, false, repository) }
                    }
                }
                ForEach(peers) { peer in
                    GlassSettingRow(
                        title: peer.name,
                        symbol: peer.type == .soundbar ? "hifispeaker.fill" : "homepod.fill",
                        subtitle: "\(peer.room.displayName) · \(peerStatus(peer))",
                        accent: accent
                    ) {
                        LiquidToggle(
                            isOn: device.groupedWith.contains(peer.id),
                            accent: accent
                        ) { on in
                            mediaSetGrouped(device, peer, on, repository)
                        }
                    }
                }
                if grouped > 0 {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accent)
                            NexText("Group volume", .bodyStrong).lineLimit(1)
                            Spacer()
                            NexText("\((device.volume * 100).rounded0)%", .label, color: NexColors.secondary)
                        }
                        LiquidSlider(value: device.volume, accent: accent) { value in
                            device.volume = value
                            device.muted = false
                            for peer in peers where device.groupedWith.contains(peer.id) {
                                peer.volume = value
                            }
                        }
                    }
                }
            }
        }
    }

    private func peerStatus(_ peer: Device) -> String {
        if !peer.isOn { return "Standby" }
        return peer.isPlaying ? peer.trackTitle : "Idle"
    }
}

/// Grouped speakers plotted as glass dots around the current device, linked while in sync.
private struct MediaConstellation: View {
    let device: Device
    let peers: [Device]
    let accent: Color

    var body: some View {
        GlassPanel(shape: glassRect(22), tint: Color.black.opacity(0.072), heavy: true) {
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.36
                ZStack {
                    ForEach(Array(peers.enumerated()), id: \.element.id) { index, peer in
                        let angle = radians(-90 + 360 * Double(index) / Double(max(peers.count, 1)))
                        let point = CGPoint(
                            x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius
                        )
                        let linked = device.groupedWith.contains(peer.id)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: point)
                        }
                        .stroke(
                            linked ? accent.opacity(0.6) : Color.white.opacity(0.1),
                            style: StrokeStyle(lineWidth: linked ? 2 : 1, dash: linked ? [] : [4, 4])
                        )
                        ZStack {
                            Circle()
                                .fill(linked ? accent.opacity(0.35) : Color.white.opacity(0.12))
                                .frame(width: 34)
                            Image(systemName: peer.type == .soundbar ? "hifispeaker.fill" : "homepod.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(linked ? .white : NexColors.tertiary)
                        }
                        .position(point)
                    }
                    GlassIconOrb(
                        symbol: device.type == .soundbar ? "hifispeaker.fill" : "homepod.fill",
                        accent: accent,
                        size: 52,
                        glow: 0.8,
                        iconTint: .white
                    )
                    .position(center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Up next and device

private struct MediaUpNextSection: View {
    @Bindable var device: Device
    let kind: MediaKind
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let tracks = DeviceGenerator.tracks
        let current = mediaTrackIndex(device)
        let queue = (0..<4).map { (current + 1 + $0) % tracks.count }

        GlassSection(
            title: kind == .tv ? "Up next" : "Queue",
            symbol: "music.note.list",
            accent: accent,
            trailing: AnyView(
                NexText(
                    device.shuffle ? "Shuffle on" : "\(queue.count) up next",
                    .caption,
                    color: NexColors.secondary
                )
                .lineLimit(1)
            )
        ) {
            ForEach(queue, id: \.self) { index in
                let track = tracks[index]
                GlassSettingRow(
                    title: track.title,
                    subtitle: "\(track.artist) · \(mediaDuration(track.durationSec))",
                    accent: mediaHueColor(track.hue, 0.6, 1),
                    action: { mediaLoadTrack(device, repository, index) }
                ) {
                    MediaArtChip(hue: track.hue, symbol: kind == .tv ? "film.fill" : "music.note")
                }
            }
        }
    }
}

/// Small artwork chip: glass over its own gradient in the track hue.
private struct MediaArtChip: View {
    let hue: Double
    let symbol: String

    var body: some View {
        GlassPanel(
            shape: glassRect(12),
            tint: .clear,
            surface: AnyView(
                LinearGradient(
                    colors: [
                        mediaHueColor(hue - 30, 0.75, 1),
                        mediaHueColor(hue + 30, 0.85, 0.45),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        ) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 44, height: 44)
        }
    }
}

private struct MediaDeviceSection: View {
    let device: Device
    let kind: MediaKind
    let accent: Color
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let watts = repository.liveWatts(device)
        let spec = mediaSpec(kind)

        GlassSection(title: "Device", symbol: "wifi.router.fill", accent: accent) {
            HStack(spacing: 12) {
                GlassMetricTile(
                    label: "Power",
                    value: watts.fixed(0),
                    unit: "W",
                    symbol: "bolt.fill",
                    accent: accent,
                    history: device.powerHistory
                )
                GlassMetricTile(
                    label: "Today",
                    value: device.energyTodayKwh.fixed(2),
                    unit: "kWh",
                    symbol: "chart.line.uptrend.xyaxis",
                    accent: accent
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            GlassSettingRow(
                title: spec.0,
                symbol: spec.3,
                subtitle: spec.1,
                accent: accent
            ) {
                NexText(spec.2, .label, color: accent).lineLimit(1)
            }
            GlassSettingRow(
                title: "Signal",
                symbol: "wifi",
                subtitle: device.isOnline ? signalName(device.signalStrength) : "Offline",
                accent: accent
            ) {
                SignalBars(strength: device.signalStrength, accent: accent)
            }
            GlassSettingRow(
                title: "Firmware",
                symbol: "memorychip.fill",
                subtitle: "Up to date",
                accent: accent
            ) {
                NexText(device.firmwareVersion, .label, color: NexColors.secondary).lineLimit(1)
            }
        }
    }

    private func mediaSpec(_ kind: MediaKind) -> (String, String, String, String) {
        switch kind {
        case .tv:
            return ("Picture", "4K HDR · 120 Hz · Filmmaker mode", "4K", "tv.fill")
        case .soundbar:
            return ("Channels", "5.1.2 · Spatial audio · Dialogue enhance", "5.1.2", "hifispeaker.fill")
        case .speaker:
            return ("Audio", "Stereo · 24-bit / 96 kHz · Room tuning", "Hi-Res", "homepod.fill")
        }
    }
}

// MARK: - Media model helpers

enum MediaKind { case speaker, tv, soundbar }

func mediaKind(_ type: DeviceType) -> MediaKind {
    switch type {
    case .tv: return .tv
    case .soundbar: return .soundbar
    default: return .speaker
    }
}

/// 0...1 kick envelope, four beats per clock loop (100 bpm).
func mediaBeat(_ phase: Double) -> Double {
    let t = ((phase * 4).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
    return exp(-t * 7)
}

func mediaHueColor(_ hue: Double, _ saturation: Double, _ value: Double) -> Color {
    let h = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
    return Color(hue: h / 360, saturation: clamp01(saturation), brightness: clamp01(value))
}

private func mediaDefaultSource(_ kind: MediaKind) -> MediaSource {
    kind == .speaker ? .streaming : .tvInput
}

private func mediaSourceName(_ source: MediaSource, _ kind: MediaKind) -> String {
    switch source {
    case .streaming: return kind == .tv ? "Apps" : "Streaming"
    case .radio: return "Radio"
    case .bluetooth: return "Bluetooth"
    case .tvInput: return kind == .tv ? "Live TV · HDMI" : "TV audio · eARC"
    case .off: return "No source"
    }
}

func mediaDuration(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return String(format: "%d:%02d", s / 60, s % 60)
}

private func mediaDb(_ value: Double) -> String {
    let db = (value * 6).rounded0
    return db > 0 ? "+\(db) dB" : "\(db) dB"
}

private func mediaLoudnessName(_ volume: Double) -> String {
    if volume < 0.2 { return "Whisper quiet" }
    if volume < 0.45 { return "Comfortable" }
    if volume < 0.7 { return "Room filling" }
    return "Party loud"
}

/// Deterministic per-track waveform (0.25...1 bar heights).
private func mediaWaveform(_ seed: String) -> [Double] {
    var random = SeededRandom(seed: UInt64(bitPattern: Int64(seed.hashValue)))
    return (0..<44).map { index in
        let envelope = 0.55 + 0.45 * sin(Double(index) / 44 * .pi)
        return (0.25 + 0.75 * random.nextDouble()) * envelope
    }
}

private func mediaTrackIndex(_ device: Device) -> Int {
    max(DeviceGenerator.tracks.firstIndex { $0.title == device.trackTitle } ?? 0, 0)
}

@MainActor
private func mediaForEachPeer(_ device: Device, _ repo: DeviceRepository, _ action: (Device) -> Void) {
    for id in device.groupedWith {
        if let peer = repo.device(id: id) { action(peer) }
    }
}

@MainActor
private func mediaTogglePlay(_ device: Device, _ repo: DeviceRepository, _ kind: MediaKind) {
    let play = !(device.isOn && device.isPlaying)
    if play {
        device.isOn = true
        if device.mediaSource == .off { device.mediaSource = mediaDefaultSource(kind) }
    }
    device.isPlaying = play
    mediaForEachPeer(device, repo) { peer in
        if play { peer.isOn = true }
        peer.isPlaying = play
    }
}

@MainActor
private func mediaSeek(_ device: Device, by seconds: Double) {
    guard device.trackDurationSec > 0 else { return }
    device.trackProgress = clamp01(device.trackProgress + seconds / Double(device.trackDurationSec))
}

/// Loads catalog track `index` on the device (and its group) and starts playback.
@MainActor
private func mediaLoadTrack(_ device: Device, _ repo: DeviceRepository, _ index: Int) {
    DeviceGenerator.applyTrack(device, index: index)
    device.isOn = true
    device.isPlaying = true
    if device.mediaSource == .off { device.mediaSource = .streaming }
    mediaForEachPeer(device, repo) { peer in
        DeviceGenerator.applyTrack(peer, index: index)
        peer.isOn = true
        peer.isPlaying = true
    }
}

/// Loads a track whose index maps to pick `pick` of `count` (always a different track than now).
@MainActor
private func mediaPickTrack(_ device: Device, _ repo: DeviceRepository, pick: Int, count: Int) {
    guard count > 0 else { return }
    let blocks = max(1, DeviceGenerator.tracks.count / count)
    let block = (mediaTrackIndex(device) / count + 1) % blocks
    mediaLoadTrack(device, repo, pick + count * block)
}

@MainActor
private func mediaSelectSource(_ device: Device, _ repo: DeviceRepository, _ source: MediaSource) {
    device.isOn = true
    device.mediaSource = source
    device.isPlaying = true
    repo.nextTrack(device)
}

@MainActor
private func mediaLaunchApp(_ device: Device, _ repo: DeviceRepository, _ index: Int) {
    let app = mediaTvApps[((index % mediaTvApps.count) + mediaTvApps.count) % mediaTvApps.count]
    device.isOn = true
    device.mediaSource = app.source
    device.isPlaying = true
    repo.nextTrack(device)
}

/// Joins/leaves a peer to the device's group, keeping every member's `groupedWith` a full mesh.
@MainActor
private func mediaSetGrouped(
    _ device: Device,
    _ peer: Device,
    _ grouped: Bool,
    _ repo: DeviceRepository
) {
    if grouped {
        guard !device.groupedWith.contains(peer.id) else { return }
        for id in peer.groupedWith {
            repo.device(id: id)?.groupedWith.remove(peer.id)
        }
        let members = device.groupedWith.union([device.id, peer.id])
        for id in members {
            repo.device(id: id)?.groupedWith = members.subtracting([id])
        }
        peer.trackTitle = device.trackTitle
        peer.trackArtist = device.trackArtist
        peer.trackDurationSec = device.trackDurationSec
        peer.artworkHue = device.artworkHue
        peer.trackProgress = device.trackProgress
        peer.nowPlaying = device.nowPlaying
        peer.volume = device.volume
        if peer.mediaSource == .off { peer.mediaSource = .streaming }
        if device.isOn && device.isPlaying {
            peer.isOn = true
            peer.isPlaying = true
        }
    } else {
        guard device.groupedWith.contains(peer.id) else { return }
        for id in peer.groupedWith {
            repo.device(id: id)?.groupedWith.remove(peer.id)
        }
        peer.groupedWith = []
    }
}

// MARK: - Media catalog data

private struct MediaSourceOption {
    let source: MediaSource
    let option: SegmentOption
}

private struct MediaPick {
    let label: String
    let detail: String
    let symbol: String
}

private struct MediaApp {
    let label: String
    let symbol: String
    let hue: Double
    let source: MediaSource
}

private struct MediaPreset {
    let label: String
    let symbol: String
    let bass: Double
    let treble: Double
}

private struct MediaVolumePreset {
    let label: String
    let symbol: String
    let level: Double
}

private func mediaSources(for kind: MediaKind) -> [MediaSourceOption] {
    switch kind {
    case .speaker:
        return [
            MediaSourceOption(source: .streaming, option: SegmentOption("Stream", "dot.radiowaves.up.forward")),
            MediaSourceOption(source: .radio, option: SegmentOption("Radio", "antenna.radiowaves.left.and.right")),
            MediaSourceOption(source: .bluetooth, option: SegmentOption("Bluetooth", "wave.3.right")),
        ]
    case .tv:
        return [
            MediaSourceOption(source: .tvInput, option: SegmentOption("Inputs", "app.connected.to.app.below.fill")),
            MediaSourceOption(source: .streaming, option: SegmentOption("Apps", "square.grid.2x2.fill")),
            MediaSourceOption(source: .bluetooth, option: SegmentOption("Bluetooth", "wave.3.right")),
        ]
    case .soundbar:
        return [
            MediaSourceOption(source: .tvInput, option: SegmentOption("TV", "tv.fill")),
            MediaSourceOption(source: .streaming, option: SegmentOption("Stream", "dot.radiowaves.up.forward")),
            MediaSourceOption(source: .bluetooth, option: SegmentOption("Bluetooth", "wave.3.right")),
            MediaSourceOption(source: .radio, option: SegmentOption("Radio", "antenna.radiowaves.left.and.right")),
        ]
    }
}

private func mediaPicks(for source: MediaSource, kind: MediaKind) -> [MediaPick] {
    switch source {
    case .tvInput: return kind == .tv ? mediaTvInputs : mediaAudioInputs
    case .radio: return mediaStations
    case .bluetooth: return mediaBluetoothDevices
    case .streaming: return kind == .tv ? mediaTvCollections : mediaPlaylists
    case .off: return []
    }
}

private let mediaTvInputs = [
    MediaPick(label: "HDMI 1", detail: "Game console · 4K 120 Hz", symbol: "gamecontroller.fill"),
    MediaPick(label: "HDMI 2", detail: "Streaming box · Dolby Vision", symbol: "airplayvideo"),
    MediaPick(label: "HDMI 3", detail: "Blu-ray player", symbol: "opticaldisc.fill"),
    MediaPick(label: "Antenna", detail: "Live channels", symbol: "tv.badge.wifi"),
]

private let mediaAudioInputs = [
    MediaPick(label: "HDMI eARC", detail: "Living room TV", symbol: "tv.fill"),
    MediaPick(label: "Optical", detail: "Digital audio in", symbol: "waveform"),
    MediaPick(label: "HDMI in", detail: "Game console passthrough", symbol: "gamecontroller.fill"),
    MediaPick(label: "AUX", detail: "3.5 mm line in", symbol: "headphones"),
]

private let mediaStations = [
    MediaPick(label: "88.1 Jazz", detail: "Smooth jazz · FM", symbol: "antenna.radiowaves.left.and.right"),
    MediaPick(label: "90.3 Indie", detail: "Alternative · FM", symbol: "antenna.radiowaves.left.and.right"),
    MediaPick(label: "97.5 Lo-fi", detail: "Beats to relax · Web", symbol: "dot.radiowaves.left.and.right"),
    MediaPick(label: "101.9 Classics", detail: "Rock classics · FM", symbol: "antenna.radiowaves.left.and.right"),
]

private let mediaBluetoothDevices = [
    MediaPick(label: "Alex's phone", detail: "Paired · AAC", symbol: "iphone"),
    MediaPick(label: "Work laptop", detail: "Paired · SBC", symbol: "laptopcomputer"),
    MediaPick(label: "Kitchen tablet", detail: "Paired · AAC", symbol: "ipad"),
    MediaPick(label: "Headphones", detail: "Paired · LDAC", symbol: "headphones"),
]

private let mediaPlaylists = [
    MediaPick(label: "Daily mix", detail: "Made for you", symbol: "music.note.list"),
    MediaPick(label: "Focus flow", detail: "Instrumental", symbol: "opticaldisc.fill"),
    MediaPick(label: "Chill vibes", detail: "Downtempo", symbol: "music.note"),
    MediaPick(label: "Workout", detail: "High energy", symbol: "bolt.fill"),
]

private let mediaTvCollections = [
    MediaPick(label: "Movies", detail: "Continue watching", symbol: "film.fill"),
    MediaPick(label: "Series", detail: "New episodes", symbol: "rectangle.stack.fill"),
    MediaPick(label: "Live sports", detail: "On now", symbol: "sportscourt.fill"),
    MediaPick(label: "Cinema", detail: "Premieres", symbol: "theatermasks.fill"),
]

private let mediaTvColumns = 4

private let mediaTvApps = [
    MediaApp(label: "Stream", symbol: "film.fill", hue: 350, source: .streaming),
    MediaApp(label: "Live TV", symbol: "tv.badge.wifi", hue: 210, source: .tvInput),
    MediaApp(label: "Music", symbol: "music.note.list", hue: 290, source: .streaming),
    MediaApp(label: "Games", symbol: "gamecontroller.fill", hue: 120, source: .tvInput),
    MediaApp(label: "Cinema", symbol: "theatermasks.fill", hue: 25, source: .streaming),
    MediaApp(label: "Library", symbol: "rectangle.stack.fill", hue: 45, source: .streaming),
    MediaApp(label: "Cast", symbol: "airplayvideo", hue: 180, source: .streaming),
    MediaApp(label: "Apps", symbol: "square.grid.2x2.fill", hue: 260, source: .streaming),
]

private let mediaSpeakerPresets = [
    MediaPreset(label: "Flat", symbol: "slider.horizontal.3", bass: 0, treble: 0),
    MediaPreset(label: "Bass boost", symbol: "waveform", bass: 0.7, treble: 0),
    MediaPreset(label: "Vocal", symbol: "mic.fill", bass: -0.2, treble: 0.5),
    MediaPreset(label: "Bright", symbol: "slider.vertical.3", bass: 0, treble: 0.8),
    MediaPreset(label: "Late night", symbol: "moon.stars.fill", bass: -0.5, treble: -0.2),
]

private let mediaTheaterPresets = [
    MediaPreset(label: "Flat", symbol: "slider.horizontal.3", bass: 0, treble: 0),
    MediaPreset(label: "Movie", symbol: "theatermasks.fill", bass: 0.5, treble: 0.3),
    MediaPreset(label: "Music", symbol: "music.note", bass: 0.3, treble: 0.2),
    MediaPreset(label: "Voice", symbol: "mic.fill", bass: -0.3, treble: 0.6),
    MediaPreset(label: "Night", symbol: "moon.fill", bass: -0.5, treble: -0.2),
]

private let mediaVolumePresets = [
    MediaVolumePreset(label: "Whisper", symbol: "speaker.slash.fill", level: 0.15),
    MediaVolumePreset(label: "Chat", symbol: "speaker.wave.1.fill", level: 0.35),
    MediaVolumePreset(label: "Room", symbol: "speaker.wave.3.fill", level: 0.55),
    MediaVolumePreset(label: "Party", symbol: "hifispeaker.2.fill", level: 0.8),
]
