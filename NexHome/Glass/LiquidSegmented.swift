import SwiftUI

/// One option of a `LiquidSegmented` selector.
struct SegmentOption: Hashable {
    let label: String
    var symbol: String?

    init(_ label: String, _ symbol: String? = nil) {
        self.label = label
        self.symbol = symbol
    }
}

/// Draggable glass blob selector: tap an option or drag the blob across; it snaps to the nearest
/// option with overshoot, swells while held and ticks a haptic per option crossed. The blob emits
/// `accent` as light while held.
struct LiquidSegmented: View {
    let options: [SegmentOption]
    let selectedIndex: Int
    var accent: Color = NexColors.cyan
    let onSelect: (Int) -> Void

    private var count: Int { max(options.count, 1) }
    private var hasSymbols: Bool { options.contains { $0.symbol != nil } }
    private var barHeight: CGFloat { hasSymbols ? 64 : 48 }
    private var blobHeight: CGFloat { barHeight - 8 }

    @State private var blob: CGFloat = 0
    @State private var dragging = false
    @State private var startBlob: CGFloat = 0
    @State private var lastTick = 0
    @State private var frame: CGRect = .zero
    @State private var token = LightToken()
    @Environment(GlassLight.self) private var light: GlassLight?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let optionWidth = max((width - 8) / CGFloat(count), 1)

            ZStack(alignment: .leading) {
                // The bar.
                GlassPanel(shape: glassCapsule, tint: NexColors.glassTintDark) {
                    HStack(spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            SegmentItem(option: option, tint: NexColors.secondary)
                                .frame(width: optionWidth, height: blobHeight)
                                .contentShape(Rectangle())
                                .onTapGesture { select(index) }
                        }
                    }
                    .padding(4)
                    .frame(height: barHeight)
                }

                // The draggable glass blob, with the selected option drawn in the accent on top.
                ZStack {
                    Capsule()
                        .fill(accent.opacity(0.18))
                        .glassEffect(.regular.interactive(), in: Capsule())
                    if options.indices.contains(snappedIndex) {
                        SegmentItem(option: options[snappedIndex], tint: .white)
                    }
                }
                .frame(width: optionWidth, height: blobHeight)
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8)
                }
                .scaleEffect(x: dragging ? 1.1 : 1, y: dragging ? 1.06 : 1)
                .shadow(color: .black.opacity(dragging ? 0.2 : 0.1), radius: 12)
                .offset(x: 4 + blob * optionWidth)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragging {
                                dragging = true
                                startBlob = blob
                                lastTick = Int(blob.rounded())
                                light?.begin(token, at: globalPoint(value.location), color: accent)
                            } else {
                                light?.move(token, to: globalPoint(value.location))
                            }
                            let next = clamp(
                                startBlob + value.translation.width / optionWidth,
                                0,
                                CGFloat(count - 1)
                            )
                            blob = next
                            let tick = Int(next.rounded())
                            if tick != lastTick {
                                lastTick = tick
                                Haptics.tick()
                            }
                        }
                        .onEnded { _ in
                            dragging = false
                            light?.end(token)
                            let target = clamp(Int(blob.rounded()), 0, count - 1)
                            withAnimation(GlassMotion.blob) { blob = CGFloat(target) }
                            if target != selectedIndex { onSelect(target) }
                        }
                )
            }
            .frame(width: width, height: barHeight)
        }
        .frame(height: barHeight)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .onAppear { blob = CGFloat(clamp(selectedIndex, 0, count - 1)) }
        .onChange(of: selectedIndex) { _, newValue in
            guard !dragging else { return }
            withAnimation(GlassMotion.blob) { blob = CGFloat(clamp(newValue, 0, count - 1)) }
        }
    }

    private var snappedIndex: Int { clamp(Int(blob.rounded()), 0, count - 1) }

    private func select(_ index: Int) {
        guard index != selectedIndex else { return }
        Haptics.tick()
        withAnimation(GlassMotion.blob) { blob = CGFloat(index) }
        onSelect(index)
    }

    private func globalPoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
    }
}

private struct SegmentItem: View {
    let option: SegmentOption
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            if let symbol = option.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            NexText(option.label, .label, color: tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
