import SwiftUI

// Battle royale systems: drop, vehicles, stations, throwables, pings, gulag, audio glue.
extension BREngine {
    // MARK: helpers

    func targetable(_ b: BRActor) -> Bool {
        b.alive && !b.air && !(b.isMe && phase != 0)
    }

    func smokeBlocks(_ a: CGPoint, _ b: CGPoint) -> Bool {
        for s in smokes where s.t > 0 {
            let rad: CGFloat = 78
            let dx = b.x - a.x, dy = b.y - a.y
            let l2 = dx * dx + dy * dy
            var k: CGFloat = l2 < 1 ? 0 : ((s.p.x - a.x) * dx + (s.p.y - a.y) * dy) / l2
            k = max(0, min(1, k))
            let cx = a.x + dx * k, cy = a.y + dy * k
            if hypot(s.p.x - cx, s.p.y - cy) < rad { return true }
        }
        return false
    }

    func sfx(_ n: String, at p: CGPoint? = nil, vol: Float = 1) {
        guard !actors.isEmpty else { return }
        guard let p = p else { BRAudio.shared.play(n, vol: vol); return }
        let m = me
        let d = hypot(p.x - m.p.x, p.y - m.p.y)
        if d > 950 { return }
        let fall = Float(pow(max(0, 1 - Double(d) / 950), 1.6))
        let rel = brWrap(atan2(p.y - m.p.y, p.x - m.p.x) - m.ang)
        BRAudio.shared.play(n, vol: vol * fall, pan: Float(sin(rel)))
    }

    // MARK: drop

    func jump() {
        guard phase == 1 else { return }
        phase = 2
        chute = false
        planeT = 0
        ads = false
        firing = false
        showToast("FREEFALL  -  PUSH FORWARD TO DIVE")
        sfx("chute", vol: 0.5)
    }

    func openChute() {
        guard phase == 2, !chute else { return }
        chute = true
        showToast("CHUTE DEPLOYED")
        sfx("chute", vol: 0.8)
    }

    func updateAir(_ dt: CGFloat) {
        let m = me
        if phase == 1 {
            planeT += dt
            let sp: CGFloat = 270
            m.p = CGPoint(x: planeS.x + planeD.dx * sp * planeT, y: planeS.y + planeD.dy * sp * planeT)
            alt = 900
            eyeNow = 54 + alt
            curFov = 1.25
            if sp * planeT > 6800 { jump() }
            return
        }
        let fwd = -move.dy
        let dive = fwd > 0.5
        let descent: CGFloat = chute ? 90 : (dive ? 400 : 270)
        let hs: CGFloat = chute ? 150 : (dive ? 330 : 110)
        alt -= descent * dt
        if !chute && alt < 300 { openChute() }
        let f = max(-0.4, min(1, fwd))
        let st = move.dx
        let ca = cos(m.ang), sa = sin(m.ang)
        m.p = CGPoint(x: max(60, min(5940, m.p.x + (ca * f - sa * st) * hs * dt)), y: max(60, min(5940, m.p.y + (sa * f + ca * st) * hs * dt)))
        pitch += ((chute ? -0.18 : -0.32) - pitch) * min(1, dt * 1.2)
        eyeNow = 54 + max(0, alt)
        curFov = 1.25 + (chute ? 0 : 0.12)
        bobAmp = 0
        if alt <= 0 { land() }
    }

    func land() {
        let m = me
        alt = 0
        phase = 0
        chute = false
        eyeNow = 54
        pitch = 0
        var tries = 0
        while BRWorld.water(m.p) && tries < 200 {
            tries += 1
            let dx = 3100 - m.p.x, dy = 2900 - m.p.y
            let d = max(1, hypot(dx, dy))
            m.p = CGPoint(x: m.p.x + dx / d * 40, y: m.p.y + dy / d * 40)
        }
        m.p = world.push(m.p, 14)
        landGrace = 2
        showToast("LANDED")
        sfx("step", vol: 0.8)
    }

    // MARK: vehicles

    func nearVehicle() -> Int? {
        guard inVeh < 0, phase == 0, me.alive, !gulagOn else { return nil }
        var best: Int? = nil
        var bd: CGFloat = 70
        for (i, v) in vehicles.enumerated() where v.hp > 0 {
            let d = hypot(v.p.x - me.p.x, v.p.y - me.p.y)
            if d < bd { bd = d; best = i }
        }
        return best
    }

    func nearStation() -> Bool {
        guard inVeh < 0, phase == 0, me.alive, !gulagOn else { return false }
        return stations.contains { hypot($0.p.x - me.p.x, $0.p.y - me.p.y) < 75 }
    }

    func enterVehicle() {
        guard let i = nearVehicle() else { return }
        inVeh = i
        ads = false
        firing = false
        crouch = false
        prone = false
        me.p = vehicles[i].p
        me.ang = vehicles[i].ang
        steer = 0
        showToast(vehicles[i].kind == 0 ? "JEEP" : "BOAT")
        sfx("pickup")
    }

    func exitVehicle() {
        guard inVeh >= 0 else { return }
        var v = vehicles[inVeh]
        v.speed = 0
        var spot = v.p
        if v.kind == 1 {
            var found = false
            var r: CGFloat = 50
            while r < 420 && !found {
                var a: CGFloat = 0
                while a < 2 * .pi {
                    let q = CGPoint(x: v.p.x + cos(a) * r, y: v.p.y + sin(a) * r)
                    if !BRWorld.water(q) && !world.insideBuilding(q, pad: 16) { spot = q; found = true; break }
                    a += 0.5
                }
                r += 40
            }
            if !found { showToast("NO LAND NEARBY"); return }
        } else {
            let q = CGPoint(x: v.p.x + cos(v.ang + .pi / 2) * 52, y: v.p.y + sin(v.ang + .pi / 2) * 52)
            if !BRWorld.water(q) && !world.insideBuilding(q, pad: 16) { spot = q }
        }
        vehicles[inVeh] = v
        inVeh = -1
        me.p = world.push(spot, 14)
    }

    func updateVehicle(_ dt: CGFloat) {
        let m = me
        guard inVeh >= 0, inVeh < vehicles.count else { inVeh = -1; return }
        var v = vehicles[inVeh]
        let maxS: CGFloat = v.kind == 0 ? 440 : 380
        let thr = -move.dy
        if thr > 0.1 { v.speed += 270 * min(1, thr) * dt }
        else if thr < -0.1 { v.speed -= 340 * min(1, -thr) * dt }
        else { v.speed -= v.speed * min(1, dt * 0.9) }
        v.speed = max(-120, min(maxS, v.speed))
        steer += (move.dx - steer) * min(1, dt * 8)
        v.ang += steer * 1.9 * (v.speed / maxS) * dt
        var np = CGPoint(x: v.p.x + cos(v.ang) * v.speed * dt, y: v.p.y + sin(v.ang) * v.speed * dt)
        var blocked = false
        if v.kind == 0 {
            if BRWorld.water(np) { blocked = true; np = v.p }
            else {
                let q = world.push(np, 24)
                if hypot(q.x - np.x, q.y - np.y) > 3 { blocked = true }
                np = q
            }
        } else if !BRWorld.water(np) || world.insideBuilding(np, pad: 10) {
            blocked = true
            np = v.p
        }
        if blocked {
            if abs(v.speed) > 150 {
                v.hp -= abs(v.speed) * 0.07
                shake = max(shake, 10)
                sfx("hurt", vol: 0.7)
            }
            v.speed *= -0.25
        }
        vehM += abs(v.speed) * dt
        v.p = np
        // run people over
        if abs(v.speed) > 140 {
            for b in actors where b.alive && !b.air && b.team != 0 && b.team != 99 {
                if hypot(b.p.x - np.x, b.p.y - np.y) < 34 {
                    damage(b, abs(v.speed) * 0.3, by: m)
                }
            }
        }
        m.p = v.p
        m.ang = v.ang
        eyeNow += (62 - eyeNow) * min(1, dt * 8)
        curFov += (1.25 + 0.16 * abs(v.speed) / maxS - curFov) * min(1, dt * 6)
        adsT = 0
        bobT += abs(v.speed) * dt * 0.05
        bobAmp = 0.25 * abs(v.speed) / maxS
        let tick = Int(time * 5)
        if tick != engTick {
            engTick = tick
            sfx("engine", vol: Float(0.15 + 0.35 * abs(v.speed) / maxS))
        }
        if v.hp <= 0 {
            vehicles[inVeh] = v
            let p = v.p
            inVeh = -1
            m.p = world.push(p, 14)
            blasts.append(BRBlast(p: p, t: 0.7, kind: 0))
            sfx("boom")
            m.hp -= 45
            m.hurt = 1
            if m.hp <= 0 { eliminate(m, by: nil) }
            return
        }
        vehicles[inVeh] = v
    }

    // MARK: stations

    func buy(_ id: Int) {
        guard nearStation() else { return }
        let costs = [300, 200, 250, 400, 150, 100]
        guard id >= 0 && id < costs.count else { return }
        if cash < costs[id] { showToast("NOT ENOUGH CASH"); return }
        switch id {
        case 0:
            guard let a = actors.first(where: { $0.team == 0 && !$0.isMe && !$0.alive && $0.team != 99 }) else { showToast("NO ONE TO REVIVE"); return }
            guard let st = stations.min(by: { hypot($0.p.x - me.p.x, $0.p.y - me.p.y) < hypot($1.p.x - me.p.x, $1.p.y - me.p.y) }) else { return }
            a.alive = true
            a.hp = 60
            a.armor = 0
            a.air = true
            a.landT = time + 4
            a.p = CGPoint(x: st.p.x + CGFloat.random(in: -50...50), y: st.p.y + CGFloat.random(in: -50...50))
            a.p = world.push(a.p, 14)
            a.dest = a.p
            a.slots = [BRSlot(gun: "pistol", mag: 15, reserve: 45), nil]
            a.cur = 0
            a.tgt = nil
            feed.append((a.name + " is being deployed", time))
        case 1: plates = min(5, plates + 3)
        case 2: uavT = 25
        case 3:
            let guns = ["rifle", "smg", "shotgun"]
            let gid = guns.randomElement() ?? "rifle"
            let g = BRGuns.def(gid)
            let p = me.p
            loot.append(BRLoot(p: CGPoint(x: p.x + 24, y: p.y), kind: 0, gun: gid, amt: 0, rar: 3))
            loot.append(BRLoot(p: CGPoint(x: p.x, y: p.y + 26), kind: 1, gun: "", amt: g.mag * 2))
            loot.append(BRLoot(p: CGPoint(x: p.x - 24, y: p.y), kind: 5, gun: "", amt: 1, att: 1))
            loot.append(BRLoot(p: CGPoint(x: p.x, y: p.y - 26), kind: 5, gun: "", amt: 1, att: 2))
            loot.append(BRLoot(p: CGPoint(x: p.x + 20, y: p.y - 30), kind: 5, gun: "", amt: 1, att: 3))
        case 4:
            frag += 1
            smokeN += 1
            flashN += 1
        default: meds += 1
        }
        cash -= costs[id]
        showToast("PURCHASED")
        sfx("pickup")
    }

    // MARK: throwables

    func cycleThrow() { thrSel = (thrSel + 1) % 3 }

    func throwCount(_ k: Int) -> Int { k == 0 ? frag : (k == 1 ? smokeN : flashN) }

    func throwNow() {
        guard me.alive, thrCD <= 0, phase == 0, inVeh < 0, me.diveT <= 0, throwCount(thrSel) > 0 else { return }
        if thrSel == 0 { frag -= 1 } else if thrSel == 1 { smokeN -= 1 } else { flashN -= 1 }
        throwNade(from: me, kind: thrSel, dist: -1)
        thrCD = 0.7
    }

    func throwNade(from a: BRActor, kind: Int, dist: CGFloat) {
        let sp: CGFloat, vz: CGFloat
        if dist > 0 { sp = dist / 0.95; vz = 200 } else { sp = 300; vz = 150 + max(-0.3, min(0.45, pitch)) * 350 }
        throwsA.append(BRThrow(kind: kind, x: a.p.x, y: a.p.y, z: 44, vx: cos(a.ang) * sp, vy: sin(a.ang) * sp, vz: vz, t: kind == 0 ? 2.4 : (kind == 1 ? 1.3 : 1.5), owner: a.id))
        sfx("throw", at: a.isMe ? nil : a.p, vol: 0.7)
    }

    func detonate(_ t: BRThrow) {
        let p = CGPoint(x: t.x, y: t.y)
        let owner = actors.first { $0.id == t.owner } ?? me
        switch t.kind {
        case 0:
            blasts.append(BRBlast(p: p, t: 0.55, kind: 0))
            sfx("boom", at: p)
            let md = hypot(p.x - me.p.x, p.y - me.p.y)
            if md < 500 { shake = max(shake, 16 * (1 - md / 500)) }
            for b in actors where b.alive && !b.air {
                let d = hypot(b.p.x - p.x, b.p.y - p.y)
                if d < 140 && world.los(p, b.p) {
                    if b.team == owner.team && b !== owner { continue }
                    let was = b.alive
                    damage(b, 160 * (1 - d / 140), by: owner)
                    if was && !b.alive && owner.isMe { nadeKills += 1 }
                }
            }
            for i in vehicles.indices where hypot(vehicles[i].p.x - p.x, vehicles[i].p.y - p.y) < 120 { vehicles[i].hp -= 60 }
        case 1:
            smokes.append(BRSmoke(p: p, t: 11))
            sfx("pop", at: p)
        default:
            blasts.append(BRBlast(p: p, t: 0.35, kind: 2))
            sfx("pop", at: p, vol: 1)
            let m = me
            let d = hypot(p.x - m.p.x, p.y - m.p.y)
            if d < 380 && m.alive && world.los(p, m.p) {
                let rel = abs(brWrap(atan2(p.y - m.p.y, p.x - m.p.x) - m.ang))
                if rel < 1.4 || d < 80 { flashT = max(flashT, 0.8 + 2.4 * (1 - d / 380)) }
            }
            for b in actors where !b.isMe && b.alive && !b.air && hypot(b.p.x - p.x, b.p.y - p.y) < 380 && world.los(p, b.p) { b.stun = 2.6 }
        }
    }

    // MARK: pings

    func ping() {
        guard me.alive, phase == 0, inVeh < 0 else { return }
        var p: CGPoint
        var kind = 0
        if let t = lockT {
            p = t.p
            kind = 1
        } else {
            let d = world.rayDist(me.p, cos(me.ang), sin(me.ang), 1400)
            p = CGPoint(x: me.p.x + cos(me.ang) * d, y: me.p.y + sin(me.ang) * d)
        }
        pings.append(BRPing(p: p, kind: kind, t: 14))
        if pings.count > 3 { pings.removeFirst() }
        sfx("ping")
        feed.append(("You pinged " + (kind == 1 ? "an enemy" : "a location"), time))
        if kind == 0 {
            for a in actors where a.team == 0 && !a.isMe && a.alive && !a.air { a.dest = p }
        }
        if let ally = actors.first(where: { $0.team == 0 && !$0.isMe && $0.alive && !$0.air }) {
            feed.append((ally.name + ": copy that", time))
        }
    }

    // MARK: gulag

    func canGulag() -> Bool {
        !gulagUsed && !gulagOn && phase == 0 && aliveCount > 6 && stage <= 2 && inVeh < 0
    }

    func startGulag() {
        let m = me
        gulagUsed = true
        gulagOn = true
        gulagT = 60
        gulagSaved = (m.slots, m.cur, m.armor, plates)
        let g = BRGuns.def("smg")
        m.slots = [BRSlot(gun: "smg", mag: g.mag, reserve: g.mag * 3), nil]
        m.cur = 0
        m.hp = 100
        m.armor = 0
        m.gulag = true
        m.reloadT = 0
        m.cd = 0.8
        m.diveT = 0
        plateT = 0
        m.p = BRWorld.gulagA
        m.ang = 0
        pitch = 0
        crouch = false
        prone = false
        ads = false
        m.hurt = 0
        let o = BRActor(id: 900, name: "GULAG", p: BRWorld.gulagB, ang: .pi, color: (0.9, 0.3, 0.3))
        o.team = 99
        o.gulag = true
        o.slots[0] = BRSlot(gun: "smg", mag: g.mag, reserve: g.mag * 3)
        o.skill = 0.6
        o.reactTime = 0.55
        o.react = 1.4
        o.dest = o.p
        actors.append(o)
        gulagOpp = o
        feed.append(("YOU WERE SENT TO THE GULAG", time))
        showToast("GULAG  -  WIN THE 1V1")
    }

    func restoreAfterGulag() {
        if let sv = gulagSaved {
            me.slots = sv.0
            me.cur = sv.1
            me.armor = sv.2
            plates = sv.3
            gulagSaved = nil
        }
    }

    func endGulag(win: Bool) {
        guard gulagOn else { return }
        gulagOn = false
        me.gulag = false
        gulagWins += 1
        restoreAfterGulag()
        me.hp = 100
        var p = zonePoint()
        var tries = 0
        while (BRWorld.water(p) || world.insideBuilding(p, pad: 30)) && tries < 40 { p = zonePoint(); tries += 1 }
        me.p = p
        me.ang = CGFloat.random(in: -.pi...(.pi))
        phase = 2
        alt = 520
        chute = true
        landGrace = 3
        feed.append((me.name + " won the gulag", time))
        showToast("REDEPLOYING")
        sfx("chute", vol: 0.7)
    }

    func updateGulagBot(_ a: BRActor, _ dt: CGFloat) {
        guard me.alive, let s = a.slots[a.cur] else { return }
        if s.mag <= 0 && a.reloadT <= 0 { reload(a) }
        let dx = me.p.x - a.p.x, dy = me.p.y - a.p.y
        let dist = hypot(dx, dy)
        let want = atan2(dy, dx)
        a.ang += max(-3.5 * dt, min(3.5 * dt, brWrap(want - a.ang)))
        a.react -= dt
        if a.react <= 0 && abs(brWrap(want - a.ang)) < 0.25 && world.los(a.p, me.p) {
            fire(a, extra: (1 - a.skill) * 0.1)
        }
        let fwd: CGFloat = dist > 230 ? 1 : (dist < 120 ? -0.7 : 0)
        let str = sin(time * 1.6) * 0.8
        let ca = cos(a.ang), sa = sin(a.ang)
        let sp: CGFloat = 105
        walk(a, (ca * fwd - sa * str) * sp * dt, (sa * fwd + ca * str) * sp * dt)
        a.spd = sp
        a.stride += dt * 8
        a.stance = 0
        a.sprinting = false
    }

    // MARK: per-frame

    func updateExtras(_ dt: CGFloat) {
        thrCD = max(0, thrCD - dt)
        landGrace = max(0, landGrace - dt)
        shake = max(0, shake - dt * 30)
        flashT = max(0, flashT - dt)
        uavT = max(0, uavT - dt)
        for i in nums.indices { nums[i].t -= dt }
        nums.removeAll { $0.t <= 0 }
        for i in pings.indices { pings[i].t -= dt }
        pings.removeAll { $0.t <= 0 }
        for i in smokes.indices { smokes[i].t -= dt }
        smokes.removeAll { $0.t <= -0.1 }
        for i in blasts.indices { blasts[i].t -= dt }
        blasts.removeAll { $0.t <= 0 }
        var keep: [BRThrow] = []
        for var t in throwsA {
            t.t -= dt
            t.vz -= 420 * dt
            let ox = t.x, oy = t.y
            t.x += t.vx * dt
            t.y += t.vy * dt
            t.z += t.vz * dt
            let dd = hypot(t.x - ox, t.y - oy)
            if dd > 0.01 {
                let hit = world.rayDist(CGPoint(x: ox, y: oy), (t.x - ox) / dd, (t.y - oy) / dd, dd + 4)
                if hit < dd + 3 {
                    t.x = ox
                    t.y = oy
                    t.vx *= -0.35
                    t.vy *= -0.35
                }
            }
            if t.z <= 0 {
                t.z = 0
                let bz = abs(t.vz) * 0.4
                t.vz = bz < 25 ? 0 : bz
                t.vx *= 0.7
                t.vy *= 0.7
            }
            if t.t <= 0 { detonate(t) } else { keep.append(t) }
        }
        throwsA = keep
        if gulagOn {
            gulagT -= dt
            if gulagT <= 0 {
                me.hp = 0
                eliminate(me, by: gulagOpp)
            }
        }
        if !me.alive && !gulagOn {
            if let k = killer, k !== me {
                let want = atan2(k.p.y - me.p.y, k.p.x - me.p.x)
                me.ang += brWrap(want - me.ang) * min(1, dt * 4)
            }
            eyeNow += (18 - eyeNow) * min(1, dt * 3)
        }
    }

    // MARK: end of match

    func settle() {
        let place = won ? 1 : (me.place == 0 ? 30 : me.place)
        let st = BRStats(kills: kills, heads: heads, place: place, won: won, plates: platesUsed, dives: dives, vehM: Int(vehM * 0.2), nadeKills: nadeKills, gulagWins: gulagWins, secs: Int(time))
        let r = BRMeta.record(st)
        contractGems = r.0
        contractLines = r.1
    }
}
