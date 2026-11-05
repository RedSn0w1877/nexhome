import SwiftUI

/// Temporary shell used to validate the toolchain on CI; replaced by the full tab shell.
struct RootView: View {
    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        ZStack {
            AmbientBackdrop(theme: .nebula)

            ScrollView {
                VStack(spacing: 16) {
                    GlassPanel(shape: glassRect(32), tint: NexColors.glassTintDark, heavy: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            NexText("NexHome", .headline)
                            NexText(
                                "\(repository.devices.count) devices across "
                                    + "\(repository.roomsWithDevices.count) rooms",
                                .body,
                                color: NexColors.secondary
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }

                    ForEach(repository.devices.prefix(12)) { device in
                        GlassPanel(
                            shape: glassRect(26),
                            tint: NexColors.glassTint,
                            accent: deviceAccent(device.type),
                            action: {}
                        ) {
                            HStack(spacing: 12) {
                                GlassIconOrb(
                                    symbol: device.type.symbol,
                                    accent: deviceAccent(device.type),
                                    size: 42,
                                    glow: device.isOn ? 1 : 0,
                                    iconTint: .white
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    NexText(device.name, .bodyStrong).lineLimit(1)
                                    NexText(device.room.displayName, .caption, color: NexColors.tertiary)
                                }
                                Spacer()
                                GlassPill(
                                    text: device.isOn ? "On" : "Off",
                                    accent: deviceAccent(device.type),
                                    lit: device.isOn
                                )
                            }
                            .padding(14)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}
