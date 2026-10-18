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

        // sky + ground
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: hz + 1)),
                 with: .linearGradient(Gradient(colors: [brc(0.3, 0.52, 0.82), brc(0.8, 0.88, 0.95)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: hz)))
        ctx.fill(Path(CGRect(x: 0, y: hz, width: W, height: H - hz + 1)),
                 with: .linearGradient(Gradient(colors: [brc(0.55, 0.62, 0.45), brc(0.27, 0.36, 0.22)]), startPoint: CGPoint(x: 0, y: hz), endPoint: CGPoint(x: 0, y: H)))

        // walls
        let cols = 150
        let cw = W / CGFloat(cols)
        var zb = [CGFloat](repeating: 9999, count: cols)
        let nearW = world.near(m.p, 1100)
        for i in 0..<cols {
            let off = atan((CGFloat(i) + 0.5 - CGFloat(cols) / 2) * cw / focal)
            let a = m.ang + off
            let dx = cos(a), dy = sin(a)
            var bt: CGFloat = 1100
            var bi = -1
            var bs = false
            for wi in nearW {
                if let h = brRay(m.p, dx, dy, world.walls[wi].r), h.0 < bt {
                    bt = h.0
                    bi = wi
                    bs = h.1
                }
            }
            if bi < 0 { continue }
            let perp = max(bt * cos(off), 1)
            zb[i] = perp
            let w = world.walls[bi]
            let top = hz - (w.h - eye) * focal / perp
            let bot = hz + eye * focal / perp
            let shade: CGFloat = bs ? 1 : 0.8
            let fog = min(1, bt / 1100) * 0.75
            let r = w.c.0 * shade * (1 - fog) + 0.74 * fog
            let g = w.c.1 * shade * (1 - fog) + 0.83 * fog
            let b = w.c.2 * shade * (1 - fog) + 0.9 * fog
            let hh = bot - top
            ctx.fill(Path(CGRect(x: CGFloat(i) * cw, y: top, width: cw + 0.6, height: hh)), with: .color(brc(r, g, b)))
            ctx.fill(Path(CGRect(x: CGFloat(i) * cw, y: top, width: cw + 0.6, height: hh * 0.07)), with: .color(brc(1, 1, 1, 0.18)))
            ctx.fill(Path(CGRect(x: CGFloat(i) * cw, y: bot - hh * 0.1, width: cw + 0.6, height: hh * 0.1)), with: .color(brc(0, 0, 0, 0.2)))
            if w.h >= 100 && w.h < 200 {
                ctx.fill(Path(CGRect(x: CGFloat(i) * cw, y: top + hh * 0.38, width: cw + 0.6, height: hh * 0.16)), with: .color(brc(0.12, 0.18, 0.26, 0.45 * (1 - fog))))
            }
        }

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
                ctx.fill(Path(CGRect(x: sx - 4 * f, y: feet - 46 * f, width: 8 * f, height: 46 * f)), with: .color(brc(0.35, 0.24, 0.14)))
                let cr = 30 * f
                ctx.fill(Path(ellipseIn: CGRect(x: sx - cr, y: feet - 78 * f - cr, width: cr * 2, height: cr * 2)),
                         with: .color(brc(0.16 + 0.5 * fog, 0.38 + 0.4 * fog, 0.17 + 0.5 * fog)))
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
        let gw = min(size.width * 0.4, size.height * 1.5)
        let gh = gw / 2
        let rec: CGFloat = m.flash > 0 ? 1 : 0
        let bob = sin(bobT) * 6 * bobAmp
        let dip: CGFloat = m.reloadT > 0 ? min(1, m.reloadT * 2.5) * gh * 0.35 : 0
        let spr = ctx.resolve(Image(uiImage: img))
        let flashOn = m.flash > 0
        let reloading = m.reloadT > 0
        ctx.drawLayer { l in
            l.translateBy(x: size.width * 0.93, y: size.height + 2 + dip + bob)
            l.rotate(by: .degrees(reloading ? 16 : 8))
            l.translateBy(x: rec * 16, y: rec * 8)
            let rect = CGRect(x: -gw, y: -gh, width: gw, height: gh)
            l.draw(spr, in: rect)
            if flashOn {
                let p = CGPoint(x: rect.minX + mz.x * gw, y: rect.minY + mz.y * gh)
                l.fill(Path(ellipseIn: CGRect(x: p.x - 44, y: p.y - 44, width: 88, height: 88)), with: .color(.yellow.opacity(0.85)))
                l.fill(Path(ellipseIn: CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)), with: .color(.white.opacity(0.95)))
            }
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
        let mc = CGPoint(x: size.width - 80, y: 86)
        let R: CGFloat = 62
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
