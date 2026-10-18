import SwiftUI

struct BRSlot {
    var gun: String
    var mag: Int
    var reserve: Int
}

struct BRLoot {
    var p: CGPoint
    var kind: Int      // 0 gun, 1 ammo, 2 armor, 3 medkit, 4 cash
    var gun: String
    var amt: Int
    var taken = false
}

struct BRPart {
    var kind: Int      // 0 smoke, 1 casing
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var max: CGFloat
    var rot: CGFloat
}

final class BRActor {
    let id: Int
    var name: String
    var p: CGPoint
    var ang: CGFloat
    var hp: CGFloat = 100
    var armor: CGFloat = 0
    var alive = true
    var isMe = false
    var slots: [BRSlot?] = [nil, nil]
    var cur = 0
    var cd: CGFloat = 0
    var reloadT: CGFloat = 0
    var flash: CGFloat = 0
    var hurt: CGFloat = 0
    var ping: CGFloat = 0
    var kills = 0
    var place = 0
    var think: CGFloat = 0
    var react: CGFloat = 0
    var reactTime: CGFloat = 0.5
    var skill: CGFloat = 0.7
    var tgt: BRActor?
    var dest: CGPoint
    var stuck: CGFloat = 0
    var avoidT: CGFloat = 0
    var avoidDir: CGFloat = 0
    var stance = 0          // 0 stand 1 crouch 2 prone
    var stride: CGFloat = 0
    var spd: CGFloat = 0
    var sprinting = false
    var diveT: CGFloat = 0
    var diveCD: CGFloat = 0
    var stanceT: CGFloat = 0
    var color: BRCol
    var team = 0
    var cash = 0

    init(id: Int, name: String, p: CGPoint, ang: CGFloat, color: BRCol) {
        self.id = id
        self.name = name
        self.p = p
        self.ang = ang
        self.dest = p
        self.color = color
    }
}

final class BREngine {
    let world = BRWorld.shared
    static let eyeH: CGFloat = 54

    var actors: [BRActor] = []
    var loot: [BRLoot] = []
    var time: CGFloat = 0
    var last: Date? = nil
    var paused = false
    var over = false
    var won = false
    var deadT: CGFloat = 0
    var feed: [(String, CGFloat)] = []
    var toast: (String, CGFloat) = ("", 0)

    // controls
    var move = CGVector.zero
    var look: CGFloat = 0
    var lookIdle: CGFloat = 1
    var firing = false
    var crouch = false
    var prone = false
    var fps: CGFloat = 60
    var sprintT: CGFloat = 0
    var eyeNow: CGFloat = 54
    var camDip: CGFloat = 0
    var plates = 2
    var plateT: CGFloat = 0
    var plateBank: CGFloat = 0
    var bobScale: CGFloat = 1
    var diveDir: CGFloat = 0
    var proneBlend: CGFloat = 0
    var autoAim = true

    // player stats
    var cash = 0
    var meds = 1
    var kills = 0
    var hitT: CGFloat = 0
    var bobT: CGFloat = 0
    var bobAmp: CGFloat = 0
    var healCD: CGFloat = 0
    var lockT: BRActor?

    // view state
    var ads = false
    var adsT: CGFloat = 0
    var curFov: CGFloat = 1.25
    var pitch: CGFloat = 0
    var lookY: CGFloat = 0
    var recoilP: CGFloat = 0
    var gunKick: CGFloat = 0
    var shotFlag = false
    var tracerT: CGFloat = 0
    var lastDT: CGFloat = 0.016
    var parts: [BRPart] = []
    var floorBuf = [UInt8](repeating: 0, count: 170 * 70 * 4)

    // zone
    static let radii: [CGFloat] = [3000, 1800, 1000, 520, 220, 40]
    static let hold: CGFloat = 35
    static let shrink: CGFloat = 30
    static let dps: [CGFloat] = [1.5, 3, 5, 8, 12]
    var centers: [CGPoint] = []
    var zoneC = CGPoint(x: 3100, y: 2900)
    var zoneR: CGFloat = 3000
    var nextC = CGPoint(x: 3100, y: 2900)
    var nextR: CGFloat = 1800
    var stage = 0
    var zoneLabel = ""

    var me: BRActor { actors[0] }
    var aliveCount: Int { actors.filter { $0.alive }.count }

    private let botNames = ["Vex", "Ronin", "Kestrel", "Mako", "Sable", "Onyx", "Rook", "Tango", "Havoc", "Nova", "Wraith", "Cinder", "Blitz", "Echo", "Fang", "Ghost", "Jinx", "Kilo", "Lynx", "Moxie", "Nitro", "Orbit", "Pike", "Quill", "Raven", "Slate", "Talon", "Umbra", "Viper"]

    // MARK: setup

    func setup(name: String) {
        var rng = BRRand(s: UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFFFFF)
        centers = [CGPoint(x: 3100, y: 2900)]
        for i in 1..<BREngine.radii.count {
            let prev = centers[i - 1]
            let maxOff = (BREngine.radii[i - 1] - BREngine.radii[i]) * 0.75
            let a = rng.r(0, 2 * .pi)
            let d = rng.r(0, maxOff)
            centers.append(CGPoint(x: prev.x + cos(a) * d, y: prev.y + sin(a) * d))
        }
        actors = []
        let pal: [BRCol] = [(0.75, 0.2, 0.2), (0.2, 0.4, 0.75), (0.85, 0.6, 0.15), (0.3, 0.6, 0.35), (0.55, 0.3, 0.7), (0.2, 0.6, 0.65)]
        let m = BRActor(id: 0, name: name, p: spawnPoint(), ang: rng.r(-.pi, .pi), color: (0.9, 0.9, 0.2))
        m.isMe = true
        m.team = 0
        m.slots[0] = BRSlot(gun: "pistol", mag: 15, reserve: 45)
        actors.append(m)
        for i in 1..<30 {
            var p = spawnPoint()
            var tries = 0
            while tries < 20 && actors.contains(where: { hypot($0.p.x - p.x, $0.p.y - p.y) < 350 }) {
                p = spawnPoint()
                tries += 1
            }
            let b = BRActor(id: i, name: botNames[(i - 1) % botNames.count], p: p, ang: rng.r(-.pi, .pi), color: pal[i % pal.count])
            let roll = rng.f()
            let gid = roll < 0.2 ? "pistol" : (roll < 0.55 ? "smg" : (roll < 0.85 ? "rifle" : "shotgun"))
            let g = BRGuns.def(gid)
            b.slots[0] = BRSlot(gun: gid, mag: g.mag, reserve: g.mag * 3)
            b.skill = rng.r(0.4, 0.9)
            b.reactTime = rng.r(0.35, 0.8)
            b.armor = rng.f() > 0.6 ? 50 : 0
            b.dest = p
            b.team = i / 4
            actors.append(b)
        }
        // loot
        loot = []
        for s in world.spots {
            if rng.f() < 0.75 { loot.append(makeLoot(&rng, s)) }
        }
        for _ in 0..<50 {
            let p = spawnPoint()
            loot.append(makeLoot(&rng, p))
        }
        updateZone()
        showToast("BATTLE ROYALE  -  30 PLAYERS")
    }

    private func makeLoot(_ rng: inout BRRand, _ p: CGPoint) -> BRLoot {
        let j = CGPoint(x: p.x + rng.r(-25, 25), y: p.y + rng.r(-25, 25))
        let r = rng.f()
        if r < 0.35 {
            let g = rng.f()
            let id = g < 0.1 ? "pistol" : (g < 0.4 ? "smg" : (g < 0.75 ? "rifle" : "shotgun"))
            return BRLoot(p: j, kind: 0, gun: id, amt: 0)
        }
        if r < 0.55 { return BRLoot(p: j, kind: 1, gun: "", amt: 40) }
        if r < 0.70 { return BRLoot(p: j, kind: 2, gun: "", amt: 50) }
        if r < 0.82 { return BRLoot(p: j, kind: 3, gun: "", amt: 1) }
        return BRLoot(p: j, kind: 4, gun: "", amt: 50 + Int(rng.f() * 5) * 50)
    }

    func spawnPoint() -> CGPoint {
        for _ in 0..<80 {
            let a = CGFloat.random(in: 0...(2 * .pi))
            let d = CGFloat.random(in: 0...2700)
            let p = CGPoint(x: 3100 + cos(a) * d, y: 2900 + sin(a) * d)
            if BRWorld.water(p) { continue }
            if world.insideBuilding(p, pad: 40) { continue }
            return p
        }
        return CGPoint(x: 3000, y: 2000)
    }

    func showToast(_ s: String) { toast = (s, 2.2) }

    // MARK: frame

    func step(_ d: Date) {
        guard let l = last else { last = d; return }
        var dt = CGFloat(d.timeIntervalSince(l))
        last = d
        dt = min(max(dt, 0), 0.05)
        if paused || over || dt <= 0 || actors.isEmpty { return }
        time += dt
        lastDT = dt
        if dt > 0 { fps += (1 / dt - fps) * 0.05 }
        updateZone()
        updateMe(dt)
        for a in actors where !a.isMe && a.alive { updateBot(a, dt) }
        for a in actors { tickActor(a, dt) }
        zoneDamage(dt)
        feed = feed.filter { time - $0.1 < 5 }
        if toast.1 > 0 { toast.1 -= dt }
        if hitT > 0 { hitT -= dt }
        if healCD > 0 { healCD -= dt }
        checkEnd(dt)
    }

    private func tickActor(_ a: BRActor, _ dt: CGFloat) {
        a.cd = max(0, a.cd - dt)
        a.flash = max(0, a.flash - dt)
        a.hurt = max(0, a.hurt - dt * 2)
        a.ping = max(0, a.ping - dt)
        if a.reloadT > 0 {
            a.reloadT -= dt
            if a.reloadT <= 0 {
                a.reloadT = 0
                if var s = a.slots[a.cur] {
                    let g = BRGuns.def(s.gun)
                    let need = g.mag - s.mag
                    let take = min(need, s.reserve)
                    s.mag += take
                    s.reserve -= take
                    a.slots[a.cur] = s
                }
            }
        }
    }

    func updateZone() {
        let cyc = BREngine.hold + BREngine.shrink
        let last = BREngine.radii.count - 2
        var s = Int(time / cyc)
        var local = time - CGFloat(s) * cyc
        if s > last { s = last; local = cyc }
        stage = s
        let c0 = centers[s], c1 = centers[s + 1]
        let r0 = BREngine.radii[s], r1 = BREngine.radii[s + 1]
        nextC = c1
        nextR = r1
        if local < BREngine.hold {
            zoneC = c0
            zoneR = r0
            let rem = Int(BREngine.hold - local)
            zoneLabel = "ZONE CLOSES  " + clockString(rem)
        } else {
            let k = min(1, (local - BREngine.hold) / BREngine.shrink)
            zoneC = CGPoint(x: c0.x + (c1.x - c0.x) * k, y: c0.y + (c1.y - c0.y) * k)
            zoneR = r0 + (r1 - r0) * k
            zoneLabel = k >= 1 && s == last ? "FINAL ZONE" : "ZONE CLOSING"
        }
    }

    private func zoneDamage(_ dt: CGFloat) {
        let dps = BREngine.dps[min(stage, BREngine.dps.count - 1)]
        for a in actors where a.alive {
            if hypot(a.p.x - zoneC.x, a.p.y - zoneC.y) > zoneR {
                a.hp -= dps * dt
                if a.isMe { a.hurt = max(a.hurt, 0.5) }
                if a.hp <= 0 { eliminate(a, by: nil) }
            }
        }
    }

    private func checkEnd(_ dt: CGFloat) {
        if !me.alive {
            deadT += dt
            if deadT > 2.2 {
                over = true
                won = false
            }
        } else if !actors.contains(where: { $0.alive && $0.team != 0 }) {
            over = true
            won = true
            me.place = 1
        }
    }

    // MARK: player

    func outsideZone() -> Bool { hypot(me.p.x - zoneC.x, me.p.y - zoneC.y) > zoneR }

    private func updateMe(_ dt: CGFloat) {
        let m = me
        guard m.alive else { return }
        let sens: CGFloat = 0.0062 * (1 - 0.6 * adsT)
        m.ang += look * sens
        pitch = max(-0.45, min(0.45, pitch - lookY * sens))
        if abs(look) > 0.4 || abs(lookY) > 0.4 { lookIdle = 0 } else { lookIdle += dt }
        look = 0
        lookY = 0
        let wantAds = ads && m.slots[m.cur] != nil
        adsT += ((wantAds ? 1 : 0) - adsT) * min(1, dt * 12)
        let zoomFov = BRGuns.def(m.slots[m.cur]?.gun ?? "pistol").zoom
        curFov = 1.25 + (zoomFov - 1.25) * adsT
        recoilP -= recoilP * min(1, dt * 7)
        gunKick = max(0, gunKick - dt * 9)
        tracerT = max(0, tracerT - dt)
        var fwd = -move.dy
        var str = move.dx
        let mag = hypot(fwd, str)
        if mag > 1 { fwd /= mag; str /= mag }
        let moving = min(1, mag)
        // stance
        let wantSprint = mag > 0.93 && fwd > 0.6 && !firing && !ads && !crouch && !prone && m.reloadT <= 0 && plateT <= 0
        m.sprinting = wantSprint
        if m.diveT > 0 { m.diveT -= dt }
        m.stance = prone ? 2 : (crouch ? 1 : 0)
        sprintT += ((wantSprint ? 1 : 0) - sprintT) * min(1, dt * 9)
        proneBlend += ((prone ? 1 : 0) - proneBlend) * min(1, dt * 7)
        var tgtEye: CGFloat = prone ? 20 : (crouch ? 40 : 54)
        if m.diveT > 0 { tgtEye = 26 }
        eyeNow += (tgtEye - eyeNow) * min(1, dt * 10)
        var speed: CGFloat = prone ? 55 : (crouch ? 105 : (mag < 0.55 ? 120 : (wantSprint ? 290 : 200)))
        speed *= (1 - 0.4 * adsT)
        if plateT > 0 { speed *= 0.6 }
        var ca = cos(m.ang), sa = sin(m.ang)
        var mdx = (ca * fwd - sa * str) * speed * dt
        var mdy = (sa * fwd + ca * str) * speed * dt
        var camTarget: CGFloat = 0
        if m.diveT > 0 {
            let k = m.diveT / 0.7
            let v = 150 + 260 * k
            ca = cos(diveDir); sa = sin(diveDir)
            mdx = ca * v * dt
            mdy = sa * v * dt
            camTarget = sin(k * .pi) * 0.16
            if m.diveT <= dt { prone = true; crouch = false; showToast("PRONE") }
        }
        camDip += (camTarget - camDip) * min(1, dt * 12)
        walk(m, mdx, mdy)
        m.spd = hypot(mdx, mdy) / max(dt, 0.0001)
        let rate: CGFloat = m.diveT > 0 ? 0 : (prone ? 4 : (crouch ? 7 : (wantSprint ? 15 : (mag < 0.55 ? 8 : 11))))
        bobAmp += (moving - bobAmp) * min(1, dt * 8)
        bobT += dt * rate * moving
        m.stride += dt * rate * moving
        bobScale = prone ? 0.45 : (wantSprint ? 1.9 : (mag < 0.55 ? 0.7 : 1))
        // plate application
        if plateT > 0 {
            if m.sprinting || m.diveT > 0 || m.armor >= 100 { plateT = 0 }
            else {
                plateT += dt / 1.6
                if plateT >= 1 {
                    plateT = 0
                    m.armor = min(100, m.armor + 33.4)
                    plates -= 1
                    showToast("ARMOR APPLIED")
                }
            }
        }
        if let s = m.slots[m.cur] {
            let g = BRGuns.def(s.gun)
            let t = pickTarget(m, cone: 0.9)
            lockT = t
            var wantFire = firing
            if autoAim, let t = t {
                let want = atan2(t.p.y - m.p.y, t.p.x - m.p.x)
                let diff = brWrap(want - m.ang)
                if lookIdle > 0.4 || firing {
                    m.ang += max(-6 * dt, min(6 * dt, diff))
                }
                if abs(diff) < 0.09 { wantFire = true }
            }
            if wantFire {
                let extra = (prone ? 0.4 : (crouch ? 0.6 : 1.0)) * (moving > 0.2 ? (wantSprint ? 0.03 : 0.02) : 0) * (1 - 0.6 * adsT)
                fire(m, extra: extra)
            }
            _ = g
        } else {
            lockT = nil
        }
        pickups(m)
    }

    func walk(_ a: BRActor, _ dx: CGFloat, _ dy: CGFloat) {
        var q = a.p
        let nx = CGPoint(x: q.x + dx, y: q.y)
        if !BRWorld.water(nx) { q = nx }
        let ny = CGPoint(x: q.x, y: q.y + dy)
        if !BRWorld.water(ny) { q = ny }
        a.p = world.push(q, 14)
    }

    private func pickups(_ m: BRActor) {
        for i in loot.indices where !loot[i].taken {
            if hypot(loot[i].p.x - m.p.x, loot[i].p.y - m.p.y) > 38 { continue }
            let it = loot[i]
            switch it.kind {
            case 0:
                if let k = m.slots.firstIndex(where: { $0?.gun == it.gun }) {
                    m.slots[k]?.reserve += BRGuns.def(it.gun).mag
                    showToast("AMMO  +\(BRGuns.def(it.gun).mag)")
                } else {
                    let g = BRGuns.def(it.gun)
                    let idx = m.slots[1] == nil ? 1 : m.cur
                    m.slots[idx] = BRSlot(gun: it.gun, mag: g.mag, reserve: g.mag * 2)
                    m.cur = idx
                    m.reloadT = 0
                    showToast("PICKED UP  " + g.name)
                }
            case 1:
                for k in 0..<2 where m.slots[k] != nil { m.slots[k]?.reserve += it.amt }
                showToast("AMMO  +\(it.amt)")
            case 2:
                if plates >= 5 { continue }
                plates += 1
                showToast("ARMOR PLATE  +1")
            case 3:
                meds += 1
                showToast("MED KIT")
            default:
                cash += it.amt
                showToast("$\(it.amt)")
            }
            loot[i].taken = true
        }
    }

    func doReload() { reload(me) }

    func swapGun() {
        let n = 1 - me.cur
        if me.slots[n] != nil && me.alive {
            me.cur = n
            me.reloadT = 0
            me.cd = 0.25
        }
    }

    func applyPlate() {
        guard me.alive, plates > 0, me.armor < 99.9, plateT <= 0, me.diveT <= 0 else { return }
        plateT = 0.001
    }

    func setProne() {
        guard me.alive, me.diveT <= 0 else { return }
        if me.sprinting && !prone {
            me.diveT = 0.7
            diveDir = me.ang
            crouch = false
            ads = false
            return
        }
        prone.toggle()
        if prone { crouch = false }
    }

    func heal() {
        guard me.alive, meds > 0, me.hp < 100, healCD <= 0 else { return }
        meds -= 1
        me.hp = min(100, me.hp + 50)
        healCD = 1.5
        showToast("HEALED")
    }

    // MARK: combat

    func pickTarget(_ a: BRActor, cone: CGFloat) -> BRActor? {
        guard let s = a.slots[a.cur] else { return nil }
        let g = BRGuns.def(s.gun)
        var best: BRActor? = nil
        var bd: CGFloat = 99999
        for b in actors where b.alive && b !== a && b.team != a.team {
            let d = hypot(b.p.x - a.p.x, b.p.y - a.p.y)
            if d > g.range * 0.9 || d >= bd { continue }
            let rel = abs(brWrap(atan2(b.p.y - a.p.y, b.p.x - a.p.x) - a.ang))
            if rel > cone { continue }
            if !world.los(a.p, b.p) { continue }
            best = b
            bd = d
        }
        return best
    }

    func reload(_ a: BRActor) {
        guard let s = a.slots[a.cur], a.reloadT <= 0, s.reserve > 0 else { return }
        if s.mag >= BRGuns.def(s.gun).mag { return }
        a.reloadT = BRGuns.def(s.gun).reload
    }

    func fire(_ a: BRActor, extra: CGFloat) {
        guard a.alive, a.cd <= 0, a.reloadT <= 0, let s = a.slots[a.cur] else { return }
        if s.mag <= 0 {
            reload(a)
            return
        }
        let g = BRGuns.def(s.gun)
        a.slots[a.cur]?.mag -= 1
        a.cd = g.rate
        a.flash = 0.07
        a.ping = 1.6
        if a.isMe {
            recoilP += g.kick * (1 - 0.35 * adsT)
            a.ang += CGFloat.random(in: -1...1) * g.kick * 0.25
            gunKick = 1
            shotFlag = true
            tracerT = 0.07
        }
        for _ in 0..<g.pellets {
            let off = CGFloat.random(in: -1...1) * (g.spread + extra) * (a.isMe ? (1 - 0.45 * adsT) : 1)
            shoot(a, a.ang + off, g)
        }
    }

    private func shoot(_ a: BRActor, _ ang: CGFloat, _ g: BRGunDef) {
        let dx = cos(ang), dy = sin(ang)
        let wd = world.rayDist(a.p, dx, dy, g.range)
        var best: BRActor? = nil
        var bt = wd
        for b in actors where b.alive && b !== a && b.team != a.team {
            let rx = b.p.x - a.p.x, ry = b.p.y - a.p.y
            let t = rx * dx + ry * dy
            if t < 0 || t > bt { continue }
            let perp = abs(rx * dy - ry * dx)
            if perp < (b.stance == 2 || b.diveT > 0 ? 8 : (b.stance == 1 ? 11 : 14)) {
                best = b
                bt = t
            }
        }
        if let b = best {
            damage(b, g.dmg * (1 - 0.45 * bt / g.range), by: a)
        }
    }

    private func damage(_ b: BRActor, _ dmg: CGFloat, by a: BRActor) {
        if b.isMe && time < 4 { return }
        var d = dmg
        if b.armor > 0 {
            let ab = min(b.armor, d * 0.5)
            b.armor -= ab
            d -= ab
        }
        b.hp -= d
        b.hurt = 1
        if a.isMe { hitT = 0.25 }
        if b.hp <= 0 { eliminate(b, by: a) }
    }

    private func eliminate(_ b: BRActor, by a: BRActor?) {
        guard b.alive else { return }
        b.alive = false
        b.hp = 0
        let others = Set(actors.filter { $0.alive && $0.team != b.team }.map { $0.team }).count
        b.place = others + 1
        if let a = a {
            a.kills += 1
            a.cash += 100
            if a.isMe {
                kills += 1
                cash += 100
            }
            feed.append((a.name + "  \u{25B8}  " + b.name, time))
        } else {
            feed.append((b.name + " was lost to the storm", time))
        }
        if let s = b.slots[b.cur] {
            loot.append(BRLoot(p: b.p, kind: 0, gun: s.gun, amt: 0))
        }
        loot.append(BRLoot(p: CGPoint(x: b.p.x + 14, y: b.p.y + 10), kind: 4, gun: "", amt: 100))
        if b.isMe { deadT = 0 }
    }

    // MARK: bots

    private func botTarget(_ a: BRActor) -> BRActor? {
        guard let s = a.slots[a.cur] else { return nil }
        let g = BRGuns.def(s.gun)
        var best: BRActor? = nil
        var bd = min(g.range * 1.1, 700)
        for b in actors where b.alive && b !== a && b.team != a.team {
            let d = hypot(b.p.x - a.p.x, b.p.y - a.p.y)
            if d >= bd { continue }
            if !world.los(a.p, b.p) { continue }
            best = b
            bd = d
        }
        return best
    }

    private func zonePoint() -> CGPoint {
        let a = CGFloat.random(in: 0...(2 * .pi))
        let d = CGFloat.random(in: 0...(max(30, zoneR * 0.5)))
        return CGPoint(x: zoneC.x + cos(a) * d, y: zoneC.y + sin(a) * d)
    }

    private func newDest(_ a: BRActor) {
        var best = zonePoint()
        for _ in 0..<6 {
            if let c = world.spots.randomElement(), hypot(c.x - zoneC.x, c.y - zoneC.y) < zoneR - 100 {
                best = c
                break
            }
        }
        a.dest = best
    }

    private func updateBot(_ a: BRActor, _ dt: CGFloat) {
        a.think -= dt
        if a.think <= 0 {
            a.think = CGFloat.random(in: 0.25...0.45)
            let old = a.tgt
            a.tgt = botTarget(a)
            if a.tgt != nil && a.tgt !== old { a.react = a.reactTime }
        }
        guard let s = a.slots[a.cur] else { return }
        let g = BRGuns.def(s.gun)
        if s.mag <= 0 && a.reloadT <= 0 { reload(a) }
        let outside = hypot(a.p.x - zoneC.x, a.p.y - zoneC.y) > zoneR - 60
        if let t = a.tgt, t.alive, !outside || hypot(t.p.x - a.p.x, t.p.y - a.p.y) < 250 {
            let want = atan2(t.p.y - a.p.y, t.p.x - a.p.x)
            let diff = brWrap(want - a.ang)
            a.ang += max(-5 * dt, min(5 * dt, diff))
            a.react -= dt
            let dist = hypot(t.p.x - a.p.x, t.p.y - a.p.y)
            if a.react <= 0 && abs(diff) < 0.2 {
                fire(a, extra: (1 - a.skill) * 0.09)
            }
            let fwd: CGFloat = dist > g.range * 0.55 ? 1 : (dist < g.range * 0.25 ? -0.6 : 0)
            let str = sin(time * 1.4 + CGFloat(a.id)) * 0.7
            let ca = cos(a.ang), sa = sin(a.ang)
            if a.diveT > 0 {
                a.diveT -= dt
                a.stance = 2
                walk(a, cos(a.ang) * 280 * (a.diveT / 0.6) * dt, sin(a.ang) * 280 * (a.diveT / 0.6) * dt)
                a.spd = 0
                return
            }
            a.diveCD -= dt
            if a.diveCD <= 0 && dist < 320 && dist > 120 && CGFloat.random(in: 0...1) < 0.01 {
                a.diveT = 0.6
                a.diveCD = 8
                return
            }
            a.stanceT -= dt
            if a.stanceT <= 0 {
                a.stanceT = CGFloat.random(in: 1.2...3)
                let r = CGFloat.random(in: 0...1)
                a.stance = dist > 260 && r < 0.3 ? 2 : (r < 0.65 ? 1 : 0)
            }
            let sp: CGFloat = a.stance == 2 ? 40 : (a.stance == 1 ? 80 : 120)
            a.sprinting = false
            a.spd = abs(fwd) + abs(str) > 0.05 ? sp : 0
            a.stride += dt * (a.spd > 0 ? 8 : 0)
            walk(a, (ca * fwd - sa * str) * sp * dt, (sa * fwd + ca * str) * sp * dt)
            return
        }
        a.tgt = nil
        a.stance = 0
        if a.team == 0 && me.alive && !outside {
            let dm = hypot(me.p.x - a.p.x, me.p.y - a.p.y)
            if dm > 200 {
                if hypot(a.dest.x - me.p.x, a.dest.y - me.p.y) > 260 {
                    a.dest = CGPoint(x: me.p.x + CGFloat.random(in: -120...120), y: me.p.y + CGFloat.random(in: -120...120))
                }
            } else {
                a.dest = a.p
                let want = atan2(me.p.y - a.p.y, me.p.x - a.p.x) + CGFloat(a.id % 3 - 1) * 0.8
                a.ang += max(-2 * dt, min(2 * dt, brWrap(want - a.ang)))
                return
            }
        }
        if outside && hypot(a.dest.x - zoneC.x, a.dest.y - zoneC.y) > zoneR - 100 { a.dest = zonePoint() }
        let dd = hypot(a.dest.x - a.p.x, a.dest.y - a.p.y)
        if dd < 70 || a.stuck > 1.6 {
            newDest(a)
            a.stuck = 0
        }
        var want = atan2(a.dest.y - a.p.y, a.dest.x - a.p.x)
        if a.stuck > 0.35 && a.avoidT <= 0 {
            a.avoidT = 0.8
            a.avoidDir = Bool.random() ? 1.4 : -1.4
        }
        if a.avoidT > 0 {
            a.avoidT -= dt
            want += a.avoidDir
        }
        let diff = brWrap(want - a.ang)
        a.ang += max(-4 * dt, min(4 * dt, diff))
        let far = dd > 400 || outside
        a.sprinting = far && abs(diff) < 0.6
        let sp: CGFloat = (abs(diff) < 1 ? (a.sprinting ? 235 : 145) : 40) * (outside ? 1.15 : 1)
        a.spd = sp
        a.stride += dt * (a.sprinting ? 14 : 9)
        let before = a.p
        walk(a, cos(a.ang) * sp * dt, sin(a.ang) * sp * dt)
        let moved = hypot(a.p.x - before.x, a.p.y - before.y)
        if moved < sp * dt * 0.3 { a.stuck += dt } else { a.stuck = max(0, a.stuck - dt) }
    }
}

extension Game {
    func battleRoyaleFinish(place: Int, kills: Int, gems: Int) {
        var st = s
        var d = st.ex.tac ?? TacData()
        if place == 1 {
            d.wins += 1
            d.rating += 25
        } else if place <= 5 {
            d.rating += 8
        } else {
            d.losses += 1
            d.rating = max(0, d.rating - 10)
        }
        d.kills += kills
        st.ex.tac = d
        st.ex.gems += gems
        gainXP(&st, place == 1 ? 50 : (place <= 5 ? 30 : 15))
        s = st
        showToast("+\(gems) gems")
    }
}
