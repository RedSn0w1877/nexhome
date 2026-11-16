import SwiftUI

// MARK: - Shapes

/// Continuous-corner rounded rectangle, the default surface shape. Type-erased so a panel can be a
/// rect, a capsule or a circle without the call site carrying a shape generic.
func glassRect(_ radius: CGFloat) -> AnyShape {
    AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
}

let glassCapsule = AnyShape(Capsule())
let glassCircle = AnyShape(Circle())

// MARK: - Glass depth

/// How many glass surfaces enclose a view. Apple's rule for Liquid Glass is one layer: a surface
/// that sits on the wallpaper is glass, and anything inside it is an inset fill, never more glass.
/// Controls (buttons, chips, thumbs, orbs) stay glass at any depth, the way toolbar buttons do.
private struct GlassDepthKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var glassDepth: Int {
        get { self[GlassDepthKey.self] }
        set { self[GlassDepthKey.self] = newValue }
    }
}

// MARK: - GlassPanel

/// The base surface every card, module, section and tile is built from.
///
/// On the wallpaper it is system Liquid Glass (`.regular`, optionally tinted). Inside another
/// surface it becomes the system inset fill instead, so glass is never stacked on glass. With an
/// `action` it is a button: the glass reacts to the touch natively, an inset fill dims and dips.
struct GlassPanel<Content: View>: View {
    var shape: AnyShape = glassRect(24)
    /// Colours the surface: tinted glass on the wallpaper, a tinted fill when inset.
    var glassTint: Color?
    /// Lets the glass respond to touches even without an `action` (surfaces holding a gesture).
    var interactive: Bool = false
    var action: (() -> Void)?
    /// Drawn on the surface, under `content` (fills, charts).
    var surface: AnyView?
    /// Drawn over `content` (progress bars, rings, sparklines).
    var front: AnyView?
    @ViewBuilder var content: () -> Content

    @Environment(\.glassDepth) private var depth

    var body: some View {
        if let action {
            Button(action: action) { panel }
                .buttonStyle(SurfaceButtonStyle(inset: depth > 0))
        } else {
            panel
        }
    }

    private var panel: some View {
        content()
            .environment(\.glassDepth, depth + 1)
            .background {
                if let surface {
                    surface
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
            .modifier(
                SurfaceMaterial(
                    shape: shape,
                    inset: depth > 0,
                    tint: glassTint,
                    interactive: interactive || action != nil
                )
            )
            .overlay {
                if let front {
                    front
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(shape)
    }
}

/// Glass on the wallpaper, an inset fill inside another surface.
private struct SurfaceMaterial: ViewModifier {
    let shape: AnyShape
    let inset: Bool
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if inset {
            content.background {
                ZStack {
                    shape.fill(NexColors.fill)
                    if let tint { shape.fill(tint.opacity(0.28)) }
                }
            }
        } else {
            content.glassEffect(glass, in: shape)
        }
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint.opacity(0.55)) }
        return glass.interactive(interactive)
    }
}

/// Press response for tappable surfaces. Glass already answers the touch itself; an inset fill
/// brightens and dips slightly, like a list row.
private struct SurfaceButtonStyle: ButtonStyle {
    let inset: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(inset && configuration.isPressed ? 0.08 : 0)
            .scaleEffect(inset && configuration.isPressed ? 0.97 : 1)
            .animation(GlassMotion.press, value: configuration.isPressed)
    }
}

// MARK: - Glass controls

extension View {
    /// System Liquid Glass for a control (button, chip, thumb, orb): interactive, optionally
    /// tinted. Controls are glass at any depth.
    func glassControl<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        return glassEffect(glass.interactive(), in: shape)
    }
}

/// A button style that adds nothing: for buttons whose label is already interactive glass, which
/// supplies its own press response.
struct GlassControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// MARK: - GlassIconOrb

/// A round icon badge. `glow` (0...1) fills it with `accent`, e.g. a device's "on" state; off, it is
/// a neutral fill with the symbol in the accent colour (the Home app's tile icon).
struct GlassIconOrb: View {
    let symbol: String
    var accent: Color = .white
    var size: CGFloat = 40
    var glow: Double = 0
    var iconTint: Color?

    @Environment(\.glassDepth) private var depth

    var body: some View {
        let g = clamp01(glow)
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(iconTint ?? (g > 0.5 ? .white : accent))
            .frame(width: size, height: size)
            .background {
                if depth > 0 {
                    ZStack {
                        Circle().fill(NexColors.fill)
                        Circle().fill(accent).opacity(g)
                    }
                }
            }
            .modifier(OrbGlass(enabled: depth == 0, tint: g > 0.01 ? accent.opacity(g) : nil))
            .animation(GlassMotion.glow, value: g)
    }
}

private struct OrbGlass: ViewModifier {
    let enabled: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        if enabled {
            var glass = Glass.regular
            if let tint { glass = glass.tint(tint) }
            return AnyView(content.glassEffect(glass, in: Circle()))
        }
        return AnyView(content)
    }
}

// MARK: - Small shared pieces

/// A compact capsule readout (temperature, state). `lit` shows it in the tinted style.
struct GlassPill: View {
    let text: String
    var accent: Color = NexColors.cyan
    var lit: Bool = false
    var height: CGFloat = 32

    var body: some View {
        GlassPanel(shape: glassCapsule, glassTint: lit ? accent : nil) {
            NexText(text, .label, color: lit ? .white : NexColors.secondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: height)
        }
        .animation(GlassMotion.glow, value: lit)
    }
}

/// A small round glass button, filled with `accent` while `lit`.
struct GlassQuickOrb: View {
    let symbol: String
    var accent: Color
    var lit: Bool
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .glassControl(Circle(), tint: lit ? accent : nil)
        }
        .buttonStyle(GlassControlButtonStyle())
        .animation(GlassMotion.glow, value: lit)
        .accessibilityValue(lit ? "On" : "Off")
        .accessibilityIdentifier("quickControl")
    }
}

/// Slim fill bar along the bottom edge of a surface.
struct GlassFillBar: View {
    let fraction: Double
    let accent: Color
    var inset: CGFloat = 16
    var bottom: CGFloat = 9

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - inset * 2, 0)
            ZStack(alignment: .leading) {
                Capsule().fill(NexColors.track)
                    .frame(width: width, height: 3)
                Capsule().fill(accent)
                    .frame(width: width * clamp01(fraction), height: 3)
            }
            .frame(width: width, height: 3)
            .position(x: proxy.size.width / 2, y: proxy.size.height - bottom - 1.5)
            .animation(GlassMotion.glow, value: fraction)
        }
        .allowsHitTesting(false)
    }
}
