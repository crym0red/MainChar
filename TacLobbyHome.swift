import SwiftUI

/// small painted harbor / outpost strip used as card art
struct MiniArt: View {
    var desert = false

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let sky: [Color] = desert ? [Color(red: 0.55, green: 0.7, blue: 0.85), Color(red: 0.95, green: 0.8, blue: 0.55)] : [Color(red: 0.35, green: 0.55, blue: 0.8), Color(red: 0.95, green: 0.75, blue: 0.5)]
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            let dark = Color(red: 0.12, green: 0.2, blue: 0.3)
            if !desert {
                for cx in [0.25, 0.62, 0.9] {
                    let x = w * cx
                    ctx.fill(Path(CGRect(x: x - 6, y: h * 0.18, width: 2, height: h * 0.55)), with: .color(dark))
                    ctx.fill(Path(CGRect(x: x - 26, y: h * 0.16, width: 52, height: 3)), with: .color(dark))
                }
            }
            let cols: [Color] = [Color(red: 0.8, green: 0.35, blue: 0.1), Color(red: 0.15, green: 0.35, blue: 0.7), Color(red: 0.7, green: 0.15, blue: 0.15), Color(red: 0.2, green: 0.5, blue: 0.3)]
            for i in 0..<9 {
                let x = w * CGFloat(i) / 9
                ctx.fill(Path(CGRect(x: x, y: h * 0.72 - CGFloat(i % 3) * 8, width: w / 9 - 1, height: 8 + CGFloat(i % 3) * 8 + h * 0.28)), with: .color((desert ? [Color(red: 0.75, green: 0.6, blue: 0.4), Color(red: 0.6, green: 0.48, blue: 0.33)] : cols)[i % (desert ? 2 : 4)]))
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

    private let diffNames = ["EASY", "NORMAL", "HARD"]

    private func tile(_ icon: String, _ title: String, _ sub: String, _ col: Color, _ w: CGFloat, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [col.opacity(0.35), Color.black.opacity(0.75)], startPoint: .topTrailing, endPoint: .bottomLeading)
                VStack(alignment: .leading, spacing: 1) {
                    SF(icon, "circle.fill").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Spacer(minLength: 0)
                    Text(title).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(sub).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.7)).lineLimit(2).minimumScaleFactor(0.7)
                }
                .padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: w, height: 66)
            .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func modeCard(_ mode: Int, _ icon: String, _ title: String, _ l1: String, _ l2: String, desert: Bool = false, _ h: CGFloat) -> some View {
        let on = nav.tacMode == mode
        return Button { nav.tacMode = mode } label: {
            ZStack {
                HStack(spacing: 0) {
                    Color(red: 0.06, green: 0.1, blue: 0.16)
                    MiniArt(desert: desert).frame(width: 150).mask(LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .init(x: 0.5, y: 0.5)))
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

    private func mapCard(_ h: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            MiniArt(desert: nav.tacMap == 3 && nav.tacMode != 7 && nav.tacMode != 6)
            LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            if nav.tacMode == 7 {
                GeometryReader { g in
                    ForEach(0..<5, id: \.self) { i in
                        FrontPoint(letter: TFront.letters[i], prog: i < 2 ? 1 : (i > 2 ? -1 : 0), size: 14)
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
        .frame(height: h).clipped()
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
            // squad + chat
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text("SQUAD 1/4").font(.jk(11, .heavy)).foregroundColor(.white)
                        Spacer()
                        SF("xmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 8).frame(height: 22).background(LS.navy.opacity(0.9))
                    squadRow(AnyView(PortraitAvatar(key: TacAvatar.myKey, size: 22, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)), TacProfile.name, "Leader")
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
                .frame(width: 160)
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
                tile("wrench.fill", "WORKSHOP", "Create & play custom guns and maps", LS.orange, leftW * 0.4) { act(.nav(3)) }
                tile("bubble.left.and.bubble.right.fill", "JOIN OUR DISCORD", "Get updates, share creations, find squads", Color(red: 0.35, green: 0.4, blue: 0.95), leftW * 0.32) { act(.friends) }
                tile("gift.fill", "DAILY REWARDS", "Log in for free rewards", Color(red: 0.95, green: 0.7, blue: 0.15), leftW * 0.28 - 10) { act(.season(0)) }
            }
            .position(x: 8 + leftW / 2, y: H - 8 - 33)
            // right panel
            VStack(spacing: 5) {
                HStack(spacing: 0) { tabBtn(0, "MODES"); tabBtn(1, "MAPS"); tabBtn(2, "SERVER") }
                    .background(LS.navy.opacity(0.9))
                if tab == 0 {
                    modeCard(7, "shield.lefthalf.filled", "FRONTLINE", "Large scale battle · 100 bots", "Capture points · Tickets · Squads", ch)
                    modeCard(1, "person.2.fill", "5v5", "Team Deathmatch · 5v5", "Fast paced · Small maps", desert: true, ch)
                    modeCard(6, "bag.fill", "EXTRACTION", "Loot · Survive · Extract", "Large map · AI + Players", ch)
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
                Spacer(minLength: 0)
                mapCard(74)
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
    }
}
