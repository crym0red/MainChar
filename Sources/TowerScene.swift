import SwiftUI
import SceneKit
import QuartzCore

struct TowerSceneView: UIViewRepresentable {
    let bridge: TowerScene
    func makeUIView(context: Context) -> SCNView {
        bridge.view.contentScaleFactor = min(UIScreen.main.scale, 2)
        return bridge.view
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

private func twCol(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
    UIColor(red: min(1, r), green: min(1, g), blue: min(1, b), alpha: a)
}

private struct TwLCG {
    var s: UInt64
    mutating func n() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
}

final class TowerScene {
    let scene = SCNScene()
    let view = SCNView(frame: .zero)
    let camNode = SCNNode()
    var camX: CGFloat = 800
    var camZ: CGFloat = 500
    var camH: CGFloat = 360
    var leadX: CGFloat = 0
    var leadZ: CGFloat = 0
    var focus = 0
    var vs: [TwView] = []
    var seenIdx: [Int] = []
    var lastKC = false
    var floorRoots: [SCNNode] = []
    var doorNodes: [[SCNNode]] = []
    var doorAngShown: [[Float]] = []

    // actors
    var actorRoots: [SCNNode] = []
    var legL: [SCNNode] = []
    var legR: [SCNNode] = []
    var gunGroups: [[SCNNode]] = []
    var gunHolder: [SCNNode] = []
    var flashNodes: [SCNNode] = []
    var shirtMats: [SCNMaterial] = []
    var gunShown: [Int] = []
    var flashShown: [Bool] = []
    var hurtShown: [Bool] = []
    var lootPool: [SCNNode] = []
    var lootKey: [Int] = []
    var tracerPool: [SCNNode] = []
    var tracerKind: [Int] = []
    let gasNode = SCNNode()
    let warnNode = SCNNode()
    private var lootGeo: [Int: SCNGeometry] = [:]
    private var tracerGeo: [SCNGeometry] = []
    private var texCache: [String: UIImage] = [:]
    let map: TowerMap
    private var def: MapDef { map.def }
    var glassNodes: [[SCNNode]] = []
    var beltNodes: [[SCNNode]] = []
    var beltVel: [[CGFloat]] = []
    var beltLen: [[CGFloat]] = []
    var switchNodes: [SCNNode] = []
    var trainNodes: [SCNNode] = []
    var doorKindShown: [[Int]] = []
    var poolRoots: [SCNNode] = []
    var quality = 2
    var sunNode: SCNNode? = nil
    var fpsEMA: CGFloat = 60
    var lowTime: CGFloat = 0
    private var rng = TwLCG(s: 4242)


    // MARK: textures

    private func tex(_ key: String, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        if let t = texCache[key] { return t }
        let s: CGFloat = 256
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: fmt).image { c in draw(c.cgContext, s) }
        texCache[key] = img
        return img
    }

    private func grime(_ g: CGContext, _ s: CGFloat, _ seed: UInt64, _ amt: CGFloat) {
        var r = TwLCG(s: seed)
        for _ in 0..<Int(16 * amt) {
            let w = 30 + r.n() * 90, h = 20 + r.n() * 70
            g.setFillColor(twCol(0, 0, 0, 0.025 + r.n() * 0.05).cgColor)
            g.fillEllipse(in: CGRect(x: r.n() * s - w / 2, y: r.n() * s - h / 2, width: w, height: h))
        }
        for _ in 0..<Int(5 * amt) {
            let w = 40 + r.n() * 80
            g.setFillColor(twCol(1, 1, 1, 0.02 + r.n() * 0.03).cgColor)
            g.fillEllipse(in: CGRect(x: r.n() * s - w / 2, y: r.n() * s - w / 2, width: w, height: w * 0.7))
        }
        for _ in 0..<Int(700 * amt) {
            g.setFillColor(twCol(0, 0, 0, 0.08 + r.n() * 0.16).cgColor)
            let d = 0.8 + r.n() * 1.6
            g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: d, height: d))
        }
        for _ in 0..<Int(260 * amt) {
            g.setFillColor(twCol(1, 1, 1, 0.05 + r.n() * 0.1).cgColor)
            g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: 1, height: 1))
        }
        g.setLineWidth(0.8)
        for _ in 0..<Int(9 * amt) {
            g.setStrokeColor(twCol(1, 1, 1, 0.07 + r.n() * 0.08).cgColor)
            let x = r.n() * s, y = r.n() * s
            g.move(to: CGPoint(x: x, y: y))
            g.addLine(to: CGPoint(x: x + (r.n() - 0.5) * 60, y: y + (r.n() - 0.5) * 60))
            g.strokePath()
        }
        // dirt at the slab edges
        g.setStrokeColor(twCol(0, 0, 0, 0.22).cgColor)
        g.setLineWidth(5)
        g.stroke(CGRect(x: 0, y: 0, width: s, height: s))
    }

    private func decalTex(_ k: Int) -> UIImage {
        tex("decal\(k)") { g, s in
            var r = TwLCG(s: UInt64(k * 31 + 7))
            switch k {
            case 0: // stain
                for _ in 0..<7 {
                    let w = 40 + r.n() * 110
                    g.setFillColor(twCol(0.05, 0.04, 0.03, 0.10 + r.n() * 0.10).cgColor)
                    g.fillEllipse(in: CGRect(x: s / 2 - w / 2 + (r.n() - 0.5) * 50, y: s / 2 - w * 0.35 + (r.n() - 0.5) * 40, width: w, height: w * 0.7))
                }
            case 1: // scorch / oil
                let cols = [twCol(0, 0, 0, 0.55).cgColor, twCol(0, 0, 0, 0).cgColor] as CFArray
                if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                    g.drawRadialGradient(gr, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0, endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2, options: [])
                }
            case 2: // loose papers
                for _ in 0..<9 {
                    g.saveGState()
                    g.translateBy(x: s / 2 + (r.n() - 0.5) * 150, y: s / 2 + (r.n() - 0.5) * 120)
                    g.rotate(by: r.n() * 6.28)
                    let v = 0.78 + r.n() * 0.2
                    g.setFillColor(twCol(v, v, v * 0.95, 0.92).cgColor)
                    g.fill(CGRect(x: -12, y: -16, width: 24, height: 32))
                    g.setFillColor(twCol(0.3, 0.3, 0.35, 0.5).cgColor)
                    for l in 0..<4 { g.fill(CGRect(x: -9, y: -11 + CGFloat(l) * 6, width: 16, height: 1.5)) }
                    g.restoreGState()
                }
            default: // crack
                g.setStrokeColor(twCol(0, 0, 0, 0.7).cgColor)
                g.setLineWidth(2)
                var p = CGPoint(x: 10, y: s * 0.3 + r.n() * s * 0.4)
                g.move(to: p)
                while p.x < s - 10 {
                    p = CGPoint(x: p.x + 10 + r.n() * 24, y: p.y + (r.n() - 0.5) * 36)
                    g.addLine(to: p)
                }
                g.strokePath()
            }
        }
    }

    private func floorTex(_ kind: String) -> UIImage {
        tex("f_" + kind) { g, s in
            var r = TwLCG(s: UInt64(kind.hashValue & 0xFFFF) + 9)
            switch kind {
            case "carpet":
                g.setFillColor(twCol(0.82, 0.82, 0.84).cgColor)
                g.fill(CGRect(x: 0, y: 0, width: s, height: s))
                for _ in 0..<900 {
                    let v = 0.62 + r.n() * 0.34
                    g.setFillColor(twCol(v, v, v, 0.55).cgColor)
                    g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: 2, height: 2))
                }
            case "tile":
                for j in 0..<2 {
                    for i in 0..<2 {
                        let v: CGFloat = (i + j) % 2 == 0 ? 0.92 : 0.8
                        g.setFillColor(twCol(v, v, v).cgColor)
                        g.fill(CGRect(x: CGFloat(i) * s / 2, y: CGFloat(j) * s / 2, width: s / 2, height: s / 2))
                    }
                }
                g.setStrokeColor(twCol(0.45, 0.45, 0.48).cgColor)
                g.setLineWidth(2)
                g.stroke(CGRect(x: 0, y: 0, width: s / 2, height: s / 2))
                g.stroke(CGRect(x: s / 2, y: s / 2, width: s / 2, height: s / 2))
                g.stroke(CGRect(x: s / 2, y: 0, width: s / 2, height: s / 2))
                g.stroke(CGRect(x: 0, y: s / 2, width: s / 2, height: s / 2))
            case "wood":
                for k in 0..<4 {
                    let v = 0.72 + r.n() * 0.25
                    g.setFillColor(twCol(v, v * 0.9, v * 0.8).cgColor)
                    g.fill(CGRect(x: 0, y: CGFloat(k) * s / 4, width: s, height: s / 4))
                    g.setStrokeColor(twCol(0.25, 0.18, 0.12, 0.8).cgColor)
                    g.setLineWidth(1.5)
                    g.stroke(CGRect(x: 0, y: CGFloat(k) * s / 4, width: s, height: s / 4))
                    let jx = r.n() * s
                    g.move(to: CGPoint(x: jx, y: CGFloat(k) * s / 4))
                    g.addLine(to: CGPoint(x: jx, y: CGFloat(k + 1) * s / 4))
                    g.strokePath()
                    for _ in 0..<6 {
                        g.setStrokeColor(twCol(0.3, 0.2, 0.1, 0.18).cgColor)
                        let y = CGFloat(k) * s / 4 + r.n() * s / 4
                        g.move(to: CGPoint(x: r.n() * s, y: y))
                        g.addLine(to: CGPoint(x: r.n() * s, y: y + 1))
                        g.strokePath()
                    }
                }
            case "marble":
                g.setFillColor(twCol(0.9, 0.9, 0.92).cgColor)
                g.fill(CGRect(x: 0, y: 0, width: s, height: s))
                for _ in 0..<7 {
                    g.setStrokeColor(twCol(0.5, 0.52, 0.58, 0.28).cgColor)
                    g.setLineWidth(1 + r.n() * 1.5)
                    g.move(to: CGPoint(x: r.n() * s, y: 0))
                    g.addCurve(to: CGPoint(x: r.n() * s, y: s), control1: CGPoint(x: r.n() * s, y: s * 0.33), control2: CGPoint(x: r.n() * s, y: s * 0.66))
                    g.strokePath()
                }
                g.setStrokeColor(twCol(0.55, 0.55, 0.6, 0.7).cgColor)
                g.setLineWidth(2)
                g.stroke(CGRect(x: 0, y: 0, width: s, height: s))
            case "metal":
                g.setFillColor(twCol(0.5, 0.52, 0.56).cgColor)
                g.fill(CGRect(x: 0, y: 0, width: s, height: s))
                g.setStrokeColor(twCol(0.22, 0.23, 0.26).cgColor)
                g.setLineWidth(2)
                g.stroke(CGRect(x: 1, y: 1, width: s - 2, height: s - 2))
                g.setFillColor(twCol(0.3, 0.31, 0.35).cgColor)
                for (x, y) in [(10.0, 10.0), (s - 14, 10.0), (10.0, s - 14), (s - 14, s - 14)] as [(CGFloat, CGFloat)] { g.fillEllipse(in: CGRect(x: x, y: y, width: 5, height: 5)) }
                for _ in 0..<300 {
                    let v = 0.4 + r.n() * 0.2
                    g.setFillColor(twCol(v, v, v + 0.03, 0.5).cgColor)
                    g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: 2, height: 2))
                }
            case "grate":
                g.setFillColor(twCol(0.1, 0.1, 0.12).cgColor)
                g.fill(CGRect(x: 0, y: 0, width: s, height: s))
                g.setStrokeColor(twCol(0.62, 0.64, 0.68).cgColor)
                g.setLineWidth(3)
                for k in 0..<8 {
                    let v = CGFloat(k) * s / 8
                    g.move(to: CGPoint(x: v, y: 0)); g.addLine(to: CGPoint(x: v, y: s))
                    g.move(to: CGPoint(x: 0, y: v)); g.addLine(to: CGPoint(x: s, y: v))
                }
                g.strokePath()
            default:
                g.setFillColor(twCol(0.68, 0.68, 0.7).cgColor)
                g.fill(CGRect(x: 0, y: 0, width: s, height: s))
                for _ in 0..<700 {
                    let v = 0.5 + r.n() * 0.4
                    g.setFillColor(twCol(v, v, v, 0.5).cgColor)
                    g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: 2, height: 2))
                }
                g.setStrokeColor(twCol(0.35, 0.35, 0.38, 0.8).cgColor)
                g.setLineWidth(1.5)
                g.stroke(CGRect(x: 0, y: 0, width: s, height: s))
            }
            grime(g, s, UInt64(kind.hashValue & 0xFFFF) + 101, kind == "grate" ? 0.25 : kind == "marble" ? 0.6 : 1)
        }
    }

    private var wallTex: UIImage {
        tex("wall") { g, s in
            g.setFillColor(twCol(0.9, 0.9, 0.92).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            // panel seams
            g.setStrokeColor(twCol(0.7, 0.7, 0.74).cgColor)
            g.setLineWidth(2)
            g.move(to: CGPoint(x: 1, y: 0)); g.addLine(to: CGPoint(x: 1, y: s)); g.strokePath()
            g.setFillColor(twCol(0.82, 0.82, 0.86).cgColor)
            g.fill(CGRect(x: 14, y: 16, width: s - 28, height: s * 0.62))
            g.setFillColor(twCol(0.93, 0.93, 0.95).cgColor)
            g.fill(CGRect(x: 18, y: 20, width: s - 36, height: s * 0.62 - 8))
            // baseboard
            g.setFillColor(twCol(0.36, 0.34, 0.34).cgColor)
            g.fill(CGRect(x: 0, y: s * 0.88, width: s, height: s * 0.12))
            // top rail
            g.setFillColor(twCol(0.55, 0.55, 0.6).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: s, height: 8))
            // accent stripe in the map colour
            let c = def.coreC
            g.setFillColor(twCol(c.0, c.1, c.2).cgColor)
            g.fill(CGRect(x: 0, y: s * 0.66, width: s, height: s * 0.055))
            grime(g, s, 303, 0.9)
        }
    }

    private var poolTex: UIImage {
        tex("pool") { g, s in
            let cs = CGColorSpaceCreateDeviceRGB()
            let cols = [twCol(1, 1, 1, 0.75).cgColor, twCol(1, 1, 1, 0).cgColor] as CFArray
            if let gr = CGGradient(colorsSpace: cs, colors: cols, locations: [0, 1]) {
                g.drawRadialGradient(gr, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0, endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2, options: [])
            }
        }
    }

    private var matCache: [String: SCNMaterial] = [:]

    private func poolMat(_ c: UIColor, _ k: CGFloat) -> SCNMaterial {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = "pool\(Int(r * 100))_\(Int(g * 100))_\(Int(b * 100))_\(Int(k * 10))"
        if let m = matCache[key] { return m }
        let m = SCNMaterial()
        m.diffuse.contents = poolTex
        m.multiply.contents = UIColor(red: r * k, green: g * k, blue: b * k, alpha: 1)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        matCache[key] = m
        return m
    }

    private func decalMat(_ k: Int) -> SCNMaterial {
        let key = "decalm\(k)"
        if let m = matCache[key] { return m }
        let m = SCNMaterial()
        m.diffuse.contents = decalTex(k)
        m.lightingModel = .lambert
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        m.transparencyMode = .aOne
        matCache[key] = m
        return m
    }

    private func texMat(_ img: UIImage, _ su: CGFloat, _ sv: CGFloat, _ tint: UIColor, shared: Bool = true, gloss: CGFloat = 0.25, bump: CGFloat = 0.5) -> SCNMaterial {
        var key = ""
        if shared {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            tint.getRed(&r, green: &g, blue: &b, alpha: &a)
            key = "t\(ObjectIdentifier(img).hashValue)_\(Int(su * 20))_\(Int(sv * 20))_\(Int(r * 100))_\(Int(g * 100))_\(Int(b * 100))_\(Int(gloss * 100))"
            if let m = matCache[key] { return m }
        }
        let m = SCNMaterial()
        m.diffuse.contents = img
        if bump > 0 {
            m.normal.contents = img
            m.normal.intensity = bump
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = SCNMatrix4MakeScale(Float(su), Float(sv), 1)
        }
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: gloss, alpha: 1)
        m.shininess = 0.35
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(su), Float(sv), 1)
        m.multiply.contents = tint
        if shared { matCache[key] = m }
        return m
    }

    private func plain(_ c: UIColor, glow: Bool = false, shared: Bool = true) -> SCNMaterial {
        var key = ""
        if shared {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            key = "p\(Int(r * 255))_\(Int(g * 255))_\(Int(b * 255))_\(Int(a * 100))_\(glow)"
            if let m = matCache[key] { return m }
        }
        let m = SCNMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant } else {
            m.lightingModel = .blinn
            m.specular.contents = UIColor(white: 0.18, alpha: 1)
            m.shininess = 0.3
        }
        if shared { matCache[key] = m }
        return m
    }

    private func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, glow: Bool = false, shared: Bool = true) -> SCNNode {
        let ch = glow ? 0 : min(1.0, min(w, h, l) * 0.28)
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: ch)
        g.chamferSegmentCount = 1
        g.materials = [plain(c, glow: glow, shared: shared)]
        return SCNNode(geometry: g)
    }

    private func ghost(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, _ a: CGFloat) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        let m = SCNMaterial()
        m.diffuse.contents = c
        m.emission.contents = c
        m.emission.intensity = 0.5
        m.transparency = a
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    private func doorColor(_ k: Int) -> UIColor {
        switch k {
        case 1: return twCol(0.5, 0.54, 0.6)
        case 2: return twCol(0.22, 0.26, 0.4)
        case 3: return twCol(0.2, 0.22, 0.25)
        default: return twCol(0.62, 0.38, 0.18)
        }
    }

    private var beltTex: UIImage {
        tex("belt") { g, s in
            g.setFillColor(twCol(0.14, 0.14, 0.16).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            g.setFillColor(twCol(1.0, 0.8, 0.1).cgColor)
            for k in 0..<2 {
                let x = CGFloat(k) * s / 2 + 8
                g.move(to: CGPoint(x: x, y: 22)); g.addLine(to: CGPoint(x: x + 30, y: s / 2)); g.addLine(to: CGPoint(x: x, y: s - 22))
                g.addLine(to: CGPoint(x: x + 14, y: s - 22)); g.addLine(to: CGPoint(x: x + 44, y: s / 2)); g.addLine(to: CGPoint(x: x + 14, y: 22))
                g.fillPath()
            }
        }
    }

    private func buildTrains() {
        for _ in 0..<2 {
            let n = SCNNode()
            n.addChildNode(at(box(560, 52, 74, twCol(0.55, 0.58, 0.64)), 0, 38, 0))
            n.addChildNode(at(box(560, 5, 70, twCol(0.8, 0.82, 0.86)), 0, 66, 0))
            for k in 0..<8 {
                let x = -245 + CGFloat(k) * 70
                n.addChildNode(at(box(40, 16, 75.5, twCol(0.45, 0.8, 1.0), glow: true), x, 46, 0))
            }
            n.addChildNode(at(box(560, 5, 76, twCol(0.9, 0.2, 0.2)), 0, 22, 0))
            n.addChildNode(at(box(6, 8, 10, twCol(1.0, 1.0, 0.8), glow: true), 281, 34, -20))
            n.addChildNode(at(box(6, 8, 10, twCol(1.0, 1.0, 0.8), glow: true), 281, 34, 20))
            n.addChildNode(at(box(6, 8, 10, twCol(1.0, 0.2, 0.2), glow: true), -281, 34, -20))
            n.addChildNode(at(box(6, 8, 10, twCol(1.0, 0.2, 0.2), glow: true), -281, 34, 20))
            n.isHidden = true
            scene.rootNode.addChildNode(n)
            trainNodes.append(n)
        }
    }

    private func cyl(_ r: CGFloat, _ h: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h)
        g.radialSegmentCount = 10
        g.materials = [plain(c)]
        return SCNNode(geometry: g)
    }

    private func ball(_ r: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNSphere(radius: r)
        g.segmentCount = 10
        g.materials = [plain(c)]
        return SCNNode(geometry: g)
    }

    private func at(_ n: SCNNode, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> SCNNode {
        n.position = SCNVector3(Float(x), Float(y), Float(z))
        return n
    }

    // MARK: init

    init(map: TowerMap) {
        self.map = map
        scene.background.contents = twCol(0.02, 0.025, 0.04)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = map.def.ambI * 0.58
        amb.light?.color = twCol(map.def.amb.0, map.def.amb.1, map.def.amb.2)
        scene.rootNode.addChildNode(amb)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 760
        sun.light?.color = twCol(0.92, 0.94, 1.0)
        sun.position = SCNVector3(300, 900, 1000)
        scene.rootNode.addChildNode(sun)
        let aim = SCNNode()
        aim.position = SCNVector3(800, 0, 480)
        scene.rootNode.addChildNode(aim)
        let lk = SCNLookAtConstraint(target: aim)
        sun.constraints = [lk]
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .forward
        sun.light?.shadowSampleCount = 6
        sun.light?.shadowRadius = 2.5
        sun.light?.shadowColor = UIColor(white: 0, alpha: 0.72)
        sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light?.orthographicScale = 950
        sun.light?.zNear = 200
        sun.light?.zFar = 2600
        sunNode = sun

        let cam = SCNCamera()
        cam.fieldOfView = 46
        cam.zNear = 10
        cam.zFar = 3000
        cam.wantsHDR = true
        cam.bloomIntensity = 0.8
        cam.bloomThreshold = 0.72
        cam.bloomBlurRadius = 6
        cam.vignettingIntensity = 0.75
        cam.vignettingPower = 1.2
        cam.screenSpaceAmbientOcclusionIntensity = 1.1
        cam.screenSpaceAmbientOcclusionRadius = 10
        cam.saturation = 1.15
        cam.contrast = 0.2
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)

        for f in 0..<map.nF { buildFloor(f) }
        buildTrains()
        buildActors()
        buildPools()

        view.scene = scene
        view.pointOfView = camNode
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
    }

    func configure(_ e: TowerEngine) {
        for (i, a) in e.actors.enumerated() where i < shirtMats.count {
            let c: UIColor
            if a.isMe { c = twCol(0.75, 0.85, 0.2) }
            else if a.team == 0 { c = twCol(0.15, 0.65, 0.8) }
            else { c = UIColor(hue: CGFloat(a.team) / CGFloat(map.def.teams), saturation: 0.6, brightness: 0.75, alpha: 1) }
            shirtMats[i].diffuse.contents = c
        }
    }

    // MARK: floors

    private func floorBox(_ w: CGFloat, _ l: CGFloat, _ y: CGFloat, _ kind: String, _ tint: UIColor, _ tile: CGFloat) -> SCNNode {
        let g = SCNBox(width: w, height: 1, length: l, chamferRadius: 0)
        let side = plain(twCol(0.15, 0.15, 0.17))
        let glossy: CGFloat = (kind == "marble" || kind == "tile") ? 0.55 : kind == "metal" ? 0.45 : 0.18
        g.materials = [side, side, side, side, texMat(floorTex(kind), w / tile, l / tile, tint, gloss: glossy, bump: kind == "carpet" ? 0.9 : 0.6), side]
        return SCNNode(geometry: g)
    }

    private func wallBox(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ tint: UIColor) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        let vf = h / 80
        let fb = texMat(wallTex, max(0.05, w / 120), vf, tint, gloss: 0.12, bump: 0.9)
        let lr = texMat(wallTex, max(0.05, l / 120), vf, tint, gloss: 0.12, bump: 0.9)
        let top = plain(twCol(0.045, 0.05, 0.065))
        let bot = plain(twCol(0.2, 0.2, 0.22))
        g.materials = [fb, lr, fb, lr, top, bot]
        return SCNNode(geometry: g)
    }

    private func buildFloor(_ f: Int) {
        let st = SCNNode()
        let W = TowerMap.W, H = TowerMap.H
        let t = def.tint[f % def.tint.count]
        let wt = def.wallTint
        let tintC = twCol(wt.0, wt.1, wt.2)
        st.addChildNode(at(floorBox(W, H, -0.5, def.hall[f % def.hall.count], twCol(0.62 * t.0, 0.64 * t.1, 0.68 * t.2), 96), W / 2, -0.5, H / 2))
        for r in map.rooms[f] {
            let c = def.roomC[r.mat % def.roomC.count]
            let n = floorBox(r.r.width, r.r.height, 0, def.room[r.mat % def.room.count], twCol(c.0, c.1, c.2), 90)
            st.addChildNode(at(n, r.r.midX, 0, r.r.midY))
        }
        // wall base shadow + walls
        let trimDark = twCol(0.16, 0.14, 0.13)
        let trimLight = twCol(0.07, 0.075, 0.09)
        for w in map.walls[f] {
            st.addChildNode(at(wallBox(w.width, TowerMap.wallH, w.height, tintC), w.midX, TowerMap.wallH / 2, w.midY))
            if min(w.width, w.height) < 40 {
                st.addChildNode(at(box(w.width + 1.6, 4, w.height + 1.6, trimDark), w.midX, 2, w.midY))
                st.addChildNode(at(box(w.width + 1.2, 2.5, w.height + 1.2, trimLight), w.midX, TowerMap.wallH - 1.5, w.midY))
            }
        }
        // windows on the exterior skin
        for k in 0..<(def.windows ? 10 : 0) {
            let x = 70 + CGFloat(k) * 150
            st.addChildNode(at(box(70, 26, 1.5, twCol(0.25, 0.45, 0.75), glow: true), x, 46, TowerMap.T + 0.9))
            st.addChildNode(at(box(70, 26, 1.5, twCol(0.25, 0.45, 0.75), glow: true), x, 46, H - TowerMap.T - 0.9))
        }
        // core accents
        let core = TowerMap.core
        st.addChildNode(at(box(core.width - 24, 3, core.height - 24, twCol(def.coreC.0 * 0.6, def.coreC.1 * 0.6, def.coreC.2 * 0.6), glow: true), core.midX, 81.5, core.midY))
        if def.id == 6 {
            st.addChildNode(at(box(170, 6, 10, twCol(0.9, 0.88, 0.8)), core.midX, 90, core.midY))
            for k in 0..<9 {
                let rb = box(3, 18, 70 - abs(CGFloat(k) - 4) * 6, twCol(0.9, 0.88, 0.8))
                st.addChildNode(at(rb, core.midX - 80 + CGFloat(k) * 20, 84, core.midY))
            }
            st.addChildNode(at(ball(14, twCol(0.9, 0.88, 0.8)), core.midX - 96, 92, core.midY))
        }
        // hazard decals
        for hz in map.hazards[f] {
            let g = ghost(hz.width, 0.4, hz.height, twCol(0.2, 1.0, 0.35), 0.22)
            st.addChildNode(at(g, hz.midX, 1.2, hz.midY))
            st.addChildNode(at(ghost(hz.width - 30, 0.4, hz.height - 30, twCol(0.5, 1.0, 0.2), 0.18), hz.midX, 1.6, hz.midY))
        }
        // train rails
        for ln in map.lanes[f] {
            st.addChildNode(at(box(ln.width, 1, ln.height, twCol(0.25, 0.25, 0.27)), ln.midX, 0.9, ln.midY))
            for dz in [ln.minY + 26, ln.maxY - 26] {
                st.addChildNode(at(box(ln.width, 2.5, 3, twCol(0.7, 0.72, 0.78)), ln.midX, 2.2, dz))
            }
            for sx in stride(from: ln.minX + 6, to: ln.maxX, by: 26) {
                st.addChildNode(at(box(5, 1.2, ln.height - 18, twCol(0.34, 0.24, 0.16)), CGFloat(sx), 1.5, ln.midY))
            }
            st.addChildNode(at(box(ln.width, 1.4, 4, twCol(1.0, 0.85, 0.1), glow: true), ln.midX, 1.8, ln.minY - 2))
            st.addChildNode(at(box(ln.width, 1.4, 4, twCol(1.0, 0.85, 0.1), glow: true), ln.midX, 1.8, ln.maxY + 2))
        }
        for p in map.props[f] { st.addChildNode(propNode(p, f)) }
        // floor grime decals: stains, scorch, papers, cracks
        var dr = TwLCG(s: UInt64(f * 977 + def.id * 131 + 5))
        for _ in 0..<34 {
            let p = CGPoint(x: 60 + dr.n() * (W - 120), y: 60 + dr.n() * (H - 120))
            if map.blockers[f].contains(where: { $0.insetBy(dx: -12, dy: -12).contains(p) }) { continue }
            let k = Int(dr.n() * 3.99)
            let sz = 26 + dr.n() * 70
            let pl = SCNPlane(width: sz, height: sz)
            pl.materials = [decalMat(k)]
            let inner = SCNNode(geometry: pl)
            inner.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            let outer = SCNNode()
            outer.addChildNode(inner)
            outer.eulerAngles = SCNVector3(0, Float(dr.n() * 6.28), 0)
            outer.position = SCNVector3(Float(p.x), 0.7, Float(p.y))
            st.addChildNode(outer)
        }
        // light pools
        let pst = SCNNode()
        var pools: [CGPoint] = []
        for x in stride(from: 160, to: 1500, by: 220) { pools.append(CGPoint(x: CGFloat(x), y: 500)); pools.append(CGPoint(x: CGFloat(x), y: 300)); pools.append(CGPoint(x: CGFloat(x), y: 700)) }
        for r in map.rooms[f] { pools.append(CGPoint(x: r.r.midX, y: r.r.midY)) }
        let cool = poolMat(twCol(0.35, 0.62, 1.0), 0.9)
        let warm = poolMat(twCol(1.0, 0.82, 0.55), 0.8)
        for (pi, p) in pools.enumerated() {
            let pl = SCNPlane(width: 230, height: 230)
            pl.materials = [(pi + Int(p.x / 100)) % 3 == 0 ? cool : warm]
            let n = SCNNode(geometry: pl)
            n.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            n.position = SCNVector3(Float(p.x), 0.8, Float(p.y))
            pst.addChildNode(n)
        }
        for r in map.rooms[f] where r.secure || r.hazard {
            let pl = SCNPlane(width: r.r.width + 90, height: r.r.height + 90)
            pl.materials = [poolMat(r.hazard ? twCol(0.3, 1.0, 0.4) : twCol(1.0, 0.25, 0.2), 0.9)]
            let n = SCNNode(geometry: pl)
            n.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            n.position = SCNVector3(Float(r.r.midX), 0.85, Float(r.r.midY))
            pst.addChildNode(n)
        }
        do {
            let cc = def.coreC
            let pl = SCNPlane(width: TowerMap.core.width + 300, height: TowerMap.core.height + 300)
            pl.materials = [poolMat(twCol(cc.0, cc.1, cc.2), 1.0)]
            let n = SCNNode(geometry: pl)
            n.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            n.position = SCNVector3(Float(TowerMap.core.midX), 0.9, Float(TowerMap.core.midY))
            pst.addChildNode(n)
        }
        // stairs
        for (k, r) in [TowerMap.stairW, TowerMap.stairE].enumerated() {
            for s in 0..<8 {
                let w = r.width / 8
                let h = 3 + CGFloat(s) * 3
                let v = 0.45 + CGFloat(s) * 0.04
                let x = k == 0 ? r.minX + w * (CGFloat(s) + 0.5) : r.maxX - w * (CGFloat(s) + 0.5)
                st.addChildNode(at(box(w, h, r.height, k == 0 ? twCol(v * 0.7, v, v * 0.7) : twCol(v, v * 0.75, v * 0.6)), x, h / 2, r.midY))
                st.addChildNode(at(box(w, 0.8, r.height - 4, twCol(0.9, 0.9, 0.9)), x, h + 0.4, r.midY))
            }
            st.addChildNode(at(box(r.width, 12, 3, twCol(0.65, 0.68, 0.72)), r.midX, 6, r.minY))
            st.addChildNode(at(box(r.width, 12, 3, twCol(0.65, 0.68, 0.72)), r.midX, 6, r.maxY))
        }
        // elevators
        for r in TowerMap.elevs {
            st.addChildNode(at(box(r.width, 2, r.height, twCol(0.55, 0.58, 0.62)), r.midX, 1, r.midY))
            st.addChildNode(at(box(r.width - 10, 0.8, r.height - 10, twCol(0.1, 0.55, 0.85), glow: true), r.midX, 2.2, r.midY))
            for dz in [r.minY - 2, r.maxY + 2] {
                st.addChildNode(at(box(r.width + 10, 40, 4, twCol(0.7, 0.74, 0.8)), r.midX, 20, dz))
            }
            st.addChildNode(at(box(4, 40, r.height, twCol(0.7, 0.74, 0.8)), r.minX - 2, 20, r.midY))
            st.addChildNode(at(box(r.width + 10, 3, 4, twCol(0.2, 0.9, 1.0), glow: true), r.midX, 41, r.minY - 2))
        }
        // door frames
        for d in map.doors[f] {
            let fc = twCol(0.28, 0.24, 0.2)
            if d.horiz {
                st.addChildNode(at(box(5, 72, TowerMap.T + 2, fc), d.r.minX, 36, d.r.midY))
                st.addChildNode(at(box(5, 72, TowerMap.T + 2, fc), d.r.maxX, 36, d.r.midY))
                st.addChildNode(at(box(d.r.width + 5, 10, TowerMap.T + 2, fc), d.r.midX, 75, d.r.midY))
            } else {
                st.addChildNode(at(box(TowerMap.T + 2, 72, 5, fc), d.r.midX, 36, d.r.minY))
                st.addChildNode(at(box(TowerMap.T + 2, 72, 5, fc), d.r.midX, 36, d.r.maxY))
                st.addChildNode(at(box(TowerMap.T + 2, 10, d.r.height + 5, fc), d.r.midX, 75, d.r.midY))
            }
        }
        let root = SCNNode()
        root.addChildNode(st.flattenedClone())
        let pflat = pst.flattenedClone()
        root.addChildNode(pflat)
        poolRoots.append(pflat)
        var dn: [SCNNode] = []
        var dk: [Int] = []
        for (di, d) in map.doors[f].enumerated() {
            let len = d.horiz ? d.r.width : d.r.height
            let thick: CGFloat = 4.5
            let panel = SCNNode()
            let body = box(d.horiz ? len : thick, 68, d.horiz ? thick : len, doorColor(d.kind), shared: false)
            panel.addChildNode(body)
            let sh = SCNNode()
            // inset panels on both faces
            let insetC = twCol(0.0, 0.0, 0.0, 0.18)
            for side in [-1.0, 1.0] as [CGFloat] {
                for k in 0..<2 {
                    let iy: CGFloat = k == 0 ? 17 : -17
                    let ih: CGFloat = 26
                    let n2 = d.horiz ? box(len - 10, ih, 0.6, insetC) : box(0.6, ih, len - 10, insetC)
                    n2.position = d.horiz ? SCNVector3(0, Float(iy), Float(side * (thick / 2 + 0.2))) : SCNVector3(Float(side * (thick / 2 + 0.2)), Float(iy), 0)
                    sh.addChildNode(n2)
                }
                let hx: CGFloat = len * 0.42
                let knob = ball(1.6, twCol(0.85, 0.7, 0.3))
                knob.position = d.horiz ? SCNVector3(Float(hx), -2, Float(side * (thick / 2 + 1.8))) : SCNVector3(Float(side * (thick / 2 + 1.8)), -2, Float(hx))
                sh.addChildNode(knob)
            }
            if d.kind == 2 || d.kind == 3 {
                let lamp = box(d.horiz ? 6 : 1.2, 3, d.horiz ? 1.2 : 6, d.kind == 2 ? twCol(0.2, 0.6, 1.0) : twCol(1.0, 0.3, 0.2), glow: true)
                lamp.position = d.horiz ? SCNVector3(Float(len * 0.3), 18, Float(thick / 2 + 0.7)) : SCNVector3(Float(thick / 2 + 0.7), 18, Float(len * 0.3))
                sh.addChildNode(lamp)
            }
            panel.addChildNode(sh)
            panel.position = d.horiz ? SCNVector3(Float(len / 2), 34, 0) : SCNVector3(0, 34, Float(len / 2))
            let n = SCNNode()
            n.addChildNode(panel)
            n.position = d.horiz ? SCNVector3(Float(d.r.minX), 0, Float(d.r.midY)) : SCNVector3(Float(d.r.midX), 0, Float(d.r.minY))
            root.addChildNode(n)
            dn.append(n)
            dk.append(d.kind)
            _ = di
        }
        doorAngShown.append([Float](repeating: -9, count: map.doors[f].count))
        doorKindShown.append(dk)
        // glass walls
        var gn: [SCNNode] = []
        for g in map.glass[f] {
            let n = ghost(g.width, 58, g.height, twCol(0.55, 0.85, 1.0), 0.3)
            n.position = SCNVector3(Float(g.midX), 29, Float(g.midY))
            n.addChildNode(at(box(g.width, 2, g.height, twCol(0.15, 0.17, 0.2)), 0, 29, 0))
            n.addChildNode(at(box(g.width, 2, g.height, twCol(0.15, 0.17, 0.2)), 0, -29, 0))
            root.addChildNode(n)
            gn.append(n)
        }
        glassNodes.append(gn)
        // conveyor belts
        var bn: [SCNNode] = []
        var bv: [CGFloat] = []
        var bl: [CGFloat] = []
        for (r, v) in map.belts[f] {
            let horizontal = abs(v.x) > abs(v.y)
            let len = horizontal ? r.width : r.height
            let wid = horizontal ? r.height : r.width
            let g = SCNBox(width: len, height: 2.5, length: wid, chamferRadius: 0)
            let top = texMat(beltTex, len / 64, 1, twCol(1, 1, 1), shared: false, gloss: 0.1, bump: 0)
            let side = plain(twCol(0.12, 0.12, 0.14))
            g.materials = [side, side, side, side, top, side]
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(Float(r.midX), 1.5, Float(r.midY))
            n.eulerAngles = SCNVector3(0, Float(-atan2(v.y, v.x)), 0)
            root.addChildNode(n)
            bn.append(n)
            bv.append(hypot(v.x, v.y))
            bl.append(len)
        }
        beltNodes.append(bn)
        beltVel.append(bv)
        beltLen.append(bl)
        // power panel
        let sw = box(16, 3, 10, twCol(1.0, 0.2, 0.2), glow: true)
        if def.mech == 6 {
            root.addChildNode(at(box(14, 34, 24, twCol(0.2, 0.22, 0.26)), TowerMap.switchPos.x, 17, TowerMap.switchPos.y))
            root.addChildNode(at(sw, TowerMap.switchPos.x + 3, 30, TowerMap.switchPos.y))
            root.addChildNode(at(box(2, 10, 18, twCol(0.1, 0.12, 0.15)), TowerMap.switchPos.x + 8, 24, TowerMap.switchPos.y))
        }
        switchNodes.append(sw)
        root.isHidden = true
        scene.rootNode.addChildNode(root)
        floorRoots.append(root)
        doorNodes.append(dn)
    }

    // MARK: prop toolkit

    private func mat(_ c: UIColor, spec: CGFloat = 0.2, shin: CGFloat = 0.3, fabric: Bool = false) -> SCNMaterial {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = "m\(Int(r * 255))_\(Int(g * 255))_\(Int(b * 255))_\(Int(spec * 100))_\(Int(shin * 100))_\(fabric)"
        if let m = matCache[key] { return m }
        let m = SCNMaterial()
        m.diffuse.contents = c
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: spec, alpha: 1)
        m.shininess = shin
        if fabric {
            m.normal.contents = floorTex("carpet")
            m.normal.intensity = 1.0
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
        }
        matCache[key] = m
        return m
    }

    private func rb(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, _ rad: CGFloat = 2.2, spec: CGFloat = 0.2, shin: CGFloat = 0.3, fabric: Bool = false) -> SCNNode {
        let ww = max(0.2, w), hh = max(0.2, h), ll = max(0.2, l)
        let g = SCNBox(width: ww, height: hh, length: ll, chamferRadius: min(rad, min(ww, hh, ll) * 0.45))
        g.chamferSegmentCount = 3
        g.materials = [mat(c, spec: spec, shin: shin, fabric: fabric)]
        return SCNNode(geometry: g)
    }

    private func wd(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ tint: UIColor = twCol(0.85, 0.7, 0.55)) -> SCNNode {
        let ww = max(0.2, w), hh = max(0.2, h), ll = max(0.2, l)
        let g = SCNBox(width: ww, height: hh, length: ll, chamferRadius: min(0.8, min(ww, hh, ll) * 0.4))
        g.chamferSegmentCount = 2
        g.materials = [texMat(floorTex("wood"), max(0.3, max(ww, ll) / 52), max(0.3, hh / 52), tint, gloss: 0.3, bump: 0.7)]
        return SCNNode(geometry: g)
    }

    private func cy(_ r: CGFloat, _ h: CGFloat, _ c: UIColor, spec: CGFloat = 0.3, shin: CGFloat = 0.5) -> SCNNode {
        let g = SCNCylinder(radius: max(0.1, r), height: max(0.1, h))
        g.radialSegmentCount = 28
        g.materials = [mat(c, spec: spec, shin: shin)]
        return SCNNode(geometry: g)
    }

    private func cn(_ top: CGFloat, _ bot: CGFloat, _ h: CGFloat, _ c: UIColor, spec: CGFloat = 0.25) -> SCNNode {
        let g = SCNCone(topRadius: top, bottomRadius: bot, height: h)
        g.radialSegmentCount = 24
        g.materials = [mat(c, spec: spec, shin: 0.4)]
        return SCNNode(geometry: g)
    }

    private func tr(_ ring: CGFloat, _ pipe: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNTorus(ringRadius: ring, pipeRadius: pipe)
        g.ringSegmentCount = 36
        g.pipeSegmentCount = 8
        g.materials = [mat(c, spec: 0.5, shin: 0.8)]
        return SCNNode(geometry: g)
    }

    private func tb(_ inner: CGFloat, _ outer: CGFloat, _ h: CGFloat, _ c: UIColor) -> SCNNode {
        let g = SCNTube(innerRadius: inner, outerRadius: outer, height: h)
        g.radialSegmentCount = 20
        g.materials = [mat(c, spec: 0.4, shin: 0.6)]
        return SCNNode(geometry: g)
    }

    private func sp(_ r: CGFloat, _ c: UIColor, spec: CGFloat = 0.3) -> SCNNode {
        let g = SCNSphere(radius: r)
        g.segmentCount = 18
        g.materials = [mat(c, spec: spec, shin: 0.5)]
        return SCNNode(geometry: g)
    }

    private func put(_ g: SCNNode, _ n: SCNNode, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, rx: CGFloat = 0, ry: CGFloat = 0, rz: CGFloat = 0) {
        n.position = SCNVector3(Float(x), Float(y), Float(z))
        n.eulerAngles = SCNVector3(Float(rx), Float(ry), Float(rz))
        g.addChildNode(n)
    }

    private func propNode(_ p: TwProp, _ f: Int) -> SCNNode {
        let r = p.r
        let long = r.width >= r.height
        let L = max(r.width, r.height), D = min(r.width, r.height)
        let hv = abs(Int(r.minX * 7 + r.minY * 13)) % 97
        var rg = TwLCG(s: UInt64(hv * 7919 + p.kind * 131 + 11))
        let g = SCNNode()
        let steel = twCol(0.55, 0.58, 0.62)
        let dark = twCol(0.1, 0.1, 0.12)
        let brass = twCol(0.85, 0.68, 0.3)
        let white = twCol(0.93, 0.93, 0.95)
        let palette: [UIColor] = [twCol(0.7, 0.2, 0.2), twCol(0.2, 0.4, 0.7), twCol(0.82, 0.7, 0.22), twCol(0.25, 0.6, 0.38), twCol(0.9, 0.9, 0.84), twCol(0.45, 0.25, 0.55), twCol(0.85, 0.5, 0.2)]
        switch p.kind {
        case 0: // shipping crate
            let H: CGFloat = 27 + CGFloat(hv % 3) * 3
            let planks = twCol(0.82, 0.66, 0.5)
            let beam = twCol(0.55, 0.42, 0.3)
            put(g, wd(L, H, D, planks), 0, H / 2, 0)
            for sx in [-1.0, 1.0] as [CGFloat] {
                for sz in [-1.0, 1.0] as [CGFloat] {
                    put(g, wd(3.4, H + 0.6, 3.4, beam), sx * (L / 2 - 1.2), H / 2, sz * (D / 2 - 1.2))
                }
            }
            for y in [2.6, H - 2.6] as [CGFloat] { put(g, wd(L + 0.9, 2.8, D + 0.9, beam), 0, y, 0) }
            let bl = hypot(L - 8, H - 8), ba = atan2(H - 8, L - 8)
            put(g, wd(bl, 2.4, 0.9, beam), 0, H / 2, D / 2 + 0.5, rz: ba)
            put(g, wd(bl, 2.4, 0.9, beam), 0, H / 2, -D / 2 - 0.5, rz: -ba)
            put(g, box(L * 0.3, 4.5, 0.3, twCol(0.08, 0.08, 0.08)), -L * 0.18, H * 0.62, D / 2 + 0.8)
            put(g, wd(L - 0.8, 1.6, D - 0.8, planks), 0, H + 0.6, 0)
            if hv % 3 == 0 && L > 30 { put(g, wd(L * 0.5, 17, D * 0.7, planks), 2, H + 9.4, 0, ry: 0.25) }
        case 1: // desk + monitor + chair
            let wood = twCol(0.78, 0.58, 0.42)
            let woodD = twCol(0.6, 0.45, 0.33)
            put(g, wd(L, 2.6, D, wood), 0, 25, 0)
            put(g, rb(20, 22, D - 4, woodD, 1.5), -L / 2 + 12, 12, 0)
            for k in 0..<3 {
                put(g, wd(18.4, 6.2, 0.9, wood), -L / 2 + 12, 5 + CGFloat(k) * 7.2, (D - 4) / 2 + 0.4)
                put(g, rb(4, 0.9, 0.9, brass, 0.3, spec: 0.7, shin: 1.0), -L / 2 + 12, 5 + CGFloat(k) * 7.2, (D - 4) / 2 + 1.2)
            }
            put(g, rb(2, 22, D - 4, woodD, 1), L / 2 - 2, 12, 0)
            put(g, rb(L - 26, 13, 1.4, woodD, 0.6), 0, 17, -D / 2 + 3)
            put(g, cy(4.5, 0.8, twCol(0.15, 0.15, 0.17)), 2, 26.7, -D * 0.12)
            put(g, rb(1.6, 8, 1.6, twCol(0.15, 0.15, 0.17), 0.6), 2, 31, -D * 0.12)
            put(g, rb(17, 10.5, 1.6, twCol(0.06, 0.06, 0.08), 0.8, spec: 0.5), 2, 37.5, -D * 0.12)
            put(g, box(15.6, 9, 0.3, twCol(0.2, 0.75, 1.0), glow: true), 2, 37.5, -D * 0.12 + 0.9)
            put(g, rb(14, 0.9, 5, twCol(0.14, 0.14, 0.16), 0.5), 2, 26.9, D * 0.2)
            for k in 0..<3 { put(g, rb(12.5, 0.3, 1.1, twCol(0.38, 0.38, 0.42), 0.2), 2, 27.5, D * 0.2 - 1.6 + CGFloat(k) * 1.6) }
            put(g, rb(2.4, 1.3, 3.6, twCol(0.1, 0.1, 0.12), 0.6), 12, 27, D * 0.2)
            put(g, cy(3, 0.8, twCol(0.1, 0.1, 0.12)), -L / 2 + 6, 26.7, -D / 2 + 6)
            put(g, cy(0.35, 11, steel), -L / 2 + 6, 32, -D / 2 + 6)
            put(g, cn(0.8, 3.6, 3.6, twCol(1, 0.85, 0.5), spec: 0.1), -L / 2 + 8.5, 38, -D / 2 + 6, rz: 0.5)
            put(g, tb(1.1, 1.7, 3.2, white), L / 2 - 8, 28, -D * 0.1)
            put(g, rb(8, 0.3, 11, white, 0.1), -4, 26.5, D * 0.12, ry: 0.35)
            let ch = SCNNode()
            put(ch, rb(12, 2.8, 12, twCol(0.17, 0.18, 0.22), 2.6, fabric: true), 0, 14, 0)
            put(ch, rb(11, 13, 2.4, twCol(0.17, 0.18, 0.22), 2.6, fabric: true), 0, 21, 6, rx: -0.12)
            put(ch, cy(1, 9, steel, spec: 0.6, shin: 1), 0, 9, 0)
            for i in 0..<5 {
                let a = CGFloat(i) * 2 * .pi / 5
                put(ch, rb(1.3, 1, 7, dark, 0.4), sin(a) * 3.5, 4, cos(a) * 3.5, ry: a)
                put(ch, sp(1.2, dark), sin(a) * 6.8, 1.4, cos(a) * 6.8)
            }
            for s in [-1.0, 1.0] as [CGFloat] { put(ch, rb(1.3, 1.3, 7.5, twCol(0.12, 0.12, 0.14), 0.5), s * 6.6, 18.5, 0) }
            ch.position = SCNVector3(Float(CGFloat(hv % 5) - 2), 0, Float(D / 2 + 9))
            ch.eulerAngles = SCNVector3(0, Float(CGFloat(hv % 7 - 3) * 0.2), 0)
            g.addChildNode(ch)
        case 2: // couch + rug
            let cols: [UIColor] = [twCol(0.46, 0.16, 0.22), twCol(0.2, 0.3, 0.45), twCol(0.28, 0.33, 0.27), twCol(0.45, 0.34, 0.24)]
            let c1 = cols[hv % 4]
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            c1.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            let c2 = twCol(min(1, cr * 1.25 + 0.05), min(1, cg * 1.25 + 0.05), min(1, cb * 1.25 + 0.05))
            put(g, rb(L + 26, 0.7, D + 26, twCol(0.3, 0.26, 0.24), 0.3, fabric: true), 0, 0.7, 6)
            put(g, rb(L + 16, 0.9, D + 16, twCol(0.55, 0.42, 0.3), 0.3, fabric: true), 0, 0.9, 6)
            put(g, rb(L, 8, D, c1, 3.5, fabric: true), 0, 7, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cy(1.2, 3, brass, spec: 0.6, shin: 1), sx * (L / 2 - 4), 1.5, sz * (D / 2 - 4)) } }
            put(g, rb(L, 17, 8, c1, 4.5, fabric: true), 0, 15.5, -D / 2 + 4)
            for sx in [-1.0, 1.0] as [CGFloat] { put(g, rb(7, 13, D, c1, 3.5, fabric: true), sx * (L / 2 - 3.5), 14.5, 0) }
            let n = L > 90 ? 3 : 2
            let cw = (L - 14) / CGFloat(n)
            for k in 0..<n {
                let x = -L / 2 + 7 + cw * (CGFloat(k) + 0.5)
                put(g, rb(cw - 1, 5.5, D - 9, c2, 3, fabric: true), x, 13.7, 2)
                put(g, rb(cw - 1, 11, 5, c2, 3.4, fabric: true), x, 19.5, -D / 2 + 10, rx: -0.14)
            }
            put(g, rb(8, 8, 3, palette[(hv + 2) % palette.count], 2.5, fabric: true), -L / 2 + 13, 19, 0, ry: 0.4, rz: 0.5)
        case 3: // plant
            let rr = min(L, D) / 2
            let terr = twCol(0.72, 0.4, 0.26)
            put(g, cn(rr, rr * 0.68, 13, terr), 0, 6.5, 0)
            put(g, tr(rr * 0.98, 0.9, twCol(0.62, 0.32, 0.2)), 0, 13, 0)
            put(g, cy(rr * 0.92, 0.8, twCol(0.16, 0.1, 0.07), spec: 0.05), 0, 12.6, 0)
            for i in 0..<3 {
                let a = CGFloat(i) * 2.1
                put(g, cy(0.55, 17, twCol(0.3, 0.22, 0.12)), sin(a) * 1.6, 21, cos(a) * 1.6, rx: cos(a) * 0.18, rz: -sin(a) * 0.18)
            }
            for i in 0..<16 {
                let a = CGFloat(i) * 0.62
                let ringR = 3 + CGFloat(i % 4) * 2.2
                let lf = sp(1, twCol(0.1 + rg.n() * 0.08, 0.42 + rg.n() * 0.25, 0.14 + rg.n() * 0.08), spec: 0.4)
                lf.scale = SCNVector3(5.5, 0.8, 2.4)
                put(g, lf, sin(a) * ringR, 17 + CGFloat(i % 5) * 3.6, cos(a) * ringR, ry: a, rz: 0.45)
            }
        case 4: // bookcase (open side faces +z)
            let wood = twCol(0.62, 0.45, 0.32)
            let H: CGFloat = 56
            for s in [-1.0, 1.0] as [CGFloat] { put(g, wd(2, H, D, wood), s * (L / 2 - 1), H / 2, 0) }
            put(g, wd(L, 2.4, D + 1, wood), 0, H + 0.6, 0)
            put(g, wd(L, 3.5, D, wood), 0, 1.8, 0)
            put(g, wd(L - 2, H, 1.4, twCol(0.5, 0.36, 0.26)), 0, H / 2, -D / 2 + 0.7)
            for k in 0..<3 { put(g, wd(L - 3, 1.5, D - 1.5, wood), 0, 14 + CGFloat(k) * 13, 0) }
            for row in 0..<4 {
                let top: CGFloat = row == 0 ? 3.5 : 14.75 + CGFloat(row - 1) * 13
                var x = -L / 2 + 3.2
                while x < L / 2 - 4 {
                    let w = 2.0 + rg.n() * 2.4
                    let h = 6.5 + rg.n() * 5
                    if rg.n() < 0.07 { x += 5; continue }
                    let lean = rg.n() < 0.05
                    let c = palette[Int(rg.n() * 6.99)]
                    put(g, rb(w, h, D * 0.62, c, 0.5, spec: 0.1), x + w / 2, top + h / 2, 0.8, rz: lean ? -0.3 : 0)
                    x += w + 0.25
                }
            }
        case 5: // table + props
            let wood = twCol(0.82, 0.62, 0.45)
            put(g, wd(L, 2.4, D, wood), 0, 22, 0)
            put(g, wd(L - 6, 3, D - 6, twCol(0.55, 0.4, 0.3)), 0, 19.8, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cn(1.4, 0.8, 19, twCol(0.5, 0.36, 0.26)), sx * (L / 2 - 3.5), 9.5, sz * (D / 2 - 3.5)) } }
            if hv % 2 == 0 {
                put(g, rb(11, 0.8, 8, twCol(0.75, 0.77, 0.8), 0.5, spec: 0.7, shin: 1), -L * 0.15, 23.6, D * 0.1)
                put(g, rb(11, 7, 0.6, twCol(0.75, 0.77, 0.8), 0.4, spec: 0.7, shin: 1), -L * 0.15, 27, D * 0.1 - 4, rx: -0.2)
                put(g, box(9.8, 5.8, 0.2, twCol(0.3, 0.7, 1.0), glow: true), -L * 0.15, 27, D * 0.1 - 3.6, rx: -0.2)
            } else {
                put(g, rb(8, 0.3, 11, white, 0.1), -L * 0.15, 23.4, 0, ry: 0.3)
                put(g, rb(6, 0.3, 8, twCol(0.9, 0.85, 0.6), 0.1), -L * 0.15 + 3, 23.7, 1, ry: -0.2)
            }
            put(g, tb(1.1, 1.7, 3.2, palette[hv % palette.count]), L * 0.25, 24.2, D * 0.1)
            put(g, cy(2, 5, twCol(0.25, 0.4, 0.6), spec: 0.6, shin: 1), L * 0.3, 25.5, -D * 0.15)
            for i in 0..<4 {
                let lf = sp(1, twCol(0.15, 0.5, 0.2))
                lf.scale = SCNVector3(3.2, 0.6, 1.4)
                put(g, lf, L * 0.3 + sin(CGFloat(i) * 1.6) * 1.5, 29 + CGFloat(i % 2), -D * 0.15 + cos(CGFloat(i) * 1.6) * 1.5, ry: CGFloat(i) * 1.6, rz: 0.5)
            }
        case 6: // server rack
            let H: CGFloat = 60
            let frame = twCol(0.07, 0.075, 0.09)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, rb(2.4, H, 2.4, frame, 0.6, spec: 0.5, shin: 0.8), sx * (L / 2 - 1.2), H / 2, sz * (D / 2 - 1.2)) } }
            put(g, rb(L, 2.4, D, frame, 0.8, spec: 0.5), 0, H + 0.4, 0)
            put(g, rb(L, 4, D, frame, 0.8, spec: 0.5), 0, 2, 0)
            for s in [-1.0, 1.0] as [CGFloat] { put(g, rb(0.8, H - 4, D - 2, twCol(0.13, 0.14, 0.17), 0.3), s * (L / 2 - 0.4), H / 2, 0) }
            for k in 0..<9 {
                let y = 6.5 + CGFloat(k) * 5.9
                put(g, rb(L - 3.6, 5.2, D - 5, k % 4 == 3 ? twCol(0.22, 0.24, 0.3) : twCol(0.16, 0.17, 0.21), 0.5, spec: 0.5, shin: 0.8), 0, y, 0)
                for sz in [-1.0, 1.0] as [CGFloat] {
                    let z = sz * (D / 2 - 2.4)
                    put(g, box(1.1, 0.7, 0.3, k % 3 == 0 ? twCol(1.0, 0.3, 0.2) : twCol(0.2, 1.0, 0.45), glow: true), -L / 2 + 5.5, y + 1, z)
                    put(g, box(1.1, 0.7, 0.3, twCol(0.3, 0.7, 1.0), glow: true), -L / 2 + 8, y + 1, z)
                    for b in 0..<4 { put(g, rb(3.4, 3.6, 0.3, twCol(0.06, 0.06, 0.08), 0.2), -L / 2 + 14 + CGFloat(b) * 4.2, y, z) }
                }
            }
            for i in 0..<3 { put(g, cy(0.55, 40, [twCol(0.9, 0.3, 0.2), twCol(0.2, 0.5, 0.9), twCol(0.9, 0.8, 0.2)][i]), -L / 2 + 2 + CGFloat(i) * 1.1, 32, -D / 2 + 3.2) }
            put(g, cy(3.6, 0.5, twCol(0.04, 0.04, 0.05)), L * 0.2, H + 1.8, 0)
            put(g, tr(3.6, 0.35, steel), L * 0.2, H + 1.8, 0)
        case 7: // steel drum
            let rr = min(L, D) / 2
            let cols: [UIColor] = [twCol(0.68, 0.14, 0.1), twCol(0.15, 0.3, 0.6), twCol(0.18, 0.45, 0.25), twCol(0.45, 0.46, 0.5)]
            put(g, cy(rr, 30, cols[hv % 4], spec: 0.5, shin: 0.9), 0, 15, 0)
            for y in [4.0, 15.0, 26.0] as [CGFloat] { put(g, tr(rr + 0.05, 0.9, twCol(0.3, 0.31, 0.34)), 0, y, 0) }
            put(g, cy(rr - 0.4, 0.8, twCol(0.5, 0.52, 0.56), spec: 0.7, shin: 1), 0, 30.2, 0)
            put(g, tr(rr - 0.4, 0.6, twCol(0.4, 0.42, 0.46)), 0, 30.5, 0)
            put(g, cy(1.4, 1.2, twCol(0.2, 0.2, 0.22)), rr * 0.45, 31, 0)
            put(g, cy(1.1, 1.0, twCol(0.2, 0.2, 0.22)), -rr * 0.3, 31, rr * 0.3)
            put(g, rb(rr * 1.0, 8, 0.5, twCol(0.95, 0.8, 0.15), 0.2), 0, 17, rr + 0.1)
            put(g, rb(3, 3, 0.4, twCol(0.08, 0.08, 0.08), 0.1), 0, 17, rr + 0.5, rz: .pi / 4)
        case 8: // kiosk
            put(g, rb(L, 4, D, twCol(0.14, 0.15, 0.18), 1.5, spec: 0.5), 0, 2, 0)
            put(g, rb(L - 4, 30, D - 4, twCol(0.2, 0.23, 0.3), 5, spec: 0.5, shin: 0.8), 0, 19, 0)
            put(g, rb(L, 6, D, twCol(0.95, 0.72, 0.22), 2, spec: 0.1), 0, 37.5, 0)
            put(g, box(L - 3, 3, D - 3, twCol(1.0, 0.82, 0.35), glow: true), 0, 40.6, 0)
            put(g, rb(L * 0.72, 13, 1.4, twCol(0.05, 0.05, 0.07), 1, spec: 0.6, shin: 1), 0, 25, D / 2 - 0.5, rx: -0.38)
            put(g, box(L * 0.64, 10.5, 0.3, twCol(0.2, 0.75, 1.0), glow: true), 0, 25.2, D / 2 + 0.2, rx: -0.38)
            for k in 0..<3 { put(g, rb(5, 6.5, 1.2, palette[(hv + k) % palette.count], 0.5), -L * 0.26 + CGFloat(k) * 5.8, 10, D / 2 + 0.6, rx: -0.15) }
        case 10: // bed (head at -x)
            let wood = twCol(0.6, 0.44, 0.32)
            let sheet = twCol(0.93, 0.93, 0.95)
            put(g, rb(L, 7, D, wood, 2), 0, 5.5, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cy(1.4, 3, twCol(0.3, 0.2, 0.14)), sx * (L / 2 - 3), 1.5, sz * (D / 2 - 3)) } }
            put(g, rb(L - 4, 9, D - 4, sheet, 4.2, fabric: true), 0, 12.5, 0)
            put(g, rb((L - 4) * 0.62, 3.6, D - 3, palette[hv % palette.count], 3.4, fabric: true), L * 0.17, 17.4, 0)
            put(g, rb(7, 4.8, D - 2, palette[hv % palette.count], 3, fabric: true), -L * 0.12, 17.6, 0)
            for s in [-1.0, 1.0] as [CGFloat] { put(g, rb(12, 5, D * 0.42, white, 3.4, fabric: true), -L / 2 + 11, 17.8, s * D * 0.23, ry: s * 0.06) }
            put(g, wd(3.2, 26, D + 1, wood), -L / 2 + 1.6, 13, 0)
            put(g, wd(2.6, 13, D, wood), L / 2 - 1.3, 6.5, 0)
        case 11: // hospital bed + IV stand
            put(g, rb(L - 8, 3, D - 8, steel, 1.2, spec: 0.7, shin: 1), 0, 10.5, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] {
                put(g, cy(0.9, 7, steel, spec: 0.7, shin: 1), sx * (L / 2 - 8), 6.5, sz * (D / 2 - 6))
                put(g, sp(2.1, dark), sx * (L / 2 - 8), 2.1, sz * (D / 2 - 6))
            } }
            put(g, rb(L * 0.68, 4.6, D - 6, twCol(0.84, 0.9, 0.95), 2.6, fabric: true), L * 0.1, 14.5, 0)
            put(g, rb(L * 0.3, 4.6, D - 6, twCol(0.84, 0.9, 0.95), 2.6, fabric: true), -L / 2 + L * 0.26, 17.2, 0, rz: 0.3)
            put(g, rb(L * 0.46, 2.6, D - 5, twCol(0.3, 0.58, 0.82), 2.2, fabric: true), L * 0.14, 17.6, 0)
            put(g, rb(10, 3.6, D * 0.52, white, 3, fabric: true), -L / 2 + 9, 21, 0, rz: 0.3)
            for s in [-1.0, 1.0] as [CGFloat] {
                put(g, rb(L * 0.55, 0.9, 0.9, steel, 0.4, spec: 0.7, shin: 1), L * 0.08, 22, s * (D / 2 - 2))
                for k in 0..<3 { put(g, rb(0.9, 6, 0.9, steel, 0.3, spec: 0.7, shin: 1), L * 0.08 - L * 0.2 + CGFloat(k) * L * 0.2, 19, s * (D / 2 - 2)) }
            }
            put(g, rb(2, 12, D - 6, white, 1.2), -L / 2 + 3, 16, 0)
            put(g, rb(2, 9, D - 6, white, 1.2), L / 2 - 3, 14.5, 0)
            let px = L / 2 + 5, pz = -D / 2 - 4
            put(g, cy(0.6, 48, steel, spec: 0.7, shin: 1), px, 24, pz)
            put(g, cy(4, 0.8, steel, spec: 0.6), px, 0.6, pz)
            put(g, rb(7, 0.8, 0.8, steel, 0.3), px, 47.5, pz)
            put(g, ghost(2.6, 6, 1.2, twCol(0.8, 0.95, 1.0), 0.45), px - 2.6, 43, pz)
            put(g, cy(0.25, 22, twCol(0.9, 0.95, 1)), px - 2.6, 29, pz)
            put(g, rb(6, 5, 2.4, dark, 1, spec: 0.5), px, 34, pz + 2)
            put(g, box(5, 3.6, 0.2, twCol(0.2, 1.0, 0.4), glow: true), px, 34, pz + 3.3)
        case 12: // display case
            put(g, rb(L, 12, D, twCol(0.06, 0.06, 0.07), 1.5, spec: 0.7, shin: 1), 0, 6, 0)
            put(g, ghost(L - 3, 22, D - 3, twCol(0.7, 0.9, 1.0), 0.2), 0, 23, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, rb(1, 22, 1, brass, 0.3, spec: 0.7, shin: 1), sx * (L / 2 - 1.6), 23, sz * (D / 2 - 1.6)) } }
            put(g, rb(L - 2, 1.8, D - 2, twCol(0.08, 0.08, 0.1), 0.8, spec: 0.6), 0, 34.8, 0)
            put(g, box(L - 5, 0.5, D - 5, twCol(0.9, 0.95, 1.0), glow: true), 0, 33.8, 0)
            put(g, cy(3.6, 1.2, brass, spec: 0.7, shin: 1), 0, 12.6, 0)
            let vase = sp(4.8, brass, spec: 0.8)
            vase.scale = SCNVector3(1, 1.3, 1)
            put(g, vase, 0, 19.3, 0)
            put(g, cy(1.9, 4.5, brass, spec: 0.8, shin: 1), 0, 26, 0)
            put(g, tr(2.1, 0.45, brass), 0, 28.2, 0)
        case 13: // industrial machine
            put(g, rb(L, 6, D, twCol(0.2, 0.21, 0.24), 1.5, spec: 0.5), 0, 3, 0)
            put(g, rb(L + 0.6, 1.8, D + 0.6, twCol(0.95, 0.78, 0.1), 0.6), 0, 1.5, 0)
            put(g, rb(L - 2, 30, D - 2, twCol(0.9, 0.46, 0.12), 3, spec: 0.5, shin: 0.8), 0, 21, 0)
            put(g, rb(L * 0.5, 9, 3, twCol(0.16, 0.17, 0.2), 1.4, spec: 0.5), L * 0.15, 28, D / 2 + 0.2, rx: -0.3)
            for (i, c) in [twCol(1, 0.2, 0.2), twCol(0.2, 0.95, 0.35), twCol(1, 0.8, 0.2), twCol(0.3, 0.6, 1)].enumerated() {
                put(g, sp(1.2, c, spec: 0.7), L * 0.15 - 6 + CGFloat(i) * 4, 29, D / 2 + 1.6)
            }
            put(g, cy(3, 0.8, twCol(0.08, 0.08, 0.1)), -L * 0.2, 26, D / 2 + 0.2, rx: .pi / 2)
            put(g, box(L * 0.34, 8, 0.4, twCol(1.0, 0.5, 0.15), glow: true), -L * 0.22, 14, D / 2 + 0.1)
            let motor = cy(5, 12, twCol(0.5, 0.53, 0.58), spec: 0.7, shin: 1)
            put(g, motor, -L / 4, 41, 0, rz: .pi / 2)
            put(g, cy(2.2, 20, steel, spec: 0.7, shin: 1), L / 2 - 6, 46, -D / 4)
            put(g, tr(3.2, 0.9, steel), L / 2 - 6, 52, -D / 4 + 3, rx: .pi / 2)
            put(g, cy(3.2, 2, dark), L / 2 - 6, 56.5, -D / 4)
        case 14: // gondola shelf
            put(g, rb(L, 3, D, twCol(0.5, 0.53, 0.58), 1, spec: 0.5), 0, 1.5, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cy(0.8, 40, twCol(0.8, 0.82, 0.86), spec: 0.8, shin: 1), sx * (L / 2 - 1), 21, sz * (D / 2 - 1)) } }
            put(g, rb(L - 2, 38, 1, twCol(0.78, 0.8, 0.84), 0.4), 0, 22, -D / 2 + 0.8)
            for row in 0..<3 {
                let y = 3.5 + CGFloat(row) * 13
                put(g, rb(L, 1.2, D - 0.8, twCol(0.9, 0.92, 0.95), 0.5, spec: 0.5), 0, y, 0)
                put(g, rb(L - 1, 1.5, 0.4, white, 0.2), 0, y, D / 2 - 0.2)
                var x = -L / 2 + 3
                var i = 0
                while x < L / 2 - 4 {
                    let t = (i + row) % 3
                    if t == 0 {
                        for s in 0..<3 { put(g, rb(7, 2.6, D * 0.6, palette[(i + s + row) % palette.count], 1.2, fabric: true), x + 3.5, y + 0.6 + 1.3 + CGFloat(s) * 2.6, 0.5, ry: CGFloat(s) * 0.05) }
                        x += 8.2
                    } else if t == 1 {
                        put(g, cy(1.3, 7, palette[(i + row) % palette.count], spec: 0.6, shin: 1), x + 1.4, y + 0.6 + 3.5, 1)
                        put(g, cy(0.8, 1.5, white), x + 1.4, y + 0.6 + 7.7, 1)
                        x += 3.4
                    } else {
                        put(g, rb(5.5, 7.5, 5.5, palette[(i * 2 + row) % palette.count], 0.5, spec: 0.1), x + 2.75, y + 0.6 + 3.75, 0.5)
                        x += 6.2
                    }
                    i += 1
                }
            }
        case 15: // bench
            let wood = twCol(0.8, 0.6, 0.42)
            let iron = twCol(0.1, 0.1, 0.12)
            for k in -1...1 { put(g, wd(L, 1.8, D / 3 - 0.4, wood), 0, 12.4, CGFloat(k) * D / 3) }
            put(g, wd(L, 3, 1.4, wood), 0, 19, -D / 2 + 1, rx: -0.2)
            put(g, wd(L, 3, 1.4, wood), 0, 23.5, -D / 2 + 0.5, rx: -0.2)
            for s in [-1.0, 1.0] as [CGFloat] {
                let x = s * (L / 2 - 5)
                put(g, rb(1.6, 12, D, iron, 0.6, spec: 0.5), x, 6, 0)
                put(g, rb(1.6, 1.6, D, iron, 0.6, spec: 0.5), x, 11.4, 0)
                put(g, rb(1.6, 22, 1.6, iron, 0.6, spec: 0.5), x, 11, -D / 2 + 1, rx: -0.2)
                put(g, rb(1.4, 1.4, D - 2, iron, 0.5, spec: 0.5), x, 17, 0)
                put(g, rb(1.4, 6, 1.4, iron, 0.5), x, 14, D / 2 - 1.5)
            }
        case 17: // lockers (doors face +z)
            let n = max(2, Int(L / 14))
            let w = L / CGFloat(n)
            let base = twCol(0.3, 0.46, 0.5)
            put(g, rb(L, 54, D, twCol(0.2, 0.3, 0.33), 1.2, spec: 0.5, shin: 0.8), 0, 28, 0)
            put(g, rb(L, 2.4, D + 1, twCol(0.22, 0.34, 0.37), 1, spec: 0.5), 0, 56.4, 0)
            put(g, rb(L, 3, D + 1, dark, 0.8), 0, 1.5, 0)
            let ajar = hv % 2 == 0 ? hv % n : -1
            for k in 0..<n {
                let x = -L / 2 + w * (CGFloat(k) + 0.5)
                let door = SCNNode()
                door.addChildNode(rb(w - 1.2, 50, 1, base, 0.8, spec: 0.5, shin: 0.8))
                for s in 0..<4 { put(door, box(w * 0.5, 0.7, 0.3, twCol(0.05, 0.08, 0.09)), 0, 20 + CGFloat(s) * 1.8, 0.6) }
                put(door, rb(1, 5, 1.2, twCol(0.8, 0.82, 0.86), 0.4, spec: 0.8, shin: 1), w * 0.28, 0, 0.9)
                put(door, box(3, 1.5, 0.3, white), 0, 12, 0.6)
                if k == ajar {
                    put(g, box(w - 1.4, 50, 0.4, twCol(0.02, 0.03, 0.03)), x, 29, D / 2 + 0.1)
                    let piv = SCNNode()
                    door.position = SCNVector3(Float((w - 1.2) / 2), 0, 0.5)
                    piv.addChildNode(door)
                    put(g, piv, x - w / 2 + 0.6, 29, D / 2 + 0.4, ry: -1.15)
                } else {
                    put(g, door, x, 29, D / 2 + 0.2)
                }
            }
        default: // pillar
            let conc = twCol(0.6, 0.62, 0.68)
            put(g, rb(L, 80, D, conc, 2.5, spec: 0.1), 0, 40, 0)
            put(g, rb(L + 6, 8, D + 6, twCol(0.42, 0.44, 0.5), 2, spec: 0.1), 0, 4, 0)
            put(g, rb(L + 6, 7, D + 6, twCol(0.42, 0.44, 0.5), 2, spec: 0.1), 0, 76.5, 0)
            let ac = def.coreC
            put(g, box(L + 0.8, 1, D + 0.8, twCol(ac.0, ac.1, ac.2), glow: true), 0, 62, 0)
            for s in [-1.0, 1.0] as [CGFloat] {
                put(g, rb(0.8, 60, 0.5, twCol(0.3, 0.32, 0.37), 0.2), 0, 34, s * (D / 2))
                put(g, rb(0.5, 60, 0.8, twCol(0.3, 0.32, 0.37), 0.2), s * (L / 2), 34, 0)
            }
        }
        g.position = SCNVector3(Float(r.midX), 0, Float(r.midY))
        if !long { g.eulerAngles = SCNVector3(0, Float.pi / 2, 0) }
        let n = SCNNode()
        n.addChildNode(g)
        return n
    }

    // MARK: actors

    private func gunModel(_ k: Int) -> SCNNode {
        let n = SCNNode()
        let metal = twCol(0.1, 0.1, 0.12)
        let metal2 = twCol(0.2, 0.2, 0.23)
        let wood = twCol(0.3, 0.2, 0.12)
        switch k {
        case 0:
            n.addChildNode(at(box(9, 2.4, 2.4, metal2), 4, 1.5, 0))
            let grip = box(2.4, 5.5, 2.4, metal)
            grip.eulerAngles = SCNVector3(0, 0, 0.18)
            n.addChildNode(at(grip, 0.8, -1.4, 0))
            n.addChildNode(at(box(1, 1, 1, twCol(1, 1, 1)), 8.4, 3, 0))
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
            n.addChildNode(at(cyl(1.2, 7, twCol(0.1, 0.1, 0.12)), 6, 4.6, 0))
            n.childNodes.last?.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        default:
            n.addChildNode(at(box(26, 2.2, 2.2, metal), 12, 1.2, 0))
            n.addChildNode(at(box(18, 1.8, 1.8, metal2), 11, -1.4, 0))
            n.addChildNode(at(box(8, 3.2, 3.4, wood), 14, -1.4, 0))
            n.addChildNode(at(box(11, 4, 2.8, wood), -6, -0.4, 0))
            n.addChildNode(at(box(5, 3, 2.6, metal), 1, 0.4, 0))
        }
        return n
    }

    private func buildActors() {
        let skins = [twCol(0.9, 0.72, 0.58), twCol(0.65, 0.45, 0.32), twCol(0.45, 0.3, 0.22), twCol(0.95, 0.8, 0.68)]
        let pants = twCol(0.16, 0.17, 0.2)
        let vest = twCol(0.2, 0.22, 0.18)
        let plate = twCol(0.32, 0.34, 0.3)
        for i in 0..<map.def.players {
            let root = SCNNode()
            let skin = skins[i % skins.count]
            // legs
            for z in [-3.5, 3.5] as [CGFloat] {
                let hip = SCNNode()
                hip.position = SCNVector3(0, 16, Float(z))
                hip.addChildNode(at(box(5.2, 15, 5.2, pants), 0, -7.5, 0))
                hip.addChildNode(at(box(8, 3, 5.8, twCol(0.08, 0.08, 0.1)), 1.2, -15, 0))
                root.addChildNode(hip)
                if z < 0 { legL.append(hip) } else { legR.append(hip) }
            }
            // torso
            let sm = SCNMaterial()
            sm.diffuse.contents = twCol(0.5, 0.5, 0.5)
            let tg = SCNBox(width: 8, height: 14, length: 14, chamferRadius: 0.8)
            tg.materials = [sm]
            root.addChildNode(at(SCNNode(geometry: tg), 0, 23.5, 0))
            shirtMats.append(sm)
            // vest + plates + pouches
            root.addChildNode(at(box(9.4, 11.5, 15, vest), 0, 24.5, 0))
            root.addChildNode(at(box(1, 8, 9.5, plate), 5, 26, 0))
            root.addChildNode(at(box(1, 8, 9.5, plate), -5, 26, 0))
            root.addChildNode(at(box(2.6, 3.6, 3.6, twCol(0.15, 0.17, 0.13)), 5.4, 20.4, -3.4))
            root.addChildNode(at(box(2.6, 3.6, 3.6, twCol(0.15, 0.17, 0.13)), 5.4, 20.4, 3.4))
            root.addChildNode(at(box(8, 2, 14.5, twCol(0.1, 0.1, 0.08)), 0, 17.6, 0))
            // shoulders
            root.addChildNode(at(box(5, 3, 4.5, vest), 0, 30, -8))
            root.addChildNode(at(box(5, 3, 4.5, vest), 0, 30, 8))
            // head
            root.addChildNode(at(ball(4.6, skin), 0.4, 35.5, 0))
            let helmet = ball(5.2, twCol(0.18, 0.2, 0.17))
            helmet.scale = SCNVector3(1, 0.72, 1)
            root.addChildNode(at(helmet, 0.2, 37.6, 0))
            root.addChildNode(at(box(2.4, 1.4, 7.5, twCol(0.05, 0.05, 0.07)), 4.1, 36, 0))
            // arms holding the gun
            let rArm = box(11, 3.6, 3.6, twCol(0.2, 0.22, 0.18))
            rArm.eulerAngles = SCNVector3(0, -0.2, -0.1)
            root.addChildNode(at(rArm, 6.5, 26.5, 6))
            root.addChildNode(at(box(3.2, 3.2, 3.2, skin), 12.2, 26, 4.8))
            let lArm = box(15, 3.6, 3.6, twCol(0.2, 0.22, 0.18))
            lArm.eulerAngles = SCNVector3(0, 0.35, -0.08)
            root.addChildNode(at(lArm, 8.2, 26.5, -4.6))
            root.addChildNode(at(box(3.2, 3.2, 3.2, skin), 15.5, 26, -1.4))
            // gun
            let holder = SCNNode()
            holder.position = SCNVector3(10, 26.5, 1.8)
            var variants: [SCNNode] = []
            for k in 0..<4 {
                let gm = gunModel(k)
                gm.isHidden = k != 0
                holder.addChildNode(gm)
                variants.append(gm)
            }
            let fl = box(6, 5, 5, twCol(1, 0.85, 0.3), glow: true)
            fl.isHidden = true
            holder.addChildNode(fl)
            root.addChildNode(holder)
            gunGroups.append(variants)
            gunHolder.append(holder)
            flashNodes.append(fl)
            gunShown.append(0)
            flashShown.append(false)
            hurtShown.append(false)
            // shadow
            let sh = SCNCylinder(radius: 10, height: 0.4)
            sh.radialSegmentCount = 12
            let shm = SCNMaterial()
            shm.diffuse.contents = twCol(0, 0, 0, 0.45)
            shm.lightingModel = .constant
            sh.materials = [shm]
            root.addChildNode(at(SCNNode(geometry: sh), 0, 0.9, 0))
            root.scale = SCNVector3(1.2, 1.2, 1.2)
            root.isHidden = true
            scene.rootNode.addChildNode(root)
            actorRoots.append(root)
        }
    }

    private func buildPools() {
        for _ in 0..<70 {
            let n = SCNNode()
            n.isHidden = true
            scene.rootNode.addChildNode(n)
            lootPool.append(n)
            lootKey.append(-1)
        }
        for c in [twCol(1, 0.9, 0.5), twCol(0.8, 0.6, 1.0)] {
            let g = SCNBox(width: 1, height: 1.2, length: 1.2, chamferRadius: 0)
            g.materials = [plain(c, glow: true)]
            tracerGeo.append(g)
        }
        for _ in 0..<40 {
            let n = SCNNode(geometry: tracerGeo[0])
            n.isHidden = true
            scene.rootNode.addChildNode(n)
            tracerPool.append(n)
            tracerKind.append(0)
        }
        let g = box(TowerMap.W, 1, TowerMap.H, twCol(0.2, 1.0, 0.25), glow: true)
        g.geometry?.firstMaterial?.transparency = 0.18
        g.geometry?.firstMaterial?.writesToDepthBuffer = false
        g.position = SCNVector3(Float(TowerMap.W / 2), 84, Float(TowerMap.H / 2))
        g.isHidden = true
        gasNode.addChildNode(g)
        scene.rootNode.addChildNode(gasNode)
        let w = box(TowerMap.W, 1, TowerMap.H, twCol(1.0, 0.6, 0.1), glow: true)
        w.geometry?.firstMaterial?.transparency = 0.1
        w.geometry?.firstMaterial?.writesToDepthBuffer = false
        w.position = SCNVector3(Float(TowerMap.W / 2), 84, Float(TowerMap.H / 2))
        w.isHidden = true
        warnNode.addChildNode(w)
        scene.rootNode.addChildNode(warnNode)
    }

    private func lootGeometry(_ key: Int, _ kind: Int, _ rar: Int) -> SCNGeometry {
        if let g = lootGeo[key] { return g }
        let rc: [UIColor] = [twCol(0.9, 0.9, 0.9), twCol(0.3, 0.62, 1.0), twCol(0.72, 0.42, 1.0), twCol(1.0, 0.8, 0.2)]
        let g: SCNGeometry
        let c: UIColor
        switch kind {
        case 0:
            g = SCNBox(width: 22, height: 5, length: 9, chamferRadius: 1)
            c = rc[min(3, rar)]
        case 1:
            g = SCNBox(width: 10, height: 8, length: 10, chamferRadius: 1)
            c = twCol(1.0, 0.65, 0.2)
        case 2:
            let cy = SCNCylinder(radius: 7, height: 6)
            cy.radialSegmentCount = 12
            g = cy
            c = twCol(0.25, 0.6, 1.0)
        case 3:
            g = SCNBox(width: 10, height: 8, length: 10, chamferRadius: 2)
            c = twCol(1.0, 0.25, 0.3)
        case 5:
            g = SCNBox(width: 11, height: 1.6, length: 15, chamferRadius: 1)
            c = twCol(1.0, 0.85, 0.2)
        default:
            g = SCNBox(width: 8, height: 4, length: 12, chamferRadius: 1)
            c = twCol(0.3, 0.9, 0.4)
        }
        let m = SCNMaterial()
        m.diffuse.contents = c
        m.emission.contents = c
        m.emission.intensity = 0.6
        g.materials = [m]
        lootGeo[key] = g
        return g
    }

    // MARK: sync

    func project(_ p: CGPoint, _ h: CGFloat) -> CGPoint? {
        let v = view.projectPoint(SCNVector3(Float(p.x), Float(h), Float(p.y)))
        if v.z > 1 || v.z < 0 { return nil }
        return CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
    }

    private func applyQuality() {
        if quality <= 1 {
            view.antialiasingMode = .none
            sunNode?.light?.castsShadow = false
            camNode.camera?.screenSpaceAmbientOcclusionIntensity = 0
        }
        if quality <= 0 {
            camNode.camera?.wantsHDR = false
            camNode.camera?.bloomIntensity = 0
        }
        for n in poolRoots { n.isHidden = quality <= 0 }
        if quality <= 0 { view.contentScaleFactor = min(view.contentScaleFactor, 1.5) }
    }

    func sync(_ e: TowerEngine, dt: CGFloat) {
        // adaptive quality: step down if the frame rate stays low
        fpsEMA = fpsEMA * 0.95 + (1 / max(0.001, dt)) * 0.05
        if fpsEMA < 42 { lowTime += dt } else { lowTime = max(0, lowTime - dt) }
        if lowTime > 2.5 && quality > 0 {
            quality -= 1
            applyQuality()
            lowTime = 0
            fpsEMA = 60
        }
        vs = e.currentViews()
        let kc = e.killcam
        var ti = 0
        if let k = kc { ti = k.killer } else if !e.me.alive { ti = e.actors.firstIndex(where: { $0.team == 0 && $0.alive }) ?? 0 }
        let tv = vs[ti]
        focus = tv.f
        let heights: [CGFloat] = [290, 360, 470]
        var wantH = heights[max(0, min(2, e.zoom))]
        var lx: CGFloat = 0, lz: CGFloat = 0
        if kc != nil {
            wantH = 250
            lx = cos(tv.ang) * 55
            lz = sin(tv.ang) * 55
        } else if ti == 0 {
            let m = hypot(e.aim.x, e.aim.y)
            if m > 0.2 { lx = e.aim.x * 95; lz = e.aim.y * 95 }
        }
        if (kc != nil) != lastKC {
            camX = tv.p.x
            camZ = tv.p.y
            lastKC = kc != nil
        }
        let k = min(1, dt * 8)
        leadX += (lx - leadX) * k
        leadZ += (lz - leadZ) * k
        camX += (tv.p.x - camX) * k
        camZ += (tv.p.y - camZ) * k
        camH += (wantH - camH) * k
        let cx = camX + leadX, cz = camZ + leadZ
        if e.look && kc == nil {
            let tx = camX, tz = camZ
            let cp = cos(e.camPitch), sp = sin(e.camPitch)
            camNode.position = SCNVector3(Float(tx + e.camDist * sin(e.camYaw) * cp), Float(e.camDist * sp), Float(tz + e.camDist * cos(e.camYaw) * cp))
            camNode.look(at: SCNVector3(Float(tx), 20, Float(tz)))
        } else {
            camNode.position = SCNVector3(Float(cx), Float(camH), Float(cz + camH * 0.82))
            camNode.look(at: SCNVector3(Float(cx), 0, Float(cz)))
        }

        for f in 0..<map.nF { floorRoots[f].isHidden = f != focus }
        for (i, d) in map.doors[focus].enumerated() where i < doorNodes[focus].count {
            let ang = Float(d.open) * 1.65 * (i % 2 == 0 ? 1 : -1)
            if abs(doorAngShown[focus][i] - ang) > 0.004 {
                doorAngShown[focus][i] = ang
                doorNodes[focus][i].eulerAngles = SCNVector3(0, d.horiz ? -ang : ang, 0)
            }
        }
        // actors
        seenIdx = []
        for (i, v) in vs.enumerated() where i < actorRoots.count {
            let r = actorRoots[i]
            var seen = v.alive && v.f == focus
            if seen && i != ti && v.team != 0 {
                let d = hypot(v.p.x - tv.p.x, v.p.y - tv.p.y)
                seen = d < 640 && map.los(focus, tv.p, v.p)
            }
            r.isHidden = !seen
            if !seen { continue }
            r.scale = SCNVector3(1, v.crouch ? 0.74 : 1, 1)
            seenIdx.append(i)
            r.position = SCNVector3(Float(v.p.x), 0, Float(v.p.y))
            r.eulerAngles = SCNVector3(0, Float(-v.ang), 0)
            let sw = Float(sin(v.walk * 1.4)) * 0.7
            legL[i].eulerAngles = SCNVector3(0, 0, sw)
            legR[i].eulerAngles = SCNVector3(0, 0, -sw)
            if gunShown[i] != v.gun {
                for (k, g) in gunGroups[i].enumerated() { g.isHidden = k != v.gun }
                flashNodes[i].position = SCNVector3([Float(10), 16, 29, 34][v.gun], 1, 0)
                gunShown[i] = v.gun
            }
            if flashShown[i] != v.flash {
                flashNodes[i].isHidden = !v.flash
                gunHolder[i].position = SCNVector3(v.flash ? 8.8 : 10, 26.5, 1.8)
                flashShown[i] = v.flash
            }
            if hurtShown[i] != v.hurt {
                shirtMats[i].emission.contents = v.hurt ? UIColor.white : UIColor.black
                hurtShown[i] = v.hurt
            }
        }
        // loot
        var used = 0
        let t = CACurrentMediaTime()
        for l in e.loot where l.alive && l.f == focus {
            if used >= lootPool.count { break }
            if abs(l.p.x - cx) > 520 || abs(l.p.y - cz) > 330 { continue }
            let n = lootPool[used]
            let key = l.kind * 10 + l.rar
            if lootKey[used] != key {
                n.geometry = lootGeometry(key, l.kind, l.rar)
                lootKey[used] = key
            }
            n.position = SCNVector3(Float(l.p.x), Float(5 + sin(t * 3 + Double(l.p.x)) * 1.5), Float(l.p.y))
            n.eulerAngles = SCNVector3(0, Float(t + Double(l.p.y)), 0)
            n.isHidden = false
            used += 1
        }
        for i in used..<lootPool.count { lootPool[i].isHidden = true }
        // tracers
        var ti2 = 0
        for tr in e.currentShots(focus) {
            if ti2 >= tracerPool.count { break }
            let n = tracerPool[ti2]
            let kind = tr.hot ? 1 : 0
            if tracerKind[ti2] != kind { n.geometry = tracerGeo[kind]; tracerKind[ti2] = kind }
            let dx = tr.b.x - tr.a.x, dy = tr.b.y - tr.a.y
            let len = max(1, hypot(dx, dy))
            n.scale = SCNVector3(Float(len), 1, 1)
            n.position = SCNVector3(Float((tr.a.x + tr.b.x) / 2), 27, Float((tr.a.y + tr.b.y) / 2))
            n.eulerAngles = SCNVector3(0, Float(-atan2(dy, dx)), 0)
            n.isHidden = false
            ti2 += 1
        }
        for i in ti2..<tracerPool.count { tracerPool[i].isHidden = true }
        // glass, doors by kind, belts, trains, power panel
        for (i, n) in glassNodes[focus].enumerated() { n.isHidden = !map.glassAlive[focus][i] }
        for (i, d) in map.doors[focus].enumerated() where i < doorKindShown[focus].count {
            if doorKindShown[focus][i] != d.kind {
                doorKindShown[focus][i] = d.kind
                doorNodes[focus][i].childNodes.first?.childNodes.first?.geometry?.firstMaterial?.diffuse.contents = doorColor(d.kind)
            }
        }
        for (i, n) in beltNodes[focus].enumerated() {
            let su = beltLen[focus][i] / 64
            let off = CGFloat(t) * beltVel[focus][i] / 64
            n.geometry?.materials[4].diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeScale(Float(su), 1, 1), SCNMatrix4MakeTranslation(Float(-off), 0, 0))
        }
        for n in trainNodes { n.isHidden = true }
        for tr in e.trains where tr.f == focus && tr.state == 2 && tr.li < trainNodes.count {
            let n = trainNodes[tr.li]
            n.isHidden = false
            n.position = SCNVector3(Float(tr.rect.midX), 0, Float(tr.rect.midY))
            n.eulerAngles = SCNVector3(0, tr.dir > 0 ? 0 : Float.pi, 0)
        }
        if def.mech == 6, focus < e.powerOn.count {
            let col = e.powerOn[focus] ? twCol(0.2, 1.0, 0.4) : twCol(1.0, 0.2, 0.2)
            switchNodes[focus].geometry?.firstMaterial?.diffuse.contents = col
            switchNodes[focus].geometry?.firstMaterial?.emission.contents = col
        }
        let gas = e.gassed.contains(focus)
        gasNode.childNodes.first?.isHidden = !gas
        warnNode.childNodes.first?.isHidden = !(e.warnFloor == focus && Int(t * 3) % 2 == 0)
    }
}
