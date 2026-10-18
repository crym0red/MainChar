import SwiftUI
import SceneKit
import QuartzCore

struct TowerSceneView: UIViewRepresentable {
    let bridge: TowerScene
    func makeUIView(context: Context) -> SCNView { bridge.view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

private func twCol(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
    UIColor(red: min(1, r), green: min(1, g), blue: min(1, b), alpha: a)
}

final class TowerScene {
    let scene = SCNScene()
    let view = SCNView(frame: .zero)
    let camNode = SCNNode()
    var camX: CGFloat = 800
    var camZ: CGFloat = 500
    var focus = 0
    var seenIdx: [Int] = []
    var floorRoots: [SCNNode] = []
    var doorNodes: [[SCNNode]] = []
    var actorRoots: [SCNNode] = []
    var actorBody: [SCNNode] = []
    var actorFlash: [SCNNode] = []
    var lootPool: [SCNNode] = []
    var tracerPool: [SCNNode] = []
    let gasNode = SCNNode()
    let warnNode = SCNNode()
    private var lootGeo: [Int: SCNGeometry] = [:]
    private var tint: [UIColor] = []
    private let map = TowerMap.shared

    private let matCols: [(CGFloat, CGFloat, CGFloat)] = [(0.52, 0.55, 0.62), (0.55, 0.43, 0.32), (0.5, 0.34, 0.46), (0.72, 0.7, 0.62), (0.36, 0.42, 0.55), (0.38, 0.62, 0.64)]
    private let floorTint: [(CGFloat, CGFloat, CGFloat)] = [(0.9, 0.92, 1.0), (1.0, 0.96, 0.88), (0.86, 1.0, 0.98), (1.0, 0.88, 0.95), (0.88, 0.9, 1.0), (1.0, 0.94, 0.8)]

    private func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, glow: Bool = false) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
        let m = SCNMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant }
        g.materials = [m]
        return SCNNode(geometry: g)
    }

    private func place(_ n: SCNNode, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> SCNNode {
        n.position = SCNVector3(Float(x), Float(y), Float(z))
        return n
    }

    init() {
        scene.background.contents = twCol(0.03, 0.04, 0.06)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 650
        scene.rootNode.addChildNode(amb)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-1.2, 0.5, 0)
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

    // MARK: build

    private func buildFloor(_ f: Int) {
        let st = SCNNode()
        let W = TowerMap.W, H = TowerMap.H
        let t = floorTint[f]
        let hall = box(W, 2, H, twCol(0.2 * t.0, 0.22 * t.1, 0.26 * t.2))
        st.addChildNode(place(hall, W / 2, -1, H / 2))
        for r in map.rooms[f] {
            let c = matCols[r.mat % matCols.count]
            let n = box(r.r.width, 1, r.r.height, twCol(c.0 * 0.62, c.1 * 0.62, c.2 * 0.62))
            st.addChildNode(place(n, r.r.midX, -0.4, r.r.midY))
        }
        // hall stripe
        st.addChildNode(place(box(W - 80, 0.6, 20, twCol(0.3 * t.0, 0.32 * t.1, 0.38 * t.2)), W / 2, 0.2, 500))
        // walls
        let wc = twCol(0.78 * t.0, 0.8 * t.1, 0.86 * t.2)
        for w in map.walls[f] {
            let h: CGFloat = w == TowerMap.core ? 80 : TowerMap.wallH
            st.addChildNode(place(box(w.width, h, w.height, wc), w.midX, h / 2, w.midY))
            st.addChildNode(place(box(w.width + 1, 2, w.height + 1, twCol(0.95, 0.96, 1.0)), w.midX, h + 1, w.midY))
        }
        // core accents
        let core = TowerMap.core
        st.addChildNode(place(box(core.width - 30, 3, core.height - 30, twCol(0.2, 0.55, 0.7), glow: true), core.midX, 82, core.midY))
        // props
        for p in map.props[f] { st.addChildNode(propNode(p)) }
        // stairs
        for (k, r) in [TowerMap.stairW, TowerMap.stairE].enumerated() {
            for s in 0..<7 {
                let w = r.width / 7
                let h = 3 + CGFloat(s) * 3
                let col = k == 0 ? twCol(0.3 + CGFloat(s) * 0.05, 0.55 + CGFloat(s) * 0.04, 0.3) : twCol(0.6, 0.3 + CGFloat(s) * 0.04, 0.3)
                let x = k == 0 ? r.minX + w * (CGFloat(s) + 0.5) : r.maxX - w * (CGFloat(s) + 0.5)
                st.addChildNode(place(box(w, h, r.height, col), x, h / 2, r.midY))
            }
        }
        // elevators
        for r in TowerMap.elevs {
            st.addChildNode(place(box(r.width, 2, r.height, twCol(0.15, 0.6, 0.9), glow: true), r.midX, 1, r.midY))
            st.addChildNode(place(box(r.width + 8, 14, 4, twCol(0.7, 0.75, 0.8)), r.midX, 7, r.minY - 2))
            st.addChildNode(place(box(r.width + 8, 14, 4, twCol(0.7, 0.75, 0.8)), r.midX, 7, r.maxY + 2))
        }
        let root = SCNNode()
        root.addChildNode(st.flattenedClone())
        var dn: [SCNNode] = []
        for d in map.doors[f] {
            let n = box(d.r.width, 66, d.r.height, twCol(0.95, 0.62, 0.2))
            n.position = SCNVector3(Float(d.r.midX), 33, Float(d.r.midY))
            root.addChildNode(n)
            dn.append(n)
        }
        root.isHidden = true
        scene.rootNode.addChildNode(root)
        floorRoots.append(root)
        doorNodes.append(dn)
    }

    private func propNode(_ p: TwProp) -> SCNNode {
        let r = p.r
        let n = SCNNode()
        switch p.kind {
        case 0:
            n.addChildNode(place(box(r.width, 30, r.height, twCol(0.6, 0.45, 0.25)), r.midX, 15, r.midY))
        case 1:
            n.addChildNode(place(box(r.width, 24, r.height, twCol(0.42, 0.3, 0.2)), r.midX, 12, r.midY))
            n.addChildNode(place(box(r.width * 0.3, 4, r.height * 0.5, twCol(0.1, 0.8, 0.9), glow: true), r.midX, 26, r.midY))
        case 2:
            n.addChildNode(place(box(r.width, 14, r.height, twCol(0.55, 0.2, 0.3)), r.midX, 7, r.midY))
            n.addChildNode(place(box(r.width, 20, 8, twCol(0.5, 0.18, 0.28)), r.midX, 14, r.minY + 4))
        case 3:
            n.addChildNode(place(box(r.width, 12, r.height, twCol(0.45, 0.3, 0.2)), r.midX, 6, r.midY))
            n.addChildNode(place(box(r.width * 0.9, 24, r.height * 0.9, twCol(0.15, 0.55, 0.2)), r.midX, 24, r.midY))
        case 4:
            n.addChildNode(place(box(r.width, 54, r.height, twCol(0.4, 0.3, 0.22)), r.midX, 27, r.midY))
        case 5:
            n.addChildNode(place(box(r.width, 22, r.height, twCol(0.5, 0.36, 0.25)), r.midX, 11, r.midY))
        case 6:
            n.addChildNode(place(box(r.width, 56, r.height, twCol(0.15, 0.17, 0.2)), r.midX, 28, r.midY))
            n.addChildNode(place(box(r.width * 0.7, 3, r.height * 0.8, twCol(0.2, 1.0, 0.4), glow: true), r.midX, 56, r.midY))
        case 7:
            n.addChildNode(place(box(r.width, 30, r.height, twCol(0.7, 0.2, 0.15)), r.midX, 15, r.midY))
        case 8:
            n.addChildNode(place(box(r.width, 40, r.height, twCol(0.2, 0.24, 0.3)), r.midX, 20, r.midY))
            n.addChildNode(place(box(r.width * 0.6, 4, r.height * 0.6, twCol(1.0, 0.8, 0.2), glow: true), r.midX, 42, r.midY))
        default:
            n.addChildNode(place(box(r.width, 80, r.height, twCol(0.6, 0.62, 0.68)), r.midX, 40, r.midY))
        }
        return n
    }

    private func buildActors() {
        for _ in 0..<(TowerEngine.teams * TowerEngine.per) {
            let root = SCNNode()
            let body = SCNCapsule(capRadius: 8, height: 28)
            let bm = SCNMaterial()
            bm.diffuse.contents = UIColor.white
            body.materials = [bm]
            let bn = SCNNode(geometry: body)
            bn.position = SCNVector3(0, 16, 0)
            root.addChildNode(bn)
            let head = SCNSphere(radius: 6)
            let hm = SCNMaterial()
            hm.diffuse.contents = twCol(0.9, 0.7, 0.55)
            head.materials = [hm]
            root.addChildNode(place(SCNNode(geometry: head), 0, 36, 0))
            root.addChildNode(place(box(22, 4, 3, twCol(0.1, 0.1, 0.12)), 12, 24, 5))
            let fl = box(7, 7, 7, twCol(1, 0.85, 0.3), glow: true)
            fl.position = SCNVector3(25, 24, 5)
            fl.isHidden = true
            root.addChildNode(fl)
            // shadow disc
            let sh = SCNCylinder(radius: 10, height: 0.5)
            let sm = SCNMaterial()
            sm.diffuse.contents = twCol(0, 0, 0, 0.45)
            sm.lightingModel = .constant
            sh.materials = [sm]
            root.addChildNode(place(SCNNode(geometry: sh), 0, 0.5, 0))
            root.isHidden = true
            scene.rootNode.addChildNode(root)
            actorRoots.append(root)
            actorBody.append(bn)
            actorFlash.append(fl)
        }
    }

    private func buildPools() {
        for _ in 0..<90 {
            let n = SCNNode()
            n.isHidden = true
            scene.rootNode.addChildNode(n)
            lootPool.append(n)
        }
        for _ in 0..<40 {
            let n = box(1, 1.4, 1.4, twCol(1, 0.9, 0.5), glow: true)
            n.isHidden = true
            scene.rootNode.addChildNode(n)
            tracerPool.append(n)
        }
        let g = box(TowerMap.W, 1, TowerMap.H, twCol(0.2, 1.0, 0.25, 0.2), glow: true)
        g.geometry?.firstMaterial?.transparency = 0.2
        g.geometry?.firstMaterial?.writesToDepthBuffer = false
        g.position = SCNVector3(Float(TowerMap.W / 2), 84, Float(TowerMap.H / 2))
        g.isHidden = true
        gasNode.addChildNode(g)
        scene.rootNode.addChildNode(gasNode)
        let w = box(TowerMap.W, 1, TowerMap.H, twCol(1.0, 0.6, 0.1, 0.12), glow: true)
        w.geometry?.firstMaterial?.transparency = 0.12
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
            g = SCNCylinder(radius: 7, height: 6)
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
        var tgt = e.me
        if !tgt.alive, let m = e.actors.first(where: { $0.team == 0 && $0.alive }) { tgt = m }
        focus = tgt.f
        let k = min(1, dt * 9)
        camX += (tgt.p.x - camX) * k
        camZ += (tgt.p.y - camZ) * k
        camNode.position = SCNVector3(Float(camX), 360, Float(camZ + 215))
        camNode.look(at: SCNVector3(Float(camX), 0, Float(camZ)))

        for f in 0..<TowerMap.nF { floorRoots[f].isHidden = f != focus }
        // doors
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
        for (i, a) in e.actors.enumerated() where i < actorRoots.count {
            let r = actorRoots[i]
            let seen = a.alive && a.f == focus && (a.team == 0 || tgt.id == a.id || (hypot(a.p.x - tgt.p.x, a.p.y - tgt.p.y) < 620 && map.los(focus, tgt.p, a.p)))
            r.isHidden = !seen
            if !seen { continue }
            seenIdx.append(i)
            let bob = abs(sin(a.walk)) * 1.6
            r.position = SCNVector3(Float(a.p.x), Float(bob), Float(a.p.y))
            r.eulerAngles = SCNVector3(0, Float(-a.ang), 0)
            let col: UIColor
            if a.isMe { col = twCol(0.9, 1.0, 0.3) }
            else if a.team == 0 { col = twCol(0.2, 0.85, 0.95) }
            else {
                let hue = CGFloat(a.team) / CGFloat(TowerEngine.teams)
                col = UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1)
            }
            actorBody[i].geometry?.firstMaterial?.diffuse.contents = a.hurtT > 0 ? UIColor.white : col
            actorFlash[i].isHidden = a.flash < 0.4
        }
        // loot
        var used = 0
        let t = CACurrentMediaTime()
        for l in e.loot where l.alive && l.f == focus {
            if used >= lootPool.count { break }
            if abs(l.p.x - camX) > 520 || abs(l.p.y - camZ) > 330 { continue }
            let n = lootPool[used]
            used += 1
            n.geometry = lootGeometry(l.kind * 10 + l.rar, l.kind, l.rar)
            n.position = SCNVector3(Float(l.p.x), Float(5 + sin(t * 3 + Double(l.p.x)) * 1.5), Float(l.p.y))
            n.eulerAngles = SCNVector3(0, Float(t + Double(l.p.y)), 0)
            n.isHidden = false
        }
        for i in used..<lootPool.count { lootPool[i].isHidden = true }
        // tracers
        var ti = 0
        for tr in e.tracers where tr.f == focus {
            if ti >= tracerPool.count { break }
            let n = tracerPool[ti]
            ti += 1
            let dx = tr.b.x - tr.a.x, dy = tr.b.y - tr.a.y
            let len = max(1, hypot(dx, dy))
            n.scale = SCNVector3(Float(len), 1, 1)
            n.position = SCNVector3(Float((tr.a.x + tr.b.x) / 2), 24, Float((tr.a.y + tr.b.y) / 2))
            n.eulerAngles = SCNVector3(0, Float(-atan2(dy, dx)), 0)
            n.geometry?.firstMaterial?.diffuse.contents = tr.hot ? twCol(0.8, 0.6, 1.0) : twCol(1, 0.9, 0.5)
            n.geometry?.firstMaterial?.emission.contents = tr.hot ? twCol(0.8, 0.6, 1.0) : twCol(1, 0.9, 0.5)
            n.isHidden = false
        }
        for i in ti..<tracerPool.count { tracerPool[i].isHidden = true }
        // gas
        let gas = e.gassed.contains(focus)
        gasNode.childNodes.first?.isHidden = !gas
        warnNode.childNodes.first?.isHidden = !(e.warnFloor == focus && Int(t * 3) % 2 == 0)
    }
}
