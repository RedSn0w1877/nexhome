import SwiftUI

extension Color {
    /// 0xRRGGBB / 0xAARRGGBB hex initialiser, matching the Android build's color literals.
    init(hex: UInt32) {
        let hasAlpha = hex > 0xFF_FFFF
        let a = hasAlpha ? Double((hex >> 24) & 0xFF) / 255 : 1
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// Deep, saturated backdrop colours — liquid glass reads best over rich, high-contrast content.
let spaceInk = Color(hex: 0x060A14)
let spaceDeep = Color(hex: 0x0C1626)
let spaceViolet = Color(hex: 0x241134)
let spaceRose = Color(hex: 0x3A1030)
let spaceTeal = Color(hex: 0x06232A)
let spaceAmber = Color(hex: 0x2A1A05)

/// NexHome colour tokens for the always-dark liquid-glass UI.
enum NexColors {
    /// Text / icon emphasis levels.
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.72)
    static let tertiary = Color.white.opacity(0.48)
    static let quaternary = Color.white.opacity(0.28)

    /// Vivid accents.
    static let cyan = Color(hex: 0x6FE3FF)
    static let violet = Color(hex: 0xB98CFF)
    static let amber = Color(hex: 0xFFC46F)
    static let rose = Color(hex: 0xFF8FB4)
    static let mint = Color(hex: 0x7CF5C4)
    static let red = Color(hex: 0xFF4D6D)
    static let blue = Color(hex: 0x52B6FF)
    static let orange = Color(hex: 0xFF8A4C)
    static let lime = Color(hex: 0xB8F55A)
    static let teal = Color(hex: 0x4FD1C5)
    static let indigo = Color(hex: 0x8C7BFF)
    static let gold = Color(hex: 0xFFD84D)
    static let pink = Color(hex: 0xFF7EDB)

    /// Default glass surface tints.
    static let glassTint = Color.black.opacity(0.05)
    static let glassTintDark = Color.black.opacity(0.18)
    static let glassTintLight = Color.white.opacity(0.08)

    /// Container colour of liquid tracks and bars.
    static let track = Color(hex: 0x787880).opacity(0.36)
    static let bar = Color(hex: 0x121212).opacity(0.4)

    /// Scrim behind sheets.
    static let dim = Color.black.opacity(0.38)
}
