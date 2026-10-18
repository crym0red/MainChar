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

final class TowerEngine {
    static let teams = 8
    static let per = 3
    let map = TowerMap.shared
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
    var autoReload = true

    var me: TwActor { actors[0] }

    func setup(name: String) {
        let m = map
        let names = ["Rex", "Nova", "Kilo", "Juno", "Axel", "Mira", "Tank", "Zed", "Echo", "Vex", "Luna", "Bolt", "Onyx", "Pike", "Sable", "Wren", "Drax", "Isla", "Cruz", "Fenix", "Gale", "Hawk", "Ivy", "Jett"]
        var id = 0
        for t in 0..<TowerEngine.teams {
            let f = t == 0 ? 0 : Int(rng.f() * 5.99)
            let base = m.spawns[f].isEmpty ? CGPoint(x: 800, y: 500) : m.spawns[f][(t * 7) % m.spawns[f].count]
            for k in 0..<TowerEngine.per {
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
        for f in 0..<TowerMap.nF {
            for p in m.loot[f] {
                let r = rng.f()
                var l = TwLoot(f: f, p: p, kind: 0, gun: "pistol", rar: 0)
                if r < 0.30 {
                    l.kind = 0
                    let g = rng.f()
                    let hi = CGFloat(f) / 5
                    l.gun = g < 0.2 ? "pistol" : g < 0.5 ? "smg" : g < 0.8 ? "rifle" : "shotgun"
                    let rr = rng.f() + hi * 0.35
                    l.rar = rr > 1.15 ? 3 : rr > 0.85 ? 2 : rr > 0.5 ? 1 : 0
                } else if r < 0.55 { l.kind = 1 } else if r < 0.75 { l.kind = 2 } else if r < 0.9 { l.kind = 3 } else { l.kind = 4 }
                loot.append(l)
            }
        }
        // zone plan
        finalFloor = Int(rng.f() * 5.99)
        gasOrder = (0..<TowerMap.nF).filter { $0 != finalFloor }
        for i in stride(from: gasOrder.count - 1, to: 0, by: -1) { gasOrder.swapAt(i, Int(rng.f() * CGFloat(i + 1)) % (i + 1)) }
        let c = map.rooms[finalFloor].randomElement()?.r ?? CGRect(x: 700, y: 400, width: 100, height: 100)
        circle = CGPoint(x: c.midX, y: c.midY)
        banner = "SQUAD DEPLOYED  -  LOOT UP AND HOLD THE SPIRE"
        bannerT = 4
        // bot mates start with a rifle so they are useful
        for a in actors where a.team == 0 && !a.isMe { a.slots[1] = TwGun(id: "smg", rar: 0, mag: 30, res: 90) }
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
        updateZone(dt)
        updateDoors(dt)
        var rep = 0
        for a in actors where a.alive {
            if a.isMe { updateMe(a, dt) } else { updateBot(a, dt, &rep) }
            if gasActive(a) {
                let dmg = (3 + CGFloat(stage) * 1.5) * dt
                hurt(a, dmg, by: nil, head: false, silent: true)
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
                banner = "FLOOR \(warnFloor + 1) \(TowerMap.names[warnFloor]) SEALING IN 12s"
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
            circleR = max(60, circleR - dt * 7)
        }
    }

    func updateDoors(_ dt: CGFloat) {
        for f in 0..<TowerMap.nF {
            for i in map.doors[f].indices {
                let c = CGPoint(x: map.doors[f][i].r.midX, y: map.doors[f][i].r.midY)
                var near = false
                for a in actors where a.alive && a.f == f {
                    if abs(a.p.x - c.x) < 62 && abs(a.p.y - c.y) < 62 { near = true; break }
                }
                var d = map.doors[f][i]
                if near { d.open = min(1, d.open + dt * 5); d.hold = 0.5 } else {
                    d.hold -= dt
                    if d.hold <= 0 { d.open = max(0, d.open - dt * 3) }
                }
                map.doors[f][i] = d
            }
        }
        map.refreshBlockers()
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
        moveActor(a, move, 150, dt)
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
            tracers.append(TwTracer(a: origin, b: end, f: a.f, t: 0.07, hot: g.rar > 0))
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
            if e.isMe { onMeDead() }
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
            place = teamsLeft + 1
            finish(false)
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

    func nearStairUp(_ a: TwActor) -> Bool { a.f < TowerMap.nF - 1 && TowerMap.stairW.insetBy(dx: -6, dy: -6).contains(a.p) }
    func nearStairDown(_ a: TwActor) -> Bool { a.f > 0 && TowerMap.stairE.insetBy(dx: -6, dy: -6).contains(a.p) }
    func nearElev(_ a: TwActor) -> Bool { TowerMap.elevs.contains { $0.insetBy(dx: -8, dy: -8).contains(a.p) } }

    func go(_ a: TwActor, to f: Int) {
        guard f >= 0, f < TowerMap.nF, f != a.f else { return }
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

        // target
        var tgt: TwActor? = a.target >= 0 && a.target < actors.count ? actors[a.target] : nil
        if let t = tgt, !(t.alive && t.f == a.f && t.team != a.team && map.los(a.f, a.p, t.p)) { tgt = nil }
        if tgt == nil {
            var bd: CGFloat = 520
            for e in actors where e.alive && e.team != a.team && e.f == a.f {
                let d = hypot(e.p.x - a.p.x, e.p.y - a.p.y)
                if d < bd && map.los(a.f, a.p, e.p) { bd = d; tgt = e }
            }
            a.target = tgt?.id ?? -1
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
            if hypot(a.p.x - a.lastP.x, a.p.y - a.lastP.y) < 12 { a.goal = nil; a.path = []; a.repath = 0; a.think = 0 }
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
            let safe = (0..<TowerMap.nF).filter { !gassed.contains($0) && $0 != warnFloor }
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
