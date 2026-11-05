import SwiftUI
import UIKit

/// The app's "light spill" state: hold one glass element and its accent colour shines onto its
/// neighbours. One instance lives at the root and is read by every kit glass surface.
///
/// `position` is in global (screen) coordinates so any surface can measure its distance to the
/// light regardless of where it sits in the hierarchy.
@MainActor
@Observable
final class GlassLight {
    private(set) var position: CGPoint = .zero
    private(set) var color: Color = .white
    private(set) var intensity: Double = 0
    /// How far the light reaches, in points.
    let reach: CGFloat = 340

    private var owner: ObjectIdentifier?

    /// Starts (or takes over) the light at `point`, blooming toward `peak`.
    func begin(_ owner: AnyObject, at point: CGPoint, color: Color, peak: Double = 1) {
        self.owner = ObjectIdentifier(owner)
        self.position = point
        self.color = color
        withAnimation(GlassMotion.lightBloom) { intensity = peak }
    }

    /// Glides the light after the finger.
    func move(_ owner: AnyObject, to point: CGPoint) {
        guard self.owner == ObjectIdentifier(owner) else { return }
        withAnimation(GlassMotion.glide) { position = point }
    }

    /// Re-targets the bloom (used by the hold orb, whose shine rises over the hold duration).
    func setPeak(_ owner: AnyObject, _ peak: Double, duration: Double) {
        guard self.owner == ObjectIdentifier(owner) else { return }
        withAnimation(.linear(duration: duration)) { intensity = peak }
    }

    /// Fades the light out.
    func end(_ owner: AnyObject) {
        guard self.owner == ObjectIdentifier(owner) else { return }
        self.owner = nil
        withAnimation(GlassMotion.lightFade) { intensity = 0 }
    }

    /// Spill strength for a surface occupying `frame` (global coords): falls off quadratically with
    /// the distance from the light to the nearest point of the rect.
    func strength(for frame: CGRect) -> Double {
        guard intensity > 0.01, frame.width > 0, frame.height > 0 else { return 0 }
        let nx = clamp(position.x, frame.minX, frame.maxX)
        let ny = clamp(position.y, frame.minY, frame.maxY)
        let dx = position.x - nx
        let dy = position.y - ny
        let distance = (dx * dx + dy * dy).squareRoot()
        let falloff = 1 - clamp01(distance / reach)
        return intensity * Double(falloff * falloff)
    }
}

/// Leaf view that paints the spilled light inside a glass surface. Kept separate so only this
/// overlay re-renders while the light animates, not the whole panel it decorates.
struct GlassSpill<S: Shape>: View {
    let shape: S
    let frame: CGRect
    @Environment(GlassLight.self) private var light: GlassLight?

    var body: some View {
        let strength = light?.strength(for: frame) ?? 0
        if let light, strength > 0.005 {
            let local = CGPoint(x: light.position.x - frame.minX, y: light.position.y - frame.minY)
            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [
                        light.color.opacity(0.5 * strength),
                        light.color.opacity(0),
                    ]),
                    center: UnitPoint(
                        x: frame.width > 0 ? local.x / frame.width : 0.5,
                        y: frame.height > 0 ? local.y / frame.height : 0.5
                    ),
                    startRadius: 0,
                    endRadius: max(frame.width, frame.height) * 1.1
                )
                .blendMode(.plusLighter)

                // The rim facing the held element lights up in its colour.
                shape
                    .stroke(
                        light.color.opacity(0.85 * strength),
                        lineWidth: lerp(0.5, 2.5, CGFloat(strength))
                    )
                    .blur(radius: 1.5)
                    .blendMode(.plusLighter)
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Every kit glass surface receives light spill. `shape` must match the surface's own shape.
    func glassLightReceiver<S: Shape>(_ shape: S) -> some View {
        modifier(GlassLightReceiverModifier(shape: shape))
    }
}

private struct GlassLightReceiverModifier<S: Shape>: ViewModifier {
    let shape: S
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newValue in
                frame = newValue
            }
            .overlay { GlassSpill(shape: shape, frame: frame) }
    }
}

// MARK: - Haptics

/// Thin wrapper so the kit can tick haptics the way the Android build did, without each control
/// building its own generator.
@MainActor
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// One detent / option crossed.
    static func tick() {
        selection.selectionChanged()
    }

    /// A control committed a value.
    static func tap() {
        impact.impactOccurred()
    }

    /// A hold completed.
    static func confirm() {
        heavy.impactOccurred(intensity: 1)
    }
}
