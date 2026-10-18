import SwiftUI

typealias BRCol = (CGFloat, CGFloat, CGFloat)

func brWrap(_ a: CGFloat) -> CGFloat {
    var d = a
    while d > .pi { d -= 2 * .pi }
    while d < -.pi { d += 2 * .pi }
    return d
}

func brc(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> Color {
    Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
}

struct BRRand {
    var s: UInt64
    mutating func f() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
    mutating func r(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * f() }
}

struct BRGunDef {
    let id: String
    let name: String
    let dmg: CGFloat
    let rate: CGFloat
    let mag: Int
    let range: CGFloat
    let spread: CGFloat
    let reload: CGFloat
    let pellets: Int
}

enum BRGuns {
    static let all: [BRGunDef] = [
        BRGunDef(id: "pistol", name: "M9 SIDEARM", dmg: 22, rate: 0.28, mag: 15, range: 650, spread: 0.025, reload: 1.2, pellets: 1),
        BRGunDef(id: "smg", name: "VX-9 SMG", dmg: 14, rate: 0.075, mag: 30, range: 520, spread: 0.05, reload: 1.6, pellets: 1),
        BRGunDef(id: "rifle", name: "AR-27 RIFLE", dmg: 24, rate: 0.12, mag: 30, range: 1100, spread: 0.02, reload: 2.0, pellets: 1),
        BRGunDef(id: "shotgun", name: "BREACHER", dmg: 11, rate: 0.9, mag: 6, range: 320, spread: 0.09, reload: 2.4, pellets: 8)
    ]
    static func def(_ id: String) -> BRGunDef { all.first { $0.id == id } ?? all[0] }
}

struct BRWall {
    let r: CGRect
    let h: CGFloat
    let c: BRCol
}

struct BRBuilding {
    let r: CGRect
    let kind: Int
}

func brRay(_ o: CGPoint, _ dx: CGFloat, _ dy: CGFloat, _ r: CGRect) -> (CGFloat, Bool)? {
    var tmin: CGFloat = 0
    var tmax: CGFloat = 100000
    var side = false
    if abs(dx) < 1e-9 {
        if o.x < r.minX || o.x > r.maxX { return nil }
    } else {
        let t1 = (r.minX - o.x) / dx
        let t2 = (r.maxX - o.x) / dx
        let lo = min(t1, t2), hi = max(t1, t2)
        if lo > tmin { tmin = lo; side = true }
        tmax = min(tmax, hi)
    }
    if abs(dy) < 1e-9 {
        if o.y < r.minY || o.y > r.maxY { return nil }
    } else {
        let t1 = (r.minY - o.y) / dy
        let t2 = (r.maxY - o.y) / dy
        let lo = min(t1, t2), hi = max(t1, t2)
        if lo > tmin { tmin = lo; side = false }
        tmax = min(tmax, hi)
    }
    if tmin > tmax { return nil }
    return (tmin, side)
}

final class BRWorld {
    static let W: CGFloat = 6000
    static let cell: CGFloat = 250
    static let shared: BRWorld = {
        let w = BRWorld()
        w.generate()
        return w
    }()

    var walls: [BRWall] = []
    var blds: [BRBuilding] = []
    var runways: [CGRect] = []
    var trees: [CGPoint] = []
    var spots: [CGPoint] = []
    var places: [(String, CGPoint)] = []
    var grid: [Int: [Int]] = [:]
    var stamp: [Int] = []
    var tick = 0

    private var rng = BRRand(s: 20260611)
    private let t: CGFloat = 14

    static func water(_ p: CGPoint) -> Bool {
        let coastX: CGFloat = 420 + 260 * sin(p.y / 640) + 140 * sin(p.y / 230)
        let coastY: CGFloat = 5560 + 200 * sin(p.x / 540)
        if p.x < coastX || p.y > coastY { return true }
        if p.x > W - 110 || p.y < 110 { return true }
        return false
    }

    // MARK: generation

    private let towns: [BRCol] = [(0.78, 0.72, 0.6), (0.85, 0.82, 0.74), (0.62, 0.38, 0.3), (0.7, 0.6, 0.5), (0.55, 0.58, 0.62), (0.8, 0.66, 0.46)]

    private func addWall(_ r: CGRect, _ h: CGFloat, _ c: BRCol) {
        walls.append(BRWall(r: r, h: h, c: c))
    }

    private func hw(_ x0: CGFloat, _ x1: CGFloat, _ y: CGFloat, _ gap: CGFloat?, _ h: CGFloat, _ c: BRCol) {
        let g: CGFloat = 96
        if let gc = gap {
            addWall(CGRect(x: x0, y: y - t / 2, width: gc - g / 2 - x0, height: t), h, c)
            addWall(CGRect(x: gc + g / 2, y: y - t / 2, width: x1 - gc - g / 2, height: t), h, c)
        } else {
            addWall(CGRect(x: x0, y: y - t / 2, width: x1 - x0, height: t), h, c)
        }
    }

    private func vw(_ y0: CGFloat, _ y1: CGFloat, _ x: CGFloat, _ gap: CGFloat?, _ h: CGFloat, _ c: BRCol) {
        let g: CGFloat = 96
        if let gc = gap {
            addWall(CGRect(x: x - t / 2, y: y0, width: t, height: gc - g / 2 - y0), h, c)
            addWall(CGRect(x: x - t / 2, y: gc + g / 2, width: t, height: y1 - gc - g / 2), h, c)
        } else {
            addWall(CGRect(x: x - t / 2, y: y0, width: t, height: y1 - y0), h, c)
        }
    }

    private func isFree(_ r: CGRect, _ pad: CGFloat) -> Bool {
        let e = r.insetBy(dx: -pad, dy: -pad)
        for b in blds where b.r.intersects(e) { return false }
        for rw in runways where rw.intersects(e) { return false }
        let pts = [CGPoint(x: e.minX, y: e.minY), CGPoint(x: e.maxX, y: e.minY), CGPoint(x: e.minX, y: e.maxY), CGPoint(x: e.maxX, y: e.maxY), CGPoint(x: e.midX, y: e.midY)]
        for p in pts where BRWorld.water(p) { return false }
        return true
    }

    private func building(_ r: CGRect, _ h: CGFloat, _ c: BRCol, _ kind: Int) {
        let side = Int(rng.f() * 4) % 4
        let big = r.width > 300
        let gx = rng.r(r.minX + 70, r.maxX - 70)
        let gy = rng.r(r.minY + 70, r.maxY - 70)
        let d0 = side == 0 || (big && side == 1)
        let d1 = side == 1 || (big && side == 0)
        let d2 = side == 2 || (big && side == 3)
        let d3 = side == 3 || (big && side == 2)
        hw(r.minX, r.maxX, r.minY, d0 ? gx : nil, h, c)
        hw(r.minX, r.maxX, r.maxY, d1 ? rng.r(r.minX + 70, r.maxX - 70) : nil, h, c)
        vw(r.minY, r.maxY, r.minX, d2 ? gy : nil, h, c)
        vw(r.minY, r.maxY, r.maxX, d3 ? rng.r(r.minY + 70, r.maxY - 70) : nil, h, c)
        if r.width > 280 {
            let px = r.minX + r.width * rng.r(0.42, 0.58)
            vw(r.minY, r.maxY, px, rng.r(r.minY + 70, r.maxY - 70), h, c)
        }
        blds.append(BRBuilding(r: r, kind: kind))
        let a = CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * rng.r(0.3, 0.7))
        let b = CGPoint(x: r.minX + r.width * 0.74, y: r.minY + r.height * rng.r(0.3, 0.7))
        spots.append(a)
        spots.append(b)
    }

    private func container(_ r: CGRect, _ c: BRCol) {
        addWall(r, 44, c)
        spots.append(CGPoint(x: r.midX, y: r.maxY + 40))
    }

    private func generate() {
        // Port Ridge: the town grid
        var bx: CGFloat = 1900
        while bx < 3800 {
            var by: CGFloat = 2300
            while by < 4000 {
                if rng.f() > 0.12 {
                    let w = rng.r(240, 320), h = rng.r(220, 300)
                    let r = CGRect(x: bx + rng.r(0, 50), y: by + rng.r(0, 50), width: w, height: h)
                    let c = towns[Int(rng.f() * 6) % 6]
                    building(r, rng.r(88, 130), c, 0)
                }
                by += 400
            }
            bx += 440
        }
        places.append(("PORT RIDGE", CGPoint(x: 2800, y: 3150)))

        // Steel Yard: warehouses and container stacks
        for i in 0..<3 {
            for j in 0..<3 {
                let r = CGRect(x: 4000 + CGFloat(i) * 540, y: 800 + CGFloat(j) * 480, width: 440, height: 280)
                building(r, 140, (0.5, 0.54, 0.58), 1)
            }
        }
        var n = 0
        var tries = 0
        while n < 18 && tries < 200 {
            tries += 1
            let horiz = rng.f() > 0.5
            let w: CGFloat = horiz ? 84 : 32
            let h: CGFloat = horiz ? 32 : 84
            let r = CGRect(x: rng.r(3950, 5600), y: rng.r(700, 2100), width: w, height: h)
            if isFree(r, 36) && !wallHit(r.insetBy(dx: -30, dy: -30)) {
                let cols: [BRCol] = [(0.7, 0.22, 0.18), (0.2, 0.36, 0.6), (0.85, 0.55, 0.15), (0.25, 0.5, 0.35)]
                container(r, cols[n % 4])
                n += 1
            }
        }
        places.append(("STEEL YARD", CGPoint(x: 4750, y: 1450)))

        // Highland Strip: airfield
        runways.append(CGRect(x: 1300, y: 1100, width: 2200, height: 90))
        for i in 0..<3 {
            let r = CGRect(x: 1400 + CGFloat(i) * 640, y: 700, width: 520, height: 300)
            building(r, 130, (0.62, 0.66, 0.6), 2)
        }
        building(CGRect(x: 2000, y: 1260, width: 150, height: 150), 220, (0.8, 0.8, 0.82), 2)
        places.append(("HIGHLAND STRIP", CGPoint(x: 2300, y: 1050)))

        // Dockside: harbor warehouses and containers
        for i in 0..<3 {
            for j in 0..<2 {
                let r = CGRect(x: 1050 + CGFloat(i) * 330, y: 4100 + CGFloat(j) * 430, width: 280, height: 260)
                building(r, 110, (0.6, 0.5, 0.42), 3)
            }
        }
        n = 0
        tries = 0
        while n < 22 && tries < 300 {
            tries += 1
            let horiz = rng.f() > 0.4
            let w: CGFloat = horiz ? 84 : 32
            let h: CGFloat = horiz ? 32 : 84
            let r = CGRect(x: rng.r(1000, 2700), y: rng.r(3800, 5200), width: w, height: h)
            if isFree(r, 36) && !wallHit(r.insetBy(dx: -30, dy: -30)) {
                let cols: [BRCol] = [(0.7, 0.22, 0.18), (0.2, 0.36, 0.6), (0.85, 0.55, 0.15), (0.25, 0.5, 0.35)]
                container(r, cols[(n + 1) % 4])
                n += 1
            }
        }
        places.append(("DOCKSIDE", CGPoint(x: 1500, y: 4550)))

        // Farmland: scattered houses
        n = 0
        tries = 0
        while n < 32 && tries < 300 {
            tries += 1
            let r = CGRect(x: rng.r(900, 5600), y: rng.r(500, 5100), width: rng.r(150, 210), height: rng.r(130, 170))
            if isFree(r, 90) && !wallHit(r.insetBy(dx: -80, dy: -80)) {
                building(r, 80, towns[Int(rng.f() * 6) % 6], 4)
                n += 1
            }
        }
        places.append(("WEST FIELDS", CGPoint(x: 1300, y: 2300)))
        places.append(("EAST FARMS", CGPoint(x: 5000, y: 3900)))

        // trees
        tries = 0
        while trees.count < 320 && tries < 2000 {
            tries += 1
            let p = CGPoint(x: rng.r(500, 5800), y: rng.r(300, 5300))
            let r = CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)
            if isFree(r, 40) && !wallHit(r.insetBy(dx: -40, dy: -40)) {
                trees.append(p)
            }
        }

        buildGrid()
    }

    private func wallHit(_ r: CGRect) -> Bool {
        for w in walls where w.r.intersects(r) { return true }
        return false
    }

    private func buildGrid() {
        grid = [:]
        for (i, w) in walls.enumerated() {
            let x0 = max(0, Int(floor(w.r.minX / BRWorld.cell)))
            let x1 = max(0, Int(floor(w.r.maxX / BRWorld.cell)))
            let y0 = max(0, Int(floor(w.r.minY / BRWorld.cell)))
            let y1 = max(0, Int(floor(w.r.maxY / BRWorld.cell)))
            if x1 < x0 || y1 < y0 { continue }
            for cx in x0...x1 {
                for cy in y0...y1 {
                    grid[cx * 1000 + cy, default: []].append(i)
                }
            }
        }
        stamp = Array(repeating: 0, count: walls.count)
    }

    // MARK: queries

    func near(_ c: CGPoint, _ rad: CGFloat) -> [Int] {
        tick += 1
        var out: [Int] = []
        let x0 = max(0, Int(floor((c.x - rad) / BRWorld.cell)))
        let x1 = Int(floor((c.x + rad) / BRWorld.cell))
        let y0 = max(0, Int(floor((c.y - rad) / BRWorld.cell)))
        let y1 = Int(floor((c.y + rad) / BRWorld.cell))
        if x1 < x0 || y1 < y0 { return out }
        for cx in x0...x1 {
            for cy in y0...y1 {
                if let l = grid[cx * 1000 + cy] {
                    for i in l where stamp[i] != tick {
                        stamp[i] = tick
                        out.append(i)
                    }
                }
            }
        }
        return out
    }

    func along(_ a: CGPoint, _ b: CGPoint) -> [Int] {
        tick += 1
        var out: [Int] = []
        let d = hypot(b.x - a.x, b.y - a.y)
        let n = max(1, Int(d / 100))
        for k in 0...n {
            let f = CGFloat(k) / CGFloat(n)
            let px = a.x + (b.x - a.x) * f
            let py = a.y + (b.y - a.y) * f
            let cx = Int(floor(px / BRWorld.cell))
            let cy = Int(floor(py / BRWorld.cell))
            for ox in -1...1 {
                for oy in -1...1 {
                    let gx = cx + ox, gy = cy + oy
                    if gx < 0 || gy < 0 { continue }
                    if let l = grid[gx * 1000 + gy] {
                        for i in l where stamp[i] != tick {
                            stamp[i] = tick
                            out.append(i)
                        }
                    }
                }
            }
        }
        return out
    }

    func rayDist(_ o: CGPoint, _ dx: CGFloat, _ dy: CGFloat, _ maxD: CGFloat) -> CGFloat {
        let e = CGPoint(x: o.x + dx * maxD, y: o.y + dy * maxD)
        var best = maxD
        for i in along(o, e) {
            if let h = brRay(o, dx, dy, walls[i].r), h.0 < best { best = h.0 }
        }
        return best
    }

    func los(_ a: CGPoint, _ b: CGPoint) -> Bool {
        let d = hypot(b.x - a.x, b.y - a.y)
        if d < 1 { return true }
        return rayDist(a, (b.x - a.x) / d, (b.y - a.y) / d, d) >= d - 0.5
    }

    func push(_ p: CGPoint, _ r: CGFloat) -> CGPoint {
        var q = p
        for _ in 0..<2 {
            for i in near(q, r + 4) {
                let w = walls[i].r
                let cx = max(w.minX, min(q.x, w.maxX))
                let cy = max(w.minY, min(q.y, w.maxY))
                let dx = q.x - cx
                let dy = q.y - cy
                let d = hypot(dx, dy)
                if d < r {
                    if d < 0.001 {
                        let l = q.x - w.minX, rr = w.maxX - q.x, u = q.y - w.minY, b = w.maxY - q.y
                        let m = min(min(l, rr), min(u, b))
                        if m == l { q.x = w.minX - r } else if m == rr { q.x = w.maxX + r } else if m == u { q.y = w.minY - r } else { q.y = w.maxY + r }
                    } else {
                        q.x = cx + dx / d * r
                        q.y = cy + dy / d * r
                    }
                }
            }
        }
        return q
    }

    func insideBuilding(_ p: CGPoint, pad: CGFloat) -> Bool {
        for b in blds where b.r.insetBy(dx: -pad, dy: -pad).contains(p) { return true }
        for i in near(p, pad + 10) where walls[i].r.insetBy(dx: -pad, dy: -pad).contains(p) { return true }
        return false
    }
}
