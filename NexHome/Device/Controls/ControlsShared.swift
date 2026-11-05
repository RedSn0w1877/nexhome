import SwiftUI

let energyRate = 0.28

// MARK: - Device info

/// The "Device" section every sheet ends with: favourite, signal and firmware.
struct DeviceInfoSection: View {
    @Bindable var device: Device
    let accent: Color

    var body: some View {
        GlassSection(title: "Device", symbol: "wifi.router.fill", accent: accent) {
            GlassSettingRow(
                title: "Favorite",
                symbol: "star",
                subtitle: "Pin to the Home screen",
                accent: accent
            ) {
                LiquidToggle(isOn: device.isFavorite, accent: accent) { device.isFavorite = $0 }
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
}

/// Small glass capsule with four signal bars drawn inside the glass; lit bars glide in.
struct SignalBars: View {
    let strength: Int
    let accent: Color

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: NexColors.glassTintDark,
            surface: AnyView(
                GeometryReader { proxy in
                    let size = proxy.size
                    let barWidth: CGFloat = 4
                    let gap: CGFloat = 3
                    let total = barWidth * 4 + gap * 3
                    let startX = (size.width - total) / 2
                    let bottom = size.height * 0.74
                    let maxHeight = size.height * 0.48
                    ForEach(0..<4, id: \.self) { index in
                        let barHeight = maxHeight * (0.35 + 0.65 * CGFloat(index) / 3)
                        let on = clamp01(Double(strength - index))
                        Capsule()
                            .fill(Color.white.opacity(0.2).lerp(to: accent, on))
                            .frame(width: barWidth, height: barHeight)
                            .position(
                                x: startX + CGFloat(index) * (barWidth + gap) + barWidth / 2,
                                y: bottom - barHeight / 2
                            )
                    }
                }
                .animation(GlassMotion.release, value: strength)
            )
        ) {
            Color.clear.frame(width: 56, height: 32)
        }
    }
}

func signalName(_ bars: Int) -> String {
    switch bars {
    case 4...: return "Excellent · 4/4"
    case 3: return "Good · 3/4"
    case 2: return "Fair · 2/4"
    default: return "Weak · \(bars)/4"
    }
}

// MARK: - Rows with a trailing control

/// A titled row with a trailing stepper, used for hours, durations and levels.
struct StepperRow: View {
    let title: String
    var subtitle: String?
    let value: Int
    var range: ClosedRange<Int> = 0...23
    var step: Int = 1
    var format: (Int) -> String
    var accent: Color
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                NexText(title, .bodyStrong).lineLimit(1)
                if let subtitle {
                    NexText(subtitle, .caption, color: NexColors.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            LiquidIntStepper(
                value: value,
                range: range,
                step: step,
                format: format,
                accent: accent,
                onChange: onChange
            )
        }
    }
}

/// A titled row with free-form trailing content.
struct ControlRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                NexText(title, .bodyStrong).lineLimit(1)
                if let subtitle {
                    NexText(subtitle, .caption, color: NexColors.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

func hourLabel(_ hour: Int) -> String {
    let h = ((hour % 24) + 24) % 24
    let twelve = h % 12 == 0 ? 12 : h % 12
    return "\(twelve) \(h < 12 ? "AM" : "PM")"
}

// MARK: - Hourly usage bars

/// 24 h usage history drawn inside glass (hourly watts, oldest first): the bars rise with a bouncy
/// overshoot when the sheet opens, the live hour glows in `accent` and the peak hour is labelled.
struct HourlyUsageBars: View {
    let history: [Double]
    let accent: Color
    var height: CGFloat = 120

    @State private var grow: Double = 0

    var body: some View {
        let peakIndex = history.indices.max { history[$0] < history[$1] }
        let peakHoursAgo = peakIndex.map { history.count - 1 - $0 } ?? -1

        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintDark,
            accent: accent,
            interactive: true,
            surface: AnyView(UsageBars(history: history, grow: grow, accent: accent))
        ) {
            VStack {
                Spacer(minLength: 0)
                HStack {
                    NexText("24 h ago", .caption, color: NexColors.tertiary).lineLimit(1)
                    Spacer()
                    if peakHoursAgo >= 0 {
                        NexText(
                            peakHoursAgo == 0 ? "Peak now" : "Peak \(peakHoursAgo) h ago",
                            .caption,
                            color: NexColors.secondary
                        )
                        .lineLimit(1)
                    }
                    Spacer()
                    NexText("Now", .caption, color: NexColors.tertiary).lineLimit(1)
                }
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .task {
            withAnimation(.spring(response: 0.662, dampingFraction: 0.5)) { grow = 1 }
        }
    }
}

private struct UsageBars: View {
    let history: [Double]
    let grow: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let n = history.count
            if n > 0, size.width > 0, size.height > 0 {
                let peak = max(history.max() ?? 1, 0.0001)
                let side: CGFloat = 12
                let top: CGFloat = 14
                let bottom = size.height - 30
                let maxBar = max(bottom - top, 1)
                let slot = (size.width - side * 2) / CGFloat(n)
                let barWidth = slot * 0.62
                ForEach(0..<n, id: \.self) { index in
                    let f = clamp01(history[index] / peak)
                    let barHeight = max(maxBar * CGFloat(f * grow), 2)
                    let x = side + slot * CGFloat(index) + slot / 2
                    let live = index == n - 1
                    let color: Color = live
                        ? accent
                        : (f >= 0.999 ? accent.lerp(to: .white, 0.3) : accent.opacity(0.42))
                    ZStack {
                        if live, grow > 0.01 {
                            Capsule()
                                .fill(accent.opacity(0.35))
                                .frame(width: barWidth * 3, height: barHeight + barWidth * 2)
                                .blur(radius: 6)
                                .blendMode(.plusLighter)
                        }
                        Capsule()
                            .fill(color)
                            .frame(width: barWidth, height: barHeight)
                    }
                    .position(x: x, y: bottom - barHeight / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 24 h schedule timeline

/// 24 h glass timeline: the on-window (wrapping past midnight) is drawn inside the glass and slides
/// with a bouncy spring when the hours change; a marker shows the current time.
struct ScheduleTimeline: View {
    let onHour: Int
    let offHour: Int
    let enabled: Bool
    let accent: Color

    private static let labels = ["12a", "6a", "12p", "6p", "12a"]

    var body: some View {
        let now: Double = {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
            return (Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60) / 24
        }()

        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintDark,
            surface: AnyView(
                ScheduleTrack(
                    on: Double(onHour) / 24,
                    off: Double(offHour) / 24,
                    enabled: enabled ? 1 : 0,
                    now: now,
                    accent: accent
                )
                .animation(GlassMotion.release, value: onHour)
                .animation(GlassMotion.release, value: offHour)
                .animation(GlassMotion.glow, value: enabled)
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
            .frame(height: 66)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

private struct ScheduleTrack: View {
    let on: Double
    let off: Double
    let enabled: Double
    let now: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let left: CGFloat = 18
            let span = max(width - left * 2, 1)
            let trackHeight: CGFloat = 10
            let cy: CGFloat = 22

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: span, height: trackHeight)
                    .offset(x: left, y: cy - trackHeight / 2)

                if off > on {
                    window(from: on, to: off, left: left, span: span, cy: cy, trackHeight: trackHeight)
                } else if off < on {
                    window(from: on, to: 1, left: left, span: span, cy: cy, trackHeight: trackHeight)
                    window(from: 0, to: off, left: left, span: span, cy: cy, trackHeight: trackHeight)
                }

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                        .offset(
                            x: left + span * CGFloat(index) / 4 - 1.5,
                            y: cy + trackHeight + 1.5
                        )
                }

                // Now marker.
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2, height: trackHeight * 1.6)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .offset(y: -3)
                }
                .offset(x: left + span * CGFloat(now) - 1, y: cy - trackHeight)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func window(
        from: Double,
        to: Double,
        left: CGFloat,
        span: CGFloat,
        cy: CGFloat,
        trackHeight: CGFloat
    ) -> some View {
        let width = span * CGFloat(to - from)
        if width > 0.5 {
            ZStack {
                Capsule()
                    .fill(accent.opacity(0.28 * enabled))
                    .frame(width: width + 6, height: trackHeight + 8)
                    .blendMode(.plusLighter)
                    .offset(x: -3, y: -4)
                Capsule()
                    .fill(accent.opacity(lerp(0.3, 0.95, enabled)))
                    .frame(width: width, height: trackHeight)
            }
            .frame(width: width, height: trackHeight, alignment: .topLeading)
            .offset(x: left + span * CGFloat(from), y: cy - trackHeight / 2)
        }
    }
}

// MARK: - Spectrum slider

/// A glass capsule track filled with a colour gradient inside the glass, and a draggable glass thumb
/// that sits over it. The thumb follows the model value with a liquid spring, swells while held and
/// shines `thumbColor` onto its neighbours. Tapping the track jumps there.
struct LiquidSpectrumSlider: View {
    let fraction: Double
    let colors: [Color]
    let thumbColor: Color
    let onChange: (Double) -> Void

    private let thumbWidth: CGFloat = 44

    @State private var dragging = false
    @State private var startFraction: Double = 0
    @State private var lastTick = -1
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let travel = max(width - thumbWidth, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 12)
                            .blendMode(.plusLighter)
                    }
                    .glassEffect(.regular, in: Capsule())
                    .frame(height: 30)
                    .contentShape(Capsule())
                    .onTapGesture { location in
                        let f = clamp01((location.x - thumbWidth / 2) / travel)
                        Haptics.tick()
                        withAnimation(GlassMotion.blob) { onChange(f) }
                    }

                Capsule()
                    .fill(Color.white.opacity(dragging ? 0.3 : 0.85))
                    .overlay {
                        Capsule().fill(thumbColor.opacity(dragging ? 0.5 : 0.25))
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    }
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .frame(width: thumbWidth, height: 34)
                    .scaleEffect(dragging ? 1.25 : 1)
                    .shadow(color: thumbColor.opacity(dragging ? 0.5 : 0.2), radius: 10)
                    .offset(x: CGFloat(clamp01(fraction)) * travel)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !dragging {
                                    dragging = true
                                    startFraction = fraction
                                    lastTick = Int((fraction * 24).rounded())
                                    light?.begin(token, at: globalPoint(value.location), color: thumbColor)
                                } else {
                                    light?.move(token, to: globalPoint(value.location))
                                }
                                let next = clamp01(
                                    startFraction + Double(value.translation.width / travel)
                                )
                                let tick = Int((next * 24).rounded())
                                if tick != lastTick {
                                    lastTick = tick
                                    Haptics.tick()
                                }
                                onChange(next)
                            }
                            .onEnded { _ in
                                dragging = false
                                light?.end(token)
                            }
                    )
            }
            .frame(width: width, height: 48)
        }
        .frame(height: 48)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .animation(dragging ? nil : GlassMotion.blob, value: fraction)
        .animation(GlassMotion.release, value: dragging)
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }
}

// MARK: - Activity rows

/// One row of a lock / garage activity log.
struct ActivityRow: View {
    let event: ActivityEvent
    let accent: Color
    var symbol: String?

    var body: some View {
        GlassPanel(shape: glassRect(18), tint: NexColors.glassTintLight) {
            HStack(spacing: 12) {
                Image(systemName: symbol ?? activitySymbol(event.label))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    NexText(event.label, .bodyStrong).lineLimit(1)
                    NexText(event.detail, .caption, color: NexColors.tertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
                NexText(relativeMinutes(event.minutesAgo), .caption, color: NexColors.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private func activitySymbol(_ label: String) -> String {
    let lower = label.lowercased()
    if lower.contains("unlock") { return "lock.open.fill" }
    if lower.contains("lock") { return "lock.fill" }
    if lower.contains("open") { return "door.left.hand.open" }
    if lower.contains("clos") { return "door.left.hand.closed" }
    if lower.contains("revers") { return "arrow.uturn.left" }
    if lower.contains("light") { return "lightbulb.fill" }
    return "clock.fill"
}

/// A simple two-up metric row, the shape most sections use for their stats.
struct MetricPair: View {
    let left: GlassMetricTile
    let right: GlassMetricTile

    var body: some View {
        HStack(spacing: 12) {
            left
            right
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
