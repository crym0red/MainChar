import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var showSeason = false
    @State private var showStats = false
    @State private var showAvatar = false
    @State private var showAdmin = false
    @State private var showRanks = false
    @State private var bg: TacScene? = nil
    @State private var diff = 1
    @State private var seasonTab = 0
    @State private var matchTab = 0
    @State private var username = TacProfile.name

    private let lime = TUI.accent
    private let diffNames = ["EASY", "NORMAL", "HARD"]
    private let modeIcons = ["timer", "person.2.fill", "tag.fill", "arrow.up.forward.circle.fill", "person.3.fill", "flag.fill"]
    private let modeInfo = ["Plant or defuse the bomb. Buy gear each round.", "Two teams, first to the kill target wins.", "Collect dog tags from fallen enemies.", "Every kill upgrades your weapon.", "Everyone for themselves.", "Hold zones A, B and C to score."]

    var body: some View {
        GeometryReader { g in
            let t = game.s.ex.tac ?? TacData()
            let colW = min(300, max(240, g.size.width * 0.34))
            ZStack {
                Color.black.ignoresSafeArea()
                if let b = bg {
                    TacSceneView(bridge: b).ignoresSafeArea().allowsHitTesting(false)
                    TimelineView(.animation) { tl in
                        Canvas { _, _ in b.orbit(tl.date.timeIntervalSinceReferenceDate) }
                    }
                    .frame(width: 1, height: 1).allowsHitTesting(false)
                }
                LinearGradient(colors: [Color.black.opacity(0.7), .clear, Color.black.opacity(0.5)], startPoint: .leading, endPoint: .trailing).ignoresSafeArea().allowsHitTesting(false)
                LinearGradient(colors: [Color.black.opacity(0.55), .clear, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 0) {
                    navBar(t)
                    HStack(alignment: .top, spacing: 12) {
                        leftPanel(t)
                        Spacer(minLength: 0)
                        rightPanel(colW)
                    }
                    .padding(.top, 10)
                    Spacer(minLength: 0)
                    bottomBar()
                }
                .padding(.horizontal, 14)
            }
        }
        .onAppear {
            OrientationLock.set(landscape: true)
            ensureBg()
            username = TacProfile.name
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
            TacSeasonView(startTab: seasonTab).environmentObject(game).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: Binding(get: { nav.tacPlay != nil }, set: { if !$0 { nav.tacPlay = nil } })) {
            TacticalPlay(diff: nav.tacPlay ?? 1, modeId: nav.tacMode).environmentObject(game).environmentObject(nav).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showAvatar) {
            AvatarStudioView().preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAdmin) {
            AdminRosterView().preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showStats) {
            statsSheet.preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showRanks) {
            TacRankSheet(t: game.s.ex.tac ?? TacData(), username: $username).preferredColorScheme(.dark)
        }
    }

    private func ensureBg() {
        guard bg == nil, nav.tacPlay == nil else { return }
        let b = TacScene()
        b.build(TacticalEngine())
        bg = b
    }

    // MARK: nav bar

    private func tab(_ icon: String, _ label: String, on: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 2) {
                SF(icon, "circle.fill").font(.system(size: 15, weight: .semibold))
                Text(label).font(.jk(9, .heavy)).tracking(1)
                Rectangle().fill(on ? lime : Color.clear).frame(height: 2).padding(.horizontal, 6)
            }
            .foregroundColor(on ? lime : .white.opacity(0.85))
            .frame(width: 54, height: 42)
        }
        .buttonStyle(TuiPress())
    }

    private func navBar(_ t: TacData) -> some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return HStack(spacing: 10) {
            Image("Splash").resizable().scaledToFit().frame(height: 42)
                .onLongPressGesture(minimumDuration: 1.5) { showAdmin = true }
            Button { showRanks = true } label: {
                HStack(spacing: 8) {
                    TacRankTile(idx: ri, size: 38, showName: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(username).font(.jk(14, .heavy)).foregroundColor(.white).lineLimit(1)
                        Text(TacRank.ranks[ri].name.uppercased()).font(.jk(9, .heavy)).tracking(1).foregroundColor(lime).lineLimit(1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(TUI.gold).frame(width: 96 * CGFloat(TacRank.progress(xp)))
                        }
                        .frame(width: 96, height: 3)
                    }
                    SF("chevron.down").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 8).frame(height: 46).tuiGlass(10, fill: 0.5)
            }
            .buttonStyle(TuiPress())
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                tab("house.fill", "HOME", on: true) {}
                tab("star.circle.fill", "SEASON") { seasonTab = 0; showSeason = true }
                tab("tshirt.fill", "LOCKER") { seasonTab = 1; showSeason = true }
                tab("gift.fill", "DRAW") { seasonTab = 2; showSeason = true }
                tab("person.crop.square.fill", "AVATAR") { showAvatar = true }
                tab("chart.bar.fill", "STATS") { showStats = true }
            }
            HStack(spacing: 6) {
                SF("diamond.fill", "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(TUI.gold)
                Text("\(game.s.ex.gems)").font(.jk(14, .heavy)).foregroundColor(.white)
            }
            .padding(.horizontal, 10).frame(height: 34).tuiGlass(17, fill: 0.5)
        }
        .padding(.top, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LinearGradient(colors: [lime.opacity(0.7), lime.opacity(0.05)], startPoint: .leading, endPoint: .trailing)).frame(height: 1).offset(y: 3)
        }
    }

    // MARK: left

    private func statLine(_ icon: String, _ v: String, _ label: String, _ col: Color) -> some View {
        HStack(spacing: 6) {
            SF(icon, "circle.fill").font(.system(size: 11, weight: .bold)).foregroundColor(col).frame(width: 16)
            Text(label).font(.jk(10, .heavy)).tracking(1).foregroundColor(.white.opacity(0.6))
            Spacer(minLength: 0)
            Text(v).font(.jk(13, .heavy)).foregroundColor(.white)
        }
    }

    private func leftPanel(_ t: TacData) -> some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let next = min(TacRank.ranks.count - 1, ri + 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                TacRankTile(idx: ri, size: 84, progress: TacRank.progress(xp))
                VStack(alignment: .leading, spacing: 5) {
                    Text(TacSeason.league(t.rating)).font(.jk(10, .heavy)).tracking(2).foregroundColor(lime)
                    statLine("scope", "\(t.kills)", "KILLS", TUI.gold)
                    statLine("trophy.fill", "\(t.wins)", "WINS", TUI.green)
                    statLine("xmark.circle.fill", "\(t.losses)", "LOSS", TUI.red)
                    statLine("shield.lefthalf.filled", "\(t.rating)", "RATING", TUI.blue)
                }
                .frame(width: 112)
            }
            Text(TacRank.toNext(xp) > 0 ? "\(TacRank.toNext(xp)) XP to \(TacRank.ranks[next].name)" : "MAX RANK")
                .font(.jk(10, .bold)).foregroundColor(.white.opacity(0.65)).lineLimit(1)
            Button { showRanks = true } label: {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<TacRank.ranks.count, id: \.self) { i in
                            TacRankTile(idx: i, size: 48, locked: i > ri, showName: false)
                                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(i == ri ? lime : Color.clear, lineWidth: 2))
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .buttonStyle(TuiPress())
        }
        .padding(10).frame(width: 232).tuiGlass(14, fill: 0.55)
    }

    // MARK: right

    private func matchTabBtn(_ label: String, _ i: Int) -> some View {
        Button { matchTab = i } label: {
            Text(label).font(.jk(11, .heavy)).tracking(1)
                .foregroundColor(matchTab == i ? .black : .white.opacity(0.8))
                .frame(maxWidth: .infinity).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(matchTab == i ? lime : Color.white.opacity(0.08)))
        }
        .buttonStyle(TuiPress())
    }

    private func rightPanel(_ w: CGFloat) -> some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    matchTabBtn("PUBLIC MATCH", 0)
                    matchTabBtn("CUSTOM MATCH", 1)
                }
                if matchTab == 0 {
                    HStack(spacing: 8) {
                        SF(modeIcons[nav.tacMode], "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(lime).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TWeapons.modeNames[nav.tacMode]).font(.jk(13, .heavy)).foregroundColor(.white)
                            Text(modeInfo[nav.tacMode]).font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.65)).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Text("5V5").font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 7).frame(height: 18).background(Capsule().fill(lime))
                    }
                    .padding(8).background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.07)))
                    HStack(spacing: 8) {
                        SF("house.fill", "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(lime).frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("THE HOUSE").font(.jk(12, .heavy)).tracking(1).foregroundColor(.white)
                            Text("Attic · Ground · Basement — breakable walls").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text("3 FLOORS").font(.jk(9, .heavy)).foregroundColor(.black).padding(.horizontal, 7).frame(height: 18).background(Capsule().fill(TUI.gold))
                    }
                    .padding(8).background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.07)))
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in
                            let on = nav.tacMode == i
                            Button { nav.tacMode = i } label: {
                                VStack(spacing: 3) {
                                    SF(modeIcons[i], "circle.fill").font(.system(size: 15, weight: .bold))
                                    Text(TWeapons.modeShort[i]).font(.jk(9, .heavy))
                                }
                                .foregroundColor(on ? .black : .white.opacity(0.85))
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? lime : Color.white.opacity(0.1)))
                            }
                            .buttonStyle(TuiPress())
                        }
                    }
                }
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        let on = diff == i
                        Button { diff = i } label: {
                            HStack(spacing: 4) {
                                SF(["gauge.low", "gauge.medium", "gauge.high"][i], "speedometer").font(.system(size: 11, weight: .bold))
                                Text(diffNames[i]).font(.jk(10, .heavy))
                            }
                            .foregroundColor(on ? .black : .white.opacity(0.8))
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .background(Capsule().fill(on ? Color.white : Color.white.opacity(0.1)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
            }
            .padding(10).frame(width: w).tuiGlass(14, fill: 0.55)
            Button { nav.tacPlay = diff } label: {
                HStack(spacing: 12) {
                    SF("play.fill", "play.circle.fill").font(.system(size: 20, weight: .bold))
                    Text("PLAY").font(.jk(28, .heavy)).tracking(3)
                }
                .foregroundColor(.black).frame(width: w, height: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: [lime, Color(red: 0.5, green: 0.9, blue: 0.3)], startPoint: .top, endPoint: .bottom)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
                .shadow(color: lime.opacity(0.35), radius: 12, y: 3)
            }
            .buttonStyle(TuiPress())
        }
    }

    // MARK: bottom

    private func bottomBar() -> some View {
        HStack(spacing: 8) {
            Text("GROUP 1/5").font(.jk(10, .heavy)).tracking(1).foregroundColor(.white.opacity(0.7))
            ForEach(0..<5, id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(i == 0 ? 0.12 : 0.05))
                    RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(i == 0 ? lime : Color.white.opacity(0.18), lineWidth: 1)
                    if i == 0 {
                        PortraitAvatar(key: TacAvatar.myKey, size: 30, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)
                    } else {
                        SF("plus", "circle.fill").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.3))
                    }
                }
                .frame(width: 36, height: 36)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 5).tuiGlass(12, fill: 0.55)
        .frame(width: 340, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var statsSheet: some View {
        let t = game.s.ex.tac ?? TacData()
        let rows: [(String, String, String, Color)] = [("trophy.fill", "Wins", "\(t.wins)", TUI.green), ("xmark.circle.fill", "Losses", "\(t.losses)", TUI.red), ("scope", "Kills", "\(t.kills)", TUI.gold), ("shield.lefthalf.filled", "Rating", "\(t.rating)", TUI.blue)]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SF("chart.bar.fill").font(.system(size: 22, weight: .bold)).foregroundColor(lime)
                Text("Stats").font(.jk(28, .heavy))
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 12) {
                    SF(r.0, "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(r.3).frame(width: 28)
                    Text(r.1).font(.jk(16, .bold))
                    Spacer()
                    Text(r.2).font(.jk(18, .heavy))
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button {
                var s2 = game.s
                s2.ex.tac = nil
                game.s = s2
            } label: {
                HStack(spacing: 8) {
                    SF("arrow.counterclockwise").font(.system(size: 14, weight: .bold))
                    Text("Reset stats").font(.jk(15, .bold))
                }
                .foregroundColor(.red).frame(maxWidth: .infinity).frame(height: 48).background(Color.red.opacity(0.15)).clipShape(Capsule())
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(T.bg.ignoresSafeArea())
    }
}
