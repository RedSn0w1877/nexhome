import Foundation
import Observation

/// Whole-home scenes applied with `DeviceRepository.apply(scene:)`.
enum HomeScene: Int, CaseIterable, Hashable, Identifiable, Sendable {
    case morning, away, movie, bedtime

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .away: return "Away"
        case .movie: return "Movie"
        case .bedtime: return "Bedtime"
        }
    }

    var detail: String {
        switch self {
        case .morning: return "Lights up, blinds open, cozy 71°F"
        case .away: return "Everything off, doors locked, alarm armed"
        case .movie: return "Warm dim lights, blinds down, TV on"
        case .bedtime: return "Lights out, doors locked, night mode"
        }
    }

    var symbol: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .away: return "figure.walk.departure"
        case .movie: return "film.fill"
        case .bedtime: return "moon.stars.fill"
        }
    }
}

/// In-memory "house" of simulated devices. One instance lives for the app's lifetime.
@MainActor
@Observable
final class DeviceRepository {
    let devices: [Device]

    /// The last scene applied with `apply(scene:)`, or nil.
    private(set) var activeScene: HomeScene?

    /// Whole-home power in kW per hour for the last 24 hours (oldest first); the last sample is live.
    private(set) var homeEnergyHistory: [Double]

    private let byId: [String: Device]
    private let byKind: [ControlKind: [Device]]
    let roomsWithDevices: [Room]
    private let devicesByRoom: [Room: [Device]]

    init(seed: UInt64 = 42) {
        let generated = DeviceGenerator.generate(seed: seed)
        devices = generated
        byId = Dictionary(generated.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        byKind = Dictionary(grouping: generated, by: { $0.controlKind })
        let grouped = Dictionary(grouping: generated, by: { $0.room })
        devicesByRoom = grouped
        roomsWithDevices = Room.allCases.filter { (grouped[$0]?.isEmpty == false) }
        homeEnergyHistory = (0..<24).map { hour in
            generated.reduce(0.0) { acc, device in
                acc + (hour < device.powerHistory.count ? device.powerHistory[hour] : 0)
            } / 1000
        }
    }

    func devices(in room: Room) -> [Device] { devicesByRoom[room] ?? [] }

    func countOn(in room: Room) -> Int { devices(in: room).count { $0.isOn } }

    /// All devices of `kind` (cached; the device list never changes size).
    func devices(ofKind kind: ControlKind) -> [Device] { byKind[kind] ?? [] }

    /// Looks a device up by id (e.g. for `Device.groupedWith`).
    func device(id: String) -> Device? { byId[id] }

    /// Live estimated power draw of `device` in watts, derived from its current state.
    func liveWatts(_ device: Device) -> Double { DeviceGenerator.estimateWatts(device) }

    /// Live whole-home power draw in watts.
    func totalPowerWatts() -> Double {
        devices.reduce(0) { $0 + DeviceGenerator.estimateWatts($1) }
    }

    /// Devices needing attention: motion, leaks, open contacts/doors, triggered alarm, obstruction.
    func alerts() -> [Device] { devices.filter(isAlert) }

    private func isAlert(_ device: Device) -> Bool {
        switch device.controlKind {
        case .cameraFeed: return device.motionDetected && !device.privacyMode
        case .sensorReadonly: return alertSensorValues.contains(device.sensorValue)
        case .securityPanel: return device.alarmState == .triggered
        case .garage: return device.obstructionDetected
        case .lock: return device.doorAjar
        default: return false
        }
    }

    // MARK: - Garage

    /// Starts opening the garage door; the motion loop animates `doorPosition` then settles to open.
    func openGarage(_ device: Device) {
        if device.garageState == .open && device.doorPosition >= 1 { return }
        device.garageOpening = true
        device.garageState = .moving
        logGarage(device, "Opened", "App · You")
    }

    /// Starts closing the garage door; reverses to open if `obstructionDetected` is set.
    func closeGarage(_ device: Device) {
        if device.garageState == .closed && device.doorPosition <= 0 { return }
        device.garageOpening = false
        device.garageState = .moving
        logGarage(device, "Closed", "App · You")
    }

    private func logGarage(_ device: Device, _ label: String, _ detail: String) {
        device.garageActivity = Array(
            ([ActivityEvent(label: label, detail: detail, minutesAgo: 0)] + device.garageActivity).prefix(maxLog)
        )
    }

    // MARK: - Locks

    /// Locks/unlocks and records the change in `lockActivity`.
    func setLocked(_ device: Device, _ locked: Bool, detail: String = "App · You") {
        device.lockState = locked ? .locked : .unlocked
        if locked { device.doorAjar = false }
        unlockedSeconds.removeValue(forKey: device.id)
        logLock(device, locked ? "Locked" : "Unlocked", detail)
    }

    private func logLock(_ device: Device, _ label: String, _ detail: String) {
        device.lockActivity = Array(
            ([ActivityEvent(label: label, detail: detail, minutesAgo: 0)] + device.lockActivity).prefix(maxLog)
        )
    }

    // MARK: - Media

    /// Skips to the next (or a random, when shuffling) track; grouped speakers follow.
    func nextTrack(_ device: Device) {
        loadTrack(device, index: nextTrackIndex(device), propagate: true)
    }

    /// Restarts the track if more than 5 s in, otherwise goes to the previous one; peers follow.
    func previousTrack(_ device: Device) {
        if device.trackProgress * Double(device.trackDurationSec) > 5 {
            device.trackProgress = 0
            return
        }
        loadTrack(device, index: trackIndex(of: device) - 1, propagate: true)
    }

    private func trackIndex(of device: Device) -> Int {
        max(DeviceGenerator.tracks.firstIndex { $0.title == device.trackTitle } ?? 0, 0)
    }

    private func nextTrackIndex(_ device: Device) -> Int {
        let current = trackIndex(of: device)
        guard device.shuffle else { return current + 1 }
        return current + 1 + simRandom.nextInt(0, DeviceGenerator.tracks.count - 1)
    }

    private func loadTrack(_ device: Device, index: Int, propagate: Bool) {
        DeviceGenerator.applyTrack(device, index: index)
        guard propagate else { return }
        for id in device.groupedWith {
            guard let peer = byId[id] else { continue }
            DeviceGenerator.applyTrack(peer, index: index)
            peer.isPlaying = device.isPlaying
        }
    }

    // MARK: - Sprinklers

    /// Starts/stops zone `index` (0-based) and keeps `activeZones` (1-based numbers) in sync.
    func setZoneRunning(_ device: Device, index: Int, running: Bool) {
        guard device.sprinklerZones.indices.contains(index) else { return }
        let zone = device.sprinklerZones[index]
        if zone.running != running { zone.progress = 0 }
        zone.running = running
        if !running && !device.sprinklerZones.contains(where: { $0.running }) {
            device.sprinklerRunAll = false
        }
        syncActiveZones(device)
    }

    /// Runs every zone in sequence (true) or stops all zones (false).
    func runAllZones(_ device: Device, _ run: Bool) {
        for zone in device.sprinklerZones {
            zone.running = false
            zone.progress = 0
        }
        device.sprinklerRunAll = run && !device.sprinklerZones.isEmpty
        if device.sprinklerRunAll { device.sprinklerZones[0].running = true }
        syncActiveZones(device)
    }

    private func syncActiveZones(_ device: Device) {
        let zones = device.sprinklerZones
        let set = Set(zones.indices.filter { zones[$0].running }.map { $0 + 1 })
        if set != device.activeZones { device.activeZones = set }
        syncedZones[device.id] = set
    }

    // MARK: - Security

    /// Arms the panel toward `target` through an exit countdown (`.arming`, `exitCountdownSeconds`
    /// from `exitDelaySeconds`). `.disarmed` / `.triggered` apply immediately.
    func armSecurity(_ device: Device, _ target: AlarmState) {
        switch target {
        case .arming:
            return
        case .disarmed, .triggered:
            device.armingTarget = nil
            device.exitCountdownSeconds = 0
            device.sirenOn = target == .triggered
            device.alarmState = target
            armingMillis.removeValue(forKey: device.id)
        default:
            device.sirenOn = false
            armingMillis.removeValue(forKey: device.id)
            if device.exitDelaySeconds <= 0 {
                device.armingTarget = nil
                device.exitCountdownSeconds = 0
                device.alarmState = target
            } else {
                device.armingTarget = target
                device.exitCountdownSeconds = device.exitDelaySeconds
                device.alarmState = .arming
            }
        }
    }

    // MARK: - Scenes

    /// Applies a whole-home scene, changing many devices at once.
    func apply(scene: HomeScene) {
        activeScene = scene
        switch scene {
        case .morning: applyMorning()
        case .away: applyAway()
        case .movie: applyMovie()
        case .bedtime: applyBedtime()
        }
    }

    private func applyMorning() {
        for d in devices(ofKind: .dimmer) {
            if d.type == .outdoorLight {
                d.isOn = false
            } else if morningRooms.contains(d.room) {
                setWhiteLight(d, level: 0.8, kelvin: 4000, scene: "Focus")
            }
        }
        for d in devices(ofKind: .blindsSlider) { d.position = 1 }
        for d in devices(ofKind: .thermostatDial) where d.type == .thermostat {
            d.isOn = true
            d.hvacMode = .auto
            d.ecoEnabled = false
            d.targetTempF = 71
            DeviceGenerator.updateClimateFlags(d)
        }
        for d in devices(ofKind: .waterHeaterDial) where d.type == .waterHeater {
            d.waterHeaterMode = .performance
        }
        for d in devices(ofKind: .securityPanel) { armSecurity(d, .disarmed) }
        for d in devices(ofKind: .mediaPlayer) where d.room == .kitchen && d.type == .speaker {
            d.isOn = true
            d.isPlaying = true
            d.mediaSource = .streaming
            d.volume = 0.3
        }
    }

    private func applyAway() {
        for d in devices(ofKind: .dimmer) {
            d.isOn = false
            d.activeScene = ""
            if d.type == .outdoorLight { d.motionActivated = true }
        }
        for d in devices(ofKind: .mediaPlayer) {
            d.isPlaying = false
            d.isOn = false
        }
        for d in devices(ofKind: .fanSpeed) where d.type != .airPurifier {
            d.isOn = false
            d.fanSpeed = 0
        }
        for d in devices(ofKind: .thermostatDial) {
            if d.hvacMode != .off { d.hvacMode = .eco }
            d.ecoEnabled = true
            DeviceGenerator.updateClimateFlags(d)
        }
        for d in devices(ofKind: .lock) where d.lockState != .locked {
            setLocked(d, true, detail: "Scene · Away")
        }
        for d in devices(ofKind: .garage) { closeGarage(d) }
        for d in devices(ofKind: .securityPanel) { armSecurity(d, .armedAway) }
        for d in devices(ofKind: .robotVacuum) {
            if d.vacuumState == .docked && !d.binFull && d.batteryPercent > 30 {
                d.cleaningProgress = 0
                d.vacuumState = .cleaning
            }
        }
        for d in devices(ofKind: .cameraFeed) {
            d.privacyMode = false
            d.isRecording = true
        }
        for d in devices(ofKind: .waterHeaterDial) where d.type == .waterHeater {
            d.waterHeaterMode = .eco
        }
    }

    private func applyMovie() {
        for d in devices(ofKind: .dimmer) {
            if d.room == .livingRoom && d.supportsColor && d.type == .lightStrip {
                d.isOn = true
                d.brightness = 0.35
                d.lightColorMode = .color
                d.hue = 265
                d.saturation = 0.9
                d.activeScene = "Relax"
            } else if d.room == .livingRoom {
                setWhiteLight(d, level: 0.12, kelvin: 2200, scene: "Relax")
            } else if d.type == .wallSconce && d.isOn {
                setWhiteLight(d, level: 0.1, kelvin: 2200, scene: "Night")
            }
        }
        for d in devices(ofKind: .blindsSlider) where d.room == .livingRoom { d.position = 0 }
        for d in devices(ofKind: .mediaPlayer) where d.room == .livingRoom {
            if d.type == .tv || d.type == .soundbar {
                d.isOn = true
                d.isPlaying = true
                d.muted = false
                d.mediaSource = .tvInput
                d.volume = d.type == .tv ? 0.45 : 0.5
            } else {
                d.isPlaying = false
            }
        }
        for d in devices(ofKind: .fanSpeed) where d.room == .livingRoom && d.type == .ceilingFan {
            d.isOn = true
            d.fanSpeed = 1
        }
    }

    private func applyBedtime() {
        for d in devices(ofKind: .dimmer) {
            if d.type == .wallSconce && d.room == .hallway {
                setWhiteLight(d, level: 0.08, kelvin: 2200, scene: "Night")
            } else {
                d.isOn = false
                d.activeScene = ""
                if d.type == .outdoorLight { d.motionActivated = true }
            }
        }
        for d in devices(ofKind: .mediaPlayer) {
            d.isPlaying = false
            d.isOn = false
        }
        for d in devices(ofKind: .blindsSlider) { d.position = 0 }
        for d in devices(ofKind: .lock) where d.lockState != .locked {
            setLocked(d, true, detail: "Scene · Bedtime")
        }
        for d in devices(ofKind: .garage) { closeGarage(d) }
        for d in devices(ofKind: .securityPanel) { armSecurity(d, .armedNight) }
        for d in devices(ofKind: .thermostatDial) where d.hvacMode != .off {
            d.hvacMode = .auto
            d.targetTempF = 67
            DeviceGenerator.updateClimateFlags(d)
        }
        for d in devices(ofKind: .fanSpeed) {
            if d.type == .ceilingFan && d.room != .livingRoom {
                d.isOn = true
                d.fanSpeed = 1
                d.fanTimerMinutes = 60
            } else if d.type == .airPurifier {
                d.isOn = true
                d.fanSpeed = 1
            }
        }
        for d in devices(ofKind: .applianceCycle) {
            if d.type == .dishwasher && d.applianceMode != .running {
                d.isOn = true
                d.program = "Eco"
                d.cycleTotalMinutes = 150
                d.cycleProgress = 0
                d.applianceMode = .running
            }
        }
    }

    private func setWhiteLight(_ device: Device, level: Double, kelvin: Int, scene: String) {
        device.isOn = true
        device.brightness = level
        device.colorTempK = kelvin
        device.lightColorMode = .white
        device.activeScene = scene  // the Device's light scene, not the repository's HomeScene
    }

    // MARK: - Simulation

    private var simRandom = SeededRandom(seed: UInt64(Date().timeIntervalSince1970 * 1000))
    private var unlockedSeconds: [String: Double] = [:]
    private var garageOpenSeconds: [String: Double] = [:]
    private var armingMillis: [String: Int] = [:]
    private var evKwhRemainder: [String: Double] = [:]
    private var syncedZones: [String: Set<Int>] = [:]
    private var simulationStarted = false

    /// Keeps the house alive: a fast (~120 ms) motion loop for devices that are animating (garage
    /// doors, vacuums, media progress, EV sessions, appliance cycles, sprinkler zones, arming
    /// countdowns) plus a slow ambient loop drifting temperatures, sensors and histories.
    func startAmbientSimulation() {
        guard !simulationStarted else { return }
        simulationStarted = true
        Task { await self.runMotionLoop() }
        Task { await self.runSlowLoop() }
    }

    private func runMotionLoop() async {
        let garages = devices(ofKind: .garage)
        let vacuums = devices(ofKind: .robotVacuum)
        let media = devices(ofKind: .mediaPlayer)
        let chargers = devices(ofKind: .evCharger).filter { $0.type == .evCharger }
        let appliances = devices(ofKind: .applianceCycle).filter { $0.type != .fridge }
        let sprinklers = devices(ofKind: .sprinklerZones)
        let panels = devices(ofKind: .securityPanel)
        var tick = 0
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(motionTickMs))
            } catch {
                return
            }
            tick += 1
            let simMinute = tick % simMinuteTicks == 0
            // Visibly moving things step every tick.
            for d in garages { stepGarage(d) }
            for d in vacuums { stepVacuum(d, simMinute) }
            // Everything else only feeds numbers and progress bars, so these run `batchTicks` steps
            // back to back once per batch (same maths, one UI update per second instead of eight).
            if tick % batchTicks == 0 {
                for step in (tick - batchTicks + 1)...tick {
                    let batchMinute = step % simMinuteTicks == 0
                    for d in media { stepMedia(d) }
                    for d in chargers { stepCharger(d) }
                    for d in appliances { stepAppliance(d, batchMinute) }
                    for d in sprinklers { stepSprinkler(d, batchMinute) }
                    for d in panels { stepPanel(d) }
                }
            }
        }
    }

    private func stepGarage(_ d: Device) {
        let target: Double
        switch d.garageState {
        case .moving: target = d.garageOpening ? 1 : 0
        case .open: target = 1
        case .closed: target = 0
        }
        let pos = d.doorPosition
        if pos != target, d.garageState == .moving, !d.garageOpening, d.obstructionDetected, pos < 0.6 {
            d.garageOpening = true
            logGarage(d, "Reversed", "Obstruction detected")
            return
        }
        let next = target > pos ? min(target, pos + garageStep) : max(target, pos - garageStep)
        if next != pos { d.doorPosition = next }
        if next == target, d.garageState == .moving {
            d.garageState = target == 1 ? .open : .closed
        }
    }

    private func stepVacuum(_ d: Device, _ simMinute: Bool) {
        switch d.vacuumState {
        case .cleaning:
            if d.cleaningProgress >= 1 {
                d.vacuumState = .returning
                return
            }
            let aim = lawnmowerPoint(d.cleaningProgress)
            // Glide onto the path first (e.g. when leaving the dock).
            guard moveRobot(d, aim.0, aim.1, vacuumStep * 1.5) else { return }
            if d.cleaningProgress == 0 {
                d.cleanedAreaSqFt = 0
                d.cleaningMinutes = 0
            }
            let progress = min(1, d.cleaningProgress + pathSpeed)
            d.cleaningProgress = progress
            let point = lawnmowerPoint(progress)
            d.robotX = point.0
            d.robotY = point.1
            if simMinute {
                d.cleaningMinutes += 1
                d.cleanedAreaSqFt += 10 + d.suction.rawValue * 2
            }
        case .returning:
            if moveRobot(d, dockX, dockY, vacuumStep) {
                d.vacuumState = .docked
                d.cleaningProgress = 0
                if simRandom.chance(0.25) { d.binFull = true }
            }
        case .docked:
            if d.robotX != dockX || d.robotY != dockY {
                _ = moveRobot(d, dockX, dockY, vacuumStep)
            }
        case .paused:
            break
        }
    }

    /// Moves the robot toward (x, y) by at most `step`; returns true once it has arrived.
    private func moveRobot(_ d: Device, _ x: Double, _ y: Double, _ step: Double) -> Bool {
        let dx = x - d.robotX
        let dy = y - d.robotY
        let dist = (dx * dx + dy * dy).squareRoot()
        if dist <= step {
            if dist > 0 {
                d.robotX = x
                d.robotY = y
            }
            return true
        }
        d.robotX += dx / dist * step
        d.robotY += dy / dist * step
        return false
    }

    /// Point at fraction `t` along a boustrophedon path from bottom-left to the top of the map.
    private func lawnmowerPoint(_ t: Double) -> (Double, Double) {
        let rowGap = (pathBottom - pathTop) / Double(pathRows - 1)
        let width = pathRight - pathLeft
        let total = Double(pathRows) * width + Double(pathRows - 1) * rowGap
        var d = min(max(t, 0), 1) * total
        for row in 0..<pathRows {
            let y = pathBottom - Double(row) * rowGap
            let leftToRight = row % 2 == 0
            if d <= width || row == pathRows - 1 {
                let f = min(max(d / width, 0), 1)
                return (leftToRight ? pathLeft + f * width : pathRight - f * width, y)
            }
            d -= width
            if d <= rowGap {
                return (leftToRight ? pathRight : pathLeft, y - d)
            }
            d -= rowGap
        }
        return (pathLeft, pathTop)
    }

    private func stepMedia(_ d: Device) {
        guard d.isOn, d.isPlaying, d.trackDurationSec > 0 else { return }
        let next = d.trackProgress + motionTickSeconds / Double(d.trackDurationSec)
        if next < 1 {
            d.trackProgress = next
        } else if d.repeatMode == .one {
            d.trackProgress = 0
        } else {
            loadTrack(d, index: nextTrackIndex(d), propagate: false)
        }
    }

    private func stepCharger(_ d: Device) {
        guard d.isCharging else { return }
        if !d.plugConnected { d.plugConnected = true }
        if d.chargePercent >= min(d.chargeLimitPercent, 100) {
            d.isCharging = false
            return
        }
        let rate = Double(min(max(d.chargeAmps, 8), 48)) * 0.24
        if d.chargeRateKw != rate { d.chargeRateKw = rate }
        let kwh = rate * motionTickSeconds / 3600 * evTimeScale
        d.sessionKwh += kwh
        d.sessionCost = d.sessionKwh * (d.offPeakScheduling ? offPeakRate : peakRate)
        let acc = (evKwhRemainder[d.id] ?? 0) + kwh
        let perPercent = evBatteryKwh / 100
        if acc >= perPercent {
            d.chargePercent = min(100, d.chargePercent + 1)
            evKwhRemainder[d.id] = acc - perPercent
        } else {
            evKwhRemainder[d.id] = acc
        }
    }

    private func stepAppliance(_ d: Device, _ simMinute: Bool) {
        let heats = d.type == .oven || d.type == .grill
        if d.applianceMode != .running {
            if heats, d.applianceTempF > ambientF {
                d.applianceTempF = max(ambientF, d.applianceTempF - 1.2)
            }
            return
        }
        if d.delayStartMinutes > 0 {
            if simMinute { d.delayStartMinutes -= 1 }
            return
        }
        if heats { stepHeatingAppliance(d, simMinute) } else { stepCycle(d) }
    }

    private func stepHeatingAppliance(_ d: Device, _ simMinute: Bool) {
        let target = d.targetApplianceTempF
        let temp = max(d.applianceTempF, ambientF)
        let newTemp = temp < target ? min(target, temp + 2.5) : max(target, temp - 1.5)
        if newTemp != d.applianceTempF { d.applianceTempF = newTemp }
        let preheat = min(max((newTemp - ambientF) / max(target - ambientF, 1), 0), 1)
        if preheat != d.cycleProgress { d.cycleProgress = preheat }
        if d.probeTempF < probeMaxF, newTemp > 150 {
            d.probeTempF = min(probeMaxF, max(d.probeTempF, ambientF) + 0.05)
        }
        if simMinute, preheat >= 1, d.timerMinutes > 0 {
            d.timerMinutes -= 1
            d.minutesRemaining = d.timerMinutes
            if d.timerMinutes == 0 { d.applianceMode = .done }
        }
    }

    private func stepCycle(_ d: Device) {
        let microwave = d.type == .microwave
        if d.cycleProgress >= 1 || d.cycleProgress == 0 {
            d.cycleProgress = 0
            if microwave, d.timerMinutes > 0 { d.cycleTotalMinutes = d.timerMinutes }
        }
        if d.cycleTotalMinutes <= 0 { d.cycleTotalMinutes = defaultCycleMinutes(d.type) }
        let progress = min(1, d.cycleProgress + 1 / Double(d.cycleTotalMinutes * simMinuteTicks))
        d.cycleProgress = progress
        let remaining = Int((Double(d.cycleTotalMinutes) * (1 - progress)).rounded(.up))
        if remaining != d.minutesRemaining {
            d.minutesRemaining = remaining
            if microwave { d.timerMinutes = remaining }
        }
        if progress >= 1 {
            d.applianceMode = .done
            d.minutesRemaining = 0
            if d.type == .washingMachine || d.type == .dishwasher {
                d.detergentPercent = max(0, d.detergentPercent - simRandom.nextInt(3, 7))
            }
        }
    }

    private func defaultCycleMinutes(_ type: DeviceType) -> Int {
        switch type {
        case .washingMachine: return 55
        case .dryer: return 60
        case .dishwasher: return 110
        case .microwave: return 2
        default: return 45
        }
    }

    private func stepSprinkler(_ d: Device, _ simMinute: Bool) {
        let zones = d.sprinklerZones
        guard !zones.isEmpty else { return }
        if let synced = syncedZones[d.id] {
            if d.activeZones != synced {
                // activeZones was edited directly (1-based numbers): mirror it into the zone objects.
                for (i, zone) in zones.enumerated() {
                    let want = d.activeZones.contains(i + 1)
                    if zone.running != want {
                        zone.running = want
                        zone.progress = 0
                    }
                }
                syncedZones[d.id] = d.activeZones
            }
        } else {
            syncActiveZones(d)
        }
        var changed = false
        var watering = false
        for i in zones.indices {
            let zone = zones[i]
            guard zone.running else { continue }
            watering = true
            let progress = zone.progress + 1 / Double(max(zone.durationMinutes, 1) * simMinuteTicks)
            if progress < 1 {
                zone.progress = progress
                continue
            }
            zone.running = false
            zone.progress = 0
            changed = true
            if d.sprinklerRunAll {
                if zones.indices.contains(i + 1) {
                    zones[i + 1].running = true
                    zones[i + 1].progress = 0
                } else {
                    d.sprinklerRunAll = false
                }
            }
        }
        if changed { syncActiveZones(d) }
        if simMinute, watering {
            if !d.waterUsageHistory.isEmpty {
                d.waterUsageHistory = withLast(
                    d.waterUsageHistory, (d.waterUsageHistory.last ?? 0) + gallonsPerMinute
                )
            }
            if d.soilMoisturePercent < 95 { d.soilMoisturePercent += 1 }
        }
    }

    private func stepPanel(_ d: Device) {
        guard d.alarmState == .arming else { return }
        let ms = (armingMillis[d.id] ?? 0) + motionTickMs
        if d.exitCountdownSeconds > 0, ms >= 1000 {
            d.exitCountdownSeconds -= 1
            armingMillis[d.id] = ms - 1000
        } else {
            armingMillis[d.id] = ms
        }
        if d.exitCountdownSeconds <= 0 {
            d.alarmState = d.armingTarget ?? .armedAway
            d.armingTarget = nil
            d.exitCountdownSeconds = 0
            armingMillis.removeValue(forKey: d.id)
        }
    }

    private func runSlowLoop() async {
        let climate = devices(ofKind: .thermostatDial)
        let heaters = devices(ofKind: .waterHeaterDial)
        let fans = devices(ofKind: .fanSpeed)
        let locks = devices(ofKind: .lock)
        let garages = devices(ofKind: .garage)
        let vacuums = devices(ofKind: .robotVacuum)
        let sensors = devices(ofKind: .sensorReadonly)
        let sprinklers = devices(ofKind: .sprinklerZones)
        var tick = 0
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(slowTickMs))
            } catch {
                return
            }
            tick += 1
            driftRandomDevice()
            for d in climate { stepClimate(d) }
            for d in heaters { stepWaterHeater(d) }
            for d in fans { stepAirAndHumidity(d) }
            for d in locks { stepAutoLock(d) }
            for d in garages { stepAutoClose(d) }
            for d in vacuums { stepVacuumBattery(d) }
            if tick % historyTicks == 0 { refreshHistories(climate: climate, sensors: sensors) }
            if tick % ticksPerMinute == 0 {
                minuteTick(fans: fans, sensors: sensors, sprinklers: sprinklers)
            }
            if tick % (ticksPerMinute * 60) == 0 { shiftHour() }
        }
    }

    /// The original ambient drift: nudge one random powered-on device.
    private func driftRandomDevice() {
        let pool = devices.filter { $0.isOn }
        guard !pool.isEmpty else { return }
        let device = simRandom.pick(pool)
        switch device.controlKind {
        case .thermostatDial:
            device.outdoorTempF = min(max(device.outdoorTempF + (simRandom.nextDouble() - 0.5) * 0.6, -10), 115)
        case .cameraFeed:
            device.cameraSeed = simRandom.nextInt(0, 9999)
            let motion = !device.privacyMode
                && simRandom.chance(0.08 * (0.5 + device.motionSensitivity))
            if motion && !device.motionDetected {
                let label = device.type == .indoorCamera ? "Motion" : "Person detected"
                device.cameraEvents = Array(
                    ([CameraEvent(label: label, minutesAgo: 0, seed: simRandom.nextInt(0, 9999))]
                        + device.cameraEvents).prefix(maxLog)
                )
            }
            device.motionDetected = motion
        case .toggle:
            device.powerDrawWatts = min(max(device.powerDrawWatts + (simRandom.nextDouble() - 0.5) * 6, 2), 180)
        case .sensorReadonly:
            stepSensorEvent(device)
        case .securityPanel:
            if device.alarmState == .disarmed, !device.securityZones.isEmpty {
                let zone = simRandom.pick(device.securityZones)
                zone.isOpen = zone.isOpen ? simRandom.chance(0.3) : simRandom.chance(0.15)
            }
        default:
            break
        }
    }

    private func stepSensorEvent(_ d: Device) {
        switch d.type {
        case .motionSensor:
            let motion = simRandom.chance(0.25 * (0.5 + d.sensitivity))
            d.sensorValue = motion ? "Motion detected" : "Clear"
            if motion {
                d.lastEventMinutesAgo = 0
                if !d.sensorHistory.isEmpty {
                    d.sensorHistory = withLast(d.sensorHistory, (d.sensorHistory.last ?? 0) + 1)
                }
            }
        case .contactSensor:
            if simRandom.chance(0.3) {
                let opening = d.sensorValue != "Open"
                d.sensorValue = opening ? "Open" : "Closed"
                d.lastEventMinutesAgo = 0
                if opening, !d.sensorHistory.isEmpty {
                    d.sensorHistory = withLast(d.sensorHistory, (d.sensorHistory.last ?? 0) + 1)
                }
            }
        default:
            break
        }
    }

    private func stepClimate(_ d: Device) {
        let step: Double
        if d.isHeating {
            step = 0.12
        } else if d.isCooling {
            step = -0.12
        } else {
            step = (d.outdoorTempF - d.currentTempF) * 0.004
        }
        if abs(step) > 0.001 { d.currentTempF = min(max(d.currentTempF + step, 50), 95) }
        DeviceGenerator.updateClimateFlags(d)
    }

    private func stepWaterHeater(_ d: Device) {
        guard d.isOn else {
            d.isHeating = false
            d.boostActive = false
            return
        }
        let target = d.waterHeaterMode == .vacation ? d.targetTempF - 20 : d.targetTempF
        let heating = d.boostActive || d.currentTempF < target - 1
        d.isHeating = heating
        if heating {
            let rate: Double
            if d.boostActive {
                rate = 0.9
            } else if d.waterHeaterMode == .performance {
                rate = 0.5
            } else {
                rate = 0.3
            }
            d.currentTempF = min(target + (d.boostActive ? 5 : 0), d.currentTempF + rate)
            if d.hotWaterPercent < 100 {
                d.hotWaterPercent = min(100, d.hotWaterPercent + (d.boostActive ? 3 : 1))
            }
        } else {
            d.currentTempF -= 0.03
        }
        if d.boostActive, d.hotWaterPercent >= 100, d.currentTempF >= target { d.boostActive = false }
        if d.type == .waterHeater, simRandom.chance(0.03) {
            // Someone runs a shower.
            d.hotWaterPercent = max(10, d.hotWaterPercent - 15)
            d.currentTempF -= 4
        }
    }

    private func stepAirAndHumidity(_ d: Device) {
        switch d.type {
        case .airPurifier:
            let target = d.isOn ? 6 + (4 - min(max(d.fanSpeed, 0), 4)) * 4 : 38
            if simRandom.chance(0.5) {
                d.airQualityIndex += min(max(target - d.airQualityIndex, -1), 1)
            }
        case .bathroomHumidity:
            let target = d.isOn && d.fanSpeed > 0 ? d.humidityTarget : 62
            d.humidityPercent += min(max(target - d.humidityPercent, -1), 1)
        default:
            break
        }
    }

    private func stepAutoLock(_ d: Device) {
        if d.lockState == .unlocked, d.doorAjar, simRandom.chance(0.1) {
            d.doorAjar = false
            logLock(d, "Door closed", "Contact sensor")
        }
        if d.lockState == .locked || !d.autoLockEnabled || d.doorAjar {
            unlockedSeconds.removeValue(forKey: d.id)
            return
        }
        let seconds = (unlockedSeconds[d.id] ?? 0) + slowTickSeconds
        if seconds >= Double(d.autoLockSeconds) {
            unlockedSeconds.removeValue(forKey: d.id)
            d.lockState = .locked
            logLock(d, "Auto-locked", "After \(d.autoLockSeconds) s")
        } else {
            unlockedSeconds[d.id] = seconds
        }
    }

    private func stepAutoClose(_ d: Device) {
        if d.obstructionDetected, d.garageState != .moving, simRandom.chance(0.04) {
            d.obstructionDetected = false
        }
        if d.garageState != .open || d.autoCloseMinutes <= 0 {
            garageOpenSeconds.removeValue(forKey: d.id)
            return
        }
        let seconds = (garageOpenSeconds[d.id] ?? 0) + slowTickSeconds
        if seconds >= Double(d.autoCloseMinutes) * 60 {
            garageOpenSeconds.removeValue(forKey: d.id)
            d.garageOpening = false
            d.garageState = .moving
            logGarage(d, "Auto-closed", "After \(d.autoCloseMinutes) min")
        } else {
            garageOpenSeconds[d.id] = seconds
        }
    }

    private func stepVacuumBattery(_ d: Device) {
        switch d.vacuumState {
        case .cleaning:
            d.batteryPercent = max(5, d.batteryPercent - 1)
            if d.batteryPercent <= 12 { d.vacuumState = .returning }
        case .docked:
            if d.batteryPercent < 100 { d.batteryPercent += 1 }
        default:
            break
        }
    }

    private func refreshHistories(climate: [Device], sensors: [Device]) {
        for d in climate {
            if let last = d.tempHistory.last, abs(last - d.currentTempF) > 0.05 {
                d.tempHistory = withLast(d.tempHistory, d.currentTempF)
            }
        }
        for d in sensors where d.type == .climateSensor {
            let temp = min(max(d.sensorNumeric + (simRandom.nextDouble() - 0.5) * 0.3, 55), 90)
            d.sensorNumeric = temp
            d.currentTempF = temp
            if simRandom.chance(0.3) {
                d.humidityPercent = min(max(d.humidityPercent + simRandom.nextInt(-1, 2), 20), 80)
            }
            d.sensorValue = "\(Int(temp))°F · \(d.humidityPercent)% humidity"
            if !d.sensorHistory.isEmpty { d.sensorHistory = withLast(d.sensorHistory, temp) }
            d.tempHistory = d.sensorHistory
        }
        var total = 0.0
        for d in devices {
            let watts = DeviceGenerator.estimateWatts(d)
            total += watts
            if d.controlKind != .toggle, abs(d.powerDrawWatts - watts) > 0.5 {
                d.powerDrawWatts = watts
            }
            let live = d.controlKind == .toggle && d.isOn ? d.powerDrawWatts : watts
            if let last = d.powerHistory.last, abs(last - live) > 0.5 {
                d.powerHistory = withLast(d.powerHistory, live)
            }
        }
        if !homeEnergyHistory.isEmpty {
            homeEnergyHistory = withLast(homeEnergyHistory, total / 1000)
        }
    }

    private func minuteTick(fans: [Device], sensors: [Device], sprinklers: [Device]) {
        for d in fans where d.fanTimerMinutes > 0 {
            d.fanTimerMinutes -= 1
            if d.fanTimerMinutes == 0 {
                d.isOn = false
                d.fanSpeed = 0
            }
        }
        for d in sensors where d.lastEventMinutesAgo < 100_000 { d.lastEventMinutesAgo += 1 }
        for d in sprinklers {
            if !d.sprinklerZones.contains(where: { $0.running }),
               d.soilMoisturePercent > 8,
               simRandom.chance(0.3) {
                d.soilMoisturePercent -= 1
            }
        }
        for d in devices {
            let watts = DeviceGenerator.estimateWatts(d)
            if watts > 0 { d.energyTodayKwh += watts / 60_000 }
        }
    }

    /// Once per real hour: roll every 24 h history forward by one sample.
    private func shiftHour() {
        for d in devices {
            d.powerHistory = shifted(d.powerHistory)
            if d.controlKind == .thermostatDial || d.controlKind == .waterHeaterDial {
                d.tempHistory = shifted(d.tempHistory)
            }
            if d.controlKind == .sensorReadonly {
                let rolled = shifted(d.sensorHistory)
                // Event-count sensors start the new hour at zero; level sensors carry the reading over.
                d.sensorHistory = (d.type == .motionSensor || d.type == .contactSensor)
                    ? withLast(rolled, 0)
                    : rolled
                if d.type == .climateSensor { d.tempHistory = d.sensorHistory }
            }
        }
        homeEnergyHistory = shifted(homeEnergyHistory)
    }
}

private func withLast(_ values: [Double], _ value: Double) -> [Double] {
    guard !values.isEmpty else { return values }
    var copy = values
    copy[copy.count - 1] = value
    return copy
}

/// Drops the oldest sample and repeats the newest one as the start of a new period.
private func shifted(_ values: [Double]) -> [Double] {
    guard let last = values.last else { return values }
    return Array(values.dropFirst()) + [last]
}

private let alertSensorValues: Set<String> = [
    "Motion detected", "Open", "Leak detected", "Smoke detected", "CO detected",
]

private let morningRooms: Set<Room> = [
    .kitchen, .livingRoom, .diningRoom, .primaryBedroom, .hallway, .entryway,
]

private let maxLog = 12

private let motionTickMs = 120
private let motionTickSeconds = 0.12

/// One simulated "minute" for cycles, timers and zones ≈ 1.44 s of real time.
private let simMinuteTicks = 12
private let batchTicks = 8  // ~1 s of motion ticks

private let slowTickMs = 2500
private let slowTickSeconds = 2.5
private let ticksPerMinute = 24
private let historyTicks = 4

private let garageStep = 0.12 / 9  // ~9 s full travel

private let dockX = 0.1
private let dockY = 0.9
private let pathLeft = 0.1
private let pathRight = 0.9
private let pathTop = 0.15
private let pathBottom = 0.8
private let pathRows = 6
private let pathSpeed = 0.12 / 100  // full clean ≈ 100 s
private let vacuumStep = 0.008

private let evTimeScale = 60.0
private let evBatteryKwh = 75.0
private let offPeakRate = 0.14
private let peakRate = 0.28

private let ambientF = 70.0
private let probeMaxF = 165.0
private let gallonsPerMinute = 2.5
