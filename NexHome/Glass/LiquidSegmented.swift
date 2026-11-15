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

/// A segmented selector with icon-over-label options. The selection is a tinted glass thumb, like
/// the iOS tab bar's: tap an option, or drag the thumb across and it snaps to the nearest one.
struct LiquidSegmented: View {
    let options: [SegmentOption]
    let selectedIndex: Int
    var accent: Color = NexColors.cyan
    let onSelect: (Int) -> Void

    private var count: Int { max(options.count, 1) }
    private var hasSymbols: Bool { options.contains { $0.symbol != nil } }
    private var barHeight: CGFloat { hasSymbols ? 64 : 48 }
    private var thumbHeight: CGFloat { barHeight - 8 }

    @State private var thumb: CGFloat = 0
    @State private var dragging = false
    @State private var startThumb: CGFloat = 0
    @State private var lastTick = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let optionWidth = max((width - 8) / CGFloat(count), 1)

            ZStack(alignment: .leading) {
                GlassPanel(shape: glassCapsule) {
                    Color.clear.frame(width: width, height: barHeight)
                }

                Capsule()
                    .fill(.clear)
                    .frame(width: optionWidth, height: thumbHeight)
                    .glassControl(Capsule(), tint: accent.opacity(0.7))
                    .scaleEffect(dragging ? 1.06 : 1)
                    .offset(x: 4 + thumb * optionWidth)

                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        SegmentItem(
                            option: option,
                            tint: index == snappedIndex ? .white : NexColors.secondary
                        )
                        .frame(width: optionWidth, height: thumbHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { select(index) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 4)
                .allowsHitTesting(!dragging)
            }
            .frame(width: width, height: barHeight)
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            startThumb = thumb
                            lastTick = Int(thumb.rounded())
                        }
                        let next = clamp(
                            startThumb + value.translation.width / optionWidth,
                            0,
                            CGFloat(count - 1)
                        )
                        thumb = next
                        let tick = Int(next.rounded())
                        if tick != lastTick {
                            lastTick = tick
                            Haptics.tick()
                        }
                    }
                    .onEnded { _ in
                        dragging = false
                        let target = clamp(Int(thumb.rounded()), 0, count - 1)
                        withAnimation(GlassMotion.blob) { thumb = CGFloat(target) }
                        if target != selectedIndex { onSelect(target) }
                    }
            )
        }
        .frame(height: barHeight)
        .onAppear { thumb = CGFloat(clamp(selectedIndex, 0, count - 1)) }
        .onChange(of: selectedIndex) { _, newValue in
            guard !dragging else { return }
            withAnimation(GlassMotion.blob) { thumb = CGFloat(clamp(newValue, 0, count - 1)) }
        }
        .animation(GlassMotion.press, value: dragging)
    }

    private var snappedIndex: Int { clamp(Int(thumb.rounded()), 0, count - 1) }

    private func select(_ index: Int) {
        guard index != selectedIndex else { return }
        Haptics.tick()
        withAnimation(GlassMotion.blob) { thumb = CGFloat(index) }
        onSelect(index)
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
