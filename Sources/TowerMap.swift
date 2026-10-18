import SwiftUI

struct TwRoom {
    var r: CGRect
    var name: String
    var mat: Int
    var secure = false
    var hazard = false
}

struct TwProp {
    var r: CGRect
    var kind: Int      // 0 crate 1 desk 2 couch 3 plant 4 shelf 5 table 6 server 7 barrel 8 kiosk 9 pillar 10 bed 11 hospital bed 12 display case 13 machine 14 rack 15 bench 17 lockers
}

struct TwDoor {
    var r: CGRect
    var horiz: Bool
    var open: CGFloat = 0
    var hold: CGFloat = 0
    var kind = 0          // 0 auto, 1 shutter (timed), 2 keycard, 3 blast (power)
    var locked = false
    var phase: CGFloat = 0
    var closed: Bool { open < 0.85 }
}

struct TwNode: Hashable {
    var f: Int
    var i: Int
    var j: Int
}

/// One footprint (core, stairs, elevators) shared by every building; each MapDef lays out rooms differently.
final class TowerMap {
    static let W: CGFloat = 1600
    static let H: CGFloat = 1000
    static let wallH: CGFloat = 80
    static let T: CGFloat = 16
    static let stairW = CGRect(x: 30, y: 430, width: 100, height: 140)
    static let stairE = CGRect(x: 1470, y: 430, width: 100, height: 140)
    static let elevs = [CGRect(x: 700, y: 320, width: 90, height: 60), CGRect(x: 810, y: 630, width: 90, height: 60)]
    static let core = CGRect(x: 690, y: 390, width: 220, height: 240)
    static let switchPos = CGPoint(x: 560, y: 560)
    static let gx = 20, gy = 12
    static let step: CGFloat = 80

    let def: MapDef
    var nF: Int { def.floors.count }
    var walls: [[CGRect]] = []
    var props: [[TwProp]] = []
    var rooms: [[TwRoom]] = []
    var doors: [[TwDoor]] = []
    var solids: [[CGRect]] = []
    var navSolids: [[CGRect]] = []
    var loot: [[CGPoint]] = []
    var lootBoost: [[Int]] = []
    var spawns: [[CGPoint]] = []
    var hazards: [[CGRect]] = []
    var glass: [[CGRect]] = []
    var glassAlive: [[Bool]] = []
    var belts: [[(CGRect, CGPoint)]] = []
    var lanes: [[CGRect]] = []
    var trainRects: [[CGRect]] = []
    var ok: [[Bool]] = []
    var adj: [[[Int]]] = []
    var blockers: [[CGRect]] = []
    var rayBlockers: [[CGRect]] = []

    private var rng: BRRand

    init(def: MapDef) {
        self.def = def
        rng = BRRand(s: UInt64(777331 + def.id * 1013))
        for f in 0..<def.floors.count { generate(f) }
        trainRects = [[CGRect]](repeating: [], count: def.floors.count)
        for f in 0..<def.floors.count { buildNav(f) }
        refreshBlockers()
    }

    // MARK: generation

    private func addRoom(_ r: CGRect, side: Int, w: inout [CGRect], d: inout [TwDoor]) {
        let T = TowerMap.T
        let gap: CGFloat = 92
        func snap(_ v: CGFloat) -> CGFloat { 40 + 80 * CGFloat(Int((v - 40) / 80 + 0.5)) }
        let jitter = CGFloat(Int(rng.f() * 3) - 1) * 80
        var gxv = snap(r.midX + jitter)
        var gyv = snap(r.midY + jitter)
        gxv = max(r.minX + 70, min(r.maxX - 70, gxv))
        gyv = max(r.minY + 70, min(r.maxY - 70, gyv))
        if side == 0 {
            w.append(CGRect(x: r.minX, y: r.minY, width: gxv - gap / 2 - r.minX, height: T))
            w.append(CGRect(x: gxv + gap / 2, y: r.minY, width: r.maxX - gxv - gap / 2, height: T))
            d.append(TwDoor(r: CGRect(x: gxv - gap / 2, y: r.minY, width: gap, height: T), horiz: true))
        } else { w.append(CGRect(x: r.minX, y: r.minY, width: r.width, height: T)) }
        if side == 1 {
            w.append(CGRect(x: r.minX, y: r.maxY - T, width: gxv - gap / 2 - r.minX, height: T))
            w.append(CGRect(x: gxv + gap / 2, y: r.maxY - T, width: r.maxX - gxv - gap / 2, height: T))
            d.append(TwDoor(r: CGRect(x: gxv - gap / 2, y: r.maxY - T, width: gap, height: T), horiz: true))
        } else { w.append(CGRect(x: r.minX, y: r.maxY - T, width: r.width, height: T)) }
        if side == 2 {
            w.append(CGRect(x: r.minX, y: r.minY, width: T, height: gyv - gap / 2 - r.minY))
            w.append(CGRect(x: r.minX, y: gyv + gap / 2, width: T, height: r.maxY - gyv - gap / 2))
            d.append(TwDoor(r: CGRect(x: r.minX, y: gyv - gap / 2, width: T, height: gap), horiz: false))
        } else { w.append(CGRect(x: r.minX, y: r.minY, width: T, height: r.height)) }
        if side == 3 {
            w.append(CGRect(x: r.maxX - T, y: r.minY, width: T, height: gyv - gap / 2 - r.minY))
            w.append(CGRect(x: r.maxX - T, y: gyv + gap / 2, width: T, height: r.maxY - gyv - gap / 2))
            d.append(TwDoor(r: CGRect(x: r.maxX - T, y: gyv - gap / 2, width: T, height: gap), horiz: false))
        } else { w.append(CGRect(x: r.maxX - T, y: r.minY, width: T, height: r.height)) }
    }

    private func generate(_ f: Int) {
        let W = TowerMap.W, H = TowerMap.H, T = TowerMap.T
        let mirror = f % 2 == 1
        func mr(_ r: CGRect) -> CGRect { mirror ? CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height) : r }
        var w: [CGRect] = []
        var d: [TwDoor] = []
        var rm: [TwRoom] = []
        w.append(CGRect(x: 0, y: 0, width: W, height: T))
        w.append(CGRect(x: 0, y: H - T, width: W, height: T))
        w.append(CGRect(x: 0, y: 0, width: T, height: H))
        w.append(CGRect(x: W - T, y: 0, width: T, height: H))
        w.append(TowerMap.core)
        var specs: [(CGRect, Int, Bool)] = []
        for (x, wd) in def.top { specs.append((CGRect(x: x, y: 16, width: wd, height: 180), 1, false)) }
        for (x, wd) in def.bot { specs.append((CGRect(x: x, y: 804, width: wd, height: 180), 0, false)) }
        for m in def.mids { specs.append((m.0, m.1, true)) }
        var hz: [CGRect] = []
        for (i, sp) in specs.enumerated() {
            var side = sp.1
            if mirror && side < 2 { side = 1 - side }
            let rect = mr(sp.0)
            let nm = def.names[(i + f * 3) % def.names.count]
            var secure = false, hazard = false
            var dk = 0
            var lock = false
            switch def.special {
            case 1: if sp.2 { secure = true; dk = 2; lock = true }
            case 2: if i % 4 == 2 { hazard = true }
            case 3: if i % 4 == 1 { secure = true; dk = 3 }
            default: break
            }
            if def.mech == 1 && i % 3 == 0 { dk = 1 }
            let before = d.count
            addRoom(rect, side: side, w: &w, d: &d)
            for k in before..<d.count {
                d[k].kind = dk
                d[k].locked = lock
                d[k].phase = CGFloat(i) * 7.3
            }
            if hazard { hz.append(rect.insetBy(dx: T, dy: T)) }
            rm.append(TwRoom(r: rect, name: nm, mat: (i + f) % def.room.count, secure: secure, hazard: hazard))
        }
        // gates (shutters / security / blast doors across the hall)
        var gk = 0
        switch def.mech {
        case 1, 3: gk = 1
        case 5: gk = 2
        case 6: gk = 3
        default: break
        }
        for (gi, g) in def.gates.enumerated() {
            d.append(TwDoor(r: g, horiz: false, kind: gk, locked: gk == 2, phase: CGFloat(gi) * 13 + CGFloat(f) * 5))
        }
        for p in def.parts { w.append(mr(p)) }
        let gl = def.glass.map { mr($0) }
        let bl: [(CGRect, CGPoint)] = def.belts.map { (mr($0.0), mirror ? CGPoint(x: $0.1.x, y: -$0.1.y) : $0.1) }
        let ln = def.lanes.map { mr($0) }
        var keep: [CGRect] = gl.map { $0.insetBy(dx: -30, dy: -30) } + ln + bl.map { $0.0 } + def.gates.map { $0.insetBy(dx: -40, dy: -10) }
        keep.append(CGRect(x: TowerMap.switchPos.x - 40, y: TowerMap.switchPos.y - 40, width: 80, height: 80))

        var pr: [TwProp] = []
        if ln.isEmpty && bl.isEmpty {
            for p in [(600, 300), (1000, 300), (600, 680), (1000, 680), (1010, 470)] {
                pr.append(TwProp(r: CGRect(x: CGFloat(p.0), y: CGFloat(p.1), width: 36, height: 36), kind: 9))
            }
        }
        pr.append(TwProp(r: CGRect(x: 480, y: 480, width: 40, height: 40), kind: 8))
        let themes = def.props[f % def.props.count]
        let sizes: [Int: CGSize] = [0: CGSize(width: 34, height: 34), 1: CGSize(width: 72, height: 34), 2: CGSize(width: 84, height: 36), 3: CGSize(width: 24, height: 24), 4: CGSize(width: 90, height: 22), 5: CGSize(width: 60, height: 60), 6: CGSize(width: 30, height: 60), 7: CGSize(width: 24, height: 24), 10: CGSize(width: 80, height: 46), 11: CGSize(width: 76, height: 34), 12: CGSize(width: 56, height: 30), 13: CGSize(width: 60, height: 42), 14: CGSize(width: 72, height: 24), 15: CGSize(width: 62, height: 16), 17: CGSize(width: 70, height: 18)]
        var lootPts: [CGPoint] = []
        var boosts: [Int] = []
        for r in rm {
            let inner = r.r.insetBy(dx: T + 24, dy: T + 24)
            var doorC = CGPoint(x: r.r.midX, y: r.r.midY)
            for dd in d where r.r.insetBy(dx: -2, dy: -2).intersects(dd.r) { doorC = CGPoint(x: dd.r.midX, y: dd.r.midY) }
            let n = 3 + Int(rng.f() * 2)
            var placed: [CGRect] = []
            var tries = 0
            while placed.count < n && tries < 40 {
                tries += 1
                let kind = themes[Int(rng.f() * CGFloat(themes.count)) % themes.count]
                guard let sz = sizes[kind] else { continue }
                let horiz = rng.f() > 0.5
                let ww = horiz ? sz.width : sz.height, hh = horiz ? sz.height : sz.width
                if inner.width < ww + 4 || inner.height < hh + 4 { continue }
                let rc = CGRect(x: rng.r(inner.minX, inner.maxX - ww), y: rng.r(inner.minY, inner.maxY - hh), width: ww, height: hh)
                if hypot(rc.midX - doorC.x, rc.midY - doorC.y) < 105 { continue }
                if placed.contains(where: { $0.insetBy(dx: -26, dy: -26).intersects(rc) }) { continue }
                placed.append(rc)
                pr.append(TwProp(r: rc, kind: kind))
            }
            var got = 0
            tries = 0
            while got < 3 && tries < 60 {
                tries += 1
                let p = CGPoint(x: rng.r(inner.minX, inner.maxX), y: rng.r(inner.minY, inner.maxY))
                if placed.contains(where: { $0.insetBy(dx: -20, dy: -20).contains(p) }) { continue }
                lootPts.append(p)
                boosts.append(r.secure ? 2 : (r.hazard ? 1 : 0))
                got += 1
            }
            if r.secure || r.hazard {
                for _ in 0..<2 {
                    let p = CGPoint(x: rng.r(inner.minX, inner.maxX), y: rng.r(inner.minY, inner.maxY))
                    lootPts.append(p)
                    boosts.append(r.secure ? 2 : 1)
                }
            }
        }
        var spawnPts = lootPts
        var hall = 0
        var tries = 0
        let solidAll = w + pr.map { $0.r }
        while hall < 12 && tries < 400 {
            tries += 1
            let p = CGPoint(x: rng.r(30, W - 30), y: rng.r(30, H - 30))
            if solidAll.contains(where: { $0.insetBy(dx: -22, dy: -22).contains(p) }) { continue }
            if rm.contains(where: { $0.r.insetBy(dx: -6, dy: -6).contains(p) }) { continue }
            if TowerMap.stairW.contains(p) || TowerMap.stairE.contains(p) { continue }
            if TowerMap.elevs.contains(where: { $0.insetBy(dx: -10, dy: -10).contains(p) }) { continue }
            if keep.contains(where: { $0.contains(p) }) { continue }
            lootPts.append(p)
            boosts.append(0)
            hall += 1
        }
        spawnPts = spawnPts.filter { sp in !keep.contains(where: { $0.contains(sp) }) }
        spawnPts.shuffle()
        walls.append(w)
        props.append(pr)
        rooms.append(rm)
        doors.append(d)
        solids.append(w + pr.map { $0.r })
        navSolids.append(w + pr.map { $0.r } + gl)
        loot.append(lootPts)
        lootBoost.append(boosts)
        spawns.append(spawnPts)
        hazards.append(hz)
        glass.append(gl)
        glassAlive.append([Bool](repeating: true, count: gl.count))
        belts.append(bl)
        lanes.append(ln)
    }

    // MARK: collision

    func refreshBlockers() {
        blockers = []
        rayBlockers = []
        for f in 0..<nF {
            var b = solids[f]
            for d in doors[f] where d.closed { b.append(d.r) }
            var rb = b
            for (i, g) in glass[f].enumerated() where glassAlive[f][i] { b.append(g) }
            if f < trainRects.count {
                b += trainRects[f]
                rb += trainRects[f]
            }
            blockers.append(b)
            rayBlockers.append(rb)
        }
    }

    func push(_ p: CGPoint, _ r: CGFloat, _ f: Int) -> CGPoint {
        var q = p
        for _ in 0..<2 {
            for w in blockers[f] {
                if q.x < w.minX - r || q.x > w.maxX + r || q.y < w.minY - r || q.y > w.maxY + r { continue }
                let cx = max(w.minX, min(q.x, w.maxX))
                let cy = max(w.minY, min(q.y, w.maxY))
                let dx = q.x - cx, dy = q.y - cy
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
        q.x = max(24, min(TowerMap.W - 24, q.x))
        q.y = max(24, min(TowerMap.H - 24, q.y))
        return q
    }

    func rayDist(_ f: Int, _ o: CGPoint, _ dx: CGFloat, _ dy: CGFloat, _ maxD: CGFloat) -> CGFloat {
        var best = maxD
        for w in rayBlockers[f] {
            if let h = brRay(o, dx, dy, w), h.0 < best { best = h.0 }
        }
        return best
    }

    func los(_ f: Int, _ a: CGPoint, _ b: CGPoint) -> Bool {
        let d = hypot(b.x - a.x, b.y - a.y)
        if d < 1 { return true }
        return rayDist(f, a, (b.x - a.x) / d, (b.y - a.y) / d, d) >= d - 0.5
    }

    // MARK: navigation (grid per floor, edges that pass through doors)

    private func nodePos(_ i: Int, _ j: Int) -> CGPoint {
        CGPoint(x: 40 + TowerMap.step * CGFloat(i), y: 40 + TowerMap.step * CGFloat(j))
    }

    func pos(_ n: TwNode) -> CGPoint { nodePos(n.i, n.j) }

    private func clear(_ f: Int, _ p: CGPoint, _ r: CGFloat) -> Bool {
        for w in navSolids[f] where w.insetBy(dx: -r, dy: -r).contains(p) { return false }
        return true
    }

    private func buildNav(_ f: Int) {
        let gx = TowerMap.gx, gy = TowerMap.gy
        var o = [Bool](repeating: false, count: gx * gy)
        for j in 0..<gy { for i in 0..<gx { o[j * gx + i] = clear(f, nodePos(i, j), 14) } }
        var ad = [[Int]](repeating: [], count: gx * gy)
        for j in 0..<gy {
            for i in 0..<gx where o[j * gx + i] {
                for dj in -1...1 {
                    for di in -1...1 where !(di == 0 && dj == 0) {
                        let ni = i + di, nj = j + dj
                        if ni < 0 || nj < 0 || ni >= gx || nj >= gy || !o[nj * gx + ni] { continue }
                        let a = nodePos(i, j), b = nodePos(ni, nj)
                        var good = true
                        let n = 6
                        for s in 1..<n {
                            let t = CGFloat(s) / CGFloat(n)
                            if !clear(f, CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), 13) { good = false; break }
                        }
                        if good { ad[j * gx + i].append(nj * gx + ni) }
                    }
                }
            }
        }
        ok.append(o)
        adj.append(ad)
    }

    func nearestNode(_ f: Int, _ p: CGPoint) -> TwNode {
        let gx = TowerMap.gx, gy = TowerMap.gy
        let ci = max(0, min(gx - 1, Int((p.x - 40) / TowerMap.step + 0.5)))
        let cj = max(0, min(gy - 1, Int((p.y - 40) / TowerMap.step + 0.5)))
        var best = TwNode(f: f, i: ci, j: cj)
        var bd: CGFloat = 1e9
        for dj in -2...2 {
            for di in -2...2 {
                let i = ci + di, j = cj + dj
                if i < 0 || j < 0 || i >= gx || j >= gy || !ok[f][j * gx + i] { continue }
                let q = nodePos(i, j)
                let d = hypot(q.x - p.x, q.y - p.y)
                if d < bd { bd = d; best = TwNode(f: f, i: i, j: j) }
            }
        }
        return best
    }

    lazy var stairWNode: TwNode = nearestNode(0, CGPoint(x: TowerMap.stairW.midX, y: TowerMap.stairW.midY))
    lazy var stairENode: TwNode = nearestNode(0, CGPoint(x: TowerMap.stairE.midX, y: TowerMap.stairE.midY))
    lazy var elevNodes: [TwNode] = TowerMap.elevs.map { nearestNode(0, CGPoint(x: $0.midX, y: $0.midY)) }

    private func floorPath(_ f: Int, _ s: TwNode, _ t: TwNode) -> [TwNode]? {
        let gx = TowerMap.gx, gy = TowerMap.gy
        let n = gx * gy
        var g = [CGFloat](repeating: 1e9, count: n)
        var prev = [Int](repeating: -1, count: n)
        var heap: [(CGFloat, Int)] = []
        func hpush(_ c: CGFloat, _ i: Int) {
            heap.append((c, i))
            var k = heap.count - 1
            while k > 0 {
                let p = (k - 1) / 2
                if heap[p].0 <= heap[k].0 { break }
                heap.swapAt(p, k)
                k = p
            }
        }
        func hpop() -> Int {
            let top = heap[0]
            let last = heap.removeLast()
            if !heap.isEmpty {
                heap[0] = last
                var k = 0
                while true {
                    let l = 2 * k + 1, r = l + 1
                    var m = k
                    if l < heap.count && heap[l].0 < heap[m].0 { m = l }
                    if r < heap.count && heap[r].0 < heap[m].0 { m = r }
                    if m == k { break }
                    heap.swapAt(k, m)
                    k = m
                }
            }
            return top.1
        }
        let si = s.j * gx + s.i, ti = t.j * gx + t.i
        let tp = nodePos(t.i, t.j)
        g[si] = 0
        hpush(0, si)
        var guardN = 0
        while !heap.isEmpty && guardN < 3000 {
            guardN += 1
            let cur = hpop()
            if cur == ti { break }
            let cp = nodePos(cur % gx, cur / gx)
            for q in adj[f][cur] {
                let qp = nodePos(q % gx, q / gx)
                let ng = g[cur] + hypot(qp.x - cp.x, qp.y - cp.y)
                if ng < g[q] {
                    g[q] = ng
                    prev[q] = cur
                    hpush(ng + hypot(qp.x - tp.x, qp.y - tp.y), q)
                }
            }
        }
        if si != ti && prev[ti] < 0 { return nil }
        var out: [TwNode] = []
        var c = ti
        while c != -1 {
            out.append(TwNode(f: f, i: c % gx, j: c / gx))
            if c == si { break }
            c = prev[c]
        }
        return out.reversed()
    }

    /// Per-floor A* joined through the cheapest stair or elevator.
    func path(from a: TwNode, to b: TwNode) -> [TwNode] {
        if a.f == b.f { return floorPath(a.f, a, b) ?? [] }
        let pa = pos(a), pb = pos(b)
        var links = elevNodes
        if b.f == a.f + 1 { links.append(stairWNode) }
        if b.f == a.f - 1 { links.append(stairENode) }
        links.sort { l1, l2 in
            let p1 = pos(l1), p2 = pos(l2)
            return hypot(pa.x - p1.x, pa.y - p1.y) + hypot(pb.x - p1.x, pb.y - p1.y) < hypot(pa.x - p2.x, pa.y - p2.y) + hypot(pb.x - p2.x, pb.y - p2.y)
        }
        for l in links {
            let l1 = TwNode(f: a.f, i: l.i, j: l.j)
            let l2 = TwNode(f: b.f, i: l.i, j: l.j)
            if let p1 = floorPath(a.f, a, l1), let p2 = floorPath(b.f, l2, b) { return p1 + p2 }
        }
        return []
    }

    func randomLoot(_ f: Int) -> CGPoint { loot[f].randomElement() ?? CGPoint(x: 800, y: 500) }
}
