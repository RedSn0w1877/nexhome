import SwiftUI

/// Motion tokens. These are plain system springs: Liquid Glass supplies its own press, morph and
/// highlight motion, so the app only animates its own values (fills, arcs, blobs) with them.
enum GlassMotion {
    /// Quick, critically damped response to a touch.
    static let press = Animation.snappy(duration: 0.22)
    /// Settling after a gesture ends, with a little life in it.
    static let release = Animation.spring(duration: 0.42, bounce: 0.22)
    /// Following a finger.
    static let glide = Animation.smooth(duration: 0.28)
    /// Content appearing.
    static let enter = Animation.spring(duration: 0.45, bounce: 0.12)
    /// State colour changes (on/off, lit/unlit).
    static let glow = Animation.smooth(duration: 0.3)
    /// A draggable thumb snapping to a value.
    static let blob = Animation.spring(duration: 0.34, bounce: 0.18)
}

// MARK: - Small numeric helpers

@inlinable
func lerp(_ from: Double, _ to: Double, _ t: Double) -> Double {
    from + (to - from) * t
}

@inlinable
func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
    from + (to - from) * t
}

@inlinable
func clamp<T: Comparable>(_ value: T, _ low: T, _ high: T) -> T {
    min(max(value, low), high)
}

@inlinable
func clamp01(_ value: Double) -> Double { clamp(value, 0, 1) }

@inlinable
func clamp01(_ value: CGFloat) -> CGFloat { clamp(value, 0, 1) }

/// Maps an unbounded overscroll progress to a rubber-banded one that approaches ±1.
@inlinable
func rubberBand(_ progress: CGFloat) -> CGFloat {
    (1 - exp(-abs(progress))) * (progress < 0 ? -1 : 1)
}

/// Degrees → radians.
@inlinable
func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

extension Double {
    /// `"%.1f"`-style formatting.
    func fixed(_ places: Int) -> String { String(format: "%.\(places)f", self) }
    var rounded0: Int { Int(self.rounded()) }
}

extension CGFloat {
    var rounded0: Int { Int(self.rounded()) }
}
