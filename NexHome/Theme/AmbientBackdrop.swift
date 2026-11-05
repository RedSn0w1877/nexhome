import SwiftUI

/// A user-selectable wallpaper palette. Every glass surface in the app refracts whichever is
/// active, so each one is a saturated 3 × 3 mesh with a few soft light blobs on top. Clear Liquid
/// Glass only reads as glass when there is real colour and contrast behind it to bend.
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

    /// Mesh colours, row by row (top to bottom, left to right).
    var mesh: [Color] {
        let hexes: [UInt32]
        switch self {
        case .nebula:
            hexes = [0x2B1055, 0x5B2A86, 0x0E5A6B,
                     0x7A1E5E, 0x3A2A8C, 0x1A7F8E,
                     0xB3466B, 0x2A1B4D, 0xC0782E]
        case .dusk:
            hexes = [0x3A1F5C, 0x8A3C7E, 0xD06A8C,
                     0x24306E, 0x6A3A8E, 0xE08A6A,
                     0x101A48, 0x3B2A6E, 0xF0A860]
        case .forest:
            hexes = [0x0B3B2E, 0x1F6B4C, 0x2E8C6A,
                     0x0A2A24, 0x2A7A5A, 0x5ACFA0,
                     0x06231C, 0x14503E, 0x8AD9B0]
        case .ember:
            hexes = [0x3A0F0F, 0x8A2A1A, 0xC9502C,
                     0x5A1414, 0xB94A2C, 0xE88A3A,
                     0x1A0A0A, 0x6A1E14, 0xFFC46F]
        case .mono:
            hexes = [0x1A1A1E, 0x3A3A42, 0x24242A,
                     0x2E2E36, 0x55555F, 0x2A3A44,
                     0x0C0C10, 0x30303A, 0x3A6A7A]
        }
        return hexes.map { Color(hex: $0) }
    }

    /// Soft light blobs floating over the mesh: colour, centre (unit space), diameter (× width).
    var blobs: [(color: Color, center: UnitPoint, size: CGFloat)] {
        switch self {
        case .nebula:
            return [(Color(hex: 0x6FE3FF), UnitPoint(x: 0.88, y: 0.18), 0.75),
                    (Color(hex: 0xFF5FA2), UnitPoint(x: 0.12, y: 0.62), 0.8),
                    (Color(hex: 0xFFB54A), UnitPoint(x: 0.8, y: 0.92), 0.7)]
        case .dusk:
            return [(Color(hex: 0xFF8FB1), UnitPoint(x: 0.85, y: 0.25), 0.8),
                    (Color(hex: 0x7A6CFF), UnitPoint(x: 0.15, y: 0.7), 0.75),
                    (Color(hex: 0xFFC27A), UnitPoint(x: 0.75, y: 0.95), 0.6)]
        case .forest:
            return [(Color(hex: 0x7CF5C4), UnitPoint(x: 0.85, y: 0.3), 0.7),
                    (Color(hex: 0x3AD08A), UnitPoint(x: 0.1, y: 0.55), 0.7),
                    (Color(hex: 0xD8F57C), UnitPoint(x: 0.7, y: 0.95), 0.55)]
        case .ember:
            return [(Color(hex: 0xFF7A3A), UnitPoint(x: 0.88, y: 0.2), 0.75),
                    (Color(hex: 0xFF3A5A), UnitPoint(x: 0.12, y: 0.6), 0.7),
                    (Color(hex: 0xFFD27A), UnitPoint(x: 0.8, y: 0.95), 0.65)]
        case .mono:
            return [(Color(hex: 0x6FE3FF), UnitPoint(x: 0.85, y: 0.85), 0.6),
                    (Color(hex: 0xFFFFFF), UnitPoint(x: 0.15, y: 0.2), 0.5)]
        }
    }
}

/// The wallpaper every glass surface in the app refracts: a vivid mesh gradient with soft light
/// blobs, or the user's own photo once they pick one.
struct AmbientBackdrop: View {
    var theme: BackgroundTheme = .nebula
    var customImage: UIImage?

    private static let points: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.45], [0.55, 0.5], [1, 0.4],
        [0, 1], [0.5, 1], [1, 1],
    ]

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
                    // A light scrim keeps text readable over an arbitrary photo.
                    Color.black.opacity(0.2)
                } else {
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: Self.points,
                        colors: theme.mesh,
                        smoothsColors: true
                    )
                    ForEach(Array(theme.blobs.enumerated()), id: \.offset) { _, blob in
                        Circle()
                            .fill(blob.color.opacity(0.55))
                            .frame(width: size.width * blob.size, height: size.width * blob.size)
                            .blur(radius: size.width * 0.16)
                            .position(
                                x: size.width * blob.center.x,
                                y: size.height * blob.center.y
                            )
                            .blendMode(.plusLighter)
                    }
                    // Keep the darkest corners from going muddy and the brightest from blowing out.
                    LinearGradient(
                        colors: [Color.black.opacity(0.1), .clear, Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            .drawingGroup()
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: theme)
    }
}
