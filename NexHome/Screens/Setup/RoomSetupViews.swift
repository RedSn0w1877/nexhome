import SwiftUI

/// Every room in the house: drag to reorder, swipe to remove, tap to edit, + to add.
struct RoomsSetupView: View {
    @Environment(DeviceRepository.self) private var repository
    @State private var roomToRemove: Room?

    var body: some View {
        List {
            Section {
                ForEach(repository.roomsWithDevices) { room in
                    NavigationLink {
                        RoomEditView(room: room)
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(symbol: room.symbol, accent: roomAccent(room))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(room.displayName).lineLimit(1)
                                Text(deviceCountText(repository.devices(in: room).count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            roomToRemove = room
                        }
                    }
                }
                .onMove { source, destination in
                    repository.moveRooms(fromOffsets: source, toOffset: destination)
                }
            } footer: {
                Text("Tap Edit to reorder. The order is used on Home and in Rooms.")
            }

            Section {
                NavigationLink {
                    AddRoomView()
                } label: {
                    Label("Add Room", systemImage: "plus")
                }
                .disabled(repository.roomsAvailableToAdd.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Rooms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .confirmationDialog(
            "Remove \(roomToRemove?.displayName ?? "room")?",
            isPresented: Binding(get: { roomToRemove != nil }, set: { if !$0 { roomToRemove = nil } }),
            titleVisibility: .visible,
            presenting: roomToRemove
        ) { room in
            Button("Remove Room", role: .destructive) { repository.removeRoom(room) }
        } message: { room in
            Text(removeMessage(room, count: repository.devices(in: room).count))
        }
    }
}

/// One room: its name and icon, the devices in it, adding a device there, and removing it.
struct RoomEditView: View {
    let room: Room

    @Environment(DeviceRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showingWizard = false
    @State private var confirmingRemove = false

    var body: some View {
        let devices = repository.devices(in: room)
        let accent = roomAccent(room)

        Form {
            Section {
                HStack(spacing: 14) {
                    SettingsIcon(symbol: room.symbol, accent: accent, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.displayName).font(.title3.bold())
                        Text(deviceCountText(devices.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                TextField(room.defaultName, text: $name)
                    .submitLabel(.done)
                    .onSubmit { repository.renameRoom(room, to: name) }
                    .accessibilityIdentifier("roomNameField")
                if room.displayName != room.defaultName {
                    Button("Use “\(room.defaultName)”") {
                        name = ""
                        repository.renameRoom(room, to: "")
                    }
                }
            } header: {
                Text("Name")
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Room.symbolChoices, id: \.self) { symbol in
                        let selected = symbol == room.symbol
                        Button {
                            Haptics.tick()
                            repository.setRoomSymbol(room, symbol)
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selected ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    selected ? AnyShapeStyle(accent) : AnyShapeStyle(NexColors.fill),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(devices) { device in
                    NavigationLink {
                        EditDeviceView(device: device)
                    } label: {
                        DeviceSetupRow(device: device)
                    }
                }
                Button {
                    showingWizard = true
                } label: {
                    Label("Add a Device Here", systemImage: "plus")
                }
            } header: {
                Text("Devices")
            }

            Section {
                Button("Remove Room", role: .destructive) { confirmingRemove = true }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(room.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = room.displayName == room.defaultName ? "" : room.displayName }
        .onDisappear {
            if repository.roomsWithDevices.contains(room) { repository.renameRoom(room, to: name) }
        }
        .sheet(isPresented: $showingWizard) { AddDeviceWizard(preferredRoom: room) }
        .confirmationDialog(
            "Remove \(room.displayName)?",
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove Room", role: .destructive) {
                repository.removeRoom(room)
                dismiss()
            }
        } message: {
            Text(removeMessage(room, count: devices.count))
        }
    }
}

/// Adds a room to the house: pick one of the available rooms, optionally rename it.
struct AddRoomView: View {
    @Environment(DeviceRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var choice: Room?
    @State private var name = ""

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    SettingsIcon(
                        symbol: choice?.defaultSymbol ?? "plus",
                        accent: choice.map(roomAccent) ?? NexColors.indigo,
                        size: 56
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? (choice?.defaultName ?? "New Room") : name)
                            .font(.title3.bold())
                        Text(choice == nil ? "Choose a room below" : "Ready to add")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .animation(GlassMotion.glow, value: choice)
            }

            if let choice {
                Section("Name") {
                    TextField(choice.defaultName, text: $name)
                        .submitLabel(.done)
                }
            }

            Section("Room") {
                ForEach(repository.roomsAvailableToAdd) { room in
                    Button {
                        Haptics.tick()
                        choice = room
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(symbol: room.defaultSymbol, accent: roomAccent(room))
                            Text(room.defaultName).foregroundStyle(.primary)
                            Spacer()
                            if choice == room {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(NexColors.blue)
                            }
                        }
                    }
                    .accessibilityAddTraits(choice == room ? .isSelected : [])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Add Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard let choice else { return }
                    repository.addRoom(choice, name: name.isEmpty ? nil : name)
                    Haptics.confirm()
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .disabled(choice == nil)
            }
        }
    }
}

private func deviceCountText(_ count: Int) -> String {
    switch count {
    case 0: return "No devices yet"
    case 1: return "1 device"
    default: return "\(count) devices"
    }
}

private func removeMessage(_ room: Room, count: Int) -> String {
    count == 0
        ? "The room is empty."
        : "Its \(count) devices are removed too. Devices from the original house can be restored from Setup."
}
