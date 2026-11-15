import SwiftUI

/// Hold-to-confirm glass orb (lock/unlock, garage, arm alarm, start cycle, scenes).
///
/// Press and hold: a progress ring fills over `holdMillis`; when it completes there is a haptic, a
/// small pop and `onConfirmed`. Letting go early winds the ring back. `active` fills the glass with
/// `accent` (e.g. "locked", "running"). The hold is the system long-press gesture, so scrolling
/// past the orb still works.
struct LiquidHoldOrb: View {
    let label: String
    let symbol: String
    var accent: Color = NexColors.mint
    var active: Bool = false
    var holdMillis: Int = 850
    var size: CGFloat = 132
    var sublabel: String?
    var enabled: Bool = true
    let onConfirmed: () -> Void

    @State private var progress: Double = 0
    @State private var pop = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: size, height: size)
                    .glassControl(Circle(), tint: active ? accent : nil)

                ring
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
            }
            .scaleEffect(pop ? 1.12 : 1)
            .opacity(enabled ? 1 : 0.5)
            .onLongPressGesture(
                minimumDuration: Double(holdMillis) / 1000,
                maximumDistance: 40,
                perform: complete,
                onPressingChanged: pressing
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(sublabel ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { complete() } }

            VStack(spacing: 2) {
                NexText(label, .bodyStrong)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                if let sublabel {
                    NexText(sublabel, .caption, color: NexColors.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .accessibilityHidden(true)
        }
        .animation(GlassMotion.glow, value: active)
    }

    /// The hold progress ring, inset from the orb's edge.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(progress > 0 ? 0.18 : 0), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .rotation(.degrees(-90))
                .stroke(active ? Color.white : accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .padding(7)
    }

    private func pressing(_ isPressing: Bool) {
        guard enabled else { return }
        if isPressing {
            withAnimation(.linear(duration: Double(holdMillis) / 1000)) { progress = 1 }
        } else if progress < 1 {
            withAnimation(GlassMotion.release) { progress = 0 }
        }
    }

    private func complete() {
        guard enabled else { return }
        Haptics.confirm()
        onConfirmed()
        withAnimation(.spring(duration: 0.22, bounce: 0.5)) { pop = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(GlassMotion.release) { pop = false }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(GlassMotion.glow) { progress = 0 }
        }
    }
}
