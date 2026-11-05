import SwiftUI

/// Cameras: a hero feed spanning the grid plus a grid of feeds. Each feed is framed in a glass tile
/// whose chrome chips (LIVE, timestamp, motion) are glass sitting over the live picture.
struct CamerasScreen: View {
    let onDeviceTap: (Device) -> Void

    @Environment(DeviceRepository.self) private var repository

    var body: some View {
        let cameras = repository.devices(ofKind: .cameraFeed)
        let others = Array(cameras.dropFirst())
        let recording = cameras.filter { $0.isRecording && !$0.privacyMode }.count
        let motion = cameras.filter { $0.motionDetected && !$0.privacyMode }.count
        let privateCount = cameras.filter { $0.privacyMode }.count

        ScrollView {
            LazyVStack(spacing: 12) {
                ScreenTitle("Cameras", subtitle: "\(cameras.count) live feeds across the property")

                HStack(spacing: 10) {
                    GlassStatPill(
                        value: "\(recording)",
                        label: "recording",
                        accent: deviceAccent(ControlKind.cameraFeed),
                        symbol: "record.circle.fill"
                    )
                    GlassStatPill(
                        value: "\(motion)",
                        label: "motion",
                        accent: motion > 0 ? NexColors.red : NexColors.cyan,
                        symbol: "figure.walk.motion"
                    )
                    GlassStatPill(
                        value: "\(privateCount)",
                        label: "private",
                        accent: NexColors.violet,
                        symbol: "eye.slash.fill"
                    )
                }
                .padding(.bottom, 4)

                if let hero = cameras.first {
                    CameraTile(device: hero, hero: true) { onDeviceTap(hero) }
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(others) { device in
                        CameraTile(device: device, hero: false) { onDeviceTap(device) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct CameraTile: View {
    @Bindable var device: Device
    let hero: Bool
    let action: () -> Void

    var body: some View {
        let accent = deviceAccent(device.type)
        let live = device.isRecording && !device.privacyMode

        GlassPanel(
            shape: glassRect(hero ? 30 : 24),
            tint: NexColors.glassTint,
            accent: accent,
            pressScale: hero ? 1.035 : GlassMotion.tilePressScale,
            action: action
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    CameraFeed(
                        seed: device.cameraSeed,
                        cornerRadius: hero ? 22 : 17,
                        shimmer: hero,
                        nightVision: device.nightVisionMode == .on ? 1 : 0,
                        privacy: device.privacyMode ? 1 : 0,
                        spotlight: device.spotlightOn ? 1 : 0,
                        onSeedTick: { device.cameraSeed = $0 }
                    )
                    .aspectRatio(hero ? 16.0 / 10.0 : 1, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            FeedChip {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(live ? NexColors.red : NexColors.tertiary)
                                NexText(
                                    device.privacyMode ? "PRIVATE" : "LIVE",
                                    .caption,
                                    color: .white
                                )
                                .lineLimit(1)
                            }
                            Spacer()
                            if hero {
                                FeedChip {
                                    NexText(timestamp, .caption, color: .white).lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        if device.motionDetected && !device.privacyMode {
                            FeedChip(tint: NexColors.red.opacity(0.38)) {
                                Image(systemName: "figure.walk.motion")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                NexText("Motion", .caption, color: .white).lineLimit(1)
                            }
                        }
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 1) {
                    NexText(device.name, hero ? .bodyStrong : .label).lineLimit(1)
                    NexText(subtitle, .caption, color: NexColors.tertiary).lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
            .padding(8)
        }
    }

    private var subtitle: String {
        guard hero, let last = device.cameraEvents.first else { return device.room.displayName }
        return "\(device.room.displayName) · \(last.label)"
    }

    private var timestamp: String {
        Date.now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
    }
}
