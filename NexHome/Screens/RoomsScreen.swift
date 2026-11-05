import SwiftUI

/// Rooms: a grid of refracting room tiles (accent orb glowing with the share of devices on, a
/// temperature readout pill, a device summary and a live on-fraction bar inside the glass).
struct RoomsScreen: View {
    let onRoomTap: (Room) -> Void

    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let rooms = repository.roomsWithDevices
        let onCount = repository.devices.filter(\.isOn).count
        let activeRooms = rooms.filter { !repository.devices(in: $0).filter(\.isOn).isEmpty }.count
        let lightsOn = repository.devices(ofKind: .dimmer).filter(\.isOn).count
        let climate = repository.devices(ofKind: .thermostatDial)
        let averageTemp: Int? = climate.isEmpty
            ? nil
            : (climate.reduce(0.0) { $0 + $1.currentTempF } / Double(climate.count)).rounded0

        ScrollView {
            LazyVStack(spacing: 12) {
                ScreenTitle("Rooms", subtitle: "\(rooms.count) rooms · \(onCount) devices on")

                HStack(spacing: 10) {
                    GlassStatPill(
                        value: "\(activeRooms)",
                        label: "active rooms",
                        accent: NexColors.cyan,
                        symbol: "door.left.hand.open"
                    )
                    GlassStatPill(
                        value: "\(lightsOn)",
                        label: "lights on",
                        accent: NexColors.amber,
                        symbol: "lightbulb.fill"
                    )
                    GlassStatPill(
                        value: averageTemp.map { "\($0)°" } ?? "—",
                        label: "avg inside",
                        accent: NexColors.orange,
                        symbol: "thermometer.medium"
                    )
                }
                .padding(.bottom, 4)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(rooms) { room in
                        RoomGridTile(room: room) { onRoomTap(room) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct RoomGridTile: View {
    let room: Room
    let action: () -> Void
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let devices = repository.devices(in: room)
        let onCount = devices.filter(\.isOn).count
        let total = Double(max(devices.count, 1))
        let accent = roomAccent(room)
        let climate = devices.first { $0.controlKind == .thermostatDial }
            ?? devices.first { $0.type == .climateSensor }

        GlassPanel(
            shape: glassRect(28),
            tint: NexColors.glassTint,
            accent: accent,
            action: action,
            front: AnyView(GlassFillBar(fraction: Double(onCount) / total, accent: accent))
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    GlassIconOrb(
                        symbol: room.symbol,
                        accent: accent,
                        size: 44,
                        glow: Double(onCount) / total,
                        iconTint: .white
                    )
                    Spacer(minLength: 0)
                    if let climate {
                        GlassPill(text: "\(climate.currentTempF.rounded0)°", height: 28)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 1) {
                    NexText(room.displayName, .bodyStrong).lineLimit(1)
                    NexText("\(onCount) of \(devices.count) on", .caption, color: NexColors.secondary)
                        .lineLimit(1)
                    NexText(roomSummary(devices), .caption, color: NexColors.tertiary).lineLimit(1)
                }
            }
            .frame(height: 172, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
    }
}
