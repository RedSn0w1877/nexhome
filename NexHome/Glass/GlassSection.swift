import SwiftUI

/// A titled glass panel — the building block of every device sheet.
struct GlassSection<Content: View>: View {
    var title: String?
    var symbol: String?
    var accent: Color?
    var tint: Color = NexColors.glassTintDark
    var padding: CGFloat = 16
    var spacing: CGFloat = 14
    var trailing: AnyView?
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassPanel(shape: glassRect(28), tint: tint, heavy: true) {
            VStack(alignment: .leading, spacing: spacing) {
                if title != nil || trailing != nil || symbol != nil {
                    HStack(spacing: 8) {
                        if let symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accent ?? NexColors.secondary)
                        }
                        if let title {
                            NexText(title.uppercased(), .caption, color: NexColors.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let trailing { trailing }
                    }
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
        }
    }
}

/// A glass settings row: optional icon orb, title + subtitle, and a trailing slot (usually a
/// `LiquidToggle`, a value or a `LiquidStepper`).
struct GlassSettingRow<Trailing: View>: View {
    let title: String
    var symbol: String?
    var subtitle: String?
    var accent: Color = NexColors.cyan
    var action: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintLight,
            accent: action != nil ? accent : nil,
            interactive: true,
            pressScale: 1.04,
            action: action
        ) {
            HStack(spacing: 12) {
                if let symbol {
                    GlassIconOrb(symbol: symbol, accent: accent, size: 36, glow: 0.35, iconTint: .white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    NexText(title, .bodyStrong).lineLimit(1)
                    if let subtitle {
                        NexText(subtitle, .caption, color: NexColors.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                trailing()
            }
            .frame(minHeight: 60)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

extension GlassSettingRow where Trailing == EmptyView {
    init(
        title: String,
        symbol: String? = nil,
        subtitle: String? = nil,
        accent: Color = NexColors.cyan,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title, symbol: symbol, subtitle: subtitle, accent: accent, action: action,
            trailing: { EmptyView() }
        )
    }
}

/// A glass stat tile: symbol + label, a big value with a unit, and an optional sparkline.
struct GlassMetricTile: View {
    let label: String
    let value: String
    var unit: String?
    var symbol: String?
    var accent: Color = NexColors.cyan
    var history: [Double]?
    var action: (() -> Void)?

    var body: some View {
        GlassPanel(
            shape: glassRect(22),
            tint: NexColors.glassTintLight,
            accent: action != nil ? accent : nil,
            interactive: true,
            action: action,
            front: history.map { data in
                AnyView(Sparkline(values: data, accent: accent).padding(.bottom, 10))
            }
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    NexText(label, .caption, color: NexColors.secondary).lineLimit(1)
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    NexText(value, .title).lineLimit(1)
                    if let unit {
                        NexText(unit, .label, color: NexColors.tertiary).lineLimit(1)
                    }
                }
                if history != nil {
                    Spacer().frame(height: 34)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }
}

/// An accent sparkline over a soft accent fill, drawn inside a glass surface.
struct Sparkline: View {
    let values: [Double]
    let accent: Color
    var bandHeight: CGFloat = 40
    var horizontalInset: CGFloat = 12
    var smooth: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if values.count >= 2, size.width > horizontalInset * 2, size.height > 0 {
                let bottom = size.height
                let top = max(bottom - bandHeight, 0)
                let minV = values.min() ?? 0
                let maxV = values.max() ?? 1
                let span = (maxV - minV) > 1e-4 ? (maxV - minV) : 1
                let stepX = (size.width - horizontalInset * 2) / CGFloat(values.count - 1)
                let points: [CGPoint] = values.enumerated().map { index, value in
                    CGPoint(
                        x: horizontalInset + stepX * CGFloat(index),
                        y: bottom - CGFloat((value - minV) / span) * bandHeight
                    )
                }
                ZStack {
                    sparkPath(points, closeTo: bottom)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.32), accent.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .mask(
                            Rectangle()
                                .frame(height: bandHeight)
                                .offset(y: top)
                                .frame(height: size.height, alignment: .top)
                        )
                    sparkPath(points, closeTo: nil)
                        .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkPath(_ points: [CGPoint], closeTo bottom: CGFloat?) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        if let bottom {
            path.move(to: CGPoint(x: first.x, y: bottom))
            path.addLine(to: first)
        } else {
            path.move(to: first)
        }
        if smooth {
            var previous = first
            for point in points.dropFirst() {
                let midX = (previous.x + point.x) / 2
                path.addCurve(
                    to: point,
                    control1: CGPoint(x: midX, y: previous.y),
                    control2: CGPoint(x: midX, y: point.y)
                )
                previous = point
            }
        } else {
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        if let bottom, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: bottom))
            path.closeSubpath()
        }
        return path
    }
}
