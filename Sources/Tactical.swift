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

enum TMap {
    static let W: CGFloat = 1700
    static let H: CGFloat = 1200
    static let th: CGFloat = 14

    private static func hw(_ y: CGFloat, _ x1: CGFloat, _ x2: CGFloat, _ gaps: [(CGFloat, CGFloat)] = []) -> [CGRect] {
        var out: [CGRect] = []
        var cur = x1
        for g in gaps.sorted(by: { $0.0 < $1.0 }) {
            if g.0 > cur { out.append(CGRect(x: cur, y: y - th / 2, width: g.0 - cur, height: th)) }
            cur = g.1
        }
        if cur < x2 { out.append(CGRect(x: cur, y: y - th / 2, width: x2 - cur, height: th)) }
        return out
    }
    private static func vw(_ x: CGFloat, _ y1: CGFloat, _ y2: CGFloat, _ gaps: [(CGFloat, CGFloat)] = []) -> [CGRect] {
        var out: [CGRect] = []
        var cur = y1
        for g in gaps.sorted(by: { $0.0 < $1.0 }) {
            if g.0 > cur { out.append(CGRect(x: x - th / 2, y: cur, width: th, height: g.0 - cur)) }
            cur = g.1
        }
        if cur < y2 { out.append(CGRect(x: x - th / 2, y: cur, width: th, height: y2 - cur)) }
        return out
    }

    static let walls: [CGRect] = {
        var w: [CGRect] = []
        w += hw(0, 0, W)
        w += hw(H, 0, W)
        w += vw(0, 0, H)
        w += vw(W, 0, H)
        w += vw(560, 0, H, [(200, 300), (700, 800), (1000, 1100)])
        w += vw(1140, 0, H, [(350, 450), (800, 900)])
        w += hw(600, 0, 560, [(220, 320)])
        w += hw(600, 560, 1140, [(700, 800)])
        w += hw(600, 1140, W, [(1350, 1450)])
        return w
    }()

    static let crates: [CGRect] = [
        CGRect(x: 300, y: 450, width: 70, height: 70), CGRect(x: 90, y: 420, width: 60, height: 60),
        CGRect(x: 440, y: 90, width: 60, height: 60), CGRect(x: 120, y: 90, width: 56, height: 56),
        CGRect(x: 700, y: 240, width: 80, height: 70), CGRect(x: 900, y: 380, width: 70, height: 70),
        CGRect(x: 860, y: 100, width: 60, height: 60), CGRect(x: 640, y: 440, width: 60, height: 60),
        CGRect(x: 640, y: 960, width: 70, height: 70), CGRect(x: 980, y: 700, width: 70, height: 70),
        CGRect(x: 1000, y: 1000, width: 80, height: 60), CGRect(x: 760, y: 700, width: 60, height: 60),
        CGRect(x: 1300, y: 300, width: 80, height: 70), CGRect(x: 1500, y: 450, width: 60, height: 60),
        CGRect(x: 1280, y: 800, width: 90, height: 70), CGRect(x: 1500, y: 1000, width: 70, height: 70),
        CGRect(x: 300, y: 800, width: 70, height: 70), CGRect(x: 200, y: 1000, width: 60, height: 60)
    ]

    static let solid: [CGRect] = walls + crates
    static let siteA = CGRect(x: 170, y: 170, width: 230, height: 170)
    static let siteB = CGRect(x: 690, y: 830, width: 240, height: 170)
    static let atkSpawn: [CGPoint] = [CGPoint(x: 90, y: 1130), CGPoint(x: 160, y: 1130), CGPoint(x: 230, y: 1130), CGPoint(x: 90, y: 1060), CGPoint(x: 160, y: 1060)]
    static let defSpawn: [CGPoint] = [CGPoint(x: 1610, y: 70), CGPoint(x: 1540, y: 70), CGPoint(x: 1470, y: 70), CGPoint(x: 1610, y: 140), CGPoint(x: 1540, y: 140)]

    static func site(_ i: Int) -> CGRect { i == 0 ? siteA : siteB }

    static func los(_ a: CGPoint, _ b: CGPoint) -> Bool {
        for r in solid where tSegT(a, b, r) != nil { return false }
        return true
    }

    static func rayDist(_ from: CGPoint, _ ang: CGFloat, _ maxD: CGFloat) -> CGFloat {
        let b = CGPoint(x: from.x + cos(ang) * maxD, y: from.y + sin(ang) * maxD)
        var best: CGFloat = 1
        for r in solid { if let t = tSegT(from, b, r), t < best { best = t } }
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
    }
    struct Nade {
        var pos: CGPoint
        var vel: CGVector
        var fuse: CGFloat
        var owner: Int
        var team: Int
    }
    struct Boom {
        var pos: CGPoint
        var life: CGFloat
        var r: CGFloat
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
    var booms: [Boom] = []
    var pops: [Pop] = []
    var feed: [Feed] = []
    var sprites: [String: UIImage] = [:]
    var me: TPlayer { players[0] }

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
    var firing = false
    var actHeld = false
    var wantNade = false
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
            let atk = p.team == atkTeam
            let spot = atk ? TMap.atkSpawn[ai % 5] : TMap.defSpawn[di % 5]
            if atk { ai += 1 } else { di += 1 }
            p.pos = spot
            p.aim = atan2(TMap.H / 2 - spot.y, TMap.W / 2 - spot.x)
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
        shake = max(0, shake - dt * 30)
        for i in feed.indices { feed[i].life -= dt }
        feed.removeAll { $0.life <= 0 }
        for i in booms.indices { booms[i].life -= dt }
        booms.removeAll { $0.life <= 0 }
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
        moveProjectiles(dt)
        // spotting
        spotT -= dt
        if spotT <= 0 {
            spotT = 0.1
            for e in players where e.team != me.team {
                e.spotted = false
                guard e.alive else { continue }
                for a in players where a.team == me.team && a.alive {
                    if tDist(a.pos, e.pos) < 900 && TMap.los(a.pos, e.pos) { e.spotted = true; e.seenEver = true; break }
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
        p.pos.x += move.dx * sp * dt
        p.pos.y += move.dy * sp * dt
        TMap.push(&p.pos, 14)
        if let a = aimIn { p.aim = a }
        p.fireCd -= dt
        if wantReload { wantReload = false; startReload(p) }
        if p.reloadT > 0 {
            p.reloadT -= dt
            if p.reloadT <= 0 { finishReload(p) }
        } else if firing && p.fireCd <= 0 && !actHeld {
            if p.mag > 0 { shoot(p, 0) } else { startReload(p) }
        }
        if wantNade { wantNade = false; throwNade(p, p.aim, 420) }
        if actHeld {
            if p.team == atkTeam && !planted && TMap.site(atkSite).contains(p.pos) && move == .zero { planting = true }
            if p.team != atkTeam && planted && tDist(p.pos, bombPos) < 46 && move == .zero { defusing = true }
        }
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

    private func throwNade(_ p: TPlayer, _ ang: CGFloat, _ speed: CGFloat) {
        guard p.nades > 0, p.alive else { return }
        p.nades -= 1
        nades.append(Nade(pos: CGPoint(x: p.pos.x + cos(ang) * 20, y: p.pos.y + sin(ang) * 20),
                          vel: CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed), fuse: 1.5, owner: p.id, team: p.team))
    }

    private func damage(_ victim: TPlayer, _ amt: CGFloat, by owner: Int) {
        guard victim.alive else { return }
        victim.hp -= amt
        victim.hurt = 0.25
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
            for r in TMap.solid where tSegT(old, b.pos, r) != nil { dead = true; break }
            if dead { continue }
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
            if n.fuse <= 0 {
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
                if d < 780 && d < bd && TMap.los(p.pos, e.pos) { best = e; bd = d }
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
        // actions
        if p.targetID < 0 {
            if atk && !planted && p.role == 1 && TMap.site(atkSite).contains(p.pos) { planting = true }
            if !atk && planted && tDist(p.pos, bombPos) < 40 { defusing = true }
        }
        // movement
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
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        let camX = min(max(0, focus.pos.x - size.width / 2), max(0, TMap.W - size.width))
        let camY = min(max(0, focus.pos.y - size.height / 2), max(0, TMap.H - size.height))
        var w = ctx
        let sx = shake > 0 ? CGFloat.random(in: -shake...shake) * 0.5 : 0
        let sy = shake > 0 ? CGFloat.random(in: -shake...shake) * 0.5 : 0
        w.translateBy(x: -camX + sx, y: -camY + sy)
        // floor
        w.fill(Path(CGRect(x: 0, y: 0, width: TMap.W, height: TMap.H)), with: .color(Color(red: 0.16, green: 0.19, blue: 0.24)))
        var grid = Path()
        var gx: CGFloat = (camX / 60).rounded(.down) * 60
        while gx < camX + size.width + 60 { grid.move(to: CGPoint(x: gx, y: camY - 60)); grid.addLine(to: CGPoint(x: gx, y: camY + size.height + 60)); gx += 60 }
        var gy: CGFloat = (camY / 60).rounded(.down) * 60
        while gy < camY + size.height + 60 { grid.move(to: CGPoint(x: camX - 60, y: gy)); grid.addLine(to: CGPoint(x: camX + size.width + 60, y: gy)); gy += 60 }
        w.stroke(grid, with: .color(.white.opacity(0.05)), lineWidth: 1)
        // sites
        for i in 0..<2 {
            let r = TMap.site(i)
            let on = i == atkSite && !planted
            w.fill(Path(roundedRect: r, cornerRadius: 10), with: .color(Color(red: 0.15, green: 0.45, blue: 0.85).opacity(0.22)))
            w.stroke(Path(roundedRect: r.insetBy(dx: 6, dy: 6), cornerRadius: 8), with: .color(Color(red: 0.98, green: 0.8, blue: 0.08).opacity(0.85)), lineWidth: 3)
            let c = CGPoint(x: r.midX, y: r.midY)
            w.fill(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)), with: .color(.black.opacity(0.5)))
            w.stroke(Path(ellipseIn: CGRect(x: c.x - 24, y: c.y - 24, width: 48, height: 48)), with: .color(.white.opacity(0.9)), lineWidth: 2.5)
            w.draw(Text(i == 0 ? "A" : "B").font(.system(size: 26, weight: .heavy)).foregroundColor(.white), at: c)
            _ = on
        }
        // walls
        for o in TMap.walls {
            w.fill(Path(o.offsetBy(dx: 0, dy: 9)), with: .color(.black.opacity(0.4)))
            w.fill(Path(o), with: .color(Color(red: 0.11, green: 0.14, blue: 0.19)))
            w.fill(Path(o.offsetBy(dx: 0, dy: -4)), with: .color(Color(red: 0.24, green: 0.3, blue: 0.38)))
        }
        for o in TMap.crates {
            w.fill(Path(o.offsetBy(dx: 0, dy: 7)), with: .color(.black.opacity(0.4)))
            w.fill(Path(roundedRect: o, cornerRadius: 5), with: .color(Color(red: 0.2, green: 0.25, blue: 0.31)))
            w.stroke(Path(roundedRect: o, cornerRadius: 5), with: .color(.white.opacity(0.22)), lineWidth: 2)
            var x = Path()
            x.move(to: CGPoint(x: o.minX + 6, y: o.minY + 6)); x.addLine(to: CGPoint(x: o.maxX - 6, y: o.maxY - 6))
            x.move(to: CGPoint(x: o.maxX - 6, y: o.minY + 6)); x.addLine(to: CGPoint(x: o.minX + 6, y: o.maxY - 6))
            w.stroke(x, with: .color(.white.opacity(0.1)), lineWidth: 2)
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
            w.fill(Path(ellipseIn: CGRect(x: g.pos.x - 5, y: g.pos.y - 5, width: 10, height: 10)), with: .color(Color(red: 0.4, green: 0.9, blue: 0.4)))
        }
        // characters (allies always, enemies when spotted)
        for p in players where p.alive && (p.team == me.team || p.spotted) { drawPlayer(&w, p) }
        for b in booms {
            let k = 1 - b.life / 0.45
            let rr = b.r * (0.35 + k * 0.7)
            w.fill(Path(ellipseIn: CGRect(x: b.pos.x - rr, y: b.pos.y - rr, width: rr * 2, height: rr * 2)), with: .color(Color.orange.opacity(0.5 * (1 - Double(min(1, k))))))
            w.stroke(Path(ellipseIn: CGRect(x: b.pos.x - rr, y: b.pos.y - rr, width: rr * 2, height: rr * 2)), with: .color(.yellow.opacity(Double(max(0, 1 - k)))), lineWidth: 3)
        }
        for p in pops {
            w.draw(Text(p.text).font(.system(size: 16, weight: .heavy)).foregroundColor(p.color.opacity(Double(p.life))), at: CGPoint(x: p.pos.x, y: p.pos.y - 24 - (1 - p.life) * 24))
        }
        // minimap (screen space)
        drawMinimap(&ctx)
        if me.hurt > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.red.opacity(Double(me.hurt) * 0.45)))
        }
        if !me.alive {
            ctx.draw(Text("SPECTATING " + focus.name.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.7)), at: CGPoint(x: size.width / 2, y: size.height - 90))
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

    private func drawMinimap(_ ctx: inout GraphicsContext) {
        let s: CGFloat = 0.085
        let ox: CGFloat = 12, oy: CGFloat = 110
        let back = CGRect(x: ox - 4, y: oy - 4, width: TMap.W * s + 8, height: TMap.H * s + 8)
        ctx.fill(Path(roundedRect: back, cornerRadius: 8), with: .color(.black.opacity(0.55)))
        for r in TMap.walls {
            ctx.fill(Path(CGRect(x: ox + r.minX * s, y: oy + r.minY * s, width: max(1.5, r.width * s), height: max(1.5, r.height * s))), with: .color(.white.opacity(0.5)))
        }
        for i in 0..<2 {
            let r = TMap.site(i)
            ctx.fill(Path(CGRect(x: ox + r.minX * s, y: oy + r.minY * s, width: r.width * s, height: r.height * s)), with: .color(.yellow.opacity(0.25)))
            ctx.draw(Text(i == 0 ? "A" : "B").font(.system(size: 9, weight: .heavy)).foregroundColor(.yellow), at: CGPoint(x: ox + r.midX * s, y: oy + r.midY * s))
        }
        for p in players where p.alive && (p.team == me.team || p.spotted) {
            let c: Color = p.isPlayer ? .green : (p.team == me.team ? .blue : .red)
            ctx.fill(Path(ellipseIn: CGRect(x: ox + p.pos.x * s - 2.5, y: oy + p.pos.y * s - 2.5, width: 5, height: 5)), with: .color(c))
        }
        if planted {
            ctx.fill(Path(ellipseIn: CGRect(x: ox + bombPos.x * s - 3.5, y: oy + bombPos.y * s - 3.5, width: 7, height: 7)), with: .color(.orange))
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
    @State private var engine = TacticalEngine()
    @State private var lStart: CGPoint? = nil
    @State private var lKnob: CGPoint = .zero
    @State private var rStart: CGPoint? = nil
    @State private var rKnob: CGPoint = .zero
    @State private var collected = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    engine.step(tl.date)
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
            let st = game.s
            let cast = st.npcs.filter { $0.id != "newsdesk" }
            let owned = (st.ex.surv ?? SurvData()).guns
            let gun = owned.contains("rifle") ? "rifle" : (owned.contains("smg") ? "smg" : "pistol")
            engine.setup(cast: cast, persona: st.persona, gun: gun, diff: diff)
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
                                rStart = v.startLocation
                                rKnob = v.location
                                let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                                if hypot(dx, dy) > 8 { engine.aimIn = atan2(dy, dx) }
                                engine.firing = true
                            }
                            .onEnded { _ in rStart = nil; engine.firing = false })
                }
                if let s = lStart { stick(s, lKnob, Color.white) }
                if let s = rStart { stick(s, rKnob, Color.red) }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
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
                    Button { e.paused = true } label: {
                        Image(systemName: "pause.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 38, height: 38).background(Color.black.opacity(0.55)).clipShape(Circle())
                    }
                }
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
