import SwiftUI

// MARK: - LiquidButton

/// A capsule button in the system glass style; `tint` makes it the prominent, colour-filled glass.
struct LiquidButton<Content: View>: View {
    var tint: Color?
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 16)
            .frame(minWidth: 48, minHeight: 48)
            .glassControl(Capsule(), tint: tint)
        }
        .buttonStyle(GlassControlButtonStyle())
    }
}

// MARK: - LiquidToggle

/// The system switch, tinted with the device's accent. (On iOS 27 its thumb turns to glass while
/// it is dragged.)
struct LiquidToggle: View {
    let isOn: Bool
    var accent: Color = NexColors.green
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(
            "",
            isOn: Binding(
                get: { isOn },
                set: { newValue in
                    guard newValue != isOn else { return }
                    onChange(newValue)
                }
            )
        )
        .labelsHidden()
        .tint(accent)
        .fixedSize()
    }
}

// MARK: - LiquidSlider

/// The system slider, tinted with the accent; `onCommit` fires when the drag ends.
struct LiquidSlider: View {
    let value: Double
    var range: ClosedRange<Double> = 0...1
    var accent: Color = NexColors.blue
    let onChange: (Double) -> Void
    var onCommit: (() -> Void)?

    var body: some View {
        Slider(
            value: Binding(get: { clamp(value, range.lowerBound, range.upperBound) }, set: onChange),
            in: range,
            onEditingChanged: { editing in
                if !editing { onCommit?() }
            }
        )
        .tint(accent)
        .frame(height: 34)
    }
}

// MARK: - LiquidChip

/// A selectable glass capsule (scenes, programs, modes). Selected, the glass fills with `accent`.
struct LiquidChip: View {
    let label: String
    var symbol: String?
    let selected: Bool
    var accent: Color = NexColors.cyan
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tick()
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? .white : accent)
                }
                NexText(label, .label, color: selected ? .white : NexColors.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, symbol != nil ? 14 : 16)
            .frame(height: 40)
            .glassControl(Capsule(), tint: selected ? accent : nil)
        }
        .buttonStyle(GlassControlButtonStyle())
        .animation(GlassMotion.glow, value: selected)
    }
}

/// A horizontally scrolling row of chips. They share one glass container, so neighbouring chips
/// blend into each other as the system expects of a group.
struct LiquidChipRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    content()
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

// MARK: - LiquidColorOrbs

/// A row of colour swatches, marked the iOS way: a ring around the selected colour.
struct LiquidColorOrbs: View {
    let colors: [Color]
    let selectedIndex: Int
    var orbSize: CGFloat = 44
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Button {
                        Haptics.tick()
                        onSelect(index)
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: orbSize - 10, height: orbSize - 10)
                            .padding(5)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        index == selectedIndex ? Color.white : .clear,
                                        lineWidth: 2.5
                                    )
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(index + 1)")
                    .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
        .animation(GlassMotion.glow, value: selectedIndex)
    }
}

// MARK: - LiquidStepper

/// A capsule with glass −/+ buttons and the value between them. Holding a button repeats (the
/// system button repeat behaviour); the value rolls like a native numeric label.
struct LiquidStepper: View {
    let value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var format: (Double) -> String = { "\(Int($0.rounded()))" }
    var label: String?
    var accent: Color = NexColors.cyan
    let onChange: (Double) -> Void

    var body: some View {
        GlassPanel(shape: glassCapsule) {
            HStack(spacing: 6) {
                stepButton("minus", sign: -1, enabled: value > range.lowerBound)
                VStack(spacing: 0) {
                    Text(format(value))
                        .font(NexType.bodyStrong.monospacedFont)
                        .foregroundStyle(NexColors.primary)
                        .contentTransition(.numericText(value: value))
                        .lineLimit(1)
                    if let label {
                        NexText(label, .caption, color: NexColors.tertiary).lineLimit(1)
                    }
                }
                .frame(minWidth: 64)
                .animation(GlassMotion.press, value: value)
                stepButton("plus", sign: 1, enabled: value < range.upperBound)
            }
            .padding(5)
        }
    }

    private func stepButton(_ symbol: String, sign: Double, enabled: Bool) -> some View {
        Button {
            let next = clamp(value + sign * step, range.lowerBound, range.upperBound)
            guard next != value else { return }
            Haptics.tick()
            onChange(next)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.35))
                .frame(width: 40, height: 40)
                .glassControl(Circle())
        }
        .buttonStyle(GlassControlButtonStyle())
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .accessibilityLabel(sign < 0 ? "Decrease" : "Increase")
    }
}

/// `LiquidStepper` for integer fields.
struct LiquidIntStepper: View {
    let value: Int
    var range: ClosedRange<Int> = 0...100
    var step: Int = 1
    var format: (Int) -> String = { "\($0)" }
    var label: String?
    var accent: Color = NexColors.cyan
    let onChange: (Int) -> Void

    var body: some View {
        LiquidStepper(
            value: Double(value),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            format: { format(Int($0.rounded())) },
            label: label,
            accent: accent,
            onChange: { onChange(Int($0.rounded())) }
        )
    }
}
