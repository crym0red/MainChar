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
    let vm = TwViewModel()
    var camX: CGFloat = 0
    var camZ: CGFloat = 0
    var started = false
    let floorRoot = [SCNNode(), SCNNode()]
    var focusFloor = 0
    var camFloor = 0
    var fpMode = false
    var fpFwd = CGPoint(x: 1, y: 0)
    var fpEye = CGPoint.zero
    var ceilNodes: [SCNNode] = []

    var roots: [SCNNode] = []
    var bodies: [SCNNode] = []
    var heads: [SCNNode] = []
    var guns: [SCNNode] = []
    var flashes: [SCNNode] = []
    var headKey: [String] = []
    var shirts: [SCNMaterial] = []
    var faceMats: [SCNMaterial] = []
    var preset = 1
    var lookOn = false
    var yaw: CGFloat = 0
    var pitch: CGFloat = 1.0
    var dist: CGFloat = 430
    var legLs: [SCNNode] = []
    var legRs: [SCNNode] = []
    var gunVars: [[SCNNode]] = []
    var gunShown: [Int] = []
    var walkPh: [CGFloat] = []
    var lastPos: [CGPoint] = []
    var bulletPool: [SCNNode] = []
    var nadePool: [SCNNode] = []
    var boomPool: [SCNNode] = []
    var smokePool: [SCNNode] = []
    var packNodes: [SCNNode] = []
    let bombNode = SCNNode()

    private var texCache: [String: UIImage] = [:]
    private let props = TwProps()
    private var doorLeaves: [[SCNNode]] = []
    private var doorHoriz: [Bool] = []
    private var doorAngShown: [Float] = []
    private var sunNode: SCNNode? = nil
    private var lastT = CACurrentMediaTime()
    private var fpsEMA: CGFloat = 60
    private var lowT: CGFloat = 0
    private var qual = 2

    // MARK: textures

    private func makeTex(_ key: String, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        if let t = texCache[key] { return t }
        let s: CGFloat = 128
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: fmt).image { c in
            draw(c.cgContext, s)
            grimeOverlay(c.cgContext, s, key)
        }
        texCache[key] = img
        return img
    }

    private func grimeOverlay(_ g: CGContext, _ s: CGFloat, _ key: String) {
        var r = LCG(s: UInt64(abs(key.hashValue) % 100000) + 17)
        for _ in 0..<9 {
            let w = 18 + r.next() * 60, h = 12 + r.next() * 44
            g.setFillColor(UIColor.black.withAlphaComponent(0.03 + r.next() * 0.05).cgColor)
            g.fillEllipse(in: CGRect(x: r.next() * s - w / 2, y: r.next() * s - h / 2, width: w, height: h))
        }
        for _ in 0..<260 {
            g.setFillColor(UIColor.black.withAlphaComponent(0.08 + r.next() * 0.14).cgColor)
            let d = 0.5 + r.next() * 0.9
            g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: d, height: d))
        }
        for _ in 0..<90 {
            g.setFillColor(UIColor.white.withAlphaComponent(0.05 + r.next() * 0.09).cgColor)
            g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 0.6, height: 0.6))
        }
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

    private func sandBlockTex() -> UIImage {
        makeTex("sandblock") { g, s in
            UIColor(red: 0.55, green: 0.43, blue: 0.29, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 41)
            for row in 0..<6 {
                let y = CGFloat(row) * s / 6
                var x: CGFloat = -r.next() * 30
                while x < s {
                    let w = 34 + r.next() * 34
                    let t = 0.88 + r.next() * 0.24
                    UIColor(red: 0.84 * t, green: 0.70 * t, blue: 0.50 * t, alpha: 1).setFill()
                    g.fill(CGRect(x: x + 1.5, y: y + 1.5, width: w - 3, height: s / 6 - 3))
                    UIColor.black.withAlphaComponent(0.06 + r.next() * 0.08).setFill()
                    g.fill(CGRect(x: x + 1.5, y: y + s / 6 - 9, width: w - 3, height: 6))
                    x += w
                }
            }
            for _ in 0..<900 {
                (r.next() > 0.5 ? UIColor.white : UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1)).withAlphaComponent(0.06).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 2 + r.next() * 3, height: 2))
            }
            UIColor(red: 0.25, green: 0.17, blue: 0.1, alpha: 0.35).setStroke()
            for _ in 0..<5 {
                let p = UIBezierPath(); var cx = r.next() * s, cy = r.next() * s
                p.move(to: CGPoint(x: cx, y: cy))
                for _ in 0..<4 { cx += (r.next() - 0.5) * 14; cy += r.next() * 12; p.addLine(to: CGPoint(x: cx, y: cy)) }
                p.lineWidth = 1; p.stroke()
            }
        }
    }

    private func plasterTex() -> UIImage {
        makeTex("sandplaster") { g, s in
            UIColor(red: 0.82, green: 0.69, blue: 0.5, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 77)
            for _ in 0..<40 {
                UIColor(red: 0.6 + r.next() * 0.3, green: 0.5 + r.next() * 0.2, blue: 0.35, alpha: 0.1).setFill()
                g.fillEllipse(in: CGRect(x: r.next() * s, y: r.next() * s, width: 20 + r.next() * 50, height: 20 + r.next() * 50))
            }
            for _ in 0..<1200 {
                (r.next() > 0.5 ? UIColor.white : UIColor.black).withAlphaComponent(0.06).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 2, height: 2))
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
            m.normal.contents = i
            m.normal.intensity = 0.7
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = SCNMatrix4MakeScale(Float(sx), Float(sy), 1)
        } else {
            m.diffuse.contents = color
        }
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: img == nil ? 0.15 : 0.22, alpha: 1)
        m.shininess = 0.3
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
        let skyImg = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 256)).image { c in
            let cs = CGColorSpaceCreateDeviceRGB()
            if let gr = CGGradient(colorsSpace: cs, colors: [UIColor(red: 0.25, green: 0.52, blue: 0.9, alpha: 1).cgColor, UIColor(red: 0.62, green: 0.8, blue: 0.96, alpha: 1).cgColor, UIColor(red: 0.95, green: 0.88, blue: 0.72, alpha: 1).cgColor] as CFArray, locations: [0, 0.6, 1]) {
                c.cgContext.drawLinearGradient(gr, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
            }
        }
        scene.background.contents = skyImg
        scene.fogColor = UIColor(red: 0.9, green: 0.82, blue: 0.66, alpha: 1)
        scene.fogStartDistance = 900
        scene.fogEndDistance = 3200
        scene.fogDensityExponent = 1.4
        let root = scene.rootNode
        floorRoot[1].position = SCNVector3(-Float(TMap.off), 0, 0)
        floorRoot[1].isHidden = true
        root.addChildNode(floorRoot[0])
        root.addChildNode(floorRoot[1])
        func fr(_ x: CGFloat) -> SCNNode { floorRoot[x >= TMap.off ? 1 : 0] }

        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 640
        amb.light?.color = UIColor(red: 0.78, green: 0.8, blue: 0.9, alpha: 1)
        root.addChildNode(amb)

        let sun = SCNNode()
        let sl = SCNLight()
        sl.type = .directional
        sl.intensity = 1000
        sl.color = UIColor(red: 1, green: 0.93, blue: 0.78, alpha: 1)
        sl.castsShadow = true
        sl.shadowMode = .deferred
        sl.shadowRadius = 5
        sl.shadowSampleCount = 8
        sl.shadowColor = UIColor(white: 0, alpha: 0.72)
        sl.maximumShadowDistance = 1200
        sun.light = sl
        sun.position = SCNVector3(-300, 650, -300)
        root.addChildNode(sun)
        sun.look(at: SCNVector3(0, 0, 0))
        sunNode = sun
        let fill = SCNNode()
        let fl = SCNLight()
        fl.type = .directional
        fl.intensity = 420
        fl.color = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1)
        fill.light = fl
        fill.position = SCNVector3(400, 500, 500)
        root.addChildNode(fill)
        fill.look(at: SCNVector3(0, 0, 0))

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
        cam.wantsHDR = true
        cam.bloomIntensity = 0.7
        cam.bloomThreshold = 0.75
        cam.bloomBlurRadius = 6
        cam.vignettingIntensity = 0.7
        cam.vignettingPower = 1.2
        cam.screenSpaceAmbientOcclusionIntensity = 0.9
        cam.screenSpaceAmbientOcclusionRadius = 10
        cam.saturation = 1.12
        cam.contrast = 0.15
        camNode.camera = cam
        root.addChildNode(camNode)
        camNode.addChildNode(vm.root)

        // ceilings (only shown in first person)
        for i in 0..<2 {
            let pl = SCNPlane(width: 1900, height: 1300)
            let cm = SCNMaterial()
            cm.diffuse.contents = UIColor(red: 0.16, green: 0.17, blue: 0.2, alpha: 1)
            cm.emission.contents = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
            cm.isDoubleSided = true
            pl.firstMaterial = cm
            let cn = SCNNode(geometry: pl)
            cn.position = SCNVector3(950, Float(TMap.wallH) + 0.5, 600)
            cn.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            cn.castsShadow = false
            cn.isHidden = true
            floorRoot[i].addChildNode(cn)
            ceilNodes.append(cn)
        }

        // floors
        let floorCols: [(CGFloat, CGFloat, CGFloat)] = [(0.72, 0.59, 0.41), (0.7, 0.6, 0.45), (0.5, 0.26, 0.2), (0.72, 0.5, 0.34), (0.4, 0.27, 0.17), (0.66, 0.56, 0.42)]
        for rm in TMap.rooms {
            let b = floorCols[rm.mat]
            let img: UIImage
            switch rm.mat {
            case 0: img = noiseTex(b, "sand0", dots: 2600, grid: false)
            case 4: img = woodTex(b, "wood4")
            case 3, 5: img = tileTex(b, "tile\(rm.mat)")
            case 1: img = noiseTex(b, "slab", dots: 1800, grid: false)
            default: img = noiseTex(b, "carpet", dots: 1400, grid: false)
            }
            let tile: CGFloat = rm.mat == 1 ? 140 : (rm.mat == 3 || rm.mat == 5 ? 112 : 128)
            let top = mat(img, sx: rm.r.width / tile, sy: rm.r.height / tile)
            let side = mat(nil, color: ui(b, 0.5))
            let n = box(rm.r, h: 1, y0: -1, mats: [side, side, side, side, top, side])
            fr(rm.r.midX).addChildNode(n)
        }
        // rugs
        for rg in TMap.rugs {
            let c = UIColor(cgColor: UIColor(rg.1).cgColor)
            let n = solid(rg.0, h: 1.6, color: c, top: c)
            n.castsShadow = false
            fr(rg.0.midX).addChildNode(n)
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
            fr(r.midX).addChildNode(n)
        }
        // doors
        let doorTop = UIColor(red: 0.62, green: 0.5, blue: 0.32, alpha: 1)
        let frame = UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1)
        _ = doorTop
        for d in TMap.doors {
            let leaves = props.door(d)
            for lf in leaves { fr(d.midX).addChildNode(lf) }
            doorLeaves.append(leaves)
            doorHoriz.append(d.width > d.height)
            doorAngShown.append(-9)
            let horiz = d.width > d.height
            let p1 = horiz ? CGRect(x: d.minX - 3, y: d.midY - 6, width: 8, height: 12) : CGRect(x: d.midX - 6, y: d.minY - 3, width: 12, height: 8)
            let p2 = horiz ? CGRect(x: d.maxX - 5, y: d.midY - 6, width: 8, height: 12) : CGRect(x: d.midX - 6, y: d.maxY - 5, width: 12, height: 8)
            fr(d.midX).addChildNode(solid(p1, h: TMap.wallH, color: frame, top: frame, chamfer: 1.5))
            fr(d.midX).addChildNode(solid(p2, h: TMap.wallH, color: frame, top: frame, chamfer: 1.5))
            let lin = horiz ? CGRect(x: d.minX, y: d.midY - 6, width: d.width, height: 12) : CGRect(x: d.midX - 6, y: d.minY, width: 12, height: d.height)
            fr(d.midX).addChildNode(solid(lin, h: 10, y0: 71, color: frame, top: frame, chamfer: 1))
        }
        // walls
        let brick = sandBlockTex()
        let concrete = plasterTex()
        let wood = woodTex((0.5, 0.36, 0.22), "wallwood")
        let wallH = TMap.wallH
        let cap = mat(nil, color: UIColor(red: 0.74, green: 0.62, blue: 0.44, alpha: 1))
        for (k, o) in TMap.walls.enumerated() {
            let mt = TMap.wallMats[k]
            let front: SCNMaterial
            let side: SCNMaterial
            switch mt {
            case .brick:
                front = mat(brick, sx: o.width / 128, sy: wallH / 128)
                side = mat(brick, sx: o.height / 128, sy: wallH / 128)
            case .concrete:
                front = mat(concrete, sx: o.width / 160, sy: wallH / 160)
                side = mat(concrete, sx: o.height / 160, sy: wallH / 160)
            case .wood:
                front = mat(wood, sx: o.width / 128, sy: wallH / 128)
                side = mat(wood, sx: o.height / 128, sy: wallH / 128)
            case .glass:
                front = mat(nil, color: UIColor(red: 0.55, green: 0.82, blue: 0.95, alpha: 1))
                front.transparency = 0.32
                front.isDoubleSided = true
                front.writesToDepthBuffer = false
                side = front
            }
            let n = box(o, h: wallH, mats: [front, side, front, side, mt == .glass ? front : cap, front])
            if mt == .glass { n.castsShadow = false; n.renderingOrder = 3 }
            fr(o.midX).addChildNode(n)
        }
        // rooftops: domes, water tanks, masts
        do {
            var lg = LCG(s: 303)
            let roofs = SCNNode()
            let domeM = mat(plasterTex(), color: UIColor(white: 1, alpha: 1), sx: 2, sy: 2)
            domeM.diffuse.contents = UIColor(red: 0.95, green: 0.92, blue: 0.82, alpha: 1)
            let tankM = mat(nil, color: UIColor(red: 0.45, green: 0.5, blue: 0.55, alpha: 1))
            let metalM = mat(nil, color: UIColor(white: 0.25, alpha: 1))
            var n = 0
            for o in TMap.walls where o.width >= 150 && o.height >= 150 {
                n += 1
                let cx = o.midX + (lg.next() - 0.5) * (o.width - 100) * 0.4
                let cz = o.midY + (lg.next() - 0.5) * (o.height - 100) * 0.4
                let rad = min(110, min(o.width, o.height) * 0.3)
                if n % 3 != 0 {
                    let d = SCNNode(geometry: SCNSphere(radius: rad))
                    d.geometry?.firstMaterial = domeM
                    (d.geometry as? SCNSphere)?.segmentCount = 28
                    d.scale = SCNVector3(1, 0.62, 1)
                    d.position = SCNVector3(Float(cx), Float(TMap.wallH), Float(cz))
                    roofs.addChildNode(d)
                    let drum = SCNNode(geometry: SCNCylinder(radius: rad * 1.02, height: 8))
                    drum.geometry?.firstMaterial = domeM
                    drum.position = SCNVector3(Float(cx), Float(TMap.wallH + 3), Float(cz))
                    roofs.addChildNode(drum)
                    let fin = SCNNode(geometry: SCNCylinder(radius: 1.6, height: 22))
                    fin.geometry?.firstMaterial = metalM
                    fin.position = SCNVector3(Float(cx), Float(TMap.wallH + rad * 0.62 + 8), Float(cz))
                    roofs.addChildNode(fin)
                } else {
                    let tk = SCNNode(geometry: SCNCylinder(radius: 22, height: 36))
                    tk.geometry?.firstMaterial = tankM
                    tk.position = SCNVector3(Float(cx), Float(TMap.wallH + 18), Float(cz))
                    roofs.addChildNode(tk)
                    for lx in [-14, 14] as [CGFloat] {
                        let lgp = SCNNode(geometry: SCNBox(width: 3, height: 10, length: 3, chamferRadius: 0))
                        lgp.geometry?.firstMaterial = metalM
                        lgp.position = SCNVector3(Float(cx + lx), Float(TMap.wallH + 4), Float(cz))
                        roofs.addChildNode(lgp)
                    }
                    let ms = SCNNode(geometry: SCNCylinder(radius: 1, height: 50))
                    ms.geometry?.firstMaterial = metalM
                    ms.position = SCNVector3(Float(cx + 50), Float(TMap.wallH + 25), Float(cz + 20))
                    roofs.addChildNode(ms)
                }
                // battlements along the roof edge
                let cap = mat(nil, color: UIColor(red: 0.78, green: 0.66, blue: 0.47, alpha: 1))
                var bx = o.minX + 20
                while bx < o.maxX - 20 {
                    for zz in [o.minY + 6, o.maxY - 6] {
                        let b = SCNNode(geometry: SCNBox(width: 14, height: 10, length: 10, chamferRadius: 1))
                        b.geometry?.firstMaterial = cap
                        b.position = SCNVector3(Float(bx), Float(TMap.wallH + 5), Float(zz))
                        roofs.addChildNode(b)
                    }
                    bx += 40
                }
            }
            floorRoot[0].addChildNode(roofs.flattenedClone())
        }
        // stairs
        for fl in 0..<2 {
            for i in TMap.stairs.indices {
                let r = TMap.stairRect(i, floor: fl)
                if fl == 0 {
                    let steps = 7
                    let sh = r.height / CGFloat(steps)
                    for k in 0..<steps {
                        let sr = CGRect(x: r.minX, y: r.maxY - CGFloat(k + 1) * sh, width: r.width, height: sh + 0.5)
                        let c = UIColor(red: 0.5 + 0.03 * CGFloat(k), green: 0.42 + 0.03 * CGFloat(k), blue: 0.3, alpha: 1)
                        let n = solid(sr, h: 3 + CGFloat(k) * 4.5, color: c, top: c)
                        n.castsShadow = false
                        fr(r.midX).addChildNode(n)
                    }
                } else {
                    let hole = solid(r, h: 1.2, y0: 0.4, color: UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1), top: UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1))
                    hole.castsShadow = false
                    fr(r.midX).addChildNode(hole)
                }
                let rail = UIColor(red: 0.95, green: 0.82, blue: 0.2, alpha: 1)
                let glow = UIColor(red: 0.5, green: 0.42, blue: 0.08, alpha: 1)
                let l = solid(CGRect(x: r.minX - 3, y: r.minY, width: 4, height: r.height), h: 22, color: rail, top: rail, emission: glow)
                let rr = solid(CGRect(x: r.maxX - 1, y: r.minY, width: 4, height: r.height), h: 22, color: rail, top: rail, emission: glow)
                l.castsShadow = false; rr.castsShadow = false
                fr(r.midX).addChildNode(l)
                fr(r.midX).addChildNode(rr)
            }
        }
        // props
        let pr0 = SCNNode(), pr1 = SCNNode()
        for pr in TMap.props { (pr.r.midX >= TMap.off ? pr1 : pr0).addChildNode(props.build(pr.k, pr.r)) }
        floorRoot[0].addChildNode(pr0.flattenedClone())
        floorRoot[1].addChildNode(pr1.flattenedClone())
        let rooms0 = TMap.rooms.filter { $0.r.midX < TMap.off }.map { $0.r }
        let rooms1 = TMap.rooms.filter { $0.r.midX >= TMap.off }.map { $0.r }
        floorRoot[0].addChildNode(props.decals(in: rooms0, avoid: TMap.baseSolid, seed: 1).flattenedClone())
        floorRoot[1].addChildNode(props.decals(in: rooms1, avoid: TMap.baseSolid, seed: 2).flattenedClone())
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
            fr(k.pos.x).addChildNode(g)
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
        let skinTints: [UIColor] = [UIColor(red: 0.9, green: 0.72, blue: 0.58, alpha: 1), UIColor(red: 0.65, green: 0.45, blue: 0.32, alpha: 1), UIColor(red: 0.45, green: 0.3, blue: 0.22, alpha: 1), UIColor(red: 0.95, green: 0.8, blue: 0.68, alpha: 1)]
        for p in e.players {
            let rt = SCNNode()
            let col: UIColor = p.isPlayer ? UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1) : (p.team == e.me.team ? UIColor(red: 0.25, green: 0.6, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
            var shirtC = p.isPlayer ? col : (p.team == e.me.team ? UIColor(red: 0.2, green: 0.38, blue: 0.7, alpha: 1) : UIColor(red: 0.72, green: 0.3, blue: 0.14, alpha: 1))
            var tint: UIColor? = nil
            if p.isPlayer {
                let oc = BRMeta.outfitColor()
                shirtC = UIColor(red: oc.0, green: oc.1, blue: oc.2, alpha: 1)
                if let sk = BRMeta.skinTint() { tint = UIColor(sk) }
            }
            let sol = TwRig.soldier(shirt: shirtC, skin: skinTints[p.id % skinTints.count], tint: tint)
            let body = sol.root
            let gun = sol.holder
            let fl = sol.flash
            shirts.append(sol.shirt)
            legLs.append(sol.legL)
            legRs.append(sol.legR)
            gunVars.append(sol.variants)
            gunShown.append(0)
            walkPh.append(0)
            lastPos.append(.zero)
            let head = sol.face
            faceMats.append(sol.faceMat)
            sol.faceMat.diffuse.contents = ringed(nil, emoji: p.emoji, color: col)
            rt.addChildNode(body)
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
        if TMap.floorOf(p) != focusFloor { return nil }
        if fpMode {
            let dx = sx(p) - fpEye.x, dz = p.y - fpEye.y
            if dx * fpFwd.x + dz * fpFwd.y <= 2 { return nil }
        }
        let v = view.projectPoint(SCNVector3(Float(sx(p)), Float(h), Float(p.y)))
        if v.z > 1 || v.z < 0 { return nil }
        return CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
    }

    func sx(_ p: CGPoint) -> CGFloat { p.x >= TMap.off ? p.x - TMap.off : p.x }

    func sync(_ e: TacticalEngine) {
        guard !e.players.isEmpty, roots.count == e.players.count else { return }
        let focus: TPlayer = e.me.alive ? e.me : (e.players.first { $0.team == e.me.team && $0.alive } ?? e.me)
        focusFloor = TMap.floorOf(focus.pos)
        floorRoot[0].isHidden = focusFloor != 0
        floorRoot[1].isHidden = focusFloor != 1
        for i in doorLeaves.indices where i < TMap.doorOpen.count {
            let ang = Float(TMap.doorOpen[i]) * 1.65
            if abs(doorAngShown[i] - ang) > 0.004 {
                doorAngShown[i] = ang
                for (k, lf) in doorLeaves[i].enumerated() {
                    let sg: Float = k == 0 ? 1 : -1
                    lf.eulerAngles = SCNVector3(0, (doorHoriz[i] ? -ang : ang) * sg, 0)
                }
            }
        }
        let tnow = CACurrentMediaTime()
        let fdt = CGFloat(min(0.1, max(0.001, tnow - lastT)))
        lastT = tnow
        fpsEMA = fpsEMA * 0.95 + (1 / fdt) * 0.05
        if fpsEMA < 42 { lowT += fdt } else { lowT = max(0, lowT - fdt) }
        if lowT > 2.5 && qual > 0 {
            qual -= 1
            lowT = 0
            fpsEMA = 60
            if qual <= 1 { camNode.camera?.screenSpaceAmbientOcclusionIntensity = 0 }
            if qual <= 0 {
                camNode.camera?.wantsHDR = false
                camNode.camera?.bloomIntensity = 0
                sunNode?.light?.shadowSampleCount = 2
            }
        }
        let fx = sx(focus.pos)
        if !started || camFloor != focusFloor { camX = fx; camZ = focus.pos.y; started = true; camFloor = focusFloor }
        camX += (fx - camX) * 0.2
        camZ += (focus.pos.y - camZ) * 0.2
        let sh = e.shake
        let jx: CGFloat = sh > 0 ? CGFloat.random(in: -sh...sh) * 0.6 : 0
        let jz: CGFloat = sh > 0 ? CGFloat.random(in: -sh...sh) * 0.6 : 0
        for c in ceilNodes { c.isHidden = true }
        if fpMode {
            let ex = fx, ez = focus.pos.y
            let dxv = cos(focus.aim), dzv = sin(focus.aim)
            let eh = CGFloat(TMap.eyeH) + CGFloat(sin(Double(min(1, e.jumpT / 0.55)) * Double.pi)) * 22 + (sh > 0 ? CGFloat.random(in: -sh...sh) * 0.25 : 0)
            fpFwd = CGPoint(x: dxv, y: dzv)
            fpEye = CGPoint(x: ex, y: ez)
            camNode.camera?.zNear = 0.6
            vm.show(TWeapons.rig(focus.gun))
            vm.root.isHidden = !(focus.alive && !e.scoped)
            let mvg = Float(min(1, hypot(e.move.dx, e.move.dy)))
            let tt = Float(e.time)
            let rl = Float(min(1, focus.reloadT * 2.5))
            let kk = Float(e.kick)
            vm.root.position = SCNVector3(sin(tt * 8) * 0.22 * mvg, -abs(cos(tt * 8)) * 0.18 * mvg - rl * 3.5, kk * 0.02)
            vm.root.eulerAngles = SCNVector3(kk * 0.004 - rl * 0.6, 0, 0)
            vm.flash(focus.flash > 0)
            camNode.camera?.fieldOfView += ((e.scoped ? 26 : 62) - (camNode.camera?.fieldOfView ?? 62)) * 0.3
            camNode.position = SCNVector3(Float(ex + jx * 0.3), Float(eh), Float(ez + jz * 0.3))
            camNode.look(at: SCNVector3(Float(ex + dxv * 100), Float(eh + e.kick + tan(e.pitch) * 100), Float(ez + dzv * 100)))
        } else {
            vm.root.isHidden = true
            camNode.camera?.zNear = 10
            camNode.camera?.fieldOfView = 52
            let pr: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(300, 170, 60, 30), (400, 250, 70, 40), (520, 70, 70, 50), (640, 400, 90, 60)]
            let c = pr[max(0, min(3, preset))]
            // always the same top-down pitch; yaw just spins the view around the player
            let lx = camX + cos(focus.aim) * c.2, lz = camZ + sin(focus.aim) * c.3
            camNode.position = SCNVector3(Float(lx + jx + c.1 * sin(yaw)), Float(c.0), Float(lz + jz + c.1 * cos(yaw)))
            camNode.look(at: SCNVector3(Float(lx), 0, Float(lz)))
        }

        for (i, p) in e.players.enumerated() {
            let rt = roots[i]
            let show = (p.team == e.me.team || p.spotted || (!p.alive && p.seenEver)) && TMap.floorOf(p.pos) == focusFloor
            rt.isHidden = !show || (fpMode && p.id == focus.id)
            if !show { continue }
            let ks: Float = fpMode ? 1.18 : 1
            rt.scale = SCNVector3(ks, ks * (p.crouch ? 0.74 : 1), ks)
            rt.position = SCNVector3(Float(sx(p.pos)), 0, Float(p.pos.y))
            rt.eulerAngles = SCNVector3(0, Float(-p.aim), 0)
            heads[i].eulerAngles = SCNVector3(0, Float(p.aim), 0)
            if p.alive {
                bodies[i].eulerAngles = SCNVector3(0, 0, 0)
                bodies[i].position = SCNVector3(0, 0, 0)
                heads[i].isHidden = false
                guns[i].isHidden = false
                flashes[i].isHidden = !(p.flash > 0)
                shirts[i].emission.contents = p.hurt > 0 ? UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1) : UIColor.black
                let dpx = p.pos.x - lastPos[i].x, dpy = p.pos.y - lastPos[i].y
                let moved = hypot(dpx, dpy)
                if moved < 40 { walkPh[i] += moved * 0.12 }
                lastPos[i] = p.pos
                let sw = Float(sin(walkPh[i])) * 0.7
                legLs[i].eulerAngles = SCNVector3(0, 0, sw)
                legRs[i].eulerAngles = SCNVector3(0, 0, -sw)
                let gi = TwRig.gunIdx(p.gun)
                if gunShown[i] != gi {
                    for (k, g) in gunVars[i].enumerated() { g.isHidden = k != gi }
                    flashes[i].position = SCNVector3(TwRig.flashX[gi], 1, 0)
                    gunShown[i] = gi
                }
            } else {
                bodies[i].eulerAngles = SCNVector3(0, 0, Float.pi / 2)
                bodies[i].position = SCNVector3(0, 8, 0)
                heads[i].isHidden = true
                flashes[i].isHidden = true
                shirts[i].emission.contents = UIColor.black
            }
            let img = e.sprites[p.handle]
            let key = p.handle + (img == nil ? "-n" : "-y")
            if headKey[i] != key {
                headKey[i] = key
                let col: UIColor = p.isPlayer ? UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1) : (p.team == e.me.team ? UIColor(red: 0.25, green: 0.6, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
                faceMats[i].diffuse.contents = ringed(img, emoji: p.emoji, color: col)
            }
        }
        // bullets
        for (i, node) in bulletPool.enumerated() {
            if i < e.bullets.count, TMap.floorOf(e.bullets[i].pos) == focusFloor {
                let b = e.bullets[i]
                node.isHidden = false
                node.position = SCNVector3(Float(sx(b.pos)), 30, Float(b.pos.y))
                node.eulerAngles = SCNVector3(0, Float(-atan2(b.vel.dy, b.vel.dx)), 0)
                let c: UIColor = b.team == e.me.team ? UIColor(red: 0.7, green: 0.9, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1)
                node.geometry?.firstMaterial?.emission.contents = c
                node.geometry?.firstMaterial?.diffuse.contents = c
            } else { node.isHidden = true }
        }
        for (i, node) in nadePool.enumerated() {
            if i < e.nades.count, TMap.floorOf(e.nades[i].pos) == focusFloor {
                let g = e.nades[i]
                node.isHidden = false
                node.position = SCNVector3(Float(sx(g.pos)), 8, Float(g.pos.y))
                node.geometry?.firstMaterial?.diffuse.contents = g.kind == 1 ? UIColor(white: 0.75, alpha: 1) : UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
            } else { node.isHidden = true }
        }
        for (i, node) in boomPool.enumerated() {
            if i < e.booms.count, TMap.floorOf(e.booms[i].pos) == focusFloor {
                let b = e.booms[i]
                let total: CGFloat = b.r > 150 ? 0.8 : 0.45
                let k = min(1, max(0, 1 - b.life / total))
                let rr = b.r * (0.35 + k * 0.7)
                node.isHidden = false
                node.position = SCNVector3(Float(sx(b.pos)), 20, Float(b.pos.y))
                node.scale = SCNVector3(Float(rr), Float(rr * 0.6), Float(rr))
                node.opacity = CGFloat(0.65 * (1 - k))
            } else { node.isHidden = true }
        }
        for (i, node) in smokePool.enumerated() {
            if i < e.smokeClouds.count, TMap.floorOf(e.smokeClouds[i].pos) == focusFloor {
                let s = e.smokeClouds[i]
                node.isHidden = false
                node.position = SCNVector3(Float(sx(s.pos)), 0, Float(s.pos.y))
                let sc = Float(s.r / 85)
                node.scale = SCNVector3(sc, sc, sc)
                node.opacity = min(1, s.life / 1.5) * 0.93
                node.eulerAngles = SCNVector3(0, Float(e.time * 0.2), 0)
            } else { node.isHidden = true }
        }
        for (i, node) in packNodes.enumerated() where i < e.packs.count {
            node.isHidden = e.packs[i].taken
        }
        let bombHere = e.planted && TMap.floorOf(e.bombPos) == focusFloor
        bombNode.isHidden = !bombHere
        if bombHere {
            bombNode.position = SCNVector3(Float(sx(e.bombPos)), 0, Float(e.bombPos.y))
        }
    }
}

// MARK: - Overlay drawn above the 3D view

extension TacticalEngine {
    func drawOverlay3D(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard let pr = project else { return }
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        // fog of war (top-down view only)
        let vp = focus.pos
        var poly = Path()
        var ok = true
        let n = 120
        for i in 0...(fp ? 0 : n) {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let d = TMap.rayDist(vp, a, 700)
            let hit = d < 699
            guard let pt = pr(CGPoint(x: vp.x + cos(a) * d, y: vp.y + sin(a) * d), hit ? TMap.wallH - 8 : 0) else { ok = false; break }
            if i == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
        }
        if ok && !fp {
            poly.closeSubpath()
            var dark = Path(CGRect(x: -60, y: -60, width: size.width + 120, height: size.height + 120))
            dark.addPath(poly)
            ctx.fill(dark, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
        }
        // stair labels
        let ff = TMap.floorOf(focus.pos)
        for i in TMap.stairs.indices {
            let r = TMap.stairRect(i, floor: ff)
            if let pt = pr(CGPoint(x: r.midX, y: r.midY), 56) {
                ctx.draw(Text(ff == 0 ? "UP" : "DOWN").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(red: 1, green: 0.88, blue: 0.25)), at: pt)
            }
        }
        // lane callouts
        for rm in TMap.rooms {
            let dd = hypot(rm.r.midX - focus.pos.x, rm.r.midY - focus.pos.y)
            if fp && dd > 900 { continue }
            guard let pt = pr(CGPoint(x: rm.r.midX, y: rm.r.midY), fp ? 74 : 4) else { continue }
            let al = fp ? Double(max(0.15, min(0.7, 1.1 - dd / 900))) : 0.5
            ctx.draw(Text(rm.name.uppercased()).font(.system(size: fp ? 14 : 11, weight: .heavy)).foregroundColor(Color(red: 1, green: 0.93, blue: 0.7).opacity(al)), at: pt)
        }
        // name tags
        for p in players where p.alive && (p.team == me.team || (p.spotted && !fp)) {
            if fp && (p.isPlayer || hypot(p.pos.x - focus.pos.x, p.pos.y - focus.pos.y) > 420) { continue }
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
        if autoTarget >= 0, let tp = players.first(where: { $0.id == autoTarget }), tp.alive, let pt = pr(tp.pos, 30) {
            let r: CGFloat = 26 + 3 * CGFloat(sin(Double(time) * 8))
            ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 1, green: 0.3, blue: 0.3).opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            var cx = Path()
            cx.move(to: CGPoint(x: pt.x - 8, y: pt.y)); cx.addLine(to: CGPoint(x: pt.x + 8, y: pt.y))
            cx.move(to: CGPoint(x: pt.x, y: pt.y - 8)); cx.addLine(to: CGPoint(x: pt.x, y: pt.y + 8))
            ctx.stroke(cx, with: .color(Color(red: 1, green: 0.3, blue: 0.3)), lineWidth: 1.5)
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
        let vg = Gradient(colors: [Color.clear, Color.black.opacity(fp ? 0.18 : 0.5)])
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(vg, center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: min(size.width, size.height) * 0.45, endRadius: max(size.width, size.height) * 0.72))
        if fp {
            var inSmoke: CGFloat = 0
            for sm in smokeClouds where hypot(sm.pos.x - focus.pos.x, sm.pos.y - focus.pos.y) < sm.r * 0.8 {
                inSmoke = max(inSmoke, min(1, sm.life / 1.5))
            }
            if inSmoke > 0 {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.72).opacity(0.92 * Double(inSmoke))))
            }
            let cx = size.width / 2, hz = size.height / 2
            var ch = Path()
            let gap: CGFloat = 5 + recoil * 22 + (moving ? 9 : 0) + (me.crouch ? -2 : 0)
            let ln: CGFloat = 9
            ch.move(to: CGPoint(x: cx - gap - ln, y: hz)); ch.addLine(to: CGPoint(x: cx - gap, y: hz))
            ch.move(to: CGPoint(x: cx + gap, y: hz)); ch.addLine(to: CGPoint(x: cx + gap + ln, y: hz))
            ch.move(to: CGPoint(x: cx, y: hz - gap - ln)); ch.addLine(to: CGPoint(x: cx, y: hz - gap))
            ch.move(to: CGPoint(x: cx, y: hz + gap)); ch.addLine(to: CGPoint(x: cx, y: hz + gap + ln))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 1, y: hz - 1, width: 2, height: 2)), with: .color(.green.opacity(0.9)))
            ctx.stroke(ch, with: .color(Color(red: 0.4, green: 1, blue: 0.45).opacity(0.9)), lineWidth: 2)
            if hitT > 0 {
                var hm = Path()
                hm.move(to: CGPoint(x: cx - 9, y: hz - 9)); hm.addLine(to: CGPoint(x: cx + 9, y: hz + 9))
                hm.move(to: CGPoint(x: cx + 9, y: hz - 9)); hm.addLine(to: CGPoint(x: cx - 9, y: hz + 9))
                ctx.stroke(hm, with: .color(.red), lineWidth: 3)
            }
            if scoped && me.alive {
                let r = min(size.width, size.height) * 0.46
                var sc = Path(CGRect(origin: .zero, size: size))
                sc.addEllipse(in: CGRect(x: cx - r, y: hz - r, width: r * 2, height: r * 2))
                ctx.fill(sc, with: .color(.black), style: FillStyle(eoFill: true))
                var ln = Path()
                ln.move(to: CGPoint(x: cx - r, y: hz)); ln.addLine(to: CGPoint(x: cx + r, y: hz))
                ln.move(to: CGPoint(x: cx, y: hz - r)); ln.addLine(to: CGPoint(x: cx, y: hz + r))
                ctx.stroke(ln, with: .color(.black.opacity(0.9)), lineWidth: 1.5)
            }
            if me.blind > 0 {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(Double(min(1, me.blind * 1.2)))))
            }
        }
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
