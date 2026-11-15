# NexHome for iOS

NexHome is a concept smart-home app with a liquid-glass interface. This repository holds the iOS 27
version, a native **SwiftUI** port of the original Android (Kotlin / Jetpack Compose) app.

- ~200 simulated devices across 24 rooms, generated procedurally, with a live simulation behind
  them (garage doors travel, vacuums follow their route, cycles count down, temperatures drift).
- Home, Rooms, Room, Cameras and Security screens, plus a full-screen sheet for every device
  category: lights, plugs, thermostats/AC, water and pool heaters, fans/purifiers/humidity, locks,
  garage doors, the security panel, speakers/TVs/soundbars, cameras, kitchen and laundry appliances,
  the robot vacuum, EV charger, pool pump, sprinklers, sensors and blinds.
- Built entirely on Apple's **Liquid Glass**: the system tab bar, navigation bars and toolbar
  buttons, system sheets, and `glassEffect` for cards and controls. Nothing is a painted imitation.
- **Setup** (the gear in any tab's toolbar): name the home, pick a wallpaper or photo, add devices
  by hand, rename/move/favourite/remove devices, reorder and hide Home sections, haptics and the
  electricity price. Edits are saved across launches.

Requirements: **Xcode 27**, **iOS 27.0+**, iPhone (portrait).

## Get the app (no Mac needed)

Every push to `main` is built by GitHub Actions on the `xcode-27` macOS runner. Open the latest
run under **Actions → iOS** and download:

| Artifact | What it is |
| --- | --- |
| `NexHome-unsigned-ipa` | `NexHome-unsigned.ipa` for installing on an iPhone |
| `NexHome-app-bundle` | The raw `NexHome.app` from the device archive |
| `NexHome-simulator-screenshots` | Screenshots taken in an iOS 27 simulator during CI |

Or with the GitHub CLI:

```bash
gh run download --repo RedSn0w1877/nexhome -n NexHome-unsigned-ipa
```

### Installing the unsigned IPA

The IPA is **not signed**. CI has no Apple certificates, and iOS will not install unsigned apps
directly. Sign it with your own Apple ID using a sideloading tool, for example
[Sideloadly](https://sideloadly.io) or [AltStore](https://altstore.io):

1. Connect your iPhone to your computer and open the sideloading tool.
2. Drop in `NexHome-unsigned.ipa` and sign in with your Apple ID.
3. On the iPhone, trust your developer certificate:
   **Settings → General → VPN & Device Management**.
4. Turn on **Developer Mode** if iOS asks for it:
   **Settings → Privacy & Security → Developer Mode**.

With a free Apple ID, the signature expires after 7 days; re-sign to keep using the app. With a paid
Apple Developer account, the workflow can produce a properly signed IPA instead (see below).

### Signed builds (optional)

To have CI produce an installable, signed IPA, add these repository secrets and a signing step:
a distribution or development certificate (`.p12`) with its password, and a matching
provisioning profile for `com.nexhome.app`. This isn't set up yet.

## Building locally

```bash
open NexHome.xcodeproj   # Xcode 27, scheme "NexHome"
```

or from the command line:

```bash
xcodebuild build -project NexHome.xcodeproj -scheme NexHome \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

The project uses a file-system-synchronized group, so new Swift files under `NexHome/` are picked
up automatically, with no project-file edits needed.

### Testing hooks

CI uses launch arguments to screenshot screens without touching the simulator:

- `-openKind <KIND>` opens the first device of a category.
- `-startTab rooms|cameras|security` starts on that tab.
- `-openSetup YES` opens Setup.

For example:

```bash
xcrun simctl launch booted com.nexhome.app -openKind THERMOSTAT_DIAL
```

Kinds: `TOGGLE`, `DIMMER`, `THERMOSTAT_DIAL`, `LOCK`, `GARAGE`, `CAMERA_FEED`, `BLINDS_SLIDER`,
`MEDIA_PLAYER`, `FAN_SPEED`, `APPLIANCE_CYCLE`, `ROBOT_VACUUM`, `WATER_HEATER_DIAL`, `EV_CHARGER`,
`SPRINKLER_ZONES`, `SENSOR_READONLY`, `SECURITY_PANEL`.

## Project layout

```
NexHome/
├── NexHomeApp.swift          App entry: repository, settings and router in the environment
├── Models/                   Device, DeviceType, Room and detail enums (Observation framework)
├── Data/                     House generator, repository + saved Setup edits, HomeSettings
├── Theme/                    System colours, Dynamic Type styles, device palettes, the wallpaper
├── Glass/                    Components built on system Liquid Glass
│   ├── GlassPanel.swift        The base surface (glass on the wallpaper, an inset fill inside it)
│   ├── GlassSection.swift      Sections, Settings-style rows, metric tiles, sparklines
│   ├── LiquidControls.swift    Glass buttons and chips, system toggle and slider, stepper
│   └── LiquidSegmented / LiquidDial / LiquidFader / LiquidHoldOrb, motion, haptics
├── Screens/                  TabView shell, the five screens, and Setup/
├── Device/                   Device card, device sheet, and one control file per category
└── Components/               The simulated live camera feed
```

## Notes on the port

- **SwiftUI rewrite, not a wrapper.** The Compose UI was rewritten in SwiftUI. Device state uses
  `@Observable`, so controls mutate the model directly, as the Compose snapshot state did.
- **Native glass, one layer.** The Android build approximated glass with the Kyant0 Backdrop
  library. Here only the system material is used, the way Apple's apps use it: surfaces on the
  wallpaper are glass, anything inside them is an inset fill (never glass on glass), and controls
  (buttons, chips, thumbs, orbs) are interactive glass. Navigation is the system's: tab bar, large
  titles, toolbars, sheets, context menus.
- **SF Symbols** replace the Material icon set.
- **Deterministic house.** The generator is seeded, so the house is the same on every launch. It
  uses a different random-number generator than Kotlin's, so individual devices differ from the
  Android build while the overall shape is the same.
- **Camera feeds** are seeded photos from picsum.photos (network required), processed with SwiftUI
  effects for night vision, privacy blur, spotlight and siren washes. No Metal toolchain is
  needed to build.
