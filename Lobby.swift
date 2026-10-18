import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var showSeason = false
    @State private var showStats = false
    @State private var showAvatar = false
    @State private var showAdmin = false
    @State private var bg: TacScene? = nil
    @State private var diff = 1
    @State private var seasonTab = 0

    private let lime = TUI.accent
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
    }

    private func ensureBg() {
        guard bg == nil, nav.tacPlay == nil else { return }
        let b = TacScene()
        b.build(TacticalEngine())
        bg = b
    }

    // MARK: top

    private func pill(_ icon: String, _ text: String, _ col: Color) -> some View {
        HStack(spacing: 7) {
            SF(icon, "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(col)
            Text(text).font(.jk(15, .heavy)).foregroundColor(.white)
        }
        .padding(.horizontal, 14).frame(height: 40).tuiGlass(20, fill: 0.5)
    }

    private func topBar(_ t: TacData) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                SF("scope", "circle.fill").font(.system(size: 17, weight: .bold)).foregroundColor(lime)
                Text("MAINSHOT").font(.jk(17, .heavy)).tracking(3).foregroundColor(.white)
            }
            .padding(.horizontal, 14).frame(height: 40).tuiGlass(20, fill: 0.5)
            .onLongPressGesture(minimumDuration: 1.5) { showAdmin = true }
            Spacer()
            pill("diamond.fill", "\(game.s.ex.gems)", TUI.gold)
        }
        .padding(.top, 8)
    }

    // MARK: left

    private func statTile(_ icon: String, _ v: String, _ label: String, _ col: Color) -> some View {
        VStack(spacing: 3) {
            SF(icon, "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(col)
            Text(v).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.white)
            Text(label).font(.jk(8, .heavy)).tracking(1).foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 74, height: 64).tuiGlass(12, fill: 0.5)
    }

    private func leftCards(_ t: TacData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SF("person.crop.circle.fill", "person.fill").font(.system(size: 40)).foregroundColor(.white.opacity(0.9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(TacSeason.league(t.rating)).font(.jk(10, .heavy)).tracking(2).foregroundColor(lime)
                    Text("\(t.rating)").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(.white)
                }
                Spacer(minLength: 0)
            }
            .padding(10).frame(width: 224).tuiGlass(16, fill: 0.55)
            HStack(spacing: 8) {
                statTile("scope", "\(t.kills)", "KILLS", TUI.gold)
                statTile("trophy.fill", "\(t.wins)", "WINS", TUI.green)
                statTile("xmark.circle.fill", "\(t.losses)", "LOSSES", TUI.red)
            }
        }
    }

    // MARK: right

    private let modeIcons = ["timer", "person.2.fill", "tag.fill", "arrow.up.forward.circle.fill", "person.3.fill", "flag.fill"]
    private let modeInfo = ["Plant or defuse the bomb. Buy gear each round.", "Two teams, first to the kill target wins.", "Collect dog tags from fallen enemies.", "Every kill upgrades your weapon.", "Everyone for themselves.", "Hold zones A, B and C to score."]

    private func rightColumn(_ t: TacData, _ w: CGFloat) -> some View {
        VStack(spacing: 8) {
            mapCard(w)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    SF(modeIcons[nav.tacMode], "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(lime)
                    Text(TWeapons.modeNames[nav.tacMode]).font(.jk(14, .heavy)).foregroundColor(.white)
                    Spacer()
                    Text("5V5").font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 7).frame(height: 18).background(Capsule().fill(lime))
                }
                Text(modeInfo[nav.tacMode]).font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.7)).lineLimit(2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in
                            let on = nav.tacMode == i
                            Button { nav.tacMode = i } label: {
                                VStack(spacing: 3) {
                                    SF(modeIcons[i], "circle.fill").font(.system(size: 15, weight: .bold))
                                    Text(TWeapons.modeShort[i]).font(.jk(8, .heavy))
                                }
                                .foregroundColor(on ? .black : .white.opacity(0.85))
                                .frame(width: 58, height: 46)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? lime : Color.white.opacity(0.1)))
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
                            .frame(maxWidth: .infinity).frame(height: 30)
                            .background(Capsule().fill(on ? Color.white : Color.white.opacity(0.1)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
            }
            .padding(12).frame(width: w).tuiGlass(18, fill: 0.55)
            Button { nav.tacPlay = diff } label: {
                HStack(spacing: 12) {
                    SF("play.fill", "play.circle.fill").font(.system(size: 22, weight: .bold))
                    Text("PLAY").font(.jk(32, .heavy)).tracking(3)
                }
                .foregroundColor(.black).frame(width: w, height: 64)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [lime, Color(red: 0.5, green: 0.9, blue: 0.3)], startPoint: .top, endPoint: .bottom)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
                .shadow(color: lime.opacity(0.35), radius: 12, y: 3)
            }
            .buttonStyle(TuiPress())
        }
    }

    private func mapCard(_ w: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SF("house.fill", "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(lime)
                Text("THE HOUSE").font(.jk(14, .heavy)).tracking(2).foregroundColor(.white)
                Spacer()
                Text("3 FLOORS").font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 7).frame(height: 18).background(Capsule().fill(TUI.gold))
            }
            HStack(spacing: 6) {
                ForEach([("ATTIC", "B SITE", TUI.orange), ("GROUND", "SPAWNS", TUI.blue), ("BASEMENT", "A SITE", TUI.red)], id: \.0) { f in
                    VStack(spacing: 2) {
                        Text(f.0).font(.jk(9, .heavy)).tracking(1).foregroundColor(.white)
                        Text(f.1).font(.jk(8, .heavy)).foregroundColor(f.2)
                    }
                    .frame(maxWidth: .infinity).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(f.2.opacity(0.5), lineWidth: 1))
                }
            }
            Text("Breakable walls and props. Stairs link all floors.").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.6))
        }
        .padding(12).frame(width: w).tuiGlass(18, fill: 0.55)
    }

    // MARK: bottom

    private func dockBtn(_ icon: String, _ label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 3) {
                SF(icon, "circle.fill").font(.system(size: 19, weight: .semibold))
                Text(label).font(.jk(9, .heavy)).tracking(1)
            }
            .foregroundColor(.white.opacity(0.92)).frame(width: 78, height: 52)
        }
        .buttonStyle(TuiPress())
    }

    private func bottomBar(_ w: CGFloat) -> some View {
        HStack(spacing: 2) {
            dockBtn("star.circle.fill", "SEASON") { seasonTab = 0; showSeason = true }
            dockBtn("person.crop.square.fill", "AVATAR") { showAvatar = true }
            dockBtn("tshirt.fill", "LOCKER") { seasonTab = 1; showSeason = true }
            dockBtn("gift.fill", "DRAW") { seasonTab = 2; showSeason = true }
            dockBtn("chart.bar.fill", "STATS") { showStats = true }
        }
        .padding(.horizontal, 6).tuiGlass(16, fill: 0.55)
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
