import Foundation
import Observation

// Detail enums used by the rich per-category device state on `Device`.

enum LockState: Hashable, Sendable { case locked, unlocked }
enum GarageState: Hashable, Sendable { case open, closed, moving }

enum ApplianceMode: Int, CaseIterable, Hashable, Sendable {
    case off, running, paused, done
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .running: return "Running"
        case .paused: return "Paused"
        case .done: return "Done"
        }
    }
}

enum VacuumState: Int, CaseIterable, Hashable, Sendable {
    case docked, cleaning, returning, paused
    var displayName: String {
        switch self {
        case .docked: return "Docked"
        case .cleaning: return "Cleaning"
        case .returning: return "Returning"
        case .paused: return "Paused"
        }
    }
}

/// `.arming` = exit countdown running toward `Device.armingTarget` (see `DeviceRepository.armSecurity`).
enum AlarmState: Int, CaseIterable, Hashable, Sendable {
    case disarmed, armedHome, armedAway, triggered, armedNight, arming
    var displayName: String {
        switch self {
        case .disarmed: return "Disarmed"
        case .armedHome: return "Armed home"
        case .armedAway: return "Armed away"
        case .triggered: return "Triggered"
        case .armedNight: return "Armed night"
        case .arming: return "Arming"
        }
    }
}

enum MediaSource: Int, CaseIterable, Hashable, Sendable {
    case streaming, radio, bluetooth, tvInput, off
    var displayName: String {
        switch self {
        case .streaming: return "Streaming"
        case .radio: return "Radio"
        case .bluetooth: return "Bluetooth"
        case .tvInput: return "TV input"
        case .off: return "Off"
        }
    }
}

enum LightColorMode: Int, CaseIterable, Hashable, Sendable { case white, color }

enum HvacMode: Int, CaseIterable, Hashable, Sendable {
    case heat, cool, auto, eco, off
    var displayName: String {
        switch self {
        case .heat: return "Heat"
        case .cool: return "Cool"
        case .auto: return "Auto"
        case .eco: return "Eco"
        case .off: return "Off"
        }
    }
    var symbol: String {
        switch self {
        case .heat: return "flame.fill"
        case .cool: return "snowflake"
        case .auto: return "a.circle.fill"
        case .eco: return "leaf.fill"
        case .off: return "power"
        }
    }
}

enum FanMode: Int, CaseIterable, Hashable, Sendable {
    case auto, on, circulate
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .circulate: return "Circulate"
        }
    }
}

enum WaterHeaterMode: Int, CaseIterable, Hashable, Sendable {
    case eco, performance, vacation
    var displayName: String {
        switch self {
        case .eco: return "Eco"
        case .performance: return "Performance"
        case .vacation: return "Vacation"
        }
    }
    var symbol: String {
        switch self {
        case .eco: return "leaf.fill"
        case .performance: return "bolt.fill"
        case .vacation: return "airplane"
        }
    }
}

enum NightVisionMode: Int, CaseIterable, Hashable, Sendable {
    case auto, on, off
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}

enum RepeatMode: Int, CaseIterable, Hashable, Sendable {
    case off, all, one
    var displayName: String {
        switch self {
        case .off: return "Repeat off"
        case .all: return "Repeat all"
        case .one: return "Repeat one"
        }
    }
    var symbol: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

enum OvenMode: Int, CaseIterable, Hashable, Sendable {
    case bake, convection, broil, airFry, keepWarm
    var displayName: String {
        switch self {
        case .bake: return "Bake"
        case .convection: return "Convection"
        case .broil: return "Broil"
        case .airFry: return "Air Fry"
        case .keepWarm: return "Keep Warm"
        }
    }
}

enum SuctionLevel: Int, CaseIterable, Hashable, Sendable {
    case quiet, standard, turbo, max
    var displayName: String {
        switch self {
        case .quiet: return "Quiet"
        case .standard: return "Standard"
        case .turbo: return "Turbo"
        case .max: return "Max"
        }
    }
}

/// One row of a lock / garage activity log. `minutesAgo` is relative to app start.
struct ActivityEvent: Identifiable, Hashable, Sendable {
    let id = UUID()
    let label: String
    let detail: String
    let minutesAgo: Int
}

/// One camera timeline event; `seed` picks the thumbnail photo (same scheme as `Device.cameraSeed`).
struct CameraEvent: Identifiable, Hashable, Sendable {
    let id = UUID()
    let label: String
    let minutesAgo: Int
    let seed: Int
}

/// A watering zone of a sprinkler controller. Toggle via `DeviceRepository.setZoneRunning`.
@Observable
final class SprinklerZone: Identifiable {
    let id = UUID()
    let name: String
    var durationMinutes: Int = 10
    var running: Bool = false
    /// 0...1 progress of the current run; advanced by the repository motion loop while `running`.
    var progress: Double = 0

    init(name: String) { self.name = name }
}

/// A monitored door/window/motion zone of the security panel.
@Observable
final class SecurityZone: Identifiable {
    let id = UUID()
    let name: String
    var isOpen: Bool = false
    var bypassed: Bool = false

    init(name: String) { self.name = name }
}

/// Selectable programs (chips) for an appliance type; empty for non-appliances.
func programs(for type: DeviceType) -> [String] {
    switch type {
    case .washingMachine: return ["Normal", "Delicates", "Heavy Duty", "Quick Wash", "Bulky", "Sanitize"]
    case .dryer: return ["Normal", "Delicates", "Heavy Duty", "Towels", "Air Fluff", "Wrinkle Release"]
    case .dishwasher: return ["Auto", "Heavy", "Normal", "Eco", "Quick", "Rinse Only"]
    case .oven: return ["Custom", "Pizza", "Roast Chicken", "Cookies", "Bread", "Dehydrate"]
    case .microwave: return ["Reheat", "Defrost", "Popcorn", "Potato", "Beverage", "Steam Veggies"]
    case .grill: return ["Sear", "Smoke", "Low & Slow", "Roast", "Bake"]
    case .fridge: return ["Normal", "Party Chill", "Vacation", "Sabbath"]
    default: return []
    }
}
