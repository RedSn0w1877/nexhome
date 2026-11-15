import PhotosUI
import SwiftUI

/// Setup: a native settings sheet for customising the home. Name and wallpaper, adding and managing
/// devices, the Home screen's sections and their order, preferences, and a full reset.
struct SetupScreen: View {
    @Environment(DeviceRepository.self) private var repository
    @Environment(HomeSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        TextField("Home Name", text: $settings.homeName)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                    } label: {
                        SetupLabel("Name", symbol: "house.fill", accent: NexColors.blue)
                    }
                } header: {
                    Text("Home")
                } footer: {
                    Text("Shown as the title of the Home tab.")
                }

                Section("Wallpaper") {
                    WallpaperGrid()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        SetupLabel("Choose a Photo…", symbol: "photo.fill", accent: NexColors.pink)
                    }
                    if settings.customImage != nil {
                        Button(role: .destructive) {
                            settings.setPhoto(nil)
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AddDeviceView()
                    } label: {
                        SetupLabel("Add Device", symbol: "plus", accent: NexColors.green)
                    }
                    NavigationLink {
                        ManageDevicesView()
                    } label: {
                        LabeledContent {
                            Text("\(repository.devices.count)")
                        } label: {
                            SetupLabel("Manage Devices", symbol: "list.bullet", accent: NexColors.indigo)
                        }
                    }
                } header: {
                    Text("Devices")
                } footer: {
                    Text("Rename devices, move them between rooms, mark favourites or remove them. Added devices get live simulated state like the rest of the house.")
                }

                Section {
                    NavigationLink {
                        HomeLayoutView()
                    } label: {
                        LabeledContent {
                            Text("\(settings.visibleSections.count) of \(HomeSection.allCases.count)")
                        } label: {
                            SetupLabel("Sections & Order", symbol: "square.stack.fill", accent: NexColors.orange)
                        }
                    }
                } header: {
                    Text("Home Screen")
                }

                Section {
                    Toggle(isOn: $settings.hapticsEnabled) {
                        SetupLabel("Haptics", symbol: "hand.tap.fill", accent: NexColors.purple)
                    }
                    Stepper(value: $settings.pricePerKwh, in: 0.05...1.0, step: 0.01) {
                        LabeledContent {
                            Text(settings.pricePerKwh, format: .currency(code: "USD").precision(.fractionLength(2)))
                                .monospacedDigit()
                        } label: {
                            SetupLabel("Electricity / kWh", symbol: "bolt.fill", accent: NexColors.yellow)
                        }
                    }
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("The price is used for every cost estimate in the app.")
                }

                Section {
                    LabeledContent("Rooms", value: "\(repository.roomsWithDevices.count)")
                    LabeledContent("Devices", value: "\(repository.devices.count)")
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("NexHome runs a simulated house: every device and reading is generated on this iPhone.")
                }

                Section {
                    Button("Reset All Customizations", role: .destructive) {
                        confirmingReset = true
                    }
                } footer: {
                    Text("Restores the original house, the default wallpaper and the Home screen layout.")
                }
            }
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset all customizations?",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    repository.resetCustomizations()
                    settings.resetAll()
                }
            } message: {
                Text("Added devices are deleted and every rename, move and removal is undone.")
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        settings.setPhoto(image)
                    }
                    photoItem = nil
                }
            }
        }
        .presentationDetents([.large])
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// A Settings-app row label: a coloured rounded-square icon and a title.
struct SetupLabel: View {
    let title: String
    let symbol: String
    let accent: Color

    init(_ title: String, symbol: String, accent: Color) {
        self.title = title
        self.symbol = symbol
        self.accent = accent
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SettingsIcon(symbol: symbol, accent: accent, size: 28)
        }
    }
}

/// Wallpaper themes as small previews; the selected one carries a checkmark.
private struct WallpaperGrid: View {
    @Environment(HomeSettings.self) private var settings

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BackgroundTheme.allCases) { theme in
                    let selected = settings.customImage == nil && settings.theme == theme
                    Button {
                        settings.setPhoto(nil)
                        settings.theme = theme
                    } label: {
                        VStack(spacing: 6) {
                            AmbientBackdrop(theme: theme)
                                .frame(width: 64, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(selected ? Color.white : .clear, lineWidth: 2.5)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.black, .white)
                                            .font(.system(size: 18))
                                            .padding(5)
                                    }
                                }
                            Text(theme.label)
                                .font(.caption)
                                .foregroundStyle(selected ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.label) wallpaper")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}
