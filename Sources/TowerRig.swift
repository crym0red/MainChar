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
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: min(w, h, l) * 0.28)
        g.chamferSegmentCount = 2
        g.materials = [mat(c, glow: glow)]
        return SCNNode(geometry: g)
    }

    static func ball(_ r: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNSphere(radius: r)
        g.segmentCount = 20
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
        g.radialSegmentCount = 20
        g.capSegmentCount = 8
        g.materials = [mat(c)]
        return SCNNode(geometry: g)
    }

    private static var camoCache: [String: SCNMaterial] = [:]
    static func camoMat(_ base: UIColor, _ key: String) -> SCNMaterial {
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
        let m = SCNMaterial()
        m.diffuse.contents = img
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        camoCache[key] = m
        return m
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
        let pants = col(0.5, 0.43, 0.3)
        let pantsM = camoMat(pants, "pants")
        let vest = col(0.36, 0.34, 0.26)
        let plate = col(0.22, 0.23, 0.2)
        var legs: [SCNNode] = []
        for z in [-3.5, 3.5] as [CGFloat] {
            let hip = SCNNode()
            hip.position = SCNVector3(0, 16, Float(z))
            let th = cap(3.0, 15, pants); th.geometry?.materials = [pantsM]
            hip.addChildNode(at(th, 0, -7.5, 0))
            let kp = cap(3.5, 5, col(0.2, 0.2, 0.17)); hip.addChildNode(at(kp, 0.6, -9, 0))
            let boot = ball(3, col(0.12, 0.09, 0.07)); boot.scale = SCNVector3(1.7, 0.8, 1.05)
            hip.addChildNode(at(boot, 1.6, -14.4, 0))
            root.addChildNode(hip)
            legs.append(hip)
        }
        let sm = SCNMaterial()
        sm.diffuse.contents = shirt
        let tg = SCNSphere(radius: 1)
        tg.segmentCount = 24
        tg.materials = [sm]
        let torso = SCNNode(geometry: tg)
        torso.scale = SCNVector3(4.6, 8.4, 7.4)
        root.addChildNode(at(torso, 0, 23.8, 0))
        for z in [-7.6, 7.6] as [CGFloat] { root.addChildNode(at(ball(3, shirt), 0, 29.4, z)) }
        root.addChildNode(at(box(9.8, 5, 15.4, vest), 0, 28, 0))
        root.addChildNode(at(box(2, 2.2, 3.4, col(0.3, 0.28, 0.2)), 5.6, 23.4, -4))
        root.addChildNode(at(box(2, 2.2, 3.4, col(0.3, 0.28, 0.2)), 5.6, 23.4, 0))
        root.addChildNode(at(box(2, 2.2, 3.4, col(0.3, 0.28, 0.2)), 5.6, 23.4, 4))
        root.addChildNode(at(box(1, 8, 9.5, plate), 5, 26, 0))
        root.addChildNode(at(box(1, 8, 9.5, plate), -5, 26, 0))
        root.addChildNode(at(box(2.6, 3.6, 3.6, col(0.15, 0.17, 0.13)), 5.4, 20.4, -3.4))
        root.addChildNode(at(box(2.6, 3.6, 3.6, col(0.15, 0.17, 0.13)), 5.4, 20.4, 3.4))
        root.addChildNode(at(box(8, 2, 14.5, col(0.1, 0.1, 0.08)), 0, 17.6, 0))
        root.addChildNode(at(ball(3.2, vest), 0, 30.4, -7.6))
        root.addChildNode(at(ball(3.2, vest), 0, 30.4, 7.6))
        root.addChildNode(at(cyl(2.6, 3, skin), 0.2, 31.6, 0))
        root.addChildNode(at(cyl(3.6, 3.2, col(0.78, 0.68, 0.5)), 0.2, 31.2, 0))
        root.addChildNode(at(box(4, 12, 9, col(0.24, 0.26, 0.2)), -6.2, 24, 0))
        root.addChildNode(at(box(2.4, 2.4, 14, col(0.12, 0.12, 0.1)), 1.2, 21.2, 0))
        let head = ball(4.6, skin); head.scale = SCNVector3(0.95, 1.12, 0.92)
        root.addChildNode(at(head, 0.4, 35.5, 0))
        root.addChildNode(at(box(1.2, 1.6, 8.6, col(0.04, 0.04, 0.05)), 4.7, 36.2, 0))
        root.addChildNode(at(box(0.8, 1, 8, col(0.35, 0.65, 0.9), glow: true), 5.1, 36.2, 0))
        let helmet = ball(5.2, col(0.3, 0.32, 0.24)); helmet.geometry?.materials = [camoMat(col(0.42, 0.4, 0.28), "helm")]
        helmet.scale = SCNVector3(1, 0.72, 1)
        root.addChildNode(at(helmet, 0.2, 37.6, 0))
        root.addChildNode(at(box(2.4, 1.4, 7.5, col(0.05, 0.05, 0.07)), 4.1, 36, 0))
        let rArm = cap(2.0, 12, col(0.3, 0.3, 0.22)); rArm.geometry?.materials = [pantsM]
        rArm.eulerAngles.z = Float.pi / 2
        rArm.eulerAngles = SCNVector3(0, -0.2, Float.pi / 2 - 0.1)
        root.addChildNode(at(rArm, 6.5, 26.5, 6))
        root.addChildNode(at(ball(1.9, skin), 12.2, 26, 4.8))
        let lArm = cap(2.0, 16, col(0.3, 0.3, 0.22)); lArm.geometry?.materials = [pantsM]
        lArm.eulerAngles = SCNVector3(0, 0.35, Float.pi / 2 - 0.08)
        root.addChildNode(at(lArm, 8.2, 26.5, -4.6))
        root.addChildNode(at(ball(1.9, skin), 15.5, 26, -1.4))
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
