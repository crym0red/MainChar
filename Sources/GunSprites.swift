import SwiftUI
import UIKit

enum GunSprites {
    private static var cache: [String: UIImage] = [:]

    static func image(_ id: String) -> UIImage {
        if let c = cache[id] { return c }
        let img = render(id)
        cache[id] = img
        return img
    }

    // muzzle position as a fraction of the sprite
    static func muzzle(_ id: String) -> CGPoint {
        switch id {
        case "pistol": return CGPoint(x: 0.09, y: 0.45)
        case "smg": return CGPoint(x: 0.05, y: 0.49)
        case "shotgun": return CGPoint(x: 0.04, y: 0.47)
        default: return CGPoint(x: 0.03, y: 0.49)
        }
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

    private static func pistol(_ g: CGContext) {
        sleeve(g, [CGPoint(x: 470, y: 320), CGPoint(x: 640, y: 320), CGPoint(x: 640, y: 236), CGPoint(x: 540, y: 262)])
        sleeve(g, [CGPoint(x: 250, y: 320), CGPoint(x: 400, y: 320), CGPoint(x: 380, y: 262), CGPoint(x: 290, y: 262)])
        part(g, CGRect(x: 60, y: 130, width: 40, height: 30), 6, darkTop, darkBot)
        part(g, CGRect(x: 90, y: 116, width: 380, height: 66), 10, metalTop, metalBot)
        part(g, CGRect(x: 230, y: 126, width: 80, height: 20), 3, darkTop, darkBot)
        for i in 0..<7 { line(CGPoint(x: 400 + CGFloat(i) * 9, y: 124), CGPoint(x: 400 + CGFloat(i) * 9, y: 174), 3, UIColor(white: 0, alpha: 0.5)) }
        part(g, CGRect(x: 104, y: 100, width: 14, height: 18), 2, metalTop, metalBot)
        part(g, CGRect(x: 436, y: 100, width: 26, height: 18), 2, metalTop, metalBot)
        part(g, CGRect(x: 120, y: 178, width: 330, height: 34), 8, darkTop, darkBot)
        let tg = UIBezierPath(roundedRect: CGRect(x: 232, y: 206, width: 70, height: 46), cornerRadius: 22)
        UIColor(white: 0.1, alpha: 1).setStroke()
        tg.lineWidth = 7
        tg.stroke()
        part(g, CGRect(x: 262, y: 206, width: 10, height: 30), 3, metalTop, metalBot)
        poly(g, [CGPoint(x: 396, y: 178), CGPoint(x: 470, y: 178), CGPoint(x: 446, y: 308), CGPoint(x: 380, y: 308)], darkTop, darkBot)
        for i in 0..<5 { for j in 0..<3 { UIColor(white: 0.35, alpha: 1).setFill(); UIBezierPath(ovalIn: CGRect(x: 398 + CGFloat(j) * 14 - CGFloat(i) * 3, y: 200 + CGFloat(i) * 20, width: 5, height: 5)).fill() } }
        part(g, CGRect(x: 376, y: 300, width: 76, height: 12), 3, metalTop, metalBot)
        part(g, CGRect(x: 468, y: 118, width: 16, height: 26), 3, metalTop, metalBot)
        hand(g, CGRect(x: 384, y: 206, width: 100, height: 96), fingers: 3)
        part(g, CGRect(x: 420, y: 176, width: 70, height: 26), 12, skinTop, skinBot)
        hand(g, CGRect(x: 270, y: 232, width: 140, height: 62), fingers: 2)
    }

    private static func rifle(_ g: CGContext) {
        sleeve(g, [CGPoint(x: 540, y: 320), CGPoint(x: 640, y: 320), CGPoint(x: 640, y: 250), CGPoint(x: 580, y: 266)])
        sleeve(g, [CGPoint(x: 230, y: 320), CGPoint(x: 360, y: 320), CGPoint(x: 340, y: 232), CGPoint(x: 262, y: 232)])
        part(g, CGRect(x: 20, y: 140, width: 56, height: 36), 5, darkTop, darkBot)
        for i in 0..<3 { line(CGPoint(x: 30 + CGFloat(i) * 12, y: 144), CGPoint(x: 30 + CGFloat(i) * 12, y: 172), 3, UIColor(white: 0, alpha: 0.6)) }
        part(g, CGRect(x: 70, y: 150, width: 130, height: 16), 4, metalTop, metalBot)
        poly(g, [CGPoint(x: 134, y: 112), CGPoint(x: 150, y: 112), CGPoint(x: 158, y: 150), CGPoint(x: 128, y: 150)], metalTop, metalBot)
        part(g, CGRect(x: 190, y: 132, width: 210, height: 54), 8, UIColor(white: 0.3, alpha: 1), UIColor(white: 0.12, alpha: 1))
        vents(CGRect(x: 190, y: 132, width: 210, height: 54), 8)
        part(g, CGRect(x: 190, y: 120, width: 380, height: 12), 2, darkTop, darkBot)
        part(g, CGRect(x: 396, y: 128, width: 170, height: 60), 8, metalTop, metalBot)
        part(g, CGRect(x: 440, y: 138, width: 70, height: 18), 3, darkTop, darkBot)
        part(g, CGRect(x: 500, y: 96, width: 44, height: 26), 4, darkTop, darkBot)
        part(g, CGRect(x: 530, y: 108, width: 22, height: 10), 2, metalTop, metalBot)
        part(g, CGRect(x: 404, y: 186, width: 150, height: 40), 8, darkTop, darkBot)
        poly(g, [CGPoint(x: 432, y: 224), CGPoint(x: 486, y: 224), CGPoint(x: 506, y: 306), CGPoint(x: 452, y: 306)], UIColor(white: 0.24, alpha: 1), UIColor(white: 0.08, alpha: 1))
        poly(g, [CGPoint(x: 526, y: 224), CGPoint(x: 566, y: 224), CGPoint(x: 588, y: 300), CGPoint(x: 548, y: 300)], darkTop, darkBot)
        let tg = UIBezierPath(roundedRect: CGRect(x: 484, y: 214, width: 50, height: 34), cornerRadius: 14)
        UIColor(white: 0.1, alpha: 1).setStroke()
        tg.lineWidth = 6
        tg.stroke()
        part(g, CGRect(x: 505, y: 208, width: 8, height: 22), 2, metalTop, metalBot)
        poly(g, [CGPoint(x: 560, y: 132), CGPoint(x: 640, y: 150), CGPoint(x: 640, y: 234), CGPoint(x: 560, y: 204)], darkTop, darkBot)
        part(g, CGRect(x: 552, y: 150, width: 70, height: 26), 6, metalTop, metalBot)
        hand(g, CGRect(x: 538, y: 230, width: 74, height: 76), fingers: 3)
        hand(g, CGRect(x: 236, y: 172, width: 140, height: 66), fingers: 3)
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
