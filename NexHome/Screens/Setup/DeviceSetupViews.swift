import SwiftUI

/// Category heading for a control kind in pickers and lists ("Lights", "Locks").
func kindTitle(_ kind: ControlKind) -> String {
    switch kind {
    case .dimmer: return "Lights"
    case .toggle: return "Plugs & Outlets"
    case .thermostatDial: return "Climate"
    case .lock: return "Locks & Doors"
    case .garage: return "Garage"
    case .cameraFeed: return "Cameras"
    case .blindsSlider: return "Shades"
    case .mediaPlayer: return "Media"
    case .fanSpeed: return "Fans & Air"
    case .applianceCycle: return "Appliances"
    case .robotVacuum: return "Vacuums"
    case .waterHeaterDial: return "Water & Pool Heaters"
    case .evCharger: return "Chargers & Pumps"
    case .sprinklerZones: return "Sprinklers"
    case .sensorReadonly: return "Sensors"
    case .securityPanel: return "Security"
    }
}

/// The device's icon in the Settings style, tinted with its accent.
struct DeviceSetupIcon: View {
    let type: DeviceType
    var size: CGFloat = 30

    var body: some View {
        SettingsIcon(symbol: type.symbol, accent: deviceAccent(type), size: size)
    }
}

// MARK: - Add

/// Adds a device by hand: a live preview, then name, type and room.
struct AddDeviceView: View {
    @Environment(DeviceRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: DeviceType = .lamp
    @State private var room: Room = .livingRoom
    @State private var roomChosen = false
    @FocusState private var nameFocused: Bool

    private var placeholder: String { "\(room.displayName) \(type.label)" }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    DeviceSetupIcon(type: type, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? placeholder : name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(room.displayName) · \(type.label)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)
                .animation(GlassMotion.glow, value: type)
            }

            Section("Name") {
                TextField(placeholder, text: $name)
                    .focused($nameFocused)
                    .submitLabel(.done)
            }

            Section {
                Picker("Type", selection: $type) {
                    ForEach(ControlKind.allCases, id: \.self) { kind in
                        let types = DeviceType.allCases.filter { $0.controlKind == kind }
                        if !types.isEmpty {
                            Section(kindTitle(kind)) {
                                ForEach(types, id: \.self) { option in
                                    Label(option.label, systemImage: option.symbol).tag(option)
                                }
                            }
                        }
                    }
                }
                .pickerStyle(.navigationLink)

                Picker(
                    "Room",
                    selection: Binding(get: { room }, set: { room = $0; roomChosen = true })
                ) {
                    ForEach(Room.allCases) { option in
                        Label(option.displayName, systemImage: option.symbol).tag(option)
                    }
                }
                .pickerStyle(.navigationLink)
            } footer: {
                Text("The device opens with the full controls for its type.")
            }
        }
        .navigationTitle("Add Device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    repository.addDevice(name: name, type: type, room: room)
                    Haptics.confirm()
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .onChange(of: type) { _, newType in
            // Until the owner picks a room, suggest one where this type usually lives.
            guard !roomChosen, !newType.rooms.contains(room),
                  let suggested = Room.allCases.first(where: { newType.rooms.contains($0) }) else { return }
            room = suggested
        }
    }
}

// MARK: - Manage

/// Every device, grouped by room and searchable. Tap to edit; swipe to remove.
struct ManageDevicesView: View {
    @Environment(DeviceRepository.self) private var repository
    @State private var query = ""

    var body: some View {
        List {
            ForEach(repository.roomsWithDevices) { room in
                let devices = filtered(repository.devices(in: room))
                if !devices.isEmpty {
                    Section(room.displayName) {
                        ForEach(devices) { device in
                            NavigationLink {
                                EditDeviceView(device: device)
                            } label: {
                                DeviceRow(device: device)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    repository.remove(device)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button(
                                    device.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: device.isFavorite ? "star.slash.fill" : "star.fill"
                                ) {
                                    repository.setFavorite(device, !device.isFavorite)
                                }
                                .tint(NexColors.yellow)
                            }
                        }
                    }
                }
            }

            if !repository.removedDevices.isEmpty && query.isEmpty {
                Section {
                    Button("Restore \(repository.removedDevices.count) Removed Devices", systemImage: "arrow.uturn.backward") {
                        repository.restoreRemovedDevices()
                    }
                } footer: {
                    Text("Removed devices from the original house can be brought back at any time.")
                }
            }
        }
        .overlay {
            if !query.isEmpty && repository.devices.allSatisfy({ !matches($0) }) {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: "Devices, rooms or types")
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filtered(_ devices: [Device]) -> [Device] {
        query.isEmpty ? devices : devices.filter(matches)
    }

    private func matches(_ device: Device) -> Bool {
        let q = query.lowercased()
        return device.name.lowercased().contains(q)
            || device.type.label.lowercased().contains(q)
            || device.room.displayName.lowercased().contains(q)
    }
}

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            DeviceSetupIcon(type: device.type)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).lineLimit(1)
                Text(device.type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if device.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(NexColors.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
    }
}

// MARK: - Edit

/// One device's name, room and favourite flag, and removal.
struct EditDeviceView: View {
    let device: Device

    @Environment(DeviceRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmingRemove = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    DeviceSetupIcon(type: device.type, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.type.label).font(.headline)
                        Text(statusLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Name") {
                TextField("Name", text: $name)
                    .submitLabel(.done)
                    .onSubmit { repository.rename(device, to: name) }
            }

            Section {
                Picker(
                    "Room",
                    selection: Binding(get: { device.room }, set: { repository.move(device, to: $0) })
                ) {
                    ForEach(Room.allCases) { room in
                        Label(room.displayName, systemImage: room.symbol).tag(room)
                    }
                }
                .pickerStyle(.navigationLink)

                Toggle(
                    "Favorite",
                    isOn: Binding(get: { device.isFavorite }, set: { repository.setFavorite(device, $0) })
                )
                .tint(NexColors.yellow)
            } footer: {
                Text("Favourites are pinned to Featured on the Home screen.")
            }

            Section {
                LabeledContent("Firmware", value: device.firmwareVersion)
                LabeledContent("Signal", value: device.isOnline ? "\(device.signalStrength) of 4 bars" : "Offline")
                LabeledContent("Added", value: repository.isCustom(device) ? "By you" : "With the house")
            }

            Section {
                Button("Remove Device", role: .destructive) { confirmingRemove = true }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = device.name }
        .onDisappear { repository.rename(device, to: name) }
        .confirmationDialog(
            "Remove \(device.name)?",
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove Device", role: .destructive) {
                repository.remove(device)
                dismiss()
            }
        } message: {
            Text(
                repository.isCustom(device)
                    ? "This device was added by hand and will be deleted."
                    : "You can restore it from the Devices list."
            )
        }
    }

    private var statusLine: String {
        "\(device.room.displayName) · \(deviceStatusText(device))"
    }
}

// MARK: - Home screen layout

/// Reorder the Home screen's sections and switch each on or off.
struct HomeLayoutView: View {
    @Environment(HomeSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                ForEach(settings.sectionOrder) { section in
                    Toggle(
                        isOn: Binding(
                            get: { !settings.hiddenSections.contains(section) },
                            set: { visible in
                                if visible {
                                    settings.hiddenSections.remove(section)
                                } else {
                                    settings.hiddenSections.insert(section)
                                }
                            }
                        )
                    ) {
                        SetupLabel(section.label, symbol: section.symbol, accent: section.accent)
                    }
                }
                .onMove { from, to in
                    settings.sectionOrder.move(fromOffsets: from, toOffset: to)
                }
            } footer: {
                Text("Drag to reorder. The greeting card always stays at the top.")
            }

            Section {
                Button("Restore Default Layout") { settings.resetLayout() }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Home Screen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
