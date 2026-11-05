import SwiftUI

/// NexHome text style tokens. The Android build hand-rolled these on top of `BasicText`; here they
/// are `Font` + tracking pairs applied through the `nexType(_:)` modifier.
enum NexType {
    case display, headline, title, body, bodyStrong, label, caption, numeric

    var font: Font {
        switch self {
        case .display: return .system(size: 40, weight: .semibold)
        case .headline: return .system(size: 28, weight: .semibold)
        case .title: return .system(size: 20, weight: .semibold)
        case .body: return .system(size: 15, weight: .regular)
        case .bodyStrong: return .system(size: 15, weight: .medium)
        case .label: return .system(size: 13, weight: .medium)
        case .caption: return .system(size: 11, weight: .medium)
        case .numeric: return .system(size: 48, weight: .light).monospacedDigit()
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display: return -1
        case .headline: return -0.4
        case .title: return -0.2
        case .body, .bodyStrong: return 0
        case .label: return 0
        case .caption: return 0.2
        case .numeric: return -1.5
        }
    }
}

extension View {
    /// Applies a NexHome type token (font + tracking) and a foreground colour.
    func nexType(_ style: NexType, color: Color = NexColors.primary) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
    }
}

/// Convenience: a `Text` already carrying a NexHome type token.
func NexText(_ string: String, _ style: NexType = .body, color: Color = NexColors.primary) -> some View {
    Text(string)
        .font(style.font)
        .tracking(style.tracking)
        .foregroundStyle(color)
}

/// Tabular-figure variants used for live numbers that must not jitter.
extension NexType {
    var monospacedFont: Font { font.monospacedDigit() }
}
