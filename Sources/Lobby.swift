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
                    case 7: CSGunsmith(back: { screen = 6 })
                    case 5: CSLeague(rating: t.rating, cash: game.s.ex.gems, coins: t.wins) { screen = 0 }
                    case 6:
                        CSLoadout(gun: $nav.tacGun, countdown: fromMatch ? cd : nil, showBattle: fromMatch, gunsmith: fromMatch ? nil : { screen = 7 }, ok: { if fromMatch { beginMatch() } else { screen = 4 } }, battle: { beginMatch() })
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
        TMap.load(nav.tacMode == 6 ? 1 : nav.tacMap)
        mapImg = TacRadar.image(1)
        loadP = 0
        screen = 3
    }

    // MARK: shared

    private func sq(_ w: CGFloat, _ h: CGFloat) -> some View { Color.clear.frame(width: w, height: h) }

    // MARK: home

    private func menuRow(_ icon: String, _ label: String, dot: Bool = false, col: Color = .white, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 8) {
                SF(icon, "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(col).frame(width: 22)
                Text(label).font(.jk(13, .heavy)).foregroundColor(col).lineLimit(1)
                if dot { Text("!").font(.jk(8, .heavy)).foregroundColor(.white).frame(width: 12, height: 12).background(Rectangle().fill(Color.red)).offset(y: -5) }
                Spacer(minLength: 0)
            }
            .frame(height: 20)
            .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
        }
        .buttonStyle(TuiPress())
    }

    private func homeScreen(_ t: TacData, _ size: CGSize) -> some View {
        TacLeague.myRating = t.rating
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let next = min(TacRank.ranks.count - 1, ri + 1)
        let W = size.width, H = size.height
        let rcw: CGFloat = 250
        return ZStack {
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: ri)
                .frame(width: W * 0.36, height: H * 0.9)
                .position(x: W * 0.5, y: H * 0.5)
                .allowsHitTesting(false)
            // top bar
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    Button { showStats = true } label: { SF("gearshape.2.fill", "gearshape.fill").font(.system(size: 20)).foregroundColor(.white) }.buttonStyle(TuiPress())
                    Button { showAdmin = true } label: { SF("envelope.fill").font(.system(size: 20)).foregroundColor(.white) }.buttonStyle(TuiPress())
                }
                .frame(width: 110, alignment: .leading)
                Spacer(minLength: 0)
                Button { showRanks = true } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            TacRankTile(idx: ri, size: 26, progress: TacRank.progress(xp), showName: false)
                            Text(username).font(.jk(13, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: 110)
                            LeagueBadge(rating: t.rating, size: 18)
                            Text("LEVEL \(ri + 1)" + ((t.prestige ?? 0) > 0 ? " P\(t.prestige ?? 0)" : "")).font(.jk(12, .heavy)).foregroundColor(.white).fixedSize()
                        }
                        ZStack {
                            Rectangle().fill(Color.white.opacity(0.18))
                            GeometryReader { gg in Rectangle().fill(Color(red: 0.2, green: 0.75, blue: 0.3)).frame(width: gg.size.width * CGFloat(TacRank.progress(xp))) }
                            Text("\(xp)/\(TacRank.ranks[next].xp)").font(.jk(9, .heavy)).foregroundColor(.white)
                        }
                        .frame(width: 220, height: 12)
                    }
                }
                .buttonStyle(TuiPress())
                Spacer(minLength: 0)
                CSCurrency(cash: game.s.ex.gems, coins: t.wins).frame(width: 150, alignment: .trailing)
            }
            .padding(.top, 6).padding(.horizontal, 4)
            .frame(width: W, height: 56, alignment: .top)
            .position(x: W / 2, y: 28)
            // left column
            VStack(alignment: .leading, spacing: 6) {
                Button { screen = 5 } label: {
                    HStack(spacing: 8) {
                        TacRankTile(idx: ri, size: 36, progress: TacRank.progress(xp), showName: false)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                SF("trophy.fill").font(.system(size: 11)).foregroundColor(CS.gold)
                                Text("\(t.rating)").font(.jk(14, .heavy)).foregroundColor(.white)
                            }
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.15))
                                Rectangle().fill(CS.blue).frame(width: 70 * CGFloat(TacRank.progress(xp)))
                            }
                            .frame(width: 70, height: 6)
                        }
                        Spacer(minLength: 0)
                        SF("shippingbox.fill", "gift.fill").font(.system(size: 26)).foregroundColor(CS.orange)
                    }
                    .padding(5).frame(width: 200).background(CS.panel.opacity(0.75)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
                Button { seasonTab = 0; showSeason = true } label: {
                    HStack {
                        Text("BATTLE PASS").font(.jk(9, .heavy)).foregroundColor(.black).padding(.horizontal, 5).padding(.vertical, 2).background(Rectangle().fill(CS.gold))
                        Spacer()
                        Text("\(min(110, t.sx?.xp ?? 0))/110").font(.jk(13, .heavy)).foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 6).frame(width: 200, height: 24).background(CS.panel.opacity(0.75)).overlay(Rectangle().stroke(CS.gold.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
                VStack(alignment: .leading, spacing: 1) {
                    menuRow("cart.fill", "SHOP", col: CS.orange) { seasonTab = 2; showSeason = true }
                    menuRow("scope", "MISSIONS") { seasonTab = 0; showSeason = true }
                    menuRow("person.3.fill", "FRIENDS") { showAdmin = true }
                    menuRow("shield.lefthalf.filled", "MY CLAN", dot: true) { showRanks = true }
                    menuRow("trophy.fill", "LEADERBOARD", dot: true) { showRanks = true }
                    menuRow("gift.fill", "DAILY REWARDS") { seasonTab = 2; showSeason = true }
                }
                .padding(.top, 4)
            }
            .frame(width: 210, height: 240, alignment: .topLeading)
            .position(x: 16 + 105, y: 58 + 120)
            // right column
            VStack(spacing: 6) {
                Button { nav.tacMode = 6; screen = 1 } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NEW MODE").font(.jk(9, .heavy)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Rectangle().fill(Color.red))
                            Text("BATTLE ROYALE").font(.jk(17, .heavy)).foregroundColor(CS.orange).lineLimit(1).minimumScaleFactor(0.7)
                            Text("20 players · woods + bunker").font(.jk(9, .bold)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        SF("scope", "circle.fill").font(.system(size: 40, weight: .bold)).foregroundColor(Color(red: 0.55, green: 0.9, blue: 0.2).opacity(0.9))
                    }
                    .padding(10).frame(width: rcw, height: 78)
                    .background(LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.08), Color.black], startPoint: .top, endPoint: .bottom))
                    .overlay(Rectangle().stroke(CS.orange, lineWidth: 1.5))
                }
                .buttonStyle(TuiPress())
                chestRow("scope", "\(t.kills % 50)/50", Color(red: 0.95, green: 0.2, blue: 0.5))
                chestRow("trophy.fill", "\(t.wins % 3)/3", Color(red: 0.1, green: 0.8, blue: 0.5))
            }
            .frame(width: rcw)
            .position(x: W - 16 - rcw / 2, y: 58 + 110)
            // bottom buttons
            CSButton(title: "ARSENAL", w: 180, h: 40, size: 18, dot: true) { showAvatar = true }
                .position(x: 16 + 90, y: H - 28)
            CSButton(title: "BATTLE", col: CS.orange, dark: CS.orangeDark, w: 180, h: 40, size: 20) { screen = 1 }
                .position(x: W - 16 - 90, y: H - 28)
        }
    }

    private func chestRow(_ icon: String, _ v: String, _ col: Color, w: CGFloat = 250) -> some View {
        HStack(spacing: 8) {
            SF("shippingbox.fill", "gift.fill").font(.system(size: 26)).foregroundColor(col)
            HStack(spacing: 6) {
                SF(icon, "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                Text(v).font(.jk(12, .heavy)).foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 8).frame(height: 22).frame(maxWidth: .infinity, alignment: .leading).background(Rectangle().fill(Color.white.opacity(0.14)))
        }
        .frame(width: w, height: 30)
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
                Text(TWeapons.modeNames[i]).font(.jk(13, .heavy)).foregroundColor(on ? col : .white)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.55).padding(.horizontal, 3).frame(height: 36).padding(.top, 4)
                Spacer(minLength: 0)
                ZStack {
                    Image(systemName: "hexagon.fill").resizable().scaledToFit().foregroundColor(col.opacity(on ? 0.35 : 0.15)).frame(width: w * 0.5)
                    SF(CS.modeIcons[i], "circle.fill").font(.system(size: w * 0.2, weight: .bold)).foregroundColor(on ? col : .white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Text(CS.modeInfo[i]).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8).padding(.horizontal, 4).frame(height: 24)
                HStack(spacing: 4) {
                    Text("\(r.0)").font(.jk(14, .heavy))
                    SF("circle.hexagongrid.fill", "circle.fill").font(.system(size: 12)).foregroundColor(CS.gold)
                    Text("PER WIN").font(.jk(10, .heavy)).opacity(0.8)
                }
                .foregroundColor(.white).padding(.top, 2)
                HStack(spacing: 4) {
                    Text("\(r.1)").font(.jk(14, .heavy))
                    SF("diamond.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.7, green: 0.35, blue: 1))
                    Text("PER WIN").font(.jk(10, .heavy)).opacity(0.8)
                }
                .foregroundColor(.white).padding(.vertical, 2).padding(.bottom, 4)
            }
            .overlay {
                if locked {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 4) {
                            SF("lock.fill").font(.system(size: 20)).foregroundColor(.white)
                            Text("REQUIRED LEVEL").font(.jk(8, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                            Text("\(lockLv)").font(.jk(18, .heavy)).foregroundColor(.white)
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
                Spacer(minLength: 4)
                HStack(spacing: 7) { ForEach(modeOrder, id: \.self) { modeCard($0, cw, max(150, H - 170)) } }
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
            .position(x: W / 2, y: H - 30)
            if nav.tacMode != 6 {
                HStack(spacing: 8) {
                    ForEach([0, 2, 3], id: \.self) { k in
                        Button { nav.tacMap = k } label: {
                            Text(TMap.mapNames[k]).font(.jk(11, .heavy)).foregroundColor(nav.tacMap == k ? .black : .white.opacity(0.85))
                                .padding(.horizontal, 12).frame(height: 28)
                                .background(Rectangle().fill(nav.tacMap == k ? CS.gold : Color.white.opacity(0.12)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
                .position(x: W / 2, y: H - 80)
            } else {
                Text("MAP: THE WOODS").font(.jk(11, .heavy)).foregroundColor(CS.gold).position(x: W / 2, y: H - 80)
            }
            CSButton(title: "CREATE SQUAD", w: 180, h: 40, size: 16) { showAdmin = true }.position(x: 100, y: H - 30)
            CSButton(title: "PLAY", col: CS.orange, dark: CS.orangeDark, w: 180, h: 42, size: 26) { searchT = 0; screen = 2 }
                .position(x: W - 110, y: H - 30)
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
            VStack(alignment: .leading, spacing: 5) {
                Text("WINNER CHEST").font(.jk(14, .heavy)).foregroundColor(.white)
                Text("Win matches to unlock the Winner Chest").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                chestRow("trophy.fill", "\(t.wins % 3)/3", Color(red: 0.1, green: 0.8, blue: 0.5), w: 200)
                Text("KILLER CHEST").font(.jk(14, .heavy)).foregroundColor(.white).padding(.top, 4)
                Text("Kill 50 enemies to unlock the Killer Chest").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                chestRow("scope", "\(t.kills % 50)/50", Color(red: 0.95, green: 0.2, blue: 0.5), w: 200)
            }
            .padding(12).frame(width: 232, alignment: .leading).background(Color.black.opacity(0.85)).overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .position(x: 16 + 116, y: H * 0.52)
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
                                Text(TMap.mapNames[woods ? 1 : nav.tacMap]).font(.jk(34, .heavy)).lineLimit(1).minimumScaleFactor(0.6).foregroundColor(.white)
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
                        Text(m == 6 ? tips[3] : tips[Int(loadP * 3) % 3]).font(.jk(14, .medium)).foregroundColor(.white.opacity(0.9)).lineLimit(2)
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
