import Foundation
import Observation

/// A single simulated smart-home device.
///
/// Every field is observable state directly on the model, so any control view can read and mutate a
/// device in place without a view model per device — this app is a concept surface for hundreds of
/// devices, not a production client. (On Android these were Compose `mutableStateOf` fields; the
/// Observation framework gives the same "mutate the model, the UI follows" behaviour here.)
@Observable
final class Device: Identifiable {
    let id: String
    let name: String
    let type: DeviceType
    let room: Room

    var isOn: Bool
    var isOnline: Bool = true

    // Dimmer / lights
    var brightness: Double = 0.7
    var colorTempK: Int = 3200

    // Thermostat / water heater / pool heater
    var currentTempF: Double = 70
    var targetTempF: Double = 70
    var isHeating: Bool = false
    var isCooling: Bool = false

    // Locks / garage / interior doors
    var lockState: LockState = .locked
    var garageState: GarageState = .closed

    // Camera
    var cameraSeed: Int = Int.random(in: 0...9999)
    var isRecording: Bool = true
    var motionDetected: Bool = false

    // Blinds / shades
    var position: Double = 1  // 0 = closed, 1 = fully open

    // Media
    var volume: Double = 0.4
    var isPlaying: Bool = false
    var mediaSource: MediaSource = .off
    var nowPlaying: String = ""

    // Fans
    var fanSpeed: Int = 0  // 0...4
    var isOscillating: Bool = false

    // Appliances
    var applianceMode: ApplianceMode = .off
    var cycleProgress: Double = 0
    var minutesRemaining: Int = 0
    var applianceTempF: Double = 0

    // Vacuum
    var vacuumState: VacuumState = .docked
    var batteryPercent: Int = 100

    // EV charger / pool pump
    var chargePercent: Int = 62
    var isCharging: Bool = false
    var chargeRateKw: Double = 7.2

    // Sprinkler
    var activeZones: Set<Int> = []
    var totalZones: Int = 4

    // Sensors (read-only)
    var sensorValue: String = "Clear"
    var sensorNumeric: Double = 0
    var lastEventMinutesAgo: Int = Int.random(in: 1...180)

    // Security panel
    var alarmState: AlarmState = .disarmed

    // Power draw, shown on plugs/outlets and as ambient detail
    var powerDrawWatts: Double = 0

    // ---- Rich detail state ----

    // General
    var energyTodayKwh: Double = 0
    var powerHistory: [Double] = Array(repeating: 0, count: 24)  // 24 hourly watts, oldest first
    var signalStrength: Int = 4  // 0...4 bars
    var firmwareVersion: String = "1.0.0"
    var isFavorite: Bool = false

    // Lights
    var supportsColor: Bool = false
    var lightColorMode: LightColorMode = .white
    var hue: Double = 30  // 0...360
    var saturation: Double = 0.8  // 0...1
    var activeScene: String = ""  // "" = none
    var fadeSeconds: Int = 1
    var motionActivated: Bool = false
    var sunsetSchedule: Bool = false

    // Plugs / outlets (schedule fields also used by climate)
    var childLock: Bool = false
    var overloadProtection: Bool = true
    var scheduleEnabled: Bool = false
    var scheduleOnHour: Int = 18  // 0...23
    var scheduleOffHour: Int = 23  // 0...23

    // Climate
    var hvacMode: HvacMode = .auto
    var fanMode: FanMode = .auto
    var humidityPercent: Int = 45
    var outdoorTempF: Double = 68
    var tempHistory: [Double] = Array(repeating: 70, count: 24)
    var ecoEnabled: Bool = false
    var filterLifePercent: Int = 80

    // Water heater / pool heater
    var waterHeaterMode: WaterHeaterMode = .eco
    var hotWaterPercent: Int = 90
    var boostActive: Bool = false

    // Fans / purifier / humidity control
    var fanTimerMinutes: Int = 0  // 0 = no timer
    var breezeMode: Bool = false
    var reverseDirection: Bool = false
    var airQualityIndex: Int = 30  // US AQI, lower is better
    var humidityTarget: Int = 50

    // Lock / interior door
    var autoLockEnabled: Bool = true
    var autoLockSeconds: Int = 60
    var doorAjar: Bool = false
    var lockActivity: [ActivityEvent] = []  // newest first
    var guestAccess: [String] = []

    // Garage
    var doorPosition: Double = 0  // 0 closed ... 1 open
    var garageOpening: Bool = true  // direction while garageState == .moving
    var obstructionDetected: Bool = false
    var autoCloseMinutes: Int = 0  // 0 = off
    var garageLightOn: Bool = false
    var garageActivity: [ActivityEvent] = []  // newest first

    // Camera
    var spotlightOn: Bool = false
    var sirenOn: Bool = false
    var privacyMode: Bool = false
    var talkActive: Bool = false
    var nightVisionMode: NightVisionMode = .auto
    var zoom: Double = 1  // 1...4
    var panX: Double = 0  // -1...1
    var panY: Double = 0  // -1...1
    var motionSensitivity: Double = 0.6  // 0...1
    var cameraEvents: [CameraEvent] = []  // newest first

    // Media
    var trackTitle: String = ""
    var trackArtist: String = ""
    var trackProgress: Double = 0  // 0...1
    var trackDurationSec: Int = 210
    var shuffle: Bool = false
    var repeatMode: RepeatMode = .off
    var bass: Double = 0  // -1...1
    var treble: Double = 0  // -1...1
    var muted: Bool = false
    var artworkHue: Double = 260  // 0...360
    var groupedWith: Set<String> = []  // device ids

    // Appliances
    var program: String = ""
    var cycleTotalMinutes: Int = 60  // length of the current cycle
    var delayStartMinutes: Int = 0
    var spinLevel: Int = 2  // 0...4
    var washTempLevel: Int = 1  // 0...3 (cold, warm, hot, extra hot)
    var ovenMode: OvenMode = .bake
    var targetApplianceTempF: Double = 350
    var timerMinutes: Int = 0  // 0 = no timer
    var fridgeTempF: Double = 37
    var freezerTempF: Double = 0
    var iceMakerOn: Bool = true
    var doorOpen: Bool = false
    var microwavePower: Int = 10  // 1...10
    var probeTempF: Double = 70
    var detergentPercent: Int = 70

    // Vacuum
    var suction: SuctionLevel = .standard
    var mopEnabled: Bool = false
    var binFull: Bool = false
    var cleanedAreaSqFt: Int = 0
    var cleaningMinutes: Int = 0
    var selectedRooms: Set<Room> = []
    var cleaningProgress: Double = 0  // 0...1 along the current lawnmower path
    var robotX: Double = 0.1  // 0...1 map space
    var robotY: Double = 0.9  // 0...1 map space

    // EV charger / pool pump
    var chargeLimitPercent: Int = 80
    var chargeAmps: Int = 32  // 8...48
    var offPeakScheduling: Bool = false
    var sessionKwh: Double = 0
    var sessionCost: Double = 0  // USD
    var vehicleName: String = ""
    var plugConnected: Bool = false
    var pumpSpeedRpm: Int = 2400
    var pumpScheduleHours: Int = 8

    // Sprinkler
    var sprinklerZones: [SprinklerZone] = []
    var sprinklerRunAll: Bool = false  // zones run in sequence while true
    var rainDelayHours: Int = 0
    var soilMoisturePercent: Int = 40
    var waterUsageHistory: [Double] = Array(repeating: 0, count: 7)  // gallons/day, oldest first
    var smartWeatherSkip: Bool = true

    // Sensors
    var sensorHistory: [Double] = Array(repeating: 0, count: 24)
    var sensitivity: Double = 0.6  // 0...1
    var chimeEnabled: Bool = false
    var autoShutoffValve: Bool = false
    var lastTestedDaysAgo: Int = 30

    // Security panel
    var armingTarget: AlarmState?  // state reached when the exit countdown ends
    var exitDelaySeconds: Int = 30  // configured exit delay
    var exitCountdownSeconds: Int = 0  // live countdown while .arming
    var entryDelaySeconds: Int = 30
    var securityZones: [SecurityZone] = []
    var sirenVolume: Double = 0.8  // 0...1
    var chimeOnOpen: Bool = true

    init(id: String, name: String, type: DeviceType, room: Room, initiallyOn: Bool = true) {
        self.id = id
        self.name = name
        self.type = type
        self.room = room
        self.isOn = initiallyOn
    }

    var controlKind: ControlKind { type.controlKind }
}
