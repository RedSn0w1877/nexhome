import SwiftUI

/// Tall Control Center fader. The accent fill rises from the bottom and follows the value with a
/// spring; dragging past either end rubber-bands the whole pill (stretching away from the anchored
/// edge) and it springs back on release, as Control Center's sliders do.
///
/// `value` is 0...1. Drags are relative, so touching the pill never jumps the value.
struct LiquidFader: View {
    let value: Double
    var accent: Color = NexColors.amber
    var symbol: String?
    var label: String?
    var valueText: ((Double) -> String)?
    var width: CGFloat = 96
    var height: CGFloat = 220
    let onChange: (Double) -> Void
    var onCommit: (() -> Void)?

    private let maxStretch: CGFloat = 28

    @State private var dragging = false
    @State private var startValue: Double = 0
    @State private var raw: Double = 0
    @State private var stretch: CGFloat = 0
    @State private var lastTick = -1

    private var fill: Double { clamp01(value) }

    private var text: String {
        if let valueText { return valueText(value) }
        return "\(Int((value * 100).rounded()))%"
    }

    var body: some View {
        let onFill = value > 0.86
        GlassPanel(
            shape: glassRect(30),
            interactive: true,
            surface: AnyView(
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        accent
                            .frame(height: proxy.size.height * fill)
                    }
                    .animation(.spring(response: 0.306, dampingFraction: 0.62), value: fill)
                }
            )
        ) {
            VStack {
                VStack(spacing: 0) {
                    Text(text)
                        .font(NexType.bodyStrong.font.monospacedDigit())
                        .foregroundStyle(value > 0.9 ? Color.black.opacity(0.78) : .white)
                        .lineLimit(1)
                    if let label {
                        NexText(
                            label,
                            .caption,
                            color: onFill ? Color.black.opacity(0.6) : NexColors.secondary
                        )
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    }
                }
                Spacer(minLength: 8)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(value > 0.14 ? Color.black.opacity(0.72) : .white)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .frame(width: width, height: height)
        }
        .scaleEffect(
            x: 1 - abs(stretch) / max(height, 1) * 0.35,
            y: 1 + abs(stretch) / max(height, 1),
            anchor: stretch >= 0 ? .bottom : .top
        )
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    if !dragging {
                        dragging = true
                        startValue = value
                        lastTick = Int((value * 10).rounded())
                    }
                    let h = max(height, 1)
                    raw = startValue - Double(gesture.translation.height) / Double(h)
                    let clamped = clamp01(raw)
                    let over = raw - clamped
                    if over != 0 {
                        // Keep the finger's overscroll bounded so reversing responds immediately.
                        raw = clamped + clamp(over, -0.6, 0.6)
                    }
                    stretch = rubberBand(CGFloat(over) * 3) * maxStretch
                    let tick = Int((clamped * 10).rounded())
                    if tick != lastTick {
                        lastTick = tick
                        Haptics.tick()
                    }
                    if clamped != value { onChange(clamped) }
                }
                .onEnded { _ in
                    dragging = false
                    withAnimation(GlassMotion.release) { stretch = 0 }
                    onCommit?()
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Level")
        .accessibilityValue(text)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(clamp01(value + 0.1))
            case .decrement: onChange(clamp01(value - 0.1))
            @unknown default: break
            }
            onCommit?()
        }
    }
}
