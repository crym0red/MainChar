import SwiftUI
import UIKit

// MARK: - Persisted stats

struct TacData: Codable, Hashable {
    var wins = 0
    var losses = 0
    var kills = 0
    var rating = 1000
    var sx: TacSeasonData? = nil
}

// MARK: - Geometry

private func tSegT(_ a: CGPoint, _ b: CGPoint, _ r: CGRect) -> CGFloat? {
    var t0: CGFloat = 0
    var t1: CGFloat = 1
    let d: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(b.x - a.x, a.x, r.minX, r.maxX), (b.y - a.y, a.y, r.minY, r.maxY)]
    for (p, q, lo, hi) in d {
        if abs(p) < 1e-9 {
            if q < lo || q > hi { return nil }
        } else {
            var ta = (lo - q) / p
            var tb = (hi - q) / p
            if ta > tb { swap(&ta, &tb) }
            t0 = max(t0, ta)
            t1 = min(t1, tb)
            if t0 > t1 { return nil }
        }
    }
    return t0
}

private func tDist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

private func tAngDiff(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    var d = a - b
    while d > .pi { d -= 2 * .pi }
    while d < -.pi { d += 2 * .pi }
    return d
}

private func tPointSeg(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let l2 = dx * dx + dy * dy
    if l2 < 1e-6 { return tDist(p, a) }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2))
    return tDist(p, CGPoint(x: a.x + dx * t, y: a.y + dy * t))
}

// MARK: - Map

enum PropKind { case bed, couch, table, counter, crate, car, shelf, barrel, sandbag, tv, plant }

struct TProp {
    let r: CGRect
    let k: PropKind
}

struct TRoom {
    let name: String
    let r: CGRect
    let mat: Int
}

enum WallMat { case brick, concrete, wood, glass }

enum TMap {
    static let floorW: CGFloat = 3000
    static let off: CGFloat = 3200
    static let W: CGFloat = 3000
    static let H: CGFloat = 1800
    static let th: CGFloat = 14
    static let wallH: CGFloat = 80
    static let eyeH: CGFloat = 54

    static func floorOf(_ p: CGPoint) -> Int { p.x >= off ? 1 : 0 }

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

    static let walkable: [(String, CGRect, Int)] = [
        ("T Spawn", CGRect(x: 150, y: 100, width: 500, height: 350), 0),
        ("Upper Lane", CGRect(x: 650, y: 150, width: 2000, height: 200), 1),
        ("B Run", CGRect(x: 2450, y: 350, width: 350, height: 750), 1),
        ("B Site", CGRect(x: 2200, y: 1100, width: 650, height: 550), 0),
        ("West Ramp", CGRect(x: 250, y: 450, width: 300, height: 950), 1),
        ("A Site", CGRect(x: 100, y: 1400, width: 700, height: 350), 0),
        ("A Link", CGRect(x: 800, y: 1500, width: 500, height: 200), 1),
        ("CT Spawn", CGRect(x: 1300, y: 1450, width: 500, height: 300), 0),
        ("CT to B", CGRect(x: 1800, y: 1500, width: 400, height: 200), 1),
        ("Mid", CGRect(x: 1150, y: 350, width: 350, height: 1100), 1),
        ("Catwalk", CGRect(x: 550, y: 900, width: 600, height: 200), 1),
        ("Suicide", CGRect(x: 1500, y: 1000, width: 700, height: 250), 1),
        ("Short A", CGRect(x: 800, y: 1100, width: 350, height: 400), 1)
    ]

    static let layout: (walls: [CGRect], mats: [WallMat], doors: [CGRect]) = {
        let cell: CGFloat = 50
        let cols = Int(W / cell), rows = Int(H / cell)
        var blocked = [Bool](repeating: true, count: cols * rows)
        for wk in walkable {
            for c in 0..<cols {
                for rw in 0..<rows {
                    let p = CGPoint(x: (CGFloat(c) + 0.5) * cell, y: (CGFloat(rw) + 0.5) * cell)
                    if wk.1.contains(p) { blocked[rw * cols + c] = false }
                }
            }
        }
        var active: [String: (c0: Int, c1: Int, r0: Int)] = [:]
        var rects: [CGRect] = []
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
                rects.append(CGRect(x: CGFloat(a.c0) * cell, y: CGFloat(a.r0) * cell, width: CGFloat(a.c1 - a.c0 + 1) * cell, height: CGFloat(rw - a.r0) * cell))
                active[k] = nil
            }
            for (k, v) in cur where active[k] == nil { active[k] = (v.0, v.1, rw) }
        }
        rects.sort { $0.minY != $1.minY ? $0.minY < $1.minY : $0.minX < $1.minX }
        var m: [WallMat] = []
        for i in rects.indices { m.append(i % 3 == 0 ? .concrete : .brick) }
        let d: [CGRect] = [
            CGRect(x: 1150, y: 650, width: 350, height: 14),
            CGRect(x: 250, y: 700, width: 300, height: 14),
            CGRect(x: 2450, y: 700, width: 350, height: 14)
        ]
        return (rects, m, d)
    }()

    static let walls: [CGRect] = layout.walls
    static let wallMats: [WallMat] = layout.mats
    static let doors: [CGRect] = layout.doors

    static let rooms: [TRoom] = [
        TRoom(name: "T Spawn", r: CGRect(x: 150, y: 100, width: 500, height: 350), mat: 0),
        TRoom(name: "Upper Lane", r: CGRect(x: 650, y: 150, width: 2000, height: 200), mat: 1),
        TRoom(name: "B Run", r: CGRect(x: 2450, y: 350, width: 350, height: 750), mat: 1),
        TRoom(name: "B Site", r: CGRect(x: 2200, y: 1100, width: 650, height: 550), mat: 0),
        TRoom(name: "West Ramp", r: CGRect(x: 250, y: 450, width: 300, height: 950), mat: 1),
        TRoom(name: "A Site", r: CGRect(x: 100, y: 1400, width: 700, height: 350), mat: 0),
        TRoom(name: "A Link", r: CGRect(x: 800, y: 1500, width: 500, height: 200), mat: 1),
        TRoom(name: "CT Spawn", r: CGRect(x: 1300, y: 1450, width: 500, height: 300), mat: 0),
        TRoom(name: "CT to B", r: CGRect(x: 1800, y: 1500, width: 400, height: 200), mat: 1),
        TRoom(name: "Mid", r: CGRect(x: 1150, y: 350, width: 350, height: 1100), mat: 1),
        TRoom(name: "Catwalk", r: CGRect(x: 550, y: 900, width: 600, height: 200), mat: 1),
        TRoom(name: "Suicide", r: CGRect(x: 1500, y: 1000, width: 700, height: 250), mat: 1),
        TRoom(name: "Short A", r: CGRect(x: 800, y: 1100, width: 350, height: 400), mat: 1)
    ]

    static func roomName(_ p: CGPoint) -> String {
        for r in rooms where r.r.contains(p) { return r.name }
        return "Outside"
    }

    static let props: [TProp] = {
        let l: [TProp] = [
            TProp(r: CGRect(x: 170, y: 120, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 590, y: 130, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 1000, y: 300, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 1700, y: 160, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 2000, y: 300, width: 100, height: 22), k: .sandbag),
            TProp(r: CGRect(x: 2250, y: 200, width: 150, height: 70), k: .car),
            TProp(r: CGRect(x: 260, y: 950, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 450, y: 1150, width: 90, height: 22), k: .sandbag),
            TProp(r: CGRect(x: 500, y: 600, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 800, y: 920, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 260, y: 1600, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 600, y: 1550, width: 80, height: 80), k: .crate),
            TProp(r: CGRect(x: 700, y: 1690, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 850, y: 1250, width: 100, height: 22), k: .sandbag),
            TProp(r: CGRect(x: 1060, y: 1350, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 1000, y: 1550, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 1320, y: 1470, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 1720, y: 1470, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 1950, y: 1500, width: 22, height: 70), k: .sandbag),
            TProp(r: CGRect(x: 1180, y: 800, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 1400, y: 1000, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 1200, y: 1250, width: 100, height: 22), k: .sandbag),
            TProp(r: CGRect(x: 1300, y: 500, width: 140, height: 40), k: .counter),
            TProp(r: CGRect(x: 1700, y: 1020, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 1950, y: 1180, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 2480, y: 500, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 2650, y: 900, width: 90, height: 22), k: .sandbag),
            TProp(r: CGRect(x: 2250, y: 1150, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 2700, y: 1200, width: 80, height: 80), k: .crate),
            TProp(r: CGRect(x: 2400, y: 1580, width: 70, height: 70), k: .crate),
            TProp(r: CGRect(x: 2700, y: 1500, width: 120, height: 70), k: .car),
            TProp(r: CGRect(x: 2250, y: 1550, width: 40, height: 40), k: .barrel)
        ]
        return l
    }()

    static let rugs: [(CGRect, Color)] = []

    static let packPos: [CGPoint] = [CGPoint(x: 400, y: 1000), CGPoint(x: 950, y: 1000), CGPoint(x: 1320, y: 1150), CGPoint(x: 2000, y: 1100), CGPoint(x: 2600, y: 800), CGPoint(x: 1050, y: 1620)]

    static let stairs: [CGRect] = []

    static func stairRect(_ i: Int, floor: Int) -> CGRect { floor == 0 ? stairs[i] : stairs[i].offsetBy(dx: off, dy: 0) }

    static func stairAt(_ p: CGPoint) -> (Int, Int)? {
        for i in stairs.indices {
            if stairs[i].contains(p) { return (i, 0) }
            if stairRect(i, floor: 1).contains(p) { return (i, 1) }
        }
        return nil
    }

    static let baseSolid: [CGRect] = layout.walls + props.map { $0.r }
    static var solid: [CGRect] = baseSolid + layout.doors
    static var solidKind: [PropKind?] = layout.walls.map { _ -> PropKind? in nil } + props.map { Optional($0.k) } + layout.doors.map { _ -> PropKind? in nil }
    static var solidMat: [WallMat] = layout.mats + props.map { TMap.propMat($0.k) } + layout.doors.map { _ -> WallMat in .wood }
    static var doorOpen: [CGFloat] = [CGFloat](repeating: 0, count: layout.doors.count)
    static var doorWant: [Bool] = [Bool](repeating: false, count: layout.doors.count)
    static var doorHold: [CGFloat] = [CGFloat](repeating: 0, count: layout.doors.count)

    static func refreshDoors() {
        let b = baseSolid.count
        for i in doors.indices { solid[b + i] = doorOpen[i] > 0.8 ? CGRect(x: -9999, y: -9999, width: 1, height: 1) : doors[i] }
    }

    static func resetDoors() {
        for i in doors.indices { doorOpen[i] = 0; doorWant[i] = false; doorHold[i] = 0 }
        refreshDoors()
    }

    static func rectDist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
    static let siteA = CGRect(x: 250, y: 1450, width: 300, height: 250)
    static let siteB = CGRect(x: 2350, y: 1300, width: 300, height: 250)
    static let atkSpawn: [CGPoint] = [CGPoint(x: 250, y: 200), CGPoint(x: 330, y: 200), CGPoint(x: 410, y: 200), CGPoint(x: 490, y: 200), CGPoint(x: 290, y: 290)]
    static let defSpawn: [CGPoint] = [CGPoint(x: 1400, y: 1560), CGPoint(x: 1480, y: 1560), CGPoint(x: 1560, y: 1560), CGPoint(x: 1640, y: 1560), CGPoint(x: 1520, y: 1640)]

    static func site(_ i: Int) -> CGRect { i == 0 ? siteA : siteB }

    static func los(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if floorOf(a) != floorOf(b) { return false }
        for k in solid.indices where solidMat[k] != .glass && tSegT(a, b, solid[k]) != nil { return false }
        return true
    }

    static func rayDist(_ from: CGPoint, _ ang: CGFloat, _ maxD: CGFloat) -> CGFloat {
        let b = CGPoint(x: from.x + cos(ang) * maxD, y: from.y + sin(ang) * maxD)
        var best: CGFloat = 1
        for k in solid.indices where solidMat[k] != .glass { if let t = tSegT(from, b, solid[k]), t < best { best = t } }
        return maxD * best
    }

    static func push(_ p: inout CGPoint, _ r: CGFloat) {
        p.x = min(max(r, p.x), W - r)
        p.y = min(max(r, p.y), H - r)
        for o in solid {
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

// MARK: - Navigation (A* on a coarse grid)

enum TNav {
    static let cell: CGFloat = 40
    static let cols = Int(TMap.W / cell) + 1
    static let rows = Int(TMap.H / cell) + 1
    static let blocked: [Bool] = {
        var b = [Bool](repeating: false, count: cols * rows)
        for c in 0..<cols {
            for r in 0..<rows {
                let p = CGPoint(x: CGFloat(c) * cell + cell / 2, y: CGFloat(r) * cell + cell / 2)
                if p.x > TMap.W - 20 || p.y > TMap.H - 20 { b[r * cols + c] = true; continue }
                for o in TMap.baseSolid where o.insetBy(dx: -18, dy: -18).contains(p) { b[r * cols + c] = true; break }
            }
        }
        return b
    }()

    static func idx(_ p: CGPoint) -> Int {
        let c = min(cols - 1, max(0, Int(p.x / cell)))
        let r = min(rows - 1, max(0, Int(p.y / cell)))
        return r * cols + c
    }
    static func center(_ i: Int) -> CGPoint { CGPoint(x: CGFloat(i % cols) * cell + cell / 2, y: CGFloat(i / cols) * cell + cell / 2) }

    static func nearestFree(_ i: Int) -> Int {
        if !blocked[i] { return i }
        let c0 = i % cols, r0 = i / cols
        for rad in 1...5 {
            for dc in -rad...rad {
                for dr in -rad...rad {
                    let c = c0 + dc, r = r0 + dr
                    if c < 0 || r < 0 || c >= cols || r >= rows { continue }
                    if !blocked[r * cols + c] { return r * cols + c }
                }
            }
        }
        return i
    }

    static func clear(_ a: CGPoint, _ b: CGPoint) -> Bool {
        for o in TMap.baseSolid where tSegT(a, b, o.insetBy(dx: -15, dy: -15)) != nil { return false }
        return true
    }

    static func path(_ from: CGPoint, _ to: CGPoint) -> [CGPoint] {
        let s = nearestFree(idx(from))
        let g = nearestFree(idx(to))
        if s == g { return [to] }
        let n = cols * rows
        var gs = [Int](repeating: Int.max, count: n)
        var came = [Int](repeating: -1, count: n)
        var closed = [Bool](repeating: false, count: n)
        var open: [Int] = [s]
        gs[s] = 0
        let gc = g % cols, gr = g / cols
        func h(_ i: Int) -> Int {
            let dx = abs(i % cols - gc), dy = abs(i / cols - gr)
            return 10 * (dx + dy) - 6 * min(dx, dy)
        }
        var found = false
        var guardN = 0
        while !open.isEmpty && guardN < 4000 {
            guardN += 1
            var bi = 0
            var bf = Int.max
            for (k, o) in open.enumerated() {
                let f = gs[o] + h(o)
                if f < bf { bf = f; bi = k }
            }
            let cur = open.remove(at: bi)
            if cur == g { found = true; break }
            if closed[cur] { continue }
            closed[cur] = true
            let c = cur % cols, r = cur / cols
            for dc in -1...1 {
                for dr in -1...1 {
                    if dc == 0 && dr == 0 { continue }
                    let nc = c + dc, nr = r + dr
                    if nc < 0 || nr < 0 || nc >= cols || nr >= rows { continue }
                    let ni = nr * cols + nc
                    if blocked[ni] || closed[ni] { continue }
                    if dc != 0 && dr != 0 && (blocked[r * cols + nc] || blocked[nr * cols + c]) { continue }
                    let cost = gs[cur] + (dc != 0 && dr != 0 ? 14 : 10)
                    if cost < gs[ni] {
                        gs[ni] = cost
                        came[ni] = cur
                        open.append(ni)
                    }
                }
            }
        }
        guard found else { return [to] }
        var cells: [Int] = []
        var k = g
        while k != -1 { cells.append(k); k = came[k] }
        cells.reverse()
        var pts = cells.map { center($0) }
        pts.append(to)
        // string pulling
        var out: [CGPoint] = []
        var anchor = from
        var i = 0
        while i < pts.count {
            var j = pts.count - 1
            while j > i && !clear(anchor, pts[j]) { j -= 1 }
            out.append(pts[j])
            anchor = pts[j]
            i = j + 1
        }
        return out
    }
}

// MARK: - Entities

final class TPlayer {
    let id: Int
    var team: Int
    let name: String
    let handle: String
    let emoji: String
    let isPlayer: Bool
    var pos = CGPoint.zero
    var hp: CGFloat = 100
    var alive = true
    var aim: CGFloat = 0
    var gun = "pistol"
    var mag = 12
    var spare = 2
    var nades = 1
    var smokes = 1
    var flashes = 1
    var armor: CGFloat = 100
    var blind: CGFloat = 0
    var pingCd: CGFloat = 0
    var reloadT: CGFloat = 0
    var fireCd: CGFloat = 0
    var flash: CGFloat = 0
    var hurt: CGFloat = 0
    var kills = 0
    var path: [CGPoint] = []
    var pathT: CGFloat = 0
    var pathDest = CGPoint.zero
    var targetID = -1
    var reactT: CGFloat = 0
    var seeT: CGFloat = 0
    var lastSeen = CGPoint.zero
    var hunt: CGFloat = 0
    var strafe: CGFloat = 1
    var strafeT: CGFloat = 0
    var role = 0
    var rank = 0   // 0 fighter, 1 staff, 2 admin
    var site = 0
    var spotted = false
    var seenEver = false
    var onStair = false
    var crouch = false
    var hiding = false
    var hideT: CGFloat = 0
    var cover: CGPoint? = nil
    var noiseT: CGFloat = 0
    var respawn: CGFloat = 0
    var money = 800
    var armorKind = 0
    var ladder = 0
    var roam = CGPoint.zero
    var altGun = "pistol"
    var altMag = 15
    var altSpare = 99

    init(id: Int, team: Int, name: String, handle: String, emoji: String, isPlayer: Bool) {
        self.id = id; self.team = team; self.name = name; self.handle = handle; self.emoji = emoji; self.isPlayer = isPlayer
    }
}

final class TacticalEngine {
    struct Bullet {
        var pos: CGPoint
        var vel: CGVector
        var dmg: CGFloat
        var life: CGFloat
        var owner: Int
        var team: Int
        var inK = -1
        var pens = 0
    }
    struct Nade {
        var pos: CGPoint
        var vel: CGVector
        var fuse: CGFloat
        var owner: Int
        var team: Int
        var kind = 0
    }
    struct Boom {
        var pos: CGPoint
        var life: CGFloat
        var r: CGFloat
    }
    struct Smoke {
        var pos: CGPoint
        var life: CGFloat
        var r: CGFloat
    }
    struct Ping {
        var pos: CGPoint
        var text: String
        var life: CGFloat
    }
    struct Pack {
        var pos: CGPoint
        var taken: Bool
    }
    struct Pop {
        var pos: CGPoint
        var text: String
        var life: CGFloat
        var color: Color
    }
    struct Feed {
        var text: String
        var life: CGFloat
        var mine: Bool
        var k = ""
        var v = ""
        var kTeam = 0
        var gun = "pistol"
        var head = false
    }

    var players: [TPlayer] = []
    var bullets: [Bullet] = []
    var nades: [Nade] = []
    var smokeClouds: [Smoke] = []
    var pings: [Ping] = []
    var packs: [Pack] = []
    var booms: [Boom] = []
    var pops: [Pop] = []
    var feed: [Feed] = []
    var sprites: [String: UIImage] = [:]
    private let dummyMe = TPlayer(id: 0, team: 0, name: "You", handle: "you", emoji: "", isPlayer: true)
    var me: TPlayer { players.first ?? dummyMe }

    var phase = 0              // 0 prep, 1 live, 2 planted, 3 round end, 4 match over
    var timer: CGFloat = 0
    var scores = [0, 0]
    var round = 0
    var atkTeam = 0
    let target = 3
    var planted = false
    var bombPos = CGPoint.zero
    var bombSite = 0
    var bombT: CGFloat = 0
    var atkSite = 0
    var plantProg: CGFloat = 0
    var defuseProg: CGFloat = 0
    var banner = ""
    var bannerT: CGFloat = 0
    var diff = 1
    var move = CGVector.zero
    var aimIn: CGFloat? = nil
    var autoAim = true
    var autoFire = true
    var autoTarget = -1
    var firing = false
    var actHeld = false
    var wantNade = false
    var wantSmoke = false
    var wantFlash = false
    var scoped = false
    var pitch: CGFloat = 0
    var fp = false
    var view3D = true
    var project: ((CGPoint, CGFloat) -> CGPoint?)? = nil
    var lookDelta: CGFloat = 0
    var hitT: CGFloat = 0
    var wantReload = false
    var wantSwap = false
    var buyT: CGFloat = 0
    var buyOpen = false
    var theme = 0
    var killFx = "fx_none"
    var charm = "charm_none"
    var fxId = "fx_none"
    var fxT: CGFloat = 0
    var fxSerial = 0
    var cpProg: [CGFloat] = [0, 0, 0]
    var cpT: CGFloat = 0
    var rivalScore: Int { gameMode == 4 ? (scores.dropFirst().max() ?? 0) : scores[1] }
    var cpZones: [CGRect] { [TMap.site(0), TMap.site(1), CGRect(x: 1150, y: 700, width: 350, height: 300)] }
    var gameMode = 0
    var killTarget = 30
    struct Tag { var pos: CGPoint; var team: Int; var life: CGFloat }
    var tags: [Tag] = []
    var fast = false
    var paused = false
    var won = false
    var last: Date? = nil
    var time: CGFloat = 0
    var spotT: CGFloat = 0
    var shake: CGFloat = 0
    var recoil: CGFloat = 0
    var jumpT: CGFloat = 0
    var kick: CGFloat = 0
    var moving: Bool { hypot(move.dx, move.dy) > 0.1 }
    var myGun = "pistol"
    var kills: Int { me.kills }

    private let react: [CGFloat] = [0.55, 0.33, 0.18]
    private let turn: [CGFloat] = [5, 8, 12]
    private let aimErr: [CGFloat] = [0.13, 0.07, 0.035]

    func setup(gun: String, diff: Int, mode: Int = 0) {
        self.diff = diff
        gameMode = mode
        tags = []
        myGun = gun
        let names: [(String, String, String)] = TacRoster.pick(9)
        players = [TPlayer(id: 0, team: 0, name: "You", handle: "you", emoji: "", isPlayer: true)]
        for i in 0..<9 {
            let bp = TPlayer(id: i + 1, team: i < 4 ? 0 : 1, name: names[i].0, handle: names[i].1, emoji: names[i].2, isPlayer: false)
            bp.rank = TacRoster.rank(of: names[i].1)
            players.append(bp)
        }
        scores = [0, 0]
        killTarget = mode == 4 ? 20 : (mode == 5 ? 100 : 30)
        if mode == 4 {
            for p in players { p.team = p.id }
            scores = Array(repeating: 0, count: 10)
        }
        round = 0
        phase = 0
        over = false
        startRound()
    }
    var over = false

    private func gunPick() -> String {
        let r = Int.random(in: 0..<100)
        if r < 6 { return "awp" }
        if r < 40 { return ["rifle", "ak", "m4"].randomElement()! }
        if r < 68 { return ["smg", "mp7", "p90"].randomElement()! }
        if r < 82 { return ["shotgun", "pump"].randomElement()! }
        return ["pistol", "eagle"].randomElement()!
    }

    func startRound() {
        round += 1
        atkTeam = round % 2 == 1 ? 0 : 1
        atkSite = Int.random(in: 0...1)
        planted = false
        plantProg = 0
        defuseProg = 0
        bullets = []; nades = []; booms = []; pops = []
        smokeClouds = []; pings = []
        TMap.resetDoors()
        lookDelta = 0
        packs = TMap.packPos.map { Pack(pos: $0, taken: false) }
        var ai = 0, di = 0
        var defBots = 0
        cpProg = [0, 0, 0]
        cpT = 1.5
        for p in players {
            let survived = p.alive
            p.hp = 100
            p.alive = true
            p.path = []
            p.targetID = -1
            p.hunt = 0
            p.reloadT = 0
            p.fireCd = 0
            p.spotted = false
            p.seenEver = false
            p.nades = 1
            p.smokes = 1
            p.flashes = 1
            if p.isPlayer { scoped = false; pitch = 0 }
            if gameMode != 0 { p.armor = 100; p.armorKind = 1 }
            p.blind = 0
            p.pingCd = 0
            p.crouch = false
            p.hiding = false
            p.cover = nil
            p.noiseT = 0
            let atk = p.team == atkTeam
            let spot = atk ? TMap.atkSpawn[ai % 5] : TMap.defSpawn[di % 5]
            if atk { ai += 1 } else { di += 1 }
            p.pos = spot
            p.aim = atan2(TMap.H / 2 - spot.y, TMap.floorW / 2 - spot.x)
            p.respawn = 0
            if gameMode == 0 {
                if round == 1 { p.money = 800; p.armor = 0; p.armorKind = 0; p.gun = "pistol" }
                else if !survived { p.armor = 0; p.armorKind = 0; p.gun = "pistol" }
                p.mag = TGuns.get(p.gun).mag
                p.spare = TWeapons.isPistol(p.gun) ? 99 : 2
                if p.isPlayer && round == 1 { p.altGun = "pistol"; p.altMag = 15; p.altSpare = 99 }
            } else {
                p.gun = p.isPlayer ? myGun : gunPick()
                if gameMode == 3 { p.gun = TWeapons.ladder[0]; p.ladder = 0 }
                p.mag = TGuns.get(p.gun).mag
                p.spare = TWeapons.isPistol(p.gun) ? 99 : 2
                if p.isPlayer {
                    p.altGun = p.gun == "pistol" ? "eagle" : "pistol"
                    p.altMag = TGuns.get(p.altGun).mag
                    p.altSpare = 99
                }
            }
            p.role = 0
            if !atk && !p.isPlayer { p.site = defBots % 2; defBots += 1 }
            p.site = atk ? atkSite : p.site
        }
        if let planter = players.filter({ $0.team == atkTeam && !$0.isPlayer }).randomElement() { planter.role = 1 }
        phase = 0
        timer = 4
        banner = me.team == atkTeam ? "PREPARE TO ATTACK" : "PREPARE TO DEFEND"
        if gameMode != 0 {
            atkTeam = 0
            banner = TWeapons.modeNames[gameMode]
            tags = []
            for p in players { respawnPlayer(p) }
        } else {
            timer = 6
            buyT = 16
            buyOpen = me.alive
            for p in players where !p.isPlayer { botBuy(p) }
            banner = "BLUE TEAM vs ORANGE TEAM"
        }
        bannerT = 3.5
    }

    // MARK: sim

    func step(_ now: Date) {
        guard let l = last else { last = now; return }
        let dt = min(0.05, CGFloat(now.timeIntervalSince(l)))
        last = now
        if paused || over { return }
        let n = (!me.alive && fast && phase < 3) ? 3 : 1
        for _ in 0..<n { update(dt) }
    }

    private func update(_ dt: CGFloat) {
        time += dt
        bannerT = max(0, bannerT - dt)
        hitT = max(0, hitT - dt)
        shake = max(0, shake - dt * 30)
        recoil = max(0, recoil - dt * 2.4)
        jumpT = max(0, jumpT - dt)
        fxT = max(0, fxT - dt * 1.0)
        buyT = max(0, buyT - dt)
        if buyT <= 0 { buyOpen = false }
        kick = max(0, kick - dt * (22 + kick * 3))
        for i in feed.indices { feed[i].life -= dt }
        feed.removeAll { $0.life <= 0 }
        for i in booms.indices { booms[i].life -= dt }
        booms.removeAll { $0.life <= 0 }
        for i in smokeClouds.indices { smokeClouds[i].life -= dt }
        smokeClouds.removeAll { $0.life <= 0 }
        for i in pings.indices { pings[i].life -= dt }
        pings.removeAll { $0.life <= 0 }
        for i in pops.indices { pops[i].life -= dt * 1.1 }
        pops.removeAll { $0.life <= 0 }
        for p in players { p.flash = max(0, p.flash - dt); p.hurt = max(0, p.hurt - dt); p.blind = max(0, p.blind - dt); p.noiseT = max(0, p.noiseT - dt) }

        if phase == 3 {
            timer -= dt
            moveProjectiles(dt)
            if timer <= 0 {
                if scores[0] >= target || scores[1] >= target {
                    phase = 4
                    over = true
                    won = scores[0] >= target
                } else { startRound() }
            }
            return
        }
        if phase == 0 {
            timer -= dt
            if timer <= 0 { phase = 1; timer = gameMode == 0 ? 100 : 240; banner = "GO"; bannerT = 1 }
            for p in players where !p.isPlayer { botLook(p, dt) }
            return
        }
        // live
        timer -= dt
        var planting = false
        var defusing = false
        updateDoors(dt)
        playerUpdate(dt, &planting, &defusing)
        for p in players where !p.isPlayer && p.alive { botThink(p, dt, &planting, &defusing) }
        for i in packs.indices where !packs[i].taken {
            for p in players where p.alive && p.hp < 100 && tDist(p.pos, packs[i].pos) < 24 {
                p.hp = min(100, p.hp + 40)
                packs[i].taken = true
                pop(p.pos, "+40", .green)
                break
            }
        }
        moveProjectiles(dt)
        for p in players where p.alive { stairCheck(p) }
        // spotting
        spotT -= dt
        if spotT <= 0 {
            spotT = 0.1
            for e in players where e.team != me.team {
                let was = e.spotted
                e.spotted = false
                e.pingCd = max(0, e.pingCd - 0.1)
                guard e.alive else { continue }
                for a in players where a.team == me.team && a.alive {
                    if tDist(a.pos, e.pos) < 900 && see(a.pos, e.pos) { e.spotted = true; e.seenEver = true; break }
                }
                if e.spotted && !was && e.pingCd <= 0 {
                    e.pingCd = 4
                    pings.append(Ping(pos: e.pos, text: TMap.roomName(e.pos), life: 3.5))
                    if pings.count > 6 { pings.removeFirst() }
                }
            }
        }
        if gameMode != 0 { dmTick(dt); return }
        // objectives
        if !planted {
            if planting { plantProg += dt } else { plantProg = max(0, plantProg - dt * 2) }
            if plantProg >= 3 {
                planted = true
                phase = 2
                bombT = 30
                bombSite = atkSite
                if let who = players.first(where: { $0.team == atkTeam && $0.alive && TMap.site(atkSite).contains($0.pos) }) { bombPos = who.pos }
                else { bombPos = CGPoint(x: TMap.site(atkSite).midX, y: TMap.site(atkSite).midY) }
                plantProg = 0
                banner = "BOMB PLANTED"
                bannerT = 2
                timer = bombT
            }
        } else {
            bombT -= dt
            timer = bombT
            if defusing { defuseProg += dt } else { defuseProg = 0 }
            if defuseProg >= 4 { endRound(winner: 1 - atkTeam, text: "BOMB DEFUSED"); return }
            if bombT <= 0 {
                booms.append(Boom(pos: bombPos, life: 0.8, r: 220))
                shake = 14
                endRound(winner: atkTeam, text: "BOMB DETONATED")
                return
            }
        }
        let atkAlive = players.filter { $0.team == atkTeam && $0.alive }.count
        let defAlive = players.filter { $0.team != atkTeam && $0.alive }.count
        if defAlive == 0 { endRound(winner: atkTeam, text: "DEFENDERS ELIMINATED"); return }
        if atkAlive == 0 && !planted { endRound(winner: 1 - atkTeam, text: "ATTACKERS ELIMINATED"); return }
        if !planted && timer <= 0 { endRound(winner: 1 - atkTeam, text: "TIME RAN OUT") }
    }

    // MARK: economy

    func price(_ id: String) -> Int {
        switch id {
        case "kev": return 650
        case "vest": return 1000
        case "spec": return 2000
        case "flashb": return 200
        case "smokeb": return 300
        case "fragb": return 300
        default: return TWeapons.w(id).price
        }
    }

    @discardableResult func buyItem(_ p: TPlayer, _ id: String) -> Bool {
        guard gameMode == 0, p.alive else { return false }
        let c = price(id)
        guard p.money >= c else { return false }
        switch id {
        case "kev": guard p.armorKind < 1 || p.armor < 50 else { return false }; p.armor = 100; p.armorKind = 1
        case "vest": guard p.armorKind < 2 || p.armor < 50 else { return false }; p.armor = 100; p.armorKind = 2
        case "spec": guard p.armorKind < 3 || p.armor < 75 else { return false }; p.armor = 150; p.armorKind = 3
        case "flashb": guard p.flashes < 2 else { return false }; p.flashes += 1
        case "smokeb": guard p.smokes < 1 else { return false }; p.smokes += 1
        case "fragb": guard p.nades < 1 else { return false }; p.nades += 1
        default:
            guard p.gun != id, p.altGun != id else { return false }
            if TWeapons.isPistol(id) {
                if TWeapons.isPistol(p.gun) { setGun(p, id) } else { p.altGun = id; p.altMag = TGuns.get(id).mag; p.altSpare = 99 }
            } else {
                if TWeapons.isPistol(p.gun) { p.altGun = p.gun; p.altMag = p.mag; p.altSpare = 99 }
                setGun(p, id)
            }
        }
        p.money -= c
        return true
    }

    private func botBuy(_ p: TPlayer) {
        if TWeapons.isPistol(p.gun) {
            let prim = TWeapons.all.filter { !TWeapons.isPistol($0.id) && $0.price <= p.money - (p.armorKind == 0 ? 650 : 0) && ($0.id != "awp" || Int.random(in: 0..<4) == 0) }
            if let w = prim.randomElement() { buyItem(p, w.id) }
            else if p.money >= 700 + 650, Int.random(in: 0..<2) == 0 { buyItem(p, "eagle") }
        }
        if p.armorKind == 0 || p.armor < 40 {
            if p.money >= 2400, Int.random(in: 0..<3) == 0 { buyItem(p, "spec") }
            else if p.money >= 1000 { buyItem(p, "vest") }
            else if p.money >= 650 { buyItem(p, "kev") }
        }
        if p.money >= 300, p.nades == 0 { buyItem(p, "fragb") }
        if p.money >= 300, p.smokes == 0 { buyItem(p, "smokeb") }
    }

    // MARK: deathmatch-style modes

    private func setGun(_ p: TPlayer, _ id: String) {
        p.gun = id
        p.mag = TGuns.get(id).mag
        p.spare = TWeapons.isPistol(id) ? 99 : 2
        p.reloadT = 0
    }

    private func respawnPlayer(_ p: TPlayer) {
        let list = p.id % 2 == 0 ? TMap.atkSpawn : TMap.defSpawn
        var best = list[0], bd: CGFloat = -1
        for c in list {
            var near = CGFloat.greatestFiniteMagnitude
            for e in players where e.alive && e.team != p.team { near = min(near, tDist(c, e.pos)) }
            near += CGFloat.random(in: 0...120)
            if near > bd { bd = near; best = c }
        }
        p.pos = CGPoint(x: best.x + CGFloat.random(in: -18...18), y: best.y + CGFloat.random(in: -18...18))
        p.hp = 100; p.armor = 100; p.alive = true; p.blind = 0; p.crouch = false
        p.path = []; p.targetID = -1; p.hunt = 0; p.reloadT = 0; p.fireCd = 0; p.hiding = false; p.cover = nil
        p.nades = 1; p.smokes = 1; p.flashes = 1
        p.aim = atan2(TMap.H / 2 - p.pos.y, TMap.floorW / 2 - p.pos.x)
        if gameMode == 3 { setGun(p, TWeapons.ladder[min(p.ladder, TWeapons.ladder.count - 1)]) }
        else { setGun(p, p.isPlayer ? myGun : gunPick()) }
        if p.isPlayer {
            scoped = false; pitch = 0
            p.altGun = p.gun == "pistol" ? "eagle" : "pistol"
            p.altMag = TGuns.get(p.altGun).mag
            p.altSpare = 99
        }
    }

    private func finishMatch(_ winner: Int) {
        phase = 4
        over = true
        won = winner == me.team
        banner = won ? "VICTORY" : "DEFEAT"
        bannerT = 3
    }

    private func dmTick(_ dt: CGFloat) {
        for p in players where !p.alive && p.respawn > 0 {
            p.respawn -= dt
            if p.respawn <= 0 { respawnPlayer(p) }
        }
        if gameMode == 2 {
            for i in tags.indices { tags[i].life -= dt }
            tags.removeAll { $0.life <= 0 }
            var rest: [Tag] = []
            for t in tags {
                var taken = false
                for p in players where p.alive && tDist(p.pos, t.pos) < 30 {
                    if p.team != t.team { scores[p.team] += 1; pop(t.pos, "CONFIRMED", .yellow) }
                    else { pop(t.pos, "DENIED", .red) }
                    taken = true
                    break
                }
                if !taken { rest.append(t) }
            }
            tags = rest
        }
        if gameMode == 3 {
            if let w = players.first(where: { $0.ladder >= TWeapons.ladder.count }) { finishMatch(w.team); return }
        } else if let wi = scores.firstIndex(where: { $0 >= killTarget }) {
            finishMatch(wi); return
        }
        if gameMode == 5 {
            let zs = cpZones
            for i in 0..<3 {
                var n0 = 0, n1 = 0
                for p in players where p.alive && zs[i].contains(p.pos) { if p.team == 0 { n0 += 1 } else { n1 += 1 } }
                let d = n0 - n1
                if d != 0 { cpProg[i] = max(-1, min(1, cpProg[i] + CGFloat(d.signum()) * dt * 0.22 * CGFloat(min(abs(d), 3)))) }
            }
            cpT -= dt
            if cpT <= 0 {
                cpT = 1.5
                for i in 0..<3 { if cpProg[i] >= 1 { scores[0] += 1 } else if cpProg[i] <= -1 { scores[1] += 1 } }
            }
        }
        if timer <= 0 {
            if gameMode == 3 {
                let a = players.filter { $0.team == 0 }.map { $0.ladder }.reduce(0, +)
                let b = players.filter { $0.team == 1 }.map { $0.ladder }.reduce(0, +)
                finishMatch(a >= b ? 0 : 1)
            } else { finishMatch(scores.firstIndex(of: scores.max() ?? 0) ?? 0) }
        }
    }

    private func swapGun(_ p: TPlayer) {
        guard gameMode != 3, p.reloadT <= 0 else { return }
        let g = p.gun, m = p.mag, s = p.spare
        p.gun = p.altGun; p.mag = p.altMag; p.spare = p.altSpare
        p.altGun = g; p.altMag = m; p.altSpare = s
        p.fireCd = 0.35
    }

    func see(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if !TMap.los(a, b) { return false }
        for s in smokeClouds where tPointSeg(s.pos, a, b) < s.r * 0.9 { return false }
        return true
    }

    private func endRound(winner: Int, text: String) {
        scores[winner] += 1
        for p in players { p.money = min(16000, p.money + (p.team == winner ? 3000 : 1900)) }
        phase = 3
        timer = 3.5
        let w = winner == me.team
        banner = (w ? "ROUND WON  " : "ROUND LOST  ") + text
        bannerT = 3.5
    }

    // MARK: player

    // MARK: doors + cover

    private func updateDoors(_ dt: CGFloat) {
        var changed = false
        for i in TMap.doors.indices {
            let d = TMap.doors[i]
            var botNear = false
            for p in players where p.alive && !p.isPlayer && TMap.floorOf(p.pos) == TMap.floorOf(CGPoint(x: d.midX, y: d.midY)) {
                if TMap.rectDist(d, p.pos) < 40 { botNear = true; break }
            }
            let meNear = me.alive && TMap.rectDist(d, me.pos) < 100
            if botNear { TMap.doorWant[i] = true; TMap.doorHold[i] = 1.2 }
            else if TMap.doorWant[i] {
                if meNear { TMap.doorHold[i] = max(TMap.doorHold[i], 2.5) } else {
                    TMap.doorHold[i] -= dt
                    if TMap.doorHold[i] <= 0 { TMap.doorWant[i] = false }
                }
            }
            let goal: CGFloat = TMap.doorWant[i] ? 1 : 0
            let was = TMap.doorOpen[i] > 0.8
            if TMap.doorOpen[i] < goal { TMap.doorOpen[i] = min(goal, TMap.doorOpen[i] + dt * 3.2) }
            else if TMap.doorOpen[i] > goal { TMap.doorOpen[i] = max(goal, TMap.doorOpen[i] - dt * 2.4) }
            if was != (TMap.doorOpen[i] > 0.8) { changed = true }
        }
        if changed { TMap.refreshDoors() }
    }

    func nearestDoor() -> Int? {
        guard me.alive else { return nil }
        var best: Int? = nil
        var bd: CGFloat = 46
        for i in TMap.doors.indices {
            let dd = TMap.rectDist(TMap.doors[i], me.pos)
            if dd < bd && TMap.floorOf(CGPoint(x: TMap.doors[i].midX, y: TMap.doors[i].midY)) == TMap.floorOf(me.pos) { bd = dd; best = i }
        }
        return best
    }

    func toggleDoor() {
        guard let i = nearestDoor() else { return }
        if TMap.doorWant[i] || TMap.doorOpen[i] > 0.5 { TMap.doorWant[i] = false; TMap.doorHold[i] = 0 }
        else { TMap.doorWant[i] = true; TMap.doorHold[i] = 3 }
    }

    func coverNear(_ p: TPlayer) -> Bool {
        for r in TMap.solid where r.minX > -5000 && TMap.rectDist(r, p.pos) < 26 { return true }
        return false
    }

    func toggleCover() {
        let p = me
        guard p.alive else { return }
        if p.crouch { p.crouch = false; return }
        if coverNear(p) { p.crouch = true }
    }

    private func coverSpot(_ p: TPlayer, _ threat: CGPoint) -> CGPoint? {
        let base = atan2(threat.y - p.pos.y, threat.x - p.pos.x)
        for rad in [44, 76, 120] as [CGFloat] {
            var best: CGPoint? = nil
            var bs: CGFloat = 1e9
            for k in 0..<12 {
                let a = base + CGFloat.pi + (CGFloat(k) / 12) * 6.283 - CGFloat.pi
                let c = CGPoint(x: p.pos.x + cos(a) * rad, y: p.pos.y + sin(a) * rad)
                if TMap.solid.contains(where: { $0.insetBy(dx: -15, dy: -15).contains(c) }) { continue }
                if TMap.los(c, threat) { continue }
                if !TMap.los(p.pos, c) { continue }
                let d = tDist(c, threat)
                if d < 90 { continue }
                let s = rad + (d > 420 ? 40 : 0)
                if s < bs { bs = s; best = c }
            }
            if best != nil { return best }
        }
        return nil
    }

    private func playerUpdate(_ dt: CGFloat, _ planting: inout Bool, _ defusing: inout Bool) {
        let p = me
        guard p.alive else { return }
        if p.crouch && !coverNear(p) { p.crouch = false }
        let sp: CGFloat = (p.crouch ? 88 : 170) * (scoped ? 0.6 : 1)
        var mv = move
        let tgt = autoAim ? pickTarget(p) : nil
        autoTarget = tgt?.id ?? -1
        var aligned = false
        if fp {
            let manual = abs(lookDelta) > 0.0005
            p.aim += lookDelta
            lookDelta = 0
            let fx = cos(p.aim), fy = sin(p.aim)
            mv = CGVector(dx: fx * (-move.dy) - fy * move.dx, dy: fy * (-move.dy) + fx * move.dx)
            if let e = tgt {
                let want = atan2(e.pos.y - p.pos.y, e.pos.x - p.pos.x)
                let off = abs(angWrap(want - p.aim))
                if !manual { p.aim = turnToward(p.aim, want, 9 * dt) }
                else if off < 0.4 { p.aim = turnToward(p.aim, want, 3 * dt) }
                aligned = abs(angWrap(want - p.aim)) < 0.09
            }
        } else if let a = aimIn { p.aim = a }
        else if let e = tgt {
            let want = atan2(e.pos.y - p.pos.y, e.pos.x - p.pos.x)
            p.aim = turnToward(p.aim, want, 13 * dt)
            aligned = abs(angWrap(want - p.aim)) < 0.09
        } else if hypot(mv.dx, mv.dy) > 0.2 {
            p.aim = turnToward(p.aim, atan2(mv.dy, mv.dx), 9 * dt)
        }
        p.pos.x += mv.dx * sp * dt
        p.pos.y += mv.dy * sp * dt
        TMap.push(&p.pos, 14)
        p.fireCd -= dt
        if wantReload { wantReload = false; startReload(p) }
        if wantSwap { wantSwap = false; swapGun(p) }
        if p.reloadT > 0 {
            p.reloadT -= dt
            if p.reloadT <= 0 { finishReload(p) }
        } else if (firing || (autoFire && aligned)) && p.fireCd <= 0 && !actHeld {
            if p.mag > 0 { shoot(p, 0) } else { startReload(p) }
        }
        if wantNade { wantNade = false; throwNade(p, p.aim, 420) }
        if wantFlash { wantFlash = false; throwNade(p, p.aim, 400, flash: true) }
        if wantSmoke { wantSmoke = false; throwNade(p, p.aim, 380, smoke: true) }
        if actHeld {
            if p.team == atkTeam && !planted && TMap.site(atkSite).contains(p.pos) && move == .zero { planting = true }
            if p.team != atkTeam && planted && tDist(p.pos, bombPos) < 46 && move == .zero { defusing = true }
        }
    }

    private func angWrap(_ x: CGFloat) -> CGFloat {
        var d = x
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    private func turnToward(_ cur: CGFloat, _ want: CGFloat, _ maxStep: CGFloat) -> CGFloat {
        let d = angWrap(want - cur)
        let s = min(abs(d), maxStep)
        return cur + (d < 0 ? -s : s)
    }

    private func pickTarget(_ p: TPlayer) -> TPlayer? {
        let range = TGuns.get(p.gun).range
        var best: TPlayer? = nil
        var bd: CGFloat = .greatestFiniteMagnitude
        for e in players where e.alive && e.team != p.team {
            let d = tDist(p.pos, e.pos)
            if d < range && d < bd && see(p.pos, e.pos) { bd = d; best = e }
        }
        return best
    }

    func startReload(_ p: TPlayer) {
        let g = TGuns.get(p.gun)
        guard p.reloadT <= 0, p.mag < g.mag, p.spare > 0 else { return }
        p.reloadT = g.reload
    }

    private func finishReload(_ p: TPlayer) {
        p.mag = TGuns.get(p.gun).mag
        if !TWeapons.isPistol(p.gun) { p.spare -= 1 }
    }

    private func shoot(_ p: TPlayer, _ err: CGFloat) {
        let g = TGuns.get(p.gun)
        let spd: CGFloat = 1100
        var muzzle: CGFloat = 20
        var sprd = g.spread + err
        if TWeapons.cls(p.gun) == "sniper" && !(p.isPlayer && scoped) { sprd += 0.06 }
        if p.isPlayer {
            sprd += recoil * 0.045 + (moving ? 0.03 : 0) + (p.crouch ? -0.004 : 0)
            if scoped { sprd *= 0.35 }
            sprd = max(0.002, sprd)
            p.aim += CGFloat.random(in: -0.0035...0.0035) * (0.4 + recoil)
            recoil = min(1.2, recoil + 0.13)
            kick = min(38, kick + 6 + recoil * 4)
        }
        if p.isPlayer && p.crouch {
            let bx = cos(p.aim), by = sin(p.aim)
            for r in TMap.solid where r.minX > -5000 {
                if let h = brRayThrough(p.pos, bx, by, r), h.0 >= 0, h.0 < 40, h.1 - h.0 < 100 { muzzle = max(muzzle, h.1 + 3) }
            }
            if muzzle > 20 { sprd *= 2.6 }
        }
        if p.blind > 0 { sprd += p.isPlayer ? 0.05 : 0.35 }
        p.noiseT = 1.5
        for _ in 0..<g.pellets {
            let a = p.aim + CGFloat.random(in: -sprd...sprd)
            bullets.append(Bullet(pos: CGPoint(x: p.pos.x + cos(a) * muzzle, y: p.pos.y + sin(a) * muzzle),
                                  vel: CGVector(dx: cos(a) * spd, dy: sin(a) * spd), dmg: g.dmg * (p.isPlayer ? 1 : [0.85, 1, 1][diff]),
                                  life: g.range / spd + 0.15, owner: p.id, team: p.team))
        }
        p.mag -= 1
        p.fireCd = (1 / g.rate) * (p.isPlayer ? 1 : 1.15)
        p.flash = 0.05
        if p.isPlayer { shake = max(shake, g.pellets > 1 ? 4 : 1.5) }
    }

    private func throwNade(_ p: TPlayer, _ ang: CGFloat, _ speed: CGFloat, smoke: Bool = false, flash: Bool = false) {
        guard p.alive, (flash ? p.flashes > 0 : (smoke ? p.smokes > 0 : p.nades > 0)) else { return }
        if flash { p.flashes -= 1 } else if smoke { p.smokes -= 1 } else { p.nades -= 1 }
        nades.append(Nade(pos: CGPoint(x: p.pos.x + cos(ang) * 20, y: p.pos.y + sin(ang) * 20),
                          vel: CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed), fuse: 1.5, owner: p.id, team: p.team, kind: flash ? 2 : (smoke ? 1 : 0)))
    }

    private func damage(_ victim: TPlayer, _ amt: CGFloat, by owner: Int) {
        guard victim.alive else { return }
        var amt = amt
        if victim.armor > 0 {
            let ratio: CGFloat = victim.armorKind >= 3 ? 0.75 : (victim.armorKind == 2 ? 0.6 : 0.5)
            let red: CGFloat = victim.armorKind >= 3 ? 0.9 : (victim.armorKind == 2 ? 0.85 : 0.8)
            let ab = min(victim.armor, amt * ratio); victim.armor -= ab; amt -= ab * red
        }
        victim.hp -= victim.crouch ? amt * 0.7 : amt
        victim.hurt = 0.25
        if owner == 0 && victim.team != me.team { hitT = 0.2 }
        if victim.isPlayer { shake = max(shake, 8) }
        if let o = players.first(where: { $0.id == owner }), o.team != victim.team {
            if !victim.isPlayer && victim.targetID < 0 && victim.hunt <= 0 { victim.lastSeen = o.pos; victim.hunt = 4 }
        }
        if victim.hp <= 0 {
            victim.hp = 0
            victim.alive = false
            let killer = players.first { $0.id == owner }
            if let k = killer, k.team != victim.team {
                k.kills += 1
                if gameMode == 0 { k.money = min(16000, k.money + 300) }
                if k.isPlayer { fxT = 1; fxId = killFx; fxSerial += 1 }
            }
            if gameMode != 0 {
                victim.respawn = 3
                if gameMode == 1, let k = killer, k.team != victim.team { scores[k.team] += 1 }
                if gameMode == 2 { tags.append(Tag(pos: victim.pos, team: victim.team, life: 25)) }
                if gameMode == 3, let k = killer, k.team != victim.team {
                    k.ladder += 1
                    scores[k.team] += 1
                    if k.ladder < TWeapons.ladder.count { setGun(k, TWeapons.ladder[k.ladder]) }
                }
            }
            let kn = killer?.name ?? "?"
            feed.append(Feed(text: "\(kn)  >  \(victim.name)", life: 5, mine: killer?.isPlayer == true || victim.isPlayer, k: kn, v: victim.name, kTeam: killer?.team ?? 0, gun: killer?.gun ?? "pistol", head: amt >= 45))
            if feed.count > 4 { feed.removeFirst() }
            pop(victim.pos, "X", .red)
        }
    }

    func pop(_ p: CGPoint, _ t: String, _ c: Color) {
        pops.append(Pop(pos: p, text: t, life: 1, color: c))
        if pops.count > 30 { pops.removeFirst() }
    }

    private func moveProjectiles(_ dt: CGFloat) {
        var keep: [Bullet] = []
        for var b in bullets {
            let old = b.pos
            b.pos.x += b.vel.dx * dt
            b.pos.y += b.vel.dy * dt
            b.life -= dt
            if b.life <= 0 { continue }
            var dead = false
            var hitK = -1
            for k in TMap.solid.indices where tSegT(old, b.pos, TMap.solid[k]) != nil {
                let mt = TMap.solidMat[k]
                if mt == .brick || mt == .concrete { dead = true; break }
                hitK = k
            }
            if dead { continue }
            if hitK >= 0 {
                if hitK != b.inK {
                    let glass = TMap.solidMat[hitK] == .glass
                    b.inK = hitK
                    b.pens += 1
                    b.dmg *= glass ? 0.92 : 0.55
                    if !glass && (b.pens > 2 || b.dmg < 6) { continue }
                }
            } else { b.inK = -1 }
            for v in players where v.alive && v.team != b.team {
                if tPointSeg(v.pos, old, b.pos) < 15 {
                    damage(v, b.dmg, by: b.owner)
                    dead = true
                    break
                }
            }
            if !dead { keep.append(b) }
        }
        bullets = keep
        var nk: [Nade] = []
        for var n in nades {
            n.fuse -= dt
            var np = CGPoint(x: n.pos.x + n.vel.dx * dt, y: n.pos.y + n.vel.dy * dt)
            for r in TMap.solid where r.contains(np) {
                let tryX = CGPoint(x: n.pos.x + n.vel.dx * dt, y: n.pos.y)
                if r.contains(tryX) { n.vel.dx = -n.vel.dx * 0.5 } else { n.vel.dy = -n.vel.dy * 0.5 }
                np = n.pos
                break
            }
            n.pos = np
            n.vel.dx *= pow(0.5, dt)
            n.vel.dy *= pow(0.5, dt)
            if n.fuse <= 0 && n.kind == 2 {
                booms.append(Boom(pos: n.pos, life: 0.25, r: 60))
                for v in players where v.alive {
                    let d = tDist(v.pos, n.pos)
                    guard d < 320, TMap.los(n.pos, v.pos) else { continue }
                    let toN = atan2(n.pos.y - v.pos.y, n.pos.x - v.pos.x)
                    let facing = abs(tAngDiff(toN, v.aim)) < 1.5
                    v.blind = max(v.blind, (facing ? 3.2 : 0.8) * (1 - d / 400))
                }
            } else if n.fuse <= 0 && n.kind == 1 {
                smokeClouds.append(Smoke(pos: n.pos, life: 10, r: 85))
            } else if n.fuse <= 0 {
                booms.append(Boom(pos: n.pos, life: 0.45, r: 110))
                shake = max(shake, tDist(n.pos, me.pos) < 300 ? 10 : 0)
                for v in players where v.alive {
                    let d = tDist(v.pos, n.pos)
                    if d < 110 && TMap.los(n.pos, v.pos) { damage(v, 100 * (1 - d / 110) + 12, by: n.owner) }
                }
            } else { nk.append(n) }
        }
        nades = nk
    }

    // MARK: bots

    private func botLook(_ p: TPlayer, _ dt: CGFloat) {
        // face the objective while frozen
        let d = objective(p)
        let a = atan2(d.y - p.pos.y, d.x - p.pos.x)
        p.aim += max(-3 * dt, min(3 * dt, tAngDiff(a, p.aim)))
    }

    private func stairCheck(_ p: TPlayer) {
        if let s = TMap.stairAt(p.pos) {
            if !p.onStair {
                let r = TMap.stairRect(s.0, floor: s.1 == 0 ? 1 : 0)
                p.pos = CGPoint(x: r.midX, y: r.midY)
                p.onStair = true
                p.path = []
                p.pathT = 0
                p.targetID = -1
                if p.isPlayer { pop(p.pos, s.1 == 0 ? "UPSTAIRS" : "DOWNSTAIRS", .white) }
            }
        } else {
            p.onStair = false
        }
    }

    private func routed(_ p: TPlayer, _ dest: CGPoint) -> CGPoint {
        let pf = TMap.floorOf(p.pos)
        if pf == TMap.floorOf(dest) { return dest }
        var best = CGPoint.zero
        var bd = CGFloat.greatestFiniteMagnitude
        for i in TMap.stairs.indices {
            let here = TMap.stairRect(i, floor: pf)
            let there = TMap.stairRect(i, floor: 1 - pf)
            let c = tDist(p.pos, CGPoint(x: here.midX, y: here.midY)) + tDist(CGPoint(x: there.midX, y: there.midY), dest)
            if c < bd { bd = c; best = CGPoint(x: here.midX, y: here.midY) }
        }
        return best
    }

    private func objective(_ p: TPlayer) -> CGPoint {
        if gameMode == 5 {
            let zs = cpZones
            let notMine = (0..<3).filter { !(p.team == 0 ? cpProg[$0] >= 1 : cpProg[$0] <= -1) }
            let pick = notMine.isEmpty ? p.id % 3 : notMine[p.id % notMine.count]
            let r = zs[pick]
            return CGPoint(x: r.midX + cos(CGFloat(p.id) * 1.9) * r.width * 0.3, y: r.midY + sin(CGFloat(p.id) * 2.7) * r.height * 0.3)
        }
        if gameMode != 0 {
            if gameMode == 2, let t = tags.min(by: { tDist($0.pos, p.pos) < tDist($1.pos, p.pos) }), tDist(t.pos, p.pos) < 900 { return t.pos }
            if p.roam == .zero || tDist(p.pos, p.roam) < 50 {
                if Int.random(in: 0..<100) < 40, let en = players.filter({ $0.alive && $0.team != p.team }).randomElement() { p.roam = en.pos }
                else if let w = TMap.walkable.randomElement() {
                    let r = w.1
                    p.roam = CGPoint(x: r.minX + r.width * CGFloat.random(in: 0.2...0.8), y: r.minY + r.height * CGFloat.random(in: 0.2...0.8))
                }
            }
            return p.roam
        }
        let atk = p.team == atkTeam
        let o = CGPoint(x: cos(CGFloat(p.id) * 1.7) * 70, y: sin(CGFloat(p.id) * 2.3) * 45)
        if planted {
            if atk { return CGPoint(x: bombPos.x + o.x * 1.6, y: bombPos.y + o.y * 1.6) }
            return bombPos
        }
        let r = TMap.site(atk ? atkSite : p.site)
        return CGPoint(x: r.midX + o.x, y: r.midY + o.y)
    }

    private func botThink(_ p: TPlayer, _ dt: CGFloat, _ planting: inout Bool, _ defusing: inout Bool) {
        p.fireCd -= dt
        if p.reloadT > 0 {
            p.reloadT -= dt
            if p.reloadT <= 0 { finishReload(p) }
        }
        if p.mag <= 0 && p.reloadT <= 0 {
            if p.spare > 0 { startReload(p) } else { p.gun = "pistol"; p.mag = 15; p.spare = 99 }
        }
        p.seeT -= dt
        p.hunt = max(0, p.hunt - dt)
        if p.seeT <= 0 {
            p.seeT = 0.12
            var best: TPlayer? = nil
            var bd = CGFloat.greatestFiniteMagnitude
            for e in players where e.team != p.team && e.alive {
                let d = tDist(p.pos, e.pos)
                if d < 780 && d < bd && see(p.pos, e.pos) { best = e; bd = d }
            }
            if let b = best {
                if p.targetID != b.id { p.targetID = b.id; p.reactT = react[diff] }
                p.lastSeen = b.pos
            } else if p.targetID >= 0 {
                p.targetID = -1
                p.hunt = 3
            }
        }
        var speed: CGFloat = 150
        var dest = objective(p)
        let atk = gameMode != 0 || p.team == atkTeam
        if p.targetID >= 0, let e = players.first(where: { $0.id == p.targetID }), e.alive {
            let d = tDist(p.pos, e.pos)
            let ang = atan2(e.pos.y - p.pos.y, e.pos.x - p.pos.x)
            let df = tAngDiff(ang, p.aim)
            let mt = turn[diff] * dt
            p.aim += max(-mt, min(mt, df))
            p.reactT -= dt
            if p.reactT <= 0 && abs(df) < 0.14 && p.fireCd <= 0 && p.reloadT <= 0 && p.mag > 0 {
                shoot(p, aimErr[diff])
            }
            if p.nades > 0 && d > 220 && Double.random(in: 0...1) < Double(dt) * 0.12 {
                throwNade(p, ang, min(d / 1.4, 470))
            }
            let pc = TWeapons.cls(p.gun)
            let pref: CGFloat = pc == "shotgun" ? 200 : (pc == "smg" ? 320 : (pc == "rifle" ? 460 : (pc == "sniper" ? 700 : 380)))
            p.strafeT -= dt
            if p.strafeT <= 0 { p.strafe = Bool.random() ? 1 : -1; p.strafeT = CGFloat.random(in: 0.5...1.4) }
            p.hideT -= dt
            if p.hideT <= 0 {
                p.hiding = p.hiding ? false : (p.hp < 50 || Double.random(in: 0...1) < 0.55)
                p.hideT = p.hiding ? CGFloat.random(in: 0.9...1.8) : CGFloat.random(in: 1.2...2.4)
                p.cover = p.hiding ? coverSpot(p, e.pos) : nil
            }
            if p.hiding, let c = p.cover, tDist(p.pos, c) > 8 {
                let a2 = atan2(c.y - p.pos.y, c.x - p.pos.x)
                p.pos.x += cos(a2) * 125 * dt
                p.pos.y += sin(a2) * 125 * dt
                TMap.push(&p.pos, 14)
                return
            }
            if d > pref + 60 && (atk || planted) {
                dest = e.pos
            } else {
                let sx = -sin(ang) * p.strafe, sy = cos(ang) * p.strafe
                p.pos.x += sx * 95 * dt
                p.pos.y += sy * 95 * dt
                TMap.push(&p.pos, 14)
                return
            }
            speed = 120
        } else if p.hunt > 0 {
            dest = p.lastSeen
            speed = 130
            // hear gunfire through walls and spray at it (no aim assist, just rough error)
            if p.fireCd <= 0 && p.reloadT <= 0 && p.mag > 0 {
                for e in players where e.team != p.team && e.alive && e.noiseT > 0 {
                    let d = tDist(p.pos, e.pos)
                    if d < 300 && TMap.floorOf(e.pos) == TMap.floorOf(p.pos) {
                        let ang = atan2(e.pos.y - p.pos.y, e.pos.x - p.pos.x)
                        p.aim += max(-6 * dt, min(6 * dt, tAngDiff(ang, p.aim)))
                        if abs(tAngDiff(ang, p.aim)) < 0.2 && Double.random(in: 0...1) < 0.5 { shoot(p, aimErr[diff] * 2) }
                        break
                    }
                }
            }
        }
        if gameMode == 0 && atk && !planted && p.smokes > 0 && p.targetID < 0 && smokeClouds.isEmpty {
            let sc = TMap.site(atkSite)
            let c = CGPoint(x: sc.midX, y: sc.midY)
            let dd = tDist(p.pos, c)
            if dd < 400 && dd > 200 && TMap.los(p.pos, c) {
                throwNade(p, atan2(c.y - p.pos.y, c.x - p.pos.x), dd / 0.93, smoke: true)
            }
        }
        // actions
        if p.targetID < 0 {
            if atk && !planted && p.role == 1 && TMap.site(atkSite).contains(p.pos) { planting = true }
            if !atk && planted && tDist(p.pos, bombPos) < 40 { defusing = true }
        }
        // movement
        dest = routed(p, dest)
        let atDest = tDist(p.pos, dest) < 26
        if atDest {
            if p.targetID < 0 { p.aim += sin(time * 1.3 + CGFloat(p.id)) * dt * 0.8 }
            return
        }
        p.pathT -= dt
        if p.pathT <= 0 || tDist(dest, p.pathDest) > 90 {
            p.path = TNav.path(p.pos, dest)
            p.pathDest = dest
            p.pathT = CGFloat.random(in: 0.8...1.4)
        }
        while let f = p.path.first, tDist(p.pos, f) < 14 { p.path.removeFirst() }
        guard let nxt = p.path.first else { return }
        let a = atan2(nxt.y - p.pos.y, nxt.x - p.pos.x)
        p.pos.x += cos(a) * speed * dt
        p.pos.y += sin(a) * speed * dt
        TMap.push(&p.pos, 14)
        if p.targetID < 0 {
            p.aim += max(-4 * dt, min(4 * dt, tAngDiff(a, p.aim)))
        }
    }

    // MARK: drawing

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        drawOverlay3D(&ctx, size)
    }














    func drawMinimapPublic(_ ctx: inout GraphicsContext) {
        drawRadar(&ctx)
    }

    /// First-person radar: baked map image rotated heading-up inside a circle, live markers on top.
    private func drawRadar(_ ctx: inout GraphicsContext) {
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        let cx: CGFloat = 84, cy: CGFloat = 128, R: CGFloat = 64
        let s: CGFloat = 0.12
        let th = -CGFloat.pi / 2 - focus.aim
        let ct = cos(th), st = sin(th)
        let circle = Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
        ctx.fill(circle, with: .color(Color(red: 0.04, green: 0.05, blue: 0.07)))
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let dx = (x - focus.pos.x) * s, dy = (y - focus.pos.y) * s
            return CGPoint(x: cx + dx * ct - dy * st, y: cy + dx * st + dy * ct)
        }
        func clamp(_ p: CGPoint) -> (CGPoint, Bool) {
            let dx = p.x - cx, dy = p.y - cy
            let d = hypot(dx, dy)
            if d <= R - 5 { return (p, false) }
            return (CGPoint(x: cx + dx / d * (R - 5), y: cy + dy / d * (R - 5)), true)
        }
        var g = ctx
        g.clip(to: circle)
        var mg = g
        mg.translateBy(x: cx, y: cy)
        mg.rotate(by: .radians(Double(th)))
        mg.scaleBy(x: s, y: s)
        mg.translateBy(x: -focus.pos.x, y: -focus.pos.y)
        mg.draw(Image(uiImage: TacRadar.image), in: CGRect(x: 0, y: 0, width: TMap.floorW, height: TMap.H))
        // dynamic doors (closed ones as bars)
        for (i, d) in TMap.doors.enumerated() where i < TMap.doorOpen.count && TMap.doorOpen[i] < 0.5 {
            mg.fill(Path(d), with: .color(Color(red: 0.75, green: 0.55, blue: 0.28)))
        }
        let pulse = 0.5 + 0.5 * sin(Double(time) * 4)
        if gameMode == 5 {
            for (i, z) in cpZones.enumerated() {
                let c = P(z.midX, z.midY)
                let pr = cpProg[i]
                let col: Color = pr == 0 ? .gray : (pr > 0 ? Color(red: 0.3, green: 0.62, blue: 1) : Color(red: 0.96, green: 0.62, blue: 0.16))
                g.stroke(Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22)), with: .color(col.opacity(0.9)), lineWidth: 2)
                g.draw(Text(["A", "B", "C"][i]).font(.system(size: 10, weight: .heavy)).foregroundColor(col), at: c)
            }
        }
        for t in tags {
            let c = clamp(P(t.pos.x, t.pos.y)).0
            let col: Color = t.team == me.team ? Color(red: 0.3, green: 0.62, blue: 1) : Color.yellow
            g.fill(Path(CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(col))
        }
        for pk in packs where !pk.taken {
            let c = P(pk.pos.x, pk.pos.y)
            g.fill(Path(CGRect(x: c.x - 3, y: c.y - 1, width: 6, height: 2)), with: .color(.green))
            g.fill(Path(CGRect(x: c.x - 1, y: c.y - 3, width: 2, height: 6)), with: .color(.green))
        }
        for sm in smokeClouds {
            let c = P(sm.pos.x, sm.pos.y)
            g.fill(Path(ellipseIn: CGRect(x: c.x - sm.r * s, y: c.y - sm.r * s, width: sm.r * 2 * s, height: sm.r * 2 * s)), with: .color(.white.opacity(0.4)))
        }
        // view cone
        var cone = Path()
        cone.move(to: CGPoint(x: cx, y: cy))
        cone.addArc(center: CGPoint(x: cx, y: cy), radius: R, startAngle: .radians(-Double.pi / 2 - 0.5), endAngle: .radians(-Double.pi / 2 + 0.5), clockwise: false)
        cone.closeSubpath()
        g.fill(cone, with: .linearGradient(Gradient(colors: [Color.green.opacity(0.32), Color.green.opacity(0)]), startPoint: CGPoint(x: cx, y: cy), endPoint: CGPoint(x: cx, y: cy - R)))
        for p in players where p.alive && !p.isPlayer && (p.team == me.team || p.spotted) {
            let (c, edge) = clamp(P(p.pos.x, p.pos.y))
            let ally = p.team == me.team
            let col: Color = ally ? Color(red: 0.3, green: 0.62, blue: 1) : Color(red: 1, green: 0.28, blue: 0.3)
            if edge {
                g.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(col))
                continue
            }
            let a = Double(p.aim + th)
            var tri = Path()
            tri.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * 7, y: c.y + CGFloat(sin(a)) * 7))
            tri.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + 2.5)) * 5, y: c.y + CGFloat(sin(a + 2.5)) * 5))
            tri.addLine(to: CGPoint(x: c.x + CGFloat(cos(a - 2.5)) * 5, y: c.y + CGFloat(sin(a - 2.5)) * 5))
            tri.closeSubpath()
            g.fill(tri, with: .color(col))
            g.stroke(tri, with: .color(.black.opacity(0.7)), lineWidth: 0.8)
            if !ally { g.stroke(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(col.opacity(0.3 + 0.4 * pulse)), lineWidth: 1) }
        }
        for pg in pings {
            let c = clamp(P(pg.pos.x, pg.pos.y)).0
            g.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.orange.opacity(Double(min(1, pg.life)))), lineWidth: 1.5)
        }
        if planted {
            let c = clamp(P(bombPos.x, bombPos.y)).0
            let rr = 5 + 5 * CGFloat(pulse)
            g.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(.red.opacity(0.8)), lineWidth: 1.5)
            g.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(.orange))
        }
        // me, always centre, pointing up
        var me3 = Path()
        me3.move(to: CGPoint(x: cx, y: cy - 8))
        me3.addLine(to: CGPoint(x: cx + 5.5, y: cy + 5))
        me3.addLine(to: CGPoint(x: cx, y: cy + 2))
        me3.addLine(to: CGPoint(x: cx - 5.5, y: cy + 5))
        me3.closeSubpath()
        g.fill(me3, with: .color(Color(red: 0.3, green: 0.95, blue: 0.45)))
        g.stroke(me3, with: .color(.black.opacity(0.8)), lineWidth: 1)
        // vignette + bezel
        ctx.fill(circle, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.5)]), center: CGPoint(x: cx, y: cy), startRadius: R * 0.62, endRadius: R))
        ctx.stroke(circle, with: .color(.white.opacity(0.55)), lineWidth: 2.5)
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - R - 3, y: cy - R - 3, width: R * 2 + 6, height: R * 2 + 6)), with: .color(.black.opacity(0.6)), lineWidth: 2)
        ctx.draw(Text("N").font(.system(size: 9, weight: .heavy)).foregroundColor(.red), at: CGPoint(x: cx + st * (R - 9), y: cy - ct * (R - 9)))
    }



    // MARK: HUD helpers

    var meInSite: Bool { me.alive && me.team == atkTeam && !planted && TMap.site(atkSite).contains(me.pos) }
    var meNearBomb: Bool { me.alive && me.team != atkTeam && planted && tDist(me.pos, bombPos) < 46 }
    var allyAlive: Int { players.filter { $0.team == me.team && $0.alive }.count }
    var enemyAlive: Int { players.filter { $0.team != me.team && $0.alive }.count }
    var objectiveText: String {
        if gameMode == 1 { return "First to \(killTarget) kills" }
        if gameMode == 2 { return "Collect enemy tags, deny yours" }
        if gameMode == 3 { return "Arms Race  \(min(me.ladder + 1, TWeapons.ladder.count))/\(TWeapons.ladder.count)  \(TGuns.get(me.gun).name)" }
        if phase == 0 { return me.team == atkTeam ? "Attack: plant at \(atkSite == 0 ? "A" : "B")" : "Defend both sites" }
        if planted { return me.team == atkTeam ? "Protect the bomb" : "Defuse the bomb" }
        return me.team == atkTeam ? "Plant the bomb at \(atkSite == 0 ? "A" : "B")" : "Hold the sites"
    }
}

// MARK: - Play view

struct TacticalPlay: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    var diff: Int
    var modeId = 0
    @State private var engine = TacticalEngine()
    @State private var lStart: CGPoint? = nil
    @State private var lKnob: CGPoint = .zero
    @State private var rStart: CGPoint? = nil
    @State private var rKnob: CGPoint = .zero
    @State private var collected = false
    @State private var autoOn = true
    @State private var bridge: TacScene? = nil
    private var fp: Bool { true }
    @State private var lastLook: CGFloat = 0
    @State private var lastLookY: CGFloat = 0
    @State private var lookOn = false
    @State private var baseYaw: CGFloat = 0
    @State private var lastDrag = CGSize.zero
    @State private var baseDist: CGFloat = 430
    @State private var camP = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let b = bridge {
                TacSceneView(bridge: b).ignoresSafeArea().allowsHitTesting(false)
            }
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    engine.step(tl.date)
                    bridge?.sync(engine)
                    engine.draw(&ctx, size)
                }
            }
            .ignoresSafeArea()
            controls
            hud
            buyLayer
            stateLayer
        }
        .statusBarHidden(true)
        .onAppear {
            OrientationLock.set(landscape: true)
            engine.fp = true
            engine.view3D = true
            engine.autoAim = true
            autoOn = true
            Task.detached(priority: .utility) { _ = TacRadar.image }
            let sxd = game.sx
            engine.killFx = sxd.fx
            engine.charm = sxd.charm
            engine.theme = TacSeason.themes.firstIndex(of: sxd.map) ?? 0
            let gc = TacSeason.cos(sxd.gloves).rgb
            TwViewModel.gloveColor = UIColor(red: gc.0, green: gc.1, blue: gc.2, alpha: 1)
            engine.setup(gun: "rifle", diff: diff, mode: modeId)
            let b = TacScene()
            b.fpMode = true
            b.build(engine)
            bridge = b
            engine.project = { [weak b] p, h in b?.project(p, h) }
        }
    }

    private func gearSym(_ id: String) -> String {
        switch id {
        case "kev": return "shield.lefthalf.filled"
        case "vest": return "shield.fill"
        case "spec": return "shield.checkered"
        case "flashb": return "sun.max.fill"
        case "smokeb": return "smoke.fill"
        default: return "circle.hexagongrid.fill"
        }
    }

    private func buyBtn(_ e: TacticalEngine, _ id: String, _ name: String, gear: Bool) -> some View {
        let c = e.price(id)
        let own = e.me.gun == id || e.me.altGun == id
        let ok = e.me.money >= c && !own
        return Button { e.buyItem(e.me, id) } label: {
            HStack(spacing: 8) {
                if gear {
                    SF(gearSym(id), "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.9)).frame(width: 34)
                } else {
                    Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                        .foregroundColor(.white.opacity(0.9)).frame(width: 34, height: 15)
                }
                Text(name).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                if own {
                    SF("checkmark.circle.fill").font(.system(size: 13)).foregroundColor(TUI.green)
                } else {
                    Text("$\(c)").font(.jk(11, .bold)).foregroundColor(ok ? TUI.green : TUI.red.opacity(0.85))
                }
            }
            .padding(.horizontal, 9).frame(width: 150, height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(ok ? 0.14 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(own ? TUI.green.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func buyCol(_ e: TacticalEngine, _ title: String, _ items: [(String, String)], gear: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.jk(10, .heavy)).tracking(1).foregroundColor(TUI.accent)
            ForEach(items, id: \.0) { it in buyBtn(e, it.0, it.1, gear: gear) }
        }
    }

    private var buyLayer: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { _ in
            let e = engine
            ZStack {
                if e.buyOpen && e.gameMode == 0 && e.buyT > 0 && e.me.alive {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            SF("cart.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Text("BUY MENU").font(.jk(15, .heavy)).foregroundColor(.white)
                            Text("\(Int(e.buyT))s").font(.jk(12, .bold)).foregroundColor(.white.opacity(0.6))
                            Spacer()
                            SF("dollarsign.circle.fill").font(.system(size: 16)).foregroundColor(TUI.green)
                            Text("\(e.me.money)").font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundColor(TUI.green)
                            Button { e.buyOpen = false } label: {
                                SF("xmark").font(.system(size: 12, weight: .black)).foregroundColor(.white)
                                    .frame(width: 30, height: 30).background(Circle().fill(Color.white.opacity(0.15)))
                            }
                            .buttonStyle(TuiPress())
                        }
                        HStack(alignment: .top, spacing: 10) {
                            buyCol(e, "PISTOL", [("eagle", "EAGLE-50")])
                            buyCol(e, "SMG", [("smg", "VX-9 SMG"), ("mp7", "MP-7"), ("p90", "P-90")])
                            buyCol(e, "RIFLE", [("rifle", "AR-27"), ("ak", "AK-74X"), ("m4", "M4-CQ")])
                            buyCol(e, "HEAVY", [("pump", "PUMP-12"), ("shotgun", "BREACHER"), ("awp", "AWP-X")])
                            buyCol(e, "GEAR", [("kev", "KEVLAR"), ("vest", "VEST + HELMET"), ("spec", "SPECIAL ARMOR"), ("flashb", "FLASHBANG"), ("smokeb", "SMOKE"), ("fragb", "FRAG")], gear: true)
                        }
                    }
                    .padding(14)
                    .tuiGlass(18, fill: 0.84)
                }
            }
        }
    }

    private var controls: some View {
        GeometryReader { g in
            ZStack {
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                lStart = v.startLocation
                                lKnob = v.location
                                let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                                let d = hypot(dx, dy)
                                let k = min(1, d / 50)
                                var mv = d > 4 ? CGVector(dx: dx / d * k, dy: dy / d * k) : .zero
                                if let b = bridge, b.yaw != 0 {
                                    let c = cos(b.yaw), sn = sin(b.yaw)
                                    mv = CGVector(dx: c * mv.dx + sn * mv.dy, dy: -sn * mv.dx + c * mv.dy)
                                }
                                engine.move = mv
                            }
                            .onEnded { _ in lStart = nil; engine.move = .zero })
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if fp {
                                    let sens: CGFloat = engine.scoped ? 0.0035 : 0.008
                                    engine.lookDelta += (v.translation.width - lastLook) * sens
                                    lastLook = v.translation.width
                                    engine.pitch = max(-0.5, min(0.5, engine.pitch - (v.translation.height - lastLookY) * sens * 0.6))
                                    lastLookY = v.translation.height
                                    return
                                }
                                rStart = v.startLocation
                                rKnob = v.location
                                let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                                if hypot(dx, dy) > 8 { engine.aimIn = atan2(dy, dx) - (bridge?.yaw ?? 0) }
                                engine.firing = true
                            }
                            .onEnded { _ in rStart = nil; lastLook = 0; lastLookY = 0; engine.aimIn = nil; engine.firing = false })
                }
                if lookOn {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: g.size.width * 0.55, height: g.size.height)
                        .position(x: g.size.width * 0.725, y: g.size.height / 2)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let dx = v.translation.width - lastDrag.width
                                let dy = v.translation.height - lastDrag.height
                                lastDrag = v.translation
                                bridge?.yaw -= dx * 0.008
                                if let b = bridge { b.pitch = max(0.45, min(1.45, b.pitch + dy * 0.005)) }
                            }
                            .onEnded { _ in lastDrag = .zero })
                        .simultaneousGesture(MagnificationGesture()
                            .onChanged { m in bridge?.dist = max(220, min(900, baseDist / m)) }
                            .onEnded { _ in baseDist = bridge?.dist ?? 430 })
                }
                if let s = lStart { stick(s, lKnob, Color.white) }
                if let s = rStart { stick(s, rKnob, Color.red) }
                if fp {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            fireButton.padding(.trailing, 108).padding(.bottom, 18)
                        }
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
            .simultaneousGesture(RotationGesture()
                .onChanged { a in bridge?.yaw = baseYaw + CGFloat(a.radians) }
                .onEnded { _ in baseYaw = bridge?.yaw ?? 0 })
        }
        .ignoresSafeArea()
    }

    private var fireButton: some View {
        Circle().fill(Color.black.opacity(0.35)).frame(width: 84, height: 84)
            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2.5))
            .overlay(Image(systemName: "scope").font(.system(size: 34, weight: .light)).foregroundColor(.white.opacity(0.95)))
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in engine.firing = true }.onEnded { _ in engine.firing = false })
    }

    private func stick(_ base: CGPoint, _ knob: CGPoint, _ c: Color) -> some View {
        let dx = knob.x - base.x, dy = knob.y - base.y
        let d = max(1, hypot(dx, dy))
        let k = min(d, 50)
        return ZStack {
            Circle().stroke(c.opacity(0.35), lineWidth: 2).frame(width: 100, height: 100).position(base)
            Circle().fill(c.opacity(0.35)).frame(width: 46, height: 46).position(x: base.x + dx / d * k, y: base.y + dy / d * k)
        }
        .allowsHitTesting(false)
    }


    @ViewBuilder private var hud: some View {
        fpHud
    }



    // MARK: HUD building blocks

    private func pip(_ p: TPlayer?, ally: Bool) -> some View {
        let col = ally ? TUI.blue : TUI.orange
        let alive = p?.alive ?? false
        return ZStack {
            Circle().fill(p == nil ? Color.white.opacity(0.12) : (alive ? col : Color.black.opacity(0.55)))
            Circle().stroke(p == nil ? Color.white.opacity(0.12) : col.opacity(alive ? 1 : 0.6), lineWidth: 1.5)
            if p != nil {
                if alive { SF("person.fill").font(.system(size: 11, weight: .bold)).foregroundColor(Color.black.opacity(0.75)) }
                else { SF("xmark").font(.system(size: 10, weight: .black)).foregroundColor(.white.opacity(0.85)) }
            }
        }
        .frame(width: 24, height: 24)
    }

    private func teamPips(_ list: [TPlayer], ally: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in pip(i < list.count ? list[i] : nil, ally: ally) }
        }
    }

    private func vbtn(_ icon: String, _ d: CGFloat, on: Bool = false, dim: Bool = false) -> some View {
        SF(icon, "circle.fill").font(.system(size: d * 0.42, weight: .semibold))
            .foregroundColor(on ? .black : .white.opacity(dim ? 0.35 : 0.95))
            .frame(width: d, height: d)
            .background(Circle().fill(on ? TUI.accent : Color.black.opacity(0.42)))
            .overlay(Circle().stroke(on ? Color.white.opacity(0.9) : Color.white.opacity(0.4), lineWidth: 1.5))
    }

    private func nadeBubble(_ icon: String, _ n: Int) -> some View {
        ZStack(alignment: .bottomTrailing) {
            SF(icon, "circle.fill").font(.system(size: 19, weight: .bold)).foregroundColor(.white.opacity(n == 0 ? 0.3 : 0.95))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.black.opacity(0.42)))
                .overlay(Circle().stroke(Color.white.opacity(n == 0 ? 0.2 : 0.45), lineWidth: 1.5))
            Text("\(n)").font(.jk(11, .heavy)).foregroundColor(.black).frame(minWidth: 17, minHeight: 17)
                .background(Circle().fill(n == 0 ? Color.white.opacity(0.4) : TUI.accent))
        }
    }

    private func statBar(_ icon: String, _ v: CGFloat, _ col: Color) -> some View {
        HStack(spacing: 7) {
            SF(icon, "circle.fill").font(.system(size: 13, weight: .black)).foregroundColor(col).frame(width: 16)
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 104, height: 6)
                .overlay(alignment: .leading) { Capsule().fill(col).frame(width: 104 * max(0, min(1, v / 100)), height: 6) }
            Text("\(Int(max(0, v)))").font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundColor(.white).frame(width: 36, alignment: .trailing)
        }
    }

    private func togglePill(_ icon: String, _ label: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 5) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold))
                Text(label).font(.jk(10, .heavy))
            }
            .foregroundColor(on ? .black : .white.opacity(0.9)).frame(width: 64, height: 28)
            .background(Capsule().fill(on ? TUI.accent : Color.black.opacity(0.45)))
            .overlay(Capsule().stroke(Color.white.opacity(on ? 0.8 : 0.35), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func actionPill(_ icon: String, _ label: String, _ col: Color) -> some View {
        HStack(spacing: 6) {
            SF(icon, "circle.fill").font(.system(size: 13, weight: .bold))
            Text(label).font(.jk(12, .heavy))
        }
        .foregroundColor(.black).padding(.horizontal, 14).frame(height: 40).background(Capsule().fill(col))
        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
    }

    private var fpHud: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let e = engine
            let allies = e.players.filter { $0.team == e.me.team }
            let foes = e.players.filter { $0.team != e.me.team }
            let t = Int(max(0, e.timer))
            let g = TGuns.get(e.me.gun)
            let charm = TacSeason.cos(e.charm)
            GeometryReader { geo in
                let W = geo.size.width, H = geo.size.height
                ZStack(alignment: .topLeading) {
                    // top-left: vitals card, then radar (canvas) and settings
                    VStack(alignment: .leading, spacing: 4) {
                        statBar("heart.fill", e.me.hp, e.me.hp < 35 ? TUI.red : .white)
                        statBar("shield.fill", e.me.armor, TUI.blue)
                        if e.gameMode == 0 {
                            HStack(spacing: 5) {
                                SF("dollarsign.circle.fill").font(.system(size: 13)).foregroundColor(TUI.green)
                                Text("\(e.me.money)").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundColor(TUI.green)
                            }
                            .padding(.leading, 1)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6).tuiGlass(12, fill: 0.4)
                    .padding(.leading, 10).padding(.top, 2)
                    Button { e.paused = true } label: { vbtn("gearshape.fill", 34) }
                        .buttonStyle(TuiPress())
                        .position(x: 180, y: 84)
                    Text(TMap.roomName(e.me.pos).uppercased()).font(.jk(10, .heavy)).tracking(1).foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 10).frame(height: 20).background(Capsule().fill(Color.black.opacity(0.45)))
                        .position(x: 84, y: 206)

                    // top-center: scoreboard
                    VStack(spacing: 5) {
                        HStack(spacing: 10) {
                            teamPips(allies, ally: true)
                            VStack(spacing: 1) {
                                Text(String(format: "%02d:%02d", t / 60, t % 60))
                                    .font(.system(size: 19, weight: .heavy, design: .monospaced))
                                    .foregroundColor(e.planted ? TUI.red : .white)
                                HStack(spacing: 8) {
                                    Text("\(e.scores[0])").foregroundColor(TUI.blue)
                                    Text("\(e.rivalScore)").foregroundColor(TUI.orange)
                                }
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                            }
                            .frame(width: 84)
                            teamPips(foes, ally: false)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6).tuiGlass(18, fill: 0.5)
                        Text(e.objectiveText).font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 12).frame(height: 22).background(Capsule().fill(Color.black.opacity(0.4)))
                        if e.gameMode == 5 {
                            HStack(spacing: 5) {
                                ForEach(0..<3, id: \.self) { i in
                                    let pr = e.cpProg[i]
                                    Text(["A", "B", "C"][i]).font(.jk(12, .heavy)).foregroundColor(.white).frame(width: 30, height: 24)
                                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(pr == 0 ? Color.gray.opacity(0.55) : (pr > 0 ? TUI.blue.opacity(0.35 + 0.65 * Double(pr)) : TUI.orange.opacity(0.35 + 0.65 * Double(-pr)))))
                                }
                            }
                        }
                        if e.bannerT > 0 {
                            Text(e.banner).font(.jk(24, .heavy)).foregroundColor(.white).shadow(color: .black.opacity(0.6), radius: 6).multilineTextAlignment(.center)
                                .padding(.top, 16).opacity(Double(min(1, e.bannerT)))
                        }
                        if e.plantProg > 0 || e.defuseProg > 0 {
                            let pr = e.plantProg > 0 ? e.plantProg / 3 : e.defuseProg / 4
                            VStack(spacing: 4) {
                                HStack(spacing: 5) {
                                    SF(e.plantProg > 0 ? "timer" : "wrench.and.screwdriver.fill", "circle.fill").font(.system(size: 11, weight: .bold))
                                    Text(e.plantProg > 0 ? "PLANTING" : "DEFUSING").font(.jk(11, .heavy))
                                }
                                .foregroundColor(.white)
                                Capsule().fill(Color.white.opacity(0.22)).frame(width: 160, height: 7)
                                    .overlay(alignment: .leading) { Capsule().fill(TUI.gold).frame(width: 160 * min(1, pr), height: 7) }
                            }
                            .padding(.top, 20)
                        }
                    }
                    .frame(width: W).padding(.top, 2)

                    // top-right: weapon card + feed
                    VStack(alignment: .trailing, spacing: 6) {
                        VStack(alignment: .trailing, spacing: 5) {
                            HStack(spacing: 8) {
                                if !charm.sym.isEmpty { SF(charm.sym, "sparkles").font(.system(size: 15, weight: .bold)).foregroundColor(TUI.gold) }
                                Image(uiImage: GunSprites.icon(TWeapons.rig(e.me.gun))).renderingMode(.template).resizable().scaledToFit()
                                    .foregroundColor(.white).frame(width: 112, height: 34)
                            }
                            HStack(alignment: .lastTextBaseline, spacing: 5) {
                                if e.me.reloadT > 0 {
                                    Text("RELOADING").font(.jk(15, .heavy)).foregroundColor(TUI.gold)
                                } else {
                                    Text("\(e.me.mag)").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundColor(e.me.mag == 0 ? TUI.red : .white)
                                }
                                Text("/").font(.jk(14, .bold)).foregroundColor(.white.opacity(0.5))
                                if TWeapons.isPistol(e.me.gun) {
                                    SF("infinity", "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.8))
                                } else {
                                    Text("\(e.me.spare * g.mag)").font(.jk(14, .bold)).foregroundColor(.white.opacity(0.8))
                                }
                            }
                            Capsule().fill(Color.white.opacity(0.18)).frame(width: 170, height: 4)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(e.me.mag <= max(1, g.mag / 4) ? TUI.red : TUI.accent)
                                        .frame(width: 170 * max(0, min(1, CGFloat(e.me.mag) / CGFloat(max(1, g.mag)))), height: 4)
                                }
                            HStack {
                                Button { e.wantSwap = true } label: {
                                    SF("arrow.triangle.swap", "arrow.2.squarepath").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        .frame(width: 34, height: 24).background(Capsule().fill(Color.white.opacity(0.14)))
                                }
                                .buttonStyle(TuiPress())
                                Spacer()
                                HStack(spacing: 4) {
                                    SF("scope", "circle.fill").font(.system(size: 11, weight: .bold)).foregroundColor(TUI.gold)
                                    Text("\(e.me.kills)").font(.jk(13, .heavy)).foregroundColor(.white)
                                }
                            }
                            .frame(width: 170)
                        }
                        .padding(10).tuiGlass(14, fill: 0.42)
                        if let f = e.feed.last {
                            HStack(spacing: 8) {
                                Text(f.k.split(separator: " ").first.map(String.init) ?? f.k).font(.jk(12, .bold)).foregroundColor(f.kTeam == e.me.team ? TUI.blue : TUI.orange)
                                Image(uiImage: GunSprites.icon(TWeapons.rig(f.gun))).renderingMode(.template).resizable().scaledToFit()
                                    .foregroundColor(.white).frame(width: 36, height: 14)
                                if f.head { SF("scope", "circle.fill").font(.system(size: 11, weight: .black)).foregroundColor(TUI.red) }
                                Text(f.v.split(separator: " ").first.map(String.init) ?? f.v).font(.jk(12, .bold)).foregroundColor(f.kTeam == e.me.team ? TUI.orange : TUI.blue)
                            }
                            .padding(.horizontal, 10).frame(height: 24).tuiGlass(12, fill: 0.5)
                        }
                    }
                    .padding(.trailing, 16).padding(.top, 4)
                    .frame(width: W, alignment: .trailing)

                    if e.me.alive {
                        Button { e.wantSmoke = true } label: { nadeBubble("smoke.fill", e.me.smokes) }
                            .buttonStyle(TuiPress()).position(x: W - 36, y: 205)
                        Button { e.wantNade = true } label: { nadeBubble("circle.hexagongrid.fill", e.me.nades) }
                            .buttonStyle(TuiPress()).position(x: W - 96, y: 232)
                        Button { e.wantFlash = true } label: { nadeBubble("sun.max.fill", e.me.flashes) }
                            .buttonStyle(TuiPress()).position(x: W - 36, y: 257)
                        Button { e.scoped.toggle() } label: { vbtn("scope", 44, on: e.scoped) }
                            .buttonStyle(TuiPress()).position(x: W - 96, y: 288)
                        Button { e.toggleCover() } label: { vbtn("figure.stand", 44, on: e.me.crouch) }
                            .buttonStyle(TuiPress()).position(x: W - 36, y: 309)
                        Button { e.jumpT = max(e.jumpT, 0.55) } label: { vbtn("arrow.up", 44) }
                            .buttonStyle(TuiPress()).position(x: W - 36, y: 361)
                        Button { e.wantReload = true } label: { vbtn("arrow.triangle.2.circlepath", 48) }
                            .buttonStyle(TuiPress()).position(x: W - 250, y: 352)
                        togglePill("target", "AIM", e.autoAim) { e.autoAim.toggle() }
                            .position(x: W - 250, y: 302)
                        togglePill("repeat", "AUTO", e.autoFire) { e.autoFire.toggle() }
                            .position(x: W - 250, y: 332)
                    } else {
                        Button { e.fast.toggle() } label: {
                            HStack(spacing: 6) {
                                SF(e.fast ? "play.fill" : "forward.fill", "circle.fill").font(.system(size: 12, weight: .bold))
                                Text(e.fast ? "Normal speed" : "Skip ahead").font(.jk(13, .bold))
                            }
                            .foregroundColor(.white).padding(.horizontal, 14).frame(height: 38).tuiGlass(19, fill: 0.55)
                        }
                        .buttonStyle(TuiPress())
                        .position(x: W - 110, y: H - 40)
                    }

                    if e.gameMode == 0 && e.buyT > 0 && e.me.alive {
                        Button { e.buyOpen.toggle() } label: {
                            HStack(spacing: 6) {
                                SF("cart.fill").font(.system(size: 13, weight: .bold))
                                Text("BUY  \(Int(e.buyT))").font(.jk(13, .heavy))
                            }
                            .foregroundColor(.black).padding(.horizontal, 14).frame(height: 38).background(Capsule().fill(TUI.green))
                            .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(TuiPress())
                        .position(x: 70, y: H * 0.55)
                    }
                    if e.fxT > 0 && e.fxId != "fx_none" {
                        TacGif(name: e.fxId).id(e.fxSerial)
                            .frame(width: 240, height: 240)
                            .position(x: W / 2, y: H * 0.42)
                            .allowsHitTesting(false)
                    }
                    // bottom-center: contextual
                    HStack(spacing: 10) {
                        if let di = e.nearestDoor() {
                            let closing = TMap.doorWant[di] || TMap.doorOpen[di] > 0.5
                            Button { e.toggleDoor() } label: {
                                actionPill(closing ? "door.left.hand.closed" : "door.left.hand.open", closing ? "CLOSE DOOR" : "OPEN DOOR", TUI.gold)
                            }
                            .buttonStyle(TuiPress())
                        }
                        if e.meInSite || e.meNearBomb {
                            actionPill(e.meInSite ? "timer" : "wrench.and.screwdriver.fill", e.meInSite ? "HOLD PLANT" : "HOLD DEFUSE", TUI.gold)
                                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in e.actHeld = true }.onEnded { _ in e.actHeld = false })
                        }
                    }
                    .position(x: W * 0.5, y: H - 40)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: pause + results

    private var stateLayer: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            ZStack {
                if engine.paused && !engine.over { pauseView }
                if engine.over { overView }
            }
        }
    }

    private func settingRow(_ icon: String, _ title: String, _ sub: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 12) {
                SF(icon, "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(on ? .black : .white.opacity(0.8))
                    .frame(width: 34, height: 34).background(Circle().fill(on ? TUI.accent : Color.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.jk(14, .heavy)).foregroundColor(.white)
                    Text(sub).font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule().fill(on ? TUI.accent : Color.white.opacity(0.2)).frame(width: 46, height: 26)
                    Circle().fill(Color.white).frame(width: 20, height: 20).padding(.horizontal, 3)
                }
            }
            .padding(.horizontal, 12).frame(width: 340, height: 56).tuiGlass(14, fill: 0.35)
        }
        .buttonStyle(TuiPress())
    }

    private var pauseView: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    SF("pause.circle.fill").font(.system(size: 22)).foregroundColor(TUI.accent)
                    Text("PAUSED").font(.jk(24, .heavy)).tracking(2).foregroundColor(.white)
                }
                .padding(.bottom, 4)
                settingRow("target", "Aim assist", "Turns toward enemies in view", engine.autoAim) { engine.autoAim.toggle() }
                settingRow("repeat", "Auto fire", "Shoots when your crosshair is on target", engine.autoFire) { engine.autoFire.toggle() }
                Button { engine.paused = false; engine.last = nil } label: {
                    HStack(spacing: 8) {
                        SF("play.fill").font(.system(size: 14, weight: .bold))
                        Text("RESUME").font(.jk(16, .heavy))
                    }
                    .foregroundColor(.black).frame(width: 340, height: 50).background(Capsule().fill(TUI.accent))
                }
                .buttonStyle(TuiPress())
                Button { engine.scores = [0, engine.target]; engine.over = true; engine.won = false; engine.paused = false } label: {
                    HStack(spacing: 8) {
                        SF("flag.fill").font(.system(size: 13, weight: .bold))
                        Text("FORFEIT MATCH").font(.jk(13, .heavy))
                    }
                    .foregroundColor(TUI.red).frame(width: 340, height: 42).background(Capsule().fill(TUI.red.opacity(0.14)))
                    .overlay(Capsule().stroke(TUI.red.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
            .padding(20).tuiGlass(22, fill: 0.7)
        }
    }

    private func resultTile(_ icon: String, _ value: String, _ label: String, _ col: Color) -> some View {
        VStack(spacing: 4) {
            SF(icon, "circle.fill").font(.system(size: 18, weight: .bold)).foregroundColor(col)
            Text(value).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.white)
            Text(label).font(.jk(9, .heavy)).tracking(1).foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 108, height: 78).tuiGlass(14, fill: 0.35)
    }

    private var overView: some View {
        let e = engine
        let gems = (e.won ? 25 : 8) + e.kills * 2 + e.scores[0] * 3
        let xp = 40 + e.kills * 10 + (e.won ? 60 : 0)
        let col = e.won ? TUI.green : TUI.red
        return ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 12) {
                SF(e.won ? "trophy.fill" : "xmark.octagon.fill", "star.fill").font(.system(size: 34)).foregroundColor(col)
                Text(e.won ? "VICTORY" : "DEFEAT").font(.jk(38, .heavy)).tracking(3).foregroundColor(col)
                HStack(spacing: 14) {
                    Text("\(e.scores[0])").foregroundColor(TUI.blue)
                    Text(":").foregroundColor(.white.opacity(0.5))
                    Text("\(e.rivalScore)").foregroundColor(TUI.orange)
                }
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                HStack(spacing: 10) {
                    resultTile("scope", "\(e.kills)", "KILLS", TUI.gold)
                    resultTile("diamond.fill", "+\(gems)", "GEMS", TUI.accent)
                    resultTile("star.fill", "+\(xp)", "SEASON XP", TUI.blue)
                }
                Button {
                    guard !collected else { return }
                    collected = true
                    game.tacticalFinish(won: e.won, kills: e.kills, gems: gems)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        SF("checkmark.circle.fill").font(.system(size: 15, weight: .bold))
                        Text("COLLECT AND EXIT").font(.jk(15, .heavy))
                    }
                    .foregroundColor(.black).frame(width: 300, height: 52).background(Capsule().fill(TUI.accent))
                }
                .buttonStyle(TuiPress())
                .padding(.top, 4)
            }
        }
    }
}

extension Game {
    func tacticalFinish(won: Bool, kills: Int, gems: Int) {
        var st = s
        var d = st.ex.tac ?? TacData()
        if won { d.wins += 1; d.rating += 25 } else { d.losses += 1; d.rating = max(0, d.rating - 18) }
        d.kills += kills
        var x = d.sx ?? TacSeasonData()
        x.xp += 40 + kills * 10 + (won ? 60 : 0)
        d.sx = x
        st.ex.tac = d
        st.ex.gems += gems
        s = st
    }
}
