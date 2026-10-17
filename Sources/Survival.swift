import SwiftUI

// MARK: - Persisted progress

struct SurvData: Codable, Hashable {
    var best = 0
    var kills = 0
    var runs = 0
    var hp = 0
    var dmg = 0
    var spd = 0
    var mag = 0
    var loot = 0
    var guns: [String] = ["pistol"]
}

struct GunDef {
    let id: String
    let name: String
    let emoji: String
    let dmg: CGFloat
    let rate: CGFloat
    let mag: Int
    let reload: CGFloat
    let spread: CGFloat
    let pellets: Int
    let speed: CGFloat
    let range: CGFloat
    let price: Int
}

enum Guns {
    static let all: [GunDef] = [
        GunDef(id: "pistol", name: "Pistol", emoji: "🔫", dmg: 22, rate: 3.5, mag: 12, reload: 1.0, spread: 0.03, pellets: 1, speed: 900, range: 520, price: 0),
        GunDef(id: "smg", name: "SMG", emoji: "⚡️", dmg: 11, rate: 11, mag: 34, reload: 1.5, spread: 0.09, pellets: 1, speed: 950, range: 480, price: 80),
        GunDef(id: "shotgun", name: "Shotgun", emoji: "💥", dmg: 14, rate: 1.3, mag: 6, reload: 1.8, spread: 0.28, pellets: 7, speed: 800, range: 330, price: 140),
        GunDef(id: "rifle", name: "Rifle", emoji: "🎯", dmg: 48, rate: 2.6, mag: 20, reload: 1.6, spread: 0.015, pellets: 1, speed: 1300, range: 800, price: 220)
    ]
    static func get(_ id: String) -> GunDef { all.first { $0.id == id } ?? all[0] }
}

// MARK: - Engine

final class SurvivalEngine {
    struct Zed {
        var id: Int
        var pos: CGPoint
        var hp: CGFloat
        var maxHp: CGFloat
        var speed: CGFloat
        var r: CGFloat
        var kind: Int          // 0 walker, 1 runner, 2 tank, 3 spitter, 4 exploder, 5 boss
        var handle: String
        var name: String
        var emoji: String
        var color: Color
        var cd: CGFloat = 0
        var flash: CGFloat = 0
    }
    struct Bullet {
        var pos: CGPoint
        var vel: CGVector
        var dmg: CGFloat
        var life: CGFloat
        var mine: Bool
    }
    struct Pickup {
        var pos: CGPoint
        var kind: Int          // 0 ammo, 1 health, 2 gem
        var amt: Int
        var life: CGFloat
    }
    struct Pop {
        var pos: CGPoint
        var text: String
        var life: CGFloat
        var color: Color
    }
    struct Boom {
        var pos: CGPoint
        var life: CGFloat
        var r: CGFloat
    }

    let W: CGFloat = 2200
    let H: CGFloat = 2200
    var obstacles: [CGRect] = []
    var pos = CGPoint(x: 1100, y: 1100)
    var hp: CGFloat = 100
    var maxHp: CGFloat = 100
    var aim: CGFloat = 0
    var move = CGVector.zero
    var firing = false
    var zeds: [Zed] = []
    var bullets: [Bullet] = []
    var pickups: [Pickup] = []
    var pops: [Pop] = []
    var booms: [Boom] = []
    var wave = 0
    var kills = 0
    var runGems = 0
    var phase = 0              // 0 fighting, 1 resting, 2 dead
    var rest: CGFloat = 0
    var toSpawn = 0
    var spawnT: CGFloat = 0
    var night = false
    var paused = false
    var guns: [String] = ["pistol"]
    var gi = 0
    var mags: [String: Int] = [:]
    var reserve: [String: Int] = [:]
    var reloadT: CGFloat = 0
    var fireCd: CGFloat = 0
    var hurtT: CGFloat = 0
    var shake: CGFloat = 0
    var flashT: CGFloat = 0
    var time: CGFloat = 0
    var dmgMul: CGFloat = 1
    var spdMul: CGFloat = 1
    var magMul: CGFloat = 1
    var lootMul: CGFloat = 1
    var cast: [NPC] = []
    var sprite: UIImage? = nil
    var sprites: [String: UIImage] = [:]
    var last: Date? = nil
    var nextID = 0
    var banner = ""
    var bannerT: CGFloat = 0

    var gun: GunDef { Guns.get(guns[min(gi, guns.count - 1)]) }
    func magSize(_ g: GunDef) -> Int { max(1, Int(CGFloat(g.mag) * magMul)) }
    var curMag: Int { mags[gun.id] ?? magSize(gun) }
    var curReserve: Int { gun.id == "pistol" ? 999 : (reserve[gun.id] ?? 0) }

    func start(cast: [NPC], data: SurvData) {
        self.cast = cast
        maxHp = 100 + 15 * CGFloat(data.hp)
        hp = maxHp
        dmgMul = 1 + 0.08 * CGFloat(data.dmg)
        spdMul = 1 + 0.04 * CGFloat(data.spd)
        magMul = 1 + 0.10 * CGFloat(data.mag)
        lootMul = 1 + 0.10 * CGFloat(data.loot)
        guns = data.guns.isEmpty ? ["pistol"] : data.guns
        gi = 0
        mags = [:]
        reserve = [:]
        for g in guns { mags[g] = magSize(Guns.get(g)); if g != "pistol" { reserve[g] = Guns.get(g).mag * 2 } }
        pos = CGPoint(x: W / 2, y: H / 2)
        zeds = []; bullets = []; pickups = []; pops = []; booms = []
        wave = 0; kills = 0; runGems = 0; phase = 0; paused = false
        reloadT = 0; fireCd = 0; last = nil
        obstacles = []
        var tries = 0
        while obstacles.count < 28 && tries < 400 {
            tries += 1
            let w = CGFloat.random(in: 60...170), h = CGFloat.random(in: 60...170)
            let r = CGRect(x: CGFloat.random(in: 80...(W - 250)), y: CGFloat.random(in: 80...(H - 250)), width: w, height: h)
            if hypot(r.midX - W / 2, r.midY - H / 2) < 260 { continue }
            if obstacles.contains(where: { $0.insetBy(dx: -50, dy: -50).intersects(r) }) { continue }
            obstacles.append(r)
        }
        startWave()
    }

    func startWave() {
        wave += 1
        night = wave % 3 == 0
        phase = 0
        toSpawn = 5 + wave * 3 + (wave % 5 == 0 ? 1 : 0)
        spawnT = 1
        banner = (night ? "NIGHT " : "WAVE ") + "\(wave)"
        bannerT = 2.2
    }

    // collision against walls and bounds
    func push(_ p: inout CGPoint, _ r: CGFloat) {
        p.x = min(max(r, p.x), W - r)
        p.y = min(max(r, p.y), H - r)
        for o in obstacles {
            let cx = min(max(p.x, o.minX), o.maxX)
            let cy = min(max(p.y, o.minY), o.maxY)
            let dx = p.x - cx, dy = p.y - cy
            let d = (dx * dx + dy * dy).squareRoot()
            if d < r {
                if d > 0.001 { p.x += dx / d * (r - d); p.y += dy / d * (r - d) }
                else { p.x = o.minX - r }
            }
        }
    }

    func hurt(_ x: CGFloat) {
        guard phase != 2 else { return }
        hp -= x
        hurtT = 0.3
        shake = max(shake, 7)
        if hp <= 0 { hp = 0; phase = 2 }
    }

    func pop(_ p: CGPoint, _ t: String, _ c: Color = .white) {
        pops.append(Pop(pos: p, text: t, life: 1, color: c))
        if pops.count > 40 { pops.removeFirst() }
    }

    func step(_ now: Date) {
        guard let l = last else { last = now; return }
        let dt = min(0.05, CGFloat(now.timeIntervalSince(l)))
        last = now
        if paused || phase == 2 { return }
        update(dt)
    }

    func cycleGun() {
        guard guns.count > 1 else { return }
        gi = (gi + 1) % guns.count
        reloadT = 0
        fireCd = 0.15
        pop(CGPoint(x: pos.x, y: pos.y - 34), gun.name, .yellow)
    }

    func reload() {
        guard reloadT <= 0, curMag < magSize(gun), curReserve > 0 else { return }
        reloadT = gun.reload
    }

    private func finishReload() {
        let g = gun
        let need = magSize(g) - (mags[g.id] ?? 0)
        let take = g.id == "pistol" ? need : min(need, reserve[g.id] ?? 0)
        mags[g.id] = (mags[g.id] ?? 0) + take
        if g.id != "pistol" { reserve[g.id] = (reserve[g.id] ?? 0) - take }
    }

    private func shoot() {
        let g = gun
        for _ in 0..<g.pellets {
            let a = aim + CGFloat.random(in: -g.spread...g.spread)
            let v = CGVector(dx: cos(a) * g.speed, dy: sin(a) * g.speed)
            bullets.append(Bullet(pos: CGPoint(x: pos.x + cos(a) * 26, y: pos.y + sin(a) * 26), vel: v,
                                  dmg: g.dmg * dmgMul, life: g.range / g.speed, mine: true))
        }
        mags[g.id] = (mags[g.id] ?? magSize(g)) - 1
        fireCd = 1 / g.rate
        flashT = 0.05
        shake = max(shake, g.pellets > 1 ? 4 : 1.5)
    }

    private func makeZed() -> Zed {
        let boss = wave % 5 == 0 && !zeds.contains { $0.kind == 5 } && toSpawn == 1
        let n: NPC? = boss ? cast.max(by: { $0.followers < $1.followers }) : cast.randomElement()
        let handle = n?.handle ?? "crowd\(Int.random(in: 100...999))"
        let name = n?.name ?? "Random"
        let emoji = n?.emoji ?? "🧟"
        var kind = 0
        if boss { kind = 5 } else if let t = n?.trait {
            switch t {
            case .hater: kind = wave >= 2 ? 1 : 0
            case .mogul: kind = wave >= 3 ? 2 : 0
            case .gossip: kind = wave >= 2 ? 3 : 0
            case .chaos: kind = wave >= 2 ? 4 : 0
            default: kind = 0
            }
        }
        let w = CGFloat(wave)
        var hp: CGFloat = 40 + w * 7
        var sp: CGFloat = min(120, 70 + w * 2)
        var r: CGFloat = 15
        switch kind {
        case 1: hp = 26 + w * 5; sp = min(190, 130 + w * 3); r = 13
        case 2: hp = 130 + w * 18; sp = 48; r = 22
        case 3: hp = 34 + w * 6; sp = 62; r = 15
        case 4: hp = 38 + w * 6; sp = 100; r = 16
        case 5: hp = 600 + w * 120; sp = 58; r = 38
        default: break
        }
        if night { sp *= 1.2 }
        let a = CGFloat.random(in: 0..<(2 * .pi))
        let dist = CGFloat.random(in: 520...680)
        var p = CGPoint(x: pos.x + cos(a) * dist, y: pos.y + sin(a) * dist)
        push(&p, r)
        nextID += 1
        return Zed(id: nextID, pos: p, hp: hp, maxHp: hp, speed: sp, r: r, kind: kind, handle: handle, name: name, emoji: emoji,
                   color: HK.neon(handle), cd: CGFloat.random(in: 0...1.5))
    }

    private func explode(_ at: CGPoint, _ radius: CGFloat) {
        booms.append(Boom(pos: at, life: 0.4, r: radius))
        if hypot(pos.x - at.x, pos.y - at.y) < radius + 16 { hurt(22) }
        for i in zeds.indices where hypot(zeds[i].pos.x - at.x, zeds[i].pos.y - at.y) < radius { zeds[i].hp -= 60; zeds[i].flash = 0.15 }
        shake = max(shake, 9)
    }

    private func drop(_ z: Zed) {
        let r = Double.random(in: 0...1)
        if z.kind == 5 {
            pickups.append(Pickup(pos: z.pos, kind: 2, amt: 15, life: 40))
            pickups.append(Pickup(pos: CGPoint(x: z.pos.x + 24, y: z.pos.y), kind: 1, amt: 40, life: 40))
            pickups.append(Pickup(pos: CGPoint(x: z.pos.x - 24, y: z.pos.y), kind: 0, amt: 1, life: 40))
            return
        }
        if r < 0.10 { pickups.append(Pickup(pos: z.pos, kind: 1, amt: 20, life: 25)) }
        else if r < 0.28 { pickups.append(Pickup(pos: z.pos, kind: 0, amt: 1, life: 25)) }
        else if r < 0.28 + 0.5 * Double(lootMul) / 1.0 * 0.8 { pickups.append(Pickup(pos: z.pos, kind: 2, amt: z.kind == 2 ? 3 : 1, life: 25)) }
    }

    private func update(_ dt: CGFloat) {
        time += dt
        hurtT = max(0, hurtT - dt)
        shake = max(0, shake - dt * 28)
        flashT = max(0, flashT - dt)
        bannerT = max(0, bannerT - dt)
        // player
        let sp = 190 * spdMul
        pos.x += move.dx * sp * dt
        pos.y += move.dy * sp * dt
        push(&pos, 16)
        // weapon
        fireCd -= dt
        if reloadT > 0 {
            reloadT -= dt
            if reloadT <= 0 { finishReload() }
        } else if curMag <= 0 {
            if curReserve > 0 { reload() }
            else if gun.id != "pistol", let pi = guns.firstIndex(of: "pistol") { gi = pi; pop(CGPoint(x: pos.x, y: pos.y - 34), "OUT OF AMMO", .orange) }
        } else if firing && fireCd <= 0 {
            shoot()
        }
        // waves
        if phase == 0 {
            spawnT -= dt
            if toSpawn > 0 && spawnT <= 0 && zeds.count < 70 {
                zeds.append(makeZed())
                toSpawn -= 1
                spawnT = max(0.22, 1.1 - CGFloat(wave) * 0.04)
            }
            if toSpawn == 0 && zeds.isEmpty {
                phase = 1
                rest = 6
                runGems += wave * 2
                hp = min(maxHp, hp + maxHp * 0.25)
                for g in guns where g != "pistol" { reserve[g] = (reserve[g] ?? 0) + Guns.get(g).mag }
                banner = "WAVE \(wave) CLEARED"
                bannerT = 2.5
            }
        } else if phase == 1 {
            rest -= dt
            if rest <= 0 { startWave() }
        }
        // zombies
        var boomsAt: [(CGPoint, CGFloat)] = []
        for i in zeds.indices {
            var z = zeds[i]
            z.flash = max(0, z.flash - dt)
            z.cd -= dt
            let dx = pos.x - z.pos.x, dy = pos.y - z.pos.y
            let d = max(1, (dx * dx + dy * dy).squareRoot())
            var mv: CGFloat = 1
            if z.kind == 3 {
                if d < 200 { mv = -1 } else if d < 330 { mv = 0 }
                if d < 440 && z.cd <= 0 {
                    z.cd = 2.2
                    bullets.append(Bullet(pos: z.pos, vel: CGVector(dx: dx / d * 270, dy: dy / d * 270), dmg: 10, life: 2.4, mine: false))
                }
            }
            z.pos.x += dx / d * z.speed * mv * dt
            z.pos.y += dy / d * z.speed * mv * dt
            push(&z.pos, z.r)
            if d < z.r + 16 {
                if z.kind == 4 { z.hp = 0; boomsAt.append((z.pos, 90)) }
                else if z.cd <= 0 { hurt(z.kind == 5 ? 26 : (z.kind == 2 ? 18 : 12)); z.cd = 0.7 }
            }
            zeds[i] = z
        }
        // separation
        if zeds.count > 1 {
            for i in zeds.indices {
                for j in (i + 1)..<zeds.count {
                    let dx = zeds[j].pos.x - zeds[i].pos.x, dy = zeds[j].pos.y - zeds[i].pos.y
                    let d = (dx * dx + dy * dy).squareRoot()
                    let m = zeds[i].r + zeds[j].r
                    if d < m && d > 0.01 {
                        let k = (m - d) * 0.5
                        zeds[i].pos.x -= dx / d * k; zeds[i].pos.y -= dy / d * k
                        zeds[j].pos.x += dx / d * k; zeds[j].pos.y += dy / d * k
                    }
                }
            }
        }
        // bullets
        var keep: [Bullet] = []
        for var b in bullets {
            b.pos.x += b.vel.dx * dt
            b.pos.y += b.vel.dy * dt
            b.life -= dt
            if b.life <= 0 || obstacles.contains(where: { $0.contains(b.pos) }) || b.pos.x < 0 || b.pos.y < 0 || b.pos.x > W || b.pos.y > H { continue }
            if b.mine {
                var hit = false
                for i in zeds.indices {
                    let d = hypot(zeds[i].pos.x - b.pos.x, zeds[i].pos.y - b.pos.y)
                    if d < zeds[i].r + 4 {
                        zeds[i].hp -= b.dmg
                        zeds[i].flash = 0.08
                        zeds[i].pos.x += b.vel.dx * 0.01
                        zeds[i].pos.y += b.vel.dy * 0.01
                        hit = true
                        break
                    }
                }
                if hit { continue }
            } else if hypot(pos.x - b.pos.x, pos.y - b.pos.y) < 20 {
                hurt(b.dmg)
                continue
            }
            keep.append(b)
        }
        bullets = keep
        // deaths
        var alive: [Zed] = []
        for z in zeds {
            if z.hp <= 0 {
                kills += 1
                if z.kind == 4 && !boomsAt.contains(where: { $0.0 == z.pos }) { boomsAt.append((z.pos, 90)) }
                drop(z)
                if z.kind == 5 { pop(z.pos, "\(z.name) is DOWN", .yellow) }
            } else { alive.append(z) }
        }
        zeds = alive
        for b in boomsAt { explode(b.0, b.1) }
        // pickups
        var left: [Pickup] = []
        for var p in pickups {
            p.life -= dt
            if p.life <= 0 { continue }
            let d = hypot(pos.x - p.pos.x, pos.y - p.pos.y)
            if d < 110 {
                p.pos.x += (pos.x - p.pos.x) / max(1, d) * 320 * dt
                p.pos.y += (pos.y - p.pos.y) / max(1, d) * 320 * dt
            }
            if d < 26 {
                switch p.kind {
                case 1:
                    hp = min(maxHp, hp + CGFloat(p.amt))
                    pop(pos, "+\(p.amt) HP", Color(red: 0.4, green: 0.95, blue: 0.5))
                case 2:
                    runGems += p.amt
                    pop(pos, "+\(p.amt) 💎", .cyan)
                default:
                    let others = guns.filter { $0 != "pistol" }
                    if let g = (gun.id != "pistol" ? gun.id : others.randomElement()) {
                        reserve[g] = (reserve[g] ?? 0) + Guns.get(g).mag
                        pop(pos, "+AMMO", .yellow)
                    } else { runGems += 1; pop(pos, "+1 💎", .cyan) }
                }
                continue
            }
            left.append(p)
        }
        pickups = left
        // effects
        for i in booms.indices { booms[i].life -= dt }
        booms.removeAll { $0.life <= 0 }
        for i in pops.indices { pops[i].life -= dt * 1.1 }
        pops.removeAll { $0.life <= 0 }
    }

    // MARK: drawing

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let camX = min(max(0, pos.x - size.width / 2), max(0, W - size.width))
        let camY = min(max(0, pos.y - size.height / 2), max(0, H - size.height))
        var w = ctx
        let sx = shake > 0 ? CGFloat.random(in: -shake...shake) * 0.5 : 0
        let sy = shake > 0 ? CGFloat.random(in: -shake...shake) * 0.5 : 0
        w.translateBy(x: -camX + sx, y: -camY + sy)
        // ground
        let ground = night ? Color(red: 0.05, green: 0.06, blue: 0.09) : Color(red: 0.11, green: 0.13, blue: 0.12)
        w.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(ground))
        var grid = Path()
        var gx = (camX / 100).rounded(.down) * 100
        while gx < camX + size.width + 100 { grid.move(to: CGPoint(x: gx, y: camY - 100)); grid.addLine(to: CGPoint(x: gx, y: camY + size.height + 100)); gx += 100 }
        var gy = (camY / 100).rounded(.down) * 100
        while gy < camY + size.height + 100 { grid.move(to: CGPoint(x: camX - 100, y: gy)); grid.addLine(to: CGPoint(x: camX + size.width + 100, y: gy)); gy += 100 }
        w.stroke(grid, with: .color(.white.opacity(0.04)), lineWidth: 1)
        w.stroke(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(Color.red.opacity(0.5)), lineWidth: 6)
        // walls
        for o in obstacles {
            let rr = Path(roundedRect: o, cornerRadius: 6)
            w.fill(rr, with: .color(Color(white: 0.2)))
            w.stroke(rr, with: .color(Color.white.opacity(0.18)), lineWidth: 2)
            var x = Path()
            x.move(to: CGPoint(x: o.minX + 6, y: o.minY + 6)); x.addLine(to: CGPoint(x: o.maxX - 6, y: o.maxY - 6))
            x.move(to: CGPoint(x: o.maxX - 6, y: o.minY + 6)); x.addLine(to: CGPoint(x: o.minX + 6, y: o.maxY - 6))
            w.stroke(x, with: .color(Color.white.opacity(0.07)), lineWidth: 2)
        }
        // pickups
        for p in pickups {
            let pulse = 1 + 0.15 * sin(time * 6 + p.pos.x)
            let c: Color = p.kind == 1 ? Color(red: 0.4, green: 0.95, blue: 0.5) : (p.kind == 2 ? .cyan : .yellow)
            let rad = 11 * pulse
            w.fill(Path(ellipseIn: CGRect(x: p.pos.x - rad * 1.7, y: p.pos.y - rad * 1.7, width: rad * 3.4, height: rad * 3.4)), with: .color(c.opacity(0.18)))
            if p.kind == 2 {
                var d = Path()
                d.move(to: CGPoint(x: p.pos.x, y: p.pos.y - rad)); d.addLine(to: CGPoint(x: p.pos.x + rad * 0.8, y: p.pos.y))
                d.addLine(to: CGPoint(x: p.pos.x, y: p.pos.y + rad)); d.addLine(to: CGPoint(x: p.pos.x - rad * 0.8, y: p.pos.y)); d.closeSubpath()
                w.fill(d, with: .color(c))
            } else if p.kind == 1 {
                w.fill(Path(ellipseIn: CGRect(x: p.pos.x - rad, y: p.pos.y - rad, width: rad * 2, height: rad * 2)), with: .color(c))
                w.draw(Text("+").font(.system(size: 16, weight: .black)).foregroundColor(.black), at: p.pos)
            } else {
                w.fill(Path(roundedRect: CGRect(x: p.pos.x - rad, y: p.pos.y - rad * 0.7, width: rad * 2, height: rad * 1.4), cornerRadius: 3), with: .color(c))
                w.draw(Text("A").font(.system(size: 12, weight: .black)).foregroundColor(.black), at: p.pos)
            }
        }
        // zombies
        for z in zeds {
            let sh = CGRect(x: z.pos.x - z.r, y: z.pos.y + z.r * 0.6, width: z.r * 2, height: z.r * 0.7)
            w.fill(Path(ellipseIn: sh), with: .color(.black.opacity(0.35)))
            let rect = CGRect(x: z.pos.x - z.r, y: z.pos.y - z.r, width: z.r * 2, height: z.r * 2)
            if let img = sprites[z.handle] {
                let im = w.resolve(Image(uiImage: img))
                w.drawLayer { l in
                    l.clip(to: Path(ellipseIn: rect))
                    l.draw(im, in: rect)
                    l.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.2, green: 0.8, blue: 0.3).opacity(0.28)))
                }
            } else {
                w.fill(Path(ellipseIn: rect), with: .color(z.color.opacity(0.7)))
                w.draw(Text(z.emoji).font(.system(size: z.r * 1.3)), at: z.pos)
            }
            let ring: Color = z.kind == 4 ? .orange : (z.kind == 3 ? .purple : (z.kind == 5 ? .red : z.color))
            w.stroke(Path(ellipseIn: rect), with: .color(ring), lineWidth: z.kind == 5 ? 4 : 2.5)
            if z.flash > 0 { w.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.6))) }
            if z.hp < z.maxHp {
                let bw = z.r * 2
                let bar = CGRect(x: z.pos.x - z.r, y: z.pos.y - z.r - 10, width: bw, height: 4)
                w.fill(Path(bar), with: .color(.black.opacity(0.6)))
                w.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: bw * max(0, z.hp / z.maxHp), height: 4)), with: .color(.red))
            }
            if z.kind == 5 {
                w.draw(Text("👑 \(z.name)").font(.system(size: 13, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: z.pos.x, y: z.pos.y - z.r - 22))
            }
        }
        // bullets
        for b in bullets {
            if b.mine {
                var t = Path()
                t.move(to: b.pos)
                t.addLine(to: CGPoint(x: b.pos.x - b.vel.dx * 0.025, y: b.pos.y - b.vel.dy * 0.025))
                w.stroke(t, with: .color(.yellow), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                w.fill(Path(ellipseIn: CGRect(x: b.pos.x - 5, y: b.pos.y - 5, width: 10, height: 10)), with: .color(Color(red: 0.7, green: 0.2, blue: 0.95)))
            }
        }
        // player
        w.fill(Path(ellipseIn: CGRect(x: pos.x - 16, y: pos.y + 10, width: 32, height: 12)), with: .color(.black.opacity(0.35)))
        w.drawLayer { l in
            l.translateBy(x: pos.x, y: pos.y)
            l.rotate(by: .radians(Double(aim)))
            l.fill(Path(roundedRect: CGRect(x: 10, y: -4, width: 26, height: 8), cornerRadius: 2), with: .color(Color(white: 0.85)))
            l.fill(Path(CGRect(x: 30, y: -2.5, width: 10, height: 5)), with: .color(Color(white: 0.45)))
            if flashT > 0 {
                l.fill(Path(ellipseIn: CGRect(x: 36, y: -9, width: 18, height: 18)), with: .color(.yellow.opacity(0.9)))
            }
        }
        let prect = CGRect(x: pos.x - 18, y: pos.y - 18, width: 36, height: 36)
        if let img = sprite {
            let im = w.resolve(Image(uiImage: img))
            w.drawLayer { l in
                l.clip(to: Path(ellipseIn: prect))
                l.draw(im, in: prect)
            }
        } else {
            w.fill(Path(ellipseIn: prect), with: .color(.blue))
        }
        w.stroke(Path(ellipseIn: prect), with: .color(hurtT > 0 ? .red : .white), lineWidth: 3)
        // explosions + pops
        for b in booms {
            let k = 1 - b.life / 0.4
            let rr = b.r * (0.4 + k * 0.7)
            w.fill(Path(ellipseIn: CGRect(x: b.pos.x - rr, y: b.pos.y - rr, width: rr * 2, height: rr * 2)), with: .color(Color.orange.opacity(0.5 * (1 - k))))
            w.stroke(Path(ellipseIn: CGRect(x: b.pos.x - rr, y: b.pos.y - rr, width: rr * 2, height: rr * 2)), with: .color(.yellow.opacity(1 - k)), lineWidth: 3)
        }
        for p in pops {
            w.draw(Text(p.text).font(.system(size: 14, weight: .heavy)).foregroundColor(p.color.opacity(Double(p.life))),
                   at: CGPoint(x: p.pos.x, y: p.pos.y - 30 - (1 - p.life) * 30))
        }
        // night darkness
        if night {
            let c = CGPoint(x: pos.x - camX, y: pos.y - camY)
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [.clear, Color.black.opacity(0.93)]), center: c, startRadius: 110, endRadius: 320))
        }
        if hurtT > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.red.opacity(Double(hurtT) * 0.5)))
        }
    }
}

@MainActor
enum SurvivalSprites {
    static func render(emoji: String, key: String, size: CGFloat = 72) -> UIImage? {
        let r = ImageRenderer(content: Avatar(emoji: emoji, key: key, size: size))
        r.scale = 2
        return r.uiImage
    }
}

// MARK: - Playing

struct SurvivalPlay: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var engine = SurvivalEngine()
    @State private var lStart: CGPoint? = nil
    @State private var lKnob: CGPoint = .zero
    @State private var rStart: CGPoint? = nil
    @State private var rKnob: CGPoint = .zero
    @State private var collected = false
    @State private var quit = false

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
            if engine.paused && engine.phase != 2 { pauseView }
            if engine.phase == 2 { overView }
        }
        .statusBarHidden(true)
        .onAppear {
            let st = game.s
            let cast = st.npcs.filter { $0.id != "newsdesk" }
            engine.start(cast: cast, data: st.ex.surv ?? SurvData())
            Task { @MainActor in
                engine.sprite = SurvivalSprites.render(emoji: st.persona.emoji, key: st.persona.handle)
                for n in cast.prefix(14) { engine.sprites[n.handle] = SurvivalSprites.render(emoji: n.emoji, key: n.handle, size: 64) }
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
                                if hypot(dx, dy) > 8 { engine.aim = atan2(dy, dx) }
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

    private var hud: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let e = engine
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.55)).frame(width: 150, height: 14)
                            Capsule().fill(e.hp / e.maxHp > 0.35 ? Color(red: 0.4, green: 0.95, blue: 0.5) : Color.red)
                                .frame(width: 150 * max(0, e.hp / e.maxHp), height: 14)
                        }
                        Text("\(Int(e.hp)) / \(Int(e.maxHp))").font(.jk(11, .bold)).foregroundColor(.white)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(e.night ? "NIGHT \(e.wave)" : "WAVE \(e.wave)").font(.jk(18, .heavy)).foregroundColor(e.night ? .purple : .white)
                        Text(e.phase == 1 ? "next wave in \(Int(e.rest) + 1)" : "\(e.zeds.count + e.toSpawn) left").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Button { e.paused = true } label: {
                            Image(systemName: "pause.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                .frame(width: 34, height: 34).background(Color.black.opacity(0.5)).clipShape(Circle())
                        }
                        Text("💎 \(e.runGems)  ☠️ \(e.kills)").font(.jk(12, .bold)).foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)
                if e.bannerT > 0 {
                    Text(e.banner).font(.jk(30, .heavy)).foregroundColor(.white).shadow(radius: 6).padding(.top, 40).opacity(Double(min(1, e.bannerT)))
                }
                Spacer()
                HStack(spacing: 10) {
                    Button { e.cycleGun() } label: {
                        Text(e.gun.emoji + " " + e.gun.name).font(.jk(13, .bold)).foregroundColor(.white)
                            .padding(.horizontal, 12).frame(height: 38).background(Color.black.opacity(0.55)).clipShape(Capsule())
                    }
                    Text(e.reloadT > 0 ? "RELOADING" : "\(e.curMag) / \(e.gun.id == "pistol" ? "∞" : "\(e.curReserve)")")
                        .font(.jk(18, .heavy)).foregroundColor(e.curMag == 0 ? .red : .white)
                    Button { e.reload() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
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
                Button { engine.hp = 0; engine.phase = 2; engine.paused = false } label: {
                    Text("Give up").font(.jk(16, .bold)).foregroundColor(.red).frame(width: 220, height: 46).background(Color.red.opacity(0.15)).clipShape(Capsule())
                }
            }
        }
    }

    private var overView: some View {
        let e = engine
        let bonus = Int(Double(e.runGems) * Double(e.lootMul))
        return ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("YOU DIED").font(.jk(36, .heavy)).foregroundColor(.red)
                Text("Reached wave \(e.wave)").font(.jk(20, .bold))
                Text("☠️ \(e.kills) kills   💎 \(bonus) gems").font(.jk(18, .semibold))
                Button {
                    guard !collected else { return }
                    collected = true
                    game.survivalFinish(wave: e.wave, kills: e.kills, gems: bonus)
                    dismiss()
                } label: {
                    Text("Collect and exit").font(.jk(18, .bold)).foregroundColor(.black).frame(width: 240, height: 52).background(Color.white).clipShape(Capsule())
                }
            }
        }
    }
}

extension Game {
    func survivalFinish(wave: Int, kills: Int, gems: Int) {
        var st = s
        var d = st.ex.surv ?? SurvData()
        d.runs += 1
        d.kills += kills
        d.best = max(d.best, wave)
        st.ex.surv = d
        st.ex.gems += gems
        gainXP(&st, wave * 5)
        s = st
        showToast("+\(gems) gems")
    }

    func survivalBuy(_ key: String) {
        var st = s
        var d = st.ex.surv ?? SurvData()
        let costs = ["hp": 25, "dmg": 35, "spd": 30, "mag": 25, "loot": 40]
        if let base = costs[key] {
            let lvl = key == "hp" ? d.hp : key == "dmg" ? d.dmg : key == "spd" ? d.spd : key == "mag" ? d.mag : d.loot
            guard lvl < 10 else { return }
            let cost = base * (lvl + 1)
            guard st.ex.gems >= cost else { showToast("Not enough gems"); return }
            st.ex.gems -= cost
            switch key {
            case "hp": d.hp += 1
            case "dmg": d.dmg += 1
            case "spd": d.spd += 1
            case "mag": d.mag += 1
            default: d.loot += 1
            }
        } else {
            let g = Guns.get(key)
            guard !d.guns.contains(key), st.ex.gems >= g.price else { if !d.guns.contains(key) { showToast("Not enough gems") }; return }
            st.ex.gems -= g.price
            d.guns.append(key)
        }
        st.ex.surv = d
        s = st
    }
}

// MARK: - Hub + Armory + Tab bar

struct SurvivalHub: View {
    @EnvironmentObject var game: Game
    @State private var play = false
    @State private var tacDiff: Int? = nil

    var body: some View {
        let st = game.s
        let d = st.ex.surv ?? SurvData()
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("MAINCHAR").font(.jk(14, .heavy)).foregroundColor(T.sub).tracking(4)
                    Text("SURVIVAL").font(.jk(40, .heavy))
                }
                .padding(.top, 20)
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 120, ring: true)
                Text(st.persona.name).font(.jk(22, .bold))
                HStack(spacing: 10) {
                    cell("Best wave", "\(d.best)")
                    cell("Kills", "\(d.kills)")
                    cell("Runs", "\(d.runs)")
                    cell("Gems", "\(st.ex.gems)")
                }
                Button { play = true } label: {
                    Text("DEPLOY").font(.jk(26, .heavy)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 66)
                        .background(Color(red: 0.4, green: 0.95, blue: 0.5)).clipShape(Capsule())
                }
                tacticalCard
                VStack(alignment: .leading, spacing: 8) {
                    Text("HOW IT WORKS").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    Text("Left thumb moves. Right thumb aims and fires. The characters from your world are the horde. Haters sprint, moguls tank, gossips spit, chaos explodes, and every fifth wave brings a boss. Every third wave is night. Gems you bank buy upgrades and guns in the Armory.")
                        .font(.jk(14)).foregroundColor(.white.opacity(0.85))
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .fullScreenCover(isPresented: $play) { SurvivalPlay().environmentObject(game).preferredColorScheme(.dark) }
        .fullScreenCover(isPresented: Binding(get: { tacDiff != nil }, set: { if !$0 { tacDiff = nil } })) {
            TacticalPlay(diff: tacDiff ?? 1).environmentObject(game).preferredColorScheme(.dark)
        }
    }

    private var tacticalCard: some View {
        let t = game.s.ex.tac ?? TacData()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TACTICAL 5v5").font(.jk(11, .heavy)).foregroundColor(T.sub)
                Spacer()
                Text("\(t.wins)W  \(t.losses)L  \u{00B7}  \(t.rating)").font(.jk(12, .bold)).foregroundColor(.white.opacity(0.85))
            }
            Text("First to 3 rounds. Attack or defend sites A and B against bots. Plant, defuse, hold angles.")
                .font(.jk(14)).foregroundColor(.white.opacity(0.85))
            HStack(spacing: 8) {
                ForEach(Array(["Easy", "Normal", "Hard"].enumerated()), id: \.offset) { i, n in
                    Button { tacDiff = i } label: {
                        Text(n).font(.jk(15, .heavy)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(Color(red: 0.4, green: 0.7, blue: 1)).clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func cell(_ k: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.jk(20, .heavy))
            Text(k.uppercased()).font(.jk(9, .heavy)).foregroundColor(T.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ArmoryView: View {
    @EnvironmentObject var game: Game

    var body: some View {
        let st = game.s
        let d = st.ex.surv ?? SurvData()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Armory").font(.jk(30, .heavy))
                    Spacer()
                    Text("💎 \(st.ex.gems)").font(.jk(18, .bold))
                }
                Text("GUNS").font(.jk(11, .heavy)).foregroundColor(T.sub)
                ForEach(Guns.all.filter { $0.id != "pistol" }, id: \.id) { g in
                    let owned = d.guns.contains(g.id)
                    HStack(spacing: 12) {
                        Text(g.emoji).font(.system(size: 30))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.name).font(.jk(16, .bold))
                            Text("dmg \(Int(g.dmg))\(g.pellets > 1 ? " x\(g.pellets)" : "") · \(String(format: "%.1f", g.rate))/s · mag \(g.mag)").font(.jk(12)).foregroundColor(T.sub)
                        }
                        Spacer()
                        Button { game.survivalBuy(g.id) } label: {
                            Text(owned ? "Owned" : "💎 \(g.price)").font(.jk(14, .bold)).foregroundColor(owned ? T.sub : .black)
                                .padding(.horizontal, 14).frame(height: 36)
                                .background(owned ? Color.white.opacity(0.1) : Color(red: 0.67, green: 0.62, blue: 0.95)).clipShape(Capsule())
                        }
                        .disabled(owned)
                    }
                    .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Text("UPGRADES").font(.jk(11, .heavy)).foregroundColor(T.sub).padding(.top, 6)
                up("hp", "❤️", "Max health", "+15 per level", d.hp, 25)
                up("dmg", "💢", "Damage", "+8% per level", d.dmg, 35)
                up("spd", "👟", "Move speed", "+4% per level", d.spd, 30)
                up("mag", "📦", "Magazine size", "+10% per level", d.mag, 25)
                up("loot", "💎", "Gem luck", "+10% gems per level", d.loot, 40)
            }
            .padding(16).padding(.bottom, 30)
        }
    }

    private func up(_ key: String, _ emoji: String, _ title: String, _ sub: String, _ lvl: Int, _ base: Int) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.jk(16, .bold))
                Text(sub).font(.jk(12)).foregroundColor(T.sub)
                HStack(spacing: 3) {
                    ForEach(0..<10, id: \.self) { i in
                        Capsule().fill(i < lvl ? Color(red: 0.4, green: 0.95, blue: 0.5) : Color.white.opacity(0.12)).frame(height: 5)
                    }
                }
            }
            Spacer()
            Button { game.survivalBuy(key) } label: {
                Text(lvl >= 10 ? "MAX" : "💎 \(base * (lvl + 1))").font(.jk(14, .bold)).foregroundColor(lvl >= 10 ? T.sub : .black)
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(lvl >= 10 ? Color.white.opacity(0.1) : Color(red: 0.67, green: 0.62, blue: 0.95)).clipShape(Capsule())
            }
            .disabled(lvl >= 10)
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SurvivalBar: View {
    @EnvironmentObject var nav: Nav

    private func item(_ i: Int, _ icon: String, _ label: String) -> some View {
        Button { nav.tab = i } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.jk(10, .semibold))
            }
            .foregroundColor(nav.tab == i ? .white : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 0) {
            item(0, "scope", "Deploy")
            item(1, "shield.lefthalf.filled", "Armory")
            item(5, "chart.line.uptrend.xyaxis", "Market")
            item(4, "person.fill", "Profile")
        }
        .padding(.top, 6)
        .background(T.bg.ignoresSafeArea(edges: .bottom))
    }
}
