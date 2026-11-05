import SwiftUI

/// Central motion tokens for the NexHome liquid-glass kit — tune the feel of the whole app here.
///
/// The language is water: a quick swell under the finger, a slow bouncy overshoot on release, and a
/// liquid follow for anything dragged or anything that trails a finger (highlights, glow).
///
/// These are the Android build's `spring(dampingRatio:, stiffness:)` tokens converted to SwiftUI's
/// `response`/`dampingFraction` form — `response = 2π / sqrt(stiffness)`, damping unchanged.
enum GlassMotion {

    /// Press: glass swells up quickly under a finger, like water bulging where it is pushed.
    static let press = Animation.spring(response: 0.351, dampingFraction: 0.55)

    /// Release: a soft, visible overshoot and a graceful settle back to rest.
    static let release = Animation.spring(response: 0.513, dampingFraction: 0.34)

    /// Finger-following motion (touch highlight, spill position) — trails, never snaps.
    static let glide = Animation.spring(response: 0.433, dampingFraction: 0.78)

    /// Light spill rise (~0.45 s): a quick tap is a faint flash, a hold becomes a full shine.
    static let lightBloom = Animation.spring(response: 0.847, dampingFraction: 1)

    /// Light spill fade after release — slower than the bloom, so light lingers gracefully.
    static let lightFade = Animation.spring(response: 1.019, dampingFraction: 1)

    /// Sheets / screens appearing: a bloom with a small overshoot.
    static let enter = Animation.spring(response: 0.482, dampingFraction: 0.62)

    /// Non-bouncy press glow (never dips below zero).
    static let glow = Animation.spring(response: 0.390, dampingFraction: 0.9)

    /// Draggable blob value follow — underdamped so blobs overshoot when they snap.
    static let blob = Animation.spring(response: 0.265, dampingFraction: 0.72)

    /// Blob press scale (X wobblier than Y for an anisotropic jelly feel).
    static let blobScaleX = Animation.spring(response: 0.414, dampingFraction: 0.36)
    static let blobScaleY = Animation.spring(response: 0.414, dampingFraction: 0.44)

    /// Tile / panel press swell.
    static let tilePressScale: CGFloat = 1.07

    /// Button press swell.
    static let buttonPressScale: CGFloat = 1.16

    /// Round orb press swell.
    static let orbPressScale: CGFloat = 1.12

    /// Max extra stretch along the drag axis for jelly surfaces (+8 %).
    static let jellyStretch: CGFloat = 0.08

    /// tanh initial derivative for the jelly translation toward the finger.
    static let jellyFollow: CGFloat = 0.06
}

// MARK: - Small numeric helpers used throughout the kit

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

/// Maps an unbounded overscroll progress to a rubber-banded one that asymptotically approaches ±1.
/// (Ported from the Backdrop catalog's `ProgressConverter`.)
@inlinable
func rubberBand(_ progress: CGFloat) -> CGFloat {
    (1 - exp(-abs(progress))) * (progress < 0 ? -1 : 1)
}

/// Degrees → radians.
@inlinable
func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

extension Double {
    /// `"%.1f"`-style formatting without pulling in a formatter per call site.
    func fixed(_ places: Int) -> String { String(format: "%.\(places)f", self) }
    var rounded0: Int { Int(self.rounded()) }
}

extension CGFloat {
    var rounded0: Int { Int(self.rounded()) }
}
