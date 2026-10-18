import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var bg: TacScene? = nil
    @State private var diff = 1
    @State private var sheet: Int? = nil

    private let lime = Color(red: 0.85, green: 0.93, blue: 0.2)
    private let diffNames = ["EASY", "NORMAL", "HARD"]

    var body: some View {
        GeometryReader { g in
            let st = game.s
            let t = st.ex.tac ?? TacData()
            let colW = max(250, g.size.width * 0.3)
            ZStack {
                Color.black.ignoresSafeArea()
                if let b = bg {
                    TacSceneView(bridge: b).ignoresSafeArea().allowsHitTesting(false)
                    TimelineView(.animation) { tl in
                        Canvas { _, _ in b.orbit(tl.date.timeIntervalSinceReferenceDate) }
                    }
                    .frame(width: 1, height: 1).allowsHitTesting(false)
                }
                LinearGradient(colors: [Color.black.opacity(0.65), .clear, Color.black.opacity(0.45)], startPoint: .leading, endPoint: .trailing).ignoresSafeArea().allowsHitTesting(false)
                LinearGradient(colors: [Color.black.opacity(0.5), .clear, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar(st, t)
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 14) {
                        leftCards(t)
                        Spacer(minLength: 0)
                        rightColumn(st, t, colW)
                    }
                    .padding(.bottom, 6)
                    bottomBar(g.size.width - colW - 14)
                }
                .padding(.horizontal, 14)
            }
        }
        .onAppear {
            OrientationLock.set(landscape: true)
            ensureBg()
        }
        .onChange(of: nav.brPlay) { v in
            if v {
                bg?.view.isPlaying = false
                bg?.view.scene = nil
                bg = nil
            } else {
                OrientationLock.set(landscape: true)
                ensureBg()
            }
        }
        .background(Color.clear.fullScreenCover(isPresented: $nav.brPlay) {
            BattleRoyalePlay().environmentObject(game).environmentObject(nav).preferredColorScheme(.dark)
        })
        .onChange(of: nav.tacPlay) { v in
            if v != nil {
                bg?.view.isPlaying = false
                bg?.view.scene = nil
                bg = nil
            } else {
                OrientationLock.set(landscape: true)
                ensureBg()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { nav.tacPlay != nil }, set: { if !$0 { nav.tacPlay = nil } })) {
            TacticalPlay(diff: nav.tacPlay ?? 1, fpMode: nav.tacFP).environmentObject(game).environmentObject(nav).preferredColorScheme(.dark)
        }
        .sheet(isPresented: Binding(get: { sheet != nil }, set: { if !$0 { sheet = nil } })) {
            sheetBody.environmentObject(game).preferredColorScheme(.dark)
        }
    }

    private func ensureBg() {
        guard bg == nil, nav.tacPlay == nil, !nav.brPlay else { return }
        let b = TacScene()
        b.build(TacticalEngine())
        bg = b
    }

    // MARK: top

    private func topBar(_ st: GameState, _ t: TacData) -> some View {
        HStack(spacing: 10) {
            Button { sheet = 3 } label: {
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 46, ring: true)
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("RANKED").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7)).tracking(1)
                    Text("\(t.rating)").font(.jk(20, .heavy)).foregroundColor(.white)
                }
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 20)).foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.3))
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color(red: 0.36, green: 0.2, blue: 0.58)).clipShape(RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.white)
                Text("\(t.wins) W  \(t.losses) L").font(.jk(14, .bold)).foregroundColor(.white)
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color.black.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer()
            Text("MAINSHOT").font(.jk(18, .heavy)).tracking(3).foregroundColor(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "diamond.fill").font(.system(size: 16)).foregroundColor(Color(red: 1, green: 0.8, blue: 0.2))
                Text("\(st.ex.gems)").font(.jk(16, .bold)).foregroundColor(.white)
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color.black.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 6))
            Button { sheet = 3 } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 20)).foregroundColor(.white)
                    .frame(width: 48, height: 44).background(Color.black.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: left

    private func leftCards(_ t: TacData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "scope").font(.system(size: 14, weight: .bold))
                Text("\(t.kills) KILLS").font(.jk(13, .heavy))
            }
            .foregroundColor(.black).padding(.horizontal, 10).frame(height: 28).background(lime).clipShape(RoundedRectangle(cornerRadius: 4))
            ZStack(alignment: .topLeading) {
                TacMapPreview().frame(width: 170)
                Text("NEW").font(.jk(14, .heavy)).foregroundColor(.black)
                    .padding(.horizontal, 8).padding(.vertical, 2).background(lime)
            }
            .overlay(alignment: .bottomLeading) {
                Text("SAFEHOUSE").font(.jk(13, .heavy)).foregroundColor(.white).padding(8).shadow(radius: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: right

    private func rightColumn(_ st: GameState, _ t: TacData, _ w: CGFloat) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                Text("SEASON RATING").font(.jk(12, .heavy)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 22).background(lime)
                VStack(spacing: 6) {
                    Text("\(t.rating)").font(.jk(34, .heavy)).foregroundColor(.white)
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 5)
                        .overlay(alignment: .leading) {
                            GeometryReader { p in
                                Capsule().fill(lime).frame(width: p.size.width * CGFloat((t.rating % 100)) / 100)
                            }
                        }
                    Text("\(t.wins) wins  \u{00B7}  \(t.losses) losses  \u{00B7}  \(t.kills) kills").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.75))
                }
                .padding(10).frame(maxWidth: .infinity).background(Color.black.opacity(0.7))
            }
            .frame(width: w)
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill").font(.system(size: 16)).foregroundColor(.white).frame(width: 40)
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 34, ring: true)
                ForEach(0..<4, id: \.self) { _ in
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 28, height: 28)
                        .overlay(Image(systemName: "cpu").font(.system(size: 11)).foregroundColor(.white.opacity(0.4)))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).frame(width: w, height: 46).background(Color.black.opacity(0.7))
            Button { diff = (diff + 1) % 3 } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(nav.lobbyMode == 1 ? "BATTLE ROYALE" : "5V5 BOMB DEFUSAL").font(.jk(16, .heavy)).foregroundColor(.white)
                        Text(nav.lobbyMode == 1 ? "Port Ridge  |  30 players  |  FIRST PERSON" : "Safehouse  |  \(diffNames[diff])  |  \(nav.tacFP ? "FIRST PERSON" : "3D")").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12).frame(width: w, height: 52).background(Color.black.opacity(0.7))
            }
            .buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(Array(["5V5 3D", "5V5 FP", "BR"].enumerated()), id: \.offset) { i, n in
                    let on = (nav.lobbyMode == 1 ? 2 : (nav.tacFP ? 1 : 0)) == i
                    Button {
                        nav.lobbyMode = i == 2 ? 1 : 0
                        if i < 2 { nav.tacFP = (i == 1) }
                    } label: {
                        Text(n).font(.jk(12, .heavy)).foregroundColor(on ? .black : .white.opacity(0.8))
                            .frame(maxWidth: .infinity).frame(height: 32).background(on ? lime : Color.black.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: w)
            Button { if nav.lobbyMode == 1 { nav.brPlay = true } else { nav.tacPlay = diff } } label: {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 12)).foregroundColor(.black.opacity(0.7))
                        Spacer()
                        Text("PLAY").font(.jk(38, .heavy)).foregroundColor(.black)
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 12)).foregroundColor(.black.opacity(0.7)).rotationEffect(.degrees(180))
                    }
                    .padding(.horizontal, 14).frame(height: 58)
                    Text("FIND A MATCH").font(.jk(14, .heavy)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 26).background(Color.black.opacity(0.15))
                }
                .frame(width: w).background(lime)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: bottom

    private func bottomBar(_ w: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(["STORE", "EVENTS", "GEAR UP"].enumerated()), id: \.offset) { i, n in
                Button { sheet = i } label: {
                    Text(n).font(.jk(16, .bold)).foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity).frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: max(0, w), alignment: .leading)
        .background(Color.black.opacity(0.55))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: sheets

    @ViewBuilder private var sheetBody: some View {
        switch sheet ?? 0 {
        case 0: ArmoryView(section: 0)
        case 2: ArmoryView(section: 1)
        case 1: statsSheet
        default: settingsSheet
        }
    }

    private var statsSheet: some View {
        let t = game.s.ex.tac ?? TacData()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Events").font(.jk(30, .heavy))
            Text("MATCH RECORD").font(.jk(11, .heavy)).foregroundColor(T.sub)
            ForEach(Array([("Wins", "\(t.wins)"), ("Losses", "\(t.losses)"), ("Kills", "\(t.kills)"), ("Rating", "\(t.rating)")].enumerated()), id: \.offset) { _, kv in
                HStack {
                    Text(kv.0).font(.jk(16, .bold))
                    Spacer()
                    Text(kv.1).font(.jk(18, .heavy))
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(T.bg.ignoresSafeArea())
    }

    private var settingsSheet: some View {
        let st = game.s
        return VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.jk(30, .heavy))
            HStack(spacing: 12) {
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 54, ring: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(st.persona.name).font(.jk(18, .bold))
                    Text("@" + st.persona.handle).font(.jk(13)).foregroundColor(T.sub)
                }
            }
            Button {
                var s2 = game.s
                s2.ex.tac = nil
                game.s = s2
            } label: {
                Text("Reset match stats").font(.jk(15, .bold)).foregroundColor(.red)
                    .frame(maxWidth: .infinity).frame(height: 48).background(Color.red.opacity(0.15)).clipShape(Capsule())
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(T.bg.ignoresSafeArea())
    }
}
