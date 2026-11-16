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
    // Rooms the owner can add in Setup. Appended so existing raw values (and accents) stay put.
    case sunroom
    case nursery
    case library
    case workshop
    case mediaRoom
    case playroom
    case pantry
    case studio
    case balcony
    case gardenShed

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
        case .sunroom: return "SUNROOM"
        case .nursery: return "NURSERY"
        case .library: return "LIBRARY"
        case .workshop: return "WORKSHOP"
        case .mediaRoom: return "MEDIA_ROOM"
        case .playroom: return "PLAYROOM"
        case .pantry: return "PANTRY"
        case .studio: return "STUDIO"
        case .balcony: return "BALCONY"
        case .gardenShed: return "GARDEN_SHED"
        }
    }

    /// The room's name: the owner's rename from Setup, or its default.
    var displayName: String { Room.customNames[self] ?? defaultName }

    /// The room's icon: the owner's choice from Setup, or its default.
    var symbol: String { Room.customSymbols[self] ?? defaultSymbol }

    var defaultName: String {
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
        case .sunroom: return "Sunroom"
        case .nursery: return "Nursery"
        case .library: return "Library"
        case .workshop: return "Workshop"
        case .mediaRoom: return "Media Room"
        case .playroom: return "Playroom"
        case .pantry: return "Pantry"
        case .studio: return "Studio"
        case .balcony: return "Balcony"
        case .gardenShed: return "Garden Shed"
        }
    }

    /// Default SF Symbol for the room.
    var defaultSymbol: String {
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
        case .sunroom: return "sun.max.fill"
        case .nursery: return "teddybear.fill"
        case .library: return "books.vertical.fill"
        case .workshop: return "hammer.fill"
        case .mediaRoom: return "tv.fill"
        case .playroom: return "puzzlepiece.fill"
        case .pantry: return "takeoutbag.and.cup.and.straw.fill"
        case .studio: return "paintpalette.fill"
        case .balcony: return "building.columns.fill"
        case .gardenShed: return "leaf.fill"
        }
    }
}

// Room groupings reused by `DeviceType`.
extension Room {
    /// The generated house's outdoor areas (used by the generator, so it never changes).
    static let outdoor: Set<Room> = [.frontYard, .backyard, .patio, .driveway, .pool]
    /// The generated house's indoor rooms. Listed explicitly so rooms added later never receive
    /// generated devices (which would reshuffle the seeded house).
    static let indoor: Set<Room> = [
        .livingRoom, .kitchen, .primaryBedroom, .bedroomTwo, .bedroomThree, .kidsRoom, .guestRoom,
        .bathroomOne, .bathroomTwo, .homeOffice, .diningRoom, .hallway, .entryway, .mudroom,
        .laundryRoom, .garage, .basement, .attic, .gym, .wineCellar,
    ]

    /// Owner renames and icons from Setup, mirrored here by `DeviceRepository` so every view that
    /// reads `displayName` / `symbol` picks them up.
    nonisolated(unsafe) static var customNames: [Room: String] = [:]
    nonisolated(unsafe) static var customSymbols: [Room: String] = [:]

    /// Icons offered when customising a room.
    static let symbolChoices: [String] = [
        "sofa.fill", "bed.double.fill", "fork.knife", "bathtub.fill", "chair.lounge.fill",
        "chair.fill", "door.left.hand.closed", "washer.fill", "car.fill", "shippingbox.fill",
        "dumbbell.fill", "wineglass.fill", "leaf.fill", "tree.fill", "sun.horizon.fill",
        "figure.pool.swim", "sun.max.fill", "teddybear.fill", "books.vertical.fill", "hammer.fill",
        "tv.fill", "puzzlepiece.fill", "paintpalette.fill", "building.columns.fill",
        "gamecontroller.fill", "music.note", "desktopcomputer", "stairs", "house.fill", "star.fill",
    ]
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
