import SwiftUI

private struct BRBill {
    let d: CGFloat
    let kind: Int   // 0 actor, 1 loot, 2 tree, 3 station, 4 vehicle, 5 throw, 6 smoke, 7 blast
    let idx: Int
}

extension BREngine {
    static let fov: CGFloat = 1.25

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard !actors.isEmpty else { return }
        let m = me
        let W = size.width, H = size.height
        let focal = (W / 2) / tan(curFov / 2)
        let shk: CGFloat = shake > 0.1 ? CGFloat(sin(time * 61)) * shake : 0
        let hz = H * 0.5 + sin(bobT) * 4 * bobAmp * bobScale + (pitch + recoilP + camDip) * focal + shk
        let eye = eyeNow

        let zb = drawBase(&ctx, size, hz, focal)
        let cols = zb.count
        let cw = W / CGFloat(cols)

        // billboards
        var list: [BRBill] = []
        for (i, a) in actors.enumerated() where a.alive && !a.isMe && !a.air {
            let d = hypot(a.p.x - m.p.x, a.p.y - m.p.y)
            if d < 1100 { list.append(BRBill(d: d, kind: 0, idx: i)) }
        }
        for (i, l) in loot.enumerated() where !l.taken {
            let d = hypot(l.p.x - m.p.x, l.p.y - m.p.y)
            if d < 420 { list.append(BRBill(d: d, kind: 1, idx: i)) }
        }
        for (i, t) in world.trees.enumerated() {
            let d = hypot(t.x - m.p.x, t.y - m.p.y)
            if d < 950 { list.append(BRBill(d: d, kind: 2, idx: i)) }
        }
        for (i, st) in stations.enumerated() {
            let d = hypot(st.p.x - m.p.x, st.p.y - m.p.y)
            if d < 1400 { list.append(BRBill(d: d, kind: 3, idx: i)) }
        }
        for (i, v) in vehicles.enumerated() where v.hp > 0 && i != inVeh {
            let d = hypot(v.p.x - m.p.x, v.p.y - m.p.y)
            if d < 1100 { list.append(BRBill(d: d, kind: 4, idx: i)) }
        }
        for (i, t) in throwsA.enumerated() {
            let d = hypot(t.x - m.p.x, t.y - m.p.y)
            if d < 900 { list.append(BRBill(d: d, kind: 5, idx: i)) }
        }
        for (i, sm) in smokes.enumerated() {
            let d = hypot(sm.p.x - m.p.x, sm.p.y - m.p.y)
            if d < 900 { list.append(BRBill(d: d, kind: 6, idx: i)) }
        }
        for (i, bl) in blasts.enumerated() {
            let d = hypot(bl.p.x - m.p.x, bl.p.y - m.p.y)
            if d < 900 { list.append(BRBill(d: d, kind: 7, idx: i)) }
        }
        list.sort { $0.d > $1.d }
        for bb in list {
            let p: CGPoint
            switch bb.kind {
            case 0: p = actors[bb.idx].p
            case 1: p = loot[bb.idx].p
            case 3: p = stations[bb.idx].p
            case 4: p = vehicles[bb.idx].p
            case 5: p = CGPoint(x: throwsA[bb.idx].x, y: throwsA[bb.idx].y)
            case 6: p = smokes[bb.idx].p
            case 7: p = blasts[bb.idx].p
            default: p = world.trees[bb.idx]
            }
            let dx = p.x - m.p.x, dy = p.y - m.p.y
            let rel = brWrap(atan2(dy, dx) - m.ang)
            if abs(rel) > curFov / 2 + 0.35 { continue }
            let perp = bb.d * cos(rel)
            if perp < 10 { continue }
            let sx = W / 2 + tan(rel) * focal
            let f = focal / perp
            let feet = hz + eye * f
            let halfW: CGFloat = (bb.kind == 2 ? 30 : (bb.kind == 6 || bb.kind == 7 ? 60 : (bb.kind == 4 ? 35 : 14))) * f
            var seen = false
            for o in [-0.8, 0, 0.8] {
                let col = Int((sx + CGFloat(o) * halfW) / cw)
                if col >= 0 && col < cols && zb[col] > perp - 6 { seen = true }
            }
            if !seen { continue }
            let fog = min(1, bb.d / 1100) * 0.6
            if bb.kind == 2 {
                if bb.idx % 3 != 0 {
                    ctx.fill(Path(CGRect(x: sx - 3.5 * f, y: feet - 30 * f, width: 7 * f, height: 30 * f)), with: .color(brc(0.3, 0.2, 0.12)))
                    for k in 0..<4 {
                        let ty = feet - (24 + CGFloat(k) * 26) * f
                        let tw = (36 - CGFloat(k) * 8) * f
                        var tri = Path()
                        tri.move(to: CGPoint(x: sx, y: ty - 44 * f))
                        tri.addLine(to: CGPoint(x: sx + tw, y: ty))
                        tri.addLine(to: CGPoint(x: sx - tw, y: ty))
                        tri.closeSubpath()
                        ctx.fill(tri, with: .color(brc(0.1 + 0.5 * fog + CGFloat(k) * 0.02, 0.3 + 0.4 * fog + CGFloat(k) * 0.03, 0.14 + 0.5 * fog)))
                    }
                } else {
                    ctx.fill(Path(CGRect(x: sx - 5 * f, y: feet - 54 * f, width: 10 * f, height: 54 * f)), with: .color(brc(0.36, 0.26, 0.16)))
                    let cr = 30 * f
                    ctx.fill(Path(ellipseIn: CGRect(x: sx - cr, y: feet - 84 * f - cr, width: cr * 2, height: cr * 2)),
                             with: .color(brc(0.2 + 0.5 * fog, 0.42 + 0.4 * fog, 0.18 + 0.5 * fog)))
                    ctx.fill(Path(ellipseIn: CGRect(x: sx - cr * 0.8 - cr * 0.3, y: feet - 94 * f - cr * 0.8, width: cr * 1.3, height: cr * 1.3)),
                             with: .color(brc(0.3 + 0.4 * fog, 0.55 + 0.3 * fog, 0.24 + 0.4 * fog)))
                }
            } else if bb.kind == 1 {
                let l = loot[bb.idx]
                let sz = 15 * f
                let c: Color
                switch l.kind {
                case 0: c = l.rar == 0 ? brc(1, 0.78, 0.15) : (l.rar == 1 ? brc(0.3, 0.62, 1) : (l.rar == 2 ? brc(0.72, 0.42, 1) : brc(1, 0.55, 0.1)))
                case 1: c = brc(0.7, 0.7, 0.72)
                case 2: c = brc(0.25, 0.55, 1)
                case 3: c = brc(1, 0.25, 0.25)
                case 5: c = brc(0.6, 0.95, 1)
                case 6: c = brc(1, 0.55, 0.2)
                default: c = brc(0.3, 0.9, 0.4)
                }
                let cy = feet - 14 * f - sin(time * 3 + CGFloat(bb.idx)) * 2 * f
                var dia = Path()
                dia.move(to: CGPoint(x: sx, y: cy - sz))
                dia.addLine(to: CGPoint(x: sx + sz, y: cy))
                dia.addLine(to: CGPoint(x: sx, y: cy + sz))
                dia.addLine(to: CGPoint(x: sx - sz, y: cy))
                dia.closeSubpath()
                ctx.fill(dia, with: .color(c))
                ctx.stroke(dia, with: .color(.white), lineWidth: 1.5)
                if bb.d < 200 {
                    let label = l.kind == 0 ? (l.rar > 0 ? BRMeta.rarNames[l.rar] + " " : "") + BRGuns.def(l.gun).name : (l.kind == 1 ? "AMMO" : (l.kind == 2 ? "ARMOR" : (l.kind == 3 ? "MED KIT" : (l.kind == 5 ? ["", "OPTIC", "EXT MAG", "SUPPRESSOR"][l.att] : (l.kind == 6 ? ["FRAG", "SMOKE", "FLASH"][l.att] : "$\(l.amt)")))))
                    ctx.draw(Text(label).font(.system(size: 10, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: sx, y: cy - sz - 8))
                }
            } else if bb.kind == 0 {
                drawActor(&ctx, actors[bb.idx], sx: sx, feet: feet, f: f, fog: fog)
            } else {
                drawExtraBill(&ctx, kind: bb.kind, idx: bb.idx, d: bb.d, sx: sx, feet: feet, f: f, fog: fog, rel: rel)
            }
        }

        drawNums(&ctx, size, hz, focal, eye)
        drawPings(&ctx, size, hz, focal, eye)
        if phase == 0 && inVeh < 0 {
            drawADS(&ctx, size)
            drawViewGun(&ctx, size)
        } else if inVeh >= 0 {
            drawCockpit(&ctx, size)
        } else {
            drawAirOverlay(&ctx, size)
        }

        // crosshair
        let ch = CGPoint(x: W / 2, y: H / 2)
        let scoped = adsT > 0.3 && (m.slots[m.cur]?.gun == "rifle" || m.slots[m.cur]?.gun == "smg")
        if !scoped && phase == 0 && inVeh < 0 {
            let cc: Color = lockT != nil ? brc(1, 0.3, 0.3) : .white
            let gap: CGFloat = 5 + recoilP * 260
            for (ax, ay) in [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)] {
                var p = Path()
                p.move(to: CGPoint(x: ch.x + CGFloat(ax) * gap, y: ch.y + CGFloat(ay) * gap))
                p.addLine(to: CGPoint(x: ch.x + CGFloat(ax) * (gap + 7), y: ch.y + CGFloat(ay) * (gap + 7)))
                ctx.stroke(p, with: .color(cc.opacity(0.9)), lineWidth: 2)
            }
        }
        if hitT > 0 {
            for (ax, ay) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
                var p = Path()
                p.move(to: CGPoint(x: ch.x + CGFloat(ax) * 7, y: ch.y + CGFloat(ay) * 7))
                p.addLine(to: CGPoint(x: ch.x + CGFloat(ax) * 15, y: ch.y + CGFloat(ay) * 15))
                ctx.stroke(p, with: .color(.red), lineWidth: 2.5)
            }
        }

        if flashT > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(brc(1, 1, 1, min(1, flashT * 1.2))))
        }
        // damage + storm tint
        if m.hurt > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(brc(1, 0, 0, m.hurt * 0.3)))
        }
        if outsideZone() {
            let pulse = 0.12 + 0.08 * sin(time * 6)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(brc(0.6, 0.1, 0.8, pulse)))
        }
        if !m.alive {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(brc(0, 0, 0, min(0.6, deadT * 0.4))))
        }

        drawCompass(&ctx, size)
        drawMinimap(&ctx, size)
    }

    private func drawActor(_ ctx: inout GraphicsContext, _ a: BRActor, sx: CGFloat, feet: CGFloat, f: CGFloat, fog: CGFloat) {
        let hpx = 72 * f
        let wpx = 26 * f
        let k = 1 - fog * 0.5
        let c = a.color
        let ally = a.team == me.team
        let dist = hypot(a.p.x - me.p.x, a.p.y - me.p.y)
        let st = a.stance
        let moving = a.spd > 8
        let swing = moving ? sin(a.stride) : 0
        let amp: CGFloat = a.sprinting ? 1.5 : 1
        // pose: vertical scale of the standing figure
        let sy: CGFloat = a.diveT > 0 ? 0.4 : st == 2 ? 0.34 : (st == 1 ? 0.72 : (a.sprinting ? 0.95 : 1))
        let sxs: CGFloat = st == 2 ? 1.5 : 1
        let lean: CGFloat = a.sprinting ? wpx * 0.12 : 0
        var fig = ctx
        fig.translateBy(x: sx, y: feet)
        fig.scaleBy(x: sxs, y: sy)
        fig.translateBy(x: -sx + lean, y: -feet)
        drawFigure(&fig, a, sx: sx, feet: feet, hpx: hpx, wpx: wpx, f: f, k: k, c: c, swing: swing * amp, st: st)
        let topS = feet - hpx * sy
        // name tag
        if dist < 520 || ally {
            let tag = ally ? brc(0.45, 0.95, 0.55) : brc(1, 0.5, 0.45)
            let ty = topS - 14
            ctx.draw(Text(a.name).font(.system(size: 10, weight: .heavy)).foregroundColor(tag), at: CGPoint(x: sx, y: ty - 8))
            let bw: CGFloat = 38
            ctx.fill(Path(CGRect(x: sx - bw / 2, y: ty, width: bw, height: 3.5)), with: .color(brc(0, 0, 0, 0.6)))
            ctx.fill(Path(CGRect(x: sx - bw / 2, y: ty, width: bw * max(0, a.hp) / 100, height: 3.5)), with: .color(ally ? brc(0.4, 0.9, 0.5) : brc(0.95, 0.25, 0.25)))
            if a.armor > 0 {
                ctx.fill(Path(CGRect(x: sx - bw / 2, y: ty - 3, width: bw * a.armor / 100, height: 2)), with: .color(brc(0.4, 0.65, 1)))
            }
        }
    }

    private func drawFigure(_ c2: inout GraphicsContext, _ a: BRActor, sx: CGFloat, feet: CGFloat, hpx: CGFloat, wpx: CGFloat, f: CGFloat, k: CGFloat, c: BRCol, swing: CGFloat, st: Int) {
        let topY = feet - hpx
        // ground shadow
        c2.fill(Path(ellipseIn: CGRect(x: sx - wpx * 0.9, y: feet - 3 * f, width: wpx * 1.8, height: 6 * f)), with: .color(brc(0, 0, 0, 0.28)))
        // legs
        let legC = brc(0.15 * k, 0.17 * k, 0.22 * k)
        c2.fill(Path(roundedRect: CGRect(x: sx - wpx * 0.38, y: feet - hpx * 0.46 - max(0, swing) * hpx * 0.07, width: wpx * 0.34, height: hpx * 0.46), cornerRadius: 2 * f), with: .color(legC))
        c2.fill(Path(roundedRect: CGRect(x: sx + wpx * 0.04, y: feet - hpx * 0.46 - max(0, -swing) * hpx * 0.07, width: wpx * 0.34, height: hpx * 0.46), cornerRadius: 2 * f), with: .color(legC))
        c2.fill(Path(CGRect(x: sx - wpx * 0.42, y: feet - 5 * f - max(0, swing) * hpx * 0.07, width: wpx * 0.4, height: 5 * f)), with: .color(brc(0.06, 0.06, 0.07)))
        c2.fill(Path(CGRect(x: sx + wpx * 0.02, y: feet - 5 * f - max(0, -swing) * hpx * 0.07, width: wpx * 0.4, height: 5 * f)), with: .color(brc(0.06, 0.06, 0.07)))
        // torso + vest
        let torso = CGRect(x: sx - wpx / 2, y: topY + hpx * 0.17, width: wpx, height: hpx * 0.4)
        c2.fill(Path(roundedRect: torso, cornerRadius: wpx * 0.14), with: .color(brc(c.0 * k, c.1 * k, c.2 * k)))
        c2.fill(Path(roundedRect: torso.insetBy(dx: wpx * 0.12, dy: hpx * 0.04), cornerRadius: wpx * 0.1), with: .color(brc(0.16 * k, 0.17 * k, 0.2 * k, 0.85)))
        // arms
        c2.fill(Path(roundedRect: CGRect(x: sx - wpx * 0.72, y: topY + hpx * 0.2 + swing * hpx * 0.02, width: wpx * 0.24, height: hpx * 0.32), cornerRadius: wpx * 0.1), with: .color(brc(c.0 * k * 0.8, c.1 * k * 0.8, c.2 * k * 0.8)))
        c2.fill(Path(roundedRect: CGRect(x: sx + wpx * 0.48, y: topY + hpx * 0.2 + swing * hpx * 0.02, width: wpx * 0.24, height: hpx * 0.32), cornerRadius: wpx * 0.1), with: .color(brc(c.0 * k * 0.8, c.1 * k * 0.8, c.2 * k * 0.8)))
        // rifle held across
        c2.fill(Path(roundedRect: CGRect(x: sx - wpx * 0.5, y: topY + hpx * 0.33, width: wpx * 1.15, height: hpx * 0.06), cornerRadius: 1.5 * f), with: .color(brc(0.07, 0.07, 0.09)))
        // head + helmet
        let hr = hpx * 0.095
        let hy = topY + hpx * 0.085
        c2.fill(Path(ellipseIn: CGRect(x: sx - hr, y: hy - hr, width: hr * 2, height: hr * 2)), with: .color(brc(0.85 * k, 0.68 * k, 0.55 * k)))
        var helm = Path()
        helm.addArc(center: CGPoint(x: sx, y: hy - hr * 0.1), radius: hr * 1.12, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        helm.closeSubpath()
        c2.fill(helm, with: .color(brc(0.2 * k, 0.24 * k, 0.2 * k)))
        if a.hurt > 0 {
            c2.fill(Path(roundedRect: torso, cornerRadius: wpx * 0.14), with: .color(brc(1, 1, 1, a.hurt * 0.5)))
        }
        if a.flash > 0 {
            let r = hpx * 0.1
            c2.fill(Path(ellipseIn: CGRect(x: sx + wpx * 0.75 - r, y: topY + hpx * 0.36 - r, width: r * 2, height: r * 2)), with: .color(brc(1, 0.9, 0.4, 0.9)))
        }
    }

    private func drawViewGun(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let m = me
        guard m.alive, let s = m.slots[m.cur] else { return }
        let img = GunSprites.image(s.gun)
        let mz = GunSprites.muzzle(s.gun)
        let bob = sin(bobT) * 6 * bobAmp * bobScale
        let sway = cos(bobT * 0.5) * 5 * bobAmp * bobScale * (1 + proneBlend * 2.5)
        var rect = GunSprites.rect(size)
        var dip: CGFloat = m.reloadT > 0 ? min(1, m.reloadT * 2.5) * rect.height * 0.4 : 0
        // armor plate: gun lowers while applying
        if plateT > 0 { dip += sin(min(1, plateT * 6) * .pi / 2) * rect.height * 0.3 * (plateT < 0.9 ? 1 : (1 - plateT) * 10) }
        if m.diveT > 0 { dip += sin(m.diveT / 0.7 * .pi) * rect.height * 0.35 }
        dip += proneBlend * rect.height * 0.08
        rect.origin.x += sway + gunKick * 20
        rect.origin.y += bob + dip + gunKick * 16 - recoilP * 40
        let sp = sprintT * (1 - adsT)
        if sp > 0.01 {
            rect.origin.x += sp * rect.width * 0.1
            rect.origin.y += sp * rect.height * 0.22
        }
        let isScope = s.gun == "rifle" || s.gun == "smg"
        let gunA: CGFloat = 1
        let spr = ctx.resolve(Image(uiImage: img))
        if gunA > 0.02 {
            ctx.drawLayer { l in
                l.opacity = Double(gunA)
                if sp > 0.01 || m.diveT > 0 {
                    let px = rect.maxX - rect.width * 0.12, py = rect.maxY - rect.height * 0.2
                    var ang = -0.5 * sp
                    if m.diveT > 0 { ang += sin(m.diveT / 0.7 * .pi) * -0.35 }
                    l.translateBy(x: px, y: py)
                    l.rotate(by: .radians(Double(ang)))
                    l.translateBy(x: -px, y: -py)
                }
                l.draw(spr, in: rect)
                if let tint = BRMeta.skinTint() {
                    l.blendMode = .sourceAtop
                    l.fill(Path(rect), with: .color(tint.opacity(0.42)))
                }
            }
        }
        let mp = CGPoint(x: rect.minX + mz.x * rect.width, y: rect.minY + mz.y * rect.height)
        // spawn particles for a shot
        if shotFlag {
            shotFlag = false
            for _ in 0..<2 {
                parts.append(BRPart(kind: 0, x: mp.x, y: mp.y, vx: CGFloat.random(in: -14...14), vy: CGFloat.random(in: -50...(-20)), life: 0.55, max: 0.55, rot: 0))
            }
            if isScope || s.gun == "pistol" {
                let ex = rect.minX + rect.width * 0.5
                let ey = rect.minY + rect.height * 0.62
                parts.append(BRPart(kind: 1, x: ex, y: ey, vx: CGFloat.random(in: 90...160), vy: CGFloat.random(in: -150...(-80)), life: 0.7, max: 0.7, rot: CGFloat.random(in: 0...6)))
            }
        }
        // update + draw particles
        var keep: [BRPart] = []
        for var q in parts {
            q.life -= lastDT
            if q.life <= 0 { continue }
            q.x += q.vx * lastDT
            q.y += q.vy * lastDT
            if q.kind == 1 {
                q.vy += 520 * lastDT
                q.rot += lastDT * 18
                var cp = Path()
                cp.addRect(CGRect(x: -3, y: -1.5, width: 6, height: 3))
                var t = CGAffineTransform(translationX: q.x, y: q.y)
                t = t.rotated(by: q.rot)
                ctx.fill(cp.applying(t), with: .color(brc(0.95, 0.75, 0.25)))
            } else {
                let k = q.life / q.max
                let r = 6 + (1 - k) * 16
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)), with: .color(brc(0.8, 0.8, 0.82, k * 0.35)))
            }
            keep.append(q)
        }
        parts = keep
        // tracer
        if tracerT > 0 && adsT < 0.5 {
            var tr = Path()
            tr.move(to: mp)
            tr.addLine(to: CGPoint(x: size.width / 2, y: size.height / 2))
            ctx.stroke(tr, with: .color(brc(1, 0.9, 0.5, tracerT / 0.07 * 0.7)), lineWidth: 1.6)
        }
        // muzzle flash
        if m.flash > 0 && adsT < 0.6 {
            let k = m.flash / 0.07
            let R: CGFloat = 52 * (0.55 + 0.45 * k)
            let rot = time * 47
            ctx.fill(Path(ellipseIn: CGRect(x: mp.x - R * 1.7, y: mp.y - R * 1.7, width: R * 3.4, height: R * 3.4)), with: .color(brc(1, 0.7, 0.3, 0.25 * k)))
            var star = Path()
            for i in 0..<14 {
                let ang = CGFloat(i) * (.pi / 7) + rot
                let jitter = 0.75 + 0.5 * abs(sin(rot * 3 + CGFloat(i) * 1.7))
                let r = (i % 2 == 0 ? R * jitter : R * 0.32)
                let pt = CGPoint(x: mp.x + cos(ang) * r, y: mp.y + sin(ang) * r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(brc(1, 0.55, 0.12, 0.92)))
            ctx.fill(Path(ellipseIn: CGRect(x: mp.x - R * 0.42, y: mp.y - R * 0.42, width: R * 0.84, height: R * 0.84)), with: .color(brc(1, 0.95, 0.7)))
        }
    }

    private func drawADS(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard adsT > 0.02, let s = me.slots[me.cur] else { return }
        let W = size.width, H = size.height
        let t = adsT
        let cx = W / 2, cy = H / 2
        switch s.gun {
        case "rifle":
            let R = H * 0.47
            var p = Path()
            p.addRect(CGRect(origin: .zero, size: size))
            p.addEllipse(in: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
            ctx.fill(p, with: .color(brc(0, 0, 0, 0.7 * t)), style: FillStyle(eoFill: true))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)), with: .color(brc(0.04, 0.04, 0.06, t)), lineWidth: 12)
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - R + 8, y: cy - R + 8, width: R * 2 - 16, height: R * 2 - 16)), with: .color(brc(0.4, 0.5, 0.6, 0.18 * t)), lineWidth: 2)
            let ink = brc(0.02, 0.02, 0.03, 0.9 * t)
            for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
                var l = Path()
                l.move(to: CGPoint(x: cx + CGFloat(dx) * 14, y: cy + CGFloat(dy) * 14))
                l.addLine(to: CGPoint(x: cx + CGFloat(dx) * R * 0.98, y: cy + CGFloat(dy) * R * 0.98))
                ctx.stroke(l, with: .color(ink), lineWidth: 1)
                var thick = Path()
                thick.move(to: CGPoint(x: cx + CGFloat(dx) * R * 0.62, y: cy + CGFloat(dy) * R * 0.62))
                thick.addLine(to: CGPoint(x: cx + CGFloat(dx) * R * 0.98, y: cy + CGFloat(dy) * R * 0.98))
                ctx.stroke(thick, with: .color(ink), lineWidth: 4)
                for k in 1..<6 {
                    let d = 14 + CGFloat(k) * 22
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + CGFloat(dx) * d - 1.5, y: cy + CGFloat(dy) * d - 1.5, width: 3, height: 3)), with: .color(ink))
                }
            }
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)), with: .color(brc(1, 0.15, 0.1, t)))
        case "smg":
            let ww = H * 0.95, hh = H * 0.62
            let win = CGRect(x: cx - ww / 2, y: cy - hh / 2, width: ww, height: hh)
            var p = Path()
            p.addRect(CGRect(origin: .zero, size: size))
            p.addRoundedRect(in: win, cornerSize: CGSize(width: 14, height: 14))
            ctx.fill(p, with: .color(brc(0, 0, 0, 0.55 * t)), style: FillStyle(eoFill: true))
            ctx.stroke(Path(roundedRect: win, cornerRadius: 14), with: .color(brc(0.04, 0.04, 0.05, t)), lineWidth: 12)
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 16, y: cy - 16, width: 32, height: 32)), with: .color(brc(1, 0.2, 0.15, 0.9 * t)), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)), with: .color(brc(1, 0.2, 0.15, t)))
            for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
                var l = Path()
                l.move(to: CGPoint(x: cx + CGFloat(dx) * 16, y: cy + CGFloat(dy) * 16))
                l.addLine(to: CGPoint(x: cx + CGFloat(dx) * 24, y: cy + CGFloat(dy) * 24))
                ctx.stroke(l, with: .color(brc(1, 0.2, 0.15, 0.9 * t)), lineWidth: 2)
            }
        default:
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3)), with: .color(brc(1, 0.9, 0.3, t)))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14)), with: .color(brc(1, 1, 1, 0.8 * t)), lineWidth: 1.5)
        }
    }

    private func drawCompass(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let cx = size.width / 2
        let y: CGFloat = 22
        let wid: CGFloat = 300
        ctx.fill(Path(roundedRect: CGRect(x: cx - wid / 2, y: y - 11, width: wid, height: 22), cornerRadius: 4), with: .color(brc(0, 0, 0, 0.4)))
        var deg = me.ang * 180 / .pi + 90
        while deg < 0 { deg += 360 }
        while deg >= 360 { deg -= 360 }
        let base = (deg / 5).rounded() * 5
        let pxPer = wid / 120
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var k = -65
        while k <= 65 {
            let dd = base + CGFloat(k)
            let x = cx + (dd - deg) * pxPer
            if x > cx - wid / 2 + 6 && x < cx + wid / 2 - 6 {
                var vi = Int(dd.rounded()) % 360
                if vi < 0 { vi += 360 }
                if vi % 45 == 0 {
                    ctx.draw(Text(names[vi / 45]).font(.system(size: 12, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: x, y: y))
                } else if vi % 15 == 0 {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y - 6))
                    p.addLine(to: CGPoint(x: x, y: y + 6))
                    ctx.stroke(p, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
                } else {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y - 3))
                    p.addLine(to: CGPoint(x: x, y: y + 3))
                    ctx.stroke(p, with: .color(.white.opacity(0.4)), lineWidth: 1)
                }
            }
            k += 5
        }
        var tri = Path()
        tri.move(to: CGPoint(x: cx, y: y + 13))
        tri.addLine(to: CGPoint(x: cx - 5, y: y + 20))
        tri.addLine(to: CGPoint(x: cx + 5, y: y + 20))
        tri.closeSubpath()
        ctx.fill(tri, with: .color(brc(0.85, 0.93, 0.2)))
        ctx.draw(Text("\(Int(deg))").font(.system(size: 10, weight: .bold)).foregroundColor(.white), at: CGPoint(x: cx, y: y + 29))
    }

    private func drawMinimap(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let m = me
        let mc = CGPoint(x: size.width - 72, y: 70)
        let R: CGFloat = 56
        let sc: CGFloat = 0.085
        let half = R / sc + 40
        let disc = Path(ellipseIn: CGRect(x: mc.x - R, y: mc.y - R, width: R * 2, height: R * 2))
        let zc = zoneC, zr = zoneR, nc = nextC, nr = nextR
        let holdPhase = (max(0, time - BREngine.dropTime) - CGFloat(stage) * (BREngine.hold + BREngine.shrink)) < BREngine.hold
        ctx.drawLayer { l in
            l.clip(to: disc)
            l.fill(disc, with: .color(brc(0.4, 0.5, 0.34)))
            l.translateBy(x: mc.x, y: mc.y)
            l.rotate(by: .radians(Double(-m.ang - .pi / 2)))
            l.scaleBy(x: sc, y: sc)
            l.translateBy(x: -m.p.x, y: -m.p.y)
            if let cg = world.mapImage {
                let res = l.resolve(Image(decorative: cg, scale: 1))
                l.draw(res, in: CGRect(x: 0, y: 0, width: BRWorld.W, height: BRWorld.W))
            }
            // storm outside the safe zone
            var storm = Path()
            storm.addRect(CGRect(x: m.p.x - half * 2, y: m.p.y - half * 2, width: half * 4, height: half * 4))
            storm.addEllipse(in: CGRect(x: zc.x - zr, y: zc.y - zr, width: zr * 2, height: zr * 2))
            l.fill(storm, with: .color(brc(0.55, 0.15, 0.75, 0.38)), style: FillStyle(eoFill: true))
            l.stroke(Path(ellipseIn: CGRect(x: zc.x - zr, y: zc.y - zr, width: zr * 2, height: zr * 2)), with: .color(brc(0.8, 0.5, 1)), lineWidth: 3 / sc)
            if holdPhase {
                l.stroke(Path(ellipseIn: CGRect(x: nc.x - nr, y: nc.y - nr, width: nr * 2, height: nr * 2)), with: .color(.white), lineWidth: 2 / sc)
            }
            drawMapExtras(&l, sc)
            for a in actors where a.alive && !a.isMe && a.ping > 0 {
                let r = 6 / sc
                l.fill(Path(ellipseIn: CGRect(x: a.p.x - r, y: a.p.y - r, width: r * 2, height: r * 2)), with: .color(brc(1, 0.25, 0.25, min(1, a.ping))))
            }
        }
        // vision cone
        var cone = Path()
        cone.move(to: mc)
        let a0: CGFloat = -.pi / 2 - curFov / 2
        let a1: CGFloat = -.pi / 2 + curFov / 2
        cone.addArc(center: mc, radius: R * 0.8, startAngle: .radians(Double(a0)), endAngle: .radians(Double(a1)), clockwise: false)
        cone.closeSubpath()
        ctx.fill(cone, with: .color(.white.opacity(0.16)))
        var arrow = Path()
        arrow.move(to: CGPoint(x: mc.x, y: mc.y - 7))
        arrow.addLine(to: CGPoint(x: mc.x + 5, y: mc.y + 5))
        arrow.addLine(to: CGPoint(x: mc.x, y: mc.y + 2))
        arrow.addLine(to: CGPoint(x: mc.x - 5, y: mc.y + 5))
        arrow.closeSubpath()
        ctx.fill(arrow, with: .color(brc(0.85, 0.93, 0.2)))
        ctx.stroke(arrow, with: .color(.black), lineWidth: 1)
        ctx.stroke(disc, with: .color(.white.opacity(0.75)), lineWidth: 2.5)
    }
}
