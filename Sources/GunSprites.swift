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
    static func muzzle(_ id: String) -> CGPoint {
        switch id {
        case "pistol": return CGPoint(x: 0.268, y: 0.499)
        case "smg": return CGPoint(x: 0.19, y: 0.419)
        case "shotgun": return CGPoint(x: 0.207, y: 0.426)
        default: return CGPoint(x: 0.178, y: 0.408)
        }
    }

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

    private static func pistol(_ g: CGContext) {
        cuff(g, [CGPoint(x: 470, y: 320), CGPoint(x: 640, y: 320), CGPoint(x: 640, y: 232), CGPoint(x: 520, y: 258)])
        // frame + dust cover
        let frame = UIBezierPath()
        frame.move(to: CGPoint(x: 86, y: 168)); frame.addLine(to: CGPoint(x: 330, y: 168)); frame.addLine(to: CGPoint(x: 470, y: 172))
        frame.addLine(to: CGPoint(x: 470, y: 196)); frame.addLine(to: CGPoint(x: 330, y: 194)); frame.addCurve(to: CGPoint(x: 296, y: 186), controlPoint1: CGPoint(x: 316, y: 192), controlPoint2: CGPoint(x: 306, y: 190))
        frame.addLine(to: CGPoint(x: 96, y: 184)); frame.close()
        gfill(g, frame, polymer)
        for i in 0..<3 { line(CGPoint(x: 110 + CGFloat(i) * 30, y: 175), CGPoint(x: 130 + CGFloat(i) * 30, y: 175), 2, UIColor(white: 0, alpha: 0.6)) }
        // barrel muzzle
        gfill(g, UIBezierPath(ovalIn: CGRect(x: 52, y: 128, width: 26, height: 36)), [UIColor(white: 0.2, alpha: 1), UIColor(white: 0.02, alpha: 1)])
        gfill(g, UIBezierPath(ovalIn: CGRect(x: 58, y: 138, width: 14, height: 16)), [UIColor(white: 0.0, alpha: 1), UIColor(white: 0.12, alpha: 1)], edge: 0)
        // slide
        let sl = UIBezierPath()
        sl.move(to: CGPoint(x: 62, y: 126)); sl.addLine(to: CGPoint(x: 72, y: 110)); sl.addLine(to: CGPoint(x: 448, y: 110))
        sl.addCurve(to: CGPoint(x: 474, y: 124), controlPoint1: CGPoint(x: 462, y: 110), controlPoint2: CGPoint(x: 472, y: 116))
        sl.addLine(to: CGPoint(x: 476, y: 168)); sl.addLine(to: CGPoint(x: 80, y: 170)); sl.addCurve(to: CGPoint(x: 62, y: 156), controlPoint1: CGPoint(x: 70, y: 170), controlPoint2: CGPoint(x: 62, y: 164)); sl.close()
        gfill(g, sl, [UIColor(white: 0.62, alpha: 1), UIColor(white: 0.36, alpha: 1), UIColor(white: 0.2, alpha: 1), UIColor(white: 0.11, alpha: 1)], [0, 0.18, 0.6, 1])
        line(CGPoint(x: 82, y: 113), CGPoint(x: 446, y: 113), 1.8, UIColor(white: 1, alpha: 0.5))
        line(CGPoint(x: 80, y: 160), CGPoint(x: 470, y: 162), 1.4, UIColor(white: 0, alpha: 0.4))
        // serrations
        for i in 0..<8 { let x = 96 + CGFloat(i) * 8; line(CGPoint(x: x, y: 116), CGPoint(x: x - 4, y: 162), 2.4, UIColor(white: 0, alpha: 0.55)); line(CGPoint(x: x + 2.6, y: 116), CGPoint(x: x - 1.4, y: 162), 1, UIColor(white: 1, alpha: 0.12)) }
        for i in 0..<7 { let x = 396 + CGFloat(i) * 8; line(CGPoint(x: x, y: 116), CGPoint(x: x - 4, y: 164), 2.4, UIColor(white: 0, alpha: 0.55)); line(CGPoint(x: x + 2.6, y: 116), CGPoint(x: x - 1.4, y: 164), 1, UIColor(white: 1, alpha: 0.12)) }
        // ejection port
        let ep = rr(CGRect(x: 236, y: 116, width: 120, height: 30), 6)
        gfill(g, ep, [UIColor(white: 0.02, alpha: 1), UIColor(white: 0.12, alpha: 1)])
        gfill(g, rr(CGRect(x: 250, y: 128, width: 80, height: 14), 4), [UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1), UIColor(red: 0.5, green: 0.35, blue: 0.1, alpha: 1)], edge: 0.3)
        // sights
        gfill(g, rr(CGRect(x: 84, y: 98, width: 16, height: 14), 2), steel)
        UIColor(white: 1, alpha: 0.9).setFill(); UIBezierPath(ovalIn: CGRect(x: 89, y: 101, width: 5, height: 5)).fill()
        gfill(g, rr(CGRect(x: 422, y: 96, width: 44, height: 16), 3), steel)
        UIColor.black.setFill(); rr(CGRect(x: 438, y: 96, width: 12, height: 12), 1).fill()
        UIColor(white: 1, alpha: 0.9).setFill(); UIBezierPath(ovalIn: CGRect(x: 426, y: 100, width: 5, height: 5)).fill(); UIBezierPath(ovalIn: CGRect(x: 457, y: 100, width: 5, height: 5)).fill()
        // trigger guard + trigger
        let tg = UIBezierPath()
        tg.move(to: CGPoint(x: 330, y: 190)); tg.addCurve(to: CGPoint(x: 296, y: 232), controlPoint1: CGPoint(x: 330, y: 212), controlPoint2: CGPoint(x: 318, y: 232))
        tg.addLine(to: CGPoint(x: 262, y: 232)); tg.addCurve(to: CGPoint(x: 246, y: 196), controlPoint1: CGPoint(x: 248, y: 230), controlPoint2: CGPoint(x: 244, y: 214)); tg.addLine(to: CGPoint(x: 252, y: 188))
        UIColor(white: 0.07, alpha: 1).setStroke(); tg.lineWidth = 8; tg.stroke()
        UIColor(white: 0.3, alpha: 0.6).setStroke(); tg.lineWidth = 1.4; tg.stroke()
        let trig = UIBezierPath(); trig.move(to: CGPoint(x: 296, y: 192)); trig.addCurve(to: CGPoint(x: 286, y: 224), controlPoint1: CGPoint(x: 296, y: 206), controlPoint2: CGPoint(x: 292, y: 218)); trig.addLine(to: CGPoint(x: 276, y: 222)); trig.addLine(to: CGPoint(x: 280, y: 192)); trig.close()
        gfill(g, trig, steel)
        // grip
        let grip = UIBezierPath()
        grip.move(to: CGPoint(x: 372, y: 192)); grip.addLine(to: CGPoint(x: 474, y: 192)); grip.addCurve(to: CGPoint(x: 450, y: 312), controlPoint1: CGPoint(x: 470, y: 240), controlPoint2: CGPoint(x: 462, y: 280))
        grip.addLine(to: CGPoint(x: 384, y: 312)); grip.addCurve(to: CGPoint(x: 372, y: 192), controlPoint1: CGPoint(x: 378, y: 270), controlPoint2: CGPoint(x: 370, y: 230)); grip.close()
        gfill(g, grip, polymer)
        g.saveGState(); g.addPath(grip.cgPath); g.clip(); stipple(CGRect(x: 372, y: 192, width: 104, height: 120), 9); g.restoreGState()
        gfill(g, rr(CGRect(x: 378, y: 306, width: 76, height: 12), 3), steel)
        gfill(g, rr(CGRect(x: 462, y: 124, width: 16, height: 30), 4), steel)
        // support hand wrapping the grip
        for (i, y) in [200, 226, 252, 278].enumerated() { finger(g, CGRect(x: 318 + CGFloat(i) * 3, y: CGFloat(y), width: 104, height: 24)) }
        gfill(g, rr(CGRect(x: 250, y: 200, width: 100, height: 70), 24), [UIColor(red: 0.88, green: 0.68, blue: 0.54, alpha: 1), UIColor(red: 0.6, green: 0.42, blue: 0.31, alpha: 1)])
        // strong-hand thumb along the frame
        finger(g, CGRect(x: 330, y: 172, width: 142, height: 22))
        // strong-hand heel behind the grip
        gfill(g, rr(CGRect(x: 456, y: 176, width: 90, height: 120), 36), [UIColor(red: 0.9, green: 0.7, blue: 0.56, alpha: 1), UIColor(red: 0.62, green: 0.44, blue: 0.33, alpha: 1)])
        // muzzle edge highlight
        line(CGPoint(x: 64, y: 130), CGPoint(x: 74, y: 114), 1.6, UIColor(white: 1, alpha: 0.5))
    }

    private static func rifle(_ g: CGContext) {
        cuff(g, [CGPoint(x: 540, y: 320), CGPoint(x: 640, y: 320), CGPoint(x: 640, y: 244), CGPoint(x: 590, y: 262)])
        // stock
        let st = UIBezierPath()
        st.move(to: CGPoint(x: 556, y: 142)); st.addLine(to: CGPoint(x: 640, y: 156)); st.addLine(to: CGPoint(x: 640, y: 232)); st.addCurve(to: CGPoint(x: 556, y: 204), controlPoint1: CGPoint(x: 616, y: 230), controlPoint2: CGPoint(x: 580, y: 216)); st.close()
        gfill(g, st, polymer)
        for i in 0..<6 { line(CGPoint(x: 572 + CGFloat(i) * 11, y: 150 + CGFloat(i) * 2), CGPoint(x: 572 + CGFloat(i) * 11, y: 208 + CGFloat(i) * 3), 2, UIColor(white: 0, alpha: 0.4)) }
        gfill(g, rr(CGRect(x: 600, y: 160, width: 40, height: 70), 6), [UIColor(white: 0.12, alpha: 1), UIColor(white: 0.04, alpha: 1)])
        // flash hider + barrel
        gfill(g, rr(CGRect(x: 18, y: 136, width: 54, height: 34), 6), steel)
        for i in 0..<4 { line(CGPoint(x: 26 + CGFloat(i) * 10, y: 140), CGPoint(x: 26 + CGFloat(i) * 10, y: 166), 4, UIColor(white: 0, alpha: 0.75)) }
        gfill(g, rr(CGRect(x: 70, y: 146, width: 140, height: 14), 4), steel)
        // front sight tower + gas block
        let fs = UIBezierPath(); fs.move(to: CGPoint(x: 128, y: 100)); fs.addLine(to: CGPoint(x: 150, y: 100)); fs.addLine(to: CGPoint(x: 158, y: 148)); fs.addLine(to: CGPoint(x: 122, y: 148)); fs.close()
        gfill(g, fs, steel)
        UIColor.black.setFill(); rr(CGRect(x: 134, y: 104, width: 8, height: 26), 2).fill()
        gfill(g, rr(CGRect(x: 160, y: 140, width: 44, height: 30), 4), steel)
        // handguard with rails
        let hg = rr(CGRect(x: 200, y: 128, width: 220, height: 60), 14)
        gfill(g, hg, [UIColor(white: 0.34, alpha: 1), UIColor(white: 0.18, alpha: 1), UIColor(white: 0.08, alpha: 1)])
        shine(CGRect(x: 200, y: 128, width: 220, height: 60), inset: 12, a: 0.4)
        for r in 0..<2 { for i in 0..<14 { UIColor(white: 0.03, alpha: 0.85).setFill(); UIBezierPath(ovalIn: CGRect(x: 214 + CGFloat(i) * 14.5, y: 140 + CGFloat(r) * 28, width: 6, height: 10)).fill() } }
        // top rail
        gfill(g, rr(CGRect(x: 200, y: 116, width: 370, height: 14), 2), [UIColor(white: 0.3, alpha: 1), UIColor(white: 0.1, alpha: 1)])
        for i in 0..<36 { line(CGPoint(x: 204 + CGFloat(i) * 10, y: 117), CGPoint(x: 204 + CGFloat(i) * 10, y: 129), 2.4, UIColor(white: 0, alpha: 0.7)) }
        // upper receiver
        let ur = UIBezierPath()
        ur.move(to: CGPoint(x: 410, y: 128)); ur.addLine(to: CGPoint(x: 566, y: 128)); ur.addLine(to: CGPoint(x: 566, y: 190)); ur.addLine(to: CGPoint(x: 410, y: 190)); ur.close()
        gfill(g, ur, [UIColor(white: 0.4, alpha: 1), UIColor(white: 0.22, alpha: 1), UIColor(white: 0.1, alpha: 1)])
        shine(CGRect(x: 410, y: 128, width: 156, height: 60), a: 0.4)
        gfill(g, rr(CGRect(x: 456, y: 140, width: 60, height: 24), 5), [UIColor(white: 0.04, alpha: 1), UIColor(white: 0.14, alpha: 1)])
        gfill(g, rr(CGRect(x: 470, y: 150, width: 34, height: 9), 3), [UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1), UIColor(red: 0.5, green: 0.35, blue: 0.1, alpha: 1)], edge: 0.3)
        gfill(g, rr(CGRect(x: 538, y: 120, width: 28, height: 16), 3), steel)
        // red-dot optic
        let ob = rr(CGRect(x: 440, y: 72, width: 96, height: 48), 10)
        gfill(g, ob, [UIColor(white: 0.3, alpha: 1), UIColor(white: 0.12, alpha: 1), UIColor(white: 0.05, alpha: 1)])
        shine(CGRect(x: 440, y: 72, width: 96, height: 48), inset: 10, a: 0.5)
        gfill(g, UIBezierPath(ovalIn: CGRect(x: 436, y: 78, width: 24, height: 36)), [UIColor(red: 0.2, green: 0.5, blue: 0.7, alpha: 1), UIColor(red: 0.05, green: 0.12, blue: 0.2, alpha: 1)])
        UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 0.95).setFill(); UIBezierPath(ovalIn: CGRect(x: 444, y: 94, width: 5, height: 5)).fill()
        gfill(g, rr(CGRect(x: 466, y: 112, width: 40, height: 10), 2), steel)
        // lower receiver, magwell, magazine
        gfill(g, rr(CGRect(x: 412, y: 186, width: 150, height: 40), 10), polymer)
        let mag = UIBezierPath()
        mag.move(to: CGPoint(x: 436, y: 222)); mag.addLine(to: CGPoint(x: 490, y: 222)); mag.addCurve(to: CGPoint(x: 506, y: 312), controlPoint1: CGPoint(x: 496, y: 256), controlPoint2: CGPoint(x: 508, y: 286)); mag.addLine(to: CGPoint(x: 452, y: 312)); mag.addCurve(to: CGPoint(x: 436, y: 222), controlPoint1: CGPoint(x: 446, y: 282), controlPoint2: CGPoint(x: 438, y: 254)); mag.close()
        gfill(g, mag, [UIColor(white: 0.34, alpha: 1), UIColor(white: 0.18, alpha: 1), UIColor(white: 0.07, alpha: 1)])
        for i in 0..<4 { line(CGPoint(x: 444 + CGFloat(i) * 2, y: 236 + CGFloat(i) * 17), CGPoint(x: 488 + CGFloat(i) * 3, y: 236 + CGFloat(i) * 17), 2, UIColor(white: 0, alpha: 0.5)) }
        gfill(g, rr(CGRect(x: 448, y: 306, width: 62, height: 10), 3), steel)
        // trigger guard + pistol grip
        let tg = UIBezierPath(); tg.move(to: CGPoint(x: 500, y: 226)); tg.addCurve(to: CGPoint(x: 522, y: 250), controlPoint1: CGPoint(x: 500, y: 242), controlPoint2: CGPoint(x: 508, y: 250)); tg.addLine(to: CGPoint(x: 534, y: 250))
        UIColor(white: 0.07, alpha: 1).setStroke(); tg.lineWidth = 6; tg.stroke()
        gfill(g, rr(CGRect(x: 512, y: 226, width: 7, height: 24), 2), steel)
        let pg = UIBezierPath(); pg.move(to: CGPoint(x: 528, y: 224)); pg.addLine(to: CGPoint(x: 566, y: 224)); pg.addCurve(to: CGPoint(x: 590, y: 306), controlPoint1: CGPoint(x: 572, y: 256), controlPoint2: CGPoint(x: 586, y: 284)); pg.addLine(to: CGPoint(x: 548, y: 306)); pg.addCurve(to: CGPoint(x: 528, y: 224), controlPoint1: CGPoint(x: 540, y: 272), controlPoint2: CGPoint(x: 530, y: 250)); pg.close()
        gfill(g, pg, polymer)
        g.saveGState(); g.addPath(pg.cgPath); g.clip(); stipple(CGRect(x: 528, y: 224, width: 62, height: 84), 8); g.restoreGState()
        // hands
        for (i, y) in [232, 256, 280].enumerated() { finger(g, CGRect(x: 520 + CGFloat(i) * 4, y: CGFloat(y), width: 74, height: 22)) }
        gfill(g, rr(CGRect(x: 560, y: 196, width: 80, height: 100), 30), [UIColor(red: 0.9, green: 0.7, blue: 0.56, alpha: 1), UIColor(red: 0.6, green: 0.43, blue: 0.32, alpha: 1)])
        finger(g, CGRect(x: 508, y: 196, width: 70, height: 20))
        // support hand under the handguard
        cuff(g, [CGPoint(x: 230, y: 320), CGPoint(x: 370, y: 320), CGPoint(x: 352, y: 250), CGPoint(x: 262, y: 250)])
        gfill(g, rr(CGRect(x: 240, y: 186, width: 150, height: 74), 30), [UIColor(red: 0.9, green: 0.7, blue: 0.56, alpha: 1), UIColor(red: 0.6, green: 0.43, blue: 0.32, alpha: 1)])
        for (i, x) in [252, 286, 320, 354].enumerated() { finger(g, CGRect(x: CGFloat(x), y: 168 + CGFloat(i % 2) * 2, width: 34, height: 26)) }
        finger(g, CGRect(x: 232, y: 200, width: 50, height: 22))
    }

    private static func smg(_ g: CGContext) {
        sleeve(g, [CGPoint(x: 500, y: 320), CGPoint(x: 640, y: 320), CGPoint(x: 640, y: 246), CGPoint(x: 548, y: 266)])
        sleeve(g, [CGPoint(x: 120, y: 320), CGPoint(x: 250, y: 320), CGPoint(x: 232, y: 250), CGPoint(x: 140, y: 250)])
        part(g, CGRect(x: 34, y: 140, width: 190, height: 36), 12, darkTop, darkBot)
        for i in 0..<6 { line(CGPoint(x: 60 + CGFloat(i) * 24, y: 146), CGPoint(x: 60 + CGFloat(i) * 24, y: 170), 4, UIColor(white: 0, alpha: 0.6)) }
        part(g, CGRect(x: 200, y: 122, width: 310, height: 68), 10, metalTop, metalBot)
        part(g, CGRect(x: 210, y: 110, width: 270, height: 12), 2, darkTop, darkBot)
        part(g, CGRect(x: 240, y: 134, width: 80, height: 18), 3, darkTop, darkBot)
        part(g, CGRect(x: 120, y: 100, width: 12, height: 22), 2, metalTop, metalBot)
        part(g, CGRect(x: 456, y: 96, width: 28, height: 16), 2, metalTop, metalBot)
        part(g, CGRect(x: 336, y: 188, width: 52, height: 128), 6, UIColor(white: 0.22, alpha: 1), UIColor(white: 0.07, alpha: 1))
        for i in 0..<6 { line(CGPoint(x: 340, y: 210 + CGFloat(i) * 18), CGPoint(x: 384, y: 210 + CGFloat(i) * 18), 2, UIColor(white: 0, alpha: 0.55)) }
        poly(g, [CGPoint(x: 440, y: 188), CGPoint(x: 504, y: 188), CGPoint(x: 484, y: 296), CGPoint(x: 426, y: 296)], darkTop, darkBot)
        let tg = UIBezierPath(roundedRect: CGRect(x: 396, y: 184, width: 48, height: 34), cornerRadius: 14)
        UIColor(white: 0.1, alpha: 1).setStroke()
        tg.lineWidth = 6
        tg.stroke()
        part(g, CGRect(x: 416, y: 188, width: 8, height: 22), 2, metalTop, metalBot)
        line(CGPoint(x: 506, y: 140), CGPoint(x: 624, y: 150), 9, UIColor(white: 0.2, alpha: 1))
        line(CGPoint(x: 624, y: 150), CGPoint(x: 624, y: 226), 9, UIColor(white: 0.2, alpha: 1))
        part(g, CGRect(x: 150, y: 188, width: 46, height: 52), 8, darkTop, darkBot)
        hand(g, CGRect(x: 424, y: 220, width: 80, height: 76), fingers: 3)
        hand(g, CGRect(x: 126, y: 190, width: 120, height: 62), fingers: 3)
    }

    private static func shotgun(_ g: CGContext) {
        sleeve(g, [CGPoint(x: 540, y: 320), CGPoint(x: 640, y: 320), CGPoint(x: 640, y: 260), CGPoint(x: 580, y: 274)])
        sleeve(g, [CGPoint(x: 170, y: 320), CGPoint(x: 330, y: 320), CGPoint(x: 310, y: 240), CGPoint(x: 200, y: 240)])
        part(g, CGRect(x: 26, y: 140, width: 340, height: 22), 8, metalTop, metalBot)
        part(g, CGRect(x: 36, y: 166, width: 300, height: 16), 7, darkTop, darkBot)
        part(g, CGRect(x: 26, y: 124, width: 10, height: 18), 2, metalTop, metalBot)
        part(g, CGRect(x: 180, y: 160, width: 150, height: 56), 12, woodTop, woodBot)
        for i in 0..<8 { line(CGPoint(x: 196 + CGFloat(i) * 17, y: 168), CGPoint(x: 196 + CGFloat(i) * 17, y: 208), 3, UIColor(white: 0, alpha: 0.35)) }
        part(g, CGRect(x: 350, y: 126, width: 150, height: 80), 10, metalTop, metalBot)
        part(g, CGRect(x: 380, y: 142, width: 70, height: 16), 3, darkTop, darkBot)
        part(g, CGRect(x: 370, y: 112, width: 90, height: 14), 3, darkTop, darkBot)
        let tg = UIBezierPath(roundedRect: CGRect(x: 396, y: 200, width: 56, height: 40), cornerRadius: 16)
        UIColor(white: 0.1, alpha: 1).setStroke()
        tg.lineWidth = 6
        tg.stroke()
        part(g, CGRect(x: 420, y: 204, width: 8, height: 24), 2, metalTop, metalBot)
        poly(g, [CGPoint(x: 496, y: 136), CGPoint(x: 640, y: 168), CGPoint(x: 640, y: 262), CGPoint(x: 496, y: 206)], woodTop, woodBot)
        for i in 0..<5 { line(CGPoint(x: 510 + CGFloat(i) * 24, y: 150 + CGFloat(i) * 6), CGPoint(x: 500 + CGFloat(i) * 28, y: 214 + CGFloat(i) * 8), 2, UIColor(white: 0, alpha: 0.25)) }
        part(g, CGRect(x: 398, y: 160, width: 14, height: 10), 2, UIColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1), UIColor(red: 0.5, green: 0.1, blue: 0.08, alpha: 1))
        hand(g, CGRect(x: 420, y: 232, width: 78, height: 72), fingers: 3)
        hand(g, CGRect(x: 170, y: 186, width: 150, height: 70), fingers: 3)
    }
}
