import SwiftUI

/// The device NexHome "discovers" during setup.
private struct DiscoveredDevice: Equatable {
    let model: String
    let serial: String
    let firmware: String
    let signal: Int

    init(type: DeviceType) {
        let letter = type.label.first.map(String.init) ?? "N"
        model = "\(type.setupBrand) \(type.label) \(letter)\(Int.random(in: 2...9))"
        serial = "NX-" + String(format: "%04X", Int.random(in: 0x1000...0xFFFF))
        firmware = "\(Int.random(in: 2...5)).\(Int.random(in: 0...9)).\(Int.random(in: 0...20))"
        signal = Int.random(in: 3...4)
    }
}

/// Add a device: choose what to set up → NexHome searches for it → found → pairing → name and
/// room → done. The search and pairing are simulated with short random delays.
struct AddDeviceWizard: View {
    /// Room to suggest, e.g. when adding from an empty room.
    var preferredRoom: Room?

    @Environment(DeviceRepository.self) private var repository
    @Environment(HomeSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: Equatable { case choose, searching, found, pairing, naming, done }

    @State private var step: Step = .choose
    @State private var type: DeviceType = .lamp
    @State private var discovered: DiscoveredDevice?
    @State private var query = ""
    @State private var category: SetupCategory?
    @State private var name = ""
    @State private var room: Room = .livingRoom
    @State private var pairingDone = 0
    @State private var added: Device?
    @State private var work: Task<Void, Never>?

    private var accent: Color { deviceAccent(type) }

    var body: some View {
        NavigationStack {
            ZStack {
                switch step {
                case .choose: chooseStep.transition(.stepTransition)
                case .searching: searchingStep.transition(.stepTransition)
                case .found: foundStep.transition(.stepTransition)
                case .pairing: pairingStep.transition(.stepTransition)
                case .naming: namingStep.transition(.stepTransition)
                case .done: doneStep.transition(.stepTransition)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.12), value: step)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step == .found || step == .naming || step == .searching {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.backward") { restart() }
                    }
                }
                if step != .done {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel", role: .cancel) {
                            work?.cancel()
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground {
            AmbientBackdrop(theme: settings.theme, customImage: settings.customImage)
        }
        .interactiveDismissDisabled(step == .pairing)
        .onDisappear { work?.cancel() }
    }

    private var title: String {
        switch step {
        case .choose: return "Add Device"
        case .searching: return "Searching"
        case .found: return "Device Found"
        case .pairing: return "Setting Up"
        case .naming: return "Name & Room"
        case .done: return "All Set"
        }
    }

    // MARK: - 1. Choose

    private var chooseStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What would you like to set up?")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Pick a device and NexHome will look for it nearby.")
                        .font(.body)
                        .foregroundStyle(NexColors.secondary)
                }
                .padding(.horizontal, 20)

                LiquidChipRow {
                    LiquidChip(label: "All", selected: category == nil, accent: NexColors.blue) {
                        category = nil
                    }
                    ForEach(SetupCategory.allCases) { option in
                        LiquidChip(
                            label: option.label,
                            symbol: option.symbol,
                            selected: category == option,
                            accent: NexColors.blue
                        ) {
                            category = category == option ? nil : option
                        }
                    }
                }
                .padding(.horizontal, 18)

                if query.isEmpty && category == nil {
                    typeSection("New in NexHome", DeviceType.allCases.filter(\.isSetupOnly))
                }
                ForEach(SetupCategory.allCases) { option in
                    let types = filteredTypes(in: option)
                    if !types.isEmpty && (category == nil || category == option) {
                        typeSection(option.label, types)
                    }
                }
                if !query.isEmpty && SetupCategory.allCases.allSatisfy({ filteredTypes(in: $0).isEmpty }) {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 40)
                }
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .searchable(text: $query, prompt: "Search devices")
    }

    private func filteredTypes(in option: SetupCategory) -> [DeviceType] {
        DeviceType.allCases.filter { candidate in
            candidate.setupCategory == option
                && (query.isEmpty || candidate.label.localizedCaseInsensitiveContains(query))
        }
    }

    private func typeSection(_ heading: String, _ types: [DeviceType]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScreenSectionLabel(title: heading)
                .padding(.horizontal, 24)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(types, id: \.self) { option in
                    TypeTile(type: option) { begin(option) }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 2. Searching

    private var searchingStep: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)
            ScanRadar(symbol: type.symbol, accent: accent, animated: !reduceMotion)
                .frame(width: 300, height: 300)
            VStack(spacing: 8) {
                Text("Looking for your \(type.label)…")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Make sure it's powered on and close to your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(NexColors.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ProgressView()
                Text("Scanning Wi-Fi, Bluetooth and Thread")
                    .font(.footnote)
                    .foregroundStyle(NexColors.tertiary)
            }
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setupSearching")
    }

    // MARK: - 3. Found

    private var foundStep: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            if let discovered {
                GlassPanel(shape: glassRect(32)) {
                    VStack(spacing: 16) {
                        GlassIconOrb(symbol: type.symbol, accent: accent, size: 96, glow: 1)
                            .symbolEffect(.bounce, value: step == .found)
                        VStack(spacing: 4) {
                            Text(discovered.model)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            Text("\(type.label) · \(discovered.serial)")
                                .font(.subheadline)
                                .foregroundStyle(NexColors.secondary)
                        }
                        HStack(spacing: 10) {
                            FoundFact(symbol: "wifi", title: discovered.signal == 4 ? "Excellent" : "Good", caption: "Signal")
                            FoundFact(symbol: "memorychip", title: "v\(discovered.firmware)", caption: "Firmware")
                            FoundFact(symbol: "checkmark.seal.fill", title: "Ready", caption: "Status")
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                Label("Found 1 device nearby", systemImage: "dot.radiowaves.left.and.right")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(NexColors.secondary)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    startPairing()
                } label: {
                    Text("Set Up").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .tint(accent)
                .accessibilityIdentifier("setupStart")

                Button("Search Again") { search() }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 4. Pairing

    private var pairingSteps: [String] {
        let model = discovered?.model ?? type.label
        return [
            "Connecting to \(model)",
            "Pairing securely",
            "Updating firmware to \(discovered?.firmware ?? "latest")",
            "Adding to \(settings.homeName)",
        ]
    }

    private var pairingStep: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .stroke(NexColors.track, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: Double(pairingDone) / Double(pairingSteps.count))
                    .rotation(.degrees(-90))
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                GlassIconOrb(symbol: type.symbol, accent: accent, size: 104, glow: 1)
            }
            .frame(width: 136, height: 136)
            .animation(GlassMotion.release, value: pairingDone)

            Text("Setting up \(discovered?.model ?? type.label)")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            GlassPanel(shape: glassRect(28)) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(pairingSteps.enumerated()), id: \.offset) { index, label in
                        HStack(spacing: 14) {
                            ZStack {
                                if index < pairingDone {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(NexColors.green)
                                        .transition(.scale.combined(with: .opacity))
                                } else if index == pairingDone {
                                    ProgressView()
                                } else {
                                    Image(systemName: "circle.dotted")
                                        .font(.system(size: 22))
                                        .foregroundStyle(NexColors.tertiary)
                                }
                            }
                            .frame(width: 26, height: 26)
                            Text(label)
                                .font(.subheadline.weight(index == pairingDone ? .semibold : .regular))
                                .foregroundStyle(index <= pairingDone ? NexColors.primary : NexColors.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(20)
                .animation(GlassMotion.glow, value: pairingDone)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("setupPairing")
    }

    // MARK: - 5. Name and room

    private var namingStep: some View {
        let houseRooms = repository.roomsWithDevices
        let otherRooms = Room.allCases.filter { !houseRooms.contains($0) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Where does it live?")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 4)

                GlassPanel(shape: glassRect(26)) {
                    HStack(spacing: 14) {
                        GlassIconOrb(symbol: type.symbol, accent: accent, size: 52, glow: 1)
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Name", text: $name)
                                .font(.title3.weight(.semibold))
                                .submitLabel(.done)
                                .accessibilityIdentifier("setupName")
                            Text("\(room.displayName) · \(type.label)")
                                .font(.caption)
                                .foregroundStyle(NexColors.secondary)
                        }
                        if !name.isEmpty {
                            Button {
                                name = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(NexColors.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear name")
                        }
                    }
                    .padding(16)
                }

                ScreenSectionLabel(title: "Room")
                    .padding(.horizontal, 4)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(houseRooms + (houseRooms.contains(room) ? [] : [room])) { option in
                        RoomChoice(room: option, selected: option == room, accent: accent) {
                            Haptics.tick()
                            room = option
                        }
                    }
                }

                if !otherRooms.isEmpty {
                    Menu {
                        ForEach(otherRooms) { option in
                            Button(option.displayName, systemImage: option.symbol) { room = option }
                        }
                    } label: {
                        Label("Add a New Room", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .glassControl(Capsule())
                    }
                    .buttonStyle(GlassControlButtonStyle())
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button {
                finish()
            } label: {
                Text("Add to \(settings.homeName)").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .tint(accent)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .accessibilityIdentifier("setupFinish")
        }
    }

    // MARK: - 6. Done

    private var doneStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: step == .done)
                .frame(width: 112, height: 112)
                .glassControl(Circle(), tint: NexColors.green)
            VStack(spacing: 6) {
                Text("\(added?.name ?? name) is ready")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("setupDoneTitle")
                Text("Added to \(added?.room.displayName ?? room.displayName). It's live in your home now.")
                    .font(.subheadline)
                    .foregroundStyle(NexColors.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            if let added {
                DeviceCard(device: added, showRoom: true) { router.openAfterClosingSheets(added) }
                    .frame(width: 220)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    if let added { router.openAfterClosingSheets(added) }
                    dismiss()
                } label: {
                    Text("Open Controls").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .tint(accent)

                HStack(spacing: 12) {
                    Button {
                        restart()
                    } label: {
                        Text("Set Up Another").frame(maxWidth: .infinity)
                    }
                    Button {
                        dismiss()
                    } label: {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("setupDone")
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Flow

    private func begin(_ option: DeviceType) {
        Haptics.tick()
        type = option
        room = preferredRoom ?? option.suggestedRoom
        name = ""
        search()
    }

    private func search() {
        work?.cancel()
        discovered = nil
        step = .searching
        work = Task { @MainActor in
            // A believable scan: somewhere between two and five seconds.
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2000...4800)))
            guard !Task.isCancelled else { return }
            discovered = DiscoveredDevice(type: type)
            Haptics.confirm()
            step = .found
        }
    }

    private func startPairing() {
        work?.cancel()
        pairingDone = 0
        step = .pairing
        work = Task { @MainActor in
            for _ in pairingSteps {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 700...1500)))
                guard !Task.isCancelled else { return }
                pairingDone += 1
                Haptics.tick()
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            if name.isEmpty { name = "\(room.displayName) \(type.label)" }
            step = .naming
        }
    }

    private func finish() {
        if !repository.roomsWithDevices.contains(room) { repository.addRoom(room) }
        added = repository.addDevice(name: name, type: type, room: room)
        Haptics.confirm()
        step = .done
    }

    private func restart() {
        work?.cancel()
        added = nil
        discovered = nil
        step = .choose
    }
}

// MARK: - Pieces

private extension AnyTransition {
    static var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

/// A device type in the chooser.
private struct TypeTile: View {
    let type: DeviceType
    let action: () -> Void

    var body: some View {
        let accent = deviceAccent(type)
        GlassPanel(shape: glassRect(24), action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    GlassIconOrb(symbol: type.symbol, accent: accent, size: 44, glow: 1)
                    Spacer(minLength: 0)
                    if type.isSetupOnly {
                        Text("NEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.85), in: Capsule())
                    }
                }
                Spacer(minLength: 10)
                Text(type.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(type.setupCategory.label)
                    .font(.caption)
                    .foregroundStyle(NexColors.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setupType.\(type.rawValue)")
    }
}

/// Expanding rings around the device icon while NexHome "searches".
private struct ScanRadar: View {
    let symbol: String
    let accent: Color
    let animated: Bool

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<4, id: \.self) { ring in
                    let phase = animated ? (time / 2.4 + Double(ring) / 4).truncatingRemainder(dividingBy: 1) : Double(ring) / 4
                    Circle()
                        .stroke(accent.opacity(0.55 * (1 - phase)), lineWidth: 2)
                        .frame(width: 120 + 180 * phase, height: 120 + 180 * phase)
                }
                // A slow sweep, like a radar arm.
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(
                        AngularGradient(colors: [accent.opacity(0), accent.opacity(0.7)], center: .center),
                        style: StrokeStyle(lineWidth: 60, lineCap: .butt)
                    )
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(animated ? (time * 90).truncatingRemainder(dividingBy: 360) : 0))
                    .opacity(0.35)
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 112, height: 112)
                    .glassControl(Circle(), tint: accent)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A small fact under the found device (signal, firmware, status).
private struct FoundFact: View {
    let symbol: String
    let title: String
    let caption: String

    var body: some View {
        GlassPanel(shape: glassRect(18)) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NexColors.secondary)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(NexColors.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

/// A room option in the naming step.
private struct RoomChoice: View {
    let room: Room
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: room.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? .white : NexColors.secondary)
                Text(room.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(selected ? .white : NexColors.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .glassControl(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: selected ? accent : nil)
        }
        .buttonStyle(GlassControlButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(GlassMotion.glow, value: selected)
    }
}
