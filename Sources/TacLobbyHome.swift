import SwiftUI

/// small painted card art: 0 harbor, 1 town, 2 industrial / extraction
struct MiniArt: View {
    var desert = false
    var variant = 0

    var body: some View {
        let v = desert ? 1 : variant
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let sky: [Color] = v == 1 ? [Color(red: 0.45, green: 0.62, blue: 0.82), Color(red: 0.98, green: 0.8, blue: 0.55)] : [Color(red: 0.3, green: 0.5, blue: 0.8), Color(red: 0.98, green: 0.78, blue: 0.52)]
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
            if v == 1 {
                let wall: [Color] = [Color(red: 0.78, green: 0.62, blue: 0.42), Color(red: 0.66, green: 0.52, blue: 0.36), Color(red: 0.86, green: 0.72, blue: 0.5)]
                for i in 0..<7 {
                    let bw = w / 7
                    let bh = h * (0.3 + 0.16 * CGFloat((i * 5) % 4))
                    let x = bw * CGFloat(i)
                    ctx.fill(Path(CGRect(x: x, y: h - bh - 4, width: bw - 1, height: bh + 4)), with: .color(wall[i % 3]))
                    ctx.fill(Path(CGRect(x: x + bw * 0.2, y: h - bh + 3, width: bw * 0.22, height: 4)), with: .color(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.7)))
                    ctx.fill(Path(CGRect(x: x + bw * 0.58, y: h - bh + 3, width: bw * 0.22, height: 4)), with: .color(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.7)))
                }
                ctx.fill(Path(CGRect(x: 0, y: h - 6, width: w, height: 6)), with: .color(Color(red: 0.55, green: 0.45, blue: 0.33)))
            } else if v == 2 {
                ctx.fill(Path(CGRect(x: 0, y: h * 0.64, width: w, height: h * 0.1)), with: .color(Color(red: 0.2, green: 0.32, blue: 0.45)))
                for i in 0..<4 {
                    let bw = w * 0.2
                    let x = w * (0.04 + 0.24 * CGFloat(i))
                    let bh = h * (0.28 + 0.1 * CGFloat(i % 2))
                    ctx.fill(Path(CGRect(x: x, y: h * 0.72 - bh, width: bw, height: bh)), with: .color(Color(red: 0.42, green: 0.45, blue: 0.5)))
                    ctx.fill(Path(CGRect(x: x - 2, y: h * 0.72 - bh - 3, width: bw + 4, height: 4)), with: .color(Color(red: 0.3, green: 0.32, blue: 0.38)))
                }
                for (i, c) in HarborArt.boxCols.prefix(6).enumerated() {
                    HarborArt.box(ctx, w * CGFloat(i) / 6, h * 0.72, w / 6 - 1, h * 0.28, c)
                }
            } else {
                ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.12)), with: .color(Color(red: 0.22, green: 0.38, blue: 0.52)))
                for cx in [0.2, 0.55, 0.88] as [CGFloat] {
                    HarborArt.crane(ctx, x: w * cx, top: h * 0.14, base: h * 0.74, s: max(0.3, h / 110))
                }
                var i = 0
                for gx in stride(from: CGFloat(0), to: w, by: max(9, w / 12)) {
                    let rows = 1 + (i * 7) % 3
                    for r in 0..<rows {
                        HarborArt.box(ctx, gx, h * 0.76 - CGFloat(r) * h * 0.14, max(8, w / 12 - 1), h * 0.13, HarborArt.boxCols[(i + r) % HarborArt.boxCols.count])
                    }
                    i += 1
                }
                ctx.fill(Path(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.24)), with: .color(Color(red: 0.45, green: 0.37, blue: 0.3)))
            }
        }
    }
}

/// PLAY page content (rendered inside LobbyShell)
struct LobbyHome: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void
    @State private var tab = 0
    private static var didDefault = false

    private let diffNames = ["EASY", "NORMAL", "HARD"]

    private func tile(_ icon: String, _ title: String, _ sub: String, _ col: Color, _ w: CGFloat, art: Int, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            ZStack(alignment: .bottomLeading) {
                MiniArt(variant: art).opacity(0.7)
                LinearGradient(colors: [col.opacity(0.3), Color.black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 1) {
                    SF(icon, "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 26, height: 26).background(Color.black.opacity(0.4))
                    Spacer(minLength: 0)
                    Text(title).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(sub).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.8)).lineLimit(2).minimumScaleFactor(0.6).fixedSize(horizontal: false, vertical: true)
                }
                .padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: w, height: 66)
            .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func modeCard(_ mode: Int, _ icon: String, _ title: String, _ l1: String, _ l2: String, art: Int = 0, _ h: CGFloat) -> some View {
        let on = nav.tacMode == mode
        return Button { nav.tacMode = mode } label: {
            ZStack {
                HStack(spacing: 0) {
                    Color(red: 0.05, green: 0.08, blue: 0.13)
                    MiniArt(variant: art).frame(width: 190).mask(LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .init(x: 0.45, y: 0.5)))
                }
                HStack(spacing: 10) {
                    SF(icon, "circle.fill").font(.system(size: 21, weight: .bold)).foregroundColor(.white).frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.jk(15, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                        Text(l1).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(l2).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                    SF("chevron.right", "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                }
                .padding(.horizontal, 8)
            }
            .frame(height: h)
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(TuiPress())
    }

    private func tabBtn(_ i: Int, _ label: String) -> some View {
        Button { tab = i } label: {
            Text(label).font(.jk(13, .heavy)).foregroundColor(tab == i ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity).frame(height: 32)
                .background(tab == i ? LS.orange.opacity(0.22) : Color.clear)
                .overlay(alignment: .bottom) { Rectangle().fill(tab == i ? LS.orange : .clear).frame(height: 3) }
        }
        .buttonStyle(TuiPress())
    }

    private var mapTitle: String {
        switch nav.tacMode {
        case 7: return "Harbor"
        case 6: return "Harbor Complex"
        default: return TMap.mapNames[nav.tacMap].capitalized
        }
    }

    private var mapSub: String {
        switch nav.tacMode {
        case 7: return "Frontline · 5 Capture Points"
        case 6: return "Extraction · Huge map"
        default: return TWeapons.modeNames[min(nav.tacMode, TWeapons.modeNames.count - 1)].capitalized
        }
    }

    private func mapCard() -> some View {
        ZStack(alignment: .bottomLeading) {
            MiniArt(variant: (nav.tacMode == 7 || nav.tacMode == 6) ? 0 : 1)
            LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            if nav.tacMode == 7 {
                GeometryReader { g in
                    ForEach(0..<5, id: \.self) { i in
                        FrontPoint(letter: TFront.letters[i], prog: i < 2 ? 1 : (i > 2 ? -1 : 0), size: 17)
                            .position(x: g.size.width * [0.14, 0.34, 0.52, 0.8, 0.68][i], y: g.size.height * [0.5, 0.36, 0.55, 0.42, 0.7][i])
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENT MAP").font(.jk(8, .heavy)).foregroundColor(.white)
                Spacer(minLength: 0)
                Text(mapTitle).font(.jk(17, .heavy)).foregroundColor(.white).lineLimit(1)
                Text(mapSub).font(.jk(9, .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
            }
            .padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 74, maxHeight: .infinity).clipped()
        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
    }

    private func squadRow(_ face: AnyView, _ name: String, _ tag: String) -> some View {
        HStack(spacing: 7) {
            face.frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1)
                if !tag.isEmpty { Text(tag).font(.jk(7, .heavy)).foregroundColor(TUI.green) }
            }
            Spacer(minLength: 0)
            Circle().fill(TUI.green).frame(width: 5, height: 5)
        }
        .padding(.horizontal, 7).frame(height: 28).background(Color.black.opacity(0.5))
        .overlay(alignment: .leading) { Rectangle().fill(TUI.green).frame(width: 2) }
    }

    private func boxIcon(_ i: String) -> AnyView {
        AnyView(SF(i, "circle.fill").font(.system(size: 11, weight: .bold)).foregroundColor(.white).frame(width: 22, height: 22).background(Color.white.opacity(0.14)))
    }

    var body: some View {
        let W = size.width, H = size.height
        let rp = min(380, W * 0.47)
        let rpH = H - 10
        let ch = max(36, min(54, (rpH - 32 - 74 - 40 - 22 - 36) / 3))
        let leftW = W - rp - 18
        let xp = TacRank.totalXP(t)
        return ZStack {
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: TacRank.index(xp), gun: nav.tacGun)
                .frame(width: leftW * 0.8, height: H * 0.98)
                .position(x: leftW * 0.62, y: H * 0.5)
                .allowsHitTesting(false)
            // nameplate above the character: username, league, rank, trophies
            Button { act(.screen(5)) } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Text(TacProfile.name).font(.jk(15, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                        LeagueBadge(rating: t.rating, size: 17)
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            SF("trophy.fill").font(.system(size: 10, weight: .bold)).foregroundColor(TacLeague.color(t.rating))
                            Text("\(t.rating)").font(.jk(11, .heavy)).foregroundColor(.white).monospacedDigit()
                        }
                        Text(TacLeague.name(t.rating)).font(.jk(10, .heavy)).foregroundColor(TacLeague.color(t.rating))
                        Text(TacRank.ranks[TacRank.index(xp)].name.uppercased()).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            }
            .buttonStyle(TuiPress())
            .position(x: leftW * 0.62, y: 26)
            // squad + chat
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text("SQUAD 1/4").font(.jk(11, .heavy)).foregroundColor(.white)
                        Spacer()
                        SF("xmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 8).frame(height: 22).background(LS.navy.opacity(0.9))
                    squadRow(AnyView(ZStack(alignment: .top) { PortraitAvatar(key: TacAvatar.myKey, size: 22, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy); SF("crown.fill").font(.system(size: 8, weight: .bold)).foregroundColor(Color(red: 1, green: 0.8, blue: 0.2)).offset(y: -6) }), TacProfile.name, "Leader")
                    squadRow(boxIcon("cross.fill"), "Medic_02", "")
                    squadRow(boxIcon("scope"), "Sniper_03", "")
                    Button { act(.friends) } label: {
                        HStack(spacing: 7) {
                            SF("plus").font(.system(size: 11, weight: .bold)).foregroundColor(.white).frame(width: 22, height: 22).background(Color.white.opacity(0.14))
                            Text("Invite Player").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.horizontal, 7).frame(height: 28).background(Color.black.opacity(0.5))
                    }
                    .buttonStyle(TuiPress())
                }
                .frame(width: 150)
                .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                Button { act(.friends) } label: {
                    HStack(spacing: 7) {
                        SF("bubble.left.fill").font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                        Text("Tap to chat...").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 8).frame(width: 220, height: 26).background(LS.navy.opacity(0.85)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
            .position(x: 8 + 110, y: H - 8 - 66 - 8 - 78)
            // bottom tiles
            HStack(spacing: 5) {
                tile("wrench.fill", "WORKSHOP", "Create & play custom guns and maps", LS.orange, leftW * 0.4, art: 2) { act(.nav(3)) }
                tile("bubble.left.and.bubble.right.fill", "JOIN OUR DISCORD", "Get updates, share creations, find squads", Color(red: 0.35, green: 0.4, blue: 0.95), leftW * 0.32, art: 1) { act(.friends) }
                tile("gift.fill", "DAILY REWARDS", "Log in for free rewards", Color(red: 0.95, green: 0.7, blue: 0.15), leftW * 0.28 - 10, art: 0) { act(.season(0)) }
            }
            .position(x: 8 + leftW / 2, y: H - 8 - 33)
            // right panel
            VStack(spacing: 5) {
                HStack(spacing: 0) { tabBtn(0, "MODES"); tabBtn(1, "MAPS"); tabBtn(2, "SERVER") }
                    .background(LS.navy.opacity(0.9))
                if tab == 0 {
                    modeCard(7, "shield.lefthalf.filled", "FRONTLINE", "Large scale battle · 100 bots", "Capture points · Tickets · Squads", ch)
                    modeCard(1, "person.2.fill", "5v5", "Team Deathmatch · 5v5", "Fast paced · Small maps", art: 1, ch)
                    modeCard(6, "bag.fill", "EXTRACTION", "Loot · Survive · Extract", "Large map · AI + Players", art: 2, ch)
                    Button { act(.screen(1)) } label: {
                        HStack(spacing: 4) {
                            Text("MORE MODES").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.85))
                            SF("chevron.right", "circle.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity).frame(height: 20).background(Color.white.opacity(0.08))
                    }
                    .buttonStyle(TuiPress())
                } else if tab == 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        if nav.tacMode == 7 || nav.tacMode == 6 {
                            Text("MAP: HARBOR").font(.jk(11, .heavy)).foregroundColor(LS.orange)
                        } else {
                            ForEach([0, 2, 3, 5], id: \.self) { k in
                                Button { nav.tacMap = k } label: {
                                    HStack {
                                        Text(TMap.mapNames[k]).font(.jk(12, .heavy)).foregroundColor(nav.tacMap == k ? .black : .white)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10).frame(height: 28)
                                    .background(Rectangle().fill(nav.tacMap == k ? LS.orange : Color.white.opacity(0.12)))
                                }
                                .buttonStyle(TuiPress())
                            }
                        }
                        if nav.tacMode == 7 {
                            Text("CLASS").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.6)).padding(.top, 4)
                            FrontClassPicker()
                            Text(TFront.classInfo[min(4, TacticalEngine.flClass)]).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.45))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(TUI.green).frame(width: 8, height: 8)
                            Text("OFFLINE · BOTS").font(.jk(12, .heavy)).foregroundColor(.white)
                        }
                        Text("BOT DIFFICULTY").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.6))
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Button { diff = i } label: {
                                    Text(diffNames[i]).font(.jk(11, .heavy)).foregroundColor(diff == i ? .black : .white.opacity(0.85))
                                        .frame(maxWidth: .infinity).frame(height: 28)
                                        .background(Rectangle().fill(diff == i ? Color.white : Color.white.opacity(0.12)))
                                }
                                .buttonStyle(TuiPress())
                            }
                        }
                    }
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.45))
                }
                mapCard()
                Button { act(.screen(2)) } label: {
                    HStack {
                        Spacer()
                        Text("PLAY").font(.jk(24, .heavy)).foregroundColor(.white)
                        Spacer()
                        SF("chevron.right", "circle.fill").font(.system(size: 18, weight: .black)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(LinearGradient(colors: [LS.orange, LS.orange2], startPoint: .top, endPoint: .bottom))
                }
                .buttonStyle(TuiPress())
            }
            .padding(5)
            .frame(width: rp, height: rpH)
            .background(LS.panel.opacity(0.9))
            .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            .position(x: W - 6 - rp / 2, y: H / 2)
        }
        .onAppear {
            if !LobbyHome.didDefault { LobbyHome.didDefault = true; if ![7, 1, 6].contains(nav.tacMode) { nav.tacMode = 7 } }
        }
    }
}
