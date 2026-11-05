import SwiftUI

/// Tall Control-Center-style glass fader. The accent fill rises from the bottom inside the glass and
/// follows the value with a liquid spring; dragging past either end rubber-bands the whole pill
/// (stretching away from the anchored edge) and it springs back on release. The pill swells while
/// held and shines `accent` onto its neighbours.
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
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    private var fill: Double { clamp01(value) }

    private var text: String {
        if let valueText { return valueText(value) }
        return "\(Int((value * 100).rounded()))%"
    }

    var body: some View {
        let onFill = value > 0.86
        GlassPanel(
            shape: glassRect(30),
            tint: Color.black.opacity(0.064),
            accent: accent,
            heavy: true,
            interactive: true,
            surface: AnyView(
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        ZStack(alignment: .top) {
                            accent.opacity(0.9)
                            Color.white.opacity(0.35)
                                .frame(height: 2)
                                .blendMode(.plusLighter)
                        }
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
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    if !dragging {
                        dragging = true
                        startValue = value
                        lastTick = Int((value * 10).rounded())
                        light?.begin(token, at: globalPoint(gesture.location), color: accent)
                    } else {
                        light?.move(token, to: globalPoint(gesture.location))
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
                    light?.end(token)
                    withAnimation(GlassMotion.release) { stretch = 0 }
                    onCommit?()
                }
        )
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }
}
