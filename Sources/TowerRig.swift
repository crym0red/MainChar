import SwiftUI
import SceneKit

/// Shared soldier model (vest, arms, legs, 3D firearms) used by the 5v5 scene.
struct TwSoldier {
    var root: SCNNode
    var legL: SCNNode
    var legR: SCNNode
    var holder: SCNNode
    var variants: [SCNNode]
    var flash: SCNNode
    var shirt: SCNMaterial
    var face: SCNNode
    var faceMat: SCNMaterial
}

enum TwRig {
    static func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: min(1, r), green: min(1, g), blue: min(1, b), alpha: 1) }

    static func mat(_ c: UIColor, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant }
        return m
    }

    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, glow: Bool = false) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        g.materials = [mat(c, glow: glow)]
        return SCNNode(geometry: g)
    }

    static func ball(_ r: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNSphere(radius: r)
        g.segmentCount = 10
        g.materials = [mat(c)]
        return SCNNode(geometry: g)
    }

    static func cyl(_ r: CGFloat, _ h: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h)
        g.radialSegmentCount = 10
        g.materials = [mat(c)]
        return SCNNode(geometry: g)
    }

    static func cap(_ rad: CGFloat, _ h: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNCapsule(capRadius: rad, height: max(h, rad * 2 + 0.1))
        g.radialSegmentCount = 12
        g.materials = [mat(c)]
        return SCNNode(geometry: g)
    }

    static func at(_ n: SCNNode, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> SCNNode {
        n.position = SCNVector3(Float(x), Float(y), Float(z))
        return n
    }

    static func gunIdx(_ id: String) -> Int {
        switch id {
        case "smg": return 1
        case "rifle": return 2
        case "shotgun": return 3
        default: return 0
        }
    }

    static let flashX: [Float] = [10, 16, 29, 34]

    static func gunModel(_ k: Int, tint: UIColor?) -> SCNNode {
        let n = SCNNode()
        let metal = col(0.1, 0.1, 0.12)
        let metal2 = tint ?? col(0.2, 0.2, 0.23)
        let wood = tint.map { _ in metal2 } ?? col(0.3, 0.2, 0.12)
        switch k {
        case 0:
            n.addChildNode(at(box(9, 2.4, 2.4, metal2), 4, 1.5, 0))
            let grip = box(2.4, 5.5, 2.4, metal)
            grip.eulerAngles = SCNVector3(0, 0, 0.18)
            n.addChildNode(at(grip, 0.8, -1.4, 0))
            n.addChildNode(at(box(1, 1, 1, col(1, 1, 1)), 8.4, 3, 0))
        case 1:
            n.addChildNode(at(box(14, 3.2, 3, metal), 5, 0, 0))
            n.addChildNode(at(box(5, 1.4, 1.4, metal2), 14, 0.4, 0))
            let mag = box(2.4, 7, 2.2, metal2)
            mag.eulerAngles = SCNVector3(0, 0, 0.12)
            n.addChildNode(at(mag, 4, -4.5, 0))
            n.addChildNode(at(box(2.4, 5, 2.4, metal), -1, -3.2, 0))
            n.addChildNode(at(box(3, 1.2, 1.2, metal2), 2, 2.4, 0))
            n.addChildNode(at(box(5, 2, 2.6, metal2), -4.5, 0.4, 0))
        case 2:
            n.addChildNode(at(box(16, 3.4, 3.2, metal), 4, 0, 0))
            n.addChildNode(at(box(10, 3, 3, metal2), 15, 0.1, 0))
            n.addChildNode(at(box(8, 1.3, 1.3, metal), 24, 0.6, 0))
            n.addChildNode(at(box(9, 4, 2.8, wood), -8, -0.6, 0))
            let mag = box(2.6, 8, 2.4, metal2)
            mag.eulerAngles = SCNVector3(0, 0, 0.3)
            n.addChildNode(at(mag, 5, -5.5, 0))
            n.addChildNode(at(box(2.4, 5, 2.4, metal), -0.5, -3.6, 0))
            n.addChildNode(at(box(7, 2.2, 2.4, metal2), 6, 3.6, 0))
            let sc = cyl(1.2, 7, col(0.1, 0.1, 0.12))
            sc.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            n.addChildNode(at(sc, 6, 4.6, 0))
        default:
            n.addChildNode(at(box(26, 2.2, 2.2, metal), 12, 1.2, 0))
            n.addChildNode(at(box(18, 1.8, 1.8, metal2), 11, -1.4, 0))
            n.addChildNode(at(box(8, 3.2, 3.4, wood), 14, -1.4, 0))
            n.addChildNode(at(box(11, 4, 2.8, wood), -6, -0.4, 0))
            n.addChildNode(at(box(5, 3, 2.6, metal), 1, 0.4, 0))
        }
        return n
    }

    static func soldier(shirt: UIColor, skin: UIColor, tint: UIColor?) -> TwSoldier {
        let root = SCNNode()
        let pants = col(0.16, 0.17, 0.2)
        let vest = col(0.2, 0.22, 0.18)
        let plate = col(0.32, 0.34, 0.3)
        var legs: [SCNNode] = []
        for z in [-3.5, 3.5] as [CGFloat] {
            let hip = SCNNode()
            hip.position = SCNVector3(0, 16, Float(z))
            hip.addChildNode(at(cap(3.0, 15, pants), 0, -7.5, 0))
            hip.addChildNode(at(cap(3.2, 6, col(0.14, 0.15, 0.17)), 0, -2, 0))
            hip.addChildNode(at(box(9, 3.6, 6, col(0.1, 0.08, 0.06)), 1.4, -14.6, 0))
            root.addChildNode(hip)
            legs.append(hip)
        }
        let sm = SCNMaterial()
        sm.diffuse.contents = shirt
        let tg = SCNBox(width: 8, height: 14, length: 14, chamferRadius: 0.8)
        tg.materials = [sm]
        root.addChildNode(at(SCNNode(geometry: tg), 0, 23.5, 0))
        root.addChildNode(at(box(9.4, 11.5, 15, vest), 0, 24.5, 0))
        root.addChildNode(at(box(1, 8, 9.5, plate), 5, 26, 0))
        root.addChildNode(at(box(1, 8, 9.5, plate), -5, 26, 0))
        root.addChildNode(at(box(2.6, 3.6, 3.6, col(0.15, 0.17, 0.13)), 5.4, 20.4, -3.4))
        root.addChildNode(at(box(2.6, 3.6, 3.6, col(0.15, 0.17, 0.13)), 5.4, 20.4, 3.4))
        root.addChildNode(at(box(8, 2, 14.5, col(0.1, 0.1, 0.08)), 0, 17.6, 0))
        root.addChildNode(at(box(5, 3, 4.5, vest), 0, 30, -8))
        root.addChildNode(at(box(5, 3, 4.5, vest), 0, 30, 8))
        root.addChildNode(at(cyl(2.6, 3, skin), 0.2, 31.6, 0))
        root.addChildNode(at(cyl(3.6, 3.2, col(0.78, 0.68, 0.5)), 0.2, 31.2, 0))
        root.addChildNode(at(box(4, 12, 9, col(0.24, 0.26, 0.2)), -6.2, 24, 0))
        root.addChildNode(at(box(2.4, 2.4, 14, col(0.12, 0.12, 0.1)), 1.2, 21.2, 0))
        root.addChildNode(at(ball(4.6, skin), 0.4, 35.5, 0))
        root.addChildNode(at(box(1.2, 1.6, 8.6, col(0.04, 0.04, 0.05)), 4.7, 36.2, 0))
        root.addChildNode(at(box(0.8, 1, 8, col(0.35, 0.65, 0.9), glow: true), 5.1, 36.2, 0))
        let helmet = ball(5.2, col(0.18, 0.2, 0.17))
        helmet.scale = SCNVector3(1, 0.72, 1)
        root.addChildNode(at(helmet, 0.2, 37.6, 0))
        root.addChildNode(at(box(2.4, 1.4, 7.5, col(0.05, 0.05, 0.07)), 4.1, 36, 0))
        let rArm = cap(2.0, 12, col(0.3, 0.3, 0.22))
        rArm.eulerAngles.z = Float.pi / 2
        rArm.eulerAngles = SCNVector3(0, -0.2, Float.pi / 2 - 0.1)
        root.addChildNode(at(rArm, 6.5, 26.5, 6))
        root.addChildNode(at(box(3.2, 3.2, 3.2, skin), 12.2, 26, 4.8))
        let lArm = cap(2.0, 16, col(0.3, 0.3, 0.22))
        lArm.eulerAngles = SCNVector3(0, 0.35, Float.pi / 2 - 0.08)
        root.addChildNode(at(lArm, 8.2, 26.5, -4.6))
        root.addChildNode(at(box(3.2, 3.2, 3.2, skin), 15.5, 26, -1.4))
        let holder = SCNNode()
        holder.position = SCNVector3(10, 26.5, 1.8)
        var variants: [SCNNode] = []
        for k in 0..<4 {
            let gm = gunModel(k, tint: tint)
            gm.isHidden = k != 0
            holder.addChildNode(gm)
            variants.append(gm)
        }
        let fl = box(6, 5, 5, col(1, 0.85, 0.3), glow: true)
        fl.position = SCNVector3(flashX[0], 1, 0)
        fl.isHidden = true
        holder.addChildNode(fl)
        root.addChildNode(holder)
        // avatar badge on top of the helmet (readable from the top-down camera)
        let faceMat = SCNMaterial()
        faceMat.lightingModel = .constant
        faceMat.isDoubleSided = true
        faceMat.diffuse.contents = UIColor.gray
        let fp = SCNPlane(width: 14, height: 14)
        fp.materials = [faceMat]
        let pn = SCNNode(geometry: fp)
        pn.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        let face = SCNNode()
        face.position = SCNVector3(0.2, 42.6, 0)
        face.addChildNode(pn)
        root.addChildNode(face)
        root.scale = SCNVector3(1.25, 1.25, 1.25)
        return TwSoldier(root: root, legL: legs[0], legR: legs[1], holder: holder, variants: variants, flash: fl, shirt: sm, face: face, faceMat: faceMat)
    }
}

enum TGuns {
    /// 5v5 uses the exact BR weapons (damage, rate, mag, range, names).
    static func get(_ id: String) -> GunDef {
        let b = BRGuns.def(id)
        let o = Guns.get(id)
        return GunDef(id: b.id, name: b.name, emoji: o.emoji, dmg: b.dmg, rate: 1 / b.rate, mag: b.mag, reload: b.reload, spread: b.spread, pellets: b.pellets, speed: o.speed, range: b.range, price: o.price)
    }
}
