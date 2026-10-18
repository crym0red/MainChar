import SwiftUI
import UIKit

private struct Rng2 {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
}

/// Compact helper that turns "areas + buildings" into the walkable masks that TMap.buildLayout understands.
final class MapBuilder {
    static let cell: CGFloat = 25
    static let cols = 120
    static let rows = 72
    var mask = [[Bool]](repeating: [Bool](repeating: false, count: 120 * 72), count: 3)
    var rooms: [TRoom] = []
    var tiles: [TRoom] = []
    var doors: [CGRect] = []
    var roofs: [CGRect] = []
    var props: [TProp] = []
    var outers: [CGRect] = []

    static func R(_ fl: Int, _ r: CGRect) -> CGRect { CGRect(x: r.minX + CGFloat(fl) * 3200, y: r.minY, width: r.width, height: r.height) }
    func rc(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

    func setR(_ fl: Int, _ r: CGRect, _ v: Bool) {
        let c = MapBuilder.cell
        let c0 = max(0, Int(floor(r.minX / c))), c1 = min(MapBuilder.cols - 1, Int(ceil(r.maxX / c)) - 1)
        let r0 = max(0, Int(floor(r.minY / c))), r1 = min(MapBuilder.rows - 1, Int(ceil(r.maxY / c)) - 1)
        if c0 > c1 || r0 > r1 { return }
        for cc in c0...c1 { for rw in r0...r1 { mask[fl][rw * MapBuilder.cols + cc] = v } }
    }

    /// walkable named area with its own floor tile
    func area(_ fl: Int, _ name: String, _ r: CGRect, _ mat: Int) {
        setR(fl, r, true)
        let t = TRoom(name: name, r: MapBuilder.R(fl, r), mat: mat, fl: fl)
        rooms.append(t)
        tiles.append(t)
    }

    /// unnamed walkable opening
    func gap(_ fl: Int, _ r: CGRect, _ mat: Int) {
        setR(fl, r, true)
        tiles.append(TRoom(name: "", r: MapBuilder.R(fl, r), mat: mat, fl: fl))
    }

    func dh(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> CGRect { CGRect(x: x + CGFloat(fl) * 3200, y: y + 5.5, width: w, height: 14) }
    func dv(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x + 5.5 + CGFloat(fl) * 3200, y: y, width: 14, height: h) }

    /// walled building on floor `fl`; each door is (side N/S/E/W, offset along that wall)
    func building(_ fl: Int, _ name: String, _ outer: CGRect, doors ds: [(Character, CGFloat)], mat: Int, roof: Bool = true) {
        let inner = outer.insetBy(dx: 25, dy: 25)
        setR(fl, outer, false)
        setR(fl, inner, true)
        let t = TRoom(name: name, r: MapBuilder.R(fl, inner), mat: mat, fl: fl)
        rooms.append(t)
        tiles.append(t)
        for (side, off) in ds {
            switch side {
            case "S":
                let g = rc(outer.minX + off, outer.maxY - 25, 100, 25)
                gap(fl, g, mat); doors.append(dh(fl, g.minX, g.minY, 100))
            case "N":
                let g = rc(outer.minX + off, outer.minY, 100, 25)
                gap(fl, g, mat); doors.append(dh(fl, g.minX, g.minY, 100))
            case "E":
                let g = rc(outer.maxX - 25, outer.minY + off, 25, 100)
                gap(fl, g, mat); doors.append(dv(fl, g.minX, g.minY, 100))
            default:
                let g = rc(outer.minX, outer.minY + off, 25, 100)
                gap(fl, g, mat); doors.append(dv(fl, g.minX, g.minY, 100))
            }
        }
        outers.append(outer)
        if roof { roofs.append(MapBuilder.R(fl, outer)) }
    }

    func p(_ fl: Int, _ k: PropKind, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        props.append(TProp(r: MapBuilder.R(fl, rc(x, y, w, h)), k: k))
    }

    private func maskRects(_ fl: Int) -> [(CGRect, Int)] {
        let cols = MapBuilder.cols, rows = MapBuilder.rows, cell = MapBuilder.cell
        var out: [(CGRect, Int)] = []
        var active: [Int: (c1: Int, r0: Int)] = [:]
        for rw in 0...rows {
            var curRuns: [Int: Int] = [:]
            if rw < rows {
                var c = 0
                while c < cols {
                    if mask[fl][rw * cols + c] {
                        var e = c
                        while e + 1 < cols && mask[fl][rw * cols + e + 1] { e += 1 }
                        curRuns[c] = e
                        c = e + 1
                    } else { c += 1 }
                }
            }
            for (k, a) in active {
                if let e = curRuns[k], e == a.c1 { continue }
                out.append((MapBuilder.R(fl, rc(CGFloat(k) * cell, CGFloat(a.r0) * cell, CGFloat(a.c1 - k + 1) * cell, CGFloat(rw - a.r0) * cell)), fl))
                active[k] = nil
            }
            for (k, e) in curRuns where active[k] == nil { active[k] = (e, rw) }
        }
        return out
    }

    func layout(_ mats: [WallMat]) -> (walls: [CGRect], mats: [WallMat], doors: [CGRect]) {
        let walk = maskRects(0) + maskRects(1) + maskRects(2)
        return TMap.buildLayout(walk, mats: mats, doors: doors)
    }

    /// 20 spread-out points on a ring avoiding the keep-out rects (used by FFA / spare spawns)
    func ring(_ keep: [CGRect], seed: UInt64) -> [CGPoint] {
        var rng = Rng2(s: seed)
        var out: [CGPoint] = []
        var att = 0
        while out.count < 20 && att < 2000 {
            att += 1
            let ang = (CGFloat(out.count) / 20) * 2 * CGFloat.pi + (rng.next() - 0.5) * 0.2
            let rad = 0.7 + rng.next() * 0.2
            let pt = CGPoint(x: 1500 + cos(ang) * 1250 * rad, y: 900 + sin(ang) * 690 * rad)
            let r = rc(pt.x - 36, pt.y - 36, 72, 72)
            if keep.contains(where: { $0.intersects(r) }) { continue }
            out.append(pt)
        }
        var fb = 0
        while out.count < 20 { out.append(CGPoint(x: 260 + CGFloat(fb) * 120, y: 1640)); fb += 1 }
        return out
    }
}

// MARK: - Warehouse Yard (kind 2): 0 tunnel, 1 yard + warehouses, 2 crane catwalk

enum TWarehouse {
    static let shared: MapData = build()

    private static func build() -> MapData {
        let b = MapBuilder()
        let rc = b.rc
        // tunnel
        b.area(0, "West Chamber", rc(500, 650, 300, 400), 1)
        b.area(0, "Service Tunnel", rc(800, 775, 1400, 150), 1)
        b.area(0, "East Chamber", rc(2200, 650, 300, 400), 1)
        // catwalk
        b.area(2, "Crane Catwalk", rc(1000, 600, 1000, 600), 4)
        // yard
        let arena = rc(150, 100, 2700, 1600)
        b.setR(1, arena, true)
        b.tiles.insert(TRoom(name: "Yard", r: MapBuilder.R(1, arena), mat: 8, fl: 1), at: 0)
        b.rooms.append(TRoom(name: "North Yard", r: MapBuilder.R(1, rc(150, 100, 2700, 800)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "South Yard", r: MapBuilder.R(1, rc(150, 900, 2700, 800)), mat: 8, fl: 1))
        b.building(1, "Warehouse A", rc(200, 150, 1000, 500), doors: [("S", 150), ("E", 200)], mat: 3)
        b.building(1, "Warehouse B", rc(1800, 1000, 1000, 650), doors: [("N", 200), ("W", 250)], mat: 3)
        b.building(1, "Office", rc(1300, 150, 450, 300), doors: [("S", 175)], mat: 5)
        b.building(1, "Garage", rc(250, 1250, 400, 350), doors: [("E", 125)], mat: 5)

        let stairs: [CGRect] = [rc(550, 700, 100, 120), rc(2350, 700, 100, 120), rc(1050, 650, 100, 150)]
        let stairLo: [Int] = [0, 0, 1]
        let layout = b.layout([.brick, .concrete, .concrete])

        // props: warehouse A
        b.p(1, .crate, 250, 200, 220, 70); b.p(1, .crate, 520, 200, 120, 70); b.p(1, .shelf, 250, 520, 500, 28); b.p(1, .barrel, 900, 220, 36, 36); b.p(1, .crate, 780, 400, 90, 90); b.p(1, .crate, 1000, 520, 100, 60)
        // warehouse B
        b.p(1, .crate, 1850, 1080, 120, 70); b.p(1, .crate, 2250, 1060, 200, 70); b.p(1, .shelf, 1850, 1560, 500, 28); b.p(1, .barrel, 2600, 1560, 36, 36); b.p(1, .crate, 2400, 1350, 100, 100); b.p(1, .crate, 2050, 1300, 90, 90)
        // office + garage
        b.p(1, .table, 1400, 250, 160, 70); b.p(1, .counter, 1340, 180, 160, 34)
        b.p(1, .car, 300, 1400, 110, 56); b.p(1, .crate, 520, 1300, 60, 60)
        // yard cover: containers, cars, barrels, sandbags
        b.p(1, .crate, 300, 880, 200, 70); b.p(1, .crate, 400, 1000, 70, 150); b.p(1, .car, 800, 1100, 110, 56)
        b.p(1, .crate, 1400, 600, 180, 70); b.p(1, .crate, 1650, 1000, 70, 160); b.p(1, .sandbag, 1300, 1250, 100, 32)
        b.p(1, .car, 1900, 400, 56, 110); b.p(1, .crate, 2150, 450, 200, 70); b.p(1, .barrel, 2450, 600, 36, 36); b.p(1, .barrel, 2500, 640, 36, 36)
        b.p(1, .sandbag, 1500, 780, 120, 32); b.p(1, .sandbag, 1500, 1050, 120, 32)
        b.p(1, .crate, 900, 800, 60, 60); b.p(1, .crate, 2050, 850, 70, 70); b.p(1, .car, 2600, 900, 110, 56)
        b.p(1, .crate, 1200, 1500, 220, 70); b.p(1, .barrel, 1000, 1400, 36, 36); b.p(1, .sandbag, 800, 700, 100, 32)
        // tunnel + catwalk
        b.p(0, .crate, 700, 980, 60, 60); b.p(0, .barrel, 1200, 790, 36, 36); b.p(0, .crate, 1700, 840, 50, 50); b.p(0, .crate, 2300, 950, 60, 60)
        b.p(2, .crate, 1300, 800, 70, 70); b.p(2, .sandbag, 1600, 700, 100, 30)

        let keep: [CGRect] = b.outers.map { $0.insetBy(dx: -70, dy: -70) } + b.props.filter { TMap.floorOfX($0.r.midX) == 1 }.map { $0.r.insetBy(dx: -30, dy: -30) } + stairs.map { $0.insetBy(dx: -60, dy: -60) }
        let ring = b.ring(keep, seed: 77)
        let spawns = ring.map { CGPoint(x: $0.x + 3200, y: $0.y) }
        let atk = (0..<5).map { CGPoint(x: 260 + 3200, y: 780 + CGFloat($0) * 90) }
        let def = (0..<5).map { CGPoint(x: 2740 + 3200, y: 260 + CGFloat($0) * 90) }
        let packs = [CGPoint(x: 1500, y: 900), CGPoint(x: 400, y: 900), CGPoint(x: 2600, y: 800), CGPoint(x: 1500, y: 1650)].map { CGPoint(x: $0.x + 3200, y: $0.y) }
        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: stairs, stairLo: stairLo,
                         siteA: MapBuilder.R(1, rc(400, 250, 500, 300)), siteB: MapBuilder.R(1, rc(2000, 1150, 500, 300)),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(1300, 800, 400, 200)),
                         floorNames: ["TUNNEL", "YARD", "CATWALK"], loot: [], roofs: b.roofs, spawns: spawns)
        md.siteNames = ["A · WAREHOUSE", "B · DEPOT"]
        return md
    }
}

// MARK: - Desert Outpost (kind 3): 0 cellar, 1 village, 2 rooftop

enum TDesert {
    static let shared: MapData = build()

    private static func build() -> MapData {
        let b = MapBuilder()
        let rc = b.rc
        b.area(0, "Cellar", rc(1250, 1250, 600, 300), 1)
        b.area(2, "Rooftop", rc(1150, 175, 500, 300), 5)
        let arena = rc(150, 100, 2700, 1600)
        b.setR(1, arena, true)
        b.tiles.insert(TRoom(name: "Desert", r: MapBuilder.R(1, arena), mat: 0, fl: 1), at: 0)
        b.rooms.append(TRoom(name: "Dune Road", r: MapBuilder.R(1, rc(150, 100, 2700, 800)), mat: 0, fl: 1))
        b.rooms.append(TRoom(name: "Old Square", r: MapBuilder.R(1, rc(150, 900, 2700, 800)), mat: 0, fl: 1))
        b.building(1, "Market", rc(300, 200, 500, 400), doors: [("S", 200)], mat: 3)
        b.building(1, "Hall", rc(1100, 150, 600, 350), doors: [("S", 250), ("W", 120)], mat: 5)
        b.building(1, "Villa", rc(2000, 200, 550, 450), doors: [("W", 150)], mat: 3)
        b.building(1, "Workshop", rc(250, 1150, 450, 400), doors: [("N", 150)], mat: 5)
        b.building(1, "Barracks", rc(1200, 1200, 700, 400), doors: [("N", 200), ("E", 150)], mat: 3)
        b.building(1, "Tower House", rc(2250, 1100, 500, 500), doors: [("W", 200)], mat: 5)

        let stairs: [CGRect] = [rc(1300, 1350, 100, 120), rc(1175, 200, 100, 150)]
        let stairLo: [Int] = [0, 1]
        let layout = b.layout([.concrete, .brick, .concrete])

        // interiors
        b.p(1, .counter, 350, 250, 300, 36); b.p(1, .crate, 650, 480, 60, 60); b.p(1, .barrel, 340, 520, 36, 36)
        b.p(1, .table, 1350, 320, 180, 70); b.p(1, .couch, 1500, 200, 160, 60); b.p(1, .crate, 1180, 420, 50, 50)
        b.p(1, .couch, 2100, 230, 200, 70); b.p(1, .table, 2300, 400, 140, 70); b.p(1, .shelf, 2450, 230, 28, 150)
        b.p(1, .crate, 300, 1260, 60, 60); b.p(1, .shelf, 330, 1480, 300, 28); b.p(1, .barrel, 600, 1400, 36, 36)
        b.p(1, .crate, 1250, 1260, 60, 60); b.p(1, .crate, 1700, 1500, 100, 60); b.p(1, .table, 1450, 1400, 200, 70); b.p(1, .barrel, 1800, 1260, 36, 36)
        b.p(1, .table, 2350, 1250, 120, 70); b.p(1, .crate, 2600, 1480, 60, 60); b.p(1, .couch, 2300, 1480, 160, 60)
        // outdoor cover
        b.p(1, .sandbag, 900, 700, 120, 32); b.p(1, .sandbag, 1000, 740, 32, 100); b.p(1, .crate, 1300, 700, 70, 70); b.p(1, .barrel, 1700, 650, 36, 36)
        b.p(1, .car, 820, 1000, 110, 56); b.p(1, .rock, 500, 800, 90, 70); b.p(1, .rock, 2100, 850, 100, 80)
        b.p(1, .sandbag, 1500, 900, 150, 32); b.p(1, .crate, 1450, 1050, 90, 90); b.p(1, .rock, 1000, 1000, 80, 60)
        b.p(1, .car, 2000, 1000, 56, 110); b.p(1, .sandbag, 2350, 800, 120, 32); b.p(1, .rock, 900, 1550, 110, 80)
        b.p(1, .crate, 780, 700, 60, 60); b.p(1, .barrel, 2700, 820, 36, 36); b.p(1, .rock, 2600, 950, 90, 90)
        b.p(1, .sandbag, 2100, 700, 32, 120); b.p(1, .crate, 700, 900, 70, 70)
        b.p(0, .crate, 1500, 1280, 60, 60); b.p(0, .barrel, 1700, 1500, 36, 36)
        b.p(2, .crate, 1400, 250, 60, 60); b.p(2, .sandbag, 1500, 400, 100, 30)

        let keep: [CGRect] = b.outers.map { $0.insetBy(dx: -70, dy: -70) } + b.props.filter { TMap.floorOfX($0.r.midX) == 1 }.map { $0.r.insetBy(dx: -30, dy: -30) } + stairs.map { $0.insetBy(dx: -60, dy: -60) }
        let ring = b.ring(keep, seed: 91)
        let spawns = ring.map { CGPoint(x: $0.x + 3200, y: $0.y) }
        let atk = (0..<5).map { CGPoint(x: 230 + 3200, y: 700 + CGFloat($0) * 90) }
        let def = (0..<5).map { CGPoint(x: 2780 + 3200, y: 700 + CGFloat($0) * 90) }
        let packs = [CGPoint(x: 1500, y: 800), CGPoint(x: 900, y: 900), CGPoint(x: 2200, y: 900), CGPoint(x: 1500, y: 1650)].map { CGPoint(x: $0.x + 3200, y: $0.y) }
        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: stairs, stairLo: stairLo,
                         siteA: MapBuilder.R(1, rc(400, 300, 300, 200)), siteB: MapBuilder.R(1, rc(2400, 1250, 300, 250)),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(1300, 700, 400, 200)),
                         floorNames: ["CELLAR", "OUTPOST", "ROOFTOP"], loot: [], roofs: b.roofs, spawns: spawns)
        md.siteNames = ["A · MARKET", "B · TOWER HOUSE"]
        return md
    }
}
