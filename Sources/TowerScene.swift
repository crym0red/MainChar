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
    private let map = TowerMap.shared
    private var rng = TwLCG(s: 4242)

    private let matCols: [(CGFloat, CGFloat, CGFloat)] = [(0.55, 0.6, 0.72), (0.9, 0.75, 0.55), (0.72, 0.5, 0.7), (0.92, 0.9, 0.82), (0.5, 0.58, 0.78), (0.6, 0.85, 0.88)]
    private let roomKind = ["carpet", "wood", "carpet", "marble", "carpet", "tile"]
    private let hallKind = ["marble", "tile", "tile", "wood", "carpet", "marble"]
    private let floorTint: [(CGFloat, CGFloat, CGFloat)] = [(0.95, 0.97, 1.0), (1.0, 0.96, 0.88), (0.86, 1.0, 0.98), (1.0, 0.88, 0.95), (0.88, 0.9, 1.0), (1.0, 0.94, 0.8)]

    // MARK: textures

    private func tex(_ key: String, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        if let t = texCache[key] { return t }
        let s: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { c in draw(c.cgContext, s) }
        texCache[key] = img
        return img
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
        }
    }

    private var poolTex: UIImage {
        tex("pool") { g, s in
            let cs = CGColorSpaceCreateDeviceRGB()
            let cols = [twCol(1, 0.95, 0.8, 0.55).cgColor, twCol(1, 0.95, 0.8, 0).cgColor] as CFArray
            if let gr = CGGradient(colorsSpace: cs, colors: cols, locations: [0, 1]) {
                g.drawRadialGradient(gr, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0, endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2, options: [])
            }
        }
    }

    private func texMat(_ img: UIImage, _ su: CGFloat, _ sv: CGFloat, _ tint: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = img
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(su), Float(sv), 1)
        m.multiply.contents = tint
        return m
    }

    private func plain(_ c: UIColor, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant }
        return m
    }

    private func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, glow: Bool = false) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        g.materials = [plain(c, glow: glow)]
        return SCNNode(geometry: g)
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

    init() {
        scene.background.contents = twCol(0.02, 0.025, 0.04)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 520
        amb.light?.color = twCol(0.8, 0.85, 1.0)
        scene.rootNode.addChildNode(amb)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1000
        sun.light?.color = twCol(1.0, 0.95, 0.88)
        sun.eulerAngles = SCNVector3(-1.15, 0.6, 0)
        scene.rootNode.addChildNode(sun)

        let cam = SCNCamera()
        cam.fieldOfView = 52
        cam.zNear = 10
        cam.zFar = 3000
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)

        for f in 0..<TowerMap.nF { buildFloor(f) }
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
            else { c = UIColor(hue: CGFloat(a.team) / CGFloat(TowerEngine.teams), saturation: 0.6, brightness: 0.75, alpha: 1) }
            shirtMats[i].diffuse.contents = c
        }
    }

    // MARK: floors

    private func floorBox(_ w: CGFloat, _ l: CGFloat, _ y: CGFloat, _ kind: String, _ tint: UIColor, _ tile: CGFloat) -> SCNNode {
        let g = SCNBox(width: w, height: 1, length: l, chamferRadius: 0)
        let side = plain(twCol(0.15, 0.15, 0.17))
        g.materials = [side, side, side, side, texMat(floorTex(kind), w / tile, l / tile, tint), side]
        return SCNNode(geometry: g)
    }

    private func wallBox(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ tint: UIColor) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        let vf = h / 80
        let fb = texMat(wallTex, max(0.05, w / 120), vf, tint)
        let lr = texMat(wallTex, max(0.05, l / 120), vf, tint)
        let top = plain(twCol(0.97, 0.97, 1.0))
        let bot = plain(twCol(0.2, 0.2, 0.22))
        g.materials = [fb, lr, fb, lr, top, bot]
        return SCNNode(geometry: g)
    }

    private func buildFloor(_ f: Int) {
        let st = SCNNode()
        let W = TowerMap.W, H = TowerMap.H
        let t = floorTint[f]
        let tintC = twCol(t.0, t.1, t.2)
        st.addChildNode(at(floorBox(W, H, -0.5, hallKind[f], twCol(0.55 * t.0, 0.58 * t.1, 0.62 * t.2), 96), W / 2, -0.5, H / 2))
        for r in map.rooms[f] {
            let c = matCols[r.mat % matCols.count]
            let n = floorBox(r.r.width, r.r.height, 0, roomKind[r.mat % roomKind.count], twCol(c.0, c.1, c.2), 90)
            st.addChildNode(at(n, r.r.midX, 0, r.r.midY))
        }
        // wall base shadow + walls
        for w in map.walls[f] {
            st.addChildNode(at(wallBox(w.width, TowerMap.wallH, w.height, tintC), w.midX, TowerMap.wallH / 2, w.midY))
        }
        // windows on the exterior skin
        for k in 0..<10 {
            let x = 70 + CGFloat(k) * 150
            st.addChildNode(at(box(70, 26, 1.5, twCol(0.25, 0.45, 0.75), glow: true), x, 46, TowerMap.T + 0.9))
            st.addChildNode(at(box(70, 26, 1.5, twCol(0.25, 0.45, 0.75), glow: true), x, 46, H - TowerMap.T - 0.9))
        }
        // core accents
        let core = TowerMap.core
        st.addChildNode(at(box(core.width - 24, 3, core.height - 24, twCol(0.1, 0.45, 0.62), glow: true), core.midX, 81.5, core.midY))
        for p in map.props[f] { st.addChildNode(propNode(p, f)) }
        // light pools
        var pools: [CGPoint] = []
        for x in stride(from: 160, to: 1500, by: 220) { pools.append(CGPoint(x: CGFloat(x), y: 500)); pools.append(CGPoint(x: CGFloat(x), y: 300)); pools.append(CGPoint(x: CGFloat(x), y: 700)) }
        for r in map.rooms[f] { pools.append(CGPoint(x: r.r.midX, y: r.r.midY)) }
        for p in pools {
            let pl = SCNPlane(width: 210, height: 210)
            let m = SCNMaterial()
            m.diffuse.contents = poolTex
            m.lightingModel = .constant
            m.blendMode = .add
            m.writesToDepthBuffer = false
            m.isDoubleSided = true
            pl.materials = [m]
            let n = SCNNode(geometry: pl)
            n.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            n.position = SCNVector3(Float(p.x), 0.8, Float(p.y))
            st.addChildNode(n)
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
        var dn: [SCNNode] = []
        for d in map.doors[f] {
            let n = box(d.r.width, 66, d.r.height, twCol(0.62, 0.38, 0.18))
            n.addChildNode(at(box(d.horiz ? 6 : d.r.width + 1, 3, d.horiz ? d.r.height + 1 : 6, twCol(0.85, 0.8, 0.3)), 0, 0, 0))
            n.position = SCNVector3(Float(d.r.midX), 33, Float(d.r.midY))
            root.addChildNode(n)
            dn.append(n)
        }
        root.isHidden = true
        scene.rootNode.addChildNode(root)
        floorRoots.append(root)
        doorNodes.append(dn)
    }

    private func propNode(_ p: TwProp, _ f: Int) -> SCNNode {
        let r = p.r
        let n = SCNNode()
        let cx = r.midX, cz = r.midY
        switch p.kind {
        case 0: // crate
            n.addChildNode(at(box(r.width, 30, r.height, twCol(0.55, 0.4, 0.22)), cx, 15, cz))
            for dy in [1.0, 29.0] as [CGFloat] { n.addChildNode(at(box(r.width + 1, 3, r.height + 1, twCol(0.35, 0.25, 0.13)), cx, dy, cz)) }
            n.addChildNode(at(box(3, 30.5, r.height + 1, twCol(0.35, 0.25, 0.13)), cx, 15, cz))
        case 1: // desk + monitor + chair
            n.addChildNode(at(box(r.width, 3, r.height, twCol(0.5, 0.36, 0.24)), cx, 23, cz))
            n.addChildNode(at(box(3, 22, r.height - 4, twCol(0.3, 0.22, 0.15)), r.minX + 3, 11, cz))
            n.addChildNode(at(box(3, 22, r.height - 4, twCol(0.3, 0.22, 0.15)), r.maxX - 3, 11, cz))
            n.addChildNode(at(box(2, 9, 12, twCol(0.05, 0.05, 0.07)), cx, 30, cz))
            n.addChildNode(at(box(0.6, 7, 10.5, twCol(0.15, 0.8, 0.95), glow: true), cx + 1.2, 30, cz))
            n.addChildNode(at(box(4, 1, 8, twCol(0.1, 0.1, 0.12)), cx - 6, 24, cz))
            let chairZ = r.height < r.width ? r.maxY + 9 : cz
            let chairX = r.height < r.width ? cx : r.maxX + 9
            n.addChildNode(at(box(11, 3, 11, twCol(0.12, 0.12, 0.15)), chairX, 13, chairZ))
            n.addChildNode(at(box(11, 12, 2, twCol(0.12, 0.12, 0.15)), chairX, 19, chairZ + 5))
            n.addChildNode(at(cyl(1, 10, twCol(0.3, 0.3, 0.3)), chairX, 7, chairZ))
        case 2: // couch with rug
            let rug = box(r.width + 24, 0.8, r.height + 24, twCol(0.35, 0.12, 0.14))
            n.addChildNode(at(rug, cx, 1, cz))
            n.addChildNode(at(box(r.width, 10, r.height, twCol(0.45, 0.16, 0.22)), cx, 8, cz))
            let long = r.width >= r.height
            n.addChildNode(at(box(long ? r.width : 9, 20, long ? 9 : r.height, twCol(0.4, 0.14, 0.2)), long ? cx : r.minX + 4.5, 15, long ? r.minY + 4.5 : cz))
            let cu = twCol(0.6, 0.22, 0.3)
            if long {
                n.addChildNode(at(box(r.width / 2 - 6, 5, r.height - 12, cu), cx - r.width / 4, 15, cz + 3))
                n.addChildNode(at(box(r.width / 2 - 6, 5, r.height - 12, cu), cx + r.width / 4, 15, cz + 3))
            } else {
                n.addChildNode(at(box(r.width - 12, 5, r.height / 2 - 6, cu), cx + 3, 15, cz - r.height / 4))
                n.addChildNode(at(box(r.width - 12, 5, r.height / 2 - 6, cu), cx + 3, 15, cz + r.height / 4))
            }
        case 3: // plant
            n.addChildNode(at(cyl(min(r.width, r.height) / 2, 12, twCol(0.5, 0.3, 0.2)), cx, 6, cz))
            for (dx, dy, dz, rr) in [(0.0, 20.0, 0.0, 9.0), (4.0, 27.0, 3.0, 6.0), (-4.0, 25.0, -3.0, 6.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                n.addChildNode(at(ball(rr, twCol(0.12, 0.5 + dy * 0.004, 0.18)), cx + dx, dy, cz + dz))
            }
        case 4: // shelf with books
            n.addChildNode(at(box(r.width, 54, r.height, twCol(0.34, 0.25, 0.18)), cx, 27, cz))
            let long = r.width >= r.height
            let cols: [UIColor] = [twCol(0.7, 0.2, 0.2), twCol(0.2, 0.4, 0.7), twCol(0.8, 0.7, 0.2), twCol(0.25, 0.6, 0.35), twCol(0.9, 0.9, 0.85)]
            for row in 0..<3 {
                let y = 12 + CGFloat(row) * 16
                let count = Int((long ? r.width : r.height) / 6)
                for b in 0..<count {
                    let off = -((long ? r.width : r.height) / 2) + 4 + CGFloat(b) * 6
                    let bh = 9 + CGFloat((b * 7 + row * 3) % 5)
                    let col = cols[(b + row * 2) % cols.count]
                    if long { n.addChildNode(at(box(4.5, bh, 3, col), cx + off, y + bh / 2 - 2, r.maxY + 0.8)) }
                    else { n.addChildNode(at(box(3, bh, 4.5, col), r.maxX + 0.8, y + bh / 2 - 2, cz + off)) }
                }
            }
        case 5: // table
            n.addChildNode(at(box(r.width, 3, r.height, twCol(0.55, 0.4, 0.28)), cx, 21, cz))
            for (dx, dz) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] as [(CGFloat, CGFloat)] {
                n.addChildNode(at(box(3, 20, 3, twCol(0.3, 0.22, 0.15)), cx + dx * (r.width / 2 - 4), 10, cz + dz * (r.height / 2 - 4)))
            }
            n.addChildNode(at(cyl(3, 4, twCol(0.9, 0.9, 0.95)), cx, 24, cz))
        case 6: // server rack
            n.addChildNode(at(box(r.width, 58, r.height, twCol(0.12, 0.13, 0.16)), cx, 29, cz))
            for k in 0..<7 {
                let y = 6 + CGFloat(k) * 7.5
                n.addChildNode(at(box(r.width + 0.6, 4, r.height - 6, twCol(0.2, 0.22, 0.26)), cx, y, cz))
                let led = k % 3 == 0 ? twCol(1.0, 0.3, 0.2) : twCol(0.2, 1.0, 0.4)
                n.addChildNode(at(box(r.width + 0.8, 1, 3, led, glow: true), cx, y + 1, cz + (r.height > r.width ? 0 : r.height / 2 - 4)))
            }
        case 7: // barrel
            n.addChildNode(at(cyl(min(r.width, r.height) / 2, 30, twCol(0.65, 0.18, 0.12)), cx, 15, cz))
            n.addChildNode(at(cyl(min(r.width, r.height) / 2 + 0.5, 3, twCol(0.2, 0.2, 0.22)), cx, 8, cz))
            n.addChildNode(at(cyl(min(r.width, r.height) / 2 + 0.5, 3, twCol(0.2, 0.2, 0.22)), cx, 22, cz))
        case 8: // kiosk
            n.addChildNode(at(box(r.width, 36, r.height, twCol(0.18, 0.22, 0.3)), cx, 18, cz))
            n.addChildNode(at(box(r.width + 4, 4, r.height + 4, twCol(0.9, 0.7, 0.2), glow: true), cx, 38, cz))
            n.addChildNode(at(box(r.width * 0.6, 10, 1, twCol(0.2, 0.8, 1.0), glow: true), cx, 24, r.maxY + 0.6))
        default: // pillar
            n.addChildNode(at(box(r.width, 80, r.height, twCol(0.62, 0.64, 0.7)), cx, 40, cz))
            n.addChildNode(at(box(r.width + 6, 6, r.height + 6, twCol(0.45, 0.47, 0.52)), cx, 3, cz))
            n.addChildNode(at(box(r.width + 6, 6, r.height + 6, twCol(0.45, 0.47, 0.52)), cx, 77, cz))
        }
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
        for i in 0..<(TowerEngine.teams * TowerEngine.per) {
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

    func sync(_ e: TowerEngine, dt: CGFloat) {
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
        camNode.position = SCNVector3(Float(cx), Float(camH), Float(cz + camH * 0.6))
        camNode.look(at: SCNVector3(Float(cx), 0, Float(cz)))

        for f in 0..<TowerMap.nF { floorRoots[f].isHidden = f != focus }
        for (i, d) in map.doors[focus].enumerated() where i < doorNodes[focus].count {
            let n = doorNodes[focus][i]
            let sc = max(0.04, 1 - d.open * 0.96)
            if d.horiz {
                n.scale = SCNVector3(Float(sc), 1, 1)
                n.position = SCNVector3(Float(d.r.minX + d.r.width * sc / 2), 33, Float(d.r.midY))
            } else {
                n.scale = SCNVector3(1, 1, Float(sc))
                n.position = SCNVector3(Float(d.r.midX), 33, Float(d.r.minY + d.r.height * sc / 2))
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
        let gas = e.gassed.contains(focus)
        gasNode.childNodes.first?.isHidden = !gas
        warnNode.childNodes.first?.isHidden = !(e.warnFloor == focus && Int(t * 3) % 2 == 0)
    }
}
