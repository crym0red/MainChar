import SwiftUI

/// Illustrated person portrait, unique per handle (skin, hair, outfit, face, accessories, background).
struct PortraitAvatar: View {
    let key: String
    var size: CGFloat = 40

    private static let skins: [UInt32] = [0xFBDDC8, 0xF3C9A8, 0xE2AE86, 0xC98B5B, 0xA9693D, 0x8A5128, 0x6A3B1E, 0x4B2813]
    private static let hairs: [UInt32] = [0x16110E, 0x2B1A12, 0x4A2E1B, 0x7A4B24, 0xC9A15A, 0xE3C98A, 0xA3341F, 0x8C8C92, 0xE6E6EA, 0xFF4FA3, 0x3AA0FF, 0x37D67A, 0x9B5CFF]
    private static let tops: [UInt32] = [0x1F2937, 0x374151, 0x7C3AED, 0x2563EB, 0x059669, 0xDC2626, 0xF59E0B, 0xE5E7EB, 0x0F172A, 0xDB2777, 0x0EA5E9, 0x84CC16]
    private static let bgs: [(UInt32, UInt32)] = [(0x3B2A5C, 0x120A24), (0x14405A, 0x07141F), (0x5A2A3B, 0x200A12), (0x1F4D3A, 0x08190F), (0x5A4A1F, 0x1E1707),
                                                  (0x2A3B5C, 0x0A1224), (0x4C1F5A, 0x180724), (0x1F5A56, 0x07201E), (0x5A3A1F, 0x241507), (0x3A3A44, 0x111116)]

    private func col(_ v: UInt32) -> Color { Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255) }
    private func shade(_ v: UInt32, _ f: Double) -> Color {
        Color(red: min(1, Double((v >> 16) & 255) / 255 * f), green: min(1, Double((v >> 8) & 255) / 255 * f), blue: min(1, Double(v & 255) / 255 * f))
    }

    var body: some View {
        let h = HK.h(key.lowercased()), h2 = h &* 2654435761, h3 = h2 &* 40503 &+ 977
        let skinV = Self.skins[Int(h % 8)]
        let hairV = Self.hairs[Int((h >> 3) % UInt32(Self.hairs.count))]
        let topV = Self.tops[Int((h2 >> 5) % UInt32(Self.tops.count))]
        let bg = Self.bgs[Int((h3 >> 4) % UInt32(Self.bgs.count))]
        let style = Int((h2 >> 9) % 10)
        let outfit = Int((h3 >> 11) % 4)
        let eyeKind = Int((h >> 14) % 3)
        let mouth = Int((h2 >> 17) % 4)
        let specs = (h3 >> 19) % 100 < 30
        let ring = (h >> 21) % 100 < 22
        let phones = (h2 >> 23) % 100 < 14
        let wide = 0.36 + Double((h >> 25) % 5) * 0.012
        let skin = col(skinV), hair = col(hairV), top = col(topV)
        Canvas { ctx, sz in
            let w = sz.width, ht = sz.height
            func R(_ x: Double, _ y: Double, _ ww: Double, _ hh: Double) -> CGRect { CGRect(x: w * x, y: ht * y, width: w * ww, height: ht * hh) }
            // background
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: [col(bg.0), col(bg.1)]), startPoint: .zero, endPoint: CGPoint(x: w, y: ht)))
            let cx = 0.5
            let headW = wide + 0.02, headH = 0.46, headX = cx - headW / 2, headY = 0.2
            // hair behind
            switch style {
            case 1, 6: // long
                ctx.fill(Path(roundedRect: R(headX - 0.05, headY + 0.02, headW + 0.10, 0.62), cornerRadius: w * 0.12), with: .color(hair))
            case 3: // afro
                ctx.fill(Path(ellipseIn: R(cx - 0.29, headY - 0.14, 0.58, 0.58)), with: .color(hair))
            case 4: // bun
                ctx.fill(Path(ellipseIn: R(cx - 0.09, headY - 0.17, 0.18, 0.18)), with: .color(hair))
            default: break
            }
            // shoulders
            ctx.fill(Path(ellipseIn: R(0.06, 0.74, 0.88, 0.62)), with: .color(top))
            if outfit == 1 { // hoodie hood
                ctx.fill(Path(ellipseIn: R(0.16, 0.62, 0.68, 0.30)), with: .color(shade(topV, 0.72)))
            }
            // neck
            ctx.fill(Path(roundedRect: R(cx - 0.075, 0.60, 0.15, 0.18), cornerRadius: w * 0.04), with: .color(shade(skinV, 0.86)))
            // collar
            switch outfit {
            case 0: ctx.fill(Path(ellipseIn: R(cx - 0.10, 0.70, 0.20, 0.10)), with: .color(shade(skinV, 0.9)))
            case 2:
                var l = Path(); l.move(to: CGPoint(x: w * 0.40, y: ht * 0.74)); l.addLine(to: CGPoint(x: w * 0.5, y: ht * 0.92)); l.addLine(to: CGPoint(x: w * 0.60, y: ht * 0.74)); l.closeSubpath()
                ctx.fill(l, with: .color(.white.opacity(0.9)))
            case 3:
                ctx.stroke(Path(ellipseIn: R(cx - 0.11, 0.70, 0.22, 0.11)), with: .color(shade(topV, 0.7)), lineWidth: max(1, w * 0.025))
            default:
                var s = Path(); s.move(to: CGPoint(x: w * 0.45, y: ht * 0.8)); s.addLine(to: CGPoint(x: w * 0.45, y: ht * 0.95))
                s.move(to: CGPoint(x: w * 0.55, y: ht * 0.8)); s.addLine(to: CGPoint(x: w * 0.55, y: ht * 0.95))
                ctx.stroke(s, with: .color(.white.opacity(0.7)), lineWidth: max(0.8, w * 0.012))
            }
            // ears
            ctx.fill(Path(ellipseIn: R(headX - 0.025, headY + 0.20, 0.05, 0.09)), with: .color(skin))
            ctx.fill(Path(ellipseIn: R(headX + headW - 0.025, headY + 0.20, 0.05, 0.09)), with: .color(skin))
            // head
            ctx.fill(Path(ellipseIn: R(headX, headY, headW, headH)), with: .color(skin))
            // hair front
            switch style {
            case 0: // short crop
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2 + 0.005), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2), y: ht * (headY + 0.20)), control: CGPoint(x: w * cx, y: ht * (headY + 0.10)))
                ctx.fill(p, with: .color(hair))
            case 1, 6:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2 + 0.01), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2), y: ht * (headY + 0.20)), control: CGPoint(x: w * (cx + 0.05), y: ht * (headY + 0.06)))
                ctx.fill(p, with: .color(hair))
            case 2: // buzz
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2), startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2 + 0.03), y: ht * (headY + 0.12)), control: CGPoint(x: w * cx, y: ht * (headY + 0.14)))
                ctx.fill(p, with: .color(hair.opacity(0.9)))
            case 3:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.18)), radius: w * (headW / 2), startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2 + 0.01), y: ht * (headY + 0.16)), control: CGPoint(x: w * cx, y: ht * (headY + 0.08)))
                ctx.fill(p, with: .color(hair))
            case 4, 5:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2 + 0.005), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2), y: ht * (headY + 0.20)), control: CGPoint(x: w * (cx - 0.08), y: ht * (headY + 0.11)))
                ctx.fill(p, with: .color(hair))
                if style == 5 { // side swoop
                    ctx.fill(Path(ellipseIn: R(cx - 0.20, headY + 0.00, 0.30, 0.16)), with: .color(hair))
                }
            case 7: // beanie
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.17)), radius: w * (headW / 2 + 0.02), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(shade(topV, 1.15)))
                ctx.fill(Path(roundedRect: R(headX - 0.02, headY + 0.13, headW + 0.04, 0.07), cornerRadius: w * 0.02), with: .color(shade(topV, 0.8)))
            case 8: // cap
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.17)), radius: w * (headW / 2 + 0.015), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(shade(topV, 0.95)))
                ctx.fill(Path(roundedRect: R(cx - 0.02, headY + 0.145, headW / 2 + 0.12, 0.04), cornerRadius: w * 0.02), with: .color(shade(topV, 0.7)))
            default: break // bald
            }
            // eyes
            let ey = headY + 0.25
            let eyeColor = Color(white: 0.08)
            func eye(_ x: Double) {
                switch eyeKind {
                case 0: ctx.fill(Path(ellipseIn: R(x - 0.018, ey, 0.036, 0.045)), with: .color(eyeColor))
                case 1:
                    ctx.fill(Path(ellipseIn: R(x - 0.03, ey - 0.005, 0.06, 0.05)), with: .color(.white))
                    ctx.fill(Path(ellipseIn: R(x - 0.015, ey, 0.03, 0.04)), with: .color(eyeColor))
                default:
                    var p = Path(); p.move(to: CGPoint(x: w * (x - 0.028), y: ht * (ey + 0.03)))
                    p.addQuadCurve(to: CGPoint(x: w * (x + 0.028), y: ht * (ey + 0.03)), control: CGPoint(x: w * x, y: ht * (ey - 0.02)))
                    ctx.stroke(p, with: .color(eyeColor), lineWidth: max(1, w * 0.018))
                }
                var b = Path(); b.move(to: CGPoint(x: w * (x - 0.035), y: ht * (ey - 0.03))); b.addLine(to: CGPoint(x: w * (x + 0.035), y: ht * (ey - 0.035)))
                ctx.stroke(b, with: .color(hair.opacity(style == 7 || style == 8 ? 0.7 : 1)), lineWidth: max(0.8, w * 0.014))
            }
            eye(cx - 0.085); eye(cx + 0.085)
            // cheeks + nose
            ctx.fill(Path(ellipseIn: R(cx - 0.17, ey + 0.07, 0.07, 0.04)), with: .color(Color.pink.opacity(0.14)))
            ctx.fill(Path(ellipseIn: R(cx + 0.10, ey + 0.07, 0.07, 0.04)), with: .color(Color.pink.opacity(0.14)))
            var nose = Path(); nose.move(to: CGPoint(x: w * cx, y: ht * (ey + 0.03))); nose.addQuadCurve(to: CGPoint(x: w * (cx + 0.015), y: ht * (ey + 0.10)), control: CGPoint(x: w * (cx - 0.012), y: ht * (ey + 0.085)))
            ctx.stroke(nose, with: .color(shade(skinV, 0.7)), lineWidth: max(0.8, w * 0.012))
            // mouth
            let my = ey + 0.14
            var m = Path()
            switch mouth {
            case 0: m.move(to: CGPoint(x: w * (cx - 0.05), y: ht * my)); m.addQuadCurve(to: CGPoint(x: w * (cx + 0.05), y: ht * my), control: CGPoint(x: w * cx, y: ht * (my + 0.05)))
            case 1: m.move(to: CGPoint(x: w * (cx - 0.04), y: ht * my)); m.addLine(to: CGPoint(x: w * (cx + 0.04), y: ht * my))
            case 2: m.move(to: CGPoint(x: w * (cx - 0.04), y: ht * (my + 0.01))); m.addQuadCurve(to: CGPoint(x: w * (cx + 0.06), y: ht * (my - 0.01)), control: CGPoint(x: w * (cx + 0.02), y: ht * (my + 0.04)))
            default:
                ctx.fill(Path(ellipseIn: R(cx - 0.045, my - 0.01, 0.09, 0.055)), with: .color(Color(red: 0.35, green: 0.1, blue: 0.12)))
                ctx.fill(Path(CGRect(x: w * (cx - 0.035), y: ht * (my - 0.005), width: w * 0.07, height: ht * 0.016)), with: .color(.white))
            }
            ctx.stroke(m, with: .color(Color(red: 0.45, green: 0.15, blue: 0.15)), lineWidth: max(1, w * 0.018))
            // accessories
            if specs {
                let lw = max(1, w * 0.014)
                ctx.stroke(Path(ellipseIn: R(cx - 0.135, ey - 0.012, 0.10, 0.07)), with: .color(.black.opacity(0.85)), lineWidth: lw)
                ctx.stroke(Path(ellipseIn: R(cx + 0.035, ey - 0.012, 0.10, 0.07)), with: .color(.black.opacity(0.85)), lineWidth: lw)
                var br = Path(); br.move(to: CGPoint(x: w * (cx - 0.035), y: ht * (ey + 0.02))); br.addLine(to: CGPoint(x: w * (cx + 0.035), y: ht * (ey + 0.02)))
                ctx.stroke(br, with: .color(.black.opacity(0.85)), lineWidth: lw)
            }
            if ring { ctx.fill(Path(ellipseIn: R(headX - 0.012, headY + 0.29, 0.03, 0.03)), with: .color(Color(red: 1, green: 0.84, blue: 0.3))) }
            if phones {
                var band = Path(); band.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.22)), radius: w * (headW / 2 + 0.03), startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
                ctx.stroke(band, with: .color(Color(white: 0.12)), lineWidth: max(1.5, w * 0.03))
                ctx.fill(Path(roundedRect: R(headX - 0.055, headY + 0.17, 0.065, 0.14), cornerRadius: w * 0.03), with: .color(Color(white: 0.12)))
                ctx.fill(Path(roundedRect: R(headX + headW - 0.01, headY + 0.17, 0.065, 0.14), cornerRadius: w * 0.03), with: .color(Color(white: 0.12)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: max(0.8, size * 0.015)))
    }
}
