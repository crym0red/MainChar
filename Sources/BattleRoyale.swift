import SwiftUI

struct BattleRoyalePlay: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var engine = BREngine()
    @State private var lStart: CGPoint? = nil
    @State private var lKnob: CGPoint = .zero
    @State private var lastLook: CGFloat = 0
    @State private var lastLookY: CGFloat = 0
    @State private var collected = false
    @State private var autoOn = true
    @State private var ready = false

    private let lime = Color(red: 0.85, green: 0.93, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if ready {
                TimelineView(.animation) { tl in
                    ZStack {
                        Canvas { ctx, size in
                            engine.step(tl.date)
                            engine.draw(&ctx, size)
                        }
                        .ignoresSafeArea()
                        controls
                        hud
                        if engine.paused && !engine.over { pauseView }
                        if engine.over { overView }
                    }
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            OrientationLock.set(landscape: true)
            let e = BREngine()
            e.setup(name: game.s.persona.handle)
            engine = e
            ready = true
        }
    }

    // MARK: controls

    private var controls: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            ZStack {
                Color.clear.contentShape(Rectangle())
                    .frame(width: W * 0.6, height: H)
                    .position(x: W * 0.7, y: H / 2)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            engine.look += v.translation.width - lastLook
                            lastLook = v.translation.width
                            engine.lookY += v.translation.height - lastLookY
                            lastLookY = v.translation.height
                        }
                        .onEnded { _ in lastLook = 0; lastLookY = 0 })
                Color.clear.contentShape(Rectangle())
                    .frame(width: W * 0.4, height: H * 0.65)
                    .position(x: W * 0.2, y: H * 0.675)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            lStart = v.startLocation
                            lKnob = v.location
                            let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                            let d = hypot(dx, dy)
                            let k = min(1, d / 50)
                            engine.move = d > 4 ? CGVector(dx: dx / d * k, dy: dy / d * k) : .zero
                        }
                        .onEnded { _ in
                            lStart = nil
                            engine.move = .zero
                        })
                stickView(W, H)
                fireButton("capsule.portrait.fill", 76).position(x: W - 92, y: H - 120)
                fireButton("capsule.portrait.fill", 52).position(x: 44, y: H - 178)
                roundButton(engine.ads ? "scope" : "scope", engine.ads ? "AIMING" : "AIM") { engine.ads.toggle() }
                    .scaleEffect(1.25).position(x: W - 92, y: H - 205)
                roundButton("arrow.clockwise", "RELOAD") { engine.doReload() }.position(x: W - 160, y: H - 52)
                roundButton("arrow.left.arrow.right", "SWAP") { engine.swapGun() }.position(x: W - 196, y: H - 112)
                roundButton(engine.crouch ? "arrow.up.to.line" : "arrow.down.to.line", "CROUCH") { engine.crouch.toggle(); if engine.crouch { engine.prone = false } }.position(x: W - 28, y: H - 64)
                roundButton(engine.prone ? "figure.stand" : "figure.fall", engine.me.sprinting ? "DIVE" : "PRONE") { engine.setProne() }.position(x: W - 28, y: H - 236)
                roundButton("shield.lefthalf.filled", "PLATE \(engine.plates)") { engine.applyPlate() }.position(x: W - 28, y: H - 193)
                roundButton("cross.case.fill", "HEAL \(engine.meds)") { engine.heal() }.position(x: W - 28, y: H - 150)
            }
        }
    }

    private func stickView(_ W: CGFloat, _ H: CGFloat) -> some View {
        let base = lStart ?? CGPoint(x: 100, y: H - 90)
        var knob = lKnob
        if lStart == nil { knob = base }
        let dx = knob.x - base.x, dy = knob.y - base.y
        let d = hypot(dx, dy)
        let k = d > 50 ? 50 / d : 1
        return ZStack {
            Circle().fill(Color.white.opacity(lStart == nil ? 0.08 : 0.14)).frame(width: 110, height: 110)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
                .position(base)
            Circle().fill(Color.white.opacity(0.4)).frame(width: 46, height: 46)
                .position(x: base.x + dx * k, y: base.y + dy * k)
        }
        .allowsHitTesting(false)
    }

    private func fireButton(_ icon: String, _ d: CGFloat) -> some View {
        Circle().fill(Color.black.opacity(0.45))
            .frame(width: d, height: d)
            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 3))
            .overlay(Image(systemName: icon).font(.system(size: d * 0.4, weight: .bold)).foregroundColor(.white).rotationEffect(.degrees(35)))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in engine.firing = true }
                .onEnded { _ in engine.firing = false })
    }

    private func roundButton(_ icon: String, _ label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold))
                Text(label).font(.jk(7, .heavy))
            }
            .foregroundColor(.white)
            .frame(width: 46, height: 46)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: hud

    private var hud: some View {
        let e = engine
        return GeometryReader { g in
            let W = g.size.width, H = g.size.height
            ZStack {
                topStats(e).position(x: 131, y: 22)
                VStack(spacing: 3) {
                    ForEach(Array(e.actors.filter { $0.team == 0 }.enumerated()), id: \.offset) { i, a in
                        squadRow(e, a, i + 1)
                    }
                }
                .position(x: 108, y: 110)
                .allowsHitTesting(false)

                Button { e.paused = true } label: {
                    Image(systemName: "line.3.horizontal").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 34, height: 30).background(Color.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .position(x: W - 150, y: 26)

                Text(e.zoneLabel).font(.jk(10, .heavy)).foregroundColor(.white)
                    .padding(.horizontal, 10).frame(height: 20)
                    .background(Color(red: 0.45, green: 0.15, blue: 0.65).opacity(0.85)).clipShape(Capsule())
                    .position(x: W - 72, y: 142)
                    .allowsHitTesting(false)

                VStack(spacing: 2) {
                    ForEach(Array(e.feed.suffix(3).enumerated()), id: \.offset) { _, f in
                        Text(f.0).font(.jk(10, .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .position(x: W / 2, y: 96)
                .allowsHitTesting(false)

                if e.toast.1 > 0 {
                    Text(e.toast.0).font(.jk(13, .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 14).frame(height: 28).background(Color.black.opacity(0.6)).clipShape(Capsule())
                        .position(x: W / 2, y: H * 0.3)
                        .allowsHitTesting(false)
                }

                if e.outsideZone() && e.me.alive {
                    Text("RETURN TO THE SAFE ZONE").font(.jk(14, .heavy)).foregroundColor(Color(red: 0.85, green: 0.6, blue: 1))
                        .position(x: W / 2, y: H * 0.38)
                        .allowsHitTesting(false)
                }

                if e.me.reloadT > 0 {
                    Text("RELOADING").font(.jk(12, .heavy)).foregroundColor(.white)
                        .position(x: W / 2, y: H * 0.58)
                        .allowsHitTesting(false)
                }

                loadout(e)
                    .position(x: 340, y: H - 62)
            }
        }
    }

    private func topStats(_ e: BREngine) -> some View {
        let squads = Set(e.actors.filter { $0.alive }.map { $0.team }).count
        return HStack(spacing: 12) {
            stat("person.3.fill", "\(squads)")
            stat("person.fill", "\(e.aliveCount)")
            stat("xmark.circle.fill", "\(e.kills)")
            Text("\(Int(e.fps)) FPS").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10).frame(width: 236, height: 28, alignment: .leading)
        .background(Color.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 6))
        .allowsHitTesting(false)
    }

    private func stat(_ icon: String, _ v: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.8))
            Text(v).font(.jk(13, .heavy)).foregroundColor(.white)
        }
    }

    private func squadRow(_ e: BREngine, _ a: BRActor, _ idx: Int) -> some View {
        let cols: [Color] = [Color(red: 0.95, green: 0.8, blue: 0.2), Color(red: 0.4, green: 0.8, blue: 1), Color(red: 0.6, green: 0.95, blue: 0.5), Color(red: 1, green: 0.55, blue: 0.7)]
        let cash = a.isMe ? e.cash : a.cash
        return HStack(spacing: 6) {
            Text("\(idx)").font(.jk(10, .heavy)).foregroundColor(.black)
                .frame(width: 16, height: 16).background(a.alive ? cols[(idx - 1) % 4] : Color.gray).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(a.isMe ? game.s.persona.handle : a.name).font(.jk(11, .bold)).foregroundColor(a.alive ? .white : .gray).lineLimit(1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.55)).frame(width: 100, height: 4)
                    Capsule().fill(Color(red: 0.4, green: 0.9, blue: 0.5)).frame(width: 100 * max(0, min(1, a.hp / 100)), height: 4)
                }
            }
            Spacer(minLength: 0)
            Text(a.alive ? "$\(cash)" : "DOWN").font(.jk(10, .bold)).foregroundColor(a.alive ? Color(red: 0.4, green: 0.95, blue: 0.5) : .red)
        }
        .padding(.horizontal, 6).frame(width: 190, height: 30)
        .background(Color.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func loadout(_ e: BREngine) -> some View {
        let me = e.me
        let cur = me.slots[me.cur]
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Button { e.autoAim.toggle(); autoOn = e.autoAim } label: {
                    Text(autoOn ? "AUTO" : "MAN").font(.jk(10, .heavy)).foregroundColor(autoOn ? .black : .white)
                        .padding(.horizontal, 10).frame(height: 22).background(autoOn ? lime : Color.black.opacity(0.55)).clipShape(Capsule())
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(cur?.mag ?? 0)").font(.jk(24, .heavy)).foregroundColor(.white)
                    Text("/\(cur?.reserve ?? 0)").font(.jk(12, .bold)).foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 254)
            HStack(spacing: 6) {
                slot(e, 0)
                slot(e, 1)
            }
            HStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.55)).frame(width: 130, height: 9)
                    Rectangle().fill(Color.white).frame(width: 130 * max(0, min(1, me.hp / 100)), height: 9)
                }
                .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .skewX(-0.35)
                ForEach(0..<3, id: \.self) { i in plateCell(e, i) }
            }
            .frame(width: 254, alignment: .leading)
            HStack {
                Text("$ \(e.cash)").font(.jk(12, .heavy)).foregroundColor(Color(red: 0.4, green: 0.95, blue: 0.5))
                Spacer()
                Text("\(e.meds) MED").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 254)
        }
    }

    private func plateCell(_ e: BREngine, _ i: Int) -> some View {
        let base = CGFloat(i) * 33.4
        let have = max(0, min(1, (e.me.armor - base) / 33.4))
        // the plate currently being applied is the first empty one
        let applying = e.plateT > 0 && e.me.armor >= base - 0.01 && e.me.armor < base + 33.4 - 0.01
        let prog = applying ? max(have, min(1, e.plateT) * (1 - have) + have) : have
        let fillW: CGFloat = 38 * (applying ? prog : have)
        let glow = applying ? 0.6 + 0.4 * sin(e.plateT * 30) : 0
        return ZStack(alignment: .leading) {
            Rectangle().fill(Color.black.opacity(0.55)).frame(width: 38, height: 9)
            Rectangle().fill(LinearGradient(colors: [Color(red: 0.45, green: 0.72, blue: 1), Color(red: 0.2, green: 0.45, blue: 0.95)], startPoint: .top, endPoint: .bottom))
                .frame(width: fillW, height: 9)
            if applying {
                Rectangle().fill(Color.white.opacity(0.55 * glow)).frame(width: 8, height: 9).offset(x: max(0, fillW - 8))
            }
        }
        .overlay(Rectangle().stroke(applying ? Color.white : Color(red: 0.45, green: 0.72, blue: 1).opacity(0.6), lineWidth: 1))
        .shadow(color: Color(red: 0.4, green: 0.7, blue: 1).opacity(glow), radius: 6)
        .skewX(-0.35)
    }

    private func slot(_ e: BREngine, _ i: Int) -> some View {
        let s = e.me.slots[i]
        let on = e.me.cur == i
        return Button {
            if e.me.slots[i] != nil && e.me.alive { e.me.cur = i; e.me.reloadT = 0 }
        } label: {
            HStack(spacing: 4) {
                if let s = s {
                    Image(uiImage: GunSprites.icon(s.gun)).resizable().scaledToFit().frame(width: 50, height: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(BRGuns.def(s.gun).name).font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.85))
                        Text("\(s.mag)/\(s.reserve)").font(.jk(11, .heavy)).foregroundColor(.white)
                    }
                } else {
                    Text("EMPTY").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.4)).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 5)
            .frame(width: 124, height: 38)
            .background(on ? lime.opacity(0.3) : Color.black.opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? lime : Color.white.opacity(0.2), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: overlays

    private var pauseView: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PAUSED").font(.jk(30, .heavy))
                Button { engine.paused = false; engine.last = nil } label: {
                    Text("Resume").font(.jk(18, .bold)).foregroundColor(.black).frame(width: 220, height: 50).background(Color.white).clipShape(Capsule())
                }
                Button {
                    engine.me.hp = 0
                    engine.me.place = engine.aliveCount
                    engine.me.alive = false
                    engine.over = true
                    engine.won = false
                    engine.paused = false
                } label: {
                    Text("Leave match").font(.jk(16, .bold)).foregroundColor(.red).frame(width: 220, height: 46).background(Color.red.opacity(0.15)).clipShape(Capsule())
                }
            }
        }
    }

    private var overView: some View {
        let e = engine
        let place = e.me.place == 0 ? 30 : e.me.place
        let gems = (e.won ? 80 : 0) + max(0, 30 - place) * 2 + e.kills * 5
        return ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(e.won ? "WINNER WINNER" : "ELIMINATED").font(.jk(38, .heavy)).foregroundColor(e.won ? lime : .red)
                Text("PLACED #\(place) OF 30").font(.jk(24, .heavy))
                Text("\(e.kills) kills   \(gems) gems").font(.jk(16, .semibold))
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

private extension View {
    func skewX(_ k: CGFloat) -> some View {
        self.transformEffect(CGAffineTransform(a: 1, b: 0, c: k, d: 1, tx: 0, ty: 0))
    }
}
