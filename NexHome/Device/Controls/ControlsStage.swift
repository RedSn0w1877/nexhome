import SwiftUI

/// Drives a 0...1 phase at `cyclesPerSecond` for live visuals (blades, waves, ripples, steam).
/// At zero it renders a single static frame, so an idle stage costs nothing.
struct PhaseTimeline<Content: View>: View {
    let cyclesPerSecond: Double
    @ViewBuilder var content: (Double) -> Content

    var body: some View {
        if cyclesPerSecond > 0.0001 {
            TimelineView(.animation) { context in
                content(
                    (context.date.timeIntervalSinceReferenceDate * cyclesPerSecond)
                        .truncatingRemainder(dividingBy: 1)
                )
            }
        } else {
            content(0)
        }
    }
}

/// Heavy glass "stage" whose surface draws a live aura; the dial or orb placed on it sits over that
/// aura, which is what gave the Android sheets their depth.
struct HeroStage<Aura: View, Content: View>: View {
    @ViewBuilder var aura: () -> Aura
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassPanel(
            shape: glassRect(24),
            tint: Color.black.opacity(0.12),
            heavy: true,
            surface: AnyView(aura())
        ) {
            VStack {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

/// A soft thermal aura: a broad accent glow plus drifting particles while the equipment runs.
struct ThermalAura: View {
    let color: Color
    /// 0 = off, 0.3 = idle, 1 = actively heating or cooling.
    let glow: Double
    let rising: Bool

    var body: some View {
        let particles = clamp01((glow - 0.3) / 0.7)
        PhaseTimeline(cyclesPerSecond: particles > 0.02 ? 0.16 : 0) { phase in
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    RadialGradient(
                        colors: [color.opacity(0.26 * glow), .clear],
                        center: UnitPoint(x: 0.5, y: rising ? 0.85 : 0.15),
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.72
                    )
                    .blendMode(.plusLighter)

                    if particles > 0.02 {
                        ForEach(0..<9, id: \.self) { index in
                            let seed = Double(index) * 0.618
                            let t = (phase * (1 + Double(index % 2)) + seed)
                                .truncatingRemainder(dividingBy: 1)
                            let x = size.width * (0.1 + 0.8 * seed.truncatingRemainder(dividingBy: 1))
                            let travel = rising ? (1 - t) : t
                            Circle()
                                .fill(
                                    color.opacity(sin(t * .pi) * 0.4 * particles)
                                )
                                .frame(width: 5 + CGFloat(index % 3) * 2)
                                .position(x: x, y: size.height * (0.1 + 0.8 * travel))
                                .blendMode(.plusLighter)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Small glass capsule with a status dot that ripples while `pulsing`.
struct StatusBadge: View {
    let text: String
    let color: Color
    var pulsing: Bool = false

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: NexColors.glassTintLight,
            surface: AnyView(
                PhaseTimeline(cyclesPerSecond: pulsing ? 0.8 : 0) { phase in
                    ZStack {
                        if pulsing {
                            Circle()
                                .fill(color.opacity(0.45 * (1 - phase)))
                                .frame(width: 7 + 12 * CGFloat(phase))
                        }
                        Circle().fill(color).frame(width: 7)
                    }
                    .frame(width: 26, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            )
        ) {
            NexText(text, .caption)
                .lineLimit(1)
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .padding(.vertical, 5)
        }
    }
}

/// Icon + value + caption column used under the hero dials.
struct Readout: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(NexType.bodyStrong.font.monospacedDigit())
                .foregroundStyle(NexColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            NexText(label, .caption, color: NexColors.tertiary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Glass capsule level bar; the fill springs (with a bouncy overshoot) to `fraction`.
struct GlassLevelBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: Color.black.opacity(0.2),
            surface: AnyView(
                GeometryReader { proxy in
                    let h = proxy.size.height
                    let w = max(proxy.size.width * CGFloat(clamp01(fraction)), h)
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.85)).frame(width: w, height: h)
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: max(w - h * 0.6, 0), height: h * 0.22)
                            .offset(x: h * 0.3, y: -h * 0.16)
                    }
                }
                .animation(GlassMotion.release, value: fraction)
            )
        ) {
            Color.clear.frame(height: 14)
        }
    }
}

/// Filter life row with a reset button and a level bar.
struct FilterCare: View {
    @Bindable var device: Device

    var body: some View {
        let life = device.filterLifePercent
        let color = filterColor(life)
        VStack(spacing: 10) {
            GlassSettingRow(
                title: "Filter",
                symbol: "line.3.horizontal.decrease.circle.fill",
                subtitle: life <= 10
                    ? "\(life)% · replace now"
                    : "\(life)% · ~\(max(Int((Double(life) * 0.12).rounded()), 1)) weeks left",
                accent: color
            ) {
                LiquidButton(tint: life < 25 ? color : nil, action: { device.filterLifePercent = 100 }) {
                    NexText("Reset", .label).lineLimit(1)
                }
            }
            GlassLevelBar(fraction: Double(life) / 100, color: color)
        }
    }
}

struct FirmwareRow: View {
    let device: Device

    var body: some View {
        GlassSettingRow(
            title: "Firmware",
            symbol: "arrow.down.circle.fill",
            subtitle: "Up to date · signal \(device.signalStrength)/4",
            accent: NexColors.violet
        ) {
            NexText("v\(device.firmwareVersion)", .caption, color: NexColors.tertiary).lineLimit(1)
        }
    }
}

/// 24 h temperature chart inside glass: gradient area, dashed target line, ripple at "now".
struct TemperatureTimeline: View {
    let history: [Double]
    let target: Double
    let color: Color
    let title: String
    var live: Bool = false

    var body: some View {
        GlassPanel(
            shape: glassRect(22),
            tint: NexColors.glassTintLight,
            interactive: true,
            surface: AnyView(
                TemperatureChart(history: history, target: target, color: color, live: live)
            )
        ) {
            VStack(spacing: 0) {
                HStack {
                    NexText(title, .caption, color: NexColors.secondary).lineLimit(1)
                    Spacer()
                    NexText("Target \(target.rounded0)°", .caption, color: NexColors.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack {
                    NexText("24h ago", .caption, color: NexColors.tertiary).lineLimit(1)
                    Spacer()
                    NexText("12h", .caption, color: NexColors.tertiary).lineLimit(1)
                    Spacer()
                    NexText("Now", .caption, color: NexColors.secondary).lineLimit(1)
                }
            }
            .frame(height: 170)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct TemperatureChart: View {
    let history: [Double]
    let target: Double
    let color: Color
    let live: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if history.count >= 2, size.width > 40, size.height > 80 {
                let pad: CGFloat = 14
                let top: CGFloat = 46
                let bottom = size.height - 30
                let minV = (min(history.min() ?? target, target)) - 1
                let maxV = (max(history.max() ?? target, target)) + 1
                let span = max(maxV - minV, 0.001)
                let band = max(bottom - top, 1)
                let stepX = (size.width - pad * 2) / CGFloat(history.count - 1)
                let points = history.enumerated().map { index, value in
                    CGPoint(
                        x: pad + stepX * CGFloat(index),
                        y: bottom - CGFloat((value - minV) / span) * band
                    )
                }
                let targetY = bottom - CGFloat((target - minV) / span) * band
                let end = points.last ?? .zero

                ZStack {
                    // Dashed target line.
                    Path { path in
                        path.move(to: CGPoint(x: pad, y: targetY))
                        path.addLine(to: CGPoint(x: size.width - pad, y: targetY))
                    }
                    .stroke(
                        Color.white.opacity(0.32),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )

                    // Area fill.
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: bottom))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: end.x, y: bottom))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    PhaseTimeline(cyclesPerSecond: live ? 0.7 : 0) { phase in
                        ZStack {
                            if live {
                                Circle()
                                    .fill(color.opacity(0.4 * (1 - phase)))
                                    .frame(width: 8 + 18 * CGFloat(phase))
                            }
                            Circle().fill(Color.white).frame(width: 8)
                            Circle().fill(color).frame(width: 4.8)
                        }
                        .position(end)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 24 h day strip: the on...off window lit in `color`, a marker at the current time.
struct ScheduleStrip: View {
    let onHour: Int
    let offHour: Int
    let color: Color
    let comfortLabel: String
    let setbackLabel: String

    var body: some View {
        let nowFraction: Double = {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
            return (Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60) / 24
        }()

        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintLight,
            surface: AnyView(
                GeometryReader { proxy in
                    let size = proxy.size
                    let pad: CGFloat = 14
                    let barHeight: CGFloat = 10
                    let top = size.height - 14 - barHeight
                    let width = max(size.width - pad * 2, 1)
                    let start = Double(clamp(onHour, 0, 23)) / 24
                    let end = Double(clamp(offHour, 0, 23)) / 24

                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: width, height: barHeight)
                            .offset(x: pad, y: top)

                        if start < end {
                            Capsule()
                                .fill(color.opacity(0.85))
                                .frame(width: width * CGFloat(end - start), height: barHeight)
                                .offset(x: pad + width * CGFloat(start), y: top)
                        } else if start > end {
                            Capsule()
                                .fill(color.opacity(0.85))
                                .frame(width: width * CGFloat(1 - start), height: barHeight)
                                .offset(x: pad + width * CGFloat(start), y: top)
                            if end > 0 {
                                Capsule()
                                    .fill(color.opacity(0.85))
                                    .frame(width: width * CGFloat(end), height: barHeight)
                                    .offset(x: pad, y: top)
                            }
                        }

                        Capsule()
                            .fill(Color.white)
                            .frame(width: 2, height: barHeight + 10)
                            .offset(x: pad + width * CGFloat(nowFraction) - 1, y: top - 5)
                    }
                }
                .animation(GlassMotion.release, value: onHour)
                .animation(GlassMotion.release, value: offHour)
            )
        ) {
            VStack {
                HStack {
                    NexText(comfortLabel, .label).lineLimit(1)
                    Spacer()
                    NexText(setbackLabel, .caption, color: NexColors.tertiary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 76)
            .padding(.horizontal, 14)
            .padding(.top, 12)
        }
    }
}

// MARK: - Shared formatting

func timerLabel(_ minutes: Int) -> String {
    if minutes <= 0 { return "Off" }
    if minutes < 60 { return "\(minutes)m" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return "\(minutes / 60)h \(minutes % 60)m"
}

func filterColor(_ life: Int) -> Color {
    if life > 50 { return NexColors.mint }
    if life > 20 { return NexColors.amber }
    return NexColors.red
}

let costPerKwh = 0.28
let idleColor = Color(hex: 0x9AA3B5)
let heatColor = NexColors.orange
let coolColor = NexColors.blue
let ecoColor = NexColors.mint
