import SwiftUI

/// NexHome text styles, mapped onto the system text styles so every label follows Dynamic Type.
enum NexType {
    case display, headline, title, body, bodyStrong, label, caption, numeric

    var font: Font {
        switch self {
        case .display: return .system(.largeTitle, weight: .bold)
        case .headline: return .system(.title, weight: .bold)
        case .title: return .system(.title3, weight: .semibold)
        case .body: return .system(.subheadline)
        case .bodyStrong: return .system(.subheadline, weight: .semibold)
        case .label: return .system(.footnote, weight: .medium)
        case .caption: return .system(.caption2, weight: .medium)
        case .numeric: return .system(size: 48, weight: .light, design: .rounded).monospacedDigit()
        }
    }

    /// Tabular-figure variant for live numbers that must not jitter.
    var monospacedFont: Font { font.monospacedDigit() }
}

extension View {
    /// Applies a NexHome text style and a foreground colour.
    func nexType(_ style: NexType, color: Color = NexColors.primary) -> some View {
        self
            .font(style.font)
            .foregroundStyle(color)
    }
}

/// A `Text` carrying a NexHome text style.
func NexText(_ string: String, _ style: NexType = .body, color: Color = NexColors.primary) -> Text {
    Text(string)
        .font(style.font)
        .foregroundStyle(color)
}
