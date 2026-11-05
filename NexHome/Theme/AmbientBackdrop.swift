import SwiftUI

/// A user-selectable wallpaper palette — every glass surface in the app refracts whichever is
/// active. Stop centres are relative to the view (the Android build used raw pixel offsets on a
/// 1080 × 2400 screen; these are the same positions expressed as fractions).
enum BackgroundTheme: Int, CaseIterable, Identifiable, Hashable {
    case nebula, dusk, forest, ember, mono

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .nebula: return "Nebula"
        case .dusk: return "Dusk"
        case .forest: return "Forest"
        case .ember: return "Ember"
        case .mono: return "Monochrome"
        }
    }

    struct Stop {
        let color: Color
        let center: UnitPoint
    }

    var base: Color { spaceInk }

    var stops: [Stop] {
        switch self {
        case .nebula:
            return [
                Stop(color: spaceViolet, center: UnitPoint(x: 0, y: 0)),
                Stop(color: spaceTeal.opacity(0.9), center: UnitPoint(x: 1.11, y: 0.125)),
                Stop(color: spaceRose.opacity(0.8), center: UnitPoint(x: 0.185, y: 0.917)),
                Stop(color: spaceAmber.opacity(0.55), center: UnitPoint(x: 0.926, y: 0.875)),
            ]
        case .dusk:
            return [
                Stop(color: Color(hex: 0x3A1F5C), center: UnitPoint(x: 0, y: 0)),
                Stop(color: Color(hex: 0xB3548A).opacity(0.7), center: UnitPoint(x: 1.02, y: 0.21)),
                Stop(color: Color(hex: 0x1B2A6B).opacity(0.85), center: UnitPoint(x: 0.28, y: 0.96)),
                Stop(color: Color(hex: 0xFF9E5E).opacity(0.4), center: UnitPoint(x: 0.83, y: 0.83)),
            ]
        case .forest:
            return [
                Stop(color: Color(hex: 0x0B3B2E), center: UnitPoint(x: 0, y: 0)),
                Stop(color: Color(hex: 0x1F6B4C).opacity(0.8), center: UnitPoint(x: 1.06, y: 0.146)),
                Stop(color: Color(hex: 0x06231C), center: UnitPoint(x: 0.23, y: 0.917)),
                Stop(color: Color(hex: 0x7CF5C4).opacity(0.3), center: UnitPoint(x: 0.88, y: 0.79)),
            ]
        case .ember:
            return [
                Stop(color: Color(hex: 0x3A0F0F), center: UnitPoint(x: 0, y: 0)),
                Stop(color: Color(hex: 0xB94A2C).opacity(0.75), center: UnitPoint(x: 1.11, y: 0.125)),
                Stop(color: Color(hex: 0x1A0A0A), center: UnitPoint(x: 0.185, y: 0.917)),
                Stop(color: Color(hex: 0xFFC46F).opacity(0.4), center: UnitPoint(x: 0.926, y: 0.83)),
            ]
        case .mono:
            return [
                Stop(color: Color(hex: 0x1A1A1E), center: UnitPoint(x: 0, y: 0)),
                Stop(color: Color(hex: 0x3A3A42).opacity(0.8), center: UnitPoint(x: 1.11, y: 0.125)),
                Stop(color: Color(hex: 0x08080A), center: UnitPoint(x: 0.185, y: 0.917)),
                Stop(color: Color(hex: 0x6FE3FF).opacity(0.18), center: UnitPoint(x: 0.926, y: 0.83)),
            ]
        }
    }

    /// Stop radius as a fraction of the view's width (1300 px on a 1080 px-wide screen).
    var radiusFraction: CGFloat {
        switch self {
        case .nebula, .ember, .mono: return 1.20
        case .dusk: return 1.30
        case .forest: return 1.25
        }
    }
}

/// The living wallpaper every glass surface in the app refracts. Liquid Glass has nothing to bend
/// or tint without a busy, colourful backdrop beneath it, so this is deliberately rich: a stack of
/// wide radial gradients over a near-black base, or the user's own photo once they pick one.
struct AmbientBackdrop: View {
    var theme: BackgroundTheme = .nebula
    var customImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if let customImage {
                    Image(uiImage: customImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                    // A dimming scrim keeps glass readable over an arbitrary photo.
                    Color.black.opacity(0.35)
                } else {
                    theme.base
                    ForEach(Array(theme.stops.enumerated()), id: \.offset) { _, stop in
                        RadialGradient(
                            gradient: Gradient(colors: [stop.color, stop.color.opacity(0)]),
                            center: stop.center,
                            startRadius: 0,
                            endRadius: size.width * theme.radiusFraction
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }
}
