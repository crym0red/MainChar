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
    let kick: CGFloat
    let zoom: CGFloat
}

enum BRGuns {
    static let all: [BRGunDef] = [
        BRGunDef(id: "pistol", name: "M9 SIDEARM", dmg: 22, rate: 0.28, mag: 15, range: 650, spread: 0.025, reload: 1.2, pellets: 1, kick: 0.010, zoom: 1.12),
        BRGunDef(id: "smg", name: "VX-9 SMG", dmg: 14, rate: 0.075, mag: 30, range: 520, spread: 0.05, reload: 1.6, pellets: 1, kick: 0.006, zoom: 0.95),
        BRGunDef(id: "rifle", name: "AR-27 RIFLE", dmg: 24, rate: 0.12, mag: 30, range: 1100, spread: 0.02, reload: 2.0, pellets: 1, kick: 0.012, zoom: 0.5),
        BRGunDef(id: "shotgun", name: "BREACHER", dmg: 11, rate: 0.9, mag: 6, range: 320, spread: 0.09, reload: 2.4, pellets: 8, kick: 0.03, zoom: 1.1)
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

    static let gulagRect = CGRect(x: 5280, y: 4560, width: 520, height: 420)
    static let gulagA = CGPoint(x: 5335, y: 4770)
    static let gulagB = CGPoint(x: 5745, y: 4770)
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

    static let lakes: [(CGPoint, CGFloat, CGFloat)] = [(CGPoint(x: 1500, y: 1350), 400, 300), (CGPoint(x: 4350, y: 3850), 150, 110)]

    var roads: [[CGPoint]] = []
    var roadSegs: [(CGPoint, CGPoint)] = []
    var patches: [(CGRect, BRCol)] = []
    static let texN = 600
    static let texS: CGFloat = 10
    var tex: [UInt8] = []
    var mapImage: CGImage? = nil

    static func coastDist(_ p: CGPoint) -> CGFloat {
        let coastX: CGFloat = 420 + 260 * sin(p.y / 640) + 140 * sin(p.y / 230)
        let coastY: CGFloat = 5560 + 200 * sin(p.x / 540)
        return min(p.x - coastX, coastY - p.y)
    }

    static func lakeDist(_ p: CGPoint) -> CGFloat {
        var best: CGFloat = 99999
        for (c, rx, ry) in lakes {
            let nx = (p.x - c.x) / rx, ny = (p.y - c.y) / ry
            let d = (sqrt(nx * nx + ny * ny) - 1) * min(rx, ry)
            best = min(best, d)
        }
        return best
    }

    static func water(_ p: CGPoint) -> Bool {
        if coastDist(p) < 0 { return true }
        if p.x > W - 110 || p.y < 110 { return true }
        return lakeDist(p) < 0
    }

    func roadDist(_ p: CGPoint) -> CGFloat {
        var best: CGFloat = 99999
        for (a, b) in roadSegs {
            let dx = b.x - a.x, dy = b.y - a.y
            let l2 = dx * dx + dy * dy
            var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / max(1, l2)
            t = max(0, min(1, t))
            let d = hypot(p.x - (a.x + dx * t), p.y - (a.y + dy * t))
            if d < best { best = d }
        }
        return best
    }

    func ground(_ p: CGPoint) -> BRCol {
        if BRWorld.water(p) {
            let r = 0.04 * sin(p.x / 30 + p.y / 45)
            return (0.17 + r, 0.4 + r, 0.6 + r)
        }
        if BRWorld.coastDist(p) < 70 || BRWorld.lakeDist(p) < 50 { return (0.8, 0.74, 0.55) }
        for (r, c) in patches where r.contains(p) { return c }
        let rd = roadDist(p)
        if rd < 30 {
            let dash = rd < 2.5 && fmod(abs(p.x + p.y), 80) < 40
            return dash ? (0.8, 0.75, 0.3) : (0.3, 0.31, 0.33)
        }
        if rd < 36 { return (0.62, 0.6, 0.55) }
        let n1 = sin(p.x / 90) * cos(p.y / 110) + 0.5 * sin((p.x + p.y) / 47)
        let n2 = sin(p.x / 230 + 1) * sin(p.y / 190 + 2)
        if n2 > 0.72 { return (0.5, 0.42, 0.3) }
        let k = n1 * 0.035
        return (0.34 + k, 0.5 + k, 0.27 + k)
    }

    // MARK: generation

    private let towns: [BRCol] = [(0.78, 0.72, 0.6), (0.85, 0.82, 0.74), (0.62, 0.38, 0.3), (0.7, 0.6, 0.5), (0.55, 0.58, 0.62), (0.8, 0.66, 0.46)]
    private let greys: [BRCol] = [(0.6, 0.62, 0.66), (0.72, 0.72, 0.7), (0.5, 0.54, 0.6), (0.78, 0.76, 0.7), (0.58, 0.5, 0.46)]

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
        for p in pts where BRWorld.water(p) || BRWorld.lakeDist(p) < 30 { return false }
        let rp = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.midX, y: r.midY)]
        for p in rp where roadDist(p) < 52 { return false }
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
        spots.append(CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * rng.r(0.3, 0.7)))
        spots.append(CGPoint(x: r.minX + r.width * 0.74, y: r.minY + r.height * rng.r(0.3, 0.7)))
    }

    private func block(_ r: CGRect, _ h: CGFloat, _ c: BRCol, _ kind: Int = 9) {
        addWall(r, h, c)
        blds.append(BRBuilding(r: r, kind: kind))
    }

    private func container(_ r: CGRect, _ c: BRCol) {
        addWall(r, 44, c)
        spots.append(CGPoint(x: r.midX, y: r.maxY + 40))
    }

    private func road(_ pts: [CGPoint]) {
        roads.append(pts)
        if pts.count > 1 {
            for i in 0..<(pts.count - 1) { roadSegs.append((pts[i], pts[i + 1])) }
        }
    }

    private func scatterContainers(_ area: CGRect, _ count: Int, _ off: Int) {
        var n = 0
        var tries = 0
        let cols: [BRCol] = [(0.7, 0.22, 0.18), (0.2, 0.36, 0.6), (0.85, 0.55, 0.15), (0.25, 0.5, 0.35)]
        while n < count && tries < 400 {
            tries += 1
            let horiz = rng.f() > 0.5
            let w: CGFloat = horiz ? 84 : 32
            let h: CGFloat = horiz ? 32 : 84
            let r = CGRect(x: rng.r(area.minX, area.maxX), y: rng.r(area.minY, area.maxY), width: w, height: h)
            if isFree(r, 34) && !wallHit(r.insetBy(dx: -30, dy: -30)) {
                container(r, cols[(n + off) % 4])
                n += 1
            }
        }
    }

    private func houses(_ area: CGRect, _ count: Int, _ kind: Int) {
        var n = 0
        var tries = 0
        while n < count && tries < 400 {
            tries += 1
            let r = CGRect(x: rng.r(area.minX, area.maxX), y: rng.r(area.minY, area.maxY), width: rng.r(150, 220), height: rng.r(130, 180))
            if isFree(r, 70) && !wallHit(r.insetBy(dx: -60, dy: -60)) {
                building(r, rng.r(75, 95), towns[Int(rng.f() * 6) % 6], kind)
                n += 1
            }
        }
    }

    private func generate() {
        // roads first so everything avoids them
        road([CGPoint(x: 3000, y: 2050), CGPoint(x: 3000, y: 1300), CGPoint(x: 5650, y: 1300)])
        road([CGPoint(x: 2200, y: 2900), CGPoint(x: 1000, y: 2900)])
        road([CGPoint(x: 3800, y: 2900), CGPoint(x: 5000, y: 2900)])
        road([CGPoint(x: 3000, y: 3750), CGPoint(x: 3000, y: 4000), CGPoint(x: 3300, y: 4000)])
        road([CGPoint(x: 2200, y: 3300), CGPoint(x: 1700, y: 3300), CGPoint(x: 1500, y: 4000), CGPoint(x: 1500, y: 5100)])
        road([CGPoint(x: 5000, y: 2900), CGPoint(x: 5000, y: 4300), CGPoint(x: 4700, y: 4500)])
        road([CGPoint(x: 3000, y: 1300), CGPoint(x: 2000, y: 1300), CGPoint(x: 2000, y: 700)])
        road([CGPoint(x: 4600, y: 1300), CGPoint(x: 4600, y: 2900)])
        road([CGPoint(x: 3300, y: 4700), CGPoint(x: 4400, y: 4700), CGPoint(x: 4700, y: 4500)])
        road([CGPoint(x: 1000, y: 2300), CGPoint(x: 2200, y: 2300), CGPoint(x: 2200, y: 2900)])

        patches.append((CGRect(x: 2150, y: 2000, width: 1700, height: 1750), (0.5, 0.5, 0.48)))   // downtown paving
        patches.append((CGRect(x: 4300, y: 4000, width: 900, height: 780), (0.56, 0.46, 0.33)))    // quarry
        patches.append((CGRect(x: 4730, y: 2640, width: 560, height: 520), (0.58, 0.54, 0.44)))    // prison yard
        patches.append((CGRect(x: 3000, y: 4260, width: 600, height: 440), (0.4, 0.55, 0.3)))      // arena turf
        patches.append((CGRect(x: 3500, y: 1030, width: 2200, height: 140), (0.28, 0.28, 0.3)))    // runway
        patches.append((CGRect(x: 3500, y: 700, width: 2200, height: 330), (0.5, 0.5, 0.5)))       // apron
        runways.append(CGRect(x: 3500, y: 1030, width: 2200, height: 140))

        // Meridian: dense downtown
        var bx: CGFloat = 2200
        while bx < 3800 {
            var by: CGFloat = 2080
            while by < 3700 {
                if rng.f() > 0.1 {
                    let w = rng.r(230, 280), h = rng.r(210, 260)
                    let r = CGRect(x: bx + rng.r(0, 30), y: by + rng.r(0, 30), width: w, height: h)
                    if isFree(r, 10) {
                        let tall = rng.f() > 0.55
                        building(r, tall ? rng.r(170, 260) : rng.r(100, 140), greys[Int(rng.f() * 5) % 5], 0)
                        if tall { spots.append(CGPoint(x: r.midX, y: r.midY)) }
                    }
                }
                by += 330
            }
            bx += 330
        }
        places.append(("MERIDIAN", CGPoint(x: 3000, y: 2900)))

        // Sunken Arena: stadium
        let ar = CGRect(x: 3000, y: 4260, width: 600, height: 440)
        hw(ar.minX, ar.maxX, ar.minY, ar.midX, 130, (0.7, 0.7, 0.72))
        hw(ar.minX, ar.maxX, ar.maxY, ar.midX + 60, 130, (0.7, 0.7, 0.72))
        vw(ar.minY, ar.maxY, ar.minX, ar.midY, 130, (0.7, 0.7, 0.72))
        vw(ar.minY, ar.maxY, ar.maxX, ar.midY - 40, 130, (0.7, 0.7, 0.72))
        let inner = ar.insetBy(dx: 120, dy: 100)
        hw(inner.minX, inner.maxX, inner.minY, inner.midX - 30, 46, (0.55, 0.6, 0.55))
        hw(inner.minX, inner.maxX, inner.maxY, inner.midX + 30, 46, (0.55, 0.6, 0.55))
        vw(inner.minY, inner.maxY, inner.minX, inner.midY, 46, (0.55, 0.6, 0.55))
        vw(inner.minY, inner.maxY, inner.maxX, inner.midY, 46, (0.55, 0.6, 0.55))
        blds.append(BRBuilding(r: ar, kind: 6))
        for i in 0..<5 { spots.append(CGPoint(x: ar.minX + 60 + CGFloat(i) * 120, y: ar.minY + 50)) }
        places.append(("SUNKEN ARENA", CGPoint(x: 3300, y: 4480)))

        // Redhill Airfield
        building(CGRect(x: 3700, y: 480, width: 640, height: 220), 120, (0.8, 0.8, 0.82), 2)
        for i in 0..<3 {
            building(CGRect(x: 4450 + CGFloat(i) * 380, y: 440, width: 330, height: 240), 130, (0.62, 0.66, 0.6), 2)
        }
        block(CGRect(x: 3600, y: 1220, width: 70, height: 70), 250, (0.82, 0.82, 0.84), 2)
        for i in 0..<4 { spots.append(CGPoint(x: 3800 + CGFloat(i) * 450, y: 1230)) }
        places.append(("REDHILL AIRFIELD", CGPoint(x: 4600, y: 900)))

        // Northgate Dam
        vw(900, 1350, 1960, 1130, 100, (0.66, 0.66, 0.64))
        vw(1350, 1800, 1960, 1560, 100, (0.66, 0.66, 0.64))
        building(CGRect(x: 2060, y: 1450, width: 230, height: 160), 100, (0.7, 0.7, 0.66), 3)
        building(CGRect(x: 2060, y: 880, width: 220, height: 150), 100, (0.7, 0.7, 0.66), 3)
        places.append(("NORTHGATE DAM", CGPoint(x: 1960, y: 1350)))

        // Ironwall Prison
        let pr = CGRect(x: 4750, y: 2660, width: 540, height: 500)
        hw(pr.minX, pr.maxX, pr.minY, nil, 120, (0.58, 0.58, 0.56))
        hw(pr.minX, pr.maxX, pr.maxY, pr.midX, 120, (0.58, 0.58, 0.56))
        vw(pr.minY, pr.maxY, pr.minX, nil, 120, (0.58, 0.58, 0.56))
        vw(pr.minY, pr.maxY, pr.maxX, pr.midY, 120, (0.58, 0.58, 0.56))
        blds.append(BRBuilding(r: pr, kind: 7))
        for (tx, ty) in [(pr.minX - 30, pr.minY - 30), (pr.maxX - 20, pr.minY - 30), (pr.minX - 30, pr.maxY - 20), (pr.maxX - 20, pr.maxY - 20)] {
            block(CGRect(x: tx, y: ty, width: 54, height: 54), 220, (0.5, 0.5, 0.5), 7)
        }
        building(CGRect(x: pr.minX + 50, y: pr.minY + 50, width: 200, height: 110), 95, (0.66, 0.64, 0.6), 7)
        building(CGRect(x: pr.minX + 290, y: pr.minY + 50, width: 200, height: 110), 95, (0.66, 0.64, 0.6), 7)
        building(CGRect(x: pr.minX + 120, y: pr.minY + 260, width: 300, height: 120), 95, (0.66, 0.64, 0.6), 7)
        places.append(("IRONWALL PRISON", CGPoint(x: 5020, y: 2900)))

        // Gravel Pit quarry
        building(CGRect(x: 4380, y: 4080, width: 230, height: 150), 90, (0.6, 0.5, 0.4), 4)
        building(CGRect(x: 4900, y: 4500, width: 230, height: 150), 90, (0.6, 0.5, 0.4), 4)
        scatterContainers(CGRect(x: 4320, y: 4280, width: 800, height: 420), 16, 2)
        places.append(("GRAVEL PIT", CGPoint(x: 4750, y: 4400)))

        // Dockline harbor
        for i in 0..<3 {
            for j in 0..<2 {
                building(CGRect(x: 1050 + CGFloat(i) * 330, y: 4150 + CGFloat(j) * 430, width: 280, height: 260), 110, (0.6, 0.5, 0.42), 5)
            }
        }
        scatterContainers(CGRect(x: 1000, y: 3800, width: 1700, height: 1350), 26, 1)
        places.append(("DOCKLINE", CGPoint(x: 1500, y: 4550)))

        // Northfield medical campus
        building(CGRect(x: 2500, y: 1000, width: 640, height: 240), 120, (0.85, 0.85, 0.86), 8)
        building(CGRect(x: 2520, y: 1320, width: 240, height: 250), 110, (0.82, 0.82, 0.84), 8)
        building(CGRect(x: 2880, y: 1380, width: 250, height: 230), 110, (0.82, 0.82, 0.84), 8)
        places.append(("NORTHFIELD", CGPoint(x: 2800, y: 1200)))

        // Greenhollow farms + hamlets
        houses(CGRect(x: 900, y: 2000, width: 1250, height: 1500), 16, 4)
        houses(CGRect(x: 3900, y: 3700, width: 600, height: 900), 8, 4)
        houses(CGRect(x: 5200, y: 3300, width: 500, height: 1500), 7, 4)
        houses(CGRect(x: 2300, y: 500, width: 1200, height: 400), 5, 4)
        houses(CGRect(x: 800, y: 600, width: 1100, height: 900), 4, 4)
        places.append(("GREENHOLLOW", CGPoint(x: 1400, y: 2700)))

        // pine and oak stands
        var centers: [CGPoint] = []
        for _ in 0..<14 { centers.append(CGPoint(x: rng.r(900, 5600), y: rng.r(500, 5200))) }
        var tries = 0
        while trees.count < 520 && tries < 6000 {
            tries += 1
            var p = CGPoint(x: rng.r(500, 5800), y: rng.r(300, 5300))
            if rng.f() < 0.75, let c = centers.randomElement() {
                p = CGPoint(x: c.x + rng.r(-420, 420), y: c.y + rng.r(-420, 420))
            }
            if BRWorld.water(p) || BRWorld.coastDist(p) < 90 { continue }
            if roadDist(p) < 55 { continue }
            var skip = false
            for (r, _) in patches where r.contains(p) { skip = true }
            if skip { continue }
            let r = CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)
            if isFree(r, 36) && !wallHit(r.insetBy(dx: -36, dy: -36)) {
                trees.append(p)
            }
        }

        // gulag arena (closed box with cover)
        let gr = BRWorld.gulagRect
        patches.append((gr, (0.38, 0.38, 0.42)))
        hw(gr.minX, gr.maxX, gr.minY, nil, 130, (0.42, 0.42, 0.48))
        hw(gr.minX, gr.maxX, gr.maxY, nil, 130, (0.42, 0.42, 0.48))
        vw(gr.minY, gr.maxY, gr.minX, nil, 130, (0.42, 0.42, 0.48))
        vw(gr.minY, gr.maxY, gr.maxX, nil, 130, (0.42, 0.42, 0.48))
        for c in [CGRect(x: 5450, y: 4640, width: 34, height: 100), CGRect(x: 5576, y: 4800, width: 34, height: 100), CGRect(x: 5500, y: 4745, width: 70, height: 30), CGRect(x: 5400, y: 4880, width: 60, height: 34), CGRect(x: 5620, y: 4650, width: 60, height: 34)] {
            addWall(c, 46, (0.55, 0.45, 0.3))
        }
        buildGrid()
        bakeGround()
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

    // MARK: baked ground texture (also used by the minimap)

    private func paint(_ r: CGRect, _ c: BRCol) {
        let n = BRWorld.texN
        let sc = BRWorld.texS
        let i0 = max(0, Int(floor(r.minX / sc))), i1 = min(n - 1, Int(floor(r.maxX / sc)))
        let j0 = max(0, Int(floor(r.minY / sc))), j1 = min(n - 1, Int(floor(r.maxY / sc)))
        if i1 < i0 || j1 < j0 { return }
        let rr = UInt8(max(0, min(255, c.0 * 255))), gg = UInt8(max(0, min(255, c.1 * 255))), bb = UInt8(max(0, min(255, c.2 * 255)))
        for j in j0...j1 {
            for i in i0...i1 {
                let o = (j * n + i) * 4
                tex[o] = rr
                tex[o + 1] = gg
                tex[o + 2] = bb
                tex[o + 3] = 255
            }
        }
    }

    private func bakeGround() {
        let n = BRWorld.texN
        let sc = BRWorld.texS
        tex = [UInt8](repeating: 255, count: n * n * 4)
        for j in 0..<n {
            for i in 0..<n {
                let p = CGPoint(x: (CGFloat(i) + 0.5) * sc, y: (CGFloat(j) + 0.5) * sc)
                let c = ground(p)
                let hsh = sin(CGFloat(i) * 12.9898 + CGFloat(j) * 78.233) * 43758.5453
                let nz = (hsh - floor(hsh) - 0.5) * 0.045
                let o = (j * n + i) * 4
                tex[o] = UInt8(max(0, min(255, (c.0 + nz) * 255)))
                tex[o + 1] = UInt8(max(0, min(255, (c.1 + nz) * 255)))
                tex[o + 2] = UInt8(max(0, min(255, (c.2 + nz) * 255)))
            }
        }
        for b in blds { paint(b.r, (0.5, 0.48, 0.44)) }
        for w in walls {
            if w.h < 60 { paint(w.r, w.c) } else { paint(w.r, (0.13, 0.13, 0.15)) }
        }
        tex.withUnsafeMutableBytes { raw in
            if let cg = CGContext(data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                mapImage = cg.makeImage()
            }
        }
    }

    // returns 0..255 rgb at world position
    func sample(_ x: CGFloat, _ y: CGFloat) -> (Int, Int, Int) {
        let n = BRWorld.texN
        let i = Int(x / BRWorld.texS), j = Int(y / BRWorld.texS)
        if i < 0 || j < 0 || i >= n || j >= n { return (44, 100, 150) }
        let o = (j * n + i) * 4
        return (Int(tex[o]), Int(tex[o + 1]), Int(tex[o + 2]))
    }
}
