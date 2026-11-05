import SwiftUI

// Placeholders while each category's controls are ported. Each is replaced by its own file.

struct PendingControls: View {
    let device: Device
    var body: some View {
        GlassSection(title: device.type.label, symbol: device.type.symbol) {
            NexText("Controls for this category are being ported.", .body, color: NexColors.secondary)
        }
    }
}

struct CameraControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
struct ApplianceControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
struct VacuumControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
struct EvChargerControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
struct SprinklerControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
struct SensorControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
struct BlindsControls: View { let device: Device; var body: some View { PendingControls(device: device) } }
