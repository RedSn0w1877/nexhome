import Foundation

/// A device added by hand in Setup.
struct AddedDevice: Codable, Hashable {
    var id: String
    var name: String
    /// `DeviceType.rawValue`.
    var type: String
    /// `Room.rawValue`.
    var room: Int
}

/// The owner's Setup edits, replayed over the generated house on every launch.
struct DeviceEdits: Codable {
    var added: [AddedDevice] = []
    var names: [String: String] = [:]
    var rooms: [String: Int] = [:]
    var favorites: [String: Bool] = [:]
    var removed: Set<String> = []

    static func load(key: String) -> DeviceEdits {
        guard let data = UserDefaults.standard.data(forKey: key),
              let edits = try? JSONDecoder().decode(DeviceEdits.self, from: data) else {
            return DeviceEdits()
        }
        return edits
    }

    func save(key: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
