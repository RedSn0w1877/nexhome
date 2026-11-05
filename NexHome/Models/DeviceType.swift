import Foundation

/// The shape of interaction a device category gets. Each kind has one purpose-built control sheet.
enum ControlKind: Int, CaseIterable, Hashable, Sendable {
    case toggle
    case dimmer
    case thermostatDial
    case lock
    case garage
    case cameraFeed
    case blindsSlider
    case mediaPlayer
    case fanSpeed
    case applianceCycle
    case robotVacuum
    case waterHeaterDial
    case evCharger
    case sprinklerZones
    case sensorReadonly
    case securityPanel

    /// Matches the Android build's `ControlKind` names, used by the deep-link style launch hook.
    var key: String {
        switch self {
        case .toggle: return "TOGGLE"
        case .dimmer: return "DIMMER"
        case .thermostatDial: return "THERMOSTAT_DIAL"
        case .lock: return "LOCK"
        case .garage: return "GARAGE"
        case .cameraFeed: return "CAMERA_FEED"
        case .blindsSlider: return "BLINDS_SLIDER"
        case .mediaPlayer: return "MEDIA_PLAYER"
        case .fanSpeed: return "FAN_SPEED"
        case .applianceCycle: return "APPLIANCE_CYCLE"
        case .robotVacuum: return "ROBOT_VACUUM"
        case .waterHeaterDial: return "WATER_HEATER_DIAL"
        case .evCharger: return "EV_CHARGER"
        case .sprinklerZones: return "SPRINKLER_ZONES"
        case .sensorReadonly: return "SENSOR_READONLY"
        case .securityPanel: return "SECURITY_PANEL"
        }
    }
}

/// Every device category the generated house can contain.
enum DeviceType: String, CaseIterable, Hashable, Sendable {
    case ceilingLight = "CEILING_LIGHT"
    case lamp = "LAMP"
    case lightStrip = "LIGHT_STRIP"
    case wallSconce = "WALL_SCONCE"
    case outdoorLight = "OUTDOOR_LIGHT"
    case smartPlug = "SMART_PLUG"
    case smartOutlet = "SMART_OUTLET"
    case thermostat = "THERMOSTAT"
    case acUnit = "AC_UNIT"
    case entryLock = "ENTRY_LOCK"
    case garageDoor = "GARAGE_DOOR"
    case interiorDoor = "WINDOW_SENSOR_DOOR"
    case indoorCamera = "INDOOR_CAMERA"
    case outdoorCamera = "OUTDOOR_CAMERA"
    case doorbellCamera = "DOORBELL_CAMERA"
    case blinds = "BLINDS"
    case shade = "SHADE"
    case speaker = "SPEAKER"
    case tv = "TV"
    case soundbar = "SOUNDBAR"
    case ceilingFan = "CEILING_FAN"
    case standingFan = "STANDING_FAN"
    case airPurifier = "AIR_PURIFIER"
    case fridge = "FRIDGE"
    case oven = "OVEN"
    case microwave = "MICROWAVE"
    case dishwasher = "DISHWASHER"
    case washingMachine = "WASHING_MACHINE"
    case dryer = "DRYER"
    case grill = "GRILL"
    case robotVacuum = "ROBOT_VACUUM"
    case waterHeater = "WATER_HEATER"
    case poolHeater = "POOL_HEATER"
    case evCharger = "EV_CHARGER"
    case poolPump = "POOL_PUMP"
    case sprinkler = "SPRINKLER"
    case motionSensor = "MOTION_SENSOR"
    case contactSensor = "CONTACT_SENSOR"
    case smokeDetector = "SMOKE_DETECTOR"
    case coDetector = "CO_DETECTOR"
    case leakSensor = "LEAK_SENSOR"
    case climateSensor = "CLIMATE_SENSOR"
    case securityPanel = "SECURITY_PANEL"
    case bathroomHumidity = "BATHROOM_HUMIDITY"

    var label: String {
        switch self {
        case .ceilingLight: return "Ceiling Light"
        case .lamp: return "Lamp"
        case .lightStrip: return "Light Strip"
        case .wallSconce: return "Wall Sconce"
        case .outdoorLight: return "Outdoor Light"
        case .smartPlug: return "Smart Plug"
        case .smartOutlet: return "Smart Outlet"
        case .thermostat: return "Thermostat"
        case .acUnit: return "AC Unit"
        case .entryLock: return "Door Lock"
        case .garageDoor: return "Garage Door"
        case .interiorDoor: return "Interior Door"
        case .indoorCamera: return "Indoor Camera"
        case .outdoorCamera: return "Outdoor Camera"
        case .doorbellCamera: return "Video Doorbell"
        case .blinds: return "Blinds"
        case .shade: return "Roller Shade"
        case .speaker: return "Smart Speaker"
        case .tv: return "TV"
        case .soundbar: return "Soundbar"
        case .ceilingFan: return "Ceiling Fan"
        case .standingFan: return "Standing Fan"
        case .airPurifier: return "Air Purifier"
        case .fridge: return "Refrigerator"
        case .oven: return "Oven"
        case .microwave: return "Microwave"
        case .dishwasher: return "Dishwasher"
        case .washingMachine: return "Washing Machine"
        case .dryer: return "Dryer"
        case .grill: return "Smart Grill"
        case .robotVacuum: return "Robot Vacuum"
        case .waterHeater: return "Water Heater"
        case .poolHeater: return "Pool Heater"
        case .evCharger: return "EV Charger"
        case .poolPump: return "Pool Pump"
        case .sprinkler: return "Sprinkler System"
        case .motionSensor: return "Motion Sensor"
        case .contactSensor: return "Contact Sensor"
        case .smokeDetector: return "Smoke Detector"
        case .coDetector: return "CO Detector"
        case .leakSensor: return "Leak Sensor"
        case .climateSensor: return "Climate Sensor"
        case .securityPanel: return "Security Panel"
        case .bathroomHumidity: return "Humidity Control"
        }
    }

    var symbol: String {
        switch self {
        case .ceilingLight, .lamp, .lightStrip, .wallSconce: return "lightbulb.fill"
        case .outdoorLight: return "sun.horizon.fill"
        case .smartPlug: return "powerplug.fill"
        case .smartOutlet: return "bolt.fill"
        case .thermostat, .climateSensor: return "thermometer.medium"
        case .acUnit: return "snowflake"
        case .entryLock: return "lock.fill"
        case .garageDoor: return "door.garage.closed"
        case .interiorDoor: return "door.left.hand.closed"
        case .indoorCamera, .outdoorCamera, .doorbellCamera: return "video.fill"
        case .blinds, .shade: return "window.shade.closed"
        case .speaker: return "homepod.fill"
        case .tv: return "tv.fill"
        case .soundbar: return "hifispeaker.fill"
        case .ceilingFan: return "fan.ceiling.fill"
        case .standingFan: return "fan.desk.fill"
        case .airPurifier: return "air.purifier.fill"
        case .fridge: return "refrigerator.fill"
        case .oven: return "oven.fill"
        case .microwave: return "microwave.fill"
        case .dishwasher: return "dishwasher.fill"
        case .washingMachine: return "washer.fill"
        case .dryer: return "dryer.fill"
        case .grill: return "flame.fill"
        case .robotVacuum: return "sensor.fill"
        case .waterHeater: return "spigot.fill"
        case .poolHeater: return "figure.pool.swim"
        case .evCharger: return "ev.charger.fill"
        case .poolPump: return "arrow.triangle.2.circlepath"
        case .sprinkler: return "sprinkler.and.droplets.fill"
        case .motionSensor: return "sensor.fill"
        case .contactSensor: return "door.left.hand.open"
        case .smokeDetector, .coDetector: return "smoke.fill"
        case .leakSensor: return "drop.fill"
        case .securityPanel: return "shield.fill"
        case .bathroomHumidity: return "humidity.fill"
        }
    }

    var controlKind: ControlKind {
        switch self {
        case .ceilingLight, .lamp, .lightStrip, .wallSconce, .outdoorLight: return .dimmer
        case .smartPlug, .smartOutlet: return .toggle
        case .thermostat, .acUnit: return .thermostatDial
        case .entryLock, .interiorDoor: return .lock
        case .garageDoor: return .garage
        case .indoorCamera, .outdoorCamera, .doorbellCamera: return .cameraFeed
        case .blinds, .shade: return .blindsSlider
        case .speaker, .tv, .soundbar: return .mediaPlayer
        case .ceilingFan, .standingFan, .airPurifier, .bathroomHumidity: return .fanSpeed
        case .fridge, .oven, .microwave, .dishwasher, .washingMachine, .dryer, .grill: return .applianceCycle
        case .robotVacuum: return .robotVacuum
        case .waterHeater, .poolHeater: return .waterHeaterDial
        case .evCharger, .poolPump: return .evCharger
        case .sprinkler: return .sprinklerZones
        case .motionSensor, .contactSensor, .smokeDetector, .coDetector, .leakSensor, .climateSensor:
            return .sensorReadonly
        case .securityPanel: return .securityPanel
        }
    }

    /// Rooms this type can appear in.
    var rooms: Set<Room> {
        switch self {
        case .ceilingLight: return Room.indoor
        case .lamp: return Room.living
        case .lightStrip: return Room.accent
        case .wallSconce: return Room.hallways
        case .outdoorLight: return Room.outdoor
        case .smartPlug, .smartOutlet: return Room.indoor
        case .thermostat: return Room.thermostats
        case .acUnit: return Room.bedrooms
        case .entryLock: return Room.locks
        case .garageDoor: return [.garage, .driveway]
        case .interiorDoor: return Room.interiorDoors
        case .indoorCamera: return Room.indoor
        case .outdoorCamera: return Room.outdoor
        case .doorbellCamera: return [.entryway, .frontYard]
        case .blinds, .shade: return Room.windows
        case .speaker: return Room.indoor
        case .tv: return [.livingRoom, .primaryBedroom, .bedroomTwo, .gym]
        case .soundbar: return [.livingRoom]
        case .ceilingFan: return Room.bedrooms.union([.livingRoom])
        case .standingFan: return Room.indoor
        case .airPurifier: return Room.bedrooms.union([.livingRoom])
        case .fridge, .oven, .microwave, .dishwasher: return [.kitchen]
        case .washingMachine, .dryer: return [.laundryRoom]
        case .grill: return [.patio, .backyard]
        case .robotVacuum: return [.livingRoom, .kitchen, .hallway]
        case .waterHeater: return [.basement, .bathroomOne]
        case .poolHeater, .poolPump: return [.pool]
        case .evCharger: return [.garage, .driveway]
        case .sprinkler: return [.frontYard, .backyard]
        case .motionSensor: return Room.indoor.union(Room.outdoor)
        case .contactSensor: return Room.doorWindow
        case .smokeDetector: return Room.indoor
        case .coDetector: return [.kitchen, .garage, .basement]
        case .leakSensor: return [.kitchen, .bathroomOne, .bathroomTwo, .laundryRoom, .basement]
        case .climateSensor: return Room.indoor
        case .securityPanel: return [.entryway]
        case .bathroomHumidity: return [.bathroomOne, .bathroomTwo]
        }
    }

    /// Inclusive `first...last` count of this type generated per applicable room.
    var perRoomCount: ClosedRange<Int> {
        switch self {
        // Every house gets its one alarm panel (it only fits in the entryway): Home's security
        // module and the Security screen are built around it.
        case .ceilingLight, .securityPanel: return 1...1
        case .outdoorLight, .outdoorCamera: return 1...2
        case .smartPlug: return 1...3
        case .lamp, .wallSconce, .blinds, .smartOutlet, .contactSensor: return 0...2
        default: return 0...1
        }
    }
}
