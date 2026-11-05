import SwiftUI

// MARK: - Shapes

/// Continuous-corner rounded rectangle, the kit's default glass shape. Type-erased so a panel can
/// be a rect, a capsule or a circle without the call site carrying a shape generic.
func glassRect(_ radius: CGFloat) -> AnyShape {
    AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
}

let glassCapsule = AnyShape(Capsule())
let glassCircle = AnyShape(Circle())

// MARK: - GlassPanel

/// The kit's base glass surface, and the only place Liquid Glass is configured.
///
/// On Android this composed a hand-written refraction shader stack (`vibrancy()` + `lens()` +
/// highlight + inner shadow). Here the real thing does that work: `glassEffect` gives genuine
/// refraction, specular highlights that track device motion, and the correct behaviour when panels
/// sit on top of each other — so the Android kit's `heavy` / `light` distinction becomes a tint and
/// rim treatment rather than two different lens configurations.
///
/// Interactive panels swell, jelly and glide their highlight under the finger, and a panel with an
/// `accent` shines that colour onto its neighbours while held. Every panel receives that spill.
struct GlassPanel<Content: View>: View {
    var shape: AnyShape = glassRect(24)
    /// A light dimming layer painted over the glass (kept faint so the glass stays see-through).
    var tint: Color = NexColors.glassTint
    /// Native Liquid Glass tint: colours the material itself (selected chips, lit orbs).
    var glassTint: Color?
    var accent: Color?
    var heavy: Bool = false
    var interactive: Bool = false
    var showHighlight: Bool = true
    var pressScale: CGFloat = GlassMotion.tilePressScale
    var action: (() -> Void)?
    /// Painted over the glass but under `content` (fills, washes, accent glows).
    var surface: AnyView?
    /// Painted over `content` (progress bars, rings, sparklines).
    var front: AnyView?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                ZStack {
                    tint
                    if let surface { surface }
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .glassEffect(material, in: shape)
            .overlay {
                if let front {
                    front
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if showHighlight && heavy {
                    // A specular rim on hero surfaces. Stroked at double width and clipped back to
                    // the shape, which keeps the inner half only (AnyShape is not insettable).
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.42),
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.22),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.6
                        )
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
            .glassLightReceiver(shape)
            .liquidPress(
                shape,
                scale: pressScale,
                accent: accent,
                enabled: interactive || action != nil,
                onTap: action
            )
            .contentShape(shape)
    }

    /// Hero surfaces use `.regular` glass, which adapts its density for legibility. Everything else
    /// uses `.clear` glass, the most see-through variant, so the wallpaper shows through.
    private var material: Glass {
        var glass: Glass = heavy ? .regular : .clear
        if let glassTint { glass = glass.tint(glassTint) }
        return glass.interactive(interactive || action != nil)
    }
}

// MARK: - GlassIconOrb

/// A round glass orb framing a symbol. `glow` (0...1) floods the orb with `accent` and lights its
/// rim — e.g. a device's "on" state.
struct GlassIconOrb: View {
    let symbol: String
    var accent: Color = .white
    var size: CGFloat = 40
    var glow: Double = 0
    var iconTint: Color?

    var body: some View {
        let g = clamp01(glow)
        GlassPanel(
            shape: glassCircle,
            tint: Color.black.opacity(0.048),
            heavy: true,
            showHighlight: false,
            surface: AnyView(
                ZStack {
                    if g > 0.01 {
                        RadialGradient(
                            gradient: Gradient(colors: [
                                accent.opacity(0.20 * g),
                                accent.opacity(0.04 * g),
                            ]),
                            center: UnitPoint(x: 0.5, y: 0.62),
                            startRadius: 0,
                            endRadius: size * 0.94
                        )
                        .blendMode(.plusLighter)
                    }
                }
            )
        ) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(iconTint ?? accent)
                .frame(width: size, height: size)
        }
        .overlay {
            Circle()
                .strokeBorder(
                    Color.white.opacity(0.5).lerp(to: accent, g),
                    lineWidth: lerp(0.5, 1.5, CGFloat(g))
                )
                .allowsHitTesting(false)
        }
        .shadow(color: accent.opacity(0.55 * g), radius: size * 0.45)
    }
}

// MARK: - Small shared pieces

/// A compact glass capsule readout (temperature, state), accent-tinted while `lit`.
struct GlassPill: View {
    let text: String
    var accent: Color = NexColors.cyan
    var lit: Bool = false
    var height: CGFloat = 32

    var body: some View {
        GlassPanel(
            shape: glassCapsule,
            tint: Color.black.opacity(lit ? 0 : 0.06),
            glassTint: lit ? accent.opacity(0.55) : nil
        ) {
            NexText(text, .label, color: lit ? .white : NexColors.secondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: height)
        }
    }
}

/// A small round glass button that floods with `accent` while `lit`.
struct GlassQuickOrb: View {
    let symbol: String
    var accent: Color
    var lit: Bool
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        GlassPanel(
            shape: glassCircle,
            tint: Color.black.opacity(lit ? 0 : 0.06),
            glassTint: lit ? accent.opacity(0.7) : nil,
            accent: accent,
            pressScale: GlassMotion.buttonPressScale,
            action: action
        ) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .animation(GlassMotion.glow, value: lit)
    }
}

/// Slim fill bar along the bottom edge of a glass surface.
struct GlassFillBar: View {
    let fraction: Double
    let accent: Color
    var inset: CGFloat = 16
    var bottom: CGFloat = 9

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - inset * 2, 0)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                    .frame(width: width, height: 3)
                Capsule().fill(accent)
                    .frame(width: width * clamp01(fraction), height: 3)
            }
            .frame(width: width, height: 3)
            .position(x: proxy.size.width / 2, y: proxy.size.height - bottom - 1.5)
        }
        .allowsHitTesting(false)
    }
}
