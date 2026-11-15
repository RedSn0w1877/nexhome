import SwiftUI

extension Color {
    /// 0xRRGGBB / 0xAARRGGBB hex initialiser.
    init(hex: UInt32) {
        let hasAlpha = hex > 0xFF_FFFF
        let a = hasAlpha ? Double((hex >> 24) & 0xFF) / 255 : 1
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// NexHome colour tokens. The app is always dark, so the accents are Apple's dark-appearance system
/// colours written out as fixed values (they also blend predictably in `lerp(to:_:)`), and text uses
/// the system label hierarchy.
enum NexColors {
    /// Text and icon emphasis levels (label, secondaryLabel, tertiaryLabel, quaternaryLabel on dark).
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.7)
    static let tertiary = Color.white.opacity(0.5)
    static let quaternary = Color.white.opacity(0.3)

    // Apple system colours, dark appearance.
    static let red = Color(hex: 0xFF453A)
    static let orange = Color(hex: 0xFF9F0A)
    static let yellow = Color(hex: 0xFFD60A)
    static let green = Color(hex: 0x30D158)
    static let mint = Color(hex: 0x63E6E2)
    static let teal = Color(hex: 0x40CBE0)
    static let cyan = Color(hex: 0x64D2FF)
    static let blue = Color(hex: 0x0A84FF)
    static let indigo = Color(hex: 0x5E5CE6)
    static let purple = Color(hex: 0xBF5AF2)
    static let pink = Color(hex: 0xFF375F)
    static let brown = Color(hex: 0xAC8E68)

    // Names the controls use for their roles.
    static let violet = purple
    static let amber = yellow
    static let gold = yellow
    static let rose = pink
    static let lime = green

    /// Inset fill for anything sitting *inside* a glass surface (wells, tracks, inner tiles), the
    /// dark-appearance tertiarySystemFill. Glass is never stacked on glass.
    static let fill = Color(hex: 0x767680).opacity(0.24)
    /// Slightly stronger inset fill for pressed or emphasised inner surfaces.
    static let fillStrong = Color(hex: 0x787880).opacity(0.36)
    /// Unfilled part of tracks, gauges and rings.
    static let track = Color(hex: 0x787880).opacity(0.32)
    /// Hairline separators inside glass.
    static let separator = Color.white.opacity(0.14)
}
