import SwiftUI

/// Vivid, harmonious accent per control category — used for glass orbs, fills and glows.
func deviceAccent(_ kind: ControlKind) -> Color {
    switch kind {
    case .toggle: return Color(hex: 0xB8F55A)          // electric lime
    case .dimmer: return Color(hex: 0xFFC46F)          // warm lamplight amber
    case .thermostatDial: return Color(hex: 0xFF8A4C)  // heat orange
    case .lock: return Color(hex: 0x5EE6A8)            // secure mint
    case .garage: return Color(hex: 0x8FA8FF)          // periwinkle
    case .cameraFeed: return Color(hex: 0xFF5F7E)      // recording coral
    case .blindsSlider: return Color(hex: 0xFFB38A)    // daylight peach
    case .mediaPlayer: return Color(hex: 0xC77DFF)     // media violet
    case .fanSpeed: return Color(hex: 0x6FE3FF)        // airflow cyan
    case .applianceCycle: return Color(hex: 0x4FD1C5)  // appliance teal
    case .robotVacuum: return Color(hex: 0x9D8CFF)     // robot lilac
    case .waterHeaterDial: return Color(hex: 0xFF7A59) // hot water red-orange
    case .evCharger: return Color(hex: 0x3DF5A0)       // charge green
    case .sprinklerZones: return Color(hex: 0x52B6FF)  // water sky blue
    case .sensorReadonly: return Color(hex: 0xFFD84D)  // sensor gold
    case .securityPanel: return Color(hex: 0xFF4D6D)   // alarm red
    }
}

/// Per-type refinement of `deviceAccent(_:)` (falls back to the type's control kind).
func deviceAccent(_ type: DeviceType) -> Color {
    switch type {
    case .lightStrip: return Color(hex: 0xFF7EDB)
    case .outdoorLight: return Color(hex: 0xFFD36E)
    case .wallSconce: return Color(hex: 0xFFB86B)
    case .smartOutlet: return Color(hex: 0xFFE45E)
    case .acUnit: return Color(hex: 0x7FD4FF)
    case .interiorDoor: return Color(hex: 0x9EE6C4)
    case .doorbellCamera: return Color(hex: 0xFF8A65)
    case .shade: return Color(hex: 0xF5C99B)
    case .tv: return Color(hex: 0x8C7BFF)
    case .soundbar: return Color(hex: 0xE07CFF)
    case .airPurifier: return Color(hex: 0x9BF6FF)
    case .bathroomHumidity: return Color(hex: 0x7FB8FF)
    case .fridge: return Color(hex: 0x8EE3FF)
    case .oven: return Color(hex: 0xFF6A3D)
    case .microwave: return Color(hex: 0xFFA24C)
    case .dishwasher: return Color(hex: 0x4FD1C5)
    case .washingMachine: return Color(hex: 0x6EC8FF)
    case .dryer: return Color(hex: 0xB39DFF)
    case .grill: return Color(hex: 0xFF5A36)
    case .poolHeater: return Color(hex: 0x3FD8E8)
    case .poolPump: return Color(hex: 0x2FC7F0)
    case .contactSensor: return Color(hex: 0x8FA8FF)
    case .smokeDetector: return Color(hex: 0xFF9F43)
    case .coDetector: return Color(hex: 0xFFB74D)
    case .leakSensor: return Color(hex: 0x4DA8FF)
    case .climateSensor: return Color(hex: 0x7CF5C4)
    default: return deviceAccent(type.controlKind)
    }
}

private let roomAccents: [Color] = [
    NexColors.cyan, NexColors.violet, NexColors.amber, NexColors.rose, NexColors.mint, NexColors.blue,
    NexColors.orange, NexColors.lime, NexColors.teal, NexColors.indigo, NexColors.gold, NexColors.pink,
]

/// A stable, vivid accent per room (used for room tiles, orbs and glows).
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
