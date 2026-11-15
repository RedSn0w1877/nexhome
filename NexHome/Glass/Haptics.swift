import UIKit

/// System haptics, switchable from Setup.
@MainActor
enum Haptics {
    static var enabled = true

    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// One detent or option crossed.
    static func tick() {
        guard enabled else { return }
        selection.selectionChanged()
    }

    /// A control committed a value.
    static func tap() {
        guard enabled else { return }
        impact.impactOccurred()
    }

    /// A hold completed.
    static func confirm() {
        guard enabled else { return }
        heavy.impactOccurred(intensity: 1)
    }
}
