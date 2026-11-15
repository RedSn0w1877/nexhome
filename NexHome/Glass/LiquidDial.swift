import SwiftUI

private let dialStartAngle: Double = 135
private let dialSweepAngle: Double = 270

/// Round dial (thermostats, set points, read-only gauges).
///
/// An inset well, a 270° track with the accent value arc and optional detent ticks, the centre
/// readout, and an orbiting knob that turns to clear glass while it is dragged, like the system
/// slider's thumb. Dragging anywhere on the ring band sets the value;
/// the centre stays free. `detents` > 0 snaps the value to that step and ticks a haptic per step.
struct LiquidDial<Center: View>: View {
    let value: Double
    var range: ClosedRange<Double> = 0...1
    var accent: Color = NexColors.orange
    var readOnly: Bool = false
    var detents: Double = 0
    var size: CGFloat = 240
    var trackColor: Color = NexColors.track
    var onChange: ((Double) -> Void)?
    var onCommit: (() -> Void)?
    @ViewBuilder var center: () -> Center

    private let ringInset: CGFloat = 24
    private var ringRadius: CGFloat { size / 2 - ringInset }

    @State private var dragging = false
    @State private var dragFraction: Double = -1
    @State private var lastTick = Int.min

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return clamp01((value - range.lowerBound) / span)
    }

    var body: some View {
        ZStack {
            // 1. Inset well.
            Circle()
                .fill(NexColors.fill)

            // 2. Track, value arc and detent ticks.
            Circle()
                .trim(from: 0, to: 0.75)
                .rotation(.degrees(dialStartAngle))
                .stroke(trackColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .padding(ringInset)

            if fraction > 0.001 {
                Circle()
                    .trim(from: 0, to: 0.75 * fraction)
                    .rotation(.degrees(dialStartAngle))
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .padding(ringInset)
            }

            if detents > 0 {
                let count = Int(((range.upperBound - range.lowerBound) / detents).rounded())
                if count >= 2 && count <= 60 {
                    ForEach(0...count, id: \.self) { index in
                        let f = Double(index) / Double(count)
                        let angle = radians(dialStartAngle + dialSweepAngle * f)
                        Circle()
                            .fill(Color.white.opacity(f <= fraction ? 0.55 : 0.2))
                            .frame(width: 2.8, height: 2.8)
                            .offset(
                                x: cos(angle) * (ringRadius - 16),
                                y: sin(angle) * (ringRadius - 16)
                            )
                    }
                }
            }

            // 3. Centre readout.
            center()

            // 4. Orbiting knob: solid at rest, a clear glass lens while dragged.
            Circle()
                .fill(Color.white.opacity(dragging ? 0.08 : 1))
                .overlay {
                    Circle()
                        .fill(accent)
                        .frame(width: (readOnly ? 28 : 36) * 0.4)
                        .opacity(dragging ? 0 : 1)
                }
                .frame(width: readOnly ? 28 : 36, height: readOnly ? 28 : 36)
                .glassEffect(.clear.interactive(), in: Circle())
                .scaleEffect(dragging ? 1.5 : 1)
                .offset(
                    x: cos(knobAngle) * ringRadius,
                    y: sin(knobAngle) * ringRadius
                )
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .animation(dragging ? nil : GlassMotion.blob, value: value)
        .animation(GlassMotion.release, value: dragging)
        .gesture(readOnly ? nil : ringDrag)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(value.rounded()))")
        .accessibilityAdjustableAction { direction in
            guard !readOnly else { return }
            let step = detents > 0 ? detents : (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: onChange?(clamp(value + step, range.lowerBound, range.upperBound))
            case .decrement: onChange?(clamp(value - step, range.lowerBound, range.upperBound))
            @unknown default: break
            }
            onCommit?()
        }
    }

    private var knobAngle: Double {
        radians(dialStartAngle + dialSweepAngle * fraction)
    }

    private var ringDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let center = CGPoint(x: size / 2, y: size / 2)
                let vector = CGPoint(x: gesture.location.x - center.x, y: gesture.location.y - center.y)
                let distance = (vector.x * vector.x + vector.y * vector.y).squareRoot()
                let radius = size / 2
                if !dragging {
                    // Only the ring band grabs; the centre stays free for the readout and scrolling.
                    guard distance >= radius * 0.52, distance <= radius * 1.12 else { return }
                    dragging = true
                    dragFraction = -1
                    lastTick = Int.min
                }
                guard dragging else { return }
                apply(vector)
            }
            .onEnded { _ in
                guard dragging else { return }
                dragging = false
                dragFraction = -1
                onCommit?()
            }
    }

    private func apply(_ vector: CGPoint) {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return }
        let next = fractionFromTouch(vector, previous: dragFraction)
        dragFraction = next
        var candidate = range.lowerBound + next * span
        if detents > 0 {
            candidate = clamp(
                range.lowerBound + (((candidate - range.lowerBound) / detents).rounded()) * detents,
                range.lowerBound,
                range.upperBound
            )
        }
        let shown = clamp01((candidate - range.lowerBound) / span)
        let tick = detents > 0
            ? Int(((candidate - range.lowerBound) / detents).rounded())
            : Int((shown * 20).rounded())
        if tick != lastTick {
            if lastTick != Int.min { Haptics.tick() }
            lastTick = tick
        }
        if candidate != value { onChange?(candidate) }
    }

    /// Maps a touch vector (from the centre) to 0...1 along the arc; `previous` < 0 allows any jump.
    private func fractionFromTouch(_ vector: CGPoint, previous: Double) -> Double {
        let degrees = atan2(vector.y, vector.x) * 180 / .pi
        var relative = (degrees - dialStartAngle).truncatingRemainder(dividingBy: 360)
        if relative < 0 { relative += 360 }
        if relative > dialSweepAngle {
            // In the bottom gap: stick to whichever end is closer.
            let gapMid = dialSweepAngle + (360 - dialSweepAngle) / 2
            if previous >= 0 { return previous > 0.5 ? 1 : 0 }
            return relative < gapMid ? 1 : 0
        }
        let f = relative / dialSweepAngle
        if previous >= 0, abs(f - previous) > 0.5 { return previous > 0.5 ? 1 : 0 }
        return f
    }
}

extension LiquidDial where Center == EmptyView {
    init(
        value: Double,
        range: ClosedRange<Double> = 0...1,
        accent: Color = NexColors.orange,
        readOnly: Bool = false,
        detents: Double = 0,
        size: CGFloat = 240,
        onChange: ((Double) -> Void)? = nil
    ) {
        self.init(
            value: value, range: range, accent: accent, readOnly: readOnly, detents: detents,
            size: size, onChange: onChange, center: { EmptyView() }
        )
    }
}
