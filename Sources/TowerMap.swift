import SwiftUI

struct TwRoom {
    var r: CGRect
    var name: String
    var mat: Int
}

struct TwProp {
    var r: CGRect
    var kind: Int      // 0 crate 1 desk 2 couch 3 plant 4 shelf 5 table 6 server 7 barrel 8 kiosk 9 pillar
}

struct TwDoor {
    var r: CGRect
    var horiz: Bool
    var open: CGFloat = 0
    var hold: CGFloat = 0
    var closed: Bool { open < 0.85 }
}

struct TwNode: Hashable {
    var f: Int
    var i: Int
    var j: Int
}

/// The Spire: a six floor skyscraper. Every floor shares one footprint (core, stairs, elevators)
/// and differs in rooms' contents, materials and loot.
final class TowerMap {
    static let shared = TowerMap()
    static let nF = 6
    static let W: CGFloat = 1600
    static let H: CGFloat = 1000
    static let wallH: CGFloat = 80
    static let T: CGFloat = 16
    static let names = ["LOBBY", "OFFICES", "LABS", "LOUNGE", "EXECUTIVE", "PENTHOUSE"]
    static let stairW = CGRect(x: 30, y: 430, width: 100, height: 140)
    static let stairE = CGRect(x: 1470, y: 430, width: 100, height: 140)
    static let elevs = [CGRect(x: 700, y: 320, width: 90, height: 60), CGRect(x: 810, y: 630, width: 90, height: 60)]
    static let elevArrive = [CGPoint(x: 745, y: 290), CGPoint(x: 855, y: 722)]
    static let core = CGRect(x: 690, y: 390, width: 220, height: 240)
    static let station = CGPoint(x: 500, y: 500)
    static let gx = 20, gy = 12          // nav grid
    static let step: CGFloat = 80

    var walls: [[CGRect]] = []
    var props: [[TwProp]] = []
    var rooms: [[TwRoom]] = []
    var doors: [[TwDoor]] = []
    var solids: [[CGRect]] = []          // walls + props (not doors)
    var loot: [[CGPoint]] = []
    var spawns: [[CGPoint]] = []
    var ok: [[Bool]] = []                // nav node clear
    var adj: [[[Int]]] = []              // nav edges per floor, node id = j * gx + i
    var blockers: [[CGRect]] = []        // solids + closed doors, refreshed each frame

    private var rng = BRRand(s: 777331)

    init() {
        for f in 0..<TowerMap.nF { generate(f) }
        for f in 0..<TowerMap.nF { buildNav(f) }
        refreshBlockers()
    }

    // MARK: generation

    private func addRoom(_ r: CGRect, side: Int, name: String, mat: Int, f: Int, w: inout [CGRect], d: inout [TwDoor]) {
        let T = TowerMap.T
        let gap: CGFloat = 92
        func snap(_ v: CGFloat) -> CGFloat { 40 + 80 * CGFloat(Int((v - 40) / 80 + 0.5)) }
        let jitter = CGFloat(Int(rng.f() * 3) - 1) * 80
        var gxv = snap(r.midX + jitter)
        var gyv = snap(r.midY + jitter)
        gxv = max(r.minX + 70, min(r.maxX - 70, gxv))
        gyv = max(r.minY + 70, min(r.maxY - 70, gyv))
        // top
        if side == 0 {
            w.append(CGRect(x: r.minX, y: r.minY, width: gxv - gap / 2 - r.minX, height: T))
            w.append(CGRect(x: gxv + gap / 2, y: r.minY, width: r.maxX - gxv - gap / 2, height: T))
            d.append(TwDoor(r: CGRect(x: gxv - gap / 2, y: r.minY, width: gap, height: T), horiz: true))
        } else { w.append(CGRect(x: r.minX, y: r.minY, width: r.width, height: T)) }
        // bottom
        if side == 1 {
            w.append(CGRect(x: r.minX, y: r.maxY - T, width: gxv - gap / 2 - r.minX, height: T))
            w.append(CGRect(x: gxv + gap / 2, y: r.maxY - T, width: r.maxX - gxv - gap / 2, height: T))
            d.append(TwDoor(r: CGRect(x: gxv - gap / 2, y: r.maxY - T, width: gap, height: T), horiz: true))
        } else { w.append(CGRect(x: r.minX, y: r.maxY - T, width: r.width, height: T)) }
        // left
        if side == 2 {
            w.append(CGRect(x: r.minX, y: r.minY, width: T, height: gyv - gap / 2 - r.minY))
            w.append(CGRect(x: r.minX, y: gyv + gap / 2, width: T, height: r.maxY - gyv - gap / 2))
            d.append(TwDoor(r: CGRect(x: r.minX, y: gyv - gap / 2, width: T, height: gap), horiz: false))
        } else { w.append(CGRect(x: r.minX, y: r.minY, width: T, height: r.height)) }
        // right
        if side == 3 {
            w.append(CGRect(x: r.maxX - T, y: r.minY, width: T, height: gyv - gap / 2 - r.minY))
            w.append(CGRect(x: r.maxX - T, y: gyv + gap / 2, width: T, height: r.maxY - gyv - gap / 2))
            d.append(TwDoor(r: CGRect(x: r.maxX - T, y: gyv - gap / 2, width: T, height: gap), horiz: false))
        } else { w.append(CGRect(x: r.maxX - T, y: r.minY, width: T, height: r.height)) }
    }

    private func generate(_ f: Int) {
        let W = TowerMap.W, H = TowerMap.H, T = TowerMap.T
        var w: [CGRect] = []
        var d: [TwDoor] = []
        var rm: [TwRoom] = []
        w.append(CGRect(x: 0, y: 0, width: W, height: T))
        w.append(CGRect(x: 0, y: H - T, width: W, height: T))
        w.append(CGRect(x: 0, y: 0, width: T, height: H))
        w.append(CGRect(x: W - T, y: 0, width: T, height: H))
        w.append(TowerMap.core)
        let xs: [(CGFloat, CGFloat)] = [(150, 300), (510, 260), (830, 260), (1150, 300)]
        let roomNames = [["RECEPTION", "SECURITY", "CAFE", "MAIL ROOM"], ["OPEN PLAN", "HR", "FINANCE", "LEGAL"], ["LAB A", "LAB B", "CLEAN ROOM", "SERVERS"], ["BAR", "CINEMA", "GAME ROOM", "SPA"], ["BOARDROOM", "CEO OFFICE", "CFO OFFICE", "ARCHIVE"], ["SUITE", "BALLROOM", "LIBRARY", "VAULT"]]
        let mats = [3, 0, 5, 2, 4, 2]
        var k = 0
        for (x, wd) in xs {
            let nm = roomNames[f][k]
            addRoom(CGRect(x: x, y: 16, width: wd, height: 180), side: 1, name: nm, mat: mats[f], f: f, w: &w, d: &d)
            rm.append(TwRoom(r: CGRect(x: x, y: 16, width: wd, height: 180), name: nm, mat: mats[f]))
            addRoom(CGRect(x: x, y: 804, width: wd, height: 180), side: 0, name: nm + " 2", mat: mats[(f + 1) % 6], f: f, w: &w, d: &d)
            rm.append(TwRoom(r: CGRect(x: x, y: 804, width: wd, height: 180), name: nm + " 2", mat: mats[(f + 1) % 6]))
            k += 1
        }
        let mids: [(CGRect, Int)] = [(CGRect(x: 170, y: 260, width: 300, height: 150), 1), (CGRect(x: 170, y: 590, width: 300, height: 150), 0), (CGRect(x: 1130, y: 260, width: 300, height: 150), 1), (CGRect(x: 1130, y: 590, width: 300, height: 150), 0)]
        for (i, m) in mids.enumerated() {
            addRoom(m.0, side: m.1, name: "ROOM \(i + 1)", mat: mats[(f + i) % 6], f: f, w: &w, d: &d)
            rm.append(TwRoom(r: m.0, name: "ROOM \(i + 1)", mat: mats[(f + i) % 6]))
        }
        // pillars + kiosk
        var pr: [TwProp] = []
        for p in [(600, 300), (1000, 300), (600, 680), (1000, 680), (1010, 470)] {
            pr.append(TwProp(r: CGRect(x: CGFloat(p.0), y: CGFloat(p.1), width: 36, height: 36), kind: 9))
        }
        pr.append(TwProp(r: CGRect(x: 480, y: 480, width: 40, height: 40), kind: 8))
        // room props
        let themes: [[Int]] = [[2, 3, 1, 5], [1, 4, 3, 0], [6, 5, 0, 7], [2, 5, 3, 7], [1, 2, 4, 3], [2, 5, 3, 4]]
        let sizes: [Int: CGSize] = [0: CGSize(width: 34, height: 34), 1: CGSize(width: 72, height: 34), 2: CGSize(width: 84, height: 36), 3: CGSize(width: 24, height: 24), 4: CGSize(width: 90, height: 22), 5: CGSize(width: 60, height: 60), 6: CGSize(width: 30, height: 60), 7: CGSize(width: 24, height: 24)]
        var lootPts: [CGPoint] = []
        for r in rm {
            let inner = r.r.insetBy(dx: T + 24, dy: T + 24)
            var doorC = CGPoint(x: r.r.midX, y: r.r.midY)
            for dd in d where r.r.insetBy(dx: -2, dy: -2).intersects(dd.r) { doorC = CGPoint(x: dd.r.midX, y: dd.r.midY) }
            let n = 3 + Int(rng.f() * 2)
            var placed: [CGRect] = []
            var tries = 0
            while placed.count < n && tries < 40 {
                tries += 1
                let kind = themes[f][Int(rng.f() * 4) % 4]
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
                got += 1
            }
        }
        var spawnPts = lootPts
        // hall loot
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
            lootPts.append(p)
            hall += 1
        }
        spawnPts.shuffle()
        walls.append(w)
        props.append(pr)
        rooms.append(rm)
        doors.append(d)
        solids.append(w + pr.map { $0.r })
        loot.append(lootPts)
        spawns.append(spawnPts)
    }

    // MARK: collision

    func refreshBlockers() {
        blockers = []
        for f in 0..<TowerMap.nF {
            var b = solids[f]
            for d in doors[f] where d.closed { b.append(d.r) }
            blockers.append(b)
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
        for w in blockers[f] {
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
        for w in solids[f] where w.insetBy(dx: -r, dy: -r).contains(p) { return false }
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
