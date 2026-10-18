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
        if abs(sunRel) < curFov / 2 + 0.3 {
            let sx = W / 2 + tan(sunRel) * focal
            let sy = hz - 130 * sc
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 60, y: sy - 60, width: 120, height: 120)), with: .color(brc(1, 0.95, 0.75, 0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 16, y: sy - 16, width: 32, height: 32)), with: .color(brc(1, 0.98, 0.85, 0.95)))
        }
        // clouds
        let cl: [CGFloat] = [0.2, 1.1, 1.9, 2.8, 3.6, 4.4, 5.3, 6.0]
        for (i, ca) in cl.enumerated() {
            let rel = brWrap(ca - m.ang)
            if abs(rel) > curFov / 2 + 0.5 { continue }
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
                 with: .linearGradient(Gradient(colors: [brc(0.66, 0.76, 0.66), brc(0.3, 0.42, 0.24)]), startPoint: CGPoint(x: 0, y: hz), endPoint: CGPoint(x: 0, y: H)))
        drawFloor(&ctx, W, H, hz, focal)

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
            let tintH = sin(CGFloat(bi) * 12.9898) * 43758.5453
            let shade: CGFloat = (bs ? 1 : 0.78) * (0.93 + 0.12 * (tintH - floor(tintH)))
            let fog = pow(min(1, bt / 1000), 1.2) * 0.75
            let hh = bot - top
            let x = CGFloat(i) * cw
            ctx.fill(Path(CGRect(x: x, y: top, width: cw + 0.6, height: hh)), with: .color(hazeMix(w.c, shade, fog)))
            // roof lip
            ctx.fill(Path(CGRect(x: x, y: top, width: cw + 0.6, height: max(1.5, 5 * f))), with: .color(brc(1, 1, 1, 0.22 * (1 - fog))))
            // base shadow
            ctx.fill(Path(CGRect(x: x, y: bot - 6 * f, width: cw + 0.6, height: 6 * f)), with: .color(brc(0, 0, 0, 0.22)))
            if w.h >= 70 && bt < 900 {
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

    private func drawFloor(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ hz: CGFloat, _ focal: CGFloat) {
        let m = me
        let y0 = max(0, hz)
        if y0 >= H - 1 { return }
        let bw = 170, bh = 70
        let span = H - y0
        let eye = BREngine.eyeH
        var cs = [CGFloat](repeating: 0, count: bw)
        var sn = [CGFloat](repeating: 0, count: bw)
        var ik = [CGFloat](repeating: 1, count: bw)
        for i in 0..<bw {
            let off = atan((CGFloat(i) + 0.5 - CGFloat(bw) / 2) * (W / CGFloat(bw)) / focal)
            cs[i] = cos(m.ang + off)
            sn[i] = sin(m.ang + off)
            ik[i] = 1 / cos(off)
        }
        let hr: CGFloat = 0.74 * 255, hg: CGFloat = 0.83 * 255, hb: CGFloat = 0.9 * 255
        for j in 0..<bh {
            let sy = y0 + (CGFloat(j) + 0.5) / CGFloat(bh) * span
            let dy = max(0.5, sy - hz)
            let d = eye * focal / dy
            let fog = min(1, pow(min(1, d / 1500), 1.15) * 0.85)
            let k = 1 - fog
            for i in 0..<bw {
                let o = (j * bw + i) * 4
                if d > 1500 {
                    floorBuf[o] = UInt8(hr)
                    floorBuf[o + 1] = UInt8(hg)
                    floorBuf[o + 2] = UInt8(hb)
                    floorBuf[o + 3] = 255
                    continue
                }
                let dist = d * ik[i]
                let c = world.sample(m.p.x + cs[i] * dist, m.p.y + sn[i] * dist)
                floorBuf[o] = UInt8(CGFloat(c.0) * k + hr * fog)
                floorBuf[o + 1] = UInt8(CGFloat(c.1) * k + hg * fog)
                floorBuf[o + 2] = UInt8(CGFloat(c.2) * k + hb * fog)
                floorBuf[o + 3] = 255
            }
        }
        var img: CGImage? = nil
        floorBuf.withUnsafeMutableBytes { raw in
            if let cg = CGContext(data: raw.baseAddress, width: bw, height: bh, bitsPerComponent: 8, bytesPerRow: bw * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                img = cg.makeImage()
            }
        }
        if let img = img {
            ctx.draw(Image(decorative: img, scale: 1).interpolation(.high), in: CGRect(x: 0, y: y0, width: W, height: span + 1))
        }
    }
}
