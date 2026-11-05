import SwiftUI

/// Hold-to-confirm glass orb (lock/unlock, garage, arm alarm, start cycle, scenes).
///
/// Holding fills an accent progress ring over `holdMillis` while the orb shines its `accent` onto
/// neighbouring glass with rising intensity. On completion: a dramatic swell-pop, a haptic, and
/// `onConfirmed`. Releasing early springs the ring back. `active` lights the orb in its accent
/// (e.g. "locked", "running").
struct LiquidHoldOrb: View {
    let label: String
    let symbol: String
    var accent: Color = NexColors.mint
    var active: Bool = false
    var holdMillis: Int = 850
    var size: CGFloat = 132
    var sublabel: String?
    var enabled: Bool = true
    let onConfirmed: () -> Void

    @State private var progress: Double = 0
    @State private var pop: Double = 0
    @State private var holding = false
    @State private var holdTask: Task<Void, Never>?
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    private var lit: Double { active ? 1 : 0 }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                GlassPanel(
                    shape: glassCircle,
                    tint: Color.black.opacity(0.14),
                    accent: accent,
                    heavy: true,
                    interactive: true,
                    pressScale: GlassMotion.orbPressScale,
                    surface: AnyView(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                accent.opacity(0.44 * glowFill),
                                accent.opacity(0.06 * glowFill),
                            ]),
                            center: UnitPoint(x: 0.5, y: 0.6),
                            startRadius: 0,
                            endRadius: size * 0.7
                        )
                        .blendMode(.plusLighter)
                    ),
                    front: AnyView(ring)
                ) {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.3, weight: .semibold))
                        .foregroundStyle(active ? accent : .white)
                        .frame(width: size, height: size)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.55).lerp(to: accent, emphasis),
                            lineWidth: lerp(0.75, 2.5, CGFloat(emphasis))
                        )
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: accent.opacity(0.12 + 0.45 * emphasis),
                    radius: 18 + 26 * emphasis,
                    y: 4
                )
                .scaleEffect(1 + 0.22 * pop)
            }
            .frame(width: size, height: size)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .gesture(holdGesture)

            NexText(label, .bodyStrong)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            if let sublabel {
                NexText(sublabel, .caption, color: NexColors.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .animation(GlassMotion.glow, value: active)
    }

    /// Progress ring: a faint full circle, the "active" tint, and the live hold arc.
    private var ring: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 5)
                .padding(9)
            if active {
                Circle()
                    .strokeBorder(accent.opacity(0.45), lineWidth: 5)
                    .padding(9)
            }
            if progress > 0.001 {
                Circle()
                    .inset(by: 11.5)
                    .trim(from: 0, to: progress)
                    .rotation(.degrees(-90))
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
    }

    private var emphasis: Double { max(progress, lit * 0.8) }
    private var glowFill: Double { max(progress * 0.8, lit * 0.55) }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard enabled, !holding else { return }
                holding = true
                light?.begin(token, at: globalPoint(gesture.location), color: accent, peak: 0.3)
                light?.setPeak(token, 1, duration: Double(holdMillis) / 1000)
                holdTask = Task { @MainActor in
                    let remaining = Double(holdMillis) * (1 - progress) / 1000
                    withAnimation(.linear(duration: max(remaining, 0.01))) { progress = 1 }
                    try? await Task.sleep(for: .seconds(max(remaining, 0.01)))
                    guard !Task.isCancelled else { return }
                    Haptics.confirm()
                    onConfirmed()
                    withAnimation(.spring(response: 0.209, dampingFraction: 0.5)) { pop = 1 }
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(GlassMotion.release) { pop = 0 }
                    try? await Task.sleep(for: .milliseconds(140))
                    light?.end(token)
                    withAnimation(.spring(response: 0.574, dampingFraction: 0.8)) { progress = 0 }
                    holding = false
                }
            }
            .onEnded { _ in
                guard holding, progress < 1 else {
                    holding = false
                    return
                }
                holdTask?.cancel()
                holdTask = nil
                holding = false
                light?.end(token)
                withAnimation(GlassMotion.release) { progress = 0 }
            }
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }
}
