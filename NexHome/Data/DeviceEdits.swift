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
    /// Rooms the owner added (by `Room.rawValue`), kept even while they hold no devices.
    var addedRooms: [Int] = []
    var roomNames: [Int: String] = [:]
    var roomSymbols: [Int: String] = [:]
    /// The owner's room order (`Room.rawValue`s); empty means the default order.
    var roomOrder: [Int] = []

    init() {}

    /// Every key is optional, so edits saved by an older build still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        added = try c.decodeIfPresent([AddedDevice].self, forKey: .added) ?? []
        names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        rooms = try c.decodeIfPresent([String: Int].self, forKey: .rooms) ?? [:]
        favorites = try c.decodeIfPresent([String: Bool].self, forKey: .favorites) ?? [:]
        removed = try c.decodeIfPresent(Set<String>.self, forKey: .removed) ?? []
        addedRooms = try c.decodeIfPresent([Int].self, forKey: .addedRooms) ?? []
        roomNames = try c.decodeIfPresent([Int: String].self, forKey: .roomNames) ?? [:]
        roomSymbols = try c.decodeIfPresent([Int: String].self, forKey: .roomSymbols) ?? [:]
        roomOrder = try c.decodeIfPresent([Int].self, forKey: .roomOrder) ?? []
    }

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
