import SwiftUI

// MARK: - LiquidButton

/// A glass capsule button: swells to `buttonPressScale` and bounces back, the glow glides after the
/// finger, and a tinted button shines its tint onto its neighbours while held.
struct LiquidButton<Content: View>: View {
    var tint: Color?
    var surfaceColor: Color?
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: surfaceColor ?? .clear,
            glassTint: tint?.opacity(0.75),
            accent: tint,
            pressScale: GlassMotion.buttonPressScale,
            action: action
        ) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
        }
    }
}

// MARK: - LiquidToggle

/// A real draggable glass blob switch: flick it, drag it partway and let go, and it springs (with
/// overshoot) to whichever side it is closer to.
struct LiquidToggle: View {
    let isOn: Bool
    var accent: Color = Color(hex: 0x30D158)
    var trackColor: Color = NexColors.track
    let onChange: (Bool) -> Void

    private let trackWidth: CGFloat = 64
    private let trackHeight: CGFloat = 28
    private let thumbWidth: CGFloat = 40
    private let thumbHeight: CGFloat = 24
    private var travel: CGFloat { trackWidth - thumbWidth - 4 }

    @State private var fraction: CGFloat = 0
    @State private var dragging = false
    @State private var didDrag = false
    @State private var startFraction: CGFloat = 0
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?
    @State private var frame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(trackColor.lerp(to: accent, Double(clamp01(fraction))))
                .frame(width: trackWidth, height: trackHeight)

            Capsule()
                .fill(Color.white.opacity(dragging ? 0.45 : 1))
                .frame(width: thumbWidth, height: thumbHeight)
                .glassEffect(.regular.interactive(), in: Capsule())
                .scaleEffect(x: dragging ? 1.06 : 1, y: dragging ? 1.12 : 1)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                .offset(x: 2 + travel * clamp01(fraction))
        }
        .frame(width: trackWidth, height: trackHeight)
        .contentShape(Capsule())
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !dragging {
                        dragging = true
                        didDrag = false
                        startFraction = fraction
                        light?.begin(token, at: globalPoint(value.location), color: accent)
                    } else {
                        light?.move(token, to: globalPoint(value.location))
                    }
                    if abs(value.translation.width) > 1 { didDrag = true }
                    if didDrag {
                        fraction = clamp01(startFraction + value.translation.width / travel)
                    }
                }
                .onEnded { _ in
                    dragging = false
                    light?.end(token)
                    let target: CGFloat = didDrag ? (fraction >= 0.5 ? 1 : 0) : (isOn ? 0 : 1)
                    withAnimation(GlassMotion.blob) { fraction = target }
                    let next = target == 1
                    if next != isOn {
                        Haptics.tick()
                        onChange(next)
                    }
                    didDrag = false
                }
        )
        .onAppear { fraction = isOn ? 1 : 0 }
        .onChange(of: isOn) { _, newValue in
            guard !dragging else { return }
            withAnimation(GlassMotion.blob) { fraction = newValue ? 1 : 0 }
        }
        .animation(dragging ? nil : GlassMotion.blob, value: dragging)
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }
}

// MARK: - LiquidSlider

/// Glass blob slider: the thumb wobbles and squashes while dragged and emits `accent` as light.
struct LiquidSlider: View {
    let value: Double
    var range: ClosedRange<Double> = 0...1
    var accent: Color = Color(hex: 0x0091FF)
    var trackColor: Color = NexColors.track
    let onChange: (Double) -> Void
    var onCommit: (() -> Void)?

    private let thumbWidth: CGFloat = 40
    private let thumbHeight: CGFloat = 24

    @State private var dragging = false
    @State private var startValue: Double = 0
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return clamp01((value - range.lowerBound) / span)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor).frame(height: 6)
                Capsule().fill(accent)
                    .frame(width: max(width * progress, 0), height: 6)
                Capsule()
                    .fill(Color.white.opacity(dragging ? 0.45 : 1))
                    .frame(width: thumbWidth, height: thumbHeight)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .scaleEffect(x: dragging ? 1.08 : 1, y: dragging ? 1.14 : 1)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                    .offset(
                        x: clamp(
                            width * progress - thumbWidth / 2,
                            -thumbWidth / 4,
                            max(width - thumbWidth * 0.75, 0)
                        )
                    )
            }
            .frame(height: thumbHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let span = range.upperBound - range.lowerBound
                        if !dragging {
                            dragging = true
                            startValue = value
                            light?.begin(token, at: globalPoint(gesture.location), color: accent)
                        } else {
                            light?.move(token, to: globalPoint(gesture.location))
                        }
                        let delta = span * Double(gesture.translation.width / max(width, 1))
                        onChange(clamp(startValue + delta, range.lowerBound, range.upperBound))
                    }
                    .onEnded { _ in
                        dragging = false
                        light?.end(token)
                        onCommit?()
                    }
            )
        }
        .frame(height: 34)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .animation(GlassMotion.release, value: dragging)
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }
}

// MARK: - LiquidChip

/// A selectable glass capsule (scenes, programs, modes). Selecting floods it with `accent` and
/// makes it bounce a little bigger.
struct LiquidChip: View {
    let label: String
    var symbol: String?
    let selected: Bool
    var accent: Color = NexColors.cyan
    let action: () -> Void

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: .clear,
            glassTint: selected ? accent.opacity(0.6) : nil,
            accent: accent,
            pressScale: GlassMotion.buttonPressScale,
            action: {
                Haptics.tick()
                action()
            }
        ) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? .white : accent)
                }
                NexText(label, .label, color: selected ? .white : NexColors.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, symbol != nil ? 14 : 16)
            .frame(height: 40)
        }
        .overlay {
            if selected {
                Capsule()
                    .strokeBorder(accent.opacity(0.8), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(selected ? 1.04 : 1)
        .animation(GlassMotion.release, value: selected)
    }
}

/// Horizontally scrolling row of chips. Vertical padding leaves room for their swell.
struct LiquidChipRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // One container for the row: neighbouring chips share a sampling region and melt into
            // each other as they swell under the finger, the way system glass groups do.
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 8) {
                    content()
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
    }
}

// MARK: - LiquidColorOrbs

/// A row of glass colour orbs. The selected one swells, gains a white ring and a coloured glow.
struct LiquidColorOrbs: View {
    let colors: [Color]
    let selectedIndex: Int
    var orbSize: CGFloat = 44
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 14) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        ColorOrb(
                            color: color,
                            selected: index == selectedIndex,
                            size: orbSize
                        ) {
                            Haptics.tick()
                            onSelect(index)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
    }
}

private struct ColorOrb: View {
    let color: Color
    let selected: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: .clear,
            accent: color,
            pressScale: GlassMotion.orbPressScale,
            action: action,
            surface: AnyView(
                RadialGradient(
                    gradient: Gradient(colors: [
                        color.lerp(to: .white, 0.35).opacity(0.9),
                        color.opacity(0.82),
                    ]),
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: size
                )
            ),
            front: AnyView(
                Circle()
                    .strokeBorder(Color.white.opacity(selected ? 0.9 : 0), lineWidth: 2.5)
            )
        ) {
            Color.clear.frame(width: size, height: size)
        }
        .shadow(color: color.opacity(selected ? 0.6 : 0.25), radius: selected ? 18 : 10)
        .scaleEffect(selected ? 1.16 : 1)
        .animation(GlassMotion.release, value: selected)
    }
}

// MARK: - LiquidStepper

/// A glass capsule with liquid −/+ buttons. Tapping steps once; press-and-hold repeats with
/// acceleration. The value text bounces in the step direction on every change.
struct LiquidStepper: View {
    let value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var format: (Double) -> String = { "\(Int($0.rounded()))" }
    var label: String?
    var accent: Color = NexColors.cyan
    let onChange: (Double) -> Void

    @State private var bounce: CGFloat = 0
    @State private var direction: CGFloat = 1

    var body: some View {
        GlassPanel(shape: glassCapsule, tint: NexColors.glassTintDark) {
            HStack(spacing: 6) {
                StepperOrb(symbol: "minus", enabled: value > range.lowerBound, accent: accent) {
                    stepBy(-1)
                }
                VStack(spacing: 0) {
                    Text(format(value))
                        .font(NexType.bodyStrong.font.monospacedDigit())
                        .foregroundStyle(NexColors.primary)
                        .lineLimit(1)
                    if let label {
                        NexText(label, .caption, color: NexColors.tertiary).lineLimit(1)
                    }
                }
                .frame(minWidth: 64)
                .scaleEffect(1 + 0.22 * bounce)
                .offset(y: -direction * 6 * bounce)
                StepperOrb(symbol: "plus", enabled: value < range.upperBound, accent: accent) {
                    stepBy(1)
                }
            }
            .padding(5)
        }
        .onChange(of: value) { oldValue, newValue in
            direction = newValue > oldValue ? 1 : -1
            bounce = 1
            withAnimation(GlassMotion.release) { bounce = 0 }
        }
    }

    @discardableResult
    private func stepBy(_ sign: Double) -> Bool {
        let next = clamp(value + sign * step, range.lowerBound, range.upperBound)
        guard next != value else { return false }
        Haptics.tick()
        onChange(next)
        return true
    }
}

/// `LiquidStepper` for integer fields (e.g. `device.autoLockSeconds`).
struct LiquidIntStepper: View {
    let value: Int
    var range: ClosedRange<Int> = 0...100
    var step: Int = 1
    var format: (Int) -> String = { "\($0)" }
    var label: String?
    var accent: Color = NexColors.cyan
    let onChange: (Int) -> Void

    var body: some View {
        LiquidStepper(
            value: Double(value),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            format: { format(Int($0.rounded())) },
            label: label,
            accent: accent,
            onChange: { onChange(Int($0.rounded())) }
        )
    }
}

/// Round liquid −/+ button with tap-to-step and accelerating hold-to-repeat.
private struct StepperOrb: View {
    let symbol: String
    let enabled: Bool
    let accent: Color
    let onStep: () -> Void

    @State private var repeatTask: Task<Void, Never>?
    @State private var pressing = false
    @State private var didRepeat = false

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: Color.white.opacity(0.1),
            accent: enabled ? accent : nil,
            interactive: true,
            pressScale: GlassMotion.buttonPressScale,
            surface: AnyView(accent.opacity(pressing ? 0.35 : 0))
        ) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.35))
                .frame(width: 40, height: 40)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard enabled, repeatTask == nil else { return }
                    pressing = true
                    didRepeat = false
                    repeatTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(380))
                        var interval = 160
                        while !Task.isCancelled {
                            didRepeat = true
                            onStep()
                            try? await Task.sleep(for: .milliseconds(interval))
                            interval = max(Int(Double(interval) * 0.82), 45)
                        }
                    }
                }
                .onEnded { _ in
                    repeatTask?.cancel()
                    repeatTask = nil
                    pressing = false
                    // A quick tap steps once; a hold has already been stepping.
                    if enabled, !didRepeat { onStep() }
                    didRepeat = false
                }
        )
    }
}
