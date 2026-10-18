import SwiftUI
import UIKit

enum GunSprites {
    private static var cache: [String: UIImage] = [:]

    static func icon(_ id: String) -> UIImage {
        UIImage(named: "gunicon_" + id) ?? image(id)
    }

    static func image(_ id: String) -> UIImage {
        if let c = cache[id] { return c }
        if let a = UIImage(named: "gun_" + id) {
            cache[id] = a
            return a
        }
        let img = render(id)
        cache[id] = img
        return img
    }

    // muzzle position as a fraction of the sprite
    static func muzzle(_ id: String) -> CGPoint { CGPoint(x: 183.0 / 640.0, y: 116.0 / 320.0) }

    // where the 1120x640 sprite sits so its aim point lands on the screen centre
    static func rect(_ size: CGSize) -> CGRect {
        let gw = size.width * 0.70
        let gh = size.height * 0.80
        return CGRect(x: size.width / 2 - 0.2857 * gw, y: size.height / 2 - 0.375 * gh, width: gw, height: gh)
    }

    private static let skinTop = UIColor(red: 0.86, green: 0.67, blue: 0.52, alpha: 1)
    private static let skinBot = UIColor(red: 0.66, green: 0.47, blue: 0.35, alpha: 1)
    private static let sleeveTop = UIColor(red: 0.2, green: 0.24, blue: 0.3, alpha: 1)
    private static let sleeveBot = UIColor(red: 0.1, green: 0.12, blue: 0.16, alpha: 1)
    private static let metalTop = UIColor(white: 0.36, alpha: 1)
    private static let metalBot = UIColor(white: 0.13, alpha: 1)
    private static let darkTop = UIColor(white: 0.2, alpha: 1)
    private static let darkBot = UIColor(white: 0.07, alpha: 1)
    private static let woodTop = UIColor(red: 0.6, green: 0.38, blue: 0.2, alpha: 1)
    private static let woodBot = UIColor(red: 0.32, green: 0.19, blue: 0.09, alpha: 1)

    private static func fillGrad(_ g: CGContext, _ path: UIBezierPath, _ top: UIColor, _ bot: UIColor) {
        g.saveGState()
        g.addPath(path.cgPath)
        g.clip()
        let b = path.bounds
        let cs = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: cs, colors: [top.cgColor, bot.cgColor] as CFArray, locations: [0, 1]) {
            g.drawLinearGradient(grad, start: CGPoint(x: b.midX, y: b.minY), end: CGPoint(x: b.midX, y: b.maxY), options: [])
        }
        g.restoreGState()
        UIColor(white: 0, alpha: 0.55).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    private static func part(_ g: CGContext, _ r: CGRect, _ rad: CGFloat, _ top: UIColor, _ bot: UIColor) {
        let p = UIBezierPath(roundedRect: r, cornerRadius: rad)
        fillGrad(g, p, top, bot)
        let hl = UIBezierPath()
        hl.move(to: CGPoint(x: r.minX + rad, y: r.minY + 2.5))
        hl.addLine(to: CGPoint(x: r.maxX - rad, y: r.minY + 2.5))
        UIColor(white: 1, alpha: 0.28).setStroke()
        hl.lineWidth = 2
        hl.stroke()
    }

    private static func poly(_ g: CGContext, _ pts: [CGPoint], _ top: UIColor, _ bot: UIColor) {
        let p = UIBezierPath()
        p.move(to: pts[0])
        for q in pts.dropFirst() { p.addLine(to: q) }
        p.close()
        fillGrad(g, p, top, bot)
    }

    private static func line(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ c: UIColor) {
        let p = UIBezierPath()
        p.move(to: a)
        p.addLine(to: b)
        p.lineWidth = w
        c.setStroke()
        p.stroke()
    }

    private static func vents(_ r: CGRect, _ n: Int) {
        let step = r.width / CGFloat(n + 1)
        for i in 1...n {
            let x = r.minX + step * CGFloat(i)
            line(CGPoint(x: x, y: r.minY + 12), CGPoint(x: x, y: r.maxY - 12), 5, UIColor(white: 0, alpha: 0.55))
        }
    }

    private static func sleeve(_ g: CGContext, _ pts: [CGPoint]) {
        poly(g, pts, sleeveTop, sleeveBot)
    }

    private static func hand(_ g: CGContext, _ r: CGRect, fingers: Int) {
        part(g, r, min(r.width, r.height) * 0.3, skinTop, skinBot)
        let step = r.height / CGFloat(fingers + 1)
        for i in 1...fingers {
            let y = r.minY + step * CGFloat(i)
            line(CGPoint(x: r.minX + 4, y: y), CGPoint(x: r.minX + r.width * 0.55, y: y), 2, UIColor(red: 0.4, green: 0.26, blue: 0.18, alpha: 0.8))
        }
    }

    private static func render(_ id: String) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 2
        f.opaque = false
        let r = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 320), format: f)
        return r.image { rc in
            let g = rc.cgContext
            switch id {
            case "pistol": pistol(g)
            case "smg": smg(g)
            case "shotgun": shotgun(g)
            default: rifle(g)
            }
        }
    }

    // MARK: detailed helpers

    private static func gfill(_ g: CGContext, _ path: UIBezierPath, _ cols: [UIColor], _ locs: [CGFloat]? = nil, edge: CGFloat = 0.6) {
        g.saveGState()
        g.addPath(path.cgPath)
        g.clip()
        let b = path.bounds
        let cs = CGColorSpaceCreateDeviceRGB()
        let l = locs ?? cols.indices.map { CGFloat($0) / CGFloat(max(1, cols.count - 1)) }
        if let gr = CGGradient(colorsSpace: cs, colors: cols.map { $0.cgColor } as CFArray, locations: l) {
            g.drawLinearGradient(gr, start: CGPoint(x: b.midX, y: b.minY), end: CGPoint(x: b.midX, y: b.maxY), options: [])
        }
        g.restoreGState()
        if edge > 0 {
            UIColor(white: 0, alpha: edge).setStroke()
            path.lineWidth = 1.6
            path.stroke()
        }
    }

    private static func rr(_ r: CGRect, _ c: CGFloat) -> UIBezierPath { UIBezierPath(roundedRect: r, cornerRadius: c) }

    private static func shine(_ r: CGRect, inset: CGFloat = 4, a: CGFloat = 0.45) {
        line(CGPoint(x: r.minX + inset, y: r.minY + 3), CGPoint(x: r.maxX - inset, y: r.minY + 3), 1.6, UIColor(white: 1, alpha: a))
    }

    private static let steel = [UIColor(white: 0.55, alpha: 1), UIColor(white: 0.30, alpha: 1), UIColor(white: 0.16, alpha: 1), UIColor(white: 0.09, alpha: 1)]
    private static let polymer = [UIColor(white: 0.22, alpha: 1), UIColor(white: 0.13, alpha: 1), UIColor(white: 0.07, alpha: 1)]

    private static func finger(_ g: CGContext, _ r: CGRect) {
        let p = rr(r, r.height / 2)
        gfill(g, p, [UIColor(red: 0.92, green: 0.73, blue: 0.58, alpha: 1), UIColor(red: 0.8, green: 0.6, blue: 0.46, alpha: 1), UIColor(red: 0.56, green: 0.39, blue: 0.29, alpha: 1)])
        line(CGPoint(x: r.minX + r.height * 0.5, y: r.minY + 3), CGPoint(x: r.maxX - r.height * 0.5, y: r.minY + 3), 1.6, UIColor(white: 1, alpha: 0.25))
        let nail = rr(CGRect(x: r.minX + 3, y: r.minY + r.height * 0.28, width: r.height * 0.5, height: r.height * 0.4), 3)
        UIColor(red: 0.95, green: 0.82, blue: 0.74, alpha: 0.85).setFill(); nail.fill()
    }

    private static func cuff(_ g: CGContext, _ pts: [CGPoint]) {
        let p = UIBezierPath(); p.move(to: pts[0]); for q in pts.dropFirst() { p.addLine(to: q) }; p.close()
        gfill(g, p, [UIColor(red: 0.3, green: 0.34, blue: 0.24, alpha: 1), UIColor(red: 0.2, green: 0.23, blue: 0.16, alpha: 1), UIColor(red: 0.1, green: 0.12, blue: 0.08, alpha: 1)])
        UIColor(white: 0, alpha: 0.25).setStroke()
        for i in 1..<4 {
            let t = CGFloat(i) / 4
            line(CGPoint(x: pts[0].x + (pts[3].x - pts[0].x) * t, y: pts[0].y + (pts[3].y - pts[0].y) * t), CGPoint(x: pts[1].x + (pts[2].x - pts[1].x) * t, y: pts[1].y + (pts[2].y - pts[1].y) * t), 1.4, UIColor(white: 0, alpha: 0.22))
        }
    }

    private static func stipple(_ r: CGRect, _ step: CGFloat) {
        var y = r.minY + 4
        var row = 0
        while y < r.maxY - 2 {
            var x = r.minX + 4 + (row % 2 == 0 ? 0 : step / 2)
            while x < r.maxX - 2 {
                UIColor(white: 0.42, alpha: 0.55).setFill()
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 2.2, height: 2.2)).fill()
                x += step
            }
            y += step
            row += 1
        }
    }

    // MARK: behind-the-gun (first person) view

    private struct FPV {
        let T: CGPoint, R: CGPoint, s0: CGFloat, s1: CGFloat
        func p(_ t: CGFloat, _ lat: CGFloat, _ z: CGFloat) -> CGPoint {
            let c = CGPoint(x: T.x + (R.x - T.x) * t, y: T.y + (R.y - T.y) * t)
            let s = s0 + (s1 - s0) * t
            return CGPoint(x: c.x + lat * s * 1.7, y: c.y - z * s * 1.3)
        }
        func sc(_ t: CGFloat) -> CGFloat { s0 + (s1 - s0) * t }
    }

    private static let topM = [UIColor(white: 0.62, alpha: 1), UIColor(white: 0.34, alpha: 1)]
    private static let sideM = [UIColor(white: 0.28, alpha: 1), UIColor(white: 0.1, alpha: 1)]
    private static let rearM = [UIColor(white: 0.16, alpha: 1), UIColor(white: 0.05, alpha: 1)]
    private static let polyTop = [UIColor(white: 0.26, alpha: 1), UIColor(white: 0.15, alpha: 1)]
    private static let polySide = [UIColor(white: 0.15, alpha: 1), UIColor(white: 0.07, alpha: 1)]
    private static let polyRear = [UIColor(white: 0.09, alpha: 1), UIColor(white: 0.03, alpha: 1)]
    private static let woodT = [UIColor(red: 0.62, green: 0.4, blue: 0.2, alpha: 1), UIColor(red: 0.46, green: 0.29, blue: 0.14, alpha: 1)]
    private static let woodS = [UIColor(red: 0.4, green: 0.25, blue: 0.12, alpha: 1), UIColor(red: 0.24, green: 0.14, blue: 0.06, alpha: 1)]
    private static let woodR = [UIColor(red: 0.28, green: 0.17, blue: 0.08, alpha: 1), UIColor(red: 0.16, green: 0.09, blue: 0.04, alpha: 1)]

    private static func quad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> UIBezierPath {
        let p = UIBezierPath(); p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.addLine(to: d); p.close(); return p
    }

    private static func blk(_ g: CGContext, _ v: FPV, _ a: CGFloat, _ b: CGFloat, _ hw: CGFloat, _ z0: CGFloat, _ z1: CGFloat, _ top: [UIColor], _ side: [UIColor], _ rear: [UIColor], cx: CGFloat = 0) {
        let l = cx - hw, r = cx + hw
        gfill(g, quad(v.p(a, l, z1), v.p(b, l, z1), v.p(b, l, z0), v.p(a, l, z0)), side)
        gfill(g, quad(v.p(a, l, z1), v.p(a, r, z1), v.p(b, r, z1), v.p(b, l, z1)), top)
        gfill(g, quad(v.p(b, l, z1), v.p(b, r, z1), v.p(b, r, z0), v.p(b, l, z0)), rear)
        line(v.p(a, l, z1), v.p(b, l, z1), 1.4, UIColor(white: 1, alpha: 0.35))
    }

    private static func dot(_ p: CGPoint, _ r: CGFloat, _ c: UIColor) {
        c.setFill(); UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).fill()
    }

    private static func thumb(_ g: CGContext, at p: CGPoint, angle: CGFloat, len: CGFloat, h: CGFloat) {
        g.saveGState()
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: angle)
        finger(g, CGRect(x: -len, y: -h / 2, width: len, height: h))
        g.restoreGState()
    }

    private static func handBack(_ g: CGContext, _ r: CGRect) {
        gfill(g, rr(r, min(r.width, r.height) * 0.4), [UIColor(red: 0.9, green: 0.7, blue: 0.56, alpha: 1), UIColor(red: 0.74, green: 0.54, blue: 0.4, alpha: 1), UIColor(red: 0.52, green: 0.36, blue: 0.27, alpha: 1)])
        for i in 0..<4 {
            let x = r.minX + r.width * (0.22 + 0.17 * CGFloat(i))
            dot(CGPoint(x: x, y: r.minY + r.height * 0.18), 3.6, UIColor(red: 0.62, green: 0.45, blue: 0.34, alpha: 0.7))
        }
    }

    private static let skinC = [UIColor(red: 0.95, green: 0.78, blue: 0.64, alpha: 1), UIColor(red: 0.82, green: 0.62, blue: 0.48, alpha: 1), UIColor(red: 0.6, green: 0.42, blue: 0.32, alpha: 1)]

    private static func limb(_ g: CGContext, _ a: CGPoint, _ b: CGPoint, _ w: CGFloat, sleeve: Bool = false) {
        let p = UIBezierPath(); p.move(to: a); p.addLine(to: b); p.lineCapStyle = .round
        UIColor(white: 0, alpha: 0.5).setStroke(); p.lineWidth = w + 2.4; p.stroke()
        (sleeve ? UIColor(red: 0.26, green: 0.3, blue: 0.19, alpha: 1) : skinC[1]).setStroke(); p.lineWidth = w; p.stroke()
        let h = UIBezierPath(); h.move(to: CGPoint(x: a.x, y: a.y - w * 0.2)); h.addLine(to: CGPoint(x: b.x, y: b.y - w * 0.2)); h.lineCapStyle = .round
        (sleeve ? UIColor(red: 0.4, green: 0.45, blue: 0.3, alpha: 1) : skinC[0]).setStroke(); h.lineWidth = w * 0.42; h.stroke()
        if sleeve {
            for i in 1..<4 {
                let t = CGFloat(i) / 4
                let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                dot(c, w * 0.08, UIColor(white: 0, alpha: 0.25))
            }
        } else {
            dot(CGPoint(x: b.x + (a.x - b.x) * 0.12, y: b.y + (a.y - b.y) * 0.12 - w * 0.12), w * 0.2, UIColor(red: 0.97, green: 0.86, blue: 0.78, alpha: 0.9))
        }
    }

    private static func blob(_ g: CGContext, _ c: CGPoint, _ w: CGFloat, _ h: CGFloat) {
        let r = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        gfill(g, UIBezierPath(ovalIn: r), skinC)
        for i in 0..<4 { dot(CGPoint(x: r.minX + w * (0.2 + 0.2 * CGFloat(i)), y: r.minY + h * 0.2), 2.8, UIColor(red: 0.6, green: 0.44, blue: 0.34, alpha: 0.6)) }
    }

    private static func armsLong(_ g: CGContext, _ v: FPV, leftWrist: CGPoint) {
        limb(g, v.p(1.0, 6, -30), CGPoint(x: 620, y: 360), 70, sleeve: true)
        limb(g, leftWrist, CGPoint(x: 120, y: 380), 64, sleeve: true)
        limb(g, CGPoint(x: 80, y: 372), CGPoint(x: 20, y: 400), 90, sleeve: true)
    }

    private static func handsLong(_ g: CGContext, _ v: FPV, leftT: CGFloat, leftZ: CGFloat) {
        let sc = v.sc(0.9)
        // support hand on the fore-end
        let lc = v.p(leftT, -6, leftZ)
        blob(g, lc, 90, 56)
        for k in 0..<3 { let t = leftT - 0.03 + CGFloat(k) * 0.05; limb(g, v.p(t, -14, leftZ + 2), v.p(t, 12, leftZ + 2), 12 * v.sc(t)) }
        limb(g, v.p(leftT + 0.03, -14, leftZ + 4), v.p(leftT - 0.1, -13, leftZ + 22), 12 * v.sc(leftT))
        // firing hand on the pistol grip, finger on the trigger
        blob(g, v.p(0.98, 4, -32), 58, 92)
        for k in 0..<3 { let z = -24 - CGFloat(k) * 12; limb(g, v.p(0.96, 8, z), v.p(0.87, -11, z), 11 * sc) }
        limb(g, v.p(0.93, 4, -10), v.p(0.8, -8, -4), 8 * sc)
        limb(g, v.p(0.94, -4, -14), v.p(0.86, -12, 4), 10 * sc)
    }

    private static let viewT = CGPoint(x: 183, y: 121)

    private static func pistol(_ g: CGContext) {
        let v = FPV(T: viewT, R: CGPoint(x: 400, y: 218), s0: 0.75, s1: 1.9)
        limb(g, v.p(1.0, 6, -26), CGPoint(x: 620, y: 360), 70, sleeve: true)
        limb(g, v.p(0.84, -30, -34), CGPoint(x: 150, y: 380), 64, sleeve: true)
        limb(g, CGPoint(x: 120, y: 372), CGPoint(x: 20, y: 400), 90, sleeve: true)
        blk(g, v, 0.08, 0.92, 10, -7, 0, polyTop, polySide, polyRear)
        blk(g, v, 0.72, 1.0, 10, -48, -4, polyTop, polySide, polyRear)
        blk(g, v, 0, 0.9, 13, 0, 16, topM, sideM, rearM)
        // slide details
        for i in 0..<6 { let t = 0.72 + CGFloat(i) * 0.028; line(v.p(t, -13, 15), v.p(t, 13, 15), 2.2, UIColor(white: 0, alpha: 0.55)); line(v.p(t, -13, 14), v.p(t, -13, 3), 1.6, UIColor(white: 0, alpha: 0.4)) }
        line(v.p(0.02, 0, 16), v.p(0.88, 0, 16), 1.2, UIColor(white: 1, alpha: 0.35))
        gfill(g, quad(v.p(0.36, -13, 12), v.p(0.62, -13, 12), v.p(0.62, -13, 3), v.p(0.36, -13, 3)), [UIColor(white: 0.02, alpha: 1), UIColor(white: 0.1, alpha: 1)], edge: 0.4)
        gfill(g, quad(v.p(0.42, -13, 8), v.p(0.58, -13, 8), v.p(0.58, -13, 4.5), v.p(0.42, -13, 4.5)), [UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1), UIColor(red: 0.5, green: 0.35, blue: 0.1, alpha: 1)], edge: 0.2)
        blk(g, v, 0.01, 0.06, 2.2, 16, 22, topM, sideM, rearM)
        dot(v.p(0.035, 0, 21.5), 1.6, .white)
        for cx in [-8.5, 8.5] as [CGFloat] {
            blk(g, v, 0.83, 0.89, 2.6, 16, 21, topM, sideM, rearM, cx: cx)
            dot(v.p(0.89, cx, 18.5), 1.9, .white)
        }
        // trigger guard
        let tg = UIBezierPath(); tg.move(to: v.p(0.5, -10, -7)); tg.addLine(to: v.p(0.5, -10, -17)); tg.addLine(to: v.p(0.72, -10, -17)); tg.addLine(to: v.p(0.72, -10, -7))
        UIColor(white: 0.06, alpha: 1).setStroke(); tg.lineWidth = 4; tg.stroke()
        // grip stipple on left face
        for i in 0..<5 { for j in 0..<4 { dot(v.p(0.76 + CGFloat(j) * 0.05, -10, -10 - CGFloat(i) * 7), 1.2, UIColor(white: 0.45, alpha: 0.6)) } }
        // hands
        let sc = v.sc(0.9)
        blob(g, v.p(1.0, 4, -26), 64, 104)
        for k in 0..<3 { let z = -12 - CGFloat(k) * 14; limb(g, v.p(0.96, 8, z), v.p(0.82, -13, z), 12.5 * sc) }
        limb(g, v.p(0.9, -12, -2), v.p(0.5, -14, 6), 11 * sc)
        blob(g, v.p(0.8, -30, -36), 68, 72)
        for k in 0..<3 { let z = -32 - CGFloat(k) * 13; limb(g, v.p(0.8, -30, z), v.p(0.95, 0, z), 12 * sc) }
        limb(g, v.p(0.8, -26, -14), v.p(0.56, -16, 2), 11 * sc)
    }

    private static func rifle(_ g: CGContext) {
        let v = FPV(T: viewT, R: CGPoint(x: 420, y: 228), s0: 0.7, s1: 1.9)
        armsLong(g, v, leftWrist: v.p(0.62, -14, -10))
        blk(g, v, 0.0, 0.07, 5, 5, 14, topM, sideM, rearM)
        for i in 0..<3 { line(v.p(0.01 + CGFloat(i) * 0.02, -5, 14), v.p(0.01 + CGFloat(i) * 0.02, 5, 14), 2, UIColor(white: 0, alpha: 0.7)) }
        blk(g, v, 0.05, 0.5, 3, 7, 13, topM, sideM, rearM)
        blk(g, v, 0.14, 0.17, 2, 13, 34, topM, sideM, rearM)
        blk(g, v, 0.2, 0.26, 5, 5, 16, topM, sideM, rearM)
        blk(g, v, 0.12, 0.64, 11, -2, 22, polyTop, polySide, polyRear)
        for i in 0..<10 { let t = 0.16 + CGFloat(i) * 0.046; let c = v.p(t, -11, 10); dot(c, 2.2 * v.sc(t), UIColor(white: 0.02, alpha: 0.9)) }
        blk(g, v, 0.12, 0.97, 5, 22, 26, topM, sideM, rearM)
        for i in 0..<30 { let t = 0.14 + CGFloat(i) * 0.028; line(v.p(t, -5, 26), v.p(t, 5, 26), 1.8, UIColor(white: 0, alpha: 0.7)) }
        blk(g, v, 0.6, 0.97, 11, -2, 22, topM, sideM, rearM)
        gfill(g, quad(v.p(0.7, -11, 17), v.p(0.86, -11, 17), v.p(0.86, -11, 7), v.p(0.7, -11, 7)), [UIColor(white: 0.02, alpha: 1), UIColor(white: 0.12, alpha: 1)], edge: 0.4)
        gfill(g, quad(v.p(0.74, -11, 13), v.p(0.83, -11, 13), v.p(0.83, -11, 9), v.p(0.74, -11, 9)), [UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1), UIColor(red: 0.5, green: 0.35, blue: 0.1, alpha: 1)], edge: 0.2)
        blk(g, v, 0.62, 0.97, 11, -22, -2, polyTop, polySide, polyRear)
        blk(g, v, 0.74, 0.86, 6, -54, -22, topM, sideM, rearM)
        for i in 0..<4 { line(v.p(0.75, -6, -28 - CGFloat(i) * 6), v.p(0.85, -6, -28 - CGFloat(i) * 6), 1.6, UIColor(white: 0, alpha: 0.5)) }
        blk(g, v, 0.9, 1.0, 8, -44, -20, polyTop, polySide, polyRear)
        // red-dot optic with glass facing the shooter
        blk(g, v, 0.62, 0.9, 11, 26, 50, topM, sideM, rearM)
        let lc = v.p(0.9, 0, 38), ls = v.sc(0.9)
        gfill(g, UIBezierPath(ovalIn: CGRect(x: lc.x - 10 * ls, y: lc.y - 11 * ls, width: 20 * ls, height: 22 * ls)), [UIColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 1), UIColor(red: 0.06, green: 0.14, blue: 0.22, alpha: 1)])
        dot(CGPoint(x: lc.x, y: lc.y), 3, UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 1))
        dot(CGPoint(x: lc.x - 5, y: lc.y - 6), 3.2, UIColor(white: 1, alpha: 0.35))
        // hands
        handsLong(g, v, leftT: 0.5, leftZ: -10)
    }

    private static func smg(_ g: CGContext) {
        let v = FPV(T: viewT, R: CGPoint(x: 410, y: 226), s0: 0.7, s1: 1.9)
        armsLong(g, v, leftWrist: v.p(0.56, -14, -26))
        blk(g, v, 0.0, 0.4, 3, 7, 13, topM, sideM, rearM)
        blk(g, v, 0.02, 0.05, 2, 13, 26, topM, sideM, rearM)
        blk(g, v, 0.1, 0.45, 10, -2, 18, polyTop, polySide, polyRear)
        for i in 0..<6 { let t = 0.14 + CGFloat(i) * 0.05; dot(v.p(t, -10, 8), 2 * v.sc(t), UIColor(white: 0.02, alpha: 0.9)) }
        blk(g, v, 0.38, 0.46, 5, -34, -2, polyTop, polySide, polyRear)
        blk(g, v, 0.3, 0.97, 11, -6, 22, topM, sideM, rearM)
        for i in 0..<18 { let t = 0.32 + CGFloat(i) * 0.036; line(v.p(t, -11, 22), v.p(t, 11, 22), 1.6, UIColor(white: 0, alpha: 0.55)) }
        gfill(g, quad(v.p(0.6, -11, 17), v.p(0.78, -11, 17), v.p(0.78, -11, 8), v.p(0.6, -11, 8)), [UIColor(white: 0.02, alpha: 1), UIColor(white: 0.12, alpha: 1)], edge: 0.4)
        blk(g, v, 0.72, 0.82, 6, -70, -6, polyTop, polySide, polyRear)
        for i in 0..<5 { line(v.p(0.73, -6, -16 - CGFloat(i) * 11), v.p(0.81, -6, -16 - CGFloat(i) * 11), 1.6, UIColor(white: 0, alpha: 0.5)) }
        blk(g, v, 0.9, 1.0, 8, -44, -6, polyTop, polySide, polyRear)
        blk(g, v, 0.9, 0.95, 2.6, 22, 27, topM, sideM, rearM, cx: -7)
        blk(g, v, 0.9, 0.95, 2.6, 22, 27, topM, sideM, rearM, cx: 7)
        handsLong(g, v, leftT: 0.42, leftZ: -24)
    }

    private static func shotgun(_ g: CGContext) {
        let v = FPV(T: viewT, R: CGPoint(x: 410, y: 226), s0: 0.7, s1: 1.9)
        armsLong(g, v, leftWrist: v.p(0.6, -12, -6))
        blk(g, v, 0.0, 0.8, 5.5, 8, 19, topM, sideM, rearM)
        blk(g, v, 0.0, 0.78, 4.5, -2, 8, topM, sideM, rearM)
        blk(g, v, 0.0, 0.03, 1.4, 19, 23, topM, sideM, rearM)
        dot(v.p(0.015, 0, 22.6), 1.5, UIColor(red: 1, green: 0.4, blue: 0.3, alpha: 1))
        line(v.p(0.04, 0, 19), v.p(0.78, 0, 19), 1.3, UIColor(white: 1, alpha: 0.4))
        blk(g, v, 0.3, 0.56, 9, -8, 8, woodT, woodS, woodR)
        for i in 0..<5 { let t = 0.32 + CGFloat(i) * 0.05; line(v.p(t, -9, 6), v.p(t, -9, -6), 1.6, UIColor(white: 0, alpha: 0.35)) }
        blk(g, v, 0.62, 0.95, 10, -10, 19, topM, sideM, rearM)
        gfill(g, quad(v.p(0.7, -10, 14), v.p(0.86, -10, 14), v.p(0.86, -10, 6), v.p(0.7, -10, 6)), [UIColor(white: 0.02, alpha: 1), UIColor(white: 0.12, alpha: 1)], edge: 0.4)
        blk(g, v, 0.88, 1.0, 8, -44, -8, woodT, woodS, woodR)
        handsLong(g, v, leftT: 0.43, leftZ: -4)
    }
}
