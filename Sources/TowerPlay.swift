import SwiftUI

struct TowerPlay: View {
    var mapId: Int = 0
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var engine = TowerEngine(def: TowerMaps.all[0])
    @State private var scene: TowerScene? = nil
    @State private var ready = false
    @State private var collected = false
    @State private var lStart: CGPoint? = nil
    @State private var lKnob = CGPoint.zero
    @State private var rStart: CGPoint? = nil
    @State private var rKnob = CGPoint.zero
    @State private var lastT = Date()
    @State private var lookOn = false
    @State private var driver: TowerDriver? = nil
    @State private var lastDrag = CGSize.zero
    @State private var baseDist: CGFloat = 430

    private let lime = Color(red: 0.85, green: 0.93, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if ready, let sc = scene {
                TowerSceneView(bridge: sc).ignoresSafeArea()
                TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { _ in
                    Canvas { ctx, size in
                        drawOverlay(&ctx, size, sc)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                controls
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    ZStack {
                        if engine.killcam != nil { killCamHud } else { hud }
                        if engine.paused && !engine.over { pauseView }
                        if engine.over { overView }
                    }
                }
            }
        }
        .statusBarHidden(true)
        .onDisappear { driver?.stop() }
        .onAppear {
            OrientationLock.set(landscape: true)
            let e = TowerEngine(def: TowerMaps.all[max(0, min(TowerMaps.all.count - 1, mapId))])
            e.setup(name: game.s.persona.handle)
            engine = e
            let sc = TowerScene(map: e.map)
            sc.configure(e)
            scene = sc
            let d = TowerDriver(engine: e, scene: sc)
            d.start()
            driver = d
            ready = true
        }
    }

    // MARK: overlay

    private func drawOverlay(_ ctx: inout GraphicsContext, _ size: CGSize, _ sc: TowerScene) {
        guard !sc.vs.isEmpty else { return }
        let e = engine
        let f = sc.focus
        if let k = e.killcam {
            let v = sc.vs[k.killer]
            if let s = sc.project(v.p, 70) {
                ctx.draw(Text("KILLER  \(e.actors[k.killer].name)").font(.jk(11, .heavy)).foregroundColor(.red), at: CGPoint(x: s.x, y: s.y - 6))
            }
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.12)))
            return
        }
        // zone ring
        if e.circleOn && f == e.finalFloor {
            var path = Path()
            var first = true
            for k in 0...48 {
                let a = CGFloat(k) / 48 * 2 * .pi
                let p = CGPoint(x: e.circle.x + cos(a) * e.circleR, y: e.circle.y + sin(a) * e.circleR)
                if let s = sc.project(p, 2) {
                    if first { path.move(to: s); first = false } else { path.addLine(to: s) }
                }
            }
            ctx.stroke(path, with: .color(Color(red: 0.4, green: 1, blue: 0.3).opacity(0.9)), lineWidth: 3)
        }
        // labels on stairs / elevators
        if f < e.map.nF - 1, let s = sc.project(CGPoint(x: TowerMap.stairW.midX, y: TowerMap.stairW.midY), 40) {
            ctx.draw(Text("STAIRS UP").font(.jk(10, .heavy)).foregroundColor(.green), at: s)
        }
        if f > 0, let s = sc.project(CGPoint(x: TowerMap.stairE.midX, y: TowerMap.stairE.midY), 40) {
            ctx.draw(Text("STAIRS DOWN").font(.jk(10, .heavy)).foregroundColor(.orange), at: s)
        }
        for r in TowerMap.elevs {
            if let s = sc.project(CGPoint(x: r.midX, y: r.midY), 30) {
                ctx.draw(Text("ELEVATOR").font(.jk(10, .heavy)).foregroundColor(.cyan), at: s)
            }
        }
        // actors
        for i in sc.seenIdx {
            let a = e.actors[i]
            guard let s = sc.project(sc.vs[i].p, 62) else { continue }
            let mate = a.team == 0
            let w: CGFloat = 38
            let bar = CGRect(x: s.x - w / 2, y: s.y - 4, width: w, height: 4)
            ctx.fill(Path(bar), with: .color(.black.opacity(0.6)))
            ctx.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: w * max(0, a.hp / 100), height: 4)), with: .color(mate ? .green : .red))
            if a.armor > 0 {
                ctx.fill(Path(CGRect(x: bar.minX, y: bar.minY - 3, width: w * min(1, a.armor / 150), height: 2)), with: .color(.cyan))
            }
            if a.team == 0 && !a.isMe {
                ctx.draw(Text(a.name).font(.jk(9, .bold)).foregroundColor(mate ? .green : .white.opacity(0.9)), at: CGPoint(x: s.x, y: s.y - 12))
            }
            if a.reloadT > 0 {
                ctx.draw(Text("RELOAD").font(.jk(8, .heavy)).foregroundColor(.yellow), at: CGPoint(x: s.x, y: s.y + 8))
            }
        }
        // damage numbers
        for n in e.nums where n.f == f {
            if let s = sc.project(n.p, 50) {
                ctx.draw(Text("\(n.v)").font(.jk(n.head ? 15 : 12, .heavy)).foregroundColor(n.head ? .yellow : .white), at: s)
            }
        }
        // minimap
        let mw: CGFloat = 176, mh: CGFloat = 110
        let mo = CGPoint(x: 12, y: 62)
        let k = mw / TowerMap.W
        ctx.fill(Path(CGRect(x: mo.x, y: mo.y, width: mw, height: mh)), with: .color(.black.opacity(0.55)))
        var wp = Path()
        for w in e.map.walls[f] {
            wp.addRect(CGRect(x: mo.x + w.minX * k, y: mo.y + w.minY * k, width: max(1, w.width * k), height: max(1, w.height * k)))
        }
        ctx.fill(wp, with: .color(.white.opacity(0.5)))
        for d in e.map.doors[f] {
            ctx.fill(Path(CGRect(x: mo.x + d.r.minX * k, y: mo.y + d.r.minY * k, width: max(2, d.r.width * k), height: max(2, d.r.height * k))), with: .color(.orange))
        }
        ctx.fill(Path(CGRect(x: mo.x + TowerMap.stairW.minX * k, y: mo.y + TowerMap.stairW.minY * k, width: TowerMap.stairW.width * k, height: TowerMap.stairW.height * k)), with: .color(.green.opacity(0.7)))
        ctx.fill(Path(CGRect(x: mo.x + TowerMap.stairE.minX * k, y: mo.y + TowerMap.stairE.minY * k, width: TowerMap.stairE.width * k, height: TowerMap.stairE.height * k)), with: .color(.orange.opacity(0.7)))
        for r in TowerMap.elevs {
            ctx.fill(Path(CGRect(x: mo.x + r.minX * k, y: mo.y + r.minY * k, width: r.width * k, height: r.height * k)), with: .color(.cyan.opacity(0.8)))
        }
        if e.gassed.contains(f) {
            ctx.fill(Path(CGRect(x: mo.x, y: mo.y, width: mw, height: mh)), with: .color(.green.opacity(0.25)))
        }
        if e.circleOn && f == e.finalFloor {
            let r = Path(ellipseIn: CGRect(x: mo.x + (e.circle.x - e.circleR) * k, y: mo.y + (e.circle.y - e.circleR) * k, width: e.circleR * 2 * k, height: e.circleR * 2 * k))
            ctx.stroke(r, with: .color(.green), lineWidth: 1)
        }
        for a in e.actors where a.alive && a.f == f && (a.team == 0 || sc.seenIdx.contains(a.id)) {
            let c: Color = a.isMe ? .yellow : a.team == 0 ? .cyan : .red
            let vp = sc.vs[a.id].p
            ctx.fill(Path(ellipseIn: CGRect(x: mo.x + vp.x * k - 2.5, y: mo.y + vp.y * k - 2.5, width: 5, height: 5)), with: .color(c))
        }
        for hz in e.map.hazards[f] {
            ctx.fill(Path(CGRect(x: mo.x + hz.minX * k, y: mo.y + hz.minY * k, width: hz.width * k, height: hz.height * k)), with: .color(.green.opacity(0.35)))
        }
        for (gi, g) in e.map.glass[f].enumerated() where e.map.glassAlive[f][gi] {
            ctx.fill(Path(CGRect(x: mo.x + g.minX * k, y: mo.y + g.minY * k, width: max(1.5, g.width * k), height: max(1.5, g.height * k))), with: .color(.cyan.opacity(0.9)))
        }
        // power panel label + noise alerts
        if e.def.mech == 6, f < e.powerOn.count, let s = sc.project(TowerMap.switchPos, 48) {
            let txt = e.powerOn[f] ? "POWER ONLINE" : (e.hack[f] > 0 ? "HACKING \(Int(min(1, e.hack[f] / 1.2) * 100))%" : "POWER OFFLINE  -  STAND HERE")
            ctx.draw(Text(txt).font(.jk(10, .heavy)).foregroundColor(e.powerOn[f] ? .green : .red), at: s)
        }
        for al in e.alerts where al.f == f {
            if let c = sc.project(al.p, 10), let edge = sc.project(CGPoint(x: al.p.x + (2.5 - al.t) * 320, y: al.p.y), 10) {
                let r = abs(edge.x - c.x)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.6, width: r * 2, height: r * 1.2)), with: .color(.red.opacity(Double(al.t / 2.5))), lineWidth: 3)
            }
        }
        // blackout
        if e.dark[f] != nil, let s = sc.project(sc.vs[0].p, 20) {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.94)]), center: s, startRadius: 60, endRadius: 240))
        }
        // hurt vignette
        if e.hurtFlash > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.red.opacity(0.28 * e.hurtFlash)))
        }
        if e.gassed.contains(f) {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.green.opacity(0.08)))
        }
        // crosshair-ish hit marker
        if e.hitMark > 0 {
            var p = Path()
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
            for (dx, dy) in ([(-1, -1), (1, -1), (-1, 1), (1, 1)] as [(CGFloat, CGFloat)]) {
                p.move(to: CGPoint(x: c.x + dx * 5, y: c.y + dy * 5))
                p.addLine(to: CGPoint(x: c.x + dx * 11, y: c.y + dy * 11))
            }
            ctx.stroke(p, with: .color(.white.opacity(e.hitMark)), lineWidth: 2)
        }
    }

    // MARK: controls

    private var controls: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            ZStack {
                Color.clear.contentShape(Rectangle())
                    .frame(width: W * 0.45, height: H)
                    .position(x: W * 0.225, y: H / 2)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("tw"))
                        .onChanged { v in
                            if lStart == nil { lStart = v.startLocation }
                            let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                            let m = hypot(dx, dy)
                            let k = min(1, m / 55)
                            lKnob = CGPoint(x: m > 0 ? dx / m * min(m, 55) : 0, y: m > 0 ? dy / m * min(m, 55) : 0)
                            engine.move = m > 6 ? CGPoint(x: dx / m * k, y: dy / m * k) : .zero
                        }
                        .onEnded { _ in
                            lStart = nil
                            lKnob = .zero
                            engine.move = .zero
                        })
                Color.clear.contentShape(Rectangle())
                    .frame(width: W * 0.4, height: H)
                    .position(x: W * 0.8, y: H / 2)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("tw"))
                        .onChanged { v in
                            if rStart == nil { rStart = v.startLocation }
                            let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                            let m = hypot(dx, dy)
                            rKnob = CGPoint(x: m > 0 ? dx / m * min(m, 55) : 0, y: m > 0 ? dy / m * min(m, 55) : 0)
                            engine.aim = m > 8 ? CGPoint(x: dx / m, y: dy / m) : engine.aim
                            engine.firing = m > 30
                        }
                        .onEnded { _ in
                            rStart = nil
                            rKnob = .zero
                            engine.firing = false
                        })
                if lookOn {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: W * 0.55, height: H)
                        .position(x: W * 0.725, y: H / 2)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let dx = v.translation.width - lastDrag.width
                                let dy = v.translation.height - lastDrag.height
                                lastDrag = v.translation
                                engine.camYaw -= dx * 0.008
                                engine.camPitch = max(0.45, min(1.45, engine.camPitch + dy * 0.005))
                            }
                            .onEnded { _ in lastDrag = .zero })
                        .simultaneousGesture(MagnificationGesture()
                            .onChanged { m in engine.camDist = max(220, min(900, baseDist / m)) }
                            .onEnded { _ in baseDist = engine.camDist })
                }
                if let s = lStart {
                    stickView(s, lKnob)
                }
                if let s = rStart {
                    stickView(s, rKnob)
                }
            }
            .coordinateSpace(name: "tw")
        }
    }

    private func stickView(_ s: CGPoint, _ k: CGPoint) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.35), lineWidth: 2).frame(width: 110, height: 110)
            Circle().fill(Color.white.opacity(0.35)).frame(width: 46, height: 46).offset(x: k.x, y: k.y)
        }
        .position(s)
        .allowsHitTesting(false)
    }

    // MARK: HUD

    private var hud: some View {
        let e = engine
        let m = e.me
        let tgt = m.alive ? m : (e.actors.first(where: { $0.team == 0 && $0.alive }) ?? m)
        return GeometryReader { g in
            ZStack {
                // top left status
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(e.def.name)  -  \(tgt.f + 1). \(e.def.floors[tgt.f])").font(.jk(13, .heavy)).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Text("\(e.aliveCount) ALIVE").font(.jk(11, .bold)).foregroundColor(lime)
                        Text("\(e.teamsLeft) SQUADS").font(.jk(11, .bold)).foregroundColor(.white.opacity(0.8))
                        Text("\(e.kills) K").font(.jk(11, .bold)).foregroundColor(.white.opacity(0.8))
                        if e.def.mech == 4 || e.def.mech == 5 {
                            Text("KEYS \(tgt.keys)").font(.jk(11, .bold)).foregroundColor(.yellow)
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .position(x: 100, y: 28)

                // banner
                if e.bannerT > 0 {
                    Text(e.banner).font(.jk(14, .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.black.opacity(0.6)).clipShape(Capsule())
                        .position(x: g.size.width / 2, y: 30)
                }
                if e.warnFloor >= 0 {
                    Text("FLOOR \(e.warnFloor + 1) SEALS IN \(Int(max(0, e.warnT)))")
                        .font(.jk(12, .heavy)).foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.orange).clipShape(Capsule())
                        .position(x: g.size.width / 2, y: 62)
                }
                // kill feed
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(Array(e.feed.enumerated()), id: \.offset) { _, f in
                        Text(f.0).font(.jk(9, .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.black.opacity(0.5)).clipShape(Capsule())
                    }
                }
                .position(x: g.size.width - 130, y: 78)

                // pause
                Button { e.paused = true } label: {
                    Image(systemName: "pause.fill").foregroundColor(.white).frame(width: 36, height: 36).background(Color.black.opacity(0.5)).clipShape(Circle())
                }
                .position(x: g.size.width - 28, y: 28)

                // bars + weapons
                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.55)).frame(width: 150, height: 10)
                            Capsule().fill(Color.white).frame(width: 150 * max(0, min(1, tgt.hp / 100)), height: 10)
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.55)).frame(width: 90, height: 10)
                            Capsule().fill(Color.cyan).frame(width: 90 * max(0, min(1, tgt.armor / 150)), height: 10)
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(0..<2, id: \.self) { i in slotView(tgt, i) }
                    }
                }
                .position(x: g.size.width / 2, y: g.size.height - 48)

                // action buttons
                actionButtons(m, g.size)
            }
        }
    }

    private var killCamHud: some View {
        let e = engine
        let k = e.killcam
        let name = k.map { e.actors[$0.killer].name } ?? ""
        let gunName = k.map { BRGuns.def(["pistol", "smg", "rifle", "shotgun"][e.currentViews()[$0.killer].gun]).name } ?? ""
        let prog = k.map { min(1, $0.t / (CGFloat(max(1, $0.frames.count)) * 0.05)) } ?? 0
        return GeometryReader { g in
            ZStack {
                VStack(spacing: 2) {
                    Text("KILL CAM").font(.jk(11, .heavy)).foregroundColor(.red)
                    Text("\(name)  -  \(gunName)").font(.jk(18, .heavy)).foregroundColor(.white)
                }
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(Color.black.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 12))
                .position(x: g.size.width / 2, y: 44)
                Rectangle().fill(Color.black.opacity(0.55)).frame(width: g.size.width, height: 26).position(x: g.size.width / 2, y: g.size.height - 13)
                Rectangle().fill(Color.red).frame(width: g.size.width * prog, height: 4).position(x: g.size.width * prog / 2, y: g.size.height - 2)
                Button { e.skipKillCam() } label: {
                    Text("SKIP").font(.jk(13, .heavy)).foregroundColor(.black).frame(width: 90, height: 38).background(Color.white).clipShape(Capsule())
                }
                .position(x: g.size.width - 70, y: g.size.height - 50)
            }
        }
    }

    private func slotView(_ a: TwActor, _ i: Int) -> some View {
        let s = a.slots[i]
        let on = a.cur == i
        return HStack(spacing: 4) {
            if let s = s {
                Image(uiImage: GunSprites.icon(s.id)).resizable().scaledToFit().frame(width: 34, height: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(BRGuns.def(s.id).name).font(.jk(7, .heavy)).foregroundColor(s.rar > 0 ? BRMeta.rarColor(s.rar) : .white)
                    Text("\(s.mag) / \(s.res)").font(.jk(11, .heavy)).foregroundColor(.white)
                }
            } else {
                Text("EMPTY").font(.jk(8, .bold)).foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(width: 130, height: 34)
        .background(Color.black.opacity(on ? 0.7 : 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(on ? lime : Color.white.opacity(0.2), lineWidth: 1.5))
        .onTapGesture { if a.isMe, s != nil { a.cur = i; a.reloadT = 0 } }
    }

    private func btn(_ t: String, _ c: Color, _ w: CGFloat = 62, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(t).font(.jk(11, .heavy)).foregroundColor(.black)
                .frame(width: w, height: 40).background(c).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func actionButtons(_ m: TwActor, _ size: CGSize) -> some View {
        let e = engine
        return ZStack {
            VStack(spacing: 8) {
                btn("RELOAD", .white) { e.startReload(m) }
                btn("SWAP", .white) { e.swap(m) }
                btn("MED \(m.meds)", .red) { e.useMed(m) }
                btn("CAM", .white) { e.zoom = (e.zoom + 1) % 3 }
                btn(lookOn ? "FOLLOW" : "LOOK", lookOn ? .yellow : .cyan) {
                    lookOn.toggle()
                    e.look = lookOn
                    e.firing = false
                    if lookOn { e.camYaw = 0; e.camPitch = 1.0; e.camDist = 430; baseDist = 430 }
                }
            }
            .position(x: size.width - 48, y: size.height - 150)

            if m.alive {
                if let di = e.nearestDoor(m) {
                    let dd = e.map.doors[m.f][di]
                    btn(dd.want || dd.open > 0.5 ? "CLOSE DOOR" : dd.kind == 2 && dd.locked ? "UNLOCK DOOR" : "OPEN DOOR", .yellow, 120) { e.toggleDoor(m) }
                        .position(x: size.width / 2, y: size.height - 162)
                }
                if e.nearStairUp(m) {
                    btn("STAIRS UP", .green, 110) { e.go(m, to: m.f + 1) }
                        .position(x: size.width / 2, y: size.height - 110)
                }
                if e.nearStairDown(m) {
                    btn("STAIRS DOWN", .orange, 120) { e.go(m, to: m.f - 1) }
                        .position(x: size.width / 2, y: size.height - 110)
                }
                if e.nearElev(m) {
                    HStack(spacing: 5) {
                        ForEach(0..<e.map.nF, id: \.self) { f in
                            Button { e.go(m, to: f) } label: {
                                Text("\(f + 1)").font(.jk(14, .heavy)).foregroundColor(.black)
                                    .frame(width: 38, height: 38)
                                    .background(f == m.f ? Color.gray : Color.cyan)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(6).background(Color.black.opacity(0.55)).clipShape(Capsule())
                    .position(x: size.width / 2, y: size.height - 110)
                }
            }
        }
    }

    // MARK: pause / over

    private var pauseView: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("PAUSED").font(.jk(28, .heavy)).foregroundColor(.white)
                BRSettingsPanel().frame(width: 320)
                HStack(spacing: 12) {
                    Button { engine.paused = false; engine.last = nil } label: {
                        Text("Resume").font(.jk(16, .bold)).foregroundColor(.black).frame(width: 130, height: 44).background(lime).clipShape(Capsule())
                    }
                    Button {
                        engine.paused = false
                        engine.place = max(1, engine.teamsLeft)
                        engine.finish(false)
                    } label: {
                        Text("Leave match").font(.jk(16, .bold)).foregroundColor(.white).frame(width: 150, height: 44).background(Color.red.opacity(0.8)).clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var overView: some View {
        let e = engine
        let place = e.won ? 1 : max(1, e.place)
        let gems = (e.won ? 80 : 0) + max(0, e.teams - place) * 8 + e.kills * 5 + e.contractGems
        return ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(e.won ? "SPIRE CLEARED" : "ELIMINATED").font(.jk(38, .heavy)).foregroundColor(e.won ? lime : .red)
                Text("SQUAD PLACED #\(place) OF \(e.teams)").font(.jk(22, .heavy)).foregroundColor(.white)
                Text("\(e.kills) kills   \(e.heads) headshots   \(gems) gems").font(.jk(16, .semibold)).foregroundColor(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text("DAILY CONTRACTS").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.6))
                    ForEach(Array(e.contractLines.enumerated()), id: \.offset) { _, l in
                        HStack(spacing: 6) {
                            Image(systemName: l.1 ? "checkmark.circle.fill" : "circle").foregroundColor(l.1 ? lime : .white.opacity(0.5)).font(.system(size: 12))
                            Text(l.0).font(.jk(11, .semibold)).foregroundColor(.white)
                        }
                    }
                }
                Button {
                    guard !collected else { return }
                    collected = true
                    game.battleRoyaleFinish(place: place, kills: e.kills, gems: gems)
                    dismiss()
                } label: {
                    Text("Collect and exit").font(.jk(18, .bold)).foregroundColor(.black).frame(width: 240, height: 52).background(Color.white).clipShape(Capsule())
                }
            }
        }
    }
}

/// Steps the simulation and the scene from a display link at the screen's rate, independent of SwiftUI redraws.
final class TowerDriver: NSObject {
    private let engine: TowerEngine
    private let scene: TowerScene
    private var link: CADisplayLink?

    init(engine: TowerEngine, scene: TowerScene) {
        self.engine = engine
        self.scene = scene
    }

    func start() {
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick() {
        engine.step(Date())
        scene.sync(engine, dt: engine.dtLast)
    }
}
