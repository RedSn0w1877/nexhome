import Foundation

/// Procedurally builds a full house's worth of devices — hundreds of them, spread across every
/// room, weighted so bigger / more device-dense rooms (kitchen, living room) get more.
enum DeviceGenerator {

    /// A song in the simulated streaming catalog.
    struct Track: Sendable {
        let title: String
        let artist: String
        let durationSec: Int
        let hue: Double
    }

    static let tracks: [Track] = [
        Track(title: "Late Night Drive", artist: "Nocturn", durationSec: 224, hue: 250),
        Track(title: "Golden Hour", artist: "Amber Fields", durationSec: 198, hue: 38),
        Track(title: "Static & Rain", artist: "Lowlight", durationSec: 263, hue: 205),
        Track(title: "Halcyon", artist: "Reverie", durationSec: 241, hue: 175),
        Track(title: "Neon Parade", artist: "Cyan Hours", durationSec: 187, hue: 300),
        Track(title: "Slow Bloom", artist: "Petal Radio", durationSec: 276, hue: 335),
        Track(title: "Glass Harbor", artist: "Tidewater", durationSec: 232, hue: 190),
        Track(title: "Emberlight", artist: "Kiln", durationSec: 205, hue: 18),
        Track(title: "Paper Moons", artist: "Satellite Hearts", durationSec: 219, hue: 225),
        Track(title: "Velvet Circuit", artist: "Mono Bloom", durationSec: 254, hue: 280),
        Track(title: "Citrus Skies", artist: "Palm Static", durationSec: 181, hue: 55),
        Track(title: "Aurora Loop", artist: "Northbound", durationSec: 297, hue: 140),
    ]

    /// Loads catalog track `index` into `device`, keeping `nowPlaying` in sync.
    static func applyTrack(_ device: Device, index: Int) {
        let count = tracks.count
        let wrapped = ((index % count) + count) % count
        let track = tracks[wrapped]
        device.trackTitle = track.title
        device.trackArtist = track.artist
        device.trackDurationSec = track.durationSec
        device.artworkHue = track.hue
        device.trackProgress = 0
        device.nowPlaying = "\(track.title) — \(track.artist)"
    }

    /// Rough live power estimate in watts for any device, derived from its current state.
    static func estimateWatts(_ device: Device) -> Double {
        guard device.isOnline else { return 0 }
        let on = device.isOn
        switch device.controlKind {
        case .dimmer:
            return on ? ratedLightWatts(device.type) * min(max(device.brightness, 0.05), 1) : 0.3
        case .toggle:
            return on ? device.powerDrawWatts : 0.4
        case .thermostatDial:
            if !on || device.hvacMode == .off { return 3 }
            if device.type == .acUnit { return device.isCooling ? 1150 : 25 }
            if device.isHeating || device.isCooling { return 3400 }
            return 90
        case .lock:
            return 0.4
        case .garage:
            return (device.garageState == .moving ? 550 : 4) + (device.garageLightOn ? 60 : 0)
        case .cameraFeed:
            if device.privacyMode { return 1.5 }
            return 5 + (device.spotlightOn ? 14 : 0) + (device.sirenOn ? 6 : 0)
        case .blindsSlider:
            return 0.5
        case .mediaPlayer:
            if !on { return 1.5 }
            switch device.type {
            case .tv: return 95 + device.volume * 20
            case .soundbar: return 20 + (device.isPlaying && !device.muted ? device.volume * 60 : 0)
            default: return 4 + (device.isPlaying && !device.muted ? device.volume * 18 : 0)
            }
        case .fanSpeed:
            if !on { return 0.5 }
            switch device.type {
            case .ceilingFan: return 6 + Double(device.fanSpeed) * 14
            case .airPurifier: return 4 + Double(device.fanSpeed) * 11
            case .bathroomHumidity: return 8 + Double(device.fanSpeed) * 18
            default: return 5 + Double(device.fanSpeed) * 12
            }
        case .applianceCycle:
            let running = device.applianceMode == .running && device.delayStartMinutes == 0
            switch device.type {
            case .fridge:
                return 120 + (device.doorOpen ? 45 : 0) + (device.iceMakerOn ? 10 : 0)
            case .oven:
                guard running else { return 2 }
                return device.applianceTempF < device.targetApplianceTempF - 5 ? 2600 : 1100
            case .microwave:
                return running ? 110 * Double(device.microwavePower) : 2
            case .dishwasher:
                return running ? 1250 : 1
            case .washingMachine:
                return running ? 450 + Double(device.washTempLevel) * 350 : 1
            case .dryer:
                return running ? 2900 : 1
            case .grill:
                return running ? 45 : 1
            default:
                return 1
            }
        case .robotVacuum:
            switch device.vacuumState {
            case .cleaning: return 30 + Double(device.suction.rawValue) * 12
            case .returning: return 28
            case .docked: return device.batteryPercent < 100 ? 24 : 3
            case .paused: return 4
            }
        case .waterHeaterDial:
            if !on { return 2 }
            if device.boostActive { return 5500 }
            if device.isHeating { return device.type == .poolHeater ? 3200 : 4500 }
            return 6
        case .evCharger:
            if device.type == .evCharger {
                return device.isCharging ? device.chargeRateKw * 1000 : 2
            }
            return on ? 1100 * (Double(device.pumpSpeedRpm) / 3450) : 2
        case .sprinklerZones:
            return device.sprinklerZones.contains(where: { $0.running }) ? 24 : 2
        case .sensorReadonly:
            return 0.2
        case .securityPanel:
            return device.sirenOn ? 18 : 4
        }
    }

    private static func ratedLightWatts(_ type: DeviceType) -> Double {
        switch type {
        case .ceilingLight: return 18
        case .lamp: return 9
        case .lightStrip: return 14
        case .wallSconce: return 7
        case .outdoorLight: return 22
        default: return 10
        }
    }

    static func generate(seed: UInt64 = 42) -> [Device] {
        var random = SeededRandom(seed: seed)
        var devices: [Device] = []
        var counter = 0

        for room in Room.allCases {
            for type in DeviceType.allCases where type.rooms.contains(room) {
                let range = type.perRoomCount
                let count = range.lowerBound == range.upperBound
                    ? range.lowerBound
                    : random.nextInt(range.lowerBound, range.upperBound + 1)
                for index in 0..<max(count, 0) {
                    counter += 1
                    let suffix = count > 1 ? " \(index + 1)" : ""
                    let device = Device(
                        id: "dev_\(counter)_\(type.rawValue.lowercased())",
                        name: "\(room.displayName) \(type.label)\(suffix)",
                        type: type,
                        room: room,
                        initiallyOn: random.chance(0.55)
                    )
                    seedState(device, &random)
                    seedGeneral(device, &random)
                    devices.append(device)
                }
            }
        }
        groupSpeakers(devices, &random)
        return devices
    }

    // MARK: - Per-kind seeding

    private static func seedState(_ device: Device, _ random: inout SeededRandom) {
        switch device.controlKind {
        case .dimmer:
            seedLight(device, &random)

        case .toggle:
            device.powerDrawWatts = device.isOn ? random.nextDouble() * 140 + 4 : 0
            device.childLock = random.chance(0.2)
            device.overloadProtection = random.chance(0.85)
            device.scheduleEnabled = random.chance(0.35)
            device.scheduleOnHour = random.nextInt(5, 20)
            device.scheduleOffHour = (device.scheduleOnHour + random.nextInt(2, 8)) % 24

        case .thermostatDial:
            seedClimate(device, &random)

        case .lock:
            device.lockState = random.chance(0.85) ? .locked : .unlocked
            device.isOn = true
            device.batteryPercent = random.nextInt(18, 101)
            device.autoLockEnabled = random.chance(0.7)
            device.autoLockSeconds = random.pick([30, 60, 120, 300])
            device.doorAjar = device.lockState == .unlocked && random.chance(0.3)
            device.lockActivity = lockLog(&random)
            device.guestAccess = device.type == .entryLock
                ? Array(random.shuffle(guestNames).prefix(random.nextInt(1, 4)))
                : []

        case .garage:
            device.garageState = random.chance(0.8) ? .closed : .open
            device.doorPosition = device.garageState == .open ? 1 : 0
            device.garageOpening = device.garageState == .closed
            device.isOn = true
            device.obstructionDetected = device.garageState == .open && random.chance(0.15)
            device.autoCloseMinutes = random.pick([0, 0, 5, 10, 15])
            device.garageLightOn = device.garageState == .open && random.chance(0.6)
            device.garageActivity = garageLog(&random)

        case .cameraFeed:
            seedCamera(device, &random)

        case .blindsSlider:
            device.position = random.nextDouble()
            device.sunsetSchedule = random.chance(0.4)

        case .mediaPlayer:
            seedMedia(device, &random)

        case .fanSpeed:
            device.fanSpeed = device.isOn ? random.nextInt(1, 5) : 0
            device.isOscillating = random.chance(0.3)
            device.fanTimerMinutes = device.isOn && random.chance(0.25) ? random.pick([30, 60, 120]) : 0
            device.breezeMode = device.type == .standingFan && random.chance(0.3)
            device.reverseDirection = device.type == .ceilingFan && random.chance(0.3)
            device.airQualityIndex = random.nextInt(8, 85)
            device.filterLifePercent = random.nextInt(12, 100)
            device.humidityPercent = device.type == .bathroomHumidity
                ? random.nextInt(45, 80)
                : random.nextInt(35, 55)
            device.humidityTarget = random.pick([40, 45, 50, 55])

        case .applianceCycle:
            seedAppliance(device, &random)

        case .robotVacuum:
            device.vacuumState = random.chance(0.7) ? .docked : .cleaning
            device.batteryPercent = random.nextInt(20, 101)
            device.isOn = true
            device.suction = random.pick(SuctionLevel.self)
            device.mopEnabled = random.chance(0.3)
            device.binFull = random.chance(0.12)
            var picked: Set<Room> = []
            for room in vacuumRooms where random.chance(0.6) { picked.insert(room) }
            device.selectedRooms = picked.isEmpty ? [device.room] : picked
            if device.vacuumState == .cleaning {
                device.cleaningProgress = random.nextDouble() * 0.7
                device.cleaningMinutes = Int((device.cleaningProgress * 60).rounded())
                device.cleanedAreaSqFt = Int((device.cleaningProgress * 900).rounded())
                // Robot position is placed on its path by the repository's first motion tick.
            } else {
                device.cleaningMinutes = random.nextInt(25, 70)
                device.cleanedAreaSqFt = random.nextInt(350, 950)
            }

        case .waterHeaterDial:
            let pool = device.type == .poolHeater
            device.currentTempF = pool ? random.nextDouble() * 8 + 76 : random.nextDouble() * 15 + 110
            device.targetTempF = pool ? 84 : 120
            let mode = random.pick(WaterHeaterMode.self)
            device.waterHeaterMode = (mode == .vacation && !random.chance(0.3)) ? .eco : mode
            device.hotWaterPercent = random.nextInt(35, 101)
            device.isHeating = device.isOn && device.currentTempF < device.targetTempF - 1
            let base = device.currentTempF
            device.tempHistory = history(24, &random) { hour, rng in
                base + cosWave(hour, 6) * 3 + (rng.nextDouble() - 0.5)
            }

        case .evCharger:
            device.isOn = true
            if device.type == .evCharger {
                device.chargePercent = random.nextInt(20, 100)
                device.chargeLimitPercent = random.pick([80, 80, 90, 100])
                device.plugConnected = random.chance(0.7)
                device.isCharging = device.plugConnected
                    && device.chargePercent < device.chargeLimitPercent
                    && random.chance(0.5)
                device.chargeAmps = random.pick([16, 24, 32, 40, 48])
                device.chargeRateKw = Double(device.chargeAmps) * 240 / 1000
                device.offPeakScheduling = random.chance(0.5)
                device.sessionKwh = device.plugConnected ? random.nextDouble() * 18 : 0
                device.sessionCost = device.sessionKwh * (device.offPeakScheduling ? 0.14 : 0.28)
                device.vehicleName = random.pick(vehicleNames)
            } else {
                device.isOn = random.chance(0.6)
                device.pumpSpeedRpm = random.pick([1200, 1800, 2400, 3000, 3450])
                device.pumpScheduleHours = random.nextInt(4, 13)
                device.scheduleEnabled = random.chance(0.7)
                device.scheduleOnHour = random.nextInt(6, 11)
            }

        case .sprinklerZones:
            device.totalZones = random.nextInt(3, 7)
            device.isOn = true
            device.sprinklerZones = random.shuffle(zoneNames).prefix(device.totalZones).map { name in
                let zone = SprinklerZone(name: name)
                zone.durationMinutes = random.pick([5, 8, 10, 12, 15, 20])
                return zone
            }
            device.rainDelayHours = random.pick([0, 0, 0, 24, 48])
            device.soilMoisturePercent = random.nextInt(18, 70)
            device.waterUsageHistory = history(7, &random) { _, rng in rng.nextDouble() * 90 + 20 }
            device.smartWeatherSkip = random.chance(0.75)

        case .sensorReadonly:
            device.isOn = true
            seedSensor(device, &random)

        case .securityPanel:
            device.isOn = true
            device.alarmState = random.pick([AlarmState.disarmed, .disarmed, .armedHome])
            device.exitDelaySeconds = random.pick([30, 45, 60])
            device.entryDelaySeconds = random.pick([15, 30, 45])
            device.securityZones = securityZoneNames.map { name in
                let zone = SecurityZone(name: name)
                zone.isOpen = random.chance(0.1)
                zone.bypassed = random.chance(0.06)
                return zone
            }
            device.sirenVolume = random.nextDouble() * 0.4 + 0.6
            device.chimeOnOpen = random.chance(0.8)
            device.batteryPercent = random.nextInt(70, 101)
        }
    }

    private static func seedLight(_ device: Device, _ random: inout SeededRandom) {
        device.brightness = device.isOn ? min(max(random.nextDouble(), 0.2), 1) : 0
        device.colorTempK = random.pick([2200, 2700, 3200, 4000, 5000, 6500])
        switch device.type {
        case .lightStrip, .lamp: device.supportsColor = true
        case .ceilingLight: device.supportsColor = random.chance(0.35)
        default: device.supportsColor = false
        }
        device.lightColorMode = device.supportsColor && random.chance(0.5) ? .color : .white
        device.hue = random.nextDouble() * 360
        device.saturation = random.nextDouble() * 0.5 + 0.5
        device.activeScene = device.isOn && random.chance(0.3) ? random.pick(lightScenes) : ""
        device.fadeSeconds = random.pick([0, 1, 2, 3, 5])
        device.motionActivated = (device.type == .wallSconce || device.type == .outdoorLight)
            && random.chance(0.6)
        device.sunsetSchedule = device.type == .outdoorLight || random.chance(0.2)
    }

    private static func seedClimate(_ device: Device, _ random: inout SeededRandom) {
        device.currentTempF = random.nextDouble() * 10 + 66
        device.targetTempF = min(max(device.currentTempF + random.nextDouble() * 4 - 2, 60), 82)
        if !device.isOn {
            device.hvacMode = .off
        } else if device.type == .acUnit {
            device.hvacMode = .cool
        } else {
            device.hvacMode = random.pick([HvacMode.auto, .auto, .heat, .cool, .eco])
        }
        updateClimateFlags(device)
        device.fanMode = random.pick(FanMode.self)
        device.humidityPercent = random.nextInt(32, 58)
        device.outdoorTempF = random.nextDouble() * 40 + 45
        let base = device.currentTempF
        device.tempHistory = history(24, &random) { hour, rng in
            base + cosWave(hour, 5) * 2.5 + (rng.nextDouble() - 0.5) * 0.6
        }
        device.ecoEnabled = device.hvacMode == .eco || random.chance(0.3)
        device.filterLifePercent = random.nextInt(8, 100)
        device.scheduleEnabled = random.chance(0.6)
    }

    /// Derives isHeating / isCooling from HVAC mode and temperatures.
    static func updateClimateFlags(_ device: Device) {
        let on = device.isOn && device.hvacMode != .off
        let wantsHeat = device.targetTempF > device.currentTempF + 0.4
        let wantsCool = device.targetTempF < device.currentTempF - 0.4
        device.isHeating = on && wantsHeat && device.type != .acUnit && device.hvacMode != .cool
        device.isCooling = on && wantsCool && device.hvacMode != .heat
    }

    private static func seedCamera(_ device: Device, _ random: inout SeededRandom) {
        device.isOn = true
        device.isRecording = random.chance(0.9)
        device.motionDetected = random.chance(0.15)
        device.cameraSeed = random.nextInt(0, 9999)
        let outdoor = device.type != .indoorCamera
        if outdoor { device.batteryPercent = random.nextInt(25, 101) }
        device.spotlightOn = outdoor && random.chance(0.1)
        device.privacyMode = !outdoor && random.chance(0.15)
        device.nightVisionMode = random.pick([NightVisionMode.auto, .auto, .on, .off])
        device.motionSensitivity = random.nextDouble() * 0.6 + 0.3
        let labels: [String]
        switch device.type {
        case .doorbellCamera:
            labels = ["Doorbell ring", "Person detected", "Package delivered", "Motion", "Package picked up"]
        case .outdoorCamera:
            labels = ["Person detected", "Vehicle detected", "Motion", "Animal detected"]
        default:
            labels = ["Motion", "Person detected", "Pet detected", "Sound detected"]
        }
        var minutes = device.motionDetected ? 0 : random.nextInt(2, 30)
        var events: [CameraEvent] = []
        for _ in 0..<random.nextInt(4, 9) {
            events.append(CameraEvent(label: random.pick(labels), minutesAgo: minutes, seed: random.nextInt(0, 9999)))
            minutes += random.nextInt(8, 140)
        }
        device.cameraEvents = events
    }

    private static func seedMedia(_ device: Device, _ random: inout SeededRandom) {
        device.isPlaying = device.isOn && random.chance(0.4)
        device.volume = random.nextDouble() * 0.6 + 0.1
        if !device.isPlaying {
            device.mediaSource = .off
        } else if device.type == .tv {
            device.mediaSource = .tvInput
        } else {
            device.mediaSource = random.pick([MediaSource.streaming, .streaming, .radio, .bluetooth])
        }
        applyTrack(device, index: random.nextInt(0, tracks.count))
        device.trackProgress = random.nextDouble() * 0.8
        device.shuffle = random.chance(0.3)
        device.repeatMode = random.pick(RepeatMode.self)
        device.bass = (random.nextDouble() - 0.5) * 0.8
        device.treble = (random.nextDouble() - 0.5) * 0.6
        device.muted = false
    }

    private static func groupSpeakers(_ devices: [Device], _ random: inout SeededRandom) {
        let speakers = devices.filter { $0.type == .speaker || $0.type == .soundbar }
        guard speakers.count >= 2 else { return }
        let group = Array(random.shuffle(speakers).prefix(min(3, speakers.count)))
        let ids = Set(group.map(\.id))
        for speaker in group { speaker.groupedWith = ids.subtracting([speaker.id]) }
    }

    private static func seedAppliance(_ device: Device, _ random: inout SeededRandom) {
        let type = device.type
        let running = type != .fridge && random.chance(0.25)
        device.applianceMode = running ? .running : .off
        device.isOn = type == .fridge || running || random.chance(0.5)
        let list = programs(for: type)
        device.program = list.isEmpty ? "" : random.pick(list)
        switch type {
        case .washingMachine: device.cycleTotalMinutes = random.nextInt(40, 75)
        case .dryer: device.cycleTotalMinutes = random.nextInt(45, 70)
        case .dishwasher: device.cycleTotalMinutes = random.nextInt(60, 140)
        case .microwave: device.cycleTotalMinutes = random.nextInt(2, 8)
        case .oven, .grill: device.cycleTotalMinutes = random.nextInt(30, 90)
        default: device.cycleTotalMinutes = 0
        }
        if running {
            device.cycleProgress = random.nextDouble() * 0.8
            device.minutesRemaining = max(
                1, Int((Double(device.cycleTotalMinutes) * (1 - device.cycleProgress)).rounded())
            )
        }
        device.delayStartMinutes = !running && random.chance(0.2) ? random.pick([30, 60, 120]) : 0
        device.spinLevel = random.nextInt(0, 5)
        device.washTempLevel = random.nextInt(0, 4)
        device.detergentPercent = random.nextInt(10, 101)
        device.ovenMode = random.pick(OvenMode.self)
        device.targetApplianceTempF = type == .grill
            ? random.pick([225.0, 275, 350, 450])
            : random.pick([325.0, 350, 375, 400, 425])
        device.timerMinutes = running && (type == .oven || type == .microwave || type == .grill)
            ? max(1, device.minutesRemaining)
            : 0
        device.fridgeTempF = random.nextDouble() * 3 + 35
        device.freezerTempF = random.nextDouble() * 4 - 2
        device.iceMakerOn = random.chance(0.8)
        device.doorOpen = type == .fridge && random.chance(0.05)
        device.microwavePower = random.nextInt(5, 11)
        switch type {
        case .fridge: device.applianceTempF = device.fridgeTempF
        case .oven, .grill:
            device.applianceTempF = running
                ? device.targetApplianceTempF - random.nextDouble() * 60
                : 70
        default: device.applianceTempF = 0
        }
        device.probeTempF = running && (type == .oven || type == .grill)
            ? random.nextDouble() * 80 + 90
            : 70
    }

    private static func seedSensor(_ device: Device, _ random: inout SeededRandom) {
        device.batteryPercent = random.nextInt(15, 101)
        device.sensitivity = random.nextDouble() * 0.6 + 0.3
        device.lastTestedDaysAgo = random.nextInt(1, 120)
        switch device.type {
        case .motionSensor:
            device.sensorValue = random.chance(0.2) ? "Motion detected" : "Clear"
            device.sensorHistory = history(24, &random) { hour, rng in
                max(0, cosWave(hour, 19) * 5 + 4 + Double(rng.nextInt(0, 4)))
            }
        case .contactSensor:
            device.sensorValue = random.chance(0.1) ? "Open" : "Closed"
            device.chimeEnabled = random.chance(0.6)
            device.sensorHistory = history(24, &random) { hour, rng in
                max(0, cosWave(hour, 18) * 3 + Double(rng.nextInt(0, 3)))
            }
        case .smokeDetector, .coDetector:
            device.sensorValue = "Normal"
            device.sensorNumeric = device.type == .coDetector
                ? random.nextDouble() * 3
                : random.nextDouble() * 8
            let base = device.sensorNumeric
            device.sensorHistory = history(24, &random) { _, rng in base + rng.nextDouble() * 2 }
        case .leakSensor:
            device.sensorValue = random.chance(0.03) ? "Leak detected" : "Dry"
            device.autoShutoffValve = random.chance(0.5)
            device.sensorNumeric = device.sensorValue == "Dry" ? random.nextDouble() * 12 + 3 : 92
            let base = device.sensorNumeric
            device.sensorHistory = history(24, &random) { _, rng in base * 0.8 + rng.nextDouble() * 4 }
        case .climateSensor:
            device.sensorNumeric = random.nextDouble() * 8 + 66
            device.humidityPercent = random.nextInt(35, 56)
            device.sensorValue = "\(Int(device.sensorNumeric))°F · \(device.humidityPercent)% humidity"
            let base = device.sensorNumeric
            device.sensorHistory = history(24, &random) { hour, rng in
                base + cosWave(hour, 16) * 2 + (rng.nextDouble() - 0.5) * 0.5
            }
            device.tempHistory = device.sensorHistory
            device.currentTempF = device.sensorNumeric
        default:
            device.sensorValue = "Normal"
        }
    }

    /// Fields common to every device: connectivity, firmware, favourites and energy history.
    private static func seedGeneral(_ device: Device, _ random: inout SeededRandom) {
        let outdoor = Room.outdoor.contains(device.room)
        device.signalStrength = outdoor ? random.nextInt(1, 5) : random.nextInt(2, 5)
        device.isOnline = random.nextDouble() > 0.01
        device.firmwareVersion = "\(random.nextInt(1, 6)).\(random.nextInt(0, 12)).\(random.nextInt(0, 30))"
        device.isFavorite = random.chance(0.08)
        let base = max(estimateWatts(device), estimateWattsWhenActive(device))
        device.powerHistory = history(24, &random) { hour, rng in
            let daily = 0.55 + 0.45 * cosWave(hour, 19)
            return max(0, base * daily * (0.6 + rng.nextDouble() * 0.6))
        }
        device.energyTodayKwh = device.powerHistory.prefix(18).reduce(0, +) / 1000 * 0.7
        if device.controlKind != .toggle {
            device.powerDrawWatts = estimateWatts(device)
        }
    }

    /// Typical watts while in use, so histories look plausible even for devices currently off.
    private static func estimateWattsWhenActive(_ device: Device) -> Double {
        switch device.controlKind {
        case .dimmer: return ratedLightWatts(device.type) * 0.4
        case .toggle: return 40
        case .thermostatDial: return device.type == .acUnit ? 500 : 900
        case .mediaPlayer: return device.type == .tv ? 60 : 10
        case .applianceCycle:
            switch device.type {
            case .fridge: return 120
            case .dryer: return 700
            case .oven: return 500
            case .grill: return 20
            default: return 250
            }
        case .waterHeaterDial: return 900
        case .evCharger: return device.type == .evCharger ? 2400 : 500
        case .fanSpeed: return 25
        default: return 2
        }
    }

    private static func lockLog(_ random: inout SeededRandom) -> [ActivityEvent] {
        var minutes = random.nextInt(3, 40)
        var events: [ActivityEvent] = []
        for _ in 0..<random.nextInt(4, 8) {
            let entry = random.pick(lockEvents)
            events.append(ActivityEvent(label: entry.0, detail: entry.1, minutesAgo: minutes))
            minutes += random.nextInt(20, 300)
        }
        return events
    }

    private static func garageLog(_ random: inout SeededRandom) -> [ActivityEvent] {
        var minutes = random.nextInt(5, 60)
        var events: [ActivityEvent] = []
        for _ in 0..<random.nextInt(4, 8) {
            let entry = random.pick(garageEvents)
            events.append(ActivityEvent(label: entry.0, detail: entry.1, minutesAgo: minutes))
            minutes += random.nextInt(30, 400)
        }
        return events
    }

    private static func history(
        _ count: Int,
        _ random: inout SeededRandom,
        _ sample: (Int, inout SeededRandom) -> Double
    ) -> [Double] {
        _ = random.next()  // decorrelate successive histories
        var out: [Double] = []
        out.reserveCapacity(count)
        for hour in 0..<count { out.append(sample(hour, &random)) }
        return out
    }

    /// Cosine wave over a 24 h day peaking (1) at `peakHour`, trough (-1) twelve hours away.
    static func cosWave(_ hour: Int, _ peakHour: Double) -> Double {
        cos((Double(hour) - peakHour) / 24 * 2 * .pi)
    }
}

// MARK: - Catalogs

private let lightScenes = ["Read", "Relax", "Focus", "Night", "Party"]

private let guestNames = [
    "Dog walker · Weekdays 12–1 PM",
    "House cleaner · Thursdays 9 AM–1 PM",
    "Grandma · Always",
    "Neighbor Sam · Until Sunday",
    "Babysitter · Fri & Sat evenings",
]

private let lockEvents: [(String, String)] = [
    ("Locked", "App · You"),
    ("Unlocked", "Keypad · Alex"),
    ("Auto-locked", "After 60 s"),
    ("Unlocked", "Fingerprint · Jordan"),
    ("Locked", "Keypad · Alex"),
    ("Unlocked", "Guest code · Dog walker"),
    ("Door opened", "Contact sensor"),
    ("Door closed", "Contact sensor"),
]

private let garageEvents: [(String, String)] = [
    ("Opened", "Remote · Car"),
    ("Closed", "App · You"),
    ("Auto-closed", "After 10 min"),
    ("Opened", "Keypad · Alex"),
    ("Closed", "Wall button"),
    ("Light on", "Motion"),
]

private let vehicleNames = ["Model Y", "Ioniq 5", "Mustang Mach-E", "Rivian R1S", "EV6", "Polestar 2"]

private let vacuumRooms: [Room] = [.livingRoom, .kitchen, .hallway, .diningRoom, .entryway, .homeOffice]

private let zoneNames = [
    "Front Lawn", "Back Lawn", "Side Yard", "Flower Beds",
    "Vegetable Garden", "Hedges", "Drip Line", "Parkway",
]

private let securityZoneNames = [
    "Front Door", "Back Door", "Garage Entry", "Patio Slider",
    "Living Room Windows", "Kitchen Window", "Basement Motion", "Upstairs Hallway Motion",
]

/// Light scene chips offered on dimmer sheets.
let lightSceneNames = lightScenes
