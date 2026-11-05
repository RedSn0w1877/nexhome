import SwiftUI

/// Identity object so a view can own the shared `GlassLight` across body re-evaluations.
final class LightToken {}

/// The kit's touch response, shared by every interactive glass surface:
///
/// - a **water swell** to `pressScale` on press with a bouncy overshoot on release (never shrinks),
/// - **jelly**: a `tanh` translation toward the finger plus an anisotropic stretch along the drag
///   direction,
/// - a **gliding highlight** — a soft additive glow that trails the finger,
/// - **light emission**: while held, a surface with an `accent` shines that colour onto its
///   neighbours through the shared `GlassLight`.
///
/// The gesture is attached with `simultaneousGesture`, so it only *observes* touches and an
/// enclosing `ScrollView` still scrolls.
struct LiquidPress<S: Shape>: ViewModifier {
    let shape: S
    var pressScale: CGFloat = GlassMotion.tilePressScale
    var accent: Color?
    var enabled: Bool = true
    var onTap: (() -> Void)?

    @State private var size: CGSize = .zero
    @State private var frame: CGRect = .zero
    @State private var touch: CGPoint?
    @State private var swell: CGFloat = 0
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    func body(content: Content) -> some View {
        let minDim = max(min(size.width, size.height), 1)
        let maxDim = max(max(size.width, size.height), 1)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let point = touch ?? center
        let dx = point.x - center.x
        let dy = point.y - center.y
        let angle = atan2(dy, dx)
        let base = lerp(1, pressScale, swell)
        let stretchX = GlassMotion.jellyStretch
            * min(abs(cos(angle) * dx / maxDim), 1)
            * min(size.width / max(size.height, 1), 1)
        let stretchY = GlassMotion.jellyStretch
            * min(abs(sin(angle) * dy / maxDim), 1)
            * min(size.height / max(size.width, 1), 1)

        return content
            .overlay {
                if swell > 0.004 {
                    GlassGlow(
                        shape: shape,
                        point: point,
                        size: size,
                        amount: swell,
                        color: accent.map { Color.white.lerp(to: $0, 0.45) } ?? .white
                    )
                }
            }
            .scaleEffect(
                x: enabled ? base + stretchX : 1,
                y: enabled ? base + stretchY : 1,
                anchor: .center
            )
            .offset(
                x: enabled ? tanh(GlassMotion.jellyFollow * dx / minDim) * minDim : 0,
                y: enabled ? tanh(GlassMotion.jellyFollow * dy / minDim) * minDim : 0
            )
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { newValue in
                frame = newValue
                size = newValue.size
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        let first = touch == nil
                        if first {
                            touch = value.location
                            withAnimation(GlassMotion.press) { swell = 1 }
                            if let accent {
                                light?.begin(token, at: globalPoint(value.location), color: accent)
                            }
                        } else {
                            withAnimation(GlassMotion.glide) { touch = value.location }
                            if accent != nil {
                                light?.move(token, to: globalPoint(value.location))
                            }
                        }
                    }
                    .onEnded { _ in
                        release()
                    }
            )
            .onTapGesture {
                guard enabled else { return }
                onTap?()
            }
            // Safety net: a gesture swallowed by an enclosing scroll view never ends, which would
            // otherwise leave the surface stuck in its pressed state.
            .task(id: touch == nil) {
                guard touch != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                release()
            }
            .onDisappear { release() }
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }

    private func release() {
        guard touch != nil else { return }
        touch = nil
        withAnimation(GlassMotion.release) { swell = 0 }
        light?.end(token)
    }
}

/// The gliding touch glow. A leaf view so it can animate without re-rendering its panel.
struct GlassGlow<S: Shape>: View {
    let shape: S
    let point: CGPoint
    let size: CGSize
    let amount: CGFloat
    let color: Color

    var body: some View {
        let radius = max(min(size.width, size.height), 1) * 1.8
        ZStack {
            color.opacity(0.14 * amount)
            RadialGradient(
                gradient: Gradient(colors: [color.opacity(0.34 * amount), color.opacity(0)]),
                center: UnitPoint(
                    x: size.width > 0 ? point.x / size.width : 0.5,
                    y: size.height > 0 ? point.y / size.height : 0.5
                ),
                startRadius: 0,
                endRadius: radius
            )
        }
        .blendMode(.plusLighter)
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

extension View {
    /// Applies the kit's press response (swell, jelly, gliding glow, light emission).
    func liquidPress<S: Shape>(
        _ shape: S,
        scale: CGFloat = GlassMotion.tilePressScale,
        accent: Color? = nil,
        enabled: Bool = true,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(LiquidPress(shape: shape, pressScale: scale, accent: accent, enabled: enabled, onTap: onTap))
    }
}

/// A soft additive radial accent wash, the SwiftUI stand-in for the Android kit's `AccentWash`.
struct AccentWash: View {
    let color: Color
    var center: UnitPoint = UnitPoint(x: 0.12, y: 0.1)
    var radiusFraction: CGFloat = 0.95
    var amount: Double

    var body: some View {
        if amount > 0.005 {
            GeometryReader { proxy in
                RadialGradient(
                    gradient: Gradient(colors: [color.opacity(amount), color.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * radiusFraction
                )
                .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)
        }
    }
}
