import Foundation

/// The rooms of the simulated house. `rawValue` doubles as the Kotlin enum's ordinal, which the
/// room accent palette and the device generator both rely on.
enum Room: Int, CaseIterable, Hashable, Identifiable, Sendable {
    case livingRoom
    case kitchen
    case primaryBedroom
    case bedroomTwo
    case bedroomThree
    case kidsRoom
    case guestRoom
    case bathroomOne
    case bathroomTwo
    case homeOffice
    case diningRoom
    case hallway
    case entryway
    case mudroom
    case laundryRoom
    case garage
    case basement
    case attic
    case gym
    case wineCellar
    case frontYard
    case backyard
    case patio
    case pool
    case driveway

    var id: Int { rawValue }

    /// Stable identifier, used for lazy-list keys and generated device ids.
    var key: String {
        switch self {
        case .livingRoom: return "LIVING_ROOM"
        case .kitchen: return "KITCHEN"
        case .primaryBedroom: return "PRIMARY_BEDROOM"
        case .bedroomTwo: return "BEDROOM_TWO"
        case .bedroomThree: return "BEDROOM_THREE"
        case .kidsRoom: return "KIDS_ROOM"
        case .guestRoom: return "GUEST_ROOM"
        case .bathroomOne: return "BATHROOM_ONE"
        case .bathroomTwo: return "BATHROOM_TWO"
        case .homeOffice: return "HOME_OFFICE"
        case .diningRoom: return "DINING_ROOM"
        case .hallway: return "HALLWAY"
        case .entryway: return "ENTRYWAY"
        case .mudroom: return "MUDROOM"
        case .laundryRoom: return "LAUNDRY_ROOM"
        case .garage: return "GARAGE"
        case .basement: return "BASEMENT"
        case .attic: return "ATTIC"
        case .gym: return "GYM"
        case .wineCellar: return "WINE_CELLAR"
        case .frontYard: return "FRONT_YARD"
        case .backyard: return "BACKYARD"
        case .patio: return "PATIO"
        case .pool: return "POOL"
        case .driveway: return "DRIVEWAY"
        }
    }

    var displayName: String {
        switch self {
        case .livingRoom: return "Living Room"
        case .kitchen: return "Kitchen"
        case .primaryBedroom: return "Primary Bedroom"
        case .bedroomTwo: return "Bedroom 2"
        case .bedroomThree: return "Bedroom 3"
        case .kidsRoom: return "Kids' Room"
        case .guestRoom: return "Guest Room"
        case .bathroomOne: return "Primary Bathroom"
        case .bathroomTwo: return "Bathroom 2"
        case .homeOffice: return "Home Office"
        case .diningRoom: return "Dining Room"
        case .hallway: return "Hallway"
        case .entryway: return "Entryway"
        case .mudroom: return "Mudroom"
        case .laundryRoom: return "Laundry Room"
        case .garage: return "Garage"
        case .basement: return "Basement"
        case .attic: return "Attic"
        case .gym: return "Home Gym"
        case .wineCellar: return "Wine Cellar"
        case .frontYard: return "Front Yard"
        case .backyard: return "Backyard"
        case .patio: return "Patio"
        case .pool: return "Pool"
        case .driveway: return "Driveway"
        }
    }

    /// SF Symbol standing in for the Android build's Material icon.
    var symbol: String {
        switch self {
        case .livingRoom: return "sofa.fill"
        case .kitchen: return "fork.knife"
        case .primaryBedroom, .bedroomTwo, .bedroomThree, .kidsRoom, .guestRoom: return "bed.double.fill"
        case .bathroomOne, .bathroomTwo: return "bathtub.fill"
        case .homeOffice: return "chair.lounge.fill"
        case .diningRoom: return "chair.fill"
        case .hallway, .entryway, .mudroom: return "door.left.hand.closed"
        case .laundryRoom: return "washer.fill"
        case .garage, .driveway: return "car.fill"
        case .basement, .attic: return "shippingbox.fill"
        case .gym: return "dumbbell.fill"
        case .wineCellar: return "wineglass.fill"
        case .frontYard: return "leaf.fill"
        case .backyard: return "tree.fill"
        case .patio: return "sun.horizon.fill"
        case .pool: return "figure.pool.swim"
        }
    }
}

// Room groupings reused by `DeviceType`.
extension Room {
    static let outdoor: Set<Room> = [.frontYard, .backyard, .patio, .driveway, .pool]
    static let indoor: Set<Room> = Set(Room.allCases).subtracting(Room.outdoor)
    static let living: Set<Room> = [
        .livingRoom, .primaryBedroom, .bedroomTwo, .bedroomThree, .homeOffice, .guestRoom, .kidsRoom,
    ]
    static let accent: Set<Room> = [.livingRoom, .kidsRoom, .gym, .wineCellar, .basement]
    static let hallways: Set<Room> = [.hallway, .entryway, .mudroom, .diningRoom]
    static let thermostats: Set<Room> = [.livingRoom, .primaryBedroom, .homeOffice, .basement]
    static let bedrooms: Set<Room> = [.primaryBedroom, .bedroomTwo, .bedroomThree, .kidsRoom, .guestRoom]
    static let locks: Set<Room> = [.entryway, .garage, .mudroom, .backyard, .patio]
    static let interiorDoors: Set<Room> = [.homeOffice, .wineCellar, .basement, .attic]
    static let windows: Set<Room> = Room.living.union([.diningRoom, .homeOffice])
    static let doorWindow: Set<Room> = Room.living.union([.entryway, .garage, .mudroom])
}
