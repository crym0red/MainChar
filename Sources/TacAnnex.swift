import SwiftUI

/// BLOCK 9 ANNEX (kind 7): one small two-storey house on a walled lot, the first map for the rebuilt stairs.
/// Plan is 1400 x 1000. Floor 1 is the ground floor and yard, floor 2 is the upper storey, floor 0 is solid and unused.
/// The staircase is a single straight run (x 975-1075, y 350-575): climb from the ground hall at the south foot,
/// arrive on the upper landing at the north head. Same footprint on both floors, so the climb is continuous.
enum TAnnex {
    static let W: CGFloat = 1400
    static let H: CGFloat = 1000
    static let shared: MapData = build()

    private static func build() -> MapData {
        let b = MapBuilder(cols: 56, rows: 40)
        let rc = b.rc

        // ---- lot
        let arena = rc(0, 0, W, H)
        b.setR(1, arena, true)
        b.tiles.insert(TRoom(name: "Yard", r: MapBuilder.R(1, arena), mat: 8, fl: 1), at: 0)
        b.rooms.append(TRoom(name: "West Yard", r: MapBuilder.R(1, rc(0, 0, 300, H)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "East Yard", r: MapBuilder.R(1, rc(1100, 0, 300, H)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "North Yard", r: MapBuilder.R(1, rc(300, 0, 800, 225)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "South Yard", r: MapBuilder.R(1, rc(300, 725, 800, 275)), mat: 8, fl: 1))

        // ---- shell
        let outer = rc(300, 225, 800, 500)
        b.setR(1, outer, false)
        b.setR(2, outer, false)
        b.outers.append(outer)

        func door(_ fl: Int, _ x: CGFloat, _ y: CGFloat) { b.doors.append(b.dh(fl, x, y, 100)) }
        func doorV(_ fl: Int, _ x: CGFloat, _ y: CGFloat) { b.doors.append(b.dv(fl, x, y, 100)) }

        let kitchen = rc(325, 250, 300, 325)
        let living = rc(650, 250, 300, 325)
        let hall = rc(325, 600, 750, 100)
        let stair = rc(975, 350, 100, 225)
        let landing = rc(975, 250, 100, 100)

        // ---- ground floor
        b.area(1, "Kitchen", kitchen, 3)
        b.area(1, "Living Room", living, 4)
        b.area(1, "Ground Hall", hall, 5)
        b.area(1, "Stairs", stair, 1)
        // hall side doors: kitchen and living are on the north row
        b.gap(1, rc(450, 575, 100, 25), 5); door(1, 450, 575)
        b.gap(1, rc(775, 575, 100, 25), 5); door(1, 775, 575)
        b.gap(1, rc(975, 575, 100, 25), 5)                            // open foot of the stairs
        b.gap(1, rc(625, 400, 25, 100), 4)                            // kitchen <-> living archway
        // ways in: both hall ends and the back door
        b.gap(1, rc(300, 600, 25, 100), 5); doorV(1, 300, 600)
        b.gap(1, rc(1075, 600, 25, 100), 5); doorV(1, 1075, 600)
        b.gap(1, rc(550, 700, 100, 25), 5); door(1, 550, 700)

        // ---- upper floor
        b.area(2, "Bedroom", kitchen, 4)
        b.area(2, "Study", living, 3)
        b.area(2, "Upper Hall", hall, 5)
        b.area(2, "Stair Head", stair, 1)
        b.area(2, "Landing", landing, 5)
        b.gap(2, rc(950, 260, 25, 80), 5)                             // landing <-> study
        b.gap(2, rc(450, 575, 100, 25), 5); door(2, 450, 575)
        b.gap(2, rc(775, 575, 100, 25), 5); door(2, 775, 575)
        b.gap(2, rc(625, 400, 25, 100), 4)

        let stairs: [CGRect] = [stair]
        let stairLo: [Int] = [1]
        let layout = b.layout([.concrete, .brick, .concrete])

        // ---- furniture
        // ground
        b.p(1, .counter, 345, 262, 220, 34); b.p(1, .table, 420, 400, 100, 60); b.p(1, .barrel, 580, 262, 36, 36)
        b.p(1, .couch, 690, 262, 150, 60); b.p(1, .tv, 890, 256, 40, 24); b.p(1, .table, 720, 420, 100, 60); b.p(1, .plant, 905, 520, 36, 36)
        b.p(1, .crate, 340, 655, 40, 36); b.p(1, .crate, 860, 665, 40, 30)
        // upper
        b.p(2, .bed, 480, 262, 100, 150); b.p(2, .shelf, 341, 290, 28, 130)
        b.p(2, .shelf, 665, 262, 130, 28); b.p(2, .table, 760, 420, 100, 60); b.p(2, .crate, 880, 290, 50, 50)
        b.p(2, .crate, 360, 660, 40, 36); b.p(2, .barrel, 900, 650, 36, 36)
        // yard
        b.p(1, .car, 60, 120, 56, 110); b.p(1, .car, 1280, 780, 56, 110)
        b.p(1, .car, 520, 40, 110, 56); b.p(1, .car, 600, 900, 110, 56)
        b.p(1, .crate, 900, 60, 100, 60); b.p(1, .crate, 230, 820, 90, 60)
        b.p(1, .barrel, 220, 480, 36, 36); b.p(1, .barrel, 1180, 500, 36, 36)
        b.p(1, .tree, 130, 780, 80, 80); b.p(1, .tree, 1210, 130, 80, 80)

        // ---- spawns
        let atk = (0..<5).map { CGPoint(x: 120 + 3200, y: 300 + CGFloat($0) * 90) }
        let def = (0..<5).map { CGPoint(x: 1280 + 3200, y: 300 + CGFloat($0) * 90) }
        var sp: [CGPoint] = []
        for i in 0..<5 { sp.append(CGPoint(x: 200 + CGFloat(i) * 250 + 3200, y: 150)) }
        for i in 0..<5 { sp.append(CGPoint(x: 200 + CGFloat(i) * 250 + 3200, y: 800)) }
        sp += atk
        sp += def
        let packs = [CGPoint(x: 700, y: 650), CGPoint(x: 800, y: 350), CGPoint(x: 1000, y: 650), CGPoint(x: 700, y: 150)].map { CGPoint(x: $0.x + 3200, y: $0.y) }

        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: stairs, stairLo: stairLo,
                         siteA: MapBuilder.R(1, kitchen), siteB: MapBuilder.R(2, living),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(650, 600, 300, 100)),
                         floorNames: ["", "GROUND", "UPPER"], loot: [], roofs: b.roofs, spawns: sp)
        md.siteNames = ["A · KITCHEN", "B · STUDY"]
        return md
    }
}
