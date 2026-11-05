import SwiftUI

/// A fake "live" camera feed: cycles through a fresh photo every `cycleSeconds` (picsum.photos,
/// seeded so each device shows a stable-but-changing stream) to simulate a moving feed without
/// video assets, then runs it through the camera's processing chain.
///
/// On Android the processing was an AGSL shader stack over a captured layer. Here it is built from
/// SwiftUI effects — grayscale + green multiply for night vision, blur + desaturation for the
/// privacy shutter, additive washes for the spotlight and siren, and a drawn scanline/refresh-band
/// shimmer — which keeps it entirely on the GPU without a Metal toolchain dependency.
struct CameraFeed: View {
    let seed: Int
    var cornerRadius: CGFloat = 24
    var cycleSeconds: Double = 4
    var cycling: Bool = true
    var shimmer: Bool = true
    var zoom: Double = 1
    var panX: Double = 0
    var panY: Double = 0
    /// Extra picture scale so a PTZ pan is visible even at 1×.
    var overscan: Double = 1
    var nightVision: Double = 0
    var privacy: Double = 0
    var spotlight: Double = 0
    var alarm: Double = 0
    var onSeedTick: ((Int) -> Void)?

    @State private var frameSeed: Int = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let nv = clamp01(nightVision)
        let shut = clamp01(privacy)
        let scale = max(zoom, 1) * max(overscan, 1)

        ZStack {
            Color.black

            AsyncImage(url: feedURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity.animation(.easeInOut(duration: 0.45)))
                case .failure:
                    // Offline or blocked: a plausible dark "no signal" field rather than nothing.
                    LinearGradient(
                        colors: [Color(hex: 0x121820), Color(hex: 0x1E2A33)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                default:
                    Color(hex: 0x0C1218)
                }
            }
            .scaleEffect(scale)
            .offset(
                x: scale > 1 ? -clamp(panX, -1, 1) * 40 * (scale - 1) : 0,
                y: scale > 1 ? -clamp(panY, -1, 1) * 40 * (scale - 1) : 0
            )
            .grayscale(nv)
            .colorMultiply(Color.white.lerp(to: Color(hex: 0x6CFFA6), nv))
            .brightness(nv * 0.04 - shut * 0.14)
            .saturation(1 - 0.85 * shut)
            .blur(radius: 28 * shut, opaque: true)

            // Night-vision vignette.
            if nv > 0.01 {
                RadialGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 260
                )
                .opacity(0.85 * nv)
            }

            // Warm spotlight from above.
            if spotlight > 0.01 {
                RadialGradient(
                    colors: [
                        Color(hex: 0xFFE7B0).opacity(0.42),
                        Color(hex: 0xFFC46F).opacity(0.12),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.5, y: -0.1),
                    startRadius: 0,
                    endRadius: 300
                )
                .opacity(clamp01(spotlight))
                .blendMode(.plusLighter)
            }

            // Siren wash.
            if alarm > 0.01 {
                RadialGradient(
                    colors: [
                        .clear,
                        Color(hex: 0xFF4D6D).opacity(0.18),
                        Color(hex: 0xFF4D6D).opacity(0.55),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 240
                )
                .opacity(clamp01(alarm))
                .blendMode(.plusLighter)
            }

            if shut > 0.01 {
                Color.black.opacity(0.34 * shut)
            }

            if shimmer {
                FeedShimmer()
            }
        }
        .clipShape(shape)
        .task(id: seed) { frameSeed = seed }
        .task(id: cycling) {
            guard cycling else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(cycleSeconds))
                guard !Task.isCancelled else { return }
                frameSeed = (frameSeed % 9973) + 1
                onSeedTick?(frameSeed)
            }
        }
    }

    private var feedURL: URL? {
        URL(string: "https://picsum.photos/seed/nexhome\(frameSeed)/800/600")
    }
}

/// Fine scanlines plus a slow rolling refresh band — proof of "it's live".
private struct FeedShimmer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let height = max(proxy.size.height, 1)
                let bandY = CGFloat((t * 0.11).truncatingRemainder(dividingBy: 1)) * height
                ZStack(alignment: .top) {
                    Canvas { canvas, size in
                        var y: CGFloat = 0
                        while y < size.height {
                            canvas.fill(
                                Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                with: .color(.white.opacity(0.02))
                            )
                            y += 3
                        }
                    }
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height * 0.16)
                    .offset(y: bandY - height * 0.08)
                }
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A small glass capsule over a feed (LIVE, timestamp, motion).
struct FeedChip<Content: View>: View {
    var tint: Color = Color.black.opacity(0.28)
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassPanel(shape: glassCapsule, tint: tint) {
            HStack(spacing: 5) {
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
}
