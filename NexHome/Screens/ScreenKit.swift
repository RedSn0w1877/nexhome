import SwiftUI

// Shared building blocks of the NexHome screens.

/// A large screen title with an optional subtitle and a leading slot (e.g. a back button).
struct ScreenTitle<Leading: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 14) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                NexText(title, .headline).lineLimit(1)
                if let subtitle {
                    NexText(subtitle, .label, color: NexColors.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

extension ScreenTitle where Leading == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() })
    }
}

/// Uppercase section caption with an optional glass capsule action ("See all ›").
struct ScreenSectionLabel: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            NexText(title.uppercased(), .caption, color: NexColors.secondary).lineLimit(1)
            Spacer(minLength: 8)
            if let action, let onAction {
                GlassPanel(
                    shape: glassCapsule,
                    tint: NexColors.glassTintLight,
                    pressScale: 1.12,
                    action: onAction
                ) {
                    HStack(spacing: 2) {
                        NexText(action, .label).lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NexColors.primary)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.top, 6)
    }
}

/// A glass stat capsule: an accent value over a small label.
struct GlassStatPill: View {
    let value: String
    let label: String
    let accent: Color
    var symbol: String?
    var action: (() -> Void)?

    var body: some View {
        GlassPanel(
            shape: glassRect(20),
            tint: NexColors.glassTintLight,
            accent: accent,
            interactive: true,
            pressScale: 1.1,
            action: action
        ) {
            VStack(alignment: .leading, spacing: 2) {
                NexText(value, .title, color: accent).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NexColors.secondary)
                    }
                    NexText(label, .caption, color: NexColors.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Formatting helpers

/// Watts as a short number: "840" or "2.4" (see `powerUnitText`).
func powerValueText(_ watts: Double) -> String {
    watts >= 1000 ? (watts / 1000).fixed(1) : "\(Int(watts.rounded()))"
}

/// "W" or "kW" matching `powerValueText`.
func powerUnitText(_ watts: Double) -> String {
    watts >= 1000 ? "kW" : "W"
}

/// Human-readable alarm state of a security panel.
func alarmStateText(_ panel: Device) -> String {
    switch panel.alarmState {
    case .disarmed: return "Disarmed"
    case .armedHome: return "Armed · Home"
    case .armedAway: return "Armed · Away"
    case .armedNight: return "Armed · Night"
    case .arming: return "Arming · \(panel.exitCountdownSeconds)s"
    case .triggered: return "Alarm triggered"
    }
}

/// "4 lights · 2 plugs": the two most common device kinds of a room.
func roomSummary(_ devices: [Device]) -> String {
    var counts: [ControlKind: Int] = [:]
    for device in devices { counts[device.controlKind, default: 0] += 1 }
    return counts
        .sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
        }
        .prefix(2)
        .map { "\($0.value) \(kindNoun($0.key, $0.value))" }
        .joined(separator: " · ")
}

func kindNoun(_ kind: ControlKind, _ count: Int) -> String {
    let pair: (String, String)
    switch kind {
    case .dimmer: pair = ("light", "lights")
    case .toggle: pair = ("plug", "plugs")
    case .thermostatDial: pair = ("thermostat", "thermostats")
    case .lock: pair = ("lock", "locks")
    case .garage: pair = ("garage door", "garage doors")
    case .cameraFeed: pair = ("camera", "cameras")
    case .blindsSlider: pair = ("shade", "shades")
    case .mediaPlayer: pair = ("media device", "media devices")
    case .fanSpeed: pair = ("fan", "fans")
    case .applianceCycle: pair = ("appliance", "appliances")
    case .robotVacuum: pair = ("vacuum", "vacuums")
    case .waterHeaterDial: pair = ("heater", "heaters")
    case .evCharger: pair = ("charger", "chargers")
    case .sprinklerZones: pair = ("sprinkler", "sprinklers")
    case .sensorReadonly: pair = ("sensor", "sensors")
    case .securityPanel: pair = ("panel", "panels")
    }
    return count == 1 ? pair.0 : pair.1
}

/// "2 h ago" / "3 d ago" for activity and event rows.
func relativeMinutes(_ minutes: Int) -> String {
    if minutes < 1 { return "just now" }
    if minutes < 60 { return "\(minutes) min ago" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours) h ago" }
    return "\(hours / 24) d ago"
}

/// "4:05" for a seconds count.
func clockText(_ seconds: Int) -> String {
    let m = max(seconds, 0) / 60
    let s = max(seconds, 0) % 60
    return String(format: "%d:%02d", m, s)
}
