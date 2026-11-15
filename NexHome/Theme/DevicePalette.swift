import SwiftUI

/// Accent per control category, from Apple's system palette (the same hues the Home app uses:
/// yellow light, orange climate, teal locks, and so on).
func deviceAccent(_ kind: ControlKind) -> Color {
    switch kind {
    case .toggle: return NexColors.green
    case .dimmer: return NexColors.yellow
    case .thermostatDial: return NexColors.orange
    case .lock: return NexColors.teal
    case .garage: return NexColors.indigo
    case .cameraFeed: return NexColors.pink
    case .blindsSlider: return NexColors.orange
    case .mediaPlayer: return NexColors.purple
    case .fanSpeed: return NexColors.cyan
    case .applianceCycle: return NexColors.teal
    case .robotVacuum: return NexColors.indigo
    case .waterHeaterDial: return NexColors.red
    case .evCharger: return NexColors.green
    case .sprinklerZones: return NexColors.blue
    case .sensorReadonly: return NexColors.mint
    case .securityPanel: return NexColors.red
    }
}

/// Per-type refinement of `deviceAccent(_:)` (falls back to the type's control kind).
func deviceAccent(_ type: DeviceType) -> Color {
    switch type {
    case .lightStrip: return NexColors.pink
    case .acUnit: return NexColors.cyan
    case .tv: return NexColors.indigo
    case .fridge: return NexColors.cyan
    case .oven, .grill: return NexColors.red
    case .microwave: return NexColors.orange
    case .washingMachine: return NexColors.blue
    case .dryer: return NexColors.purple
    case .poolHeater: return NexColors.cyan
    case .poolPump: return NexColors.blue
    case .smokeDetector, .coDetector: return NexColors.orange
    case .leakSensor: return NexColors.blue
    case .contactSensor: return NexColors.indigo
    default: return deviceAccent(type.controlKind)
    }
}

private let roomAccents: [Color] = [
    NexColors.cyan, NexColors.purple, NexColors.yellow, NexColors.pink, NexColors.mint, NexColors.blue,
    NexColors.orange, NexColors.green, NexColors.teal, NexColors.indigo, NexColors.red,
]

/// A stable accent per room.
func roomAccent(_ room: Room) -> Color {
    roomAccents[room.rawValue % roomAccents.count]
}

extension Color {
    /// Linear blend toward `other` in sRGB — the equivalent of Compose's `lerp(Color, Color, t)`.
    /// (SwiftUI's own `mix(with:by:)` interpolates perceptually, which shifts these accents.)
    func lerp(to other: Color, _ amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(self).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        UIColor(other).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            .sRGB,
            red: Double(ar + (br - ar) * t),
            green: Double(ag + (bg - ag) * t),
            blue: Double(ab + (bb - ab) * t),
            opacity: Double(aa + (ba - aa) * t)
        )
    }
}
