import SwiftUI

struct TwGun {
    var id: String
    var rar: Int
    var mag: Int
    var res: Int
}

struct TwLoot {
    var f: Int
    var p: CGPoint
    var kind: Int      // 0 gun 1 ammo 2 armor 3 med 4 cash
    var gun: String
    var rar: Int
    var alive = true
}

struct TwTracer {
    var a: CGPoint
    var b: CGPoint
    var f: Int
    var t: CGFloat
    var hot: Bool
}

struct TwNum {
    var p: CGPoint
    var f: Int
    var v: Int
    var head: Bool
    var t: CGFloat
}

struct TwView {
    var p: CGPoint
    var f: Int
    var ang: CGFloat
    var alive: Bool
    var flash: Bool
    var walk: CGFloat
    var gun: Int
    var hurt: Bool
    var team: Int
}

struct TwFrame {
    var v: [TwView]
    var shots: [TwTracer]
}

final class TwKillCam {
    var frames: [TwFrame]
    var t: CGFloat = 0
    let killer: Int
    let victim: Int
    init(frames: [TwFrame], killer: Int, victim: Int) {
        self.frames = frames
        self.killer = killer
        self.victim = victim
    }
    var idx: Int { max(0, min(frames.count - 1, Int(t / 0.05))) }
    var done: Bool { idx >= frames.count - 1 }
}

final class TwActor {
    let id: Int
    var name: String
    var team: Int
    var isMe: Bool
    var p: CGPoint
    var f: Int
    var hp: CGFloat = 100
    var armor: CGFloat = 0
    var ang: CGFloat = 0
    var alive = true
    var slots: [TwGun?] = [TwGun(id: "pistol", rar: 0, mag: 15, res: 45), nil]
    var cur = 0
    var fireT: CGFloat = 0
    var reloadT: CGFloat = 0
    var meds = 0
    var path: [TwNode] = []
    var pi = 0
    var repath: CGFloat = 0
    var goal: CGPoint? = nil
    var goalF = 0
    var target = -1
    var strafe: CGFloat = 1
    var strafeT: CGFloat = 0
    var xfer: CGFloat = 0
    var kills = 0
    var flash: CGFloat = 0
    var walk: CGFloat = 0
    var hurtT: CGFloat = 0
    var think: CGFloat = 0
    var skill: CGFloat = 0.5
    var stuck: CGFloat = 0
    var lastP = CGPoint.zero
    var scanT: CGFloat = 0
    var keys = 0
    var lastStep = 0

    init(id: Int, name: String, team: Int, isMe: Bool, p: CGPoint, f: Int) {
        self.id = id
        self.name = name
        self.team = team
        self.isMe = isMe
        self.p = p
        self.f = f
        self.lastP = p
    }

    var gun: TwGun? { slots[cur] }
}

struct TwTrain {
    var f: Int
    var li: Int
    var x: CGFloat
    var dir: CGFloat
    var state: Int      // 0 idle, 1 warning, 2 moving
    var t: CGFloat
    var rect: CGRect
}

final class TowerEngine {
    let def: MapDef
    lazy var map: TowerMap = TowerMap(def: def)
    var teams: Int { def.teams }
    var per: Int { def.per }
    var powerOn: [Bool] = []
    var hack: [CGFloat] = []
    var dark: [Int: CGFloat] = [:]
    var nextDark: CGFloat = 40
    var trains: [TwTrain] = []
    var alerts: [TwNum] = []

    init(def: MapDef) {
        self.def = def
    }
    var actors: [TwActor] = []
    var loot: [TwLoot] = []
    var tracers: [TwTracer] = []
    var nums: [TwNum] = []
    var time: CGFloat = 0
    var paused = false
    var over = false
    var won = false
    var place = 8
    var last: Date? = nil
    var rng = BRRand(s: UInt64.random(in: 1...999999))

    // input
    var move = CGPoint.zero
    var aim = CGPoint.zero
    var firing = false
    var sens: CGFloat = 1

    // zone
    var gasOrder: [Int] = []
    var gassed: Set<Int> = []
    var warnFloor = -1
    var warnT: CGFloat = 0
    var nextGasT: CGFloat = 40
    var finalFloor = 0
    var circle = CGPoint(x: 800, y: 500)
    var circleR: CGFloat = 1200
    var circleOn = false
    var stage = 0

    // stats
    var kills = 0
    var heads = 0
    var contractGems = 0
    var contractLines: [(String, Bool)] = []
    var banner = ""
    var bannerT: CGFloat = 0
    var hurtFlash: CGFloat = 0
    var hitMark: CGFloat = 0
    var elevCool: CGFloat = 0
    var feed: [(String, CGFloat)] = []
    var recorded = false
    var hist: [TwFrame] = []
    var histT: CGFloat = 0
    var pendingShots: [TwTracer] = []
    var killcam: TwKillCam? = nil
    var placeSet = false
    var zoom = 1
    var look = false
    var camYaw: CGFloat = 0
    var camPitch: CGFloat = 1.0
    var camDist: CGFloat = 430
    var dtLast: CGFloat = 0.016
    var autoReload = true

    var me: TwActor { actors[0] }

    func setup(name: String) {
        let m = map
        let names = ["Rex", "Nova", "Kilo", "Juno", "Axel", "Mira", "Tank", "Zed", "Echo", "Vex", "Luna", "Bolt", "Onyx", "Pike", "Sable", "Wren", "Drax", "Isla", "Cruz", "Fenix", "Gale", "Hawk", "Ivy", "Jett"]
        var id = 0
        for t in 0..<teams {
            let f = t == 0 ? 0 : Int(rng.f() * CGFloat(map.nF)) % map.nF
            let base = m.spawns[f].isEmpty ? CGPoint(x: 800, y: 500) : m.spawns[f][(t * 7) % m.spawns[f].count]
            for k in 0..<per {
                let me = (t == 0 && k == 0)
                var p = t == 0 ? CGPoint(x: 620 + CGFloat(k) * 30, y: 520) : CGPoint(x: base.x + CGFloat(k) * 20, y: base.y)
                p = m.push(p, 12, f)
                let a = TwActor(id: id, name: me ? name : names[id % names.count], team: t, isMe: me, p: p, f: f)
                a.skill = 0.35 + rng.f() * 0.4
                a.ang = rng.f() * 6.28
                actors.append(a)
                id += 1
            }
        }
        // loot
        for f in 0..<map.nF {
            for (idx, p) in m.loot[f].enumerated() {
                let boost = m.lootBoost[f][idx]
                let r = rng.f()
                var l = TwLoot(f: f, p: p, kind: 0, gun: "pistol", rar: 0)
                let hi = CGFloat(f) / CGFloat(max(1, map.nF - 1))
                func pickGun() -> String {
                    let g = rng.f()
                    return g < 0.2 ? "pistol" : g < 0.5 ? "smg" : g < 0.8 ? "rifle" : "shotgun"
                }
                if boost == 2 {
                    if r < 0.6 { l.kind = 0; l.gun = ["smg", "rifle", "shotgun", "rifle"][Int(rng.f() * 3.99)]; l.rar = rng.f() > 0.5 ? 3 : 2 } else if r < 0.85 { l.kind = 2 } else { l.kind = 3 }
                } else if boost == 1 {
                    if r < 0.4 { l.kind = 0; l.gun = pickGun(); l.rar = rng.f() > 0.5 ? 2 : 1 } else if r < 0.7 { l.kind = 3 } else { l.kind = 2 }
                } else if r < 0.30 {
                    l.kind = 0
                    l.gun = pickGun()
                    let rr = rng.f() + hi * 0.35
                    l.rar = rr > 1.15 ? 3 : rr > 0.85 ? 2 : rr > 0.5 ? 1 : 0
                } else if r < 0.55 { l.kind = 1 } else if r < 0.75 { l.kind = 2 } else if r < 0.9 { l.kind = 3 } else { l.kind = 4 }
                loot.append(l)
            }
            if def.mech == 4 || def.mech == 5 {
                for _ in 0..<3 { loot.append(TwLoot(f: f, p: map.randomLoot(f), kind: 5, gun: "", rar: 0)) }
            }
        }
        powerOn = [Bool](repeating: false, count: map.nF)
        hack = [CGFloat](repeating: 0, count: map.nF)
        for f in 0..<map.nF {
            for li in 0..<map.lanes[f].count {
                trains.append(TwTrain(f: f, li: li, x: -700, dir: li % 2 == 0 ? 1 : -1, state: 0, t: 8 + rng.f() * 22, rect: .zero))
            }
        }
        if def.mech == 4 || def.mech == 5 { for a in actors { a.keys = 1 } }
        // zone plan
        finalFloor = def.finalFloor >= 0 ? def.finalFloor : Int(rng.f() * CGFloat(map.nF)) % map.nF
        gasOrder = (0..<map.nF).filter { $0 != finalFloor }
        for i in stride(from: gasOrder.count - 1, to: 0, by: -1) { gasOrder.swapAt(i, Int(rng.f() * CGFloat(i + 1)) % (i + 1)) }
        let c = map.rooms[finalFloor].randomElement()?.r ?? CGRect(x: 700, y: 400, width: 100, height: 100)
        circle = def.finalCore ? CGPoint(x: TowerMap.core.midX, y: TowerMap.core.midY) : CGPoint(x: c.midX, y: c.midY)
        banner = "\(def.name)  -  \(def.sign)  -  LOOT UP"
        bannerT = 4
        // bot mates start with a rifle so they are useful
        for a in actors where a.team == 0 && !a.isMe { a.slots[1] = TwGun(id: "smg", rar: 0, mag: 30, res: 90) }
    }

    // MARK: views / replay

    func gunIdx(_ a: TwActor) -> Int {
        switch a.gun?.id ?? "pistol" {
        case "smg": return 1
        case "rifle": return 2
        case "shotgun": return 3
        default: return 0
        }
    }

    func snapshot() -> [TwView] {
        actors.map { TwView(p: $0.p, f: $0.f, ang: $0.ang, alive: $0.alive, flash: $0.flash > 0.4, walk: $0.walk, gun: gunIdx($0), hurt: $0.hurtT > 0, team: $0.team) }
    }

    func currentViews() -> [TwView] {
        if let k = killcam { return k.frames[k.idx].v }
        return snapshot()
    }

    func currentShots(_ f: Int) -> [TwTracer] {
        if let k = killcam { return k.frames[k.idx].shots.filter { $0.f == f } }
        return tracers.filter { $0.f == f }
    }

    func skipKillCam() {
        killcam = nil
        checkEnd()
    }

    // MARK: helpers

    func teamAlive(_ t: Int) -> Int { actors.filter { $0.team == t && $0.alive }.count }
    var teamsLeft: Int { Set(actors.filter { $0.alive }.map { $0.team }).count }
    var aliveCount: Int { actors.filter { $0.alive }.count }

    func note(_ s: String) {
        feed.append((s, 5))
        if feed.count > 5 { feed.removeFirst() }
    }

    func sfx(_ n: String, at p: CGPoint, f: Int, vol: Float = 1) {
        guard let m = actors.first, m.f == f else { return }
        let d = hypot(p.x - m.p.x, p.y - m.p.y)
        if d > 800 { return }
        let fall = Float(pow(max(0, 1 - Double(d) / 800), 1.5))
        BRAudio.shared.play(n, vol: vol * fall, pan: Float(max(-1, min(1, (p.x - m.p.x) / 500))))
    }

    func gasActive(_ a: TwActor) -> Bool {
        if gassed.contains(a.f) { return true }
        if circleOn && a.f == finalFloor && hypot(a.p.x - circle.x, a.p.y - circle.y) > circleR { return true }
        return false
    }

    // MARK: step

    func step(_ date: Date) {
        var dt = CGFloat(last.map { date.timeIntervalSince($0) } ?? 0.016)
        last = date
        dt = max(0.001, min(0.05, dt))
        dtLast = dt
        if paused || over { return }
        time += dt
        elevCool = max(0, elevCool - dt)
        hurtFlash = max(0, hurtFlash - dt * 2)
        hitMark = max(0, hitMark - dt * 4)
        bannerT = max(0, bannerT - dt)
        feed = feed.compactMap { $0.1 - dt > 0 ? ($0.0, $0.1 - dt) : nil }
        for i in tracers.indices { tracers[i].t -= dt }
        tracers.removeAll { $0.t <= 0 }
        for i in nums.indices { nums[i].t -= dt; nums[i].p.y -= dt * 22 }
        nums.removeAll { $0.t <= 0 }
        histT += dt
        if histT >= 0.05 {
            histT -= 0.05
            hist.append(TwFrame(v: snapshot(), shots: pendingShots))
            pendingShots = []
            if hist.count > 90 { hist.removeFirst() }
        }
        if let k = killcam {
            k.t += dt
            if k.done { killcam = nil }
        }
        updateZone(dt)
        updateDoors(dt)
        updateMech(dt)
        var rep = 0
        for a in actors where a.alive {
            if a.isMe { updateMe(a, dt) } else { updateBot(a, dt, &rep) }
            if gasActive(a) {
                let dmg = (3 + CGFloat(stage) * 1.5) * dt
                hurt(a, dmg, by: nil, head: false, silent: true)
            }
            for b in map.belts[a.f] where b.0.contains(a.p) {
                a.p = map.push(CGPoint(x: a.p.x + b.1.x * dt, y: a.p.y + b.1.y * dt), 11, a.f)
            }
            if map.hazards[a.f].contains(where: { $0.contains(a.p) }) {
                hurt(a, 5 * dt, by: nil, head: false, silent: true)
            }
            let ph = Int(a.walk / 0.9)
            if ph != a.lastStep {
                a.lastStep = ph
                if !a.isMe && a.f == me.f && hypot(a.p.x - me.p.x, a.p.y - me.p.y) < 480 { sfx("step", at: a.p, f: a.f, vol: 0.5) }
            }
            a.flash = max(0, a.flash - dt * 8)
            a.hurtT = max(0, a.hurtT - dt)
        }
        pickups()
        checkEnd()
    }

    func updateZone(_ dt: CGFloat) {
        if stage < gasOrder.count {
            if warnFloor < 0 && time > nextGasT {
                warnFloor = gasOrder[stage]
                warnT = 12
                banner = "FLOOR \(warnFloor + 1) \(def.floors[warnFloor]) SEALING IN 12s"
                bannerT = 4
                BRAudio.shared.play("siren", vol: 0.5)
            }
            if warnFloor >= 0 {
                warnT -= dt
                if warnT <= 0 {
                    gassed.insert(warnFloor)
                    banner = "FLOOR \(warnFloor + 1) IS TOXIC"
                    bannerT = 3
                    warnFloor = -1
                    stage += 1
                    nextGasT = time + 38
                }
            }
        } else if !circleOn {
            circleOn = true
            circleR = 900
            banner = "FINAL FLOOR  -  ZONE CLOSING"
            bannerT = 4
        } else {
            circleR = max(def.finalCore ? 170 : 60, circleR - dt * 7)
        }
    }

    func updateDoors(_ dt: CGFloat) {
        var changed = false
        for f in 0..<map.nF {
            for i in map.doors[f].indices {
                var d = map.doors[f][i]
                let was = d.closed
                let c = CGPoint(x: d.r.midX, y: d.r.midY)
                if d.kind == 1 {
                    let P: CGFloat = def.mech == 3 ? 36 : 26
                    let ph = (time + d.phase).truncatingRemainder(dividingBy: P)
                    if ph < P * 0.4 { d.open = max(0, d.open - dt * 1.6) } else { d.open = min(1, d.open + dt * 1.6) }
                } else {
                    var near = false
                    var who: TwActor? = nil
                    for a in actors where a.alive && a.f == f {
                        if abs(a.p.x - c.x) < 62 && abs(a.p.y - c.y) < 62 { near = true; who = a; if a.keys > 0 { break } }
                    }
                    if d.kind == 2 && d.locked {
                        if near, let w = who, w.keys > 0 {
                            w.keys -= 1
                            d.locked = false
                            d.kind = 0
                            if w.isMe { note("DOOR UNLOCKED"); BRAudio.shared.play("pickup", vol: 0.6) }
                        } else { near = false }
                    }
                    if d.kind == 3 && !powerOn[f] { near = false }
                    if near { d.open = min(1, d.open + dt * 5); d.hold = 0.5 } else {
                        d.hold -= dt
                        if d.hold <= 0 { d.open = max(0, d.open - dt * 3) }
                    }
                }
                map.doors[f][i] = d
                if was != d.closed { changed = true }
            }
        }
        if changed { map.refreshBlockers() }
    }

    // MARK: mechanics

    func activatePower(_ f: Int) {
        powerOn[f] = true
        let sp = TowerMap.switchPos
        for a in actors where a.alive && a.f == f && !a.isMe && a.target < 0 && hypot(a.p.x - sp.x, a.p.y - sp.y) < 780 {
            a.goal = CGPoint(x: sp.x + rng.r(-60, 60), y: sp.y + rng.r(-60, 60))
            a.goalF = f
            a.path = []
            a.repath = 0
            a.think = 5
        }
        alerts.append(TwNum(p: sp, f: f, v: 0, head: false, t: 2.5))
        if me.f == f {
            banner = "POWER RESTORED  -  NOISE ALERT"
            bannerT = 3
        }
        sfx("siren", at: sp, f: f, vol: 0.7)
    }

    func updateMech(_ dt: CGFloat) {
        for i in alerts.indices { alerts[i].t -= dt }
        alerts.removeAll { $0.t <= 0 }
        if def.mech == 6 {
            let sp = TowerMap.switchPos
            for f in 0..<map.nF where !powerOn[f] {
                let near = actors.contains { $0.alive && $0.f == f && hypot($0.p.x - sp.x, $0.p.y - sp.y) < 46 }
                hack[f] = near ? hack[f] + dt : max(0, hack[f] - dt)
                if hack[f] >= 1.2 { activatePower(f) }
            }
        }
        if def.mech == 2 {
            nextDark -= dt
            if nextDark <= 0 {
                nextDark = 45 + rng.f() * 20
                let cands = (0..<map.nF).filter { !gassed.contains($0) && dark[$0] == nil }
                if let f = cands.randomElement() {
                    dark[f] = 22
                    if me.f == f { banner = "POWER FAILURE  -  LIGHTS OUT"; bannerT = 3 }
                }
            }
            for k in Array(dark.keys) {
                dark[k] = (dark[k] ?? 0) - dt
                if (dark[k] ?? 0) <= 0 { dark[k] = nil }
            }
        }
        if !trains.isEmpty {
            var dirty = false
            for i in trains.indices {
                var t = trains[i]
                let lane = map.lanes[t.f][t.li]
                switch t.state {
                case 0:
                    t.t -= dt
                    if t.t <= 3 {
                        t.state = 1
                        if me.f == t.f { banner = "TRAIN INCOMING"; bannerT = 3 }
                        sfx("siren", at: CGPoint(x: 800, y: lane.midY), f: t.f, vol: 0.6)
                    }
                case 1:
                    t.t -= dt
                    if t.t <= 0 {
                        t.state = 2
                        t.x = t.dir > 0 ? -620 : TowerMap.W + 60
                        dirty = true
                    }
                default:
                    t.x += t.dir * 400 * dt
                    t.rect = CGRect(x: t.x, y: lane.minY + 8, width: 560, height: lane.height - 16)
                    dirty = true
                    if (t.dir > 0 && t.x > TowerMap.W + 60) || (t.dir < 0 && t.x < -620) {
                        t.state = 0
                        t.t = 16 + rng.f() * 14
                        t.rect = .zero
                    }
                    for a in actors where a.alive && a.f == t.f && t.rect.insetBy(dx: -6, dy: -6).contains(a.p) {
                        hurt(a, 120 * dt, by: nil, head: false, silent: true)
                    }
                }
                trains[i] = t
            }
            if dirty {
                for f in 0..<map.nF { map.trainRects[f] = trains.filter { $0.f == f && $0.state == 2 }.map { $0.rect } }
                map.refreshBlockers()
            }
        }
    }

    // MARK: movement

    func moveActor(_ a: TwActor, _ v: CGPoint, _ spd: CGFloat, _ dt: CGFloat) {
        let m = hypot(v.x, v.y)
        if m < 0.02 { return }
        let k = min(1, m)
        let nx = a.p.x + v.x / m * spd * k * dt
        let ny = a.p.y + v.y / m * spd * k * dt
        a.p = map.push(CGPoint(x: nx, y: ny), 11, a.f)
        a.walk += spd * k * dt * 0.08
    }

    func updateMe(_ a: TwActor, _ dt: CGFloat) {
        var mv = move
        if look {
            let c = cos(camYaw), sn = sin(camYaw)
            mv = CGPoint(x: c * move.x + sn * move.y, y: -sn * move.x + c * move.y)
        }
        moveActor(a, mv, 150, dt)
        if hypot(aim.x, aim.y) > 0.2 {
            var want = atan2(aim.y, aim.x)
            if let g = a.gun, hypot(aim.x, aim.y) > 0.5 {
                let r = BRGuns.def(g.id).range
                var best: CGFloat = 0.12
                for e in actors where e.alive && e.team != a.team && e.f == a.f {
                    let d = hypot(e.p.x - a.p.x, e.p.y - a.p.y)
                    if d > r || d < 1 { continue }
                    let ang = atan2(e.p.y - a.p.y, e.p.x - a.p.x)
                    let df = abs(brWrap(ang - want))
                    if df < best && map.los(a.f, a.p, e.p) { best = df; want = ang }
                }
            }
            a.ang = want
        }
        a.fireT = max(0, a.fireT - dt)
        if a.reloadT > 0 {
            a.reloadT -= dt
            if a.reloadT <= 0 { finishReload(a) }
        }
        if firing { fire(a) }
        if let g = a.gun, g.mag == 0, a.reloadT <= 0, g.res > 0, autoReload { startReload(a) }
    }

    func startReload(_ a: TwActor) {
        guard a.reloadT <= 0, let g = a.gun else { return }
        let d = BRGuns.def(g.id)
        if g.mag >= d.mag || g.res <= 0 { return }
        a.reloadT = d.reload
        sfx("reload", at: a.p, f: a.f, vol: 0.7)
    }

    func finishReload(_ a: TwActor) {
        guard var g = a.slots[a.cur] else { return }
        let d = BRGuns.def(g.id)
        let n = min(d.mag - g.mag, g.res)
        g.mag += n
        g.res -= n
        a.slots[a.cur] = g
    }

    func swap(_ a: TwActor) {
        let o = 1 - a.cur
        if a.slots[o] != nil { a.cur = o; a.reloadT = 0; a.fireT = 0.25 }
    }

    func useMed(_ a: TwActor) {
        guard a.meds > 0, a.hp < 100 else { return }
        a.meds -= 1
        a.hp = min(100, a.hp + 45)
        sfx("plate", at: a.p, f: a.f, vol: 0.6)
    }

    // MARK: combat

    func fire(_ a: TwActor) {
        guard a.fireT <= 0, a.reloadT <= 0, var g = a.slots[a.cur] else { return }
        let d = BRGuns.def(g.id)
        if g.mag <= 0 { if g.res > 0 { startReload(a) }; return }
        g.mag -= 1
        a.slots[a.cur] = g
        a.fireT = d.rate
        a.flash = 1
        let rb: CGFloat = 1 + CGFloat(g.rar) * 0.08
        sfx("shot_" + g.id, at: a.p, f: a.f, vol: a.isMe ? 0.9 : 1)
        let spreadMul: CGFloat = a.isMe ? 1 : (1.8 - a.skill)
        for _ in 0..<d.pellets {
            let ang = a.ang + (rng.f() - 0.5) * 2 * d.spread * spreadMul
            let dx = cos(ang), dy = sin(ang)
            let origin = CGPoint(x: a.p.x + dx * 16, y: a.p.y + dy * 16)
            var dist = map.rayDist(a.f, origin, dx, dy, d.range)
            if def.mech == 7 {
                var broke = false
                for gi in map.glass[a.f].indices where map.glassAlive[a.f][gi] {
                    if let h = brRay(origin, dx, dy, map.glass[a.f][gi]), h.0 < dist {
                        map.glassAlive[a.f][gi] = false
                        broke = true
                        sfx("pop", at: origin, f: a.f, vol: 0.8)
                    }
                }
                if broke { map.refreshBlockers() }
            }
            var hit: TwActor? = nil
            for e in actors where e.alive && e.team != a.team && e.f == a.f {
                let ox = e.p.x - origin.x, oy = e.p.y - origin.y
                let t = ox * dx + oy * dy
                if t < 0 || t > dist { continue }
                let px = origin.x + dx * t - e.p.x, py = origin.y + dy * t - e.p.y
                if px * px + py * py < 13 * 13 {
                    dist = t
                    hit = e
                }
            }
            let end = CGPoint(x: origin.x + dx * dist, y: origin.y + dy * dist)
            let tr = TwTracer(a: origin, b: end, f: a.f, t: 0.07, hot: g.rar > 0)
            tracers.append(tr)
            pendingShots.append(tr)
            if let e = hit {
                let fall = 1 - 0.4 * min(1, dist / d.range)
                let head = rng.f() < 0.1 + (a.isMe ? 0.04 : 0)
                let dmg = d.dmg * rb * fall * (head ? 1.8 : 1)
                hurt(e, dmg, by: a, head: head, silent: false)
            }
        }
        if tracers.count > 40 { tracers.removeFirst(tracers.count - 40) }
    }

    func hurt(_ e: TwActor, _ dmgIn: CGFloat, by: TwActor?, head: Bool, silent: Bool) {
        guard e.alive else { return }
        var dmg = dmgIn
        if e.armor > 0 {
            let ab = min(e.armor, dmg * 0.6)
            e.armor -= ab
            dmg -= ab
        }
        e.hp -= dmg
        e.hurtT = 0.2
        if !silent {
            nums.append(TwNum(p: CGPoint(x: e.p.x, y: e.p.y - 10), f: e.f, v: Int(dmgIn), head: head, t: 0.8))
            if let b = by, b.isMe {
                hitMark = 1
                sfx(head ? "head" : "hit", at: b.p, f: b.f, vol: 0.8)
            }
            if e.isMe {
                hurtFlash = 1
                BRAudio.shared.play("hurt", vol: 0.8)
            }
            if let b = by, e.team != b.team { e.target = b.id }
        }
        if e.hp <= 0 {
            e.alive = false
            e.hp = 0
            if let b = by {
                b.kills += 1
                note("\(b.isMe ? "YOU" : b.name) eliminated \(e.isMe ? "YOU" : e.name)")
                if b.isMe { kills += 1; if head { heads += 1 }; BRAudio.shared.play("kill", vol: 0.8) }
            } else {
                note("\(e.isMe ? "YOU" : e.name) was lost to toxins")
            }
            // drop
            if let g = e.gun { loot.append(TwLoot(f: e.f, p: e.p, kind: 0, gun: g.id, rar: g.rar)) }
            loot.append(TwLoot(f: e.f, p: CGPoint(x: e.p.x + 14, y: e.p.y), kind: 2, gun: "", rar: 0))
            if e.isMe {
                if let b = by, !hist.isEmpty {
                    hist.append(TwFrame(v: snapshot(), shots: pendingShots))
                    killcam = TwKillCam(frames: hist, killer: b.id, victim: e.id)
                }
                onMeDead()
            }
        }
    }

    func onMeDead() {
        if teamAlive(0) > 0 {
            banner = "DOWN  -  SPECTATING SQUAD"
            bannerT = 3
        }
    }

    func finish(_ w: Bool) {
        guard !over else { return }
        won = w
        over = true
        if w { place = 1 }
        if !recorded {
            recorded = true
            var s = BRStats()
            s.kills = kills
            s.heads = heads
            s.place = place
            s.won = w
            s.secs = Int(time)
            let r = BRMeta.record(s)
            contractGems = r.0
            contractLines = r.1
        }
    }

    func checkEnd() {
        if over { return }
        if teamAlive(0) == 0 {
            if !placeSet { place = teamsLeft + 1; placeSet = true }
            if killcam == nil { finish(false) }
        } else if teamsLeft <= 1 {
            finish(true)
        }
    }

    // MARK: pickups

    func pickups() {
        for a in actors where a.alive {
            for i in loot.indices where loot[i].alive && loot[i].f == a.f {
                let l = loot[i]
                if abs(l.p.x - a.p.x) > 26 || abs(l.p.y - a.p.y) > 26 { continue }
                switch l.kind {
                case 0:
                    let d = BRGuns.def(l.gun)
                    if a.slots[0] == nil || a.slots[1] == nil || a.gun?.id == "pistol" || (a.isMe == false && l.rar > (a.gun?.rar ?? 0)) {
                        let g = TwGun(id: l.gun, rar: l.rar, mag: d.mag, res: d.mag * 2)
                        if a.slots[1] == nil { a.slots[1] = g; if a.isMe { a.cur = 1 } }
                        else if a.slots[0] == nil { a.slots[0] = g }
                        else { a.slots[a.cur] = g }
                        loot[i].alive = false
                        if a.isMe { BRAudio.shared.play("pickup", vol: 0.7); note("PICKED UP " + d.name) }
                    }
                case 1:
                    for k in 0..<2 where a.slots[k] != nil { a.slots[k]!.res += BRGuns.def(a.slots[k]!.id).mag }
                    loot[i].alive = false
                    if a.isMe { BRAudio.shared.play("pickup", vol: 0.5) }
                case 5:
                    a.keys += 1
                    loot[i].alive = false
                    if a.isMe { BRAudio.shared.play("pickup", vol: 0.6); note("KEYCARD x\(a.keys)") }
                case 2:
                    if a.armor < 150 {
                        a.armor = min(150, a.armor + 50)
                        loot[i].alive = false
                        if a.isMe { BRAudio.shared.play("plate", vol: 0.7) }
                    }
                case 3:
                    if a.meds < 4 {
                        a.meds += 1
                        loot[i].alive = false
                        if a.isMe { BRAudio.shared.play("pickup", vol: 0.5) }
                    }
                default:
                    loot[i].alive = false
                    if a.isMe { BRAudio.shared.play("pickup", vol: 0.4); contractGems += 0 }
                }
            }
        }
    }

    // MARK: floors

    func nearStairUp(_ a: TwActor) -> Bool { a.f < map.nF - 1 && TowerMap.stairW.insetBy(dx: -6, dy: -6).contains(a.p) }
    func nearStairDown(_ a: TwActor) -> Bool { a.f > 0 && TowerMap.stairE.insetBy(dx: -6, dy: -6).contains(a.p) }
    func nearElev(_ a: TwActor) -> Bool { TowerMap.elevs.contains { $0.insetBy(dx: -8, dy: -8).contains(a.p) } }

    func go(_ a: TwActor, to f: Int) {
        guard f >= 0, f < map.nF, f != a.f else { return }
        a.f = f
        a.p = map.push(a.p, 11, f)
        a.path = []
        a.xfer = 0.6
        if a.isMe { elevCool = 0.8; BRAudio.shared.play("pickup", vol: 0.6) }
    }

    // MARK: bots

    func updateBot(_ a: TwActor, _ dt: CGFloat, _ rep: inout Int) {
        a.fireT = max(0, a.fireT - dt)
        a.xfer = max(0, a.xfer - dt)
        a.repath -= dt
        a.think -= dt
        a.strafeT -= dt
        if a.reloadT > 0 {
            a.reloadT -= dt
            if a.reloadT <= 0 { finishReload(a) }
        }
        if let g = a.gun, g.mag == 0, a.reloadT <= 0 {
            if g.res > 0 { startReload(a) } else if a.slots[1 - a.cur] != nil { swap(a) }
        }
        if a.hp < 55 && a.meds > 0 && a.think < 0 { useMed(a); a.think = 2 }

        // target (scanned a few times a second, not every frame)
        var tgt: TwActor? = a.target >= 0 && a.target < actors.count ? actors[a.target] : nil
        if let t = tgt, !(t.alive && t.f == a.f && t.team != a.team) { tgt = nil; a.target = -1 }
        a.scanT -= dt
        if a.scanT <= 0 {
            a.scanT = 0.18 + rng.f() * 0.12
            if let t = tgt, !map.los(a.f, a.p, t.p) { tgt = nil; a.target = -1 }
            if tgt == nil {
                var bd: CGFloat = dark[a.f] != nil ? 260 : 520
                for e in actors where e.alive && e.team != a.team && e.f == a.f {
                    let dx = e.p.x - a.p.x, dy = e.p.y - a.p.y
                    if abs(dx) > bd || abs(dy) > bd { continue }
                    let d = hypot(dx, dy)
                    if d < bd && map.los(a.f, a.p, e.p) { bd = d; tgt = e }
                }
                a.target = tgt?.id ?? -1
            }
        }

        let inGas = gasActive(a)
        if inGas || (warnFloor == a.f) {
            if a.goal == nil || a.repath <= 0 || !(safeGoalValid(a)) {
                setSafeGoal(a)
            }
        } else if tgt == nil {
            if a.think <= 0 || a.goal == nil {
                chooseGoal(a)
                a.think = 3 + rng.f() * 3
            }
        }

        if let t = tgt {
            let d = hypot(t.p.x - a.p.x, t.p.y - a.p.y)
            let want = atan2(t.p.y - a.p.y, t.p.x - a.p.x)
            let df = brWrap(want - a.ang)
            a.ang += max(-1, min(1, df)) * min(1, dt * (5 + a.skill * 6))
            if abs(df) < 0.25 && !inGas { fire(a) }
            let gd = BRGuns.def(a.gun?.id ?? "pistol")
            let ideal = gd.range * 0.4
            if a.strafeT <= 0 { a.strafe = rng.f() > 0.5 ? 1 : -1; a.strafeT = 0.6 + rng.f() }
            let fwd = CGPoint(x: cos(want), y: sin(want))
            var v = CGPoint(x: -fwd.y * a.strafe * 0.7, y: fwd.x * a.strafe * 0.7)
            if d > ideal { v.x += fwd.x * 0.6; v.y += fwd.y * 0.6 } else if d < ideal * 0.5 { v.x -= fwd.x * 0.5; v.y -= fwd.y * 0.5 }
            if !inGas { moveActor(a, v, 110, dt) }
            else { follow(a, dt, &rep) }
        } else {
            follow(a, dt, &rep)
        }
        // stuck detection
        a.stuck += dt
        if a.stuck > 1.2 {
            if hypot(a.p.x - a.lastP.x, a.p.y - a.lastP.y) < 12 {
                a.goal = nil
                a.path = []
                a.repath = 0
                a.think = 0
                if def.mech == 6 && !powerOn[a.f] && a.target < 0 {
                    a.goal = TowerMap.switchPos
                    a.goalF = a.f
                    a.think = 4
                }
            }
            a.lastP = a.p
            a.stuck = 0
        }
    }

    func safeGoalValid(_ a: TwActor) -> Bool {
        guard a.goal != nil else { return false }
        return !gassed.contains(a.goalF) && a.goalF != warnFloor
    }

    func setSafeGoal(_ a: TwActor) {
        var f = finalFloor
        if !circleOn {
            let safe = (0..<map.nF).filter { !gassed.contains($0) && $0 != warnFloor }
            f = safe.min(by: { abs($0 - a.f) < abs($1 - a.f) }) ?? finalFloor
        }
        a.goal = circleOn ? circle : map.randomLoot(f)
        a.goalF = f
        a.path = []
        a.repath = 0
        a.pi = 0
    }

    func chooseGoal(_ a: TwActor) {
        // squad mates stick with the player
        if a.team == 0, me.alive {
            let d = hypot(me.p.x - a.p.x, me.p.y - a.p.y)
            if me.f != a.f || d > 190 {
                a.goal = me.p
                a.goalF = me.f
                a.path = []
                a.repath = 0
                return
            }
            a.goal = CGPoint(x: me.p.x + rng.r(-70, 70), y: me.p.y + rng.r(-70, 70))
            a.goalF = a.f
            a.path = []
            a.repath = 0
            return
        }
        var f = a.f
        let needGear = (a.gun?.id ?? "pistol") == "pistol" || a.armor < 40
        // hunt: after the gas begins, move toward last floors
        if stage > 1 && Int(rng.f() * 3) == 0 { f = finalFloor }
        if !needGear && rng.f() < 0.5 { f = Int(rng.f() * 5.99) }
        if gassed.contains(f) { f = finalFloor }
        // nearest live loot on floor
        var best: CGPoint? = nil
        var bd: CGFloat = 1e9
        for l in loot where l.alive && l.f == f {
            let d = hypot(l.p.x - a.p.x, l.p.y - a.p.y) + rng.f() * 200
            if f != a.f || d < bd { if d < bd { bd = d; best = l.p } }
        }
        a.goal = best ?? map.randomLoot(f)
        a.goalF = f
        a.path = []
        a.repath = 0
    }

    func follow(_ a: TwActor, _ dt: CGFloat, _ rep: inout Int) {
        guard let g = a.goal else { return }
        if a.xfer > 0 { return }
        if a.path.isEmpty || a.repath <= 0 {
            if rep < 2 {
                rep += 1
                let s = map.nearestNode(a.f, a.p)
                let t = map.nearestNode(a.goalF, g)
                a.path = map.path(from: s, to: t)
                a.pi = 0
                a.repath = 2.5 + rng.f()
                if a.path.isEmpty {
                    a.goal = nil
                    return
                }
            } else { return }
        }
        // advance
        while a.pi < a.path.count {
            let n = a.path[a.pi]
            if n.f != a.f {
                // transition node reached earlier; teleport
                a.f = n.f
                a.p = map.push(map.pos(n), 11, a.f)
                a.xfer = 0.5
                a.pi += 1
                return
            }
            let np = map.pos(n)
            let d = hypot(np.x - a.p.x, np.y - a.p.y)
            if d < 16 {
                // is next node on another floor? then we are at the transfer point
                if a.pi + 1 < a.path.count, a.path[a.pi + 1].f != a.f {
                    a.pi += 1
                    continue
                }
                a.pi += 1
                continue
            }
            let v = CGPoint(x: np.x - a.p.x, y: np.y - a.p.y)
            let want = atan2(v.y, v.x)
            if a.target < 0 || a.target >= actors.count || !actors[a.target].alive { a.ang += brWrap(want - a.ang) * min(1, dt * 8) }
            moveActor(a, v, 125, dt)
            return
        }
        // arrived at final node; walk to exact goal on same floor
        if a.f == a.goalF {
            let d = hypot(g.x - a.p.x, g.y - a.p.y)
            if d > 20 && map.los(a.f, a.p, g) {
                moveActor(a, CGPoint(x: g.x - a.p.x, y: g.y - a.p.y), 120, dt)
                return
            }
        }
        a.goal = nil
        a.path = []
        a.think = 0
    }
}
