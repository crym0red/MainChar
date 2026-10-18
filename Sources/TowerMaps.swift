import SwiftUI

typealias TwRGB = (CGFloat, CGFloat, CGFloat)

struct MapDef {
    let id: Int
    let name: String
    let tag: String
    let floors: [String]
    let teams: Int
    let per: Int
    let top: [(CGFloat, CGFloat)]
    let bot: [(CGFloat, CGFloat)]
    let mids: [(CGRect, Int)]
    let names: [String]
    let special: Int          // 0 none, 1 key suites, 2 hazard wards, 3 blast vaults
    let mech: Int             // 0 none, 1 shutters, 2 trains+blackout, 3 belts+heavy doors, 4 keycards, 5 hazards+security doors, 6 power switches, 7 glass
    let gates: [CGRect]
    let parts: [CGRect]
    let glass: [CGRect]
    let belts: [(CGRect, CGPoint)]
    let lanes: [CGRect]
    let hall: [String]
    let room: [String]
    let roomC: [TwRGB]
    let tint: [TwRGB]
    let wallTint: TwRGB
    let windows: Bool
    let amb: TwRGB
    let ambI: CGFloat
    let coreC: TwRGB
    let props: [[Int]]
    let finalFloor: Int
    let finalCore: Bool
    let sign: String

    var players: Int { teams * per }
    var nF: Int { floors.count }
}

enum TowerMaps {
    static let gate1 = CGRect(x: 142, y: 410, width: 16, height: 180)
    static let gate2 = CGRect(x: 1442, y: 410, width: 16, height: 180)
    static let midsStd: [(CGRect, Int)] = [
        (CGRect(x: 170, y: 258, width: 300, height: 152), 1), (CGRect(x: 170, y: 590, width: 300, height: 152), 0),
        (CGRect(x: 1130, y: 258, width: 300, height: 152), 1), (CGRect(x: 1130, y: 590, width: 300, height: 152), 0)
    ]

    static let all: [MapDef] = [mall, underground, foundry, hotel, quarantine, blacksite, museum]

    static let mall = MapDef(
        id: 0, name: "THE MALL", tag: "Atrium shops, roll-down shutters, 3 floors", floors: ["PARKING", "ATRIUM LEVEL", "BALCONY LEVEL"], teams: 8, per: 4,
        top: [(40, 280), (340, 270), (630, 280), (930, 280), (1230, 330)], bot: [(40, 280), (340, 270), (630, 280), (930, 280), (1230, 330)],
        mids: midsStd, names: ["SPORTS STORE", "ELECTRONICS", "FOOD STALL", "BOOKSHOP", "SHOE STORE", "PHARMACY", "TOY SHOP", "CAFE", "DEPARTMENT STORE", "BOUTIQUE", "ARCADE", "SALON"],
        special: 0, mech: 1, gates: [gate1, gate2], parts: [], glass: [], belts: [], lanes: [],
        hall: ["concrete", "marble", "marble"], room: ["tile", "carpet", "wood", "carpet"],
        roomC: [(0.8, 0.82, 0.9), (0.95, 0.75, 0.7), (0.9, 0.8, 0.6), (0.7, 0.85, 0.95)],
        tint: [(0.8, 0.8, 0.85), (1.0, 0.97, 0.92), (1.0, 0.94, 0.86)], wallTint: (1.0, 0.95, 0.92), windows: true,
        amb: (1.0, 0.95, 0.9), ambI: 620, coreC: (1.0, 0.5, 0.2), props: [[14, 5, 3, 2], [14, 14, 3, 8], [14, 5, 2, 15]], finalFloor: -1, finalCore: false, sign: "SHUTTERS")

    static let underground = MapDef(
        id: 1, name: "THE UNDERGROUND", tag: "Subway platforms, trains, blackouts", floors: ["PLATFORM LEVEL", "MID TUNNELS", "DEEP TUNNELS"], teams: 8, per: 3,
        top: [(60, 300), (410, 300), (760, 300), (1110, 330)], bot: [(60, 300), (410, 300), (760, 300), (1110, 330)],
        mids: [], names: ["TICKET HALL", "UTILITY ROOM", "SIGNAL ROOM", "MAINTENANCE", "STAFF ROOM", "KIOSK", "CONTROL ROOM", "STORAGE"],
        special: 0, mech: 2, gates: [], parts: [], glass: [], belts: [],
        lanes: [CGRect(x: 40, y: 215, width: 1520, height: 90), CGRect(x: 40, y: 695, width: 1520, height: 90)],
        hall: ["tile", "concrete", "concrete"], room: ["tile", "concrete", "tile"],
        roomC: [(0.7, 0.85, 0.8), (0.6, 0.62, 0.66), (0.85, 0.85, 0.7)],
        tint: [(0.75, 0.85, 0.85), (0.6, 0.65, 0.7), (0.5, 0.55, 0.6)], wallTint: (0.8, 0.9, 0.88), windows: false,
        amb: (0.7, 0.85, 0.9), ambI: 430, coreC: (0.2, 0.9, 0.7), props: [[15, 14, 0, 7], [6, 0, 7, 15], [7, 0, 6, 15]], finalFloor: -1, finalCore: false, sign: "TRAINS")

    static let foundry = MapDef(
        id: 2, name: "THE FOUNDRY", tag: "Conveyors, catwalks, heavy doors, 4 levels", floors: ["GROUND FLOOR", "MEZZANINE", "CATWALKS", "FURNACE DECK"], teams: 8, per: 3,
        top: [(50, 340), (410, 340), (770, 340), (1130, 420)], bot: [(50, 340), (410, 340), (770, 340), (1130, 420)],
        mids: [], names: ["STORAGE BAY", "FURNACE", "CASTING HALL", "TOOL CRIB", "BOILER ROOM", "ASSEMBLY", "FOREMAN OFFICE", "PRESS ROOM"],
        special: 0, mech: 3, gates: [gate1, gate2], parts: [CGRect(x: 250, y: 440, width: 16, height: 120), CGRect(x: 1334, y: 440, width: 16, height: 120)], glass: [],
        belts: [(CGRect(x: 180, y: 222, width: 1240, height: 44), CGPoint(x: 75, y: 0)), (CGRect(x: 180, y: 734, width: 1240, height: 44), CGPoint(x: -75, y: 0)),
                (CGRect(x: 520, y: 270, width: 44, height: 110), CGPoint(x: 0, y: 70)), (CGRect(x: 1036, y: 640, width: 44, height: 110), CGPoint(x: 0, y: -70))],
        lanes: [], hall: ["metal", "grate", "metal", "grate"], room: ["grate", "concrete", "metal"],
        roomC: [(0.7, 0.62, 0.55), (0.62, 0.6, 0.62), (0.8, 0.6, 0.45)],
        tint: [(0.8, 0.7, 0.65), (0.75, 0.7, 0.7), (0.7, 0.68, 0.72), (0.9, 0.65, 0.5)], wallTint: (0.85, 0.75, 0.7), windows: false,
        amb: (1.0, 0.8, 0.65), ambI: 480, coreC: (1.0, 0.4, 0.1), props: [[13, 7, 0, 13], [13, 0, 7, 13], [13, 7, 13, 0], [13, 13, 7, 0]], finalFloor: -1, finalCore: false, sign: "CONVEYORS")

    static let hotel = MapDef(
        id: 3, name: "THE LAST CHECK-IN", tag: "Guest rooms, keycard suites, 8 floors", floors: ["BASEMENT", "LOBBY", "FLOOR 2", "FLOOR 3", "FLOOR 4", "FLOOR 5", "SUITES", "ROOFTOP"], teams: 8, per: 3,
        top: [(40, 240), (290, 240), (540, 240), (790, 240), (1040, 240), (1290, 240)], bot: [(40, 240), (290, 240), (540, 240), (790, 240), (1040, 240), (1290, 240)],
        mids: midsStd, names: ["ROOM 101", "ROOM 102", "BALLROOM", "KITCHEN", "LAUNDRY", "ROOM 104", "BAR", "ROOM 105", "SUITE A", "SUITE B", "SUITE C", "PENTHOUSE"],
        special: 1, mech: 4, gates: [], parts: [], glass: [], belts: [], lanes: [],
        hall: ["carpet", "marble", "carpet", "carpet", "carpet", "carpet", "marble", "wood"], room: ["carpet", "wood", "carpet", "tile"],
        roomC: [(0.85, 0.55, 0.55), (0.9, 0.7, 0.5), (0.6, 0.55, 0.8), (0.8, 0.85, 0.9)],
        tint: [(0.8, 0.7, 0.7), (1.0, 0.9, 0.8), (0.95, 0.8, 0.8), (0.9, 0.85, 0.95), (0.85, 0.9, 0.95), (1.0, 0.9, 0.85), (1.0, 0.85, 0.7), (0.75, 0.85, 1.0)], wallTint: (1.0, 0.92, 0.88), windows: true,
        amb: (1.0, 0.9, 0.85), ambI: 560, coreC: (0.9, 0.7, 0.3), props: [[10, 1, 3, 2], [10, 5, 4, 3], [10, 2, 3, 1], [10, 10, 4, 2]], finalFloor: -1, finalCore: false, sign: "KEYCARDS")

    static let quarantine = MapDef(
        id: 4, name: "QUARANTINE", tag: "Sealed hospital, security doors, hot wards", floors: ["EMERGENCY ROOM", "PATIENT WARDS", "LABORATORIES", "PHARMACY WING", "ROOFTOP HELIPAD"], teams: 8, per: 3,
        top: [(40, 280), (340, 270), (630, 280), (930, 280), (1230, 330)], bot: [(40, 280), (340, 270), (630, 280), (930, 280), (1230, 330)],
        mids: midsStd, names: ["ER BAY", "WARD A", "WARD B", "X-RAY", "ICU", "PHARMACY", "LAB 1", "LAB 2", "MORGUE", "SURGERY", "ISOLATION", "WAITING ROOM"],
        special: 2, mech: 5, gates: [gate1, gate2], parts: [], glass: [], belts: [], lanes: [],
        hall: ["tile", "tile", "tile", "tile", "concrete"], room: ["tile", "tile", "carpet"],
        roomC: [(0.8, 0.95, 0.9), (0.85, 0.9, 1.0), (0.9, 0.95, 0.85)],
        tint: [(0.85, 1.0, 0.95), (0.9, 0.98, 1.0), (0.85, 0.95, 0.9), (0.95, 1.0, 0.95), (0.7, 0.8, 0.9)], wallTint: (0.88, 1.0, 0.95), windows: true,
        amb: (0.85, 1.0, 0.95), ambI: 600, coreC: (0.3, 1.0, 0.6), props: [[11, 17, 5, 3], [11, 11, 17, 4], [5, 17, 4, 6], [4, 17, 5, 11], [0, 7, 3, 5]], finalFloor: -1, finalCore: false, sign: "SECURITY")

    static let blacksite = MapDef(
        id: 5, name: "BLACKSITE", tag: "Underground bunker, blast doors, power", floors: ["LEVEL B1", "LEVEL B2", "LEVEL B3"], teams: 8, per: 3,
        top: [(40, 300), (360, 300), (680, 240), (940, 240), (1200, 360)], bot: [(40, 300), (360, 300), (680, 240), (940, 240), (1200, 360)],
        mids: midsStd, names: ["COMMAND CENTER", "ARMORY", "SERVER ROOM", "BARRACKS", "CONTAINMENT", "GENERATOR", "COMMS", "VAULT", "MESS HALL", "CELL BLOCK", "LAB", "QUARTERS"],
        special: 3, mech: 6, gates: [gate1, gate2], parts: [], glass: [], belts: [], lanes: [],
        hall: ["metal", "metal", "grate"], room: ["metal", "concrete", "grate"],
        roomC: [(0.55, 0.6, 0.65), (0.5, 0.55, 0.5), (0.6, 0.62, 0.7)],
        tint: [(0.55, 0.6, 0.68), (0.5, 0.55, 0.62), (0.45, 0.5, 0.58)], wallTint: (0.6, 0.66, 0.72), windows: false,
        amb: (0.6, 0.75, 1.0), ambI: 400, coreC: (0.2, 0.6, 1.0), props: [[6, 0, 7, 17], [6, 17, 0, 7], [6, 0, 13, 7]], finalFloor: 0, finalCore: true, sign: "POWER")

    static let museum = MapDef(
        id: 6, name: "THE MUSEUM", tag: "Long halls, glass cases, central skeleton", floors: ["GRAND HALLS", "GALLERIES", "PLANETARIUM"], teams: 8, per: 3,
        top: [(40, 400), (460, 340), (820, 340), (1180, 380)], bot: [(40, 380), (440, 380), (840, 300), (1160, 400)],
        mids: [], names: ["DINOSAUR HALL", "EGYPT", "ARCHIVES", "ART GALLERY", "MINERALS", "ARMOR HALL", "GIFT SHOP", "PLANETARIUM"],
        special: 0, mech: 7, gates: [], parts: [],
        glass: [CGRect(x: 170, y: 330, width: 320, height: 6), CGRect(x: 1110, y: 330, width: 320, height: 6), CGRect(x: 170, y: 670, width: 320, height: 6), CGRect(x: 1110, y: 670, width: 320, height: 6),
                CGRect(x: 560, y: 230, width: 6, height: 110), CGRect(x: 1030, y: 230, width: 6, height: 110), CGRect(x: 560, y: 660, width: 6, height: 110), CGRect(x: 1030, y: 660, width: 6, height: 110)],
        belts: [], lanes: [], hall: ["marble", "wood", "marble"], room: ["wood", "marble", "carpet"],
        roomC: [(0.9, 0.8, 0.65), (0.85, 0.85, 0.9), (0.6, 0.5, 0.65)],
        tint: [(1.0, 0.95, 0.85), (0.95, 0.9, 0.8), (0.7, 0.75, 0.95)], wallTint: (0.95, 0.9, 0.82), windows: true,
        amb: (1.0, 0.92, 0.8), ambI: 520, coreC: (0.9, 0.85, 0.7), props: [[12, 15, 3, 4], [12, 12, 2, 4], [12, 3, 15, 5]], finalFloor: 0, finalCore: true, sign: "GLASS")
}
