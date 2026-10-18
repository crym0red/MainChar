import SwiftUI

extension BREngine {
    func drawExtraBill(_ ctx: inout GraphicsContext, kind: Int, idx: Int, d: CGFloat, sx: CGFloat, feet: CGFloat, f: CGFloat, fog: CGFloat, rel: CGFloat) {
        let m = me
        switch kind {
        case 3:
            let c = brc(0.2, 0.9, 1)
            let top = feet - 260 * f
            ctx.fill(Path(CGRect(x: sx - 7 * f, y: top, width: 14 * f, height: 260 * f)),
                     with: .linearGradient(Gradient(colors: [c.opacity(0), c.opacity(0.5)]), startPoint: CGPoint(x: sx, y: top), endPoint: CGPoint(x: sx, y: feet)))
            let bw = 26 * f, bh = 30 * f
            ctx.fill(Path(roundedRect: CGRect(x: sx - bw / 2, y: feet - bh, width: bw, height: bh), cornerRadius: 3 * f), with: .color(brc(0.12, 0.14, 0.18)))
            ctx.fill(Path(CGRect(x: sx - bw / 2 + 3 * f, y: feet - bh + 4 * f, width: bw - 6 * f, height: bh * 0.4)), with: .color(c))
            ctx.draw(Text("$").font(.system(size: max(8, 14 * f), weight: .heavy)).foregroundColor(.black), at: CGPoint(x: sx, y: feet - bh + 4 * f + bh * 0.2))
            if d < 420 {
                ctx.draw(Text("BUY STATION").font(.system(size: 10, weight: .heavy)).foregroundColor(c), at: CGPoint(x: sx, y: feet - bh - 10))
            }
        case 4:
            let v = vehicles[idx]
            let dx = v.p.x - m.p.x, dy = v.p.y - m.p.y
            let vrel = brWrap(v.ang - atan2(dy, dx))
            let cs = abs(cos(vrel)), sn = abs(sin(vrel))
            let k = 1 - fog * 0.4
            if v.kind == 0 {
                let w = (74 * sn + 36 * cs) * f
                let bh = 22 * f
                // wheels
                let wheelC = brc(0.05, 0.05, 0.06)
                for o in [-0.42, 0.42] {
                    ctx.fill(Path(ellipseIn: CGRect(x: sx + CGFloat(o) * w - 7 * f, y: feet - 12 * f, width: 14 * f, height: 12 * f)), with: .color(wheelC))
                }
                ctx.fill(Path(roundedRect: CGRect(x: sx - w / 2, y: feet - 12 * f - bh, width: w, height: bh), cornerRadius: 3 * f), with: .color(brc(0.34 * k, 0.4 * k, 0.24 * k)))
                let cw = w * (0.45 + 0.1 * cs)
                ctx.fill(Path(roundedRect: CGRect(x: sx - cw / 2 + (sn > 0.5 ? -w * 0.08 : 0), y: feet - 12 * f - bh - 15 * f, width: cw, height: 15 * f), cornerRadius: 3 * f), with: .color(brc(0.28 * k, 0.34 * k, 0.2 * k)))
                ctx.fill(Path(CGRect(x: sx - cw / 2 + 3 * f + (sn > 0.5 ? -w * 0.08 : 0), y: feet - 12 * f - bh - 12 * f, width: cw - 6 * f, height: 8 * f)), with: .color(brc(0.55, 0.72, 0.85, 0.85)))
                if cs > 0.6 {
                    let lc = vrel > 0 && abs(vrel) > .pi / 2 ? brc(1, 0.95, 0.6) : brc(0.9, 0.15, 0.1)
                    for o in [-0.32, 0.32] {
                        ctx.fill(Path(ellipseIn: CGRect(x: sx + CGFloat(o) * w - 3 * f, y: feet - 12 * f - bh * 0.6, width: 6 * f, height: 5 * f)), with: .color(lc))
                    }
                }
            } else {
                let w = (80 * sn + 34 * cs) * f
                var hull = Path()
                hull.move(to: CGPoint(x: sx - w / 2, y: feet - 12 * f))
                hull.addLine(to: CGPoint(x: sx + w / 2, y: feet - 12 * f))
                hull.addLine(to: CGPoint(x: sx + w * 0.38, y: feet))
                hull.addLine(to: CGPoint(x: sx - w * 0.38, y: feet))
                hull.closeSubpath()
                ctx.fill(hull, with: .color(brc(0.85 * k, 0.86 * k, 0.88 * k)))
                ctx.fill(Path(roundedRect: CGRect(x: sx - w * 0.2, y: feet - 26 * f, width: w * 0.4, height: 14 * f), cornerRadius: 2 * f), with: .color(brc(0.25 * k, 0.4 * k, 0.6 * k)))
            }
            if d < 220 {
                ctx.draw(Text("ENTER").font(.system(size: 10, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: sx, y: feet - 50 * f - 8))
            }
        case 5:
            let t = throwsA[idx]
            let c: Color = t.kind == 0 ? brc(0.25, 0.35, 0.2) : (t.kind == 1 ? brc(0.65, 0.65, 0.68) : brc(0.95, 0.95, 0.85))
            let r = max(1.5, 4 * f)
            ctx.fill(Path(ellipseIn: CGRect(x: sx - r, y: feet - t.z * f - r * 1.5, width: r * 2, height: r * 2)), with: .color(c))
        case 6:
            let sm = smokes[idx]
            let age = 11 - sm.t
            let grow = min(1, age / 1.2)
            let fade = min(1, max(0, sm.t / 2.0))
            let r = 80 * grow
            for i in 0..<6 {
                let ang = CGFloat(i) * 1.05 + CGFloat(idx)
                let ox = cos(ang) * r * 0.42
                let rr = r * (0.55 + 0.12 * CGFloat(i % 3))
                let cy = feet - (r * 0.55 + sin(ang) * r * 0.2) * f
                ctx.fill(Path(ellipseIn: CGRect(x: sx + ox * f * 0.9 - rr * f, y: cy - rr * f, width: rr * 2 * f, height: rr * 2 * f)), with: .color(brc(0.8, 0.8, 0.82, 0.5 * fade)))
            }
        default:
            let b = blasts[idx]
            if b.kind == 0 {
                let k = 1 - b.t / 0.55
                let r = (50 + 90 * k) * f
                let cy = feet - 45 * f
                ctx.fill(Path(ellipseIn: CGRect(x: sx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(brc(1, 0.5, 0.1, 0.85 * (1 - k))))
                ctx.fill(Path(ellipseIn: CGRect(x: sx - r * 0.6, y: cy - r * 0.6, width: r * 1.2, height: r * 1.2)), with: .color(brc(1, 0.9, 0.4, 0.9 * (1 - k))))
                ctx.fill(Path(ellipseIn: CGRect(x: sx - r * 1.1, y: cy - r * 1.4, width: r * 2.2, height: r * 1.5)), with: .color(brc(0.2, 0.2, 0.22, 0.4 * k * (1 - k) * 4)))
            } else if b.kind == 3 || b.kind == 4 {
                let life: CGFloat = b.kind == 3 ? 1.0 : 0.3
                let k = 1 - b.t / life
                let big = b.kind == 3
                let r = (big ? 30 + 55 * k : 4 + 8 * k)
                for i in 0..<(big ? 6 : 2) {
                    let ang = CGFloat(i) * 1.1 + CGFloat(idx)
                    let ox = cos(ang) * r * 0.6
                    let oy = sin(ang) * r * 0.25 + k * (big ? 25 : 4)
                    let rr = r * (0.55 + 0.1 * CGFloat(i % 3))
                    ctx.fill(Path(ellipseIn: CGRect(x: sx + ox * f - rr * f, y: feet - (20 + oy) * f - rr * f, width: rr * 2 * f, height: rr * 2 * f)),
                             with: .color(brc(0.62, 0.57, 0.5, 0.55 * (1 - k))))
                }
            } else {
                let k = 1 - b.t / 0.35
                let r = (30 + 60 * k) * f
                ctx.fill(Path(ellipseIn: CGRect(x: sx - r, y: feet - 40 * f - r, width: r * 2, height: r * 2)), with: .color(brc(1, 1, 1, 0.9 * (1 - k))))
            }
        }
    }

    func drawNums(_ ctx: inout GraphicsContext, _ size: CGSize, _ hz: CGFloat, _ focal: CGFloat, _ eye: CGFloat) {
        let m = me
        for n in nums {
            let dx = n.p.x - m.p.x, dy = n.p.y - m.p.y
            let rel = brWrap(atan2(dy, dx) - m.ang)
            if abs(rel) > curFov / 2 + 0.2 { continue }
            let d = hypot(dx, dy)
            let perp = d * cos(rel)
            if perp < 10 { continue }
            let f = focal / perp
            let age = 0.9 - n.t
            let z = 80 + age * 55
            let sx = size.width / 2 + tan(rel) * focal
            let sy = hz + (eye - z) * f
            let a = min(1, n.t / 0.4)
            let col: Color = n.head ? brc(1, 0.35, 0.2, a) : brc(1, 1, 1, a)
            ctx.draw(Text("\(n.v)").font(.system(size: n.head ? 17 : 13, weight: .heavy)).foregroundColor(col), at: CGPoint(x: sx, y: sy))
        }
    }

    func drawPings(_ ctx: inout GraphicsContext, _ size: CGSize, _ hz: CGFloat, _ focal: CGFloat, _ eye: CGFloat) {
        let m = me
        for pg in pings {
            let dx = pg.p.x - m.p.x, dy = pg.p.y - m.p.y
            let rel = brWrap(atan2(dy, dx) - m.ang)
            if abs(rel) > curFov / 2 + 0.1 { continue }
            let d = hypot(dx, dy)
            let sx = size.width / 2 + tan(rel) * focal
            let perp = max(20, d * cos(rel))
            let sy = hz + (eye - 95) * (focal / perp)
            let c = pg.kind == 1 ? brc(1, 0.3, 0.25) : brc(0.3, 0.9, 1)
            let s: CGFloat = 9 + sin(time * 6) * 1.5
            var dia = Path()
            dia.move(to: CGPoint(x: sx, y: sy - s))
            dia.addLine(to: CGPoint(x: sx + s, y: sy))
            dia.addLine(to: CGPoint(x: sx, y: sy + s))
            dia.addLine(to: CGPoint(x: sx - s, y: sy))
            dia.closeSubpath()
            ctx.fill(dia, with: .color(c.opacity(0.35)))
            ctx.stroke(dia, with: .color(c), lineWidth: 2)
            ctx.draw(Text("\(Int(d * 0.2))m").font(.system(size: 10, weight: .heavy)).foregroundColor(c), at: CGPoint(x: sx, y: sy + s + 9))
        }
    }

    func drawCockpit(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let W = size.width, H = size.height
        guard inVeh >= 0, inVeh < vehicles.count else { return }
        let v = vehicles[inVeh]
        if v.kind == 0 {
            var hood = Path()
            hood.move(to: CGPoint(x: W * 0.12, y: H))
            hood.addLine(to: CGPoint(x: W * 0.32, y: H * 0.8))
            hood.addLine(to: CGPoint(x: W * 0.68, y: H * 0.8))
            hood.addLine(to: CGPoint(x: W * 0.88, y: H))
            hood.closeSubpath()
            ctx.fill(hood, with: .linearGradient(Gradient(colors: [brc(0.3, 0.36, 0.22), brc(0.2, 0.25, 0.15)]), startPoint: CGPoint(x: W / 2, y: H * 0.8), endPoint: CGPoint(x: W / 2, y: H)))
            ctx.stroke(Path(CGRect(x: W * 0.2, y: H * 0.87, width: W * 0.6, height: 1)), with: .color(brc(0, 0, 0, 0.3)), lineWidth: 1)
            // wheel
            var w = ctx
            w.translateBy(x: W / 2, y: H * 1.02)
            w.rotate(by: .radians(Double(steer * 0.9)))
            let r = H * 0.26
            w.stroke(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(brc(0.06, 0.06, 0.07)), lineWidth: 9)
            w.fill(Path(CGRect(x: -r, y: -3, width: r * 2, height: 6)), with: .color(brc(0.06, 0.06, 0.07)))
            w.fill(Path(CGRect(x: -3, y: -r, width: 6, height: r)), with: .color(brc(0.06, 0.06, 0.07)))
        } else {
            var bow = Path()
            bow.move(to: CGPoint(x: W * 0.18, y: H))
            bow.addLine(to: CGPoint(x: W * 0.5, y: H * 0.78))
            bow.addLine(to: CGPoint(x: W * 0.82, y: H))
            bow.closeSubpath()
            ctx.fill(bow, with: .linearGradient(Gradient(colors: [brc(0.9, 0.9, 0.92), brc(0.6, 0.62, 0.68)]), startPoint: CGPoint(x: W / 2, y: H * 0.78), endPoint: CGPoint(x: W / 2, y: H)))
        }
    }

    func drawAirOverlay(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let W = size.width, H = size.height
        if phase == 2 && chute {
            ctx.drawLayer { l in
                l.clip(to: Path(CGRect(x: 0, y: 0, width: W, height: H * 0.34)))
                let e = Path(ellipseIn: CGRect(x: W * 0.06, y: -H * 0.42, width: W * 0.88, height: H * 0.7))
                l.fill(e, with: .color(brc(0.92, 0.3, 0.18)))
                for i in 0..<8 where i % 2 == 0 {
                    let x0 = W * 0.06 + W * 0.88 * CGFloat(i) / 8
                    l.fill(Path(CGRect(x: x0, y: 0, width: W * 0.88 / 8, height: H * 0.34)), with: .color(brc(0.97, 0.95, 0.9, 0.9)))
                }
                l.stroke(e, with: .color(brc(0.2, 0.05, 0.03)), lineWidth: 3)
            }
            for i in 0..<5 {
                let x0 = W * (0.14 + 0.18 * CGFloat(i))
                var ln = Path()
                ln.move(to: CGPoint(x: x0, y: H * 0.26))
                ln.addLine(to: CGPoint(x: W / 2 + (x0 - W / 2) * 0.2, y: H * 1.05))
                ctx.stroke(ln, with: .color(brc(0.1, 0.1, 0.1, 0.45)), lineWidth: 1)
            }
        } else if phase == 2 {
            for i in 0..<14 {
                let s = CGFloat(i) * 7.31 + time * 4
                let x = (sin(s) * 0.5 + 0.5) * W
                let y0 = (cos(s * 1.7) * 0.5 + 0.5) * H
                let len = 40 + 60 * CGFloat(i % 3)
                var ln = Path()
                ln.move(to: CGPoint(x: x, y: y0))
                ln.addLine(to: CGPoint(x: x + (x - W / 2) * 0.1, y: y0 + len))
                ctx.stroke(ln, with: .color(brc(1, 1, 1, 0.25)), lineWidth: 1.5)
            }
        }
    }

    func drawMapExtras(_ l: inout GraphicsContext, _ sc: CGFloat) {
        let r = 5 / sc
        for st in stations {
            l.fill(Path(CGRect(x: st.p.x - r, y: st.p.y - r, width: r * 2, height: r * 2)), with: .color(brc(0.2, 0.9, 1)))
        }
        for v in vehicles where v.hp > 0 {
            l.fill(Path(ellipseIn: CGRect(x: v.p.x - r * 0.8, y: v.p.y - r * 0.8, width: r * 1.6, height: r * 1.6)), with: .color(brc(1, 0.85, 0.2)))
        }
        for pg in pings {
            let rr = (8 + sin(time * 6) * 2) / sc
            l.stroke(Path(ellipseIn: CGRect(x: pg.p.x - rr, y: pg.p.y - rr, width: rr * 2, height: rr * 2)), with: .color(pg.kind == 1 ? brc(1, 0.3, 0.25) : brc(0.3, 0.9, 1)), lineWidth: 2 / sc)
        }
        if uavT > 0 {
            for a in actors where a.alive && !a.isMe && a.team != 0 && !a.air && a.team != 99 {
                l.fill(Path(ellipseIn: CGRect(x: a.p.x - r, y: a.p.y - r, width: r * 2, height: r * 2)), with: .color(brc(1, 0.25, 0.25)))
            }
        }
        if phase == 1 {
            var ln = Path()
            ln.move(to: planeS)
            ln.addLine(to: CGPoint(x: planeS.x + planeD.dx * 6800, y: planeS.y + planeD.dy * 6800))
            l.stroke(ln, with: .color(brc(1, 1, 1, 0.7)), style: StrokeStyle(lineWidth: 2 / sc, dash: [14 / sc, 10 / sc]))
        }
    }

    func reloadSettings() {
        sensMul = BRMeta.f("br.sens", 1)
        adsMul = BRMeta.f("br.ads", 1)
        lefty = UserDefaults.standard.bool(forKey: "br.lefty")
        showFPS = UserDefaults.standard.object(forKey: "br.fps") as? Bool ?? true
        BRAudio.shared.volume = Float(BRMeta.f("br.vol", 0.8))
    }
}
