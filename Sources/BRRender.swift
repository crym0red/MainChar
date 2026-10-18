import SwiftUI

extension BREngine {
    private func hazeMix(_ c: BRCol, _ k: CGFloat, _ fog: CGFloat) -> Color {
        brc(c.0 * k * (1 - fog) + 0.74 * fog, c.1 * k * (1 - fog) + 0.83 * fog, c.2 * k * (1 - fog) + 0.9 * fog)
    }

    // sky, mountains, floor, walls. Returns the per-column depth buffer.
    func drawBase(_ ctx: inout GraphicsContext, _ size: CGSize, _ hz: CGFloat, _ focal: CGFloat) -> [CGFloat] {
        let m = me
        let W = size.width, H = size.height
        let eye = BREngine.eyeH
        let sc = H / 390

        // sky
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: hz + 1)),
                 with: .linearGradient(Gradient(colors: [brc(0.26, 0.48, 0.82), brc(0.55, 0.74, 0.92), brc(0.82, 0.9, 0.96)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: hz)))
        // sun
        let sunRel = brWrap(0.7 - m.ang)
        if abs(sunRel) < BREngine.fov / 2 + 0.3 {
            let sx = W / 2 + tan(sunRel) * focal
            let sy = hz - 130 * sc
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 60, y: sy - 60, width: 120, height: 120)), with: .color(brc(1, 0.95, 0.75, 0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 16, y: sy - 16, width: 32, height: 32)), with: .color(brc(1, 0.98, 0.85, 0.95)))
        }
        // clouds
        let cl: [CGFloat] = [0.2, 1.1, 1.9, 2.8, 3.6, 4.4, 5.3, 6.0]
        for (i, ca) in cl.enumerated() {
            let rel = brWrap(ca - m.ang)
            if abs(rel) > BREngine.fov / 2 + 0.5 { continue }
            let cx = W / 2 + tan(rel) * focal
            let cy = hz - (90 + CGFloat(i % 3) * 36) * sc
            let cwid: CGFloat = (120 + CGFloat(i % 4) * 30) * sc
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cwid / 2, y: cy - 12 * sc, width: cwid, height: 24 * sc)), with: .color(brc(1, 1, 1, 0.55)))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - cwid * 0.28, y: cy - 22 * sc, width: cwid * 0.5, height: 22 * sc)), with: .color(brc(1, 1, 1, 0.6)))
        }
        // mountains
        for layer in 0..<2 {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: hz + 1))
            var x: CGFloat = 0
            while x <= W + 8 {
                let a = m.ang + atan((x - W / 2) / focal)
                var hgt: CGFloat
                if layer == 0 {
                    hgt = 38 + 30 * sin(a * 3 + 1) + 16 * sin(a * 7 + 2) + 8 * sin(a * 13)
                } else {
                    hgt = 14 + 12 * sin(a * 5 + 4) + 7 * sin(a * 11 + 1)
                }
                p.addLine(to: CGPoint(x: x, y: hz - max(2, hgt) * sc))
                x += 8
            }
            p.addLine(to: CGPoint(x: W + 8, y: hz + 1))
            p.closeSubpath()
            ctx.fill(p, with: .color(layer == 0 ? brc(0.56, 0.68, 0.8) : brc(0.45, 0.6, 0.52)))
        }

        // ground base
        ctx.fill(Path(CGRect(x: 0, y: hz, width: W, height: H - hz + 1)),
                 with: .linearGradient(Gradient(colors: [brc(0.62, 0.72, 0.58), brc(0.3, 0.42, 0.24)]), startPoint: CGPoint(x: 0, y: hz), endPoint: CGPoint(x: 0, y: H)))
        // floor casting
        let nx = 60
        let cwf = W / CGFloat(nx)
        var cs = [CGFloat](repeating: 0, count: nx)
        var sn = [CGFloat](repeating: 0, count: nx)
        var ik = [CGFloat](repeating: 1, count: nx)
        for i in 0..<nx {
            let off = atan((CGFloat(i) + 0.5 - CGFloat(nx) / 2) * cwf / focal)
            cs[i] = cos(m.ang + off)
            sn[i] = sin(m.ang + off)
            ik[i] = 1 / cos(off)
        }
        let rows = 26
        let dmin: CGFloat = 45, dmax: CGFloat = 1300
        var prevD = dmin
        for r in 1...rows {
            let d = dmin * pow(dmax / dmin, CGFloat(r) / CGFloat(rows))
            let yNear = hz + eye * focal / prevD
            let yFar = hz + eye * focal / d
            let mid = (prevD + d) / 2
            prevD = d
            if yFar > H { continue }
            let fog = pow(min(1, mid / 1300), 1.1) * 0.8
            for i in 0..<nx {
                let dist = mid * ik[i]
                let c = world.ground(CGPoint(x: m.p.x + cs[i] * dist, y: m.p.y + sn[i] * dist))
                ctx.fill(Path(CGRect(x: CGFloat(i) * cwf, y: yFar, width: cwf + 1, height: min(yNear, H) - yFar + 1)), with: .color(hazeMix(c, 1, fog)))
            }
        }

        // walls
        let cols = max(120, Int(W / 3))
        let cw = W / CGFloat(cols)
        var zb = [CGFloat](repeating: 9999, count: cols)
        let nearW = world.near(m.p, 1000)
        for i in 0..<cols {
            let off = atan((CGFloat(i) + 0.5 - CGFloat(cols) / 2) * cw / focal)
            let a = m.ang + off
            let dx = cos(a), dy = sin(a)
            var bt: CGFloat = 1000
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
            let f = focal / perp
            let top = hz - (w.h - eye) * f
            let bot = hz + eye * f
            let shade: CGFloat = bs ? 1 : 0.78
            let fog = pow(min(1, bt / 1000), 1.2) * 0.75
            let hh = bot - top
            let x = CGFloat(i) * cw
            ctx.fill(Path(CGRect(x: x, y: top, width: cw + 0.6, height: hh)), with: .color(hazeMix(w.c, shade, fog)))
            // roof lip
            ctx.fill(Path(CGRect(x: x, y: top, width: cw + 0.6, height: max(1.5, 5 * f))), with: .color(brc(1, 1, 1, 0.22 * (1 - fog))))
            // base shadow
            ctx.fill(Path(CGRect(x: x, y: bot - 6 * f, width: cw + 0.6, height: 6 * f)), with: .color(brc(0, 0, 0, 0.22)))
            if w.h >= 95 && bt < 800 {
                let hx = m.p.x + dx * bt, hy = m.p.y + dy * bt
                let u = abs(bs ? hy : hx)
                let cell = fmod(u, 52)
                if cell > 13 && cell < 39 {
                    let floors = Int((w.h - 14) / 60)
                    if floors > 0 {
                        for fl in 0..<floors {
                            let z0 = CGFloat(fl) * 60 + 22
                            let z1 = z0 + 28
                            if z1 > w.h - 8 { continue }
                            let y0 = hz - (z1 - eye) * f
                            let y1 = hz - (z0 - eye) * f
                            ctx.fill(Path(CGRect(x: x, y: y0, width: cw + 0.6, height: y1 - y0)), with: .color(hazeMix((0.14, 0.2, 0.28), 1, fog)))
                            ctx.fill(Path(CGRect(x: x, y: y0, width: cw + 0.6, height: (y1 - y0) * 0.3)), with: .color(brc(0.7, 0.85, 1, 0.22 * (1 - fog))))
                        }
                    }
                }
            }
        }
        return zb
    }
}
