import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var showSeason = false
    @State private var showStats = false
    @State private var bg: TacScene? = nil
    @State private var diff = 1

    private let lime = Color(red: 0.85, green: 0.93, blue: 0.2)
    private let diffNames = ["EASY", "NORMAL", "HARD"]

    var body: some View {
        GeometryReader { g in
            let t = game.s.ex.tac ?? TacData()
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
                    topBar(t)
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 14) {
                        leftCards(t)
                        Spacer(minLength: 0)
                        rightColumn(t, colW)
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
        .fullScreenCover(isPresented: $showSeason) {
            TacSeasonView().environmentObject(game).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: Binding(get: { nav.tacPlay != nil }, set: { if !$0 { nav.tacPlay = nil } })) {
            TacticalPlay(diff: nav.tacPlay ?? 1, modeId: nav.tacMode).environmentObject(game).environmentObject(nav).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showStats) {
            statsSheet.preferredColorScheme(.dark)
        }
    }

    private func ensureBg() {
        guard bg == nil, nav.tacPlay == nil else { return }
        let b = TacScene()
        b.build(TacticalEngine())
        bg = b
    }

    // MARK: top

    private func topBar(_ t: TacData) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(TacSeason.league(t.rating)).font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7)).tracking(1)
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
                Text("\(game.s.ex.gems)").font(.jk(16, .bold)).foregroundColor(.white)
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color.black.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 6))
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
            Text("SAFEHOUSE").font(.jk(13, .heavy)).foregroundColor(.white).padding(8)
                .frame(width: 170, alignment: .leading).background(Color.black.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: right

    private func rightColumn(_ t: TacData, _ w: CGFloat) -> some View {
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
            Button { diff = (diff + 1) % 3 } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("5V5 \(TWeapons.modeNames[nav.tacMode])").font(.jk(16, .heavy)).foregroundColor(.white)
                        Text("Safehouse  |  \(diffNames[diff])  |  FIRST PERSON").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12).frame(width: w, height: 52).background(Color.black.opacity(0.7))
            }
            .buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    let on = nav.tacMode == i
                    Button { nav.tacMode = i } label: {
                        Text(TWeapons.modeShort[i]).font(.jk(9, .heavy)).foregroundColor(on ? .black : .white.opacity(0.8))
                            .frame(maxWidth: .infinity).frame(height: 28).background(on ? lime : Color.black.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: w)
            Button { nav.tacPlay = diff } label: {
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
            Button { showSeason = true } label: {
                Text("SEASON").font(.jk(16, .bold)).foregroundColor(.white.opacity(0.9)).frame(maxWidth: .infinity).frame(height: 48)
            }
            .buttonStyle(.plain)
            Button { showStats = true } label: {
                Text("STATS").font(.jk(16, .bold)).foregroundColor(.white.opacity(0.9)).frame(maxWidth: .infinity).frame(height: 48)
            }
            .buttonStyle(.plain)
        }
        .frame(width: max(0, w), alignment: .leading)
        .background(Color.black.opacity(0.55))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var statsSheet: some View {
        let t = game.s.ex.tac ?? TacData()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Stats").font(.jk(30, .heavy))
            ForEach(Array([("Wins", "\(t.wins)"), ("Losses", "\(t.losses)"), ("Kills", "\(t.kills)"), ("Rating", "\(t.rating)")].enumerated()), id: \.offset) { _, kv in
                HStack {
                    Text(kv.0).font(.jk(16, .bold))
                    Spacer()
                    Text(kv.1).font(.jk(18, .heavy))
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Button {
                var s2 = game.s
                s2.ex.tac = nil
                game.s = s2
            } label: {
                Text("Reset stats").font(.jk(15, .bold)).foregroundColor(.red)
                    .frame(maxWidth: .infinity).frame(height: 48).background(Color.red.opacity(0.15)).clipShape(Capsule())
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(T.bg.ignoresSafeArea())
    }
}
