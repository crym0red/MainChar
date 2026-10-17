import SwiftUI
import SceneKit
import UIKit

// MARK: - SwiftUI host

struct TacSceneView: UIViewRepresentable {
    let bridge: TacScene
    func makeUIView(context: Context) -> SCNView { bridge.view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

private struct LCG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
}

private func ui(_ c: (CGFloat, CGFloat, CGFloat), _ k: CGFloat = 1) -> UIColor {
    UIColor(red: min(1, c.0 * k), green: min(1, c.1 * k), blue: min(1, c.2 * k), alpha: 1)
}

// MARK: - Scene bridge

final class TacScene {
    let scene = SCNScene()
    let view = SCNView(frame: .zero)
    let camNode = SCNNode()
    var camX: CGFloat = 0
    var camZ: CGFloat = 0
    var started = false

    var roots: [SCNNode] = []
    var bodies: [SCNNode] = []
    var heads: [SCNNode] = []
    var guns: [SCNNode] = []
    var flashes: [SCNNode] = []
    var headKey: [String] = []
    var bulletPool: [SCNNode] = []
    var nadePool: [SCNNode] = []
    var boomPool: [SCNNode] = []
    var smokePool: [SCNNode] = []
    var packNodes: [SCNNode] = []
    let bombNode = SCNNode()

    private var texCache: [String: UIImage] = [:]

    // MARK: textures

    private func makeTex(_ key: String, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        if let t = texCache[key] { return t }
        let s: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { c in draw(c.cgContext, s) }
        texCache[key] = img
        return img
    }

    private func woodTex(_ base: (CGFloat, CGFloat, CGFloat), _ key: String) -> UIImage {
        makeTex(key) { g, s in
            ui(base).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 7)
            for row in 0..<4 {
                let y = CGFloat(row) * 32
                let shade = 0.9 + r.next() * 0.2
                ui(base, shade).setFill(); g.fill(CGRect(x: 0, y: y, width: s, height: 32))
                UIColor.black.withAlphaComponent(0.35).setFill(); g.fill(CGRect(x: 0, y: y, width: s, height: 2))
                let sx = CGFloat(row % 2) * 64 + r.next() * 20
                g.fill(CGRect(x: sx, y: y, width: 2, height: 32))
                for _ in 0..<5 {
                    UIColor.black.withAlphaComponent(0.08).setFill()
                    g.fill(CGRect(x: r.next() * s, y: y + 4 + r.next() * 24, width: 20 + r.next() * 30, height: 1))
                }
            }
        }
    }

    private func tileTex(_ base: (CGFloat, CGFloat, CGFloat), _ key: String) -> UIImage {
        makeTex(key) { g, s in
            ui(base).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 11)
            for i in 0..<2 {
                for j in 0..<2 {
                    ui(base, 0.94 + r.next() * 0.12).setFill()
                    g.fill(CGRect(x: CGFloat(i) * 64, y: CGFloat(j) * 64, width: 64, height: 64))
                }
            }
            UIColor.black.withAlphaComponent(0.4).setFill()
            g.fill(CGRect(x: 0, y: 0, width: s, height: 3)); g.fill(CGRect(x: 0, y: 64, width: s, height: 3))
            g.fill(CGRect(x: 0, y: 0, width: 3, height: s)); g.fill(CGRect(x: 64, y: 0, width: 3, height: s))
        }
    }

    private func noiseTex(_ base: (CGFloat, CGFloat, CGFloat), _ key: String, dots: Int, grid: Bool) -> UIImage {
        makeTex(key) { g, s in
            ui(base).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 23)
            for _ in 0..<dots {
                (r.next() > 0.5 ? UIColor.white : UIColor.black).withAlphaComponent(0.07).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 2, height: 2))
            }
            if grid {
                UIColor.black.withAlphaComponent(0.3).setFill()
                g.fill(CGRect(x: 0, y: 0, width: s, height: 2)); g.fill(CGRect(x: 0, y: 0, width: 2, height: s))
            }
        }
    }

    private func brickTex() -> UIImage {
        makeTex("brick") { g, s in
            UIColor(red: 0.2, green: 0.22, blue: 0.27, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 5)
            for row in 0..<8 {
                let y = CGFloat(row) * 16
                let off: CGFloat = row % 2 == 0 ? 0 : 16
                for k in -1..<5 {
                    let x = CGFloat(k) * 32 + off
                    let t = 0.85 + r.next() * 0.3
                    UIColor(red: 0.42 * t, green: 0.45 * t, blue: 0.52 * t, alpha: 1).setFill()
                    g.fill(CGRect(x: x + 1, y: y + 1, width: 30, height: 14))
                }
            }
        }
    }

    private func siteTex(_ letter: String, _ w: CGFloat, _ h: CGFloat) -> UIImage {
        let sz = CGSize(width: w * 2, height: h * 2)
        return UIGraphicsImageRenderer(size: sz).image { c in
            let g = c.cgContext
            UIColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.28).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: 20).fill()
            let p = UIBezierPath(roundedRect: CGRect(x: 14, y: 14, width: sz.width - 28, height: sz.height - 28), cornerRadius: 16)
            p.lineWidth = 7
            p.setLineDash([28, 16], count: 2, phase: 0)
            UIColor(red: 0.98, green: 0.8, blue: 0.08, alpha: 0.95).setStroke()
            p.stroke()
            let cr = CGRect(x: sz.width / 2 - 48, y: sz.height / 2 - 48, width: 96, height: 96)
            UIColor.black.withAlphaComponent(0.55).setFill(); g.fillEllipse(in: cr)
            UIColor.white.setStroke(); g.setLineWidth(5); g.strokeEllipse(in: cr)
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 56, weight: .heavy), .foregroundColor: UIColor.white]
            let tsz = (letter as NSString).size(withAttributes: attrs)
            (letter as NSString).draw(at: CGPoint(x: cr.midX - tsz.width / 2, y: cr.midY - tsz.height / 2), withAttributes: attrs)
        }
    }

    private func ringed(_ img: UIImage?, emoji: String, color: UIColor) -> UIImage {
        let s: CGFloat = 96
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { c in
            let g = c.cgContext
            let rect = CGRect(x: 4, y: 4, width: s - 8, height: s - 8)
            g.saveGState()
            UIBezierPath(ovalIn: rect).addClip()
            if let i = img {
                i.draw(in: rect)
            } else {
                color.withAlphaComponent(0.5).setFill(); g.fill(rect)
                (emoji as NSString).draw(in: rect.insetBy(dx: 18, dy: 14), withAttributes: [.font: UIFont.systemFont(ofSize: 44)])
            }
            g.restoreGState()
            color.setStroke()
            let p = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            p.lineWidth = 6
            p.stroke()
        }
    }

    // MARK: materials / nodes

    private func mat(_ img: UIImage?, color: UIColor = .gray, sx: CGFloat = 1, sy: CGFloat = 1, emission: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        if let i = img {
            m.diffuse.contents = i
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(sx), Float(sy), 1)
        } else {
            m.diffuse.contents = color
        }
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: 0.12, alpha: 1)
        m.shininess = 0.15
        if let e = emission { m.emission.contents = e }
        return m
    }

    private func box(_ r: CGRect, h: CGFloat, y0: CGFloat = 0, mats: [SCNMaterial], chamfer: CGFloat = 0) -> SCNNode {
        let g = SCNBox(width: r.width, height: h, length: r.height, chamferRadius: chamfer)
        g.materials = mats
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(Float(r.midX), Float(y0 + h / 2), Float(r.midY))
        return n
    }

    private func solid(_ r: CGRect, h: CGFloat, y0: CGFloat = 0, color: UIColor, top: UIColor? = nil, chamfer: CGFloat = 0, emission: UIColor? = nil) -> SCNNode {
        let side = mat(nil, color: color, emission: emission)
        let t = mat(nil, color: top ?? color, emission: emission)
        return box(r, h: h, y0: y0, mats: [side, side, side, side, t, side], chamfer: chamfer)
    }

    // MARK: build

    func build(_ e: TacticalEngine) {
        scene.background.contents = UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1)
        let root = scene.rootNode

        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 330
        amb.light?.color = UIColor(red: 0.55, green: 0.62, blue: 0.82, alpha: 1)
        root.addChildNode(amb)

        let sun = SCNNode()
        let sl = SCNLight()
        sl.type = .directional
        sl.intensity = 820
        sl.color = UIColor(red: 1, green: 0.94, blue: 0.84, alpha: 1)
        sl.castsShadow = true
        sl.shadowMode = .deferred
        sl.shadowRadius = 5
        sl.shadowSampleCount = 8
        sl.shadowColor = UIColor(white: 0, alpha: 0.6)
        sl.maximumShadowDistance = 1200
        sun.light = sl
        sun.position = SCNVector3(-300, 650, -300)
        root.addChildNode(sun)
        sun.look(at: SCNVector3(0, 0, 0))

        let lamps: [(CGFloat, CGFloat, UIColor)] = [
            (850, 900, UIColor(red: 1, green: 0.82, blue: 0.55, alpha: 1)),
            (280, 300, UIColor(red: 1, green: 0.78, blue: 0.5, alpha: 1)),
            (850, 300, UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1)),
            (1200, 300, UIColor(red: 1, green: 0.45, blue: 0.3, alpha: 1)),
            (1200, 900, UIColor(red: 1, green: 0.45, blue: 0.3, alpha: 1)),
            (1480, 300, UIColor(red: 1, green: 0.8, blue: 0.5, alpha: 1)),
            (280, 900, UIColor(red: 0.8, green: 0.88, blue: 1, alpha: 1)),
            (1480, 900, UIColor(red: 0.9, green: 0.7, blue: 1, alpha: 1))
        ]
        for l in lamps {
            let n = SCNNode()
            let li = SCNLight()
            li.type = .omni
            li.intensity = 520
            li.color = l.2
            li.attenuationStartDistance = 60
            li.attenuationEndDistance = 520
            n.light = li
            n.position = SCNVector3(Float(l.0), 170, Float(l.1))
            root.addChildNode(n)
        }

        let cam = SCNCamera()
        cam.fieldOfView = 52
        cam.zNear = 10
        cam.zFar = 3000
        camNode.camera = cam
        root.addChildNode(camNode)

        // floors
        let floorCols: [(CGFloat, CGFloat, CGFloat)] = [(0.45, 0.31, 0.19), (0.34, 0.36, 0.38), (0.27, 0.24, 0.33), (0.5, 0.54, 0.56), (0.28, 0.19, 0.13), (0.4, 0.4, 0.42)]
        for rm in TMap.rooms {
            let b = floorCols[rm.mat]
            let img: UIImage
            switch rm.mat {
            case 0: img = woodTex(b, "wood0")
            case 4: img = woodTex(b, "wood4")
            case 3, 5: img = tileTex(b, "tile\(rm.mat)")
            case 1: img = noiseTex(b, "slab", dots: 500, grid: true)
            default: img = noiseTex(b, "carpet", dots: 1400, grid: false)
            }
            let tile: CGFloat = rm.mat == 1 ? 140 : (rm.mat == 3 || rm.mat == 5 ? 112 : 128)
            let top = mat(img, sx: rm.r.width / tile, sy: rm.r.height / tile)
            let side = mat(nil, color: ui(b, 0.5))
            let n = box(rm.r, h: 1, y0: -1, mats: [side, side, side, side, top, side])
            root.addChildNode(n)
        }
        // rugs
        for rg in TMap.rugs {
            let c = UIColor(cgColor: UIColor(rg.1).cgColor)
            let n = solid(rg.0, h: 1.6, color: c, top: c)
            n.castsShadow = false
            root.addChildNode(n)
        }
        // sites
        for i in 0..<2 {
            let r = TMap.site(i)
            let m = mat(siteTex(i == 0 ? "A" : "B", r.width, r.height))
            m.lightingModel = .constant
            m.writesToDepthBuffer = false
            let clear = mat(nil, color: .clear)
            clear.transparency = 0
            let n = box(r, h: 0.4, y0: 2, mats: [clear, clear, clear, clear, m, clear])
            n.castsShadow = false
            n.renderingOrder = 5
            root.addChildNode(n)
        }
        // doors
        let doorTop = UIColor(red: 0.62, green: 0.5, blue: 0.32, alpha: 1)
        let frame = UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1)
        for d in TMap.doors {
            let n = solid(d, h: 2.4, color: doorTop, top: doorTop)
            n.castsShadow = false
            root.addChildNode(n)
            let horiz = d.width > d.height
            let p1 = horiz ? CGRect(x: d.minX - 3, y: d.midY - 6, width: 8, height: 12) : CGRect(x: d.midX - 6, y: d.minY - 3, width: 12, height: 8)
            let p2 = horiz ? CGRect(x: d.maxX - 5, y: d.midY - 6, width: 8, height: 12) : CGRect(x: d.midX - 6, y: d.maxY - 5, width: 12, height: 8)
            root.addChildNode(solid(p1, h: 74, color: frame, top: frame, chamfer: 1.5))
            root.addChildNode(solid(p2, h: 74, color: frame, top: frame, chamfer: 1.5))
        }
        // walls
        let brick = brickTex()
        for o in TMap.walls {
            let wallH: CGFloat = 70
            let front = mat(brick, sx: o.width / 128, sy: wallH / 128)
            let side = mat(brick, sx: o.height / 128, sy: wallH / 128)
            let cap = mat(nil, color: UIColor(red: 0.66, green: 0.69, blue: 0.74, alpha: 1))
            let n = box(o, h: wallH, mats: [front, side, front, side, cap, front])
            root.addChildNode(n)
        }
        // props
        for pr in TMap.props { root.addChildNode(buildProp(pr)) }
        // health packs
        for k in e.packs {
            let g = SCNNode()
            let ball = SCNNode(geometry: SCNSphere(radius: 10))
            ball.geometry?.firstMaterial = mat(nil, color: UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1), emission: UIColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1))
            let h = SCNNode(geometry: SCNBox(width: 14, height: 4, length: 4, chamferRadius: 0))
            h.geometry?.firstMaterial = mat(nil, color: .white, emission: .white)
            let v = SCNNode(geometry: SCNBox(width: 4, height: 4, length: 14, chamferRadius: 0))
            v.geometry?.firstMaterial = h.geometry?.firstMaterial
            h.position = SCNVector3(0, 10, 0)
            v.position = SCNVector3(0, 10, 0)
            ball.position = SCNVector3(0, 10, 0)
            ball.scale = SCNVector3(1, 0.3, 1)
            g.addChildNode(ball); g.addChildNode(h); g.addChildNode(v)
            g.position = SCNVector3(Float(k.pos.x), 4, Float(k.pos.y))
            g.runAction(.repeatForever(.rotateBy(x: 0, y: 2, z: 0, duration: 2)))
            root.addChildNode(g)
            packNodes.append(g)
        }
        // bomb
        let bb = SCNNode(geometry: SCNBox(width: 18, height: 10, length: 14, chamferRadius: 2))
        bb.geometry?.firstMaterial = mat(nil, color: UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1), emission: UIColor(red: 0.6, green: 0, blue: 0, alpha: 1))
        bb.position = SCNVector3(0, 5, 0)
        let bl = SCNNode()
        bl.light = SCNLight()
        bl.light?.type = .omni
        bl.light?.color = UIColor.red
        bl.light?.intensity = 500
        bl.light?.attenuationEndDistance = 200
        bl.position = SCNVector3(0, 30, 0)
        bombNode.addChildNode(bb)
        bombNode.addChildNode(bl)
        bombNode.isHidden = true
        root.addChildNode(bombNode)
        // players
        for p in e.players {
            let rt = SCNNode()
            let col: UIColor = p.isPlayer ? UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1) : (p.team == e.me.team ? UIColor(red: 0.25, green: 0.6, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
            let body = SCNNode(geometry: SCNCapsule(capRadius: 11, height: 46))
            body.geometry?.firstMaterial = mat(nil, color: col)
            body.position = SCNVector3(0, 23, 0)
            let gun = SCNNode(geometry: SCNBox(width: 26, height: 5, length: 5, chamferRadius: 1))
            gun.geometry?.firstMaterial = mat(nil, color: UIColor(white: 0.25, alpha: 1))
            gun.position = SCNVector3(18, 30, 5)
            let fl = SCNNode(geometry: SCNSphere(radius: 7))
            fl.geometry?.firstMaterial = mat(nil, color: .yellow, emission: .yellow)
            fl.position = SCNVector3(36, 30, 5)
            fl.isHidden = true
            fl.castsShadow = false
            let head = SCNNode(geometry: SCNPlane(width: 32, height: 32))
            head.position = SCNVector3(0, 58, 0)
            head.castsShadow = false
            let bbc = SCNBillboardConstraint()
            head.constraints = [bbc]
            let hm = SCNMaterial()
            hm.lightingModel = .constant
            hm.isDoubleSided = true
            hm.diffuse.contents = ringed(nil, emoji: p.emoji, color: col)
            head.geometry?.firstMaterial = hm
            rt.addChildNode(body); rt.addChildNode(gun); rt.addChildNode(fl); rt.addChildNode(head)
            root.addChildNode(rt)
            roots.append(rt); bodies.append(body); heads.append(head); guns.append(gun); flashes.append(fl)
            headKey.append("")
        }
        // pools
        for _ in 0..<60 {
            let b = SCNNode(geometry: SCNBox(width: 26, height: 2.4, length: 2.4, chamferRadius: 0))
            b.geometry?.firstMaterial = mat(nil, color: .white, emission: .white)
            b.castsShadow = false
            b.isHidden = true
            root.addChildNode(b)
            bulletPool.append(b)
        }
        for _ in 0..<6 {
            let g = SCNNode(geometry: SCNSphere(radius: 5))
            g.geometry?.firstMaterial = mat(nil, color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1))
            g.isHidden = true
            root.addChildNode(g)
            nadePool.append(g)
        }
        for _ in 0..<6 {
            let g = SCNNode(geometry: SCNSphere(radius: 1))
            let m = mat(nil, color: .orange, emission: UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1))
            m.lightingModel = .constant
            g.geometry?.firstMaterial = m
            g.castsShadow = false
            g.isHidden = true
            root.addChildNode(g)
            boomPool.append(g)
        }
        var r = LCG(s: 99)
        for _ in 0..<4 {
            let g = SCNNode()
            for i in 0..<9 {
                let s = SCNNode(geometry: SCNSphere(radius: i == 0 ? 60 : 44))
                let m = mat(nil, color: UIColor(white: 0.8, alpha: 1))
                m.lightingModel = .lambert
                s.geometry?.firstMaterial = m
                let a = CGFloat(i) * 0.7
                let d: CGFloat = i == 0 ? 0 : 42
                s.position = SCNVector3(Float(cos(a) * d), Float(40 + r.next() * 40), Float(sin(a) * d))
                s.castsShadow = false
                g.addChildNode(s)
            }
            g.isHidden = true
            root.addChildNode(g)
            smokePool.append(g)
        }

        view.scene = scene
        view.pointOfView = camNode
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.allowsCameraControl = false
    }

    // MARK: props

    private func buildProp(_ pr: TProp) -> SCNNode {
        let r = pr.r
        let g = SCNNode()
        let colors: (CGFloat, CGFloat, CGFloat)
        switch pr.k {
        case .bed: colors = (0.32, 0.4, 0.62)
        case .couch: colors = (0.55, 0.26, 0.3)
        case .table: colors = (0.62, 0.44, 0.26)
        case .counter: colors = (0.78, 0.8, 0.82)
        case .crate: colors = (0.52, 0.38, 0.22)
        case .car: colors = (0.2, 0.38, 0.62)
        case .shelf: colors = (0.3, 0.22, 0.15)
        case .barrel: colors = (0.5, 0.2, 0.14)
        case .sandbag: colors = (0.76, 0.68, 0.44)
        case .tv: colors = (0.1, 0.12, 0.16)
        case .plant: colors = (0.16, 0.45, 0.22)
        }
        let c = ui(colors)
        let cl = ui(colors, 1.2)
        switch pr.k {
        case .bed:
            g.addChildNode(solid(r, h: 14, color: ui((0.35, 0.25, 0.15)), top: ui((0.35, 0.25, 0.15))))
            g.addChildNode(solid(r.insetBy(dx: 2, dy: 2), h: 8, y0: 14, color: c, top: cl, chamfer: 3))
            g.addChildNode(solid(CGRect(x: r.minX + 8, y: r.minY + 8, width: r.width - 16, height: 26), h: 7, y0: 22, color: .white, top: .white, chamfer: 3))
        case .couch:
            g.addChildNode(solid(r, h: 18, color: c, top: cl, chamfer: 4))
            if r.width >= r.height {
                g.addChildNode(solid(CGRect(x: r.minX, y: r.minY, width: r.width, height: min(16, r.height * 0.35)), h: 34, color: ui(colors, 0.8), top: c, chamfer: 4))
            } else {
                g.addChildNode(solid(CGRect(x: r.minX, y: r.minY, width: min(16, r.width * 0.35), height: r.height), h: 34, color: ui(colors, 0.8), top: c, chamfer: 4))
            }
        case .table:
            g.addChildNode(solid(r, h: 5, y0: 24, color: c, top: cl, chamfer: 1.5))
            for (lx, ly) in [(r.minX + 4, r.minY + 4), (r.maxX - 9, r.minY + 4), (r.minX + 4, r.maxY - 9), (r.maxX - 9, r.maxY - 9)] {
                g.addChildNode(solid(CGRect(x: lx, y: ly, width: 5, height: 5), h: 24, color: ui(colors, 0.7)))
            }
        case .counter:
            g.addChildNode(solid(r, h: 36, color: ui((0.35, 0.28, 0.2)), top: ui((0.35, 0.28, 0.2))))
            g.addChildNode(solid(r.insetBy(dx: -1.5, dy: -1.5), h: 4, y0: 36, color: c, top: cl, chamfer: 1))
        case .crate:
            g.addChildNode(solid(r, h: 38, color: c, top: cl, chamfer: 2))
            g.addChildNode(solid(CGRect(x: r.minX - 1, y: r.minY - 1, width: r.width + 2, height: 5), h: 38, color: ui(colors, 0.6), top: ui(colors, 0.6)))
            g.addChildNode(solid(CGRect(x: r.minX - 1, y: r.maxY - 4, width: r.width + 2, height: 5), h: 38, color: ui(colors, 0.6), top: ui(colors, 0.6)))
        case .car:
            g.addChildNode(solid(r, h: 22, y0: 6, color: c, top: cl, chamfer: 8))
            g.addChildNode(solid(CGRect(x: r.minX + r.width * 0.3, y: r.minY + 8, width: r.width * 0.4, height: r.height - 16), h: 16, y0: 28, color: ui((0.1, 0.14, 0.2)), top: ui((0.1, 0.14, 0.2)), chamfer: 5))
            for ly in [r.minY + 10, r.maxY - 18] {
                g.addChildNode(solid(CGRect(x: r.maxX - 3, y: ly, width: 4, height: 8), h: 5, y0: 14, color: .yellow, top: .yellow, emission: UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)))
            }
        case .shelf:
            g.addChildNode(solid(r, h: 66, color: c, top: cl, chamfer: 1))
            var rr = LCG(s: UInt64(r.minX * 7 + r.minY))
            var yy: CGFloat = 12
            while yy < 62 {
                let horiz = r.width >= r.height
                let strip = horiz ? CGRect(x: r.minX + 2, y: r.maxY - 1, width: r.width - 4, height: 3) : CGRect(x: r.maxX - 1, y: r.minY + 2, width: 3, height: r.height - 4)
                let bk = UIColor(hue: rr.next(), saturation: 0.45, brightness: 0.6, alpha: 1)
                g.addChildNode(solid(strip, h: 7, y0: yy, color: bk, top: bk))
                yy += 14
            }
        case .barrel:
            let n = SCNNode(geometry: SCNCylinder(radius: r.width / 2, height: 34))
            n.geometry?.firstMaterial = mat(nil, color: c)
            n.position = SCNVector3(Float(r.midX), 17, Float(r.midY))
            g.addChildNode(n)
        case .sandbag:
            g.addChildNode(solid(r, h: 18, color: c, top: cl, chamfer: 6))
        case .tv:
            g.addChildNode(solid(r, h: 40, color: c, top: c, chamfer: 2))
            g.addChildNode(solid(CGRect(x: r.minX + 6, y: r.maxY - 2, width: r.width - 12, height: 3), h: 26, y0: 8, color: UIColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 1), top: UIColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 1), emission: UIColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1)))
        case .plant:
            let pot = SCNNode(geometry: SCNCylinder(radius: r.width * 0.28, height: 14))
            pot.geometry?.firstMaterial = mat(nil, color: ui((0.4, 0.28, 0.18)))
            pot.position = SCNVector3(Float(r.midX), 7, Float(r.midY))
            let leaf = SCNNode(geometry: SCNSphere(radius: r.width * 0.45))
            leaf.geometry?.firstMaterial = mat(nil, color: c)
            leaf.position = SCNVector3(Float(r.midX), 30, Float(r.midY))
            g.addChildNode(pot); g.addChildNode(leaf)
        }
        return g
    }

    // MARK: per-frame

    func project(_ p: CGPoint, _ h: CGFloat) -> CGPoint? {
        let v = view.projectPoint(SCNVector3(Float(p.x), Float(h), Float(p.y)))
        if v.z > 1 || v.z < 0 { return nil }
        return CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
    }

    func sync(_ e: TacticalEngine) {
        guard !e.players.isEmpty, roots.count == e.players.count else { return }
        let focus: TPlayer = e.me.alive ? e.me : (e.players.first { $0.team == e.me.team && $0.alive } ?? e.me)
        if !started { camX = focus.pos.x; camZ = focus.pos.y; started = true }
        camX += (focus.pos.x - camX) * 0.2
        camZ += (focus.pos.y - camZ) * 0.2
        let sh = e.shake
        let jx: CGFloat = sh > 0 ? CGFloat.random(in: -sh...sh) * 0.6 : 0
        let jz: CGFloat = sh > 0 ? CGFloat.random(in: -sh...sh) * 0.6 : 0
        camNode.position = SCNVector3(Float(camX + jx), 430, Float(camZ + 270 + jz))
        camNode.look(at: SCNVector3(Float(camX), 0, Float(camZ)))

        for (i, p) in e.players.enumerated() {
            let rt = roots[i]
            let show = p.team == e.me.team || p.spotted || (!p.alive && p.seenEver)
            rt.isHidden = !show
            if !show { continue }
            rt.position = SCNVector3(Float(p.pos.x), 0, Float(p.pos.y))
            rt.eulerAngles = SCNVector3(0, Float(-p.aim), 0)
            if p.alive {
                bodies[i].eulerAngles = SCNVector3(0, 0, 0)
                bodies[i].position = SCNVector3(0, 23, 0)
                heads[i].isHidden = false
                guns[i].isHidden = false
                flashes[i].isHidden = !(p.flash > 0)
                bodies[i].geometry?.firstMaterial?.emission.contents = p.hurt > 0 ? UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1) : UIColor.black
            } else {
                bodies[i].eulerAngles = SCNVector3(0, 0, Float.pi / 2)
                bodies[i].position = SCNVector3(0, 11, 0)
                heads[i].isHidden = true
                guns[i].isHidden = true
                flashes[i].isHidden = true
                bodies[i].geometry?.firstMaterial?.emission.contents = UIColor.black
            }
            let img = e.sprites[p.handle]
            let key = p.handle + (img == nil ? "-n" : "-y")
            if headKey[i] != key {
                headKey[i] = key
                let col: UIColor = p.isPlayer ? UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1) : (p.team == e.me.team ? UIColor(red: 0.25, green: 0.6, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
                heads[i].geometry?.firstMaterial?.diffuse.contents = ringed(img, emoji: p.emoji, color: col)
            }
        }
        // bullets
        for (i, node) in bulletPool.enumerated() {
            if i < e.bullets.count {
                let b = e.bullets[i]
                node.isHidden = false
                node.position = SCNVector3(Float(b.pos.x), 30, Float(b.pos.y))
                node.eulerAngles = SCNVector3(0, Float(-atan2(b.vel.dy, b.vel.dx)), 0)
                let c: UIColor = b.team == e.me.team ? UIColor(red: 0.7, green: 0.9, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1)
                node.geometry?.firstMaterial?.emission.contents = c
                node.geometry?.firstMaterial?.diffuse.contents = c
            } else { node.isHidden = true }
        }
        for (i, node) in nadePool.enumerated() {
            if i < e.nades.count {
                let g = e.nades[i]
                node.isHidden = false
                node.position = SCNVector3(Float(g.pos.x), 8, Float(g.pos.y))
                node.geometry?.firstMaterial?.diffuse.contents = g.kind == 1 ? UIColor(white: 0.75, alpha: 1) : UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
            } else { node.isHidden = true }
        }
        for (i, node) in boomPool.enumerated() {
            if i < e.booms.count {
                let b = e.booms[i]
                let total: CGFloat = b.r > 150 ? 0.8 : 0.45
                let k = min(1, max(0, 1 - b.life / total))
                let rr = b.r * (0.35 + k * 0.7)
                node.isHidden = false
                node.position = SCNVector3(Float(b.pos.x), 20, Float(b.pos.y))
                node.scale = SCNVector3(Float(rr), Float(rr * 0.6), Float(rr))
                node.opacity = CGFloat(0.65 * (1 - k))
            } else { node.isHidden = true }
        }
        for (i, node) in smokePool.enumerated() {
            if i < e.smokeClouds.count {
                let s = e.smokeClouds[i]
                node.isHidden = false
                node.position = SCNVector3(Float(s.pos.x), 0, Float(s.pos.y))
                let sc = Float(s.r / 85)
                node.scale = SCNVector3(sc, sc, sc)
                node.opacity = min(1, s.life / 1.5) * 0.93
                node.eulerAngles = SCNVector3(0, Float(e.time * 0.2), 0)
            } else { node.isHidden = true }
        }
        for (i, node) in packNodes.enumerated() where i < e.packs.count {
            node.isHidden = e.packs[i].taken
        }
        bombNode.isHidden = !e.planted
        if e.planted {
            bombNode.position = SCNVector3(Float(e.bombPos.x), 0, Float(e.bombPos.y))
        }
    }
}

// MARK: - Overlay drawn above the 3D view

extension TacticalEngine {
    func drawOverlay3D(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard let pr = project else { return }
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        // fog of war
        let vp = focus.pos
        var poly = Path()
        var ok = true
        let n = 120
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let d = TMap.rayDist(vp, a, 700)
            let hit = d < 699
            guard let pt = pr(CGPoint(x: vp.x + cos(a) * d, y: vp.y + sin(a) * d), hit ? 62 : 0) else { ok = false; break }
            if i == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
        }
        if ok {
            poly.closeSubpath()
            var dark = Path(CGRect(x: -60, y: -60, width: size.width + 120, height: size.height + 120))
            dark.addPath(poly)
            ctx.fill(dark, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
        }
        // name tags
        for p in players where p.alive && (p.team == me.team || p.spotted) {
            guard let pt = pr(p.pos, 84) else { continue }
            let ally = p.team == me.team
            let col: Color = p.isPlayer ? Color(red: 0.4, green: 0.95, blue: 0.5) : (ally ? Color(red: 0.25, green: 0.6, blue: 1) : Color(red: 1, green: 0.25, blue: 0.3))
            ctx.draw(Text(p.name).font(.system(size: 11, weight: .bold)).foregroundColor(col), at: CGPoint(x: pt.x, y: pt.y - 6))
            let bar = CGRect(x: pt.x - 20, y: pt.y + 2, width: 40, height: 4)
            ctx.fill(Path(bar), with: .color(.black.opacity(0.6)))
            ctx.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: 40 * max(0, p.hp / 100), height: 4)), with: .color(col))
            if p.reloadT > 0 {
                ctx.draw(Text("reload").font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.85)), at: CGPoint(x: pt.x, y: pt.y + 14))
            }
        }
        // pings
        for pg in pings {
            guard let pt = pr(pg.pos, 40) else { continue }
            let al = Double(min(1, pg.life))
            var dm = Path()
            dm.move(to: CGPoint(x: pt.x, y: pt.y - 12)); dm.addLine(to: CGPoint(x: pt.x + 8, y: pt.y - 22))
            dm.addLine(to: CGPoint(x: pt.x, y: pt.y - 32)); dm.addLine(to: CGPoint(x: pt.x - 8, y: pt.y - 22)); dm.closeSubpath()
            ctx.fill(dm, with: .color(Color.orange.opacity(al)))
            ctx.draw(Text(pg.text).font(.system(size: 12, weight: .heavy)).foregroundColor(Color.yellow.opacity(al)), at: CGPoint(x: pt.x, y: pt.y - 44))
        }
        for pp in pops {
            guard let pt = pr(pp.pos, 50 + (1 - pp.life) * 40) else { continue }
            ctx.draw(Text(pp.text).font(.system(size: 16, weight: .heavy)).foregroundColor(pp.color.opacity(Double(pp.life))), at: pt)
        }
        if planted, let pt = pr(bombPos, 36) {
            ctx.draw(Text(String(format: "%.0f", max(0, bombT))).font(.system(size: 14, weight: .heavy)).foregroundColor(.white), at: pt)
        }
        let vg = Gradient(colors: [Color.clear, Color.black.opacity(0.5)])
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(vg, center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: min(size.width, size.height) * 0.45, endRadius: max(size.width, size.height) * 0.72))
        drawMinimapPublic(&ctx)
        if me.hurt > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.red.opacity(Double(me.hurt) * 0.45)))
        }
        if !me.alive {
            ctx.draw(Text("SPECTATING " + focus.name.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.7)), at: CGPoint(x: size.width / 2, y: size.height - 70))
        }
    }
}

extension TacScene {
    func orbit(_ time: Double) {
        let a = time * 0.12
        let cx: Double = 850, cz: Double = 600
        camNode.position = SCNVector3(Float(cx + cos(a) * 520), 300, Float(cz + sin(a) * 420))
        camNode.look(at: SCNVector3(Float(cx), 20, Float(cz)))
    }
}
