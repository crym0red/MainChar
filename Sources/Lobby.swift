import SwiftUI
import Combine

struct LobbyView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var showSeason = false
    @State private var showStats = false
    @State private var showAvatar = false
    @State private var showAdmin = false
    @State private var showRanks = false
    @State private var diff = 1
    @State private var seasonTab = 0
    @State private var username = TacProfile.name
    @State private var screen = 0          // 0 home, 1 game mode, 2 battle search, 3 map loading
    @State private var searchT = 0
    @State private var loadP: CGFloat = 0
    @State private var mapImg: UIImage? = nil
    @State private var cd = 12
    @State private var fromMatch = false
    private let modeOrder = [1, 4, 5, 0, 3, 2, 6]
    private let modeLock = [4, 1, 6, 5, 1, 3, 1]

    private let lime = TUI.accent
    private let diffNames = ["EASY", "NORMAL", "HARD"]

    var body: some View {
        GeometryReader { g in
            let t = game.s.ex.tac ?? TacData()
            ZStack {
                CSBackdrop()
                Group {
                    switch screen {
                    case 1: modeScreen(t, g.size)
                    case 2: searchScreen(t, g.size)
                    case 3: loadingScreen(g.size)
                    case 4:
                        CSArsenal(gun: $nav.tacGun, rank: TacRank.index(TacRank.totalXP(t)), cash: game.s.ex.gems, coins: t.wins, back: { screen = 0 },
                                  editLoadout: { fromMatch = false; screen = 6 }, editChar: { showAvatar = true }, editCos: { seasonTab = 1; showSeason = true }, offer: { seasonTab = 2; showSeason = true })
                    case 5: CSLeague(rating: t.rating, cash: game.s.ex.gems, coins: t.wins) { screen = 0 }
                    case 6:
                        CSLoadout(gun: $nav.tacGun, countdown: fromMatch ? cd : nil, showBattle: fromMatch, ok: { if fromMatch { beginMatch() } else { screen = 4 } }, battle: { beginMatch() })
                    default: homeScreen(t, g.size)
                    }
                }
                .transition(.opacity)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if screen == 2 {
                searchT += 1
                if searchT >= 3 { startLoading() }
            }
            if screen == 6 && fromMatch {
                cd -= 1
                if cd <= 0 { beginMatch() }
            }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            if screen == 3 {
                loadP = min(1, loadP + 0.012 + CGFloat.random(in: 0...0.012))
                if loadP >= 1 { cd = 12; fromMatch = true; screen = 6 }
            }
        }
        .onAppear {
            OrientationLock.set(landscape: true)
            username = TacProfile.name
        }
        .onChange(of: nav.tacPlay) { v in
            if v == nil { OrientationLock.set(landscape: true); screen = 0 }
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
            TacRankSheet(t: game.s.ex.tac ?? TacData(), username: $username, onPrestige: { game.tacPrestige() }).preferredColorScheme(.dark)
        }
    }

    private func beginMatch() {
        fromMatch = false
        screen = 0
        nav.tacPlay = diff
    }

    private func startLoading() {
        TMap.load(nav.tacMode == 6 ? 1 : 0)
        mapImg = TacRadar.image(1)
        loadP = 0
        screen = 3
    }

    // MARK: shared

    private func sq(_ w: CGFloat, _ h: CGFloat) -> some View { Color.clear.frame(width: w, height: h) }

    private func menuRow(_ icon: String, _ label: String, dot: Bool = false, col: Color = .white, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 10) {
                SF(icon, "circle.fill").font(.system(size: 22, weight: .bold)).foregroundColor(col).frame(width: 34)
                Text(label).font(.jk(19, .heavy)).foregroundColor(col)
                if dot { Text("!").font(.jk(10, .heavy)).foregroundColor(.white).frame(width: 15, height: 15).background(Rectangle().fill(Color.red)).offset(y: -8) }
                Spacer(minLength: 0)
            }
            .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
        }
        .buttonStyle(TuiPress())
    }

    // MARK: home

    private func homeScreen(_ t: TacData, _ size: CGSize) -> some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let next = min(TacRank.ranks.count - 1, ri + 1)
        let W = size.width, H = size.height
        return ZStack {
            // character
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: ri)
                .frame(width: W * 0.46, height: H * 0.95)
                .position(x: W * 0.5, y: H * 0.55)
                .allowsHitTesting(false)
            // top bar
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    HStack(spacing: 14) {
                        Button { showStats = true } label: { SF("gearshape.2.fill", "gearshape.fill").font(.system(size: 26)).foregroundColor(.white) }.buttonStyle(TuiPress())
                        Button { showAdmin = true } label: { SF("envelope.fill").font(.system(size: 26)).foregroundColor(.white) }.buttonStyle(TuiPress())
                    }
                    .frame(width: 150, alignment: .leading)
                    Spacer()
                    Button { showRanks = true } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 12) {
                                TacRankTile(idx: ri, size: 34, progress: TacRank.progress(xp), showName: false)
                                Text(username).font(.jk(15, .heavy)).foregroundColor(.white).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                Text("LEVEL \(ri + 1)" + ((t.prestige ?? 0) > 0 ? "  P\(t.prestige ?? 0)" : "")).font(.jk(14, .heavy)).foregroundColor(.white)
                            }
                            ZStack {
                                Rectangle().fill(Color.white.opacity(0.18))
                                GeometryReader { gg in Rectangle().fill(Color(red: 0.2, green: 0.75, blue: 0.3)).frame(width: gg.size.width * CGFloat(TacRank.progress(xp))) }
                                Text("\(xp)/\(TacRank.ranks[next].xp)").font(.jk(10, .heavy)).foregroundColor(.white)
                            }
                            .frame(width: 250, height: 14)
                        }
                    }
                    .buttonStyle(TuiPress())
                    Spacer()
                    CSCurrency(cash: game.s.ex.gems, coins: t.wins).frame(width: 190, alignment: .trailing)
                }
                .padding(.top, 8)
                Spacer()
            }
            // left column
            VStack(alignment: .leading, spacing: 12) {
                Button { screen = 5 } label: {
                    HStack(spacing: 10) {
                        TacRankTile(idx: ri, size: 58, progress: TacRank.progress(xp), showName: false)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                SF("trophy.fill").font(.system(size: 13)).foregroundColor(CS.gold)
                                Text("\(t.rating)").font(.jk(16, .heavy)).foregroundColor(.white)
                            }
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.15))
                                Rectangle().fill(CS.blue).frame(width: 96 * CGFloat(TacRank.progress(xp)))
                            }
                            .frame(width: 96, height: 7)
                        }
                        SF("shippingbox.fill", "gift.fill").font(.system(size: 34)).foregroundColor(CS.orange)
                    }
                    .padding(8).background(CS.panel.opacity(0.75)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
                Button { seasonTab = 0; showSeason = true } label: {
                    HStack {
                        Text("BATTLE PASS").font(.jk(11, .heavy)).foregroundColor(.black).padding(.horizontal, 6).padding(.vertical, 3).background(Rectangle().fill(CS.gold)).rotationEffect(.degrees(-8))
                        Spacer()
                        Text("\(t.sx?.xp ?? 0)/110").font(.jk(15, .heavy)).foregroundColor(.white)
                        Spacer()
                    }
                    .padding(8).frame(width: 232).background(CS.panel.opacity(0.75)).overlay(Rectangle().stroke(CS.gold.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
                VStack(alignment: .leading, spacing: 11) {
                    menuRow("cart.fill", "SHOP", col: CS.orange) { seasonTab = 2; showSeason = true }
                    menuRow("scope", "MISSIONS") { seasonTab = 0; showSeason = true }
                    menuRow("person.3.fill", "FRIENDS") { showAdmin = true }
                    menuRow("shield.lefthalf.filled", "MY CLAN", dot: true) { showRanks = true }
                    menuRow("trophy.fill", "LEADERBOARD", dot: true) { showRanks = true }
                    menuRow("gift.fill", "DAILY REWARDS") { seasonTab = 2; showSeason = true }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 52).padding(.leading, 6)
            .frame(width: 250, height: H, alignment: .topLeading)
            .position(x: 131, y: H / 2)
            // right column
            VStack(spacing: 10) {
                Button { nav.tacMode = 6; screen = 1 } label: {
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.08), Color.black], startPoint: .top, endPoint: .bottom)
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NEW MODE").font(.jk(11, .heavy)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3).background(Rectangle().fill(Color.red))
                                Text("BATTLE\nROYALE").font(.jk(24, .heavy)).foregroundColor(CS.orange).lineSpacing(-4)
                                Text("20 players · woods + bunker").font(.jk(10, .bold)).foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            SF("scope", "circle.fill").font(.system(size: 62, weight: .bold)).foregroundColor(Color(red: 0.55, green: 0.9, blue: 0.2).opacity(0.9))
                        }
                        .padding(12)
                    }
                    .frame(width: 270, height: 112)
                    .overlay(Rectangle().stroke(CS.orange, lineWidth: 1.5))
                }
                .buttonStyle(TuiPress())
                chestRow("skull.fill", "\(t.kills % 50)/50", Color(red: 0.95, green: 0.2, blue: 0.5))
                chestRow("trophy.fill", "\(t.wins % 3)/3", Color(red: 0.1, green: 0.8, blue: 0.5))
                Spacer(minLength: 0)
            }
            .padding(.top, 58)
            .frame(width: 270, height: H, alignment: .top)
            .position(x: W - 150, y: H / 2)
            // event icons
            Button { seasonTab = 2; showSeason = true } label: {
                Text("SPIN").font(.system(size: 30, weight: .black, design: .rounded)).italic().foregroundStyle(LinearGradient(colors: [CS.gold, Color.cyan], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .topTrailing) { Text("!").font(.jk(10, .heavy)).foregroundColor(.white).frame(width: 14, height: 14).background(Rectangle().fill(Color.red)).offset(x: 8, y: -6) }
            }
            .buttonStyle(TuiPress()).position(x: W * 0.69, y: H * 0.56)
            Button { showAdmin = true } label: {
                ZStack {
                    Circle().fill(Color(red: 0.05, green: 0.15, blue: 0.1)).frame(width: 52, height: 52).overlay(Circle().stroke(Color.green, lineWidth: 2))
                    SF("person.fill.viewfinder", "person.fill").font(.system(size: 24)).foregroundColor(.white)
                    Text("CS HUB").font(.jk(9, .heavy)).foregroundColor(.white).offset(y: 31)
                }
            }
            .buttonStyle(TuiPress()).position(x: W * 0.66, y: H * 0.7)
            HStack(spacing: 8) {
                Button { seasonTab = 2; showSeason = true } label: { CSHex(icon: "rectangle.stack.fill", col: CS.gold, size: 54) }.buttonStyle(TuiPress())
                Button { seasonTab = 2; showSeason = true } label: { CSHex(icon: "gift.fill", col: .white, size: 54) }.buttonStyle(TuiPress())
                Button { seasonTab = 0; showSeason = true } label: { CSHex(icon: "shippingbox.fill", col: .cyan, size: 54, dot: true) }.buttonStyle(TuiPress())
            }
            .position(x: W - 150, y: H * 0.69)
            Button { seasonTab = 2; showSeason = true } label: {
                ZStack {
                    Image(systemName: "hexagon.fill").resizable().scaledToFit().foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.0)).frame(width: 78, height: 78)
                    Image(systemName: "hexagon").resizable().scaledToFit().foregroundColor(CS.gold).frame(width: 78, height: 78)
                    VStack(spacing: 0) {
                        Text("FREE").font(.jk(9, .heavy)).foregroundColor(.white)
                        SF("shippingbox.fill", "gift.fill").font(.system(size: 28)).foregroundColor(.red)
                        Text("SUPER CHEST").font(.jk(6, .heavy)).foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(TuiPress()).position(x: W * 0.5, y: H - 44)
            Text("SEASONAL\nDRAW").font(.system(size: 15, weight: .black, design: .rounded)).italic().foregroundColor(CS.orange).multilineTextAlignment(.center).position(x: W * 0.5 - 150, y: H - 40)
            Text("LUCKY\nDRAW").font(.system(size: 15, weight: .black, design: .rounded)).italic().foregroundColor(Color(red: 0.7, green: 0.5, blue: 1)).multilineTextAlignment(.center).position(x: W * 0.5 + 130, y: H - 40)
            SF("gift.fill").font(.system(size: 28)).foregroundColor(CS.gold).position(x: W - 290, y: H - 38)
            VStack(spacing: 0) {
                SF("exclamationmark.triangle.fill").font(.system(size: 26)).foregroundColor(.red)
                Text("INACTIVE").font(.jk(7, .heavy)).foregroundColor(.white)
            }
            .position(x: W - 340, y: H - 38)
            // bottom buttons
            CSButton(title: "ARSENAL", w: 190, h: 46, size: 22, dot: true) { showAvatar = true }
                .position(x: 112, y: H - 36)
            CSButton(title: "BATTLE", col: CS.orange, dark: CS.orangeDark, w: 190, h: 46, size: 24) { screen = 1 }
                .position(x: W - 120, y: H - 36)
        }
    }

    private func chestRow(_ icon: String, _ v: String, _ col: Color) -> some View {
        HStack(spacing: 8) {
            SF("shippingbox.fill", "gift.fill").font(.system(size: 36)).foregroundColor(col)
            HStack(spacing: 6) {
                SF(icon, "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Text(v).font(.jk(13, .heavy)).foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 8).frame(height: 26).background(Rectangle().fill(Color.white.opacity(0.14)))
            Spacer(minLength: 0)
        }
        .frame(width: 270)
    }

    // MARK: game mode

    private func modeCard(_ i: Int, _ w: CGFloat, _ h: CGFloat) -> some View {
        let on = nav.tacMode == i
        let col = CS.modeCols[i]
        let r = CS.modeReward[i]
        let lockLv = modeLock[i]
        let locked = TacRank.index(TacRank.totalXP(game.s.ex.tac ?? TacData())) + 1 < lockLv
        return Button { if !locked { nav.tacMode = i } } label: {
            VStack(spacing: 0) {
                Text(TWeapons.modeNames[i]).font(.jk(15, .heavy)).foregroundColor(on ? col : .white)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7).frame(height: 42).padding(.top, 8)
                Spacer(minLength: 0)
                ZStack {
                    Image(systemName: "hexagon.fill").resizable().scaledToFit().foregroundColor(col.opacity(on ? 0.35 : 0.15)).frame(width: w * 0.62)
                    SF(CS.modeIcons[i], "circle.fill").font(.system(size: w * 0.26, weight: .bold)).foregroundColor(on ? col : .white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Text(CS.modeInfo[i]).font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).lineLimit(2).padding(.horizontal, 8).frame(height: 28)
                HStack(spacing: 4) {
                    Text("\(r.0)").font(.jk(14, .heavy))
                    SF("circle.hexagongrid.fill", "circle.fill").font(.system(size: 12)).foregroundColor(CS.gold)
                    Text("PER WIN").font(.jk(10, .heavy)).opacity(0.8)
                }
                .foregroundColor(.white).padding(.top, 4)
                HStack(spacing: 4) {
                    Text("\(r.1)").font(.jk(14, .heavy))
                    SF("diamond.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.7, green: 0.35, blue: 1))
                    Text("PER WIN").font(.jk(10, .heavy)).opacity(0.8)
                }
                .foregroundColor(.white).padding(.vertical, 4).padding(.bottom, 6)
            }
            .overlay {
                if locked {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 4) {
                            SF("lock.fill").font(.system(size: 24)).foregroundColor(.white)
                            Text("REQUIRED LEVEL").font(.jk(9, .heavy)).foregroundColor(.white)
                            Text("\(lockLv)").font(.jk(20, .heavy)).foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(width: w, height: h)
            .background(LinearGradient(colors: on ? [Color(red: 0.3, green: 0.36, blue: 0.46), Color(red: 0.12, green: 0.15, blue: 0.22)] : [Color(red: 0.1, green: 0.13, blue: 0.2), Color(red: 0.04, green: 0.05, blue: 0.09)], startPoint: .top, endPoint: .bottom))
            .overlay(Rectangle().stroke(on ? col : Color.white.opacity(0.15), lineWidth: on ? 2 : 1))
            .shadow(color: on ? col.opacity(0.45) : .clear, radius: 10)
        }
        .buttonStyle(TuiPress())
    }

    private func modeScreen(_ t: TacData, _ size: CGSize) -> some View {
        let W = size.width, H = size.height
        let cw = min(140, (W - 60 - 6 * 7) / 7)
        return ZStack {
            VStack(spacing: 0) {
                CSHeader(title: "GAME MODE", cash: game.s.ex.gems, coins: t.wins) { screen = 0 }.padding(.top, 8)
                Spacer(minLength: 8)
                HStack(spacing: 7) { ForEach(modeOrder, id: \.self) { modeCard($0, cw, H * 0.6) } }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Button { diff = i } label: {
                        Text(diffNames[i]).font(.jk(12, .heavy)).foregroundColor(diff == i ? .black : .white.opacity(0.85))
                            .frame(width: 78, height: 30)
                            .background(Rectangle().fill(diff == i ? Color.white : Color.white.opacity(0.12)))
                    }
                    .buttonStyle(TuiPress())
                }
            }
            .position(x: W / 2, y: H - 36)
            CSButton(title: "CREATE SQUAD", w: 190, h: 44, size: 16) { showAdmin = true }.position(x: 90, y: H - 36)
            CSButton(title: "PLAY", col: CS.orange, dark: CS.orangeDark, w: 190, h: 46, size: 26) { searchT = 0; screen = 2 }
                .position(x: W - 120, y: H - 36)
        }
        .padding(.horizontal, 6)
    }

    // MARK: battle search

    private func searchScreen(_ t: TacData, _ size: CGSize) -> some View {
        let W = size.width, H = size.height
        let ri = TacRank.index(TacRank.totalXP(t))
        return ZStack {
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: ri)
                .frame(width: W * 0.4, height: H * 0.92).position(x: W * 0.5, y: H * 0.58).allowsHitTesting(false)
            HStack(spacing: 14) {
                Circle().fill(CS.modeCols[nav.tacMode].opacity(0.3)).frame(width: 54, height: 54)
                    .overlay(SF(CS.modeIcons[nav.tacMode], "circle.fill").font(.system(size: 24, weight: .bold)).foregroundColor(CS.modeCols[nav.tacMode]))
                VStack(alignment: .leading, spacing: 0) {
                    Text("BATTLE SEARCH").font(.jk(22, .heavy)).foregroundColor(.white)
                    Text(TWeapons.modeNames[nav.tacMode]).font(.jk(17, .heavy)).foregroundColor(CS.modeCols[nav.tacMode])
                }
                Text(String(format: "00:%02d", searchT)).font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundColor(.white).monospacedDigit()
            }
            .padding(.horizontal, 16).padding(.vertical, 8).background(Color.black.opacity(0.85)).overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            .position(x: W / 2, y: 52)
            VStack(alignment: .leading, spacing: 10) {
                Text("WINNER CHEST").font(.jk(17, .heavy)).foregroundColor(.white)
                Text("Get 1 victories to unlock Winner Chest").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.8))
                chestRow("trophy.fill", "\(t.wins % 3)/3", Color(red: 0.1, green: 0.8, blue: 0.5)).frame(width: 220)
                Text("KILLER CHEST").font(.jk(17, .heavy)).foregroundColor(.white)
                Text("Kill 50 enemies to unlock Killer Chest").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.8))
                chestRow("skull.fill", "\(t.kills % 50)/50", Color(red: 0.95, green: 0.2, blue: 0.5)).frame(width: 220)
            }
            .padding(14).frame(width: 250).background(Color.black.opacity(0.85)).overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .position(x: 140, y: H * 0.56)
            VStack(alignment: .leading, spacing: 6) {
                Text("BEST PLAYERS OF THE DAY").font(.jk(14, .heavy)).foregroundColor(.white)
                ForEach(0..<5, id: \.self) { i in
                    let nm = TacRoster.pool[i].name
                    let cols: [Color] = [Color(red: 0.75, green: 0.6, blue: 0.1), Color(red: 0.55, green: 0.57, blue: 0.62), Color(red: 0.8, green: 0.45, blue: 0.15), Color(red: 0.2, green: 0.22, blue: 0.27), Color(red: 0.2, green: 0.22, blue: 0.27)]
                    HStack(spacing: 8) {
                        Rectangle().fill(Color.white.opacity(0.85)).frame(width: 44, height: 28).overlay(Text("\(i + 1)").font(.jk(14, .heavy)).foregroundColor(.black))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(nm).font(.jk(13, .heavy)).foregroundColor(i < 3 ? CS.gold : .white).lineLimit(1)
                            Text("Score \(5200 - i * 520)").font(.jk(10, .heavy)).foregroundColor(.white)
                        }
                        Spacer(minLength: 0)
                        Text("\(50 - i * 5)").font(.jk(12, .heavy)).foregroundColor(CS.gold)
                    }
                    .padding(.horizontal, 6).frame(width: 240, height: 40).background(cols[i]).overlay(Rectangle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                }
            }
            .position(x: W - 135, y: H * 0.6)
            Text("Americas 37").font(.jk(11, .heavy)).foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.3)).position(x: W - 50, y: 14)
            CSButton(title: "CANCEL", w: 150, h: 44, size: 18) { screen = 1 }.position(x: 100, y: H - 34)
        }
    }

    // MARK: loading

    private func loadingScreen(_ size: CGSize) -> some View {
        let W = size.width, H = size.height
        let woods = nav.tacMode == 6
        let m = nav.tacMode
        let tips = ["Pistols are very useful weapons that can save you from a lot of trouble.", "Walls and props can be shot apart. Break cover to flush enemies out.", "Doors can be closed to slow pushes and hide sound.", "The storm shrinks toward the bunker. Best loot is underground."]
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                SF("info.circle.fill").font(.system(size: 24)).foregroundColor(.white)
                Text("Battle and make your way to the top of the leaderboard for better prizes.").font(.jk(14, .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).frame(height: 50).background(Color.black.opacity(0.88)).overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Color.black
                        if let im = mapImg { Image(uiImage: im).resizable().scaledToFit().padding(10).opacity(0.9) }
                    }
                    .frame(width: W * 0.4, height: H * 0.56)
                    .overlay(Rectangle().stroke(CS.blue.opacity(0.8), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(woods ? "THE WOODS" : "THE HOUSE").font(.jk(34, .heavy)).foregroundColor(.white)
                                Text(TWeapons.modeNames[m]).font(.jk(22, .heavy)).foregroundColor(CS.modeCols[m])
                            }
                            Spacer()
                            SF(CS.modeIcons[m], "circle.fill").font(.system(size: 40, weight: .bold)).foregroundColor(CS.modeCols[m])
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• \(m == 6 ? "Last player alive wins" : (m == 0 ? "First to 3 rounds wins" : "First to the kill target wins"))")
                            Text("• \(m == 6 ? "Storm closes in on the bunker" : "5 minutes time limit")")
                            Text("• Up to \(m == 6 ? 20 : 10) players")
                        }
                        .font(.jk(14, .semibold)).foregroundColor(.white).padding(.top, 8)
                        Spacer(minLength: 0)
                        Text(tips[Int(loadP * 10) % tips.count]).font(.jk(14, .medium)).foregroundColor(.white.opacity(0.9)).lineLimit(2)
                    }
                    .frame(maxHeight: H * 0.56)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Map is loading").font(.jk(16, .semibold)).foregroundColor(.white)
                    GeometryReader { gg in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.22))
                            Rectangle().fill(Color(red: 0.1, green: 0.8, blue: 0.2)).frame(width: gg.size.width * loadP)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(14).background(Color.black.opacity(0.88)).overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.top, 10)
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
