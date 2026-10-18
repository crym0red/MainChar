import SwiftUI
import UIKit

/// "The House": three stacked floors (0 basement, 1 ground floor, 2 attic). Every floor is its own 3000x1800 plane,
/// laid out side by side in world space at x = floor * `off`. Interior partitions are destructible.
enum TMap {
    static let floorW: CGFloat = 3000
    static let off: CGFloat = 3200
    static let nFloors = 3
    static let W: CGFloat = 3000
    static let H: CGFloat = 1800
    static let totalW: CGFloat = 3200 * 3
    static let th: CGFloat = 14
    static let wallH: CGFloat = 80
    static let eyeH: CGFloat = 54
    static let floorNames = ["BASEMENT", "GROUND FLOOR", "ATTIC"]

    static func floorOf(_ p: CGPoint) -> Int { min(nFloors - 1, max(0, Int(p.x / off))) }
    static func floorOfX(_ x: CGFloat) -> Int { min(nFloors - 1, max(0, Int(x / off))) }
    static func origin(_ fl: Int) -> CGFloat { CGFloat(fl) * off }
    static func aimAtCenter(_ p: CGPoint) -> CGFloat { atan2(H / 2 - p.y, origin(floorOf(p)) + floorW / 2 - p.x) }

    static func propH(_ k: PropKind) -> CGFloat {
        switch k {
        case .bed: return 22
        case .couch: return 34
        case .table: return 29
        case .counter: return 40
        case .crate: return 38
        case .car: return 44
        case .shelf: return 66
        case .barrel: return 34
        case .sandbag: return 18
        case .tv: return 40
        case .plant: return 44
        }
    }

    static func propMat(_ k: PropKind) -> WallMat {
        switch k {
        case .counter, .car, .barrel, .sandbag: return .concrete
        case .tv: return .glass
        default: return .wood
        }
    }

    static func propHP(_ k: PropKind) -> CGFloat {
        switch k {
        case .crate: return 70
        case .barrel: return 50
        case .shelf: return 90
        case .tv: return 35
        case .plant: return 20
        case .table: return 90
        case .couch: return 140
        case .bed: return 160
        case .counter: return 200
        case .car, .sandbag: return -1
        }
    }

    // MARK: rooms

    private static func R(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x + CGFloat(fl) * 3200, y: y, width: w, height: h)
    }

    static let rooms: [TRoom] = {
        func r(_ fl: Int, _ n: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ m: Int) -> TRoom {
            TRoom(name: n, r: R(fl, x, y, w, h), mat: m, fl: fl)
        }
        var l: [TRoom] = []
        // basement
        l += [r(0, "Laundry", 200, 150, 700, 500, 5), r(0, "Furnace", 925, 150, 625, 500, 1), r(0, "Wine Cellar", 1575, 150, 625, 500, 4), r(0, "Workshop", 2225, 150, 575, 500, 1),
              r(0, "Cellar Hall", 200, 675, 2600, 225, 1),
              r(0, "Storage", 200, 925, 900, 725, 1), r(0, "Rec Room", 1125, 925, 1125, 725, 2), r(0, "Boiler Room", 2275, 925, 525, 725, 1)]
        // ground floor
        l += [r(1, "Garage", 200, 150, 700, 500, 1), r(1, "Kitchen", 925, 150, 625, 500, 5), r(1, "Dining", 1575, 150, 625, 500, 4), r(1, "Study", 2225, 150, 575, 500, 2),
              r(1, "Main Hall", 200, 675, 2600, 225, 4),
              r(1, "Living Room", 200, 925, 900, 725, 2), r(1, "Foyer", 1125, 925, 550, 725, 3), r(1, "Master Bed", 1700, 925, 550, 725, 2),
              r(1, "Bathroom", 2275, 925, 525, 325, 5), r(1, "Sunroom", 2275, 1275, 525, 375, 3)]
        // attic
        l += [r(2, "Loft", 200, 150, 700, 500, 4), r(2, "Library", 925, 150, 625, 500, 4), r(2, "Gallery", 1575, 150, 625, 500, 4), r(2, "Studio", 2225, 150, 575, 500, 4),
              r(2, "Attic Hall", 200, 675, 2600, 225, 4),
              r(2, "Kids Room", 200, 925, 900, 725, 2), r(2, "Landing", 1125, 925, 550, 725, 4), r(2, "Master Loft", 1700, 925, 1100, 725, 2)]
        return l
    }()

    /// plan-space doorway gaps (same on every floor; ones that fall inside a merged room are simply skipped)
    static let openings: [CGRect] = {
        var o: [CGRect] = []
        for x in [525, 1175, 1825, 2450] as [CGFloat] { o.append(CGRect(x: x, y: 650, width: 100, height: 25)) }
        o.append(CGRect(x: 600, y: 900, width: 100, height: 25))
        o.append(CGRect(x: 1325, y: 900, width: 150, height: 25))
        o.append(CGRect(x: 1925, y: 900, width: 100, height: 25))
        o.append(CGRect(x: 2500, y: 900, width: 100, height: 25))
        for x in [900, 1550, 2200] as [CGFloat] { o.append(CGRect(x: x, y: 450, width: 25, height: 100)) }
        o.append(CGRect(x: 1100, y: 1200, width: 25, height: 100))
        o.append(CGRect(x: 1675, y: 1200, width: 25, height: 100))
        o.append(CGRect(x: 2250, y: 1000, width: 25, height: 100))
        o.append(CGRect(x: 2500, y: 1250, width: 100, height: 25))
        return o
    }()

    /// every walkable rect (rooms + doorways) with its floor, in world coordinates
    static let walkRects: [(CGRect, Int)] = {
        var l: [(CGRect, Int)] = rooms.map { ($0.r, $0.fl) }
        for fl in 0..<3 {
            for o in openings {
                let w = o.offsetBy(dx: CGFloat(fl) * 3200, dy: 0)
                let mid = CGPoint(x: w.midX, y: w.midY)
                if rooms.contains(where: { $0.fl == fl && $0.r.contains(mid) }) { continue }
                l.append((w, fl))
            }
        }
        return l
    }()

    /// floor tiles to render: rooms + the doorway gaps that are not inside a room
    static let floorTiles: [TRoom] = {
        var l = rooms
        for fl in 0..<3 {
            for o in openings {
                let w = o.offsetBy(dx: CGFloat(fl) * 3200, dy: 0)
                let mid = CGPoint(x: w.midX, y: w.midY)
                if rooms.contains(where: { $0.fl == fl && $0.r.contains(mid) }) { continue }
                l.append(TRoom(name: "", r: w, mat: fl == 0 ? 1 : 4, fl: fl))
            }
        }
        return l
    }()

    static let walkable: [(String, CGRect, Int)] = rooms.map { ($0.name, $0.r, $0.mat) }

    // MARK: walls

    static let layout: (walls: [CGRect], mats: [WallMat], doors: [CGRect]) = {
        let cell: CGFloat = 25
        let cols = Int(W / cell), rows = Int(H / cell)
        var rects: [CGRect] = []
        var mats: [WallMat] = []
        for fl in 0..<3 {
            var blocked = [Bool](repeating: true, count: cols * rows)
            let ox = CGFloat(fl) * off
            for (r, f) in walkRects where f == fl {
                let c0 = max(0, Int((r.minX - ox) / cell)), c1 = min(cols - 1, Int(ceil((r.maxX - ox) / cell)) - 1)
                let r0 = max(0, Int(r.minY / cell)), r1 = min(rows - 1, Int(ceil(r.maxY / cell)) - 1)
                if c0 > c1 || r0 > r1 { continue }
                for c in c0...c1 { for rw in r0...r1 { blocked[rw * cols + c] = false } }
            }
            var active: [String: (c0: Int, c1: Int, r0: Int)] = [:]
            var local: [CGRect] = []
            for rw in 0...rows {
                var cur: [String: (Int, Int)] = [:]
                if rw < rows {
                    var c = 0
                    while c < cols {
                        if blocked[rw * cols + c] {
                            var e = c
                            while e + 1 < cols && blocked[rw * cols + e + 1] { e += 1 }
                            cur["\(c)-\(e)"] = (c, e)
                            c = e + 1
                        } else { c += 1 }
                    }
                }
                for (k, a) in active where cur[k] == nil {
                    local.append(CGRect(x: CGFloat(a.c0) * cell + ox, y: CGFloat(a.r0) * cell, width: CGFloat(a.c1 - a.c0 + 1) * cell, height: CGFloat(rw - a.r0) * cell))
                    active[k] = nil
                }
                for (k, v) in cur where active[k] == nil { active[k] = (v.0, v.1, rw) }
            }
            local.sort { $0.minY != $1.minY ? $0.minY < $1.minY : $0.minX < $1.minX }
            let m: WallMat = fl == 0 ? .brick : .concrete
            for w in local {
                let thin = min(w.width, w.height) <= 25.01
                if thin {
                    let horiz = w.width >= w.height
                    let len = horiz ? w.width : w.height
                    let n = max(1, Int((len / 100).rounded()))
                    for i in 0..<n {
                        let a = len * CGFloat(i) / CGFloat(n), b = len * CGFloat(i + 1) / CGFloat(n)
                        rects.append(horiz ? CGRect(x: w.minX + a, y: w.minY, width: b - a, height: w.height) : CGRect(x: w.minX, y: w.minY + a, width: w.width, height: b - a))
                        mats.append(m)
                    }
                } else {
                    rects.append(w)
                    mats.append(m)
                }
            }
        }
        func dh(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> CGRect { CGRect(x: x + CGFloat(fl) * 3200, y: y + 5.5, width: w, height: 14) }
        func dv(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x + 5.5 + CGFloat(fl) * 3200, y: y, width: 14, height: h) }
        let d: [CGRect] = [
            dh(1, 1175, 650, 100), dh(1, 2450, 650, 100), dh(1, 1925, 900, 100), dv(1, 900, 450, 100),
            dh(0, 1175, 650, 100), dh(0, 2450, 650, 100),
            dh(2, 1175, 650, 100), dh(2, 1925, 900, 100)
        ]
        return (rects, mats, d)
    }()

    static let walls: [CGRect] = layout.walls
    static let wallMats: [WallMat] = layout.mats
    static let doors: [CGRect] = layout.doors

    static func roomName(_ p: CGPoint) -> String {
        for r in rooms where r.r.contains(p) { return r.name }
        return "Stairs"
    }

    // MARK: props

    static let props: [TProp] = {
        var l: [TProp] = []
        func p(_ fl: Int, _ k: PropKind, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { l.append(TProp(r: R(fl, x, y, w, h), k: k)) }
        // ---- basement
        p(0, .counter, 400, 160, 250, 45); p(0, .crate, 780, 540, 70, 70); p(0, .barrel, 835, 175, 40, 40); p(0, .barrel, 835, 225, 40, 40); p(0, .crate, 240, 540, 60, 60); p(0, .table, 500, 380, 140, 70)
        p(0, .barrel, 1300, 190, 40, 40); p(0, .barrel, 1350, 190, 40, 40); p(0, .barrel, 1325, 240, 40, 40); p(0, .crate, 1400, 500, 80, 80); p(0, .crate, 1470, 430, 60, 60); p(0, .counter, 1100, 560, 200, 45); p(0, .shelf, 1505, 175, 30, 200)
        p(0, .shelf, 1650, 200, 320, 30); p(0, .shelf, 1650, 330, 320, 30); p(0, .shelf, 1650, 460, 320, 30); p(0, .barrel, 2080, 200, 40, 40); p(0, .barrel, 2080, 260, 40, 40); p(0, .barrel, 2080, 500, 40, 40); p(0, .table, 2000, 380, 100, 60)
        p(0, .counter, 2300, 160, 420, 45); p(0, .crate, 2680, 480, 80, 80); p(0, .crate, 2600, 540, 60, 60); p(0, .table, 2420, 330, 180, 80); p(0, .barrel, 2250, 560, 40, 40)
        p(0, .crate, 230, 690, 50, 50); p(0, .barrel, 2720, 820, 40, 40); p(0, .crate, 1500, 690, 50, 50); p(0, .crate, 900, 830, 50, 50); p(0, .crate, 2100, 690, 50, 50)
        p(0, .crate, 300, 1000, 90, 90); p(0, .crate, 300, 1100, 60, 60); p(0, .crate, 690, 1480, 110, 110); p(0, .crate, 850, 1050, 80, 80); p(0, .crate, 230, 1560, 70, 70); p(0, .shelf, 205, 1250, 30, 250); p(0, .barrel, 560, 1580, 40, 40); p(0, .barrel, 610, 1580, 40, 40)
        p(0, .couch, 1300, 1550, 300, 90); p(0, .tv, 1350, 1622, 200, 25); p(0, .table, 1850, 1420, 260, 130); p(0, .counter, 2150, 1000, 40, 300); p(0, .crate, 1480, 1150, 70, 70); p(0, .crate, 1700, 1300, 80, 80); p(0, .plant, 1140, 945, 32, 32)
        p(0, .barrel, 2420, 1000, 40, 40); p(0, .barrel, 2420, 1050, 40, 40); p(0, .barrel, 2420, 1100, 40, 40); p(0, .crate, 2650, 1500, 100, 100); p(0, .crate, 2500, 1300, 80, 80); p(0, .shelf, 2740, 1000, 30, 300); p(0, .counter, 2400, 1580, 300, 45)
        // ---- ground floor
        p(1, .car, 400, 300, 170, 80); p(1, .shelf, 205, 500, 30, 140); p(1, .crate, 800, 200, 60, 60); p(1, .crate, 700, 540, 70, 70); p(1, .barrel, 840, 580, 40, 40); p(1, .counter, 400, 160, 300, 45)
        p(1, .counter, 1075, 160, 400, 45); p(1, .table, 1150, 360, 260, 80); p(1, .shelf, 1510, 200, 30, 100); p(1, .plant, 1480, 580, 32, 32)
        p(1, .table, 1750, 300, 320, 120); p(1, .shelf, 1590, 175, 30, 150); p(1, .counter, 1750, 160, 300, 45); p(1, .plant, 2150, 580, 32, 32)
        p(1, .shelf, 2400, 160, 370, 35); p(1, .table, 2450, 350, 200, 80); p(1, .couch, 2690, 300, 50, 150); p(1, .plant, 2700, 580, 32, 32)
        p(1, .plant, 215, 690, 32, 32); p(1, .plant, 2750, 690, 32, 32); p(1, .plant, 2750, 840, 32, 32); p(1, .plant, 215, 840, 32, 32); p(1, .table, 700, 690, 160, 40); p(1, .table, 1600, 845, 200, 40)
        p(1, .couch, 320, 1500, 300, 90); p(1, .tv, 320, 1620, 200, 28); p(1, .table, 380, 1370, 160, 70); p(1, .plant, 215, 945, 32, 32); p(1, .shelf, 1040, 950, 40, 200); p(1, .couch, 800, 1400, 100, 100)
        p(1, .table, 1520, 1000, 100, 40); p(1, .plant, 1140, 1600, 32, 32); p(1, .plant, 1630, 1600, 32, 32); p(1, .shelf, 1640, 1000, 30, 150)
        p(1, .bed, 1900, 1450, 220, 130); p(1, .shelf, 2195, 1140, 40, 180); p(1, .couch, 1730, 960, 50, 200); p(1, .plant, 2200, 1600, 32, 32)
        p(1, .counter, 2300, 945, 300, 45); p(1, .plant, 2750, 1200, 32, 32)
        p(1, .plant, 2300, 1360, 32, 32); p(1, .plant, 2740, 1360, 32, 32); p(1, .plant, 2300, 1610, 32, 32); p(1, .couch, 2450, 1560, 260, 80); p(1, .table, 2450, 1400, 160, 70)
        // ---- attic
        p(2, .crate, 250, 500, 90, 90); p(2, .crate, 700, 200, 80, 80); p(2, .shelf, 205, 175, 30, 200); p(2, .bed, 480, 200, 200, 110); p(2, .plant, 850, 580, 32, 32)
        p(2, .shelf, 950, 160, 560, 35); p(2, .shelf, 950, 590, 200, 35); p(2, .table, 1100, 350, 260, 90); p(2, .couch, 1450, 200, 50, 130)
        p(2, .crate, 1650, 300, 80, 80); p(2, .crate, 1900, 450, 100, 100); p(2, .crate, 2050, 200, 70, 70); p(2, .table, 1800, 250, 200, 70); p(2, .plant, 2150, 580, 32, 32)
        p(2, .table, 2500, 300, 180, 70); p(2, .shelf, 2400, 160, 370, 35); p(2, .couch, 2650, 500, 150, 80); p(2, .plant, 2760, 590, 32, 32)
        p(2, .crate, 230, 690, 50, 50); p(2, .crate, 2720, 820, 50, 50); p(2, .crate, 1000, 690, 50, 50)
        p(2, .bed, 250, 1000, 200, 100); p(2, .bed, 250, 1450, 200, 100); p(2, .table, 600, 1400, 160, 90); p(2, .crate, 900, 1500, 100, 100); p(2, .plant, 215, 1610, 32, 32)
        p(2, .shelf, 1500, 950, 150, 35); p(2, .table, 1450, 1500, 150, 80); p(2, .plant, 1140, 1600, 32, 32); p(2, .plant, 1630, 1600, 32, 32)
        p(2, .bed, 1750, 1450, 220, 120); p(2, .crate, 2080, 1150, 80, 80); p(2, .crate, 2250, 1280, 90, 90); p(2, .crate, 2150, 1500, 100, 100); p(2, .shelf, 2740, 950, 35, 250); p(2, .counter, 2400, 1590, 300, 45); p(2, .table, 2500, 1050, 180, 70)
        return l
    }()

    static let rugs: [(CGRect, Color)] = []

    static let packPos: [CGPoint] = [
        CGPoint(x: 1400, y: 790), CGPoint(x: 700, y: 790), CGPoint(x: 2200, y: 790),
        CGPoint(x: 3200 + 1400, y: 790), CGPoint(x: 3200 + 450, y: 1000), CGPoint(x: 3200 + 2000, y: 790),
        CGPoint(x: 6400 + 800, y: 790), CGPoint(x: 6400 + 2000, y: 790)
    ]

    // MARK: stairs (plan-space rects, each links floor `stairLo[i]` with `stairLo[i] + 1` at the same spot)

    static let stairs: [CGRect] = [
        CGRect(x: 950, y: 175, width: 100, height: 150),
        CGRect(x: 225, y: 175, width: 100, height: 150),
        CGRect(x: 1150, y: 1000, width: 100, height: 160),
        CGRect(x: 2250, y: 175, width: 100, height: 150)
    ]
    static let stairLo: [Int] = [0, 0, 1, 1]

    static func stairRect(_ i: Int, floor: Int) -> CGRect { stairs[i].offsetBy(dx: CGFloat(floor) * off, dy: 0) }

    static func stairAt(_ p: CGPoint) -> (Int, Int)? {
        for i in stairs.indices {
            if stairRect(i, floor: stairLo[i]).contains(p) { return (i, stairLo[i]) }
            if stairRect(i, floor: stairLo[i] + 1).contains(p) { return (i, stairLo[i] + 1) }
        }
        return nil
    }

    // MARK: solids + destruction

    static let origBase: [CGRect] = layout.walls + props.map { $0.r }
    static var baseSolid: [CGRect] = origBase
    static var solid: [CGRect] = origBase + layout.doors
    static var solidKind: [PropKind?] = layout.walls.map { _ -> PropKind? in nil } + props.map { Optional($0.k) } + layout.doors.map { _ -> PropKind? in nil }
    static var solidMat: [WallMat] = layout.mats + props.map { TMap.propMat($0.k) } + layout.doors.map { _ -> WallMat in .wood }
    static let maxHP: [CGFloat] = layout.walls.map { min($0.width, $0.height) <= 25.01 ? 110 : -1 } + props.map { propHP($0.k) }
    static var hp: [CGFloat] = maxHP
    static var broken: [Int] = []          // pending events for the 3D scene
    static var brokenAll: [Int] = []       // everything broken this round (radar overlay)
    static var breaches: [CGRect] = []     // pending events for bot AI
    static var resetTick = 0
    /// solid indices per floor (static by original position) so collision / LOS / bullets only test the current floor
    static let floorIdx: [[Int]] = {
        var f: [[Int]] = [[], [], []]
        for (k, r) in (origBase + layout.doors).enumerated() { f[floorOfX(r.midX)].append(k) }
        return f
    }()
    static let gone = CGRect(x: -9999, y: -9999, width: 1, height: 1)

    static var doorOpen: [CGFloat] = [CGFloat](repeating: 0, count: layout.doors.count)
    static var doorWant: [Bool] = [Bool](repeating: false, count: layout.doors.count)
    static var doorHold: [CGFloat] = [CGFloat](repeating: 0, count: layout.doors.count)

    static func refreshDoors() {
        let b = baseSolid.count
        for i in doors.indices { solid[b + i] = doorOpen[i] > 0.8 ? gone : doors[i] }
    }

    static func resetDoors() {
        for i in doors.indices { doorOpen[i] = 0; doorWant[i] = false; doorHold[i] = 0 }
        refreshDoors()
    }

    /// applies damage to a destructible solid; true when it just broke
    @discardableResult
    static func hit(_ k: Int, _ amt: CGFloat) -> Bool {
        guard k >= 0, k < hp.count, hp[k] > 0 else { return false }
        hp[k] -= amt
        if hp[k] <= 0 { destroy(k); return true }
        return false
    }

    static func destroy(_ k: Int) {
        guard k < baseSolid.count, baseSolid[k] != gone else { return }
        let r = origBase[k]
        baseSolid[k] = gone
        solid[k] = gone
        hp[k] = 0
        broken.append(k)
        brokenAll.append(k)
        breaches.append(r)
        TNav.refresh(r)
    }

    static func blast(_ c: CGPoint, radius: CGFloat, dmg: CGFloat) {
        let fl = floorOf(c)
        for k in 0..<baseSolid.count where hp[k] > 0 {
            let r = baseSolid[k]
            if floorOfX(r.midX) != fl { continue }
            let d = rectDist(r, c)
            if d < radius { hit(k, dmg * (1 - d / radius) + 8) }
        }
    }

    static func resetDestruction() {
        var any = false
        for k in 0..<baseSolid.count where baseSolid[k] == gone { baseSolid[k] = origBase[k]; solid[k] = origBase[k]; any = true }
        hp = maxHP
        broken = []
        brokenAll = []
        breaches = []
        if any { TNav.rebuild(); resetTick += 1 }
        refreshDoors()
    }

    static func rectDist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: sites + spawns (T = foyer on the ground floor, CT = dining room)

    static let siteA = R(0, 1450, 1100, 350, 300)
    static let siteB = R(2, 2000, 1100, 350, 300)
    static let atkSpawn: [CGPoint] = [CGPoint(x: 3200 + 1220, y: 1560), CGPoint(x: 3200 + 1300, y: 1560), CGPoint(x: 3200 + 1380, y: 1560), CGPoint(x: 3200 + 1460, y: 1560), CGPoint(x: 3200 + 1340, y: 1480)]
    static let defSpawn: [CGPoint] = [CGPoint(x: 3200 + 1650, y: 480), CGPoint(x: 3200 + 1730, y: 480), CGPoint(x: 3200 + 1810, y: 480), CGPoint(x: 3200 + 1890, y: 480), CGPoint(x: 3200 + 1770, y: 560)]
    static let hubZone = R(1, 1100, 700, 400, 200)

    static func site(_ i: Int) -> CGRect { i == 0 ? siteA : siteB }

    static func los(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if floorOf(a) != floorOf(b) { return false }
        for k in floorIdx[floorOf(a)] where solidMat[k] != .glass && tSegT(a, b, solid[k]) != nil { return false }
        return true
    }

    static func rayDist(_ from: CGPoint, _ ang: CGFloat, _ maxD: CGFloat) -> CGFloat {
        let b = CGPoint(x: from.x + cos(ang) * maxD, y: from.y + sin(ang) * maxD)
        var best: CGFloat = 1
        for k in floorIdx[floorOf(from)] where solidMat[k] != .glass { if let t = tSegT(from, b, solid[k]), t < best { best = t } }
        return maxD * best
    }

    static func push(_ p: inout CGPoint, _ r: CGFloat) {
        let fl = floorOf(p)
        let o = origin(fl)
        p.x = min(max(o + r, p.x), o + W - r)
        p.y = min(max(r, p.y), H - r)
        for k in floorIdx[fl] {
            let o = solid[k]
            let cx = min(max(p.x, o.minX), o.maxX)
            let cy = min(max(p.y, o.minY), o.maxY)
            let dx = p.x - cx, dy = p.y - cy
            let d = (dx * dx + dy * dy).squareRoot()
            if d < r {
                if d > 0.001 { p.x += dx / d * (r - d); p.y += dy / d * (r - d) }
                else { p.y -= r }
            }
        }
    }

    static func inSolid(_ p: CGPoint) -> Bool { solid.contains { $0.contains(p) } }
}
