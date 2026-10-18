import SwiftUI

// MARK: - Persisted stats

struct TacData: Codable, Hashable {
    var wins = 0
    var losses = 0
    var kills = 0
    var rating = 1000
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
    static let floorW: CGFloat = 1700
    static let off: CGFloat = 1800
    static let W: CGFloat = 3500
    static let H: CGFloat = 1200
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

    static let layout: (walls: [CGRect], mats: [WallMat], doors: [CGRect]) = {
        var w: [CGRect] = []
        var m: [WallMat] = []
        var d: [CGRect] = []
        var ox: CGFloat = 0
        let t: CGFloat = 14
        func hw(_ y: CGFloat, _ x1: CGFloat, _ x2: CGFloat, _ mt: WallMat, _ gaps: [(CGFloat, CGFloat)] = []) {
            var cur = x1
            for g in gaps.sorted(by: { $0.0 < $1.0 }) {
                if g.0 > cur { w.append(CGRect(x: ox + cur, y: y - t / 2, width: g.0 - cur, height: t)); m.append(mt) }
                d.append(CGRect(x: ox + g.0, y: y - t / 2, width: g.1 - g.0, height: t))
                cur = g.1
            }
            if cur < x2 { w.append(CGRect(x: ox + cur, y: y - t / 2, width: x2 - cur, height: t)); m.append(mt) }
        }
        func vw(_ x: CGFloat, _ y1: CGFloat, _ y2: CGFloat, _ mt: WallMat, _ gaps: [(CGFloat, CGFloat)] = []) {
            var cur = y1
            for g in gaps.sorted(by: { $0.0 < $1.0 }) {
                if g.0 > cur { w.append(CGRect(x: ox + x - t / 2, y: cur, width: t, height: g.0 - cur)); m.append(mt) }
                d.append(CGRect(x: ox + x - t / 2, y: g.0, width: t, height: g.1 - g.0))
                cur = g.1
            }
            if cur < y2 { w.append(CGRect(x: ox + x - t / 2, y: cur, width: t, height: y2 - cur)); m.append(mt) }
        }
        let bw: CGFloat = 1700
        let bh: CGFloat = 1200
        // ground floor
        ox = 0
        hw(0, 0, bw, .brick)
        hw(bh, 0, bw, .brick)
        vw(0, 0, bh, .brick)
        vw(bw, 0, bh, .brick)
        vw(560, 0, bh, .concrete, [(200, 300), (700, 800), (1000, 1100)])
        vw(1140, 0, bh, .wood, [(150, 250), (800, 900)])
        vw(1260, 0, bh, .glass, [(350, 450), (950, 1050)])
        hw(600, 0, 560, .wood, [(220, 320)])
        hw(600, 560, 1140, .wood, [(700, 800)])
        hw(600, 1260, bw, .wood, [(1350, 1450)])
        vw(300, 0, 150, .wood)
        hw(850, 1480, bw, .glass)
        // upper floor
        ox = TMap.off
        hw(0, 0, bw, .brick)
        hw(bh, 0, bw, .brick)
        vw(0, 0, bh, .brick)
        vw(bw, 0, bh, .brick)
        vw(560, 0, bh, .wood, [(250, 350), (750, 850)])
        vw(1140, 0, bh, .glass, [(100, 200), (700, 800)])
        vw(1260, 0, bh, .wood, [(400, 500), (900, 1000)])
        hw(600, 0, 560, .wood, [(180, 280)])
        hw(600, 560, 1140, .glass, [(650, 750)])
        hw(600, 1260, bw, .concrete, [(1300, 1400)])
        return (w, m, d)
    }()

    static let walls: [CGRect] = layout.walls
    static let wallMats: [WallMat] = layout.mats
    static let doors: [CGRect] = layout.doors

    static let rooms: [TRoom] = [
        TRoom(name: "Master Bedroom", r: CGRect(x: 0, y: 0, width: 560, height: 600), mat: 0),
        TRoom(name: "Living Room", r: CGRect(x: 560, y: 0, width: 580, height: 600), mat: 2),
        TRoom(name: "East Hallway", r: CGRect(x: 1140, y: 0, width: 120, height: 1200), mat: 5),
        TRoom(name: "Study", r: CGRect(x: 1260, y: 0, width: 440, height: 600), mat: 4),
        TRoom(name: "Garage", r: CGRect(x: 0, y: 600, width: 560, height: 600), mat: 1),
        TRoom(name: "Kitchen", r: CGRect(x: 560, y: 600, width: 580, height: 600), mat: 3),
        TRoom(name: "Game Room", r: CGRect(x: 1260, y: 600, width: 440, height: 600), mat: 2),
        TRoom(name: "Office", r: CGRect(x: off, y: 0, width: 560, height: 600), mat: 4),
        TRoom(name: "Lounge", r: CGRect(x: off + 560, y: 0, width: 580, height: 600), mat: 2),
        TRoom(name: "Upper Hall", r: CGRect(x: off + 1140, y: 0, width: 120, height: 1200), mat: 5),
        TRoom(name: "Server Room", r: CGRect(x: off + 1260, y: 0, width: 440, height: 600), mat: 1),
        TRoom(name: "Storage", r: CGRect(x: off, y: 600, width: 560, height: 600), mat: 1),
        TRoom(name: "Balcony", r: CGRect(x: off + 560, y: 600, width: 580, height: 600), mat: 3),
        TRoom(name: "Gym", r: CGRect(x: off + 1260, y: 600, width: 440, height: 600), mat: 2)
    ]

    static func roomName(_ p: CGPoint) -> String {
        for r in rooms where r.r.contains(p) { return r.name }
        return "Outside"
    }

    static let props: [TProp] = {
        var l: [TProp] = [
            TProp(r: CGRect(x: 30, y: 40, width: 110, height: 150), k: .bed),
            TProp(r: CGRect(x: 150, y: 40, width: 40, height: 40), k: .table),
            TProp(r: CGRect(x: 440, y: 40, width: 90, height: 40), k: .shelf),
            TProp(r: CGRect(x: 30, y: 430, width: 60, height: 140), k: .shelf),
            TProp(r: CGRect(x: 200, y: 385, width: 60, height: 50), k: .couch),
            TProp(r: CGRect(x: 440, y: 500, width: 100, height: 60), k: .table),
            TProp(r: CGRect(x: 470, y: 360, width: 80, height: 22), k: .sandbag),
            TProp(r: CGRect(x: 700, y: 40, width: 120, height: 60), k: .couch),
            TProp(r: CGRect(x: 700, y: 330, width: 120, height: 70), k: .table),
            TProp(r: CGRect(x: 980, y: 330, width: 60, height: 150), k: .couch),
            TProp(r: CGRect(x: 900, y: 20, width: 140, height: 40), k: .tv),
            TProp(r: CGRect(x: 880, y: 260, width: 50, height: 50), k: .plant),
            TProp(r: CGRect(x: 1090, y: 300, width: 30, height: 160), k: .shelf),
            TProp(r: CGRect(x: 590, y: 480, width: 120, height: 40), k: .counter),
            TProp(r: CGRect(x: 1280, y: 40, width: 30, height: 200), k: .shelf),
            TProp(r: CGRect(x: 1450, y: 260, width: 150, height: 60), k: .table),
            TProp(r: CGRect(x: 1620, y: 400, width: 60, height: 120), k: .shelf),
            TProp(r: CGRect(x: 1300, y: 500, width: 60, height: 60), k: .crate),
            TProp(r: CGRect(x: 20, y: 640, width: 170, height: 40), k: .counter),
            TProp(r: CGRect(x: 30, y: 780, width: 40, height: 40), k: .barrel),
            TProp(r: CGRect(x: 300, y: 880, width: 160, height: 80), k: .car),
            TProp(r: CGRect(x: 420, y: 620, width: 70, height: 60), k: .crate),
            TProp(r: CGRect(x: 510, y: 880, width: 30, height: 100), k: .shelf),
            TProp(r: CGRect(x: 600, y: 1140, width: 300, height: 40), k: .counter),
            TProp(r: CGRect(x: 740, y: 870, width: 140, height: 44), k: .counter),
            TProp(r: CGRect(x: 1080, y: 1100, width: 50, height: 80), k: .shelf),
            TProp(r: CGRect(x: 980, y: 1000, width: 80, height: 60), k: .crate),
            TProp(r: CGRect(x: 900, y: 640, width: 100, height: 50), k: .counter),
            TProp(r: CGRect(x: 1000, y: 700, width: 40, height: 40), k: .plant),
            TProp(r: CGRect(x: 950, y: 1010, width: 22, height: 80), k: .sandbag),
            TProp(r: CGRect(x: 1500, y: 680, width: 160, height: 90), k: .table),
            TProp(r: CGRect(x: 1290, y: 700, width: 40, height: 120), k: .couch),
            TProp(r: CGRect(x: 1520, y: 880, width: 150, height: 50), k: .couch),
            TProp(r: CGRect(x: 1620, y: 1100, width: 60, height: 80), k: .shelf),
            TProp(r: CGRect(x: 1400, y: 1050, width: 70, height: 70), k: .crate)
        ]
        let up: [(CGFloat, CGFloat, CGFloat, CGFloat, PropKind)] = [
            (60, 60, 160, 70, .table), (20, 300, 40, 160, .shelf), (300, 420, 150, 50, .couch), (430, 250, 60, 60, .crate),
            (700, 40, 150, 60, .couch), (900, 20, 140, 40, .tv), (760, 300, 110, 70, .table), (1000, 380, 60, 140, .couch), (640, 520, 40, 40, .plant),
            (1300, 60, 40, 200, .shelf), (1430, 60, 40, 200, .shelf), (1560, 60, 40, 200, .shelf), (1500, 420, 70, 70, .crate),
            (60, 700, 70, 70, .crate), (340, 700, 70, 70, .crate), (460, 900, 40, 40, .barrel), (20, 1000, 40, 160, .shelf), (240, 950, 100, 22, .sandbag), (100, 1100, 70, 70, .crate),
            (980, 900, 22, 100, .sandbag), (600, 1140, 300, 40, .counter), (1080, 640, 40, 40, .plant), (1000, 1050, 70, 70, .crate), (800, 700, 140, 44, .counter),
            (1300, 700, 100, 60, .table), (1560, 900, 70, 70, .crate), (1290, 1000, 40, 120, .couch), (1620, 1100, 60, 80, .shelf), (1600, 640, 40, 40, .barrel), (1400, 1100, 200, 40, .counter)
        ]
        for u in up { l.append(TProp(r: CGRect(x: TMap.off + u.0, y: u.1, width: u.2, height: u.3), k: u.4)) }
        return l
    }()

    static let rugs: [(CGRect, Color)] = [
        (CGRect(x: 640, y: 190, width: 300, height: 240), Color(red: 0.42, green: 0.22, blue: 0.3)),
        (CGRect(x: 1160, y: 0, width: 80, height: 1200), Color(red: 0.38, green: 0.14, blue: 0.16)),
        (CGRect(x: 1320, y: 850, width: 180, height: 140), Color(red: 0.2, green: 0.35, blue: 0.42)),
        (CGRect(x: 1380, y: 150, width: 220, height: 90), Color(red: 0.35, green: 0.2, blue: 0.14)),
        (CGRect(x: 60, y: 240, width: 90, height: 120), Color(red: 0.4, green: 0.3, blue: 0.4)),
        (CGRect(x: off + 1160, y: 0, width: 80, height: 1200), Color(red: 0.14, green: 0.22, blue: 0.38)),
        (CGRect(x: off + 760, y: 120, width: 260, height: 160), Color(red: 0.22, green: 0.3, blue: 0.24)),
        (CGRect(x: off + 1340, y: 740, width: 220, height: 140), Color(red: 0.3, green: 0.16, blue: 0.2))
    ]

    static let packPos: [CGPoint] = [CGPoint(x: 870, y: 540), CGPoint(x: 1200, y: 600), CGPoint(x: 440, y: 1040), CGPoint(x: off + 1200, y: 300), CGPoint(x: off + 880, y: 780)]

    static let stairs: [CGRect] = [CGRect(x: 1160, y: 1040, width: 80, height: 140), CGRect(x: 575, y: 130, width: 70, height: 110)]

    static func stairRect(_ i: Int, floor: Int) -> CGRect { floor == 0 ? stairs[i] : stairs[i].offsetBy(dx: off, dy: 0) }

    static func stairAt(_ p: CGPoint) -> (Int, Int)? {
        for i in stairs.indices {
            if stairs[i].contains(p) { return (i, 0) }
            if stairRect(i, floor: 1).contains(p) { return (i, 1) }
        }
        return nil
    }

    static let solid: [CGRect] = layout.walls + props.map { $0.r }
    static let solidKind: [PropKind?] = layout.walls.map { _ -> PropKind? in nil } + props.map { Optional($0.k) }
    static let solidMat: [WallMat] = layout.mats + props.map { TMap.propMat($0.k) }
    static let siteA = CGRect(x: 170, y: 170, width: 230, height: 170)
    static let siteB = CGRect(x: off + 690, y: 830, width: 240, height: 170)
    static let atkSpawn: [CGPoint] = [CGPoint(x: 90, y: 1130), CGPoint(x: 160, y: 1130), CGPoint(x: 230, y: 1130), CGPoint(x: 90, y: 1060), CGPoint(x: 160, y: 1060)]
    static let defSpawn: [CGPoint] = [CGPoint(x: 1610, y: 70), CGPoint(x: 1540, y: 70), CGPoint(x: 1470, y: 70), CGPoint(x: 1610, y: 140), CGPoint(x: 1540, y: 140)]

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
                for o in TMap.solid where o.insetBy(dx: -18, dy: -18).contains(p) { b[r * cols + c] = true; break }
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
        for o in TMap.solid where tSegT(a, b, o.insetBy(dx: -15, dy: -15)) != nil { return false }
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
    let team: Int
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
    var site = 0
    var spotted = false
    var seenEver = false
    var onStair = false

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
    private let dummyMe = TPlayer(id: 0, team: 0, name: "You", handle: "you", emoji: "🙂", isPlayer: true)
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
    var autoTarget = -1
    var firing = false
    var actHeld = false
    var wantNade = false
    var wantSmoke = false
    var fp = false
    var view3D = true
    var project: ((CGPoint, CGFloat) -> CGPoint?)? = nil
    var lookDelta: CGFloat = 0
    var hitT: CGFloat = 0
    var wantReload = false
    var fast = false
    var paused = false
    var won = false
    var last: Date? = nil
    var time: CGFloat = 0
    var spotT: CGFloat = 0
    var shake: CGFloat = 0
    var myGun = "pistol"
    var kills: Int { me.kills }

    private let react: [CGFloat] = [0.55, 0.33, 0.18]
    private let turn: [CGFloat] = [5, 8, 12]
    private let aimErr: [CGFloat] = [0.13, 0.07, 0.035]

    func setup(cast: [NPC], persona: Persona, gun: String, diff: Int) {
        self.diff = diff
        myGun = gun
        var names: [(String, String, String)] = []
        for n in cast.shuffled().prefix(9) { names.append((n.name, n.handle, n.emoji)) }
        while names.count < 9 {
            let u = Crowd.make()
            names.append((u.name, u.handle, "🙂"))
        }
        players = [TPlayer(id: 0, team: 0, name: "You", handle: persona.handle, emoji: persona.emoji, isPlayer: true)]
        for i in 0..<9 {
            players.append(TPlayer(id: i + 1, team: i < 4 ? 0 : 1, name: names[i].0, handle: names[i].1, emoji: names[i].2, isPlayer: false))
        }
        scores = [0, 0]
        round = 0
        phase = 0
        over = false
        startRound()
    }
    var over = false

    private func gunPick() -> String {
        let r = Int.random(in: 0..<100)
        if r < 35 { return "rifle" }
        if r < 65 { return "smg" }
        if r < 80 { return "shotgun" }
        return "pistol"
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
        lookDelta = 0
        packs = TMap.packPos.map { Pack(pos: $0, taken: false) }
        var ai = 0, di = 0
        var defBots = 0
        for p in players {
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
            p.pingCd = 0
            let atk = p.team == atkTeam
            let spot = atk ? TMap.atkSpawn[ai % 5] : TMap.defSpawn[di % 5]
            if atk { ai += 1 } else { di += 1 }
            p.pos = spot
            p.aim = atan2(TMap.H / 2 - spot.y, TMap.floorW / 2 - spot.x)
            p.gun = p.isPlayer ? myGun : gunPick()
            p.mag = Guns.get(p.gun).mag
            p.spare = p.gun == "pistol" ? 99 : 2
            p.role = 0
            if !atk && !p.isPlayer { p.site = defBots % 2; defBots += 1 }
            p.site = atk ? atkSite : p.site
        }
        if let planter = players.filter({ $0.team == atkTeam && !$0.isPlayer }).randomElement() { planter.role = 1 }
        phase = 0
        timer = 4
        banner = me.team == atkTeam ? "PREPARE TO ATTACK" : "PREPARE TO DEFEND"
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
        for p in players { p.flash = max(0, p.flash - dt); p.hurt = max(0, p.hurt - dt) }

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
            if timer <= 0 { phase = 1; timer = 100; banner = "GO"; bannerT = 1 }
            for p in players where !p.isPlayer { botLook(p, dt) }
            return
        }
        // live
        timer -= dt
        var planting = false
        var defusing = false
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

    func see(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if !TMap.los(a, b) { return false }
        for s in smokeClouds where tPointSeg(s.pos, a, b) < s.r * 0.9 { return false }
        return true
    }

    private func endRound(winner: Int, text: String) {
        scores[winner] += 1
        phase = 3
        timer = 3.5
        let w = winner == me.team
        banner = (w ? "ROUND WON  " : "ROUND LOST  ") + text
        bannerT = 3.5
    }

    // MARK: player

    private func playerUpdate(_ dt: CGFloat, _ planting: inout Bool, _ defusing: inout Bool) {
        let p = me
        guard p.alive else { return }
        let sp: CGFloat = 170
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
                if !manual { p.aim = turnToward(p.aim, want, 9 * dt) }
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
        if p.reloadT > 0 {
            p.reloadT -= dt
            if p.reloadT <= 0 { finishReload(p) }
        } else if (firing || aligned) && p.fireCd <= 0 && !actHeld {
            if p.mag > 0 { shoot(p, 0) } else { startReload(p) }
        }
        if wantNade { wantNade = false; throwNade(p, p.aim, 420) }
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
        let range = Guns.get(p.gun).range
        var best: TPlayer? = nil
        var bd: CGFloat = .greatestFiniteMagnitude
        for e in players where e.alive && e.team != p.team {
            let d = tDist(p.pos, e.pos)
            if d < range && d < bd && see(p.pos, e.pos) { bd = d; best = e }
        }
        return best
    }

    func startReload(_ p: TPlayer) {
        let g = Guns.get(p.gun)
        guard p.reloadT <= 0, p.mag < g.mag, p.spare > 0 else { return }
        p.reloadT = g.reload
    }

    private func finishReload(_ p: TPlayer) {
        p.mag = Guns.get(p.gun).mag
        if p.gun != "pistol" { p.spare -= 1 }
    }

    private func shoot(_ p: TPlayer, _ err: CGFloat) {
        let g = Guns.get(p.gun)
        let spd: CGFloat = 1100
        for _ in 0..<g.pellets {
            let a = p.aim + CGFloat.random(in: -(g.spread + err)...(g.spread + err))
            bullets.append(Bullet(pos: CGPoint(x: p.pos.x + cos(a) * 20, y: p.pos.y + sin(a) * 20),
                                  vel: CGVector(dx: cos(a) * spd, dy: sin(a) * spd), dmg: g.dmg * (p.isPlayer ? 1 : [0.85, 1, 1][diff]),
                                  life: g.range / spd + 0.15, owner: p.id, team: p.team))
        }
        p.mag -= 1
        p.fireCd = (1 / g.rate) * (p.isPlayer ? 1 : 1.15)
        p.flash = 0.05
        if p.isPlayer { shake = max(shake, g.pellets > 1 ? 4 : 1.5) }
    }

    private func throwNade(_ p: TPlayer, _ ang: CGFloat, _ speed: CGFloat, smoke: Bool = false) {
        guard p.alive, (smoke ? p.smokes > 0 : p.nades > 0) else { return }
        if smoke { p.smokes -= 1 } else { p.nades -= 1 }
        nades.append(Nade(pos: CGPoint(x: p.pos.x + cos(ang) * 20, y: p.pos.y + sin(ang) * 20),
                          vel: CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed), fuse: 1.5, owner: p.id, team: p.team, kind: smoke ? 1 : 0))
    }

    private func damage(_ victim: TPlayer, _ amt: CGFloat, by owner: Int) {
        guard victim.alive else { return }
        victim.hp -= amt
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
            if let k = killer, k.team != victim.team { k.kills += 1 }
            let kn = killer?.name ?? "?"
            feed.append(Feed(text: "\(kn)  >  \(victim.name)", life: 5, mine: killer?.isPlayer == true || victim.isPlayer))
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
            if n.fuse <= 0 && n.kind == 1 {
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
            if p.spare > 0 { startReload(p) } else { p.gun = "pistol"; p.mag = 12; p.spare = 99 }
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
        let atk = p.team == atkTeam
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
            let pref: CGFloat = p.gun == "shotgun" ? 200 : (p.gun == "smg" ? 320 : (p.gun == "rifle" ? 460 : 380))
            p.strafeT -= dt
            if p.strafeT <= 0 { p.strafe = Bool.random() ? 1 : -1; p.strafeT = CGFloat.random(in: 0.5...1.4) }
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
        }
        if atk && !planted && p.smokes > 0 && p.targetID < 0 && smokeClouds.isEmpty {
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
        if view3D { drawOverlay3D(&ctx, size); return }
        if fp { drawFP(&ctx, size); return }
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        let camX = min(max(0, focus.pos.x - size.width / 2), max(0, TMap.W - size.width))
        let camY = min(max(0, focus.pos.y - size.height / 2), max(0, TMap.H - size.height))
        var w = ctx
        let sx = shake > 0 ? CGFloat.random(in: -shake...shake) * 0.5 : 0
        let sy = shake > 0 ? CGFloat.random(in: -shake...shake) * 0.5 : 0
        w.translateBy(x: -camX + sx, y: -camY + sy)
        // floors
        let cam = CGRect(x: camX - 20, y: camY - 20, width: size.width + 40, height: size.height + 40)
        w.fill(Path(CGRect(x: -400, y: -400, width: TMap.W + 800, height: TMap.H + 800)), with: .color(Color(red: 0.04, green: 0.05, blue: 0.07)))
        for rm in TMap.rooms {
            let vis = rm.r.intersection(cam)
            if vis.isNull || vis.isEmpty { continue }
            floorFill(&w, rm, vis)
        }
        for rg in TMap.rugs {
            if !rg.0.intersects(cam) { continue }
            w.fill(Path(roundedRect: rg.0, cornerRadius: 10), with: .color(rg.1.opacity(0.85)))
            w.stroke(Path(roundedRect: rg.0.insetBy(dx: 8, dy: 8), cornerRadius: 6), with: .color(.white.opacity(0.16)), lineWidth: 2)
        }
        // sites
        for i in 0..<2 {
            let r = TMap.site(i)
            w.fill(Path(roundedRect: r, cornerRadius: 10), with: .color(Color(red: 0.15, green: 0.45, blue: 0.85).opacity(0.22)))
            w.stroke(Path(roundedRect: r.insetBy(dx: 6, dy: 6), cornerRadius: 8), with: .color(Color(red: 0.98, green: 0.8, blue: 0.08).opacity(0.85)), style: StrokeStyle(lineWidth: 3, dash: [14, 8]))
            let c = CGPoint(x: r.midX, y: r.midY)
            w.fill(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)), with: .color(.black.opacity(0.5)))
            w.stroke(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)), with: .color(.white.opacity(0.9)), lineWidth: 2.5)
            w.draw(Text(i == 0 ? "A" : "B").font(.system(size: 26, weight: .heavy)).foregroundColor(.white), at: c)
        }
        // doors
        for dr in TMap.doors {
            w.fill(Path(dr), with: .color(Color(red: 0.62, green: 0.5, blue: 0.32)))
            let horiz = dr.width > dr.height
            let a = horiz ? CGRect(x: dr.minX - 2, y: dr.minY - 3, width: 5, height: dr.height + 6) : CGRect(x: dr.minX - 3, y: dr.minY - 2, width: dr.width + 6, height: 5)
            let b = horiz ? CGRect(x: dr.maxX - 3, y: dr.minY - 3, width: 5, height: dr.height + 6) : CGRect(x: dr.minX - 3, y: dr.maxY - 3, width: dr.width + 6, height: 5)
            w.fill(Path(a), with: .color(Color(red: 0.3, green: 0.2, blue: 0.1)))
            w.fill(Path(b), with: .color(Color(red: 0.3, green: 0.2, blue: 0.1)))
        }
        // walls + props, depth sorted, extruded
        var items: [(CGFloat, Int, Int)] = []
        for (i, o) in TMap.walls.enumerated() where o.insetBy(dx: -60, dy: -60).intersects(cam) { items.append((o.maxY, 0, i)) }
        for (i, pr) in TMap.props.enumerated() where pr.r.insetBy(dx: -60, dy: -60).intersects(cam) { items.append((pr.r.maxY, 1, i)) }
        items.sort { $0.0 < $1.0 }
        for it in items {
            if it.1 == 0 { drawWall(&w, TMap.walls[it.2]) } else { drawProp3(&w, TMap.props[it.2]) }
        }
        for k in packs where !k.taken {
            w.fill(Path(ellipseIn: CGRect(x: k.pos.x - 13, y: k.pos.y - 13, width: 26, height: 26)), with: .color(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.9)))
            w.fill(Path(CGRect(x: k.pos.x - 3, y: k.pos.y - 8, width: 6, height: 16)), with: .color(.white))
            w.fill(Path(CGRect(x: k.pos.x - 8, y: k.pos.y - 3, width: 16, height: 6)), with: .color(.white))
        }
        // bomb
        if planted {
            let pulse = 0.5 + 0.5 * sin(time * (bombT < 10 ? 14 : 6))
            w.fill(Path(ellipseIn: CGRect(x: bombPos.x - 40, y: bombPos.y - 40, width: 80, height: 80)), with: .color(Color.red.opacity(0.08 + 0.12 * Double(pulse))))
            w.fill(Path(ellipseIn: CGRect(x: bombPos.x - 9, y: bombPos.y - 9, width: 18, height: 18)), with: .color(Color.red))
            w.draw(Text(String(format: "%.0f", max(0, bombT))).font(.system(size: 13, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: bombPos.x, y: bombPos.y - 24))
        }
        // dead bodies
        for p in players where !p.alive {
            var x = Path()
            x.move(to: CGPoint(x: p.pos.x - 8, y: p.pos.y - 8)); x.addLine(to: CGPoint(x: p.pos.x + 8, y: p.pos.y + 8))
            x.move(to: CGPoint(x: p.pos.x + 8, y: p.pos.y - 8)); x.addLine(to: CGPoint(x: p.pos.x - 8, y: p.pos.y + 8))
            w.stroke(x, with: .color((p.team == me.team ? Color.blue : Color.red).opacity(0.6)), lineWidth: 3)
        }
        let lg = Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.55).opacity(0.16), Color.clear])
        w.fill(Path(ellipseIn: CGRect(x: focus.pos.x - 260, y: focus.pos.y - 260, width: 520, height: 520)), with: .radialGradient(lg, center: focus.pos, startRadius: 0, endRadius: 260))
        // vision darkness
        let vp = focus.pos
        var poly = Path()
        let n = 140
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let d = TMap.rayDist(vp, a, 720)
            let pt = CGPoint(x: vp.x + cos(a) * d, y: vp.y + sin(a) * d)
            if i == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
        }
        poly.closeSubpath()
        var dark = Path(CGRect(x: camX - 80, y: camY - 80, width: size.width + 160, height: size.height + 160))
        dark.addPath(poly)
        w.fill(dark, with: .color(.black.opacity(0.74)), style: FillStyle(eoFill: true))
        // projectiles
        for b in bullets {
            var t = Path()
            t.move(to: b.pos)
            t.addLine(to: CGPoint(x: b.pos.x - b.vel.dx * 0.03, y: b.pos.y - b.vel.dy * 0.03))
            w.stroke(t, with: .color(b.team == me.team ? Color(red: 0.7, green: 0.9, blue: 1) : Color(red: 1, green: 0.55, blue: 0.4)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        for g in nades {
            w.fill(Path(ellipseIn: CGRect(x: g.pos.x - 5, y: g.pos.y - 5, width: 10, height: 10)), with: .color(g.kind == 1 ? Color(white: 0.75) : Color(red: 0.4, green: 0.9, blue: 0.4)))
        }
        // characters (allies always, enemies when spotted)
        for p in players where p.alive && (p.team == me.team || p.spotted) { drawPlayer(&w, p) }
        for s in smokeClouds {
            let fade = Double(min(1, s.life / 1.5))
            for i in 0..<9 {
                let ang = CGFloat(i) * 0.7 + time * 0.2
                let dist = s.r * (i == 0 ? 0 : 0.5)
                let cx = s.pos.x + cos(ang) * dist
                let cy = s.pos.y + sin(ang) * dist
                let rr = s.r * (i == 0 ? 0.9 : 0.62)
                let g = Gradient(colors: [Color(white: 0.9).opacity(0.97 * fade), Color(white: 0.72).opacity(0.85 * fade), Color(white: 0.6).opacity(0)])
                w.fill(Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2)), with: .radialGradient(g, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: rr))
            }
        }
        for b in booms {
            let k = 1 - b.life / 0.45
            let rr = b.r * (0.35 + k * 0.7)
            w.fill(Path(ellipseIn: CGRect(x: b.pos.x - rr, y: b.pos.y - rr, width: rr * 2, height: rr * 2)), with: .color(Color.orange.opacity(0.5 * (1 - Double(min(1, k))))))
            w.stroke(Path(ellipseIn: CGRect(x: b.pos.x - rr, y: b.pos.y - rr, width: rr * 2, height: rr * 2)), with: .color(.yellow.opacity(Double(max(0, 1 - k)))), lineWidth: 3)
        }
        for p in pops {
            w.draw(Text(p.text).font(.system(size: 16, weight: .heavy)).foregroundColor(p.color.opacity(Double(p.life))), at: CGPoint(x: p.pos.x, y: p.pos.y - 24 - (1 - p.life) * 24))
        }
        for pg in pings {
            let al = Double(min(1, pg.life))
            var dm = Path()
            dm.move(to: CGPoint(x: pg.pos.x, y: pg.pos.y - 12)); dm.addLine(to: CGPoint(x: pg.pos.x + 8, y: pg.pos.y - 22))
            dm.addLine(to: CGPoint(x: pg.pos.x, y: pg.pos.y - 32)); dm.addLine(to: CGPoint(x: pg.pos.x - 8, y: pg.pos.y - 22)); dm.closeSubpath()
            w.fill(dm, with: .color(Color.orange.opacity(al)))
            w.draw(Text(pg.text).font(.system(size: 12, weight: .heavy)).foregroundColor(Color.yellow.opacity(al)), at: CGPoint(x: pg.pos.x, y: pg.pos.y - 44))
        }
        let vg = Gradient(colors: [Color.clear, Color.black.opacity(0.5)])
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(vg, center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: min(size.width, size.height) * 0.45, endRadius: max(size.width, size.height) * 0.72))
        // minimap (screen space)
        drawMinimap(&ctx)
        if me.hurt > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.red.opacity(Double(me.hurt) * 0.45)))
        }
        if !me.alive {
            ctx.draw(Text("SPECTATING " + focus.name.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.7)), at: CGPoint(x: size.width / 2, y: size.height - 90))
        }
    }

    // MARK: first-person raycast view

    private struct FPBill {
        var perp: CGFloat
        var sx: CGFloat
        var kind: Int
        var p: TPlayer?
        var r: CGFloat
        var a: CGFloat
    }

    private func fpColor(_ k: PropKind?) -> (CGFloat, CGFloat, CGFloat) {
        guard let kk = k else { return (0.62, 0.66, 0.72) }
        switch kk {
        case .bed: return (0.32, 0.4, 0.62)
        case .couch: return (0.55, 0.26, 0.3)
        case .table: return (0.62, 0.44, 0.26)
        case .counter: return (0.78, 0.8, 0.82)
        case .crate: return (0.52, 0.38, 0.22)
        case .car: return (0.2, 0.38, 0.62)
        case .shelf: return (0.3, 0.22, 0.15)
        case .barrel: return (0.5, 0.2, 0.14)
        case .sandbag: return (0.76, 0.68, 0.44)
        case .tv: return (0.1, 0.12, 0.16)
        case .plant: return (0.16, 0.45, 0.22)
        }
    }

    private func fpWallColor(_ m: WallMat) -> (CGFloat, CGFloat, CGFloat) {
        switch m {
        case .brick: return (0.56, 0.3, 0.25)
        case .concrete: return (0.6, 0.62, 0.66)
        case .wood: return (0.55, 0.4, 0.25)
        case .glass: return (0.5, 0.78, 0.92)
        }
    }

    private func fpHeight(_ k: PropKind?) -> CGFloat {
        guard let kk = k else { return 1 }
        switch kk {
        case .bed: return 0.35
        case .couch: return 0.45
        case .table: return 0.4
        case .counter: return 0.5
        case .crate: return 0.55
        case .car: return 0.6
        case .shelf: return 0.95
        case .barrel: return 0.5
        case .sandbag: return 0.3
        case .tv: return 0.5
        case .plant: return 0.6
        }
    }

    private func rayRect(_ ox: CGFloat, _ oy: CGFloat, _ dx: CGFloat, _ dy: CGFloat, _ r: CGRect) -> (CGFloat, Int)? {
        var t0: CGFloat = 0
        var t1: CGFloat = 5000
        var side = 0
        if abs(dx) < 1e-7 {
            if ox < r.minX || ox > r.maxX { return nil }
        } else {
            var ta = (r.minX - ox) / dx
            var tb = (r.maxX - ox) / dx
            if ta > tb { let tmp = ta; ta = tb; tb = tmp }
            if ta > t0 { t0 = ta; side = 0 }
            t1 = min(t1, tb)
            if t0 > t1 { return nil }
        }
        if abs(dy) < 1e-7 {
            if oy < r.minY || oy > r.maxY { return nil }
        } else {
            var ta = (r.minY - oy) / dy
            var tb = (r.maxY - oy) / dy
            if ta > tb { let tmp = ta; ta = tb; tb = tmp }
            if ta > t0 { t0 = ta; side = 1 }
            t1 = min(t1, tb)
            if t0 > t1 { return nil }
        }
        if t0 <= 0.001 { return nil }
        return (t0, side)
    }

    func drawFP(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        let pos = focus.pos
        let ang = focus.aim
        let W = size.width
        let H = size.height
        let hz = H / 2
        let fov: CGFloat = 1.15
        let tanH = tan(fov / 2)
        // ceiling + floor
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: hz)), with: .color(Color(red: 0.07, green: 0.08, blue: 0.11)))
        var mat = 1
        for rm in TMap.rooms where rm.r.contains(pos) { mat = rm.mat }
        let fcs: [(CGFloat, CGFloat, CGFloat)] = [(0.45, 0.31, 0.19), (0.34, 0.36, 0.38), (0.27, 0.24, 0.33), (0.5, 0.54, 0.56), (0.28, 0.19, 0.13), (0.4, 0.4, 0.42)]
        let fc = fcs[mat]
        for b in 0..<6 {
            let k = 0.35 + 0.1 * CGFloat(b)
            ctx.fill(Path(CGRect(x: 0, y: hz + CGFloat(b) * hz / 6, width: W, height: hz / 6 + 1)), with: .color(Color(red: fc.0 * k, green: fc.1 * k, blue: fc.2 * k)))
        }
        let n = max(60, Int(W / 4))
        let cw = W / CGFloat(n)
        var z = [CGFloat](repeating: 9999, count: n)
        var near: [Int] = []
        for (k, r) in TMap.solid.enumerated() {
            let cx = min(max(pos.x, r.minX), r.maxX)
            let cy = min(max(pos.y, r.minY), r.maxY)
            if tDist(pos, CGPoint(x: cx, y: cy)) < 1300 { near.append(k) }
        }
        for i in 0..<n {
            let sxn = (CGFloat(i) + 0.5) / CGFloat(n) * 2 - 1
            let off = atan(sxn * tanH)
            let a = ang + off
            let dx = cos(a)
            let dy = sin(a)
            var hits: [(CGFloat, Int, Int)] = []
            for k in near {
                if let h = rayRect(pos.x, pos.y, dx, dy, TMap.solid[k]) { hits.append((h.0, k, h.1)) }
            }
            hits.sort { $0.0 > $1.0 }
            let co = cos(off)
            for h in hits {
                let perp = max(8, h.0 * co)
                let u = H * 0.72 / perp
                let kind = TMap.solidKind[h.1]
                let mt = TMap.solidMat[h.1]
                let hgt: CGFloat = kind == nil ? TMap.wallH : TMap.propH(kind!)
                let bottom = hz + TMap.eyeH * u
                let top = bottom - hgt * u
                var sh = max(0.22, min(1, 1.25 - perp / 950))
                if h.2 == 1 { sh *= 0.78 }
                let c = kind == nil ? fpWallColor(mt) : fpColor(kind)
                let col = Color(red: Double(c.0 * sh), green: Double(c.1 * sh), blue: Double(c.2 * sh))
                let rect = CGRect(x: CGFloat(i) * cw, y: top, width: cw + 0.6, height: bottom - top)
                if mt == .glass {
                    ctx.fill(Path(rect), with: .color(col.opacity(0.3)))
                    ctx.fill(Path(CGRect(x: rect.minX, y: top, width: rect.width, height: 2)), with: .color(.white.opacity(0.55)))
                    ctx.fill(Path(CGRect(x: rect.minX, y: bottom - 2, width: rect.width, height: 2)), with: .color(.white.opacity(0.35)))
                    continue
                }
                ctx.fill(Path(rect), with: .color(col))
                if kind == nil && mt == .brick {
                    let rows = max(1, Int((bottom - top) / max(4, 9 * u)))
                    for rr in 1..<(rows + 1) {
                        let yy = top + CGFloat(rr) * (bottom - top) / CGFloat(rows + 1)
                        ctx.fill(Path(CGRect(x: rect.minX, y: yy, width: rect.width, height: 1)), with: .color(.black.opacity(0.22)))
                    }
                } else if kind == nil && mt == .wood {
                    ctx.fill(Path(CGRect(x: rect.minX, y: top, width: rect.width, height: 2)), with: .color(.black.opacity(0.3)))
                }
                let hi = Color(red: Double(min(1, c.0 * sh * 1.3)), green: Double(min(1, c.1 * sh * 1.3)), blue: Double(min(1, c.2 * sh * 1.3)))
                ctx.fill(Path(CGRect(x: rect.minX, y: top, width: rect.width, height: max(2, hgt * u * 0.05))), with: .color(hi))
            }
            if let nearest = hits.last(where: { TMap.solidMat[$0.1] != .glass }) { z[i] = nearest.0 * co }
        }
        // billboards
        var bills: [FPBill] = []
        for p in players where p.alive && p.id != focus.id {
            if !see(pos, p.pos) { continue }
            let dx = p.pos.x - pos.x
            let dy = p.pos.y - pos.y
            let d = hypot(dx, dy)
            let diff = tAngDiff(atan2(dy, dx), ang)
            if abs(diff) > 1.1 { continue }
            let perp = d * cos(diff)
            if perp < 12 { continue }
            bills.append(FPBill(perp: perp, sx: W / 2 + tan(diff) / tanH * W / 2, kind: 0, p: p, r: 0, a: 1))
        }
        var inSmoke: CGFloat = 0
        for s in smokeClouds {
            let dx = s.pos.x - pos.x
            let dy = s.pos.y - pos.y
            let d = hypot(dx, dy)
            let fade = min(1, s.life / 1.5)
            if d < s.r * 0.8 { inSmoke = max(inSmoke, fade); continue }
            let diff = tAngDiff(atan2(dy, dx), ang)
            if abs(diff) > 1.3 { continue }
            let perp = d * cos(diff)
            if perp < 12 { continue }
            bills.append(FPBill(perp: perp, sx: W / 2 + tan(diff) / tanH * W / 2, kind: 1, p: nil, r: s.r, a: fade))
        }
        if planted && TMap.los(pos, bombPos) {
            let dx = bombPos.x - pos.x
            let dy = bombPos.y - pos.y
            let diff = tAngDiff(atan2(dy, dx), ang)
            let perp = hypot(dx, dy) * cos(diff)
            if abs(diff) < 1.1 && perp > 12 {
                bills.append(FPBill(perp: perp, sx: W / 2 + tan(diff) / tanH * W / 2, kind: 2, p: nil, r: 0, a: 1))
            }
        }
        for k in packs where !k.taken && TMap.los(pos, k.pos) {
            let dx = k.pos.x - pos.x
            let dy = k.pos.y - pos.y
            let diff = tAngDiff(atan2(dy, dx), ang)
            let perp = hypot(dx, dy) * cos(diff)
            if abs(diff) < 1.1 && perp > 12 {
                bills.append(FPBill(perp: perp, sx: W / 2 + tan(diff) / tanH * W / 2, kind: 3, p: nil, r: 0, a: 1))
            }
        }
        bills.sort { $0.perp > $1.perp }
        for s in bills {
            let u = H * 0.72 / s.perp
            let floorY = hz + TMap.eyeH * u
            let half: CGFloat = (s.kind == 1 ? s.r : 14) * u
            let c0 = max(0, Int((s.sx - half) / cw))
            let c1 = min(n - 1, Int((s.sx + half) / cw))
            if c0 > c1 { continue }
            var clip = Path()
            for c in c0...c1 where z[c] > s.perp {
                clip.addRect(CGRect(x: CGFloat(c) * cw, y: 0, width: cw + 0.6, height: H))
            }
            if clip.isEmpty { continue }
            ctx.drawLayer { l in
                l.clip(to: clip)
                if s.kind == 0, let p = s.p {
                    let ally = p.team == me.team
                    let col: Color = ally ? Color(red: 0.25, green: 0.6, blue: 1) : Color(red: 1, green: 0.25, blue: 0.3)
                    l.fill(Path(ellipseIn: CGRect(x: s.sx - 14 * u, y: floorY - 4 * u, width: 28 * u, height: 8 * u)), with: .color(.black.opacity(0.35)))
                    l.fill(Path(roundedRect: CGRect(x: s.sx - 12 * u, y: floorY - 56 * u, width: 24 * u, height: 56 * u), cornerRadius: 6 * u), with: .color(col.opacity(0.85)))
                    let head = CGRect(x: s.sx - 11 * u, y: floorY - 80 * u, width: 22 * u, height: 22 * u)
                    if let img = sprites[p.handle] {
                        let im = l.resolve(Image(uiImage: img))
                        l.drawLayer { l2 in
                            l2.clip(to: Path(ellipseIn: head))
                            l2.draw(im, in: head)
                        }
                    } else {
                        l.fill(Path(ellipseIn: head), with: .color(Color(red: 0.9, green: 0.75, blue: 0.62)))
                    }
                    l.stroke(Path(ellipseIn: head), with: .color(col), lineWidth: max(1, 2 * u))
                    if p.flash > 0 {
                        l.fill(Path(ellipseIn: CGRect(x: s.sx + 6 * u, y: floorY - 42 * u, width: 16 * u, height: 16 * u)), with: .color(.yellow.opacity(0.9)))
                    }
                    if s.perp < 750 {
                        l.draw(Text(p.name).font(.system(size: 11, weight: .bold)).foregroundColor(col), at: CGPoint(x: s.sx, y: floorY - 90 * u))
                        let bx = s.sx - 18
                        let by = floorY - 82 * u
                        l.fill(Path(CGRect(x: bx, y: by, width: 36, height: 4)), with: .color(.black.opacity(0.6)))
                        l.fill(Path(CGRect(x: bx, y: by, width: 36 * max(0, p.hp / 100), height: 4)), with: .color(col))
                    }
                } else if s.kind == 1 {
                    let rr = s.r * u
                    l.fill(Path(ellipseIn: CGRect(x: s.sx - rr, y: floorY - 50 * u - rr, width: rr * 2, height: rr * 2)), with: .color(Color(white: 0.72).opacity(0.93 * Double(s.a))))
                } else if s.kind == 2 {
                    let pulse = 0.6 + 0.4 * sin(time * 8)
                    l.fill(Path(ellipseIn: CGRect(x: s.sx - 9 * u, y: floorY - 14 * u, width: 18 * u, height: 14 * u)), with: .color(Color.red.opacity(Double(pulse))))
                    l.draw(Text("BOMB").font(.system(size: 11, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: s.sx, y: floorY - 26 * u))
                } else {
                    l.fill(Path(ellipseIn: CGRect(x: s.sx - 10 * u, y: floorY - 22 * u, width: 20 * u, height: 20 * u)), with: .color(Color(red: 0.2, green: 0.8, blue: 0.4)))
                    l.fill(Path(CGRect(x: s.sx - 2 * u, y: floorY - 20 * u, width: 4 * u, height: 16 * u)), with: .color(.white))
                    l.fill(Path(CGRect(x: s.sx - 8 * u, y: floorY - 14 * u, width: 16 * u, height: 4 * u)), with: .color(.white))
                }
            }
        }
        if inSmoke > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.72).opacity(0.92 * Double(inSmoke))))
        }
        // crosshair
        let cx = W / 2
        var ch = Path()
        ch.move(to: CGPoint(x: cx - 14, y: hz)); ch.addLine(to: CGPoint(x: cx - 5, y: hz))
        ch.move(to: CGPoint(x: cx + 5, y: hz)); ch.addLine(to: CGPoint(x: cx + 14, y: hz))
        ch.move(to: CGPoint(x: cx, y: hz - 14)); ch.addLine(to: CGPoint(x: cx, y: hz - 5))
        ch.move(to: CGPoint(x: cx, y: hz + 5)); ch.addLine(to: CGPoint(x: cx, y: hz + 14))
        ctx.stroke(ch, with: .color(.white.opacity(0.85)), lineWidth: 2)
        if hitT > 0 {
            var hm = Path()
            hm.move(to: CGPoint(x: cx - 9, y: hz - 9)); hm.addLine(to: CGPoint(x: cx + 9, y: hz + 9))
            hm.move(to: CGPoint(x: cx + 9, y: hz - 9)); hm.addLine(to: CGPoint(x: cx - 9, y: hz + 9))
            ctx.stroke(hm, with: .color(.red), lineWidth: 3)
        }
        // viewmodel
        if me.alive { drawViewGun(&ctx, size) }
        drawMinimap(&ctx)
        if me.hurt > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.red.opacity(Double(me.hurt) * 0.45)))
        }
        if !me.alive {
            ctx.draw(Text("SPECTATING " + focus.name.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.7)), at: CGPoint(x: size.width / 2, y: size.height - 70))
        }
    }

    private func drawViewGun(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let id = me.gun
        let img = GunSprites.image(id)
        let mz = GunSprites.muzzle(id)
        let gw = min(size.width * 0.5, size.height * 1.6)
        let gh = gw * 0.625
        let rec: CGFloat = me.flash > 0 ? 1 : 0
        let moving = hypot(move.dx, move.dy)
        let bob = CGFloat(sin(Double(time) * 9)) * 6 * moving
        let dip: CGFloat = me.reloadT > 0 ? min(1, me.reloadT * 2.5) * gh * 0.4 : 0
        let spr = ctx.resolve(Image(uiImage: img))
        let rect = CGRect(x: size.width - gw * 0.97 + rec * 10, y: size.height - gh + 6 + dip + bob + rec * 12, width: gw, height: gh)
        ctx.draw(spr, in: rect)
        if me.flash > 0 {
            let p = CGPoint(x: rect.minX + mz.x * gw, y: rect.minY + mz.y * gh)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 30, y: p.y - 30, width: 60, height: 60)), with: .color(.yellow.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 14, y: p.y - 14, width: 28, height: 28)), with: .color(.white.opacity(0.95)))
        }
    }

    private func propLift(_ k: PropKind) -> CGFloat {
        switch k {
        case .bed: return 8
        case .couch: return 14
        case .table: return 12
        case .counter: return 18
        case .crate: return 18
        case .car: return 18
        case .shelf: return 28
        case .barrel: return 16
        case .sandbag: return 10
        case .tv: return 14
        case .plant: return 12
        }
    }

    private func drawWall(_ w: inout GraphicsContext, _ o: CGRect) {
        let h: CGFloat = 26
        w.fill(Path(CGRect(x: o.minX - 2, y: o.maxY, width: o.width + 6, height: 14)), with: .color(.black.opacity(0.22)))
        w.fill(Path(CGRect(x: o.minX, y: o.maxY, width: o.width + 3, height: 8)), with: .color(.black.opacity(0.22)))
        let face = CGRect(x: o.minX, y: o.maxY - h, width: o.width, height: h)
        w.fill(Path(face), with: .color(Color(red: 0.3, green: 0.33, blue: 0.4)))
        if o.width > o.height {
            var ln = Path()
            var y = face.minY + 8
            while y < face.maxY { ln.move(to: CGPoint(x: face.minX, y: y)); ln.addLine(to: CGPoint(x: face.maxX, y: y)); y += 8 }
            w.stroke(ln, with: .color(.black.opacity(0.28)), lineWidth: 1)
        }
        let top = o.offsetBy(dx: 0, dy: -h)
        w.fill(Path(top), with: .color(Color(red: 0.66, green: 0.69, blue: 0.74)))
        w.stroke(Path(top), with: .color(Color(red: 0.36, green: 0.4, blue: 0.46)), lineWidth: 1.5)
        w.fill(Path(CGRect(x: top.minX, y: top.minY, width: top.width, height: min(3, top.height))), with: .color(.white.opacity(0.35)))
    }

    private func drawProp3(_ w: inout GraphicsContext, _ pr: TProp) {
        let lift = propLift(pr.k)
        let r = pr.r
        w.fill(Path(roundedRect: r.offsetBy(dx: 5, dy: 8).insetBy(dx: -2, dy: -2), cornerRadius: 6), with: .color(.black.opacity(0.3)))
        let c = fpColor(pr.k)
        let side = Color(red: Double(c.0 * 0.5), green: Double(c.1 * 0.5), blue: Double(c.2 * 0.5))
        if pr.k == .barrel || pr.k == .plant {
            w.fill(Path(ellipseIn: r), with: .color(side))
            w.fill(Path(CGRect(x: r.minX, y: r.midY - lift, width: r.width, height: lift + r.height / 2)), with: .color(side))
        } else {
            w.fill(Path(roundedRect: CGRect(x: r.minX, y: r.maxY - lift, width: r.width, height: lift), cornerRadius: 3), with: .color(side))
        }
        w.drawLayer { l in
            l.translateBy(x: 0, y: -lift)
            drawProp(&l, TProp(r: r, k: pr.k))
        }
    }

    private func floorFill(_ w: inout GraphicsContext, _ rm: TRoom, _ vis: CGRect) {
        let cols: [Color] = [
            Color(red: 0.45, green: 0.31, blue: 0.19),
            Color(red: 0.34, green: 0.36, blue: 0.38),
            Color(red: 0.27, green: 0.24, blue: 0.33),
            Color(red: 0.5, green: 0.54, blue: 0.56),
            Color(red: 0.28, green: 0.19, blue: 0.13),
            Color(red: 0.4, green: 0.4, blue: 0.42)
        ]
        w.fill(Path(vis), with: .color(cols[rm.mat]))
        var ln = Path()
        switch rm.mat {
        case 0, 4:
            var y = (vis.minY / 26).rounded(.down) * 26
            while y < vis.maxY {
                ln.move(to: CGPoint(x: vis.minX, y: y)); ln.addLine(to: CGPoint(x: vis.maxX, y: y)); y += 26
            }
        case 3, 5:
            var x = (vis.minX / 56).rounded(.down) * 56
            while x < vis.maxX { ln.move(to: CGPoint(x: x, y: vis.minY)); ln.addLine(to: CGPoint(x: x, y: vis.maxY)); x += 56 }
            var y = (vis.minY / 56).rounded(.down) * 56
            while y < vis.maxY { ln.move(to: CGPoint(x: vis.minX, y: y)); ln.addLine(to: CGPoint(x: vis.maxX, y: y)); y += 56 }
        case 1:
            var x = (vis.minX / 140).rounded(.down) * 140
            while x < vis.maxX { ln.move(to: CGPoint(x: x, y: vis.minY)); ln.addLine(to: CGPoint(x: x, y: vis.maxY)); x += 140 }
            var y = (vis.minY / 140).rounded(.down) * 140
            while y < vis.maxY { ln.move(to: CGPoint(x: vis.minX, y: y)); ln.addLine(to: CGPoint(x: vis.maxX, y: y)); y += 140 }
        default:
            break
        }
        w.stroke(ln, with: .color(.black.opacity(0.17)), lineWidth: 1.2)
        let fs: CGFloat = rm.r.width < 200 ? 11 : 15
        w.draw(Text(rm.name.uppercased()).font(.system(size: fs, weight: .heavy)).foregroundColor(.white.opacity(0.2)), at: CGPoint(x: rm.r.midX, y: rm.r.minY + 28))
    }

    private func drawProp(_ w: inout GraphicsContext, _ pr: TProp) {
        let r = pr.r
        w.fill(Path(r.offsetBy(dx: 0, dy: 7)), with: .color(.black.opacity(0.4)))
        let rr = Path(roundedRect: r, cornerRadius: 5)
        switch pr.k {
        case .bed:
            w.fill(rr, with: .color(Color(red: 0.32, green: 0.4, blue: 0.62)))
            w.fill(Path(roundedRect: CGRect(x: r.minX + 8, y: r.minY + 8, width: r.width - 16, height: 28), cornerRadius: 6), with: .color(.white.opacity(0.85)))
            w.fill(Path(CGRect(x: r.minX, y: r.minY + 70, width: r.width, height: 3)), with: .color(.black.opacity(0.25)))
        case .couch:
            w.fill(rr, with: .color(Color(red: 0.55, green: 0.26, blue: 0.3)))
            if r.width >= r.height {
                w.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: min(16, r.height * 0.35))), with: .color(.black.opacity(0.28)))
            } else {
                w.fill(Path(CGRect(x: r.minX, y: r.minY, width: min(16, r.width * 0.35), height: r.height)), with: .color(.black.opacity(0.28)))
            }
        case .table:
            w.fill(rr, with: .color(Color(red: 0.62, green: 0.44, blue: 0.26)))
            w.stroke(Path(roundedRect: r.insetBy(dx: 5, dy: 5), cornerRadius: 3), with: .color(.black.opacity(0.22)), lineWidth: 1.5)
        case .counter:
            w.fill(rr, with: .color(Color(red: 0.78, green: 0.8, blue: 0.82)))
            w.stroke(Path(roundedRect: r.insetBy(dx: 4, dy: 4), cornerRadius: 3), with: .color(.black.opacity(0.3)), lineWidth: 2)
        case .crate:
            w.fill(rr, with: .color(Color(red: 0.52, green: 0.38, blue: 0.22)))
            w.stroke(rr, with: .color(.black.opacity(0.35)), lineWidth: 2)
            var x = Path()
            x.move(to: CGPoint(x: r.minX + 5, y: r.minY + 5)); x.addLine(to: CGPoint(x: r.maxX - 5, y: r.maxY - 5))
            x.move(to: CGPoint(x: r.maxX - 5, y: r.minY + 5)); x.addLine(to: CGPoint(x: r.minX + 5, y: r.maxY - 5))
            w.stroke(x, with: .color(.black.opacity(0.25)), lineWidth: 2)
        case .car:
            w.fill(Path(roundedRect: r, cornerRadius: 16), with: .color(Color(red: 0.2, green: 0.38, blue: 0.62)))
            w.fill(Path(roundedRect: CGRect(x: r.minX + r.width * 0.55, y: r.minY + 8, width: r.width * 0.2, height: r.height - 16), cornerRadius: 5), with: .color(Color(red: 0.1, green: 0.14, blue: 0.2)))
            w.fill(Path(ellipseIn: CGRect(x: r.maxX - 10, y: r.minY + 8, width: 6, height: 10)), with: .color(.yellow))
            w.fill(Path(ellipseIn: CGRect(x: r.maxX - 10, y: r.maxY - 18, width: 6, height: 10)), with: .color(.yellow))
        case .shelf:
            w.fill(rr, with: .color(Color(red: 0.3, green: 0.22, blue: 0.15)))
            var ln = Path()
            if r.width >= r.height {
                var x = r.minX + 12
                while x < r.maxX { ln.move(to: CGPoint(x: x, y: r.minY)); ln.addLine(to: CGPoint(x: x, y: r.maxY)); x += 12 }
            } else {
                var y = r.minY + 12
                while y < r.maxY { ln.move(to: CGPoint(x: r.minX, y: y)); ln.addLine(to: CGPoint(x: r.maxX, y: y)); y += 12 }
            }
            w.stroke(ln, with: .color(.black.opacity(0.35)), lineWidth: 1.5)
        case .barrel:
            w.fill(Path(ellipseIn: r), with: .color(Color(red: 0.5, green: 0.2, blue: 0.14)))
            w.stroke(Path(ellipseIn: r.insetBy(dx: 7, dy: 7)), with: .color(.black.opacity(0.35)), lineWidth: 2)
        case .sandbag:
            w.fill(rr, with: .color(Color(red: 0.76, green: 0.68, blue: 0.44)))
            w.stroke(rr, with: .color(.black.opacity(0.3)), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        case .tv:
            w.fill(rr, with: .color(Color(red: 0.08, green: 0.09, blue: 0.11)))
            w.fill(Path(CGRect(x: r.minX + 6, y: r.minY + 6, width: r.width - 12, height: r.height - 14)), with: .color(Color(red: 0.2, green: 0.45, blue: 0.7).opacity(0.8)))
        case .plant:
            w.fill(Path(ellipseIn: r), with: .color(Color(red: 0.16, green: 0.45, blue: 0.22)))
            w.fill(Path(ellipseIn: r.insetBy(dx: r.width * 0.3, dy: r.height * 0.3)), with: .color(Color(red: 0.4, green: 0.28, blue: 0.18)))
        }
    }

    private func drawPlayer(_ w: inout GraphicsContext, _ p: TPlayer) {
        let ally = p.team == me.team
        let ring: Color = p.isPlayer ? Color(red: 0.4, green: 0.95, blue: 0.5) : (ally ? Color(red: 0.25, green: 0.6, blue: 1) : Color(red: 1, green: 0.25, blue: 0.3))
        w.fill(Path(ellipseIn: CGRect(x: p.pos.x - 13, y: p.pos.y + 8, width: 26, height: 10)), with: .color(.black.opacity(0.35)))
        w.drawLayer { l in
            l.translateBy(x: p.pos.x, y: p.pos.y)
            l.rotate(by: .radians(Double(p.aim)))
            l.fill(Path(roundedRect: CGRect(x: 8, y: -3.5, width: 22, height: 7), cornerRadius: 2), with: .color(Color(white: 0.85)))
            l.fill(Path(CGRect(x: 26, y: -2.2, width: 9, height: 4.4)), with: .color(Color(white: 0.45)))
            if p.flash > 0 { l.fill(Path(ellipseIn: CGRect(x: 32, y: -8, width: 16, height: 16)), with: .color(.yellow.opacity(0.9))) }
        }
        let rect = CGRect(x: p.pos.x - 14, y: p.pos.y - 14, width: 28, height: 28)
        if let img = sprites[p.handle] {
            let im = w.resolve(Image(uiImage: img))
            w.drawLayer { l in
                l.clip(to: Path(ellipseIn: rect))
                l.draw(im, in: rect)
            }
        } else {
            w.fill(Path(ellipseIn: rect), with: .color(ring.opacity(0.6)))
            w.draw(Text(p.emoji).font(.system(size: 18)), at: p.pos)
        }
        w.stroke(Path(ellipseIn: rect), with: .color(p.hurt > 0 ? .white : ring), lineWidth: 3)
        // name + hp
        w.draw(Text(p.name).font(.system(size: 11, weight: .bold)).foregroundColor(ring), at: CGPoint(x: p.pos.x, y: p.pos.y - 32))
        let bar = CGRect(x: p.pos.x - 18, y: p.pos.y - 25, width: 36, height: 4)
        w.fill(Path(bar), with: .color(.black.opacity(0.6)))
        w.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: 36 * max(0, p.hp / 100), height: 4)), with: .color(ring))
        if p.reloadT > 0 {
            w.draw(Text("reload").font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.8)), at: CGPoint(x: p.pos.x, y: p.pos.y + 26))
        }
    }

    func drawMinimapPublic(_ ctx: inout GraphicsContext) { drawMinimap(&ctx) }

    private func drawMinimap(_ ctx: inout GraphicsContext) {
        let s: CGFloat = 0.15
        let ox: CGFloat = 16, oy: CGFloat = 104
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        let fl = TMap.floorOf(focus.pos)
        let fo: CGFloat = fl == 1 ? TMap.off : 0
        let w = TMap.floorW * s, h = TMap.H * s
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + (x - fo) * s, y: oy + y * s) }
        func R(_ r: CGRect) -> CGRect { CGRect(x: ox + (r.minX - fo) * s, y: oy + r.minY * s, width: r.width * s, height: r.height * s) }
        func here(_ p: CGPoint) -> Bool { TMap.floorOf(p) == fl }
        func hereR(_ r: CGRect) -> Bool { TMap.floorOf(CGPoint(x: r.midX, y: r.midY)) == fl }
        let frame = CGRect(x: ox - 5, y: oy - 5, width: w + 10, height: h + 10)
        ctx.fill(Path(roundedRect: frame, cornerRadius: 10), with: .color(Color(red: 0.04, green: 0.05, blue: 0.08).opacity(0.82)))
        ctx.stroke(Path(roundedRect: frame, cornerRadius: 10), with: .color(.white.opacity(0.35)), lineWidth: 1.5)
        ctx.draw(Text(fl == 0 ? "GROUND FLOOR" : "UPSTAIRS").font(.system(size: 9, weight: .heavy)).foregroundColor(fl == 0 ? Color.white.opacity(0.8) : Color(red: 0.85, green: 0.93, blue: 0.2)), at: CGPoint(x: ox + w / 2, y: oy - 11))
        let floors: [Color] = [Color(red: 0.45, green: 0.31, blue: 0.19), Color(red: 0.34, green: 0.36, blue: 0.38), Color(red: 0.27, green: 0.24, blue: 0.33), Color(red: 0.5, green: 0.54, blue: 0.56), Color(red: 0.28, green: 0.19, blue: 0.13), Color(red: 0.4, green: 0.4, blue: 0.42)]
        for rm in TMap.rooms where hereR(rm.r) {
            ctx.fill(Path(R(rm.r)), with: .color(floors[rm.mat % floors.count].opacity(0.55)))
        }
        for pr in TMap.props where hereR(pr.r) {
            ctx.fill(Path(roundedRect: R(pr.r), cornerRadius: 1.5), with: .color(.black.opacity(0.35)))
        }
        for d in TMap.doors where hereR(d) {
            ctx.fill(Path(R(d)), with: .color(Color(red: 0.7, green: 0.5, blue: 0.25).opacity(0.9)))
        }
        for (k, wl) in TMap.walls.enumerated() where hereR(wl) {
            let r = R(wl)
            let rr = CGRect(x: r.minX, y: r.minY, width: max(2, r.width), height: max(2, r.height))
            let c: Color
            switch TMap.wallMats[k] {
            case .brick: c = Color(red: 0.85, green: 0.5, blue: 0.42)
            case .concrete: c = Color(red: 0.82, green: 0.86, blue: 0.95)
            case .wood: c = Color(red: 0.8, green: 0.6, blue: 0.35)
            case .glass: c = Color(red: 0.5, green: 0.85, blue: 1)
            }
            ctx.fill(Path(rr), with: .color(c.opacity(TMap.wallMats[k] == .glass ? 0.55 : 0.92)))
        }
        for rm in TMap.rooms where hereR(rm.r) {
            ctx.draw(Text(rm.name.uppercased()).font(.system(size: 6, weight: .bold)).foregroundColor(.white.opacity(0.55)), at: CGPoint(x: R(rm.r).midX, y: R(rm.r).minY + 8))
        }
        let pulse = 0.5 + 0.5 * sin(Double(time) * 4)
        for i in 0..<2 where hereR(TMap.site(i)) {
            let r = R(TMap.site(i))
            let hot = i == atkSite && !planted
            ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(Color.yellow.opacity(hot ? 0.25 + 0.2 * pulse : 0.18)))
            ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(Color.yellow.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
            ctx.draw(Text(i == 0 ? "A" : "B").font(.system(size: 14, weight: .heavy)).foregroundColor(.yellow), at: CGPoint(x: r.midX, y: r.midY))
        }
        for i in TMap.stairs.indices {
            let r = R(TMap.stairRect(i, floor: fl))
            ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(.white.opacity(0.22)))
            var st = Path()
            var yy = r.minY + 3
            while yy < r.maxY - 1 { st.move(to: CGPoint(x: r.minX + 2, y: yy)); st.addLine(to: CGPoint(x: r.maxX - 2, y: yy)); yy += 3 }
            ctx.stroke(st, with: .color(.white.opacity(0.55)), lineWidth: 0.8)
            ctx.draw(Text(fl == 0 ? "UP" : "DN").font(.system(size: 6, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: r.midX, y: r.midY))
        }
        for pk in packs where !pk.taken && here(pk.pos) {
            let c = P(pk.pos.x, pk.pos.y)
            ctx.fill(Path(CGRect(x: c.x - 3, y: c.y - 1, width: 6, height: 2)), with: .color(.green))
            ctx.fill(Path(CGRect(x: c.x - 1, y: c.y - 3, width: 2, height: 6)), with: .color(.green))
        }
        for sm in smokeClouds where here(sm.pos) {
            let c = P(sm.pos.x, sm.pos.y)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - sm.r * s, y: c.y - sm.r * s, width: sm.r * 2 * s, height: sm.r * 2 * s)), with: .color(.white.opacity(0.35)))
        }
        if me.alive && here(me.pos) {
            let c = P(me.pos.x, me.pos.y)
            var cone = Path()
            cone.move(to: c)
            cone.addArc(center: c, radius: 70, startAngle: .radians(Double(me.aim) - 0.55), endAngle: .radians(Double(me.aim) + 0.55), clockwise: false)
            cone.closeSubpath()
            ctx.fill(cone, with: .color(.green.opacity(0.18)))
        }
        for p in players where p.alive && here(p.pos) && (p.team == me.team || p.spotted) {
            let c = P(p.pos.x, p.pos.y)
            let col: Color = p.isPlayer ? Color(red: 0.3, green: 0.95, blue: 0.45) : (p.team == me.team ? Color(red: 0.3, green: 0.62, blue: 1) : Color(red: 1, green: 0.28, blue: 0.3))
            let a = Double(p.aim)
            var tri = Path()
            let sz: CGFloat = p.isPlayer ? 6.5 : 5
            tri.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * sz * 1.4, y: c.y + CGFloat(sin(a)) * sz * 1.4))
            tri.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + 2.5)) * sz, y: c.y + CGFloat(sin(a + 2.5)) * sz))
            tri.addLine(to: CGPoint(x: c.x + CGFloat(cos(a - 2.5)) * sz, y: c.y + CGFloat(sin(a - 2.5)) * sz))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(col))
            ctx.stroke(tri, with: .color(.black.opacity(0.7)), lineWidth: 0.8)
            if p.team != me.team {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)), with: .color(col.opacity(0.4 + 0.4 * pulse)), lineWidth: 1)
            }
        }
        for p in players where !p.alive && here(p.pos) && (p.team == me.team || p.seenEver) {
            ctx.draw(Text("\u{2715}").font(.system(size: 8, weight: .heavy)).foregroundColor(.white.opacity(0.6)), at: P(p.pos.x, p.pos.y))
        }
        for pg in pings where here(pg.pos) {
            let c = P(pg.pos.x, pg.pos.y)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.orange.opacity(Double(min(1, pg.life)))), lineWidth: 1.5)
        }
        if planted && here(bombPos) {
            let c = P(bombPos.x, bombPos.y)
            let rr = 5 + 5 * CGFloat(pulse)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(.red.opacity(0.8)), lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(.orange))
        }
    }

    // MARK: HUD helpers

    var meInSite: Bool { me.alive && me.team == atkTeam && !planted && TMap.site(atkSite).contains(me.pos) }
    var meNearBomb: Bool { me.alive && me.team != atkTeam && planted && tDist(me.pos, bombPos) < 46 }
    var allyAlive: Int { players.filter { $0.team == me.team && $0.alive }.count }
    var enemyAlive: Int { players.filter { $0.team != me.team && $0.alive }.count }
    var objectiveText: String {
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
    var fpMode = false
    @State private var engine = TacticalEngine()
    @State private var lStart: CGPoint? = nil
    @State private var lKnob: CGPoint = .zero
    @State private var rStart: CGPoint? = nil
    @State private var rKnob: CGPoint = .zero
    @State private var collected = false
    @State private var mode = 0
    @State private var autoOn = true
    @State private var bridge: TacScene? = nil
    private var fp: Bool { mode == 1 }
    @State private var lastLook: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let b = bridge, mode == 0 {
                TacSceneView(bridge: b).ignoresSafeArea().allowsHitTesting(false)
            }
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    engine.step(tl.date)
                    if mode == 0 { bridge?.sync(engine) }
                    engine.draw(&ctx, size)
                }
            }
            .ignoresSafeArea()
            controls
            hud
            if engine.paused && !engine.over { pauseView }
            if engine.over { overView }
        }
        .statusBarHidden(true)
        .onAppear {
            OrientationLock.set(landscape: true)
            mode = fpMode ? 1 : 0
            engine.fp = fpMode
            engine.view3D = !fpMode
            engine.autoAim = true
            autoOn = true
            let st = game.s
            let cast = st.npcs.filter { $0.id != "newsdesk" }
            let owned = (st.ex.surv ?? SurvData()).guns
            let gun = owned.contains("rifle") ? "rifle" : (owned.contains("smg") ? "smg" : "pistol")
            engine.setup(cast: cast, persona: st.persona, gun: gun, diff: diff)
            let b = TacScene()
            b.build(engine)
            bridge = b
            engine.project = { [weak b] p, h in b?.project(p, h) }
            Task { @MainActor in
                engine.sprites[st.persona.handle] = SurvivalSprites.render(emoji: st.persona.emoji, key: st.persona.handle, size: 64)
                for p in engine.players where !p.isPlayer {
                    engine.sprites[p.handle] = SurvivalSprites.render(emoji: p.emoji, key: p.handle, size: 64)
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
                                engine.move = d > 4 ? CGVector(dx: dx / d * k, dy: dy / d * k) : .zero
                            }
                            .onEnded { _ in lStart = nil; engine.move = .zero })
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if fp {
                                    engine.lookDelta += (v.translation.width - lastLook) * 0.008
                                    lastLook = v.translation.width
                                    return
                                }
                                rStart = v.startLocation
                                rKnob = v.location
                                let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                                if hypot(dx, dy) > 8 { engine.aimIn = atan2(dy, dx) }
                                engine.firing = true
                            }
                            .onEnded { _ in rStart = nil; lastLook = 0; engine.aimIn = nil; engine.firing = false })
                }
                if let s = lStart { stick(s, lKnob, Color.white) }
                if let s = rStart { stick(s, rKnob, Color.red) }
                if fp {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            fireButton.padding(.trailing, 36).padding(.bottom, 56)
                        }
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
    }

    private var fireButton: some View {
        Circle().fill(Color.red.opacity(0.45)).frame(width: 78, height: 78)
            .overlay(Circle().stroke(Color.red.opacity(0.7), lineWidth: 3))
            .overlay(Text("FIRE").font(.jk(13, .heavy)).foregroundColor(.white))
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

    private func chip(_ p: TPlayer, ally: Bool) -> some View {
        let show = ally || p.seenEver
        return VStack(spacing: 2) {
            ZStack {
                if show, let img = engine.sprites[p.handle] {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)).frame(width: 28, height: 28)
                    Text(show ? p.emoji : "?").font(.jk(14, .heavy)).foregroundColor(.white.opacity(0.7))
                }
                if !p.alive { Color.black.opacity(0.6).frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 6)) }
                if !p.alive { Image(systemName: "xmark").font(.system(size: 12, weight: .black)).foregroundColor(.red) }
            }
            Capsule().fill(Color.white.opacity(0.15)).frame(width: 28, height: 3)
                .overlay(alignment: .leading) {
                    Capsule().fill(ally ? Color(red: 0.25, green: 0.6, blue: 1) : Color(red: 1, green: 0.3, blue: 0.35))
                        .frame(width: 28 * max(0, p.alive ? p.hp / 100 : 0), height: 3)
                }
        }
    }

    private var hud: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let e = engine
            let allies = e.players.filter { $0.team == e.me.team }
            let foes = e.players.filter { $0.team != e.me.team }
            let t = Int(max(0, e.timer))
            let matchPoint = e.scores.contains(e.target - 1)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    HStack(spacing: 3) { ForEach(allies, id: \.id) { chip($0, ally: true) } }
                    Spacer(minLength: 4)
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(e.scores[0])").font(.jk(16, .heavy)).foregroundColor(.white)
                                .frame(width: 26, height: 26).background(Color(red: 0.25, green: 0.6, blue: 1)).clipShape(RoundedRectangle(cornerRadius: 5))
                            Text(String(format: "%d:%02d", t / 60, t % 60)).font(.jk(18, .heavy)).foregroundColor(e.planted ? .red : .white)
                            Text("\(e.scores[1])").font(.jk(16, .heavy)).foregroundColor(.white)
                                .frame(width: 26, height: 26).background(Color(red: 1, green: 0.25, blue: 0.4)).clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        Text(matchPoint ? "Match Point" : "Round \(e.round)").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.85))
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 3) { ForEach(foes, id: \.id) { chip($0, ally: false) } }
                }
                .padding(.horizontal, 8).padding(.top, 8)
                Text(e.objectiveText).font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.85)).padding(.top, 6)
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(Array(e.feed.enumerated()), id: \.offset) { _, f in
                            Text(f.text).font(.jk(10, .bold)).foregroundColor(f.mine ? .yellow : .white.opacity(0.8))
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.top, 4)
                if e.bannerT > 0 {
                    Text(e.banner).font(.jk(26, .heavy)).foregroundColor(.white).shadow(radius: 6).multilineTextAlignment(.center)
                        .padding(.top, 28).padding(.horizontal, 20).opacity(Double(min(1, e.bannerT)))
                }
                Spacer()
                if e.plantProg > 0 || e.defuseProg > 0 {
                    let pr = e.plantProg > 0 ? e.plantProg / 3 : e.defuseProg / 4
                    VStack(spacing: 4) {
                        Text(e.plantProg > 0 ? "PLANTING" : "DEFUSING").font(.jk(11, .heavy)).foregroundColor(.white)
                        Capsule().fill(Color.white.opacity(0.2)).frame(width: 160, height: 8)
                            .overlay(alignment: .leading) { Capsule().fill(Color.yellow).frame(width: 160 * min(1, pr), height: 8) }
                    }
                    .padding(.bottom, 6)
                }
                HStack(spacing: 10) {
                    if !e.me.alive && e.phase < 3 {
                        Button { e.fast.toggle() } label: {
                            Text(e.fast ? "Normal speed" : "Skip ahead").font(.jk(13, .bold)).foregroundColor(.white)
                                .padding(.horizontal, 14).frame(height: 38).background(Color.black.opacity(0.55)).clipShape(Capsule())
                        }
                    } else {
                        Button { e.wantNade = true } label: {
                            Text("Nade \(e.me.nades)").font(.jk(12, .bold)).foregroundColor(e.me.nades > 0 ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 12).frame(height: 38).background(Color.black.opacity(0.55)).clipShape(Capsule())
                        }
                        Button { e.wantSmoke = true } label: {
                            Text("Smoke \(e.me.smokes)").font(.jk(12, .bold)).foregroundColor(e.me.smokes > 0 ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 12).frame(height: 38).background(Color.black.opacity(0.55)).clipShape(Capsule())
                        }
                        Text(e.me.reloadT > 0 ? "RELOADING" : "\(e.me.mag) / \(e.me.gun == "pistol" ? "∞" : "\(e.me.spare * Guns.get(e.me.gun).mag)")")
                            .font(.jk(17, .heavy)).foregroundColor(e.me.mag == 0 ? .red : .white)
                        Button { e.wantReload = true } label: {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                .frame(width: 38, height: 38).background(Color.black.opacity(0.55)).clipShape(Circle())
                        }
                        if e.meInSite || e.meNearBomb {
                            Text(e.meInSite ? "HOLD PLANT" : "HOLD DEFUSE").font(.jk(12, .heavy)).foregroundColor(.black)
                                .padding(.horizontal, 14).frame(height: 44).background(Color.yellow).clipShape(Capsule())
                                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in e.actHeld = true }.onEnded { _ in e.actHeld = false })
                        }
                    }
                    Button { e.autoAim.toggle(); autoOn = e.autoAim } label: {
                        Text(autoOn ? "AUTO" : "MAN").font(.jk(12, .heavy)).foregroundColor(autoOn ? .black : .white)
                            .padding(.horizontal, 12).frame(height: 38).background(autoOn ? Color(red: 0.85, green: 0.93, blue: 0.2) : Color.black.opacity(0.55)).clipShape(Capsule())
                    }
                    Button { e.paused = true } label: {
                        Image(systemName: "pause.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 38, height: 38).background(Color.black.opacity(0.55)).clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: fpMode ? .leading : .center)
                .padding(.leading, fpMode ? 200 : 0)
                .padding(.bottom, 14)
            }
        }
    }

    private var pauseView: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PAUSED").font(.jk(30, .heavy))
                Button { engine.paused = false; engine.last = nil } label: {
                    Text("Resume").font(.jk(18, .bold)).foregroundColor(.black).frame(width: 220, height: 50).background(Color.white).clipShape(Capsule())
                }
                Button { engine.scores = [0, engine.target]; engine.over = true; engine.won = false; engine.paused = false } label: {
                    Text("Forfeit match").font(.jk(16, .bold)).foregroundColor(.red).frame(width: 220, height: 46).background(Color.red.opacity(0.15)).clipShape(Capsule())
                }
            }
        }
    }

    private var overView: some View {
        let e = engine
        let gems = (e.won ? 25 : 8) + e.kills * 2 + e.scores[0] * 3
        return ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(e.won ? "VICTORY" : "DEFEAT").font(.jk(40, .heavy)).foregroundColor(e.won ? Color(red: 0.4, green: 0.95, blue: 0.5) : .red)
                Text("\(e.scores[0])  :  \(e.scores[1])").font(.jk(28, .heavy))
                Text("\(e.kills) kills   \(gems) gems").font(.jk(17, .semibold))
                Button {
                    guard !collected else { return }
                    collected = true
                    game.tacticalFinish(won: e.won, kills: e.kills, gems: gems)
                    dismiss()
                } label: {
                    Text("Collect and exit").font(.jk(18, .bold)).foregroundColor(.black).frame(width: 240, height: 52).background(Color.white).clipShape(Capsule())
                }
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
        st.ex.tac = d
        st.ex.gems += gems
        gainXP(&st, won ? 40 : 15)
        s = st
        showToast("+\(gems) gems")
    }
}
