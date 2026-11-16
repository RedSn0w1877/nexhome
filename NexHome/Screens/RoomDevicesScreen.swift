import SwiftUI

private let switchableKinds: Set<ControlKind> = [.dimmer, .toggle, .fanSpeed, .mediaPlayer]

/// One room, pushed onto the navigation stack: a glass hero (room badge filled by the share of
/// devices on, live power, a lights-on pill and an "All on / All off" button), then a grid of
/// device cards.
struct RoomDevicesScreen: View {
    let room: Room
    let onDeviceTap: (Device) -> Void

    @Environment(DeviceRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    var body: some View {
        let accent = roomAccent(room)
        let devices = repository.devices(in: room)
            .sorted { $0.controlKind.rawValue < $1.controlKind.rawValue }
        let switchables = devices.filter { switchableKinds.contains($0.controlKind) }
        let lights = devices.filter { $0.controlKind == .dimmer }
        let onCount = devices.filter { $0.isOn }.count
        let lightsOn = lights.filter { $0.isOn }.count
        let anySwitchOn = switchables.contains { $0.isOn }
        let watts = devices.reduce(0.0) { $0 + repository.liveWatts($1) }
        let total = Double(max(devices.count, 1))

        ScrollView {
            LazyVStack(spacing: 12) {
                if !devices.isEmpty {
                GlassPanel(shape: glassRect(30)) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            GlassIconOrb(
                                symbol: room.symbol,
                                accent: accent,
                                size: 56,
                                glow: Double(onCount) / total,
                                iconTint: .white
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                NexText("\(onCount) of \(devices.count) on", .title).lineLimit(1)
                                NexText(
                                    "Using \(powerValueText(watts)) \(powerUnitText(watts)) right now",
                                    .caption,
                                    color: NexColors.secondary
                                )
                                .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 10) {
                            GlassStatPill(
                                value: powerValueText(watts),
                                label: "\(powerUnitText(watts)) now",
                                accent: NexColors.amber,
                                symbol: "bolt.fill"
                            )
                            GlassStatPill(
                                value: "\(lightsOn)/\(lights.count)",
                                label: "lights on",
                                accent: accent,
                                symbol: "lightbulb.fill"
                            )
                            if !switchables.isEmpty {
                                LiquidButton(tint: accent, action: {
                                    let target = !anySwitchOn
                                    for device in switchables { device.isOn = target }
                                }) {
                                    Image(systemName: "power")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    NexText(anySwitchOn ? "All off" : "All on", .label, color: .white)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                }
                .padding(.bottom, 4)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(devices) { device in
                        DeviceCard(device: device) { onDeviceTap(device) }
                    }
                }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView {
                    Label("No Devices Yet", systemImage: room.symbol)
                } description: {
                    Text("Set up a device and put it in \(room.displayName).")
                } actions: {
                    Button("Add a Device") { router.addDevice(in: room) }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .wallpaperBackground()
        .toolbar {
            Button("Add Device", systemImage: "plus") { router.addDevice(in: room) }
        }
        .navigationTitle(room.displayName)
        .navigationSubtitle("\(devices.count) devices")
    }
}
