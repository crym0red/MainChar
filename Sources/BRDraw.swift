import SwiftUI

private struct BRBill {
    let d: CGFloat
    let kind: Int   // 0 actor, 1 loot, 2 tree
    let idx: Int
}

extension BREngine {
    static let fov: CGFloat = 1.25

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard !actors.isEmpty else { return }
        let m = me
        let W = size.width, H = size.height
        let focal = (W / 2) / tan(BREngine.fov / 2)
        let hz = H * 0.5 + sin(bobT) * 4 * bobAmp
        let eye = BREngine.eyeH

        let zb = drawBase(&ctx, size, hz, focal)
        let cols = zb.count
        let cw = W / CGFloat(cols)

        // billboards
        var list: [BRBill] = []
        for (i, a) in actors.enumerated() where a.alive && !a.isMe {
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
        list.sort { $0.d > $1.d }
        for bb in list {
            let p: CGPoint
            switch bb.kind {
            case 0: p = actors[bb.idx].p
            case 1: p = loot[bb.idx].p
            default: p = world.trees[bb.idx]
            }
            let dx = p.x - m.p.x, dy = p.y - m.p.y
            let rel = brWrap(atan2(dy, dx) - m.ang)
            if abs(rel) > BREngine.fov / 2 + 0.35 { continue }
            let perp = bb.d * cos(rel)
            if perp < 10 { continue }
            let sx = W / 2 + tan(rel) * focal
            let f = focal / perp
            let feet = hz + eye * f
            let halfW: CGFloat = (bb.kind == 2 ? 30 : 14) * f
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
                case 0: c = brc(1, 0.78, 0.15)
                case 1: c = brc(0.7, 0.7, 0.72)
                case 2: c = brc(0.25, 0.55, 1)
                case 3: c = brc(1, 0.25, 0.25)
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
                    let label = l.kind == 0 ? BRGuns.def(l.gun).name : (l.kind == 1 ? "AMMO" : (l.kind == 2 ? "ARMOR" : (l.kind == 3 ? "MED KIT" : "$\(l.amt)")))
                    ctx.draw(Text(label).font(.system(size: 10, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: sx, y: cy - sz - 8))
                }
            } else {
                drawActor(&ctx, actors[bb.idx], sx: sx, feet: feet, f: f, fog: fog)
            }
        }

        drawViewGun(&ctx, size)

        // crosshair
        let ch = CGPoint(x: W / 2, y: H / 2)
        let cc: Color = lockT != nil ? brc(1, 0.3, 0.3) : .white
        for (ax, ay) in [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)] {
            var p = Path()
            p.move(to: CGPoint(x: ch.x + CGFloat(ax) * 5, y: ch.y + CGFloat(ay) * 5))
            p.addLine(to: CGPoint(x: ch.x + CGFloat(ax) * 12, y: ch.y + CGFloat(ay) * 12))
            ctx.stroke(p, with: .color(cc.opacity(0.9)), lineWidth: 2)
        }
        if hitT > 0 {
            for (ax, ay) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
                var p = Path()
                p.move(to: CGPoint(x: ch.x + CGFloat(ax) * 7, y: ch.y + CGFloat(ay) * 7))
                p.addLine(to: CGPoint(x: ch.x + CGFloat(ax) * 15, y: ch.y + CGFloat(ay) * 15))
                ctx.stroke(p, with: .color(.red), lineWidth: 2.5)
            }
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
        let topY = feet - hpx
        let k = 1 - fog * 0.5
        let c = a.color
        ctx.fill(Path(CGRect(x: sx - wpx * 0.36, y: feet - hpx * 0.46, width: wpx * 0.72, height: hpx * 0.46)), with: .color(brc(0.14 * k, 0.15 * k, 0.2 * k)))
        ctx.fill(Path(roundedRect: CGRect(x: sx - wpx / 2, y: topY + hpx * 0.17, width: wpx, height: hpx * 0.42), cornerRadius: wpx * 0.12), with: .color(brc(c.0 * k, c.1 * k, c.2 * k)))
        let hr = hpx * 0.09
        ctx.fill(Path(ellipseIn: CGRect(x: sx - hr, y: topY + hpx * 0.08 - hr, width: hr * 2, height: hr * 2)), with: .color(brc(0.85 * k, 0.68 * k, 0.55 * k)))
        ctx.fill(Path(CGRect(x: sx - wpx * 0.08, y: topY + hpx * 0.34, width: wpx * 0.9, height: hpx * 0.05)), with: .color(brc(0.08, 0.08, 0.1)))
        if a.hurt > 0 {
            ctx.fill(Path(CGRect(x: sx - wpx / 2, y: topY + hpx * 0.17, width: wpx, height: hpx * 0.42)), with: .color(brc(1, 1, 1, a.hurt * 0.5)))
        }
        if a.flash > 0 {
            let r = hpx * 0.1
            ctx.fill(Path(ellipseIn: CGRect(x: sx + wpx * 0.8 - r, y: topY + hpx * 0.36 - r, width: r * 2, height: r * 2)), with: .color(brc(1, 0.9, 0.4, 0.9)))
        }
        if lockT === a || a.hp < 100 {
            let bw = wpx * 1.3
            let y = topY - 8
            ctx.fill(Path(CGRect(x: sx - bw / 2, y: y, width: bw, height: 4)), with: .color(brc(0, 0, 0, 0.6)))
            ctx.fill(Path(CGRect(x: sx - bw / 2, y: y, width: bw * a.hp / 100, height: 4)), with: .color(brc(0.9, 0.2, 0.2)))
        }
    }

    private func drawViewGun(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let m = me
        guard m.alive, let s = m.slots[m.cur] else { return }
        let img = GunSprites.image(s.gun)
        let mz = GunSprites.muzzle(s.gun)
        let gw = min(size.width * 0.5, size.height * 1.6)
        let gh = gw * 0.625
        let rec: CGFloat = m.flash > 0 ? 1 : 0
        let bob = sin(bobT) * 6 * bobAmp
        let sway = cos(bobT * 0.5) * 5 * bobAmp
        let dip: CGFloat = m.reloadT > 0 ? min(1, m.reloadT * 2.5) * gh * 0.4 : 0
        let spr = ctx.resolve(Image(uiImage: img))
        let flashOn = m.flash > 0
        let rect = CGRect(x: size.width - gw * 0.97 + sway + rec * 10, y: size.height - gh + 6 + dip + bob + rec * 12, width: gw, height: gh)
        ctx.draw(spr, in: rect)
        if flashOn {
            let p = CGPoint(x: rect.minX + mz.x * gw, y: rect.minY + mz.y * gh)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 30, y: p.y - 30, width: 60, height: 60)), with: .color(.yellow.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 14, y: p.y - 14, width: 28, height: 28)), with: .color(.white.opacity(0.95)))
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
        let holdPhase = (time - CGFloat(stage) * (BREngine.hold + BREngine.shrink)) < BREngine.hold
        ctx.drawLayer { l in
            l.clip(to: disc)
            l.fill(disc, with: .color(brc(0.4, 0.5, 0.34)))
            l.translateBy(x: mc.x, y: mc.y)
            l.rotate(by: .radians(Double(-m.ang - .pi / 2)))
            l.scaleBy(x: sc, y: sc)
            l.translateBy(x: -m.p.x, y: -m.p.y)
            // water
            let step: CGFloat = 60
            var x = floor((m.p.x - half) / step) * step
            while x < m.p.x + half {
                var y = floor((m.p.y - half) / step) * step
                while y < m.p.y + half {
                    if BRWorld.water(CGPoint(x: x + step / 2, y: y + step / 2)) {
                        l.fill(Path(CGRect(x: x, y: y, width: step + 1, height: step + 1)), with: .color(brc(0.18, 0.4, 0.62)))
                    }
                    y += step
                }
                x += step
            }
            for (pr, pc) in world.patches where abs(pr.midX - m.p.x) < half + pr.width / 2 && abs(pr.midY - m.p.y) < half + pr.height / 2 {
                l.fill(Path(pr), with: .color(brc(pc.0, pc.1, pc.2, 0.7)))
            }
            for (ra, rb) in world.roadSegs {
                var rp = Path()
                rp.move(to: ra)
                rp.addLine(to: rb)
                l.stroke(rp, with: .color(brc(0.88, 0.85, 0.72)), lineWidth: 46)
            }
            for rw in world.runways where abs(rw.midX - m.p.x) < half + 1200 && abs(rw.midY - m.p.y) < half + 200 {
                l.fill(Path(rw), with: .color(brc(0.3, 0.3, 0.32)))
            }
            for b in world.blds where abs(b.r.midX - m.p.x) < half + 300 && abs(b.r.midY - m.p.y) < half + 300 {
                l.fill(Path(b.r), with: .color(brc(0.78, 0.76, 0.7)))
                l.stroke(Path(b.r), with: .color(brc(0.25, 0.25, 0.28)), lineWidth: 5)
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
            for a in actors where a.alive && !a.isMe && a.ping > 0 {
                let r = 6 / sc
                l.fill(Path(ellipseIn: CGRect(x: a.p.x - r, y: a.p.y - r, width: r * 2, height: r * 2)), with: .color(brc(1, 0.25, 0.25, min(1, a.ping))))
            }
        }
        // vision cone
        var cone = Path()
        cone.move(to: mc)
        let a0: CGFloat = -.pi / 2 - BREngine.fov / 2
        let a1: CGFloat = -.pi / 2 + BREngine.fov / 2
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
