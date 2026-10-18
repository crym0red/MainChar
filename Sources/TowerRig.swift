import SwiftUI

/// Shared soldier model (vest, arms, legs, 3D firearms) used by the 5v5 scene.
struct TwSoldier {
    var root: MXNode
    var legL: MXNode
    var legR: MXNode
    var holder: MXNode
    var variants: [MXNode]
    var flash: MXNode
    var shirt: MXMaterial
    var face: MXNode
    var faceMat: MXMaterial
    var kev: MXNode
    var helm: MXNode
    var heavy: MXNode
    var hat: MXNode
}

enum TwRig {
    static func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: min(1, r), green: min(1, g), blue: min(1, b), alpha: 1) }

    static func mat(_ c: UIColor, glow: Bool = false) -> MXMaterial {
        let m = MXMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant }
        return m
    }

    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, glow: Bool = false) -> MXNode {
        let g = MXBox(width: w, height: h, length: l, chamferRadius: min(w, h, l) * 0.28)
        g.chamferSegmentCount = 2
        g.materials = [mat(c, glow: glow)]
        return MXNode(geometry: g)
    }

    static func ball(_ r: CGFloat, _ c: UIColor) -> MXNode {
        let g = MXSphere(radius: r)
        g.segmentCount = 20
        g.materials = [mat(c)]
        return MXNode(geometry: g)
    }

    static func cyl(_ r: CGFloat, _ h: CGFloat, _ c: UIColor) -> MXNode {
        let g = MXCylinder(radius: r, height: h)
        g.radialSegmentCount = 18
        g.materials = [mat(c)]
        return MXNode(geometry: g)
    }

    static func cap(_ rad: CGFloat, _ h: CGFloat, _ c: UIColor) -> MXNode {
        let g = MXCapsule(capRadius: rad, height: max(h, rad * 2 + 0.1))
        g.radialSegmentCount = 20
        g.capSegmentCount = 8
        g.materials = [mat(c)]
        return MXNode(geometry: g)
    }

    private static var camoCache: [String: MXMaterial] = [:]
    static func camoMat(_ base: UIColor, _ key: String) -> MXMaterial {
        if let m = camoCache[key] { return m }
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let img = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { c in
            base.setFill(); c.cgContext.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            var seed: UInt64 = 99
            func nx() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
            for i in 0..<26 {
                let k: CGFloat = i % 2 == 0 ? 0.72 : 1.22
                UIColor(red: min(1, br * k), green: min(1, bg * k), blue: min(1, bb * k), alpha: 1).setFill()
                c.cgContext.fillEllipse(in: CGRect(x: nx() * 64, y: nx() * 64, width: 8 + nx() * 16, height: 5 + nx() * 10))
            }
        }
        let m = MXMaterial()
        m.diffuse.contents = img
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        camoCache[key] = m
        return m
    }

    static func at(_ n: MXNode, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> MXNode {
        n.position = MXVector3(Float(x), Float(y), Float(z))
        return n
    }

    static func gunIdx(_ id: String) -> Int { TWeapons.all.firstIndex { $0.id == id } ?? 0 }

    /// Curved patch of the head ellipsoid facing +x. The face texture is projected onto it from the front.
    static func facePatch(rx: CGFloat, ry: CGFloat, rz: CGFloat, span: CGFloat) -> MXGeometry {
        let nA = 16, nE = 16
        let azMax: CGFloat = 1.22, elMin: CGFloat = -1.0, elMax: CGFloat = 0.95
        var vs: [MXVector3] = [], ns: [MXVector3] = [], uv: [CGPoint] = []
        for j in 0...nE {
            let el = elMin + (elMax - elMin) * CGFloat(j) / CGFloat(nE)
            for i in 0...nA {
                let az = -azMax + 2 * azMax * CGFloat(i) / CGFloat(nA)
                let x = rx * cos(el) * cos(az), y = ry * sin(el), z = rz * cos(el) * sin(az)
                vs.append(MXVector3(Float(x), Float(y), Float(z)))
                let nx = x / (rx * rx), ny = y / (ry * ry), nz = z / (rz * rz)
                let l = max(0.0001, sqrt(nx * nx + ny * ny + nz * nz))
                ns.append(MXVector3(Float(nx / l), Float(ny / l), Float(nz / l)))
                uv.append(CGPoint(x: 0.5 - z / span, y: 0.5 - y / span))
            }
        }
        var idx: [Int32] = []
        for j in 0..<nE {
            for i in 0..<nA {
                let a = Int32(j * (nA + 1) + i), b = a + 1, c = a + Int32(nA + 1), d = c + 1
                idx += [a, c, b, b, c, d]
            }
        }
        return MXCustomGeometry(sources: [MXGeometrySource(vertices: vs), MXGeometrySource(normals: ns), MXGeometrySource(textureCoordinates: uv)],
                           elements: [MXGeometryElement(indices: idx, primitiveType: .triangles)])
    }

    static func cone(_ r: CGFloat, _ h: CGFloat, _ c: UIColor) -> MXNode {
        let g = MXCone(topRadius: 0, bottomRadius: r, height: h)
        g.radialSegmentCount = 16
        g.materials = [mat(c)]
        return MXNode(geometry: g)
    }

    /// 3D hair for the AvatarLook hair styles. Head centre is (0.4, 35.5, 0), the face looks along +x.
    static func hair3D(_ st: Int, _ c: UIColor) -> MXNode {
        let n = MXNode()
        func capHair(_ sy: CGFloat, _ yy: CGFloat = 38.2) {
            let b = ball(4.9, c)
            b.scale = MXVector3(0.98, Float(sy), 0.95)
            n.addChildNode(at(b, 0.1, yy, 0))
        }
        switch st {
        case 9: break
        case 2: capHair(0.5, 37.8)
        case 3, 13:
            let b = ball(6.2, c)
            b.scale = MXVector3(0.95, 0.85, 1.05)
            n.addChildNode(at(b, -0.2, 38.6, 0))
        case 4:
            capHair(0.6)
            n.addChildNode(at(ball(2, c), -0.4, 42.4, 0))
        case 10, 15:
            capHair(0.45, 37.9)
            for k in -2...2 { n.addChildNode(at(box(1.2, 2.8 - CGFloat(abs(k)) * 0.4, 1.0, c), 0.2, 41.6, CGFloat(k) * 1.3)) }
        case 1, 16, 12:
            capHair(0.62)
            n.addChildNode(at(box(2.2, 8.4, 8.8, c), -3.4, 33.6, 0))
        case 11:
            capHair(0.62)
            n.addChildNode(at(cap(1.1, 7.5, c), -4.6, 34.2, 0))
        case 17:
            capHair(0.62)
            for z in [-4.9, 4.9] as [CGFloat] { n.addChildNode(at(cap(1.1, 7.5, c), -1.0, 34.0, z)) }
        case 19:
            capHair(0.6)
            for z in [-3.6, 3.6] as [CGFloat] { n.addChildNode(at(ball(1.9, c), -0.4, 41.6, z)) }
        default: capHair(0.62)
        }
        return n
    }

    /// 3D hats for the AvatarLook hat list.
    static func hat3D(_ k: Int, _ c: UIColor) -> MXNode {
        let n = MXNode()
        let gold = col(1, 0.82, 0.25)
        func dome(_ r: CGFloat, _ sy: CGFloat, _ y: CGFloat, _ cc: UIColor) {
            let b = ball(r, cc)
            b.scale = MXVector3(1, Float(sy), 1)
            n.addChildNode(at(b, 0.2, y, 0))
        }
        switch k {
        case 1: dome(5.15, 0.66, 38.3, c); n.addChildNode(at(ball(1.2, c), 0.2, 42.2, 0))
        case 2: dome(5.15, 0.58, 38.4, c); n.addChildNode(at(box(3.8, 0.5, 7.8, c), 5.5, 37.6, 0))
        case 3:
            n.addChildNode(at(cyl(4.3, 2.4, gold), 0.3, 40.4, 0))
            for z in [-3.2, -1.6, 0, 1.6, 3.2] as [CGFloat] { n.addChildNode(at(cone(0.9, 2.4, gold), 0.3, 42.6, z)) }
        case 4: n.addChildNode(at(cone(3.1, 7, c), 0.3, 43.4, 0))
        case 5:
            n.addChildNode(at(cyl(8.4, 0.5, c), 0.3, 38.8, 0))
            n.addChildNode(at(cyl(4.3, 3.6, c), 0.3, 40.6, 0))
        case 6: n.addChildNode(at(cyl(4.6, 1.4, c), 0.3, 38.0, 0))
        case 7:
            let t = MXTorus(ringRadius: 3.6, pipeRadius: 0.45)
            t.materials = [mat(gold, glow: true)]
            n.addChildNode(at(MXNode(geometry: t), 0.3, 44.0, 0))
        case 8:
            for z in [-2.2, 2.2] as [CGFloat] { n.addChildNode(at(box(1.4, 7, 1.6, c), 0.2, 43.5, z)) }
        case 9:
            for z in [-3.2, 3.2] as [CGFloat] { n.addChildNode(at(cone(1.9, 3.2, c), 0.3, 41.8, z)) }
        case 10:
            n.addChildNode(at(cyl(4.1, 5.8, c), 0.3, 41.8, 0))
            n.addChildNode(at(cyl(6.2, 0.5, c), 0.3, 39.0, 0))
        case 11:
            n.addChildNode(at(cone(5, 9.5, c), 0.3, 43.8, 0))
            n.addChildNode(at(cyl(6.8, 0.4, c), 0.3, 39.2, 0))
        case 12:
            for z in [-4.3, 4.3] as [CGFloat] {
                let h = cone(1.1, 4.4, col(0.92, 0.9, 0.82))
                h.eulerAngles = MXVector3(Float(z > 0 ? 0.6 : -0.6), 0, 0)
                n.addChildNode(at(h, 0.3, 41.2, z))
            }
        case 13: n.addChildNode(at(box(3.4, 2.4, 9.6, c), 0.2, 39.9, 0)); n.addChildNode(at(box(8.2, 0.6, 5.2, c), 0.2, 38.9, 0))
        case 14:
            n.addChildNode(at(cone(4.6, 8.5, col(0.85, 0.12, 0.12)), -0.6, 43.2, 0))
            n.addChildNode(at(cyl(5, 1.3, col(0.96, 0.96, 0.96)), 0.2, 38.7, 0))
            n.addChildNode(at(ball(1.2, col(0.96, 0.96, 0.96)), -0.6, 47.6, 0))
        case 15:
            n.addChildNode(at(cyl(4.4, 5.2, col(0.97, 0.97, 0.97)), 0.2, 41.4, 0))
            let t = ball(5.2, col(0.97, 0.97, 0.97)); t.scale = MXVector3(1, 0.5, 1)
            n.addChildNode(at(t, 0.2, 44.0, 0))
        case 16:
            let cols = [col(1, 0.4, 0.6), col(1, 0.85, 0.3), col(0.7, 0.5, 1), col(1, 0.6, 0.3)]
            for (i, z) in ([-3.6, -1.2, 1.2, 3.6] as [CGFloat]).enumerated() { n.addChildNode(at(ball(1.2, cols[i]), 0.4, 40.9, z)) }
        case 17:
            n.addChildNode(at(cyl(0.25, 5, col(0.6, 0.6, 0.64)), 0.2, 43.2, 0))
            n.addChildNode(at(ball(0.9, col(1, 0.2, 0.2)), 0.2, 46.0, 0).applyingGlow())
        case 18:
            n.addChildNode(at(box(1.0, 1.0, 9.6, c), 0.2, 40.8, 0))
            for z in [-4.9, 4.9] as [CGFloat] { n.addChildNode(at(box(2.0, 3.6, 2.4, c), 0.2, 35.6, z)) }
        case 19:
            n.addChildNode(at(cyl(4.7, 3.4, c), 0.3, 38.8, 0))
            n.addChildNode(at(cyl(6.3, 0.4, c), 0.3, 37.6, 0))
        case 20:
            dome(5.15, 0.62, 38.4, col(0.55, 0.57, 0.6))
            for z in [-5.2, 5.2] as [CGFloat] {
                let h = cone(1.1, 4.6, col(0.92, 0.9, 0.82))
                h.eulerAngles = MXVector3(Float(z > 0 ? 0.7 : -0.7), 0, 0)
                n.addChildNode(at(h, 0.3, 40.4, z))
            }
        case 21:
            n.addChildNode(at(box(10, 0.6, 10, c), 0.2, 41.0, 0))
            n.addChildNode(at(cyl(4.4, 2.2, c), 0.2, 39.6, 0))
            n.addChildNode(at(box(0.5, 2.6, 0.5, gold), 0.2, 39.6, 4.6))
        default: break
        }
        return n
    }

    /// team: coloured shoulder markers so allies and enemies read at a glance.
    /// style: the player's own designed avatar (face, outfit, build, hair, hats ...).
    /// rank: 0 = regular player, 1 = staff (hi-vis vest, cap, lanyard), 2 = admin (black suit, tie).
    static func soldier(team: UIColor, style st: TwStyle, rank: Int) -> TwSoldier {
        let root = MXNode()
        let admin = rank == 2, staff = rank == 1
        let bw: CGFloat = [0.85, 1.0, 1.12, 1.3][max(0, min(3, st.build))]
        let hs: Float = [0.93, 1.0, 1.07][max(0, min(2, st.height))]
        let skin = st.skin

        // ---- clothing colours
        let pantsCol: UIColor = admin ? col(0.07, 0.07, 0.09) : (staff ? col(0.1, 0.13, 0.22) : st.pants)
        let top: UIColor = admin ? col(0.08, 0.08, 0.1) : (staff ? col(0.08, 0.45, 0.5) : st.top)
        let tank = !admin && !staff && st.outfit == 7
        let sleeveM: MXMaterial = tank ? mat(skin) : mat(top)
        let vestC = st.vest
        let plateC = col(0.22, 0.23, 0.2)
        let bootC: UIColor = admin ? col(0.04, 0.04, 0.05) : st.shoes
        let shorts = !admin && !staff && st.pantsStyle == 3

        // ---- legs
        var legs: [MXNode] = []
        for z in [-3.5, 3.5] as [CGFloat] {
            let hip = MXNode()
            hip.position = MXVector3(0, 16, Float(z * bw))
            if shorts {
                hip.addChildNode(at(cap(3.0, 8.5, pantsCol), 0, -4.2, 0))
                hip.addChildNode(at(cap(2.2, 8.5, skin), 0, -10.2, 0))
            } else {
                hip.addChildNode(at(cap(3.0, 15, pantsCol), 0, -7.5, 0))
                if !admin && !staff {
                    if st.pantsStyle == 0 {
                        hip.addChildNode(at(box(2.0, 5, 3.4, pantsCol.withAlphaComponent(1)), 2.6, -9, 0))
                    } else if st.pantsStyle == 2 {
                        hip.addChildNode(at(box(1.8, 3.4, 4.6, col(0.12, 0.12, 0.14)), 2.4, -9.8, 0))
                    }
                }
            }
            let boot = ball(3, bootC); boot.scale = MXVector3(1.7, 0.8, 1.05)
            hip.addChildNode(at(boot, 1.6, -14.4, 0))
            root.addChildNode(hip)
            legs.append(hip)
        }

        // ---- torso + shoulders
        let sm = MXMaterial()
        sm.diffuse.contents = top
        let tg = MXSphere(radius: 1)
        tg.segmentCount = 24
        tg.materials = [sm]
        let torso = MXNode(geometry: tg)
        torso.scale = MXVector3(4.6, 8.4, Float(7.4 * bw))
        root.addChildNode(at(torso, 0, 23.8, 0))
        for z in [-7.6, 7.6] as [CGFloat] {
            root.addChildNode(at(ball(3, tank ? skin : top), 0, 29.4, z * bw))
            root.addChildNode(at(box(2.4, 1.0, 3.4, team, glow: true), 0, 32.3, z * bw))   // team marker
        }
        root.addChildNode(at(box(8, 2, 14.5 * bw, admin ? col(0.04, 0.04, 0.05) : col(0.1, 0.1, 0.08)), 0, 17.6, 0))   // belt
        let turtle = !admin && !staff && st.outfit == 3
        root.addChildNode(at(cyl(turtle ? 3.1 : 2.6, 3, turtle ? top : skin), 0.2, 31.6, 0))

        // ---- clothing details (scaled with the build)
        let roleN = MXNode()
        roleN.scale = MXVector3(1, 1, Float(bw))
        root.addChildNode(roleN)
        if admin {
            roleN.addChildNode(at(box(0.9, 5.6, 3.8, col(0.95, 0.95, 0.97)), 4.72, 26.6, 0))
            roleN.addChildNode(at(box(0.7, 6.2, 1.1, col(0.8, 0.08, 0.1)), 5.12, 26.2, 0))
            for s in [-1.0, 1.0] as [CGFloat] {
                let lap = box(0.8, 6.8, 2.4, col(0.05, 0.05, 0.07))
                lap.eulerAngles = MXVector3(0, Float(s) * 0.4, 0)
                roleN.addChildNode(at(lap, 4.9, 26.4, s * 3.0))
            }
            roleN.addChildNode(at(box(0.5, 1.0, 1.0, col(1, 0.82, 0.25), glow: true), 5.15, 28.6, 3.6))
            roleN.addChildNode(at(box(5.2, 0.7, 14.8, col(0.04, 0.04, 0.05)), 0, 20.2, 0))
        } else if staff {
            let hv = col(0.82, 0.96, 0.12)
            roleN.addChildNode(at(box(9.6, 8.6, 15.2, hv), 0, 25.6, 0))
            roleN.addChildNode(at(box(9.8, 0.9, 15.4, col(0.88, 0.88, 0.92)), 0, 23.6, 0))
            roleN.addChildNode(at(box(9.8, 0.9, 15.4, col(0.88, 0.88, 0.92)), 0, 27.6, 0))
            roleN.addChildNode(at(box(0.4, 5.6, 0.7, col(1, 1, 1)), 5.1, 26.2, 1.4))
            roleN.addChildNode(at(box(0.5, 2.8, 2.0, col(0.95, 0.95, 1)), 5.25, 22.6, 1.4))
            roleN.addChildNode(at(box(0.3, 0.8, 1.6, col(0.1, 0.55, 0.6)), 5.55, 23.4, 1.4))
        } else {
            switch st.outfit {
            case 1:   // hoodie
                let hd = ball(3.4, top); hd.scale = MXVector3(0.8, 0.9, 1.3)
                roleN.addChildNode(at(hd, -3.2, 32.4, 0))
                roleN.addChildNode(at(box(0.6, 3.6, 7.6, top.withAlphaComponent(1)), 4.9, 20.8, 0))
            case 4, 12, 13:   // jacket / varsity / kimono
                roleN.addChildNode(at(box(5.2, 0.9, 14.8, top), 0, 20.2, 0))
                roleN.addChildNode(at(box(0.5, 8, 0.6, col(0.9, 0.9, 0.92)), 4.9, 24.6, 0))
                if st.outfit == 12 { roleN.addChildNode(at(box(0.5, 1.6, 15, col(1, 1, 1)), 4.8, 27.8, 0)) }
            case 5:   // jersey
                roleN.addChildNode(at(box(0.5, 8, 1.4, col(1, 1, 1)), 4.85, 24.6, -2.6))
                roleN.addChildNode(at(box(0.5, 8, 1.4, col(1, 1, 1)), 4.85, 24.6, 2.6))
            case 6:   // suit
                roleN.addChildNode(at(box(0.9, 5.6, 3.8, col(0.95, 0.95, 0.97)), 4.72, 26.6, 0))
                roleN.addChildNode(at(box(0.7, 6.0, 1.0, col(0.8, 0.1, 0.12)), 5.1, 26.2, 0))
            case 8:   // overalls
                roleN.addChildNode(at(box(0.8, 6.6, 6.4, st.pants), 4.85, 22.8, 0))
                for z in [-2.8, 2.8] as [CGFloat] { roleN.addChildNode(at(box(0.8, 8, 1.2, st.pants), 4.8, 27.2, z)) }
            case 9:   // hawaiian
                for (i, z) in ([-4.5, -1.5, 1.5, 4.5] as [CGFloat]).enumerated() {
                    roleN.addChildNode(at(ball(0.9, i % 2 == 0 ? col(1, 0.9, 0.3) : col(1, 0.4, 0.6)), 4.7, 24 + CGFloat(i % 2) * 3, z))
                }
            case 10:  // armor tee
                roleN.addChildNode(at(box(1.3, 7.2, 9.4, col(0.23, 0.25, 0.3)), 4.95, 25.6, 0))
            case 11:  // lab coat
                roleN.addChildNode(at(box(9.8, 11.5, 15.4, col(0.95, 0.95, 0.97)), 0, 23.6, 0))
            default: break
            }
        }

        // ---- backpack
        if !admin && !staff && st.pack > 0 {
            if st.pack == 1 {
                roleN.addChildNode(at(box(3.2, 7, 8, st.packCol), -6.0, 25.5, 0))
            } else {
                roleN.addChildNode(at(box(4.6, 11, 10.5, st.packCol), -6.8, 26, 0))
                roleN.addChildNode(at(cyl(1.4, 10, st.packCol.withAlphaComponent(1)), -6.9, 20.4, 0))
            }
        }

        // ---- armor layers (toggled from the scene by the player's armor state)
        let kev = MXNode()
        kev.scale = MXVector3(1, 1, Float(bw))
        kev.addChildNode(at(box(9.8, 5, 15.4, vestC), 0, 28, 0))
        for z in [-4.0, 0.0, 4.0] as [CGFloat] { kev.addChildNode(at(box(2, 2.2, 3.4, col(0.3, 0.28, 0.2)), 5.6, 23.4, z)) }
        kev.addChildNode(at(box(1, 8, 9.5, plateC), 5, 26, 0))
        kev.addChildNode(at(box(1, 8, 9.5, plateC), -5, 26, 0))
        for z in [-3.4, 3.4] as [CGFloat] { kev.addChildNode(at(box(2.6, 3.6, 3.6, col(0.15, 0.17, 0.13)), 5.4, 20.4, z)) }
        kev.addChildNode(at(ball(3.2, vestC), 0, 30.4, -7.6))
        kev.addChildNode(at(ball(3.2, vestC), 0, 30.4, 7.6))
        kev.addChildNode(at(cyl(3.6, 3.2, col(0.78, 0.68, 0.5)), 0.2, 31.2, 0))
        kev.addChildNode(at(box(4, 12, 9, col(0.24, 0.26, 0.2)), -6.2, 24, 0))
        kev.addChildNode(at(box(2.4, 2.4, 14, col(0.12, 0.12, 0.1)), 1.2, 21.2, 0))
        kev.isHidden = true
        root.addChildNode(kev)

        let heavy = MXNode()
        heavy.scale = MXVector3(1, 1, Float(bw))
        for z in [-9.2, 9.2] as [CGFloat] { heavy.addChildNode(at(box(3.4, 3.6, 4.8, col(0.14, 0.15, 0.17)), 0, 32, z)) }
        heavy.addChildNode(at(box(1.6, 10.5, 11.5, col(0.12, 0.13, 0.15)), 5.9, 26, 0))
        heavy.addChildNode(at(box(2, 4.2, 6.6, col(0.14, 0.15, 0.17)), 5.4, 16.6, 0))
        heavy.addChildNode(at(box(0.5, 0.9, 10, col(1, 0.75, 0.2), glow: true), 6.8, 30, 0))
        heavy.addChildNode(at(box(0.5, 0.9, 10, col(1, 0.75, 0.2), glow: true), 6.8, 22.4, 0))
        heavy.isHidden = true
        root.addChildNode(heavy)

        // ---- head: round, with the illustrated face wrapped over the front
        let hg = MXSphere(radius: 4.6)
        hg.segmentCount = 28
        hg.materials = [mat(skin)]
        let headN = MXNode(geometry: hg)
        headN.scale = MXVector3(0.95, 1.12, 0.92)
        root.addChildNode(at(headN, 0.4, 35.5, 0))

        let faceMat = MXMaterial()
        faceMat.isDoubleSided = true
        faceMat.diffuse.contents = UIColor.clear
        let fpN = MXNode(geometry: facePatch(rx: 4.6 * 0.95 * 1.012, ry: 4.6 * 1.12 * 1.012, rz: 4.6 * 0.92 * 1.012, span: 10.5))
        fpN.geometry?.materials = [faceMat]
        fpN.castsShadow = false
        root.addChildNode(at(fpN, 0.4, 35.5, 0))
        TacAvatar.applyFace(faceMat, style: st)

        // ---- hair + hats (hidden together when a helmet is worn)
        let hat = MXNode()
        if staff {
            let c = ball(5, col(0.1, 0.14, 0.3)); c.scale = MXVector3(1, 0.55, 1)
            hat.addChildNode(at(c, 0.2, 38.4, 0))
            hat.addChildNode(at(box(3.8, 0.5, 7.8, col(0.08, 0.1, 0.24)), 5.4, 37.6, 0))
            hat.addChildNode(at(box(0.4, 1.5, 1.7, col(1, 0.82, 0.25), glow: true), 5.0, 38.6, 0))
        } else {
            hat.addChildNode(hair3D(st.hairStyle, st.hairCol))
            if !admin && st.hat != 0 { hat.addChildNode(hat3D(st.hat, st.hatCol)) }
        }
        root.addChildNode(hat)

        let helm = MXNode()
        helm.addChildNode(at(box(1.2, 1.6, 8.6, col(0.04, 0.04, 0.05)), 5.0, 36.6, 0))
        helm.addChildNode(at(box(0.8, 1, 8, col(0.35, 0.65, 0.9), glow: true), 5.4, 36.6, 0))
        let helmet = ball(5.4, col(0.3, 0.32, 0.24)); helmet.geometry?.materials = [camoMat(col(0.42, 0.4, 0.28), "helm")]
        helmet.scale = MXVector3(1, 0.72, 1)
        helm.addChildNode(at(helmet, 0.2, 38.0, 0))
        helm.addChildNode(at(box(2.4, 1.4, 7.5, col(0.05, 0.05, 0.07)), 4.4, 36.4, 0))
        helm.isHidden = true
        root.addChildNode(helm)

        // ---- arms + hands
        let az = Float(min(bw, 1.12))
        let rArm = cap(2.0, 12, col(0.3, 0.3, 0.22)); rArm.geometry?.materials = [sleeveM]
        rArm.eulerAngles = MXVector3(0, -0.2, Float.pi / 2 - 0.1)
        root.addChildNode(at(rArm, 6.5, 26.5, CGFloat(6 * az)))
        let lArm = cap(2.0, 16, col(0.3, 0.3, 0.22)); lArm.geometry?.materials = [sleeveM]
        lArm.eulerAngles = MXVector3(0, 0.35, Float.pi / 2 - 0.08)
        root.addChildNode(at(lArm, 8.2, 26.5, -4.6 * CGFloat(az)))
        for (hx, hy, hz) in [(12.2, 26.0, 4.8), (15.5, 26.0, -1.4)] as [(CGFloat, CGFloat, CGFloat)] {
            if admin {
                root.addChildNode(at(ball(1.9, col(0.92, 0.92, 0.94)), hx, hy, hz))
            } else if st.gloves == 2 {
                root.addChildNode(at(ball(2.15, st.gloveCol), hx, hy, hz))
            } else {
                root.addChildNode(at(ball(1.9, skin), hx, hy, hz))
                if st.gloves == 1 { root.addChildNode(at(cyl(1.9, 1.2, st.gloveCol), hx - 1.3, hy, hz)) }
            }
        }

        // ---- weapon: one detailed model per gun id
        let holder = MXNode()
        holder.position = MXVector3(10, 26.5, 1.8)
        var variants: [MXNode] = []
        for (k, w) in TWeapons.all.enumerated() {
            let gm = TwGunLib.worldGun(w.id)
            gm.isHidden = k != 0
            holder.addChildNode(gm)
            variants.append(gm)
        }
        let fl = box(6, 5, 5, col(1, 0.85, 0.3), glow: true)
        fl.position = MXVector3(TwGunLib.muzzleX(TWeapons.all[0].id) + 1, 1, 0)
        fl.isHidden = true
        holder.addChildNode(fl)
        root.addChildNode(holder)

        let face = MXNode()
        face.isHidden = true
        root.addChildNode(face)
        root.scale = MXVector3(1.25, 1.25 * hs, 1.25)
        return TwSoldier(root: root, legL: legs[0], legR: legs[1], holder: holder, variants: variants, flash: fl, shirt: sm, face: face, faceMat: faceMat, kev: kev, helm: helm, heavy: heavy, hat: hat)
    }
}

extension MXNode {
    /// emissive copy of the node's first material (used for small indicator lights)
    func applyingGlow() -> MXNode {
        if let m = geometry?.firstMaterial {
            m.emission.contents = m.diffuse.contents
            m.lightingModel = .constant
        }
        return self
    }
}

enum TGuns {
    static func get(_ id: String) -> GunDef {
        let w = TWeapons.w(id)
        return GunDef(id: w.id, name: w.name, emoji: "", dmg: w.dmg, rate: 1 / w.interval, mag: w.mag, reload: w.reload, spread: w.spread, pellets: w.pellets, speed: 1100, range: w.range, price: w.price)
    }
}
