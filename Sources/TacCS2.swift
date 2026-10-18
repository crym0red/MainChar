import SwiftUI
import UIKit

// MARK: shared tiles

struct CSGunTile: View {
    let id: String
    var equipped: Bool
    var w: CGFloat
    var h: CGFloat = 78
    var act: (() -> Void)? = nil

    var body: some View {
        let g = TWeapons.w(id)
        let power = Int(g.dmg * CGFloat(g.pellets) / g.interval)
        return Button { act?() } label: {
            ZStack {
                LinearGradient(colors: equipped ? [Color(red: 0.12, green: 0.1, blue: 0.05), Color(red: 0.55, green: 0.38, blue: 0.0)] : [Color(red: 0.03, green: 0.03, blue: 0.04), Color(red: 0.1, green: 0.1, blue: 0.12)], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        Text(g.name).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                        Text("[TIER-1]").font(.jk(6, .heavy)).foregroundColor(.white.opacity(0.7))
                    }
                    Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                        .foregroundColor(.white).frame(width: w - 30, height: h - 38)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
                VStack {
                    Spacer()
                    HStack {
                        if equipped {
                            Text("EQUIPPED").font(.jk(8, .heavy)).foregroundColor(.black).padding(.horizontal, 5).frame(height: 13)
                                .background(Rectangle().fill(CS.gold))
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            SF("shield.lefthalf.filled").font(.system(size: 8)).foregroundColor(.white)
                            Text("\(power)").font(.jk(10, .heavy)).foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 3).padding(.bottom, 2)
                }
            }
            .frame(width: w, height: h)
            .overlay(Rectangle().stroke(equipped ? CS.gold : Color.white.opacity(0.22), lineWidth: 1.2))
        }
        .buttonStyle(TuiPress())
    }
}

struct CSSlot: View {
    let title: String
    var sub: String = ""
    var lvl: Int = 0
    var w: CGFloat
    var h: CGFloat
    var empty = false
    var icon: UIImage? = nil
    var sf: String? = nil
    var count: String? = nil
    var bar: Color = Color.white.opacity(0.75)
    var act: (() -> Void)? = nil

    var body: some View {
        Button { act?() } label: {
            ZStack {
                LinearGradient(colors: [Color(red: 0.26, green: 0.28, blue: 0.32), Color(red: 0.13, green: 0.14, blue: 0.17)], startPoint: .top, endPoint: .bottom)
                if empty {
                    SF("nosign", "xmark.circle").font(.system(size: min(w, h) * 0.5, weight: .light)).foregroundColor(.white.opacity(0.45))
                } else if let im = icon {
                    Image(uiImage: im).renderingMode(.template).resizable().scaledToFit().foregroundColor(.white.opacity(0.92)).padding(.horizontal, 14).padding(.vertical, 20)
                } else if let s = sf {
                    SF(s, "circle.fill").font(.system(size: min(w, h) * 0.42, weight: .semibold)).foregroundColor(.white.opacity(0.88))
                }
                VStack {
                    HStack { Text(title).font(.jk(11, .heavy)).foregroundColor(.white); Spacer() }
                    Spacer()
                    HStack(alignment: .bottom) {
                        Text(sub).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(2)
                        Spacer()
                        if lvl > 0 { Text("LVL \(lvl)").font(.jk(11, .heavy)).foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.3)) }
                        if let c = count { Text(c).font(.jk(12, .heavy)).foregroundColor(.white) }
                    }
                }
                .padding(6)
            }
            .frame(width: w, height: h)
            .overlay(alignment: .bottom) { Rectangle().fill(bar).frame(height: 3) }
        }
        .buttonStyle(TuiPress())
    }
}

struct CSHex: View {
    let icon: String
    let col: Color
    var size: CGFloat = 56
    var dot = false
    var label: String? = nil

    var body: some View {
        ZStack {
            Image(systemName: "hexagon.fill").resizable().scaledToFit().foregroundColor(Color(red: 0.05, green: 0.07, blue: 0.1).opacity(0.9))
            Image(systemName: "hexagon").resizable().scaledToFit().foregroundColor(col)
            SF(icon, "circle.fill").font(.system(size: size * 0.4, weight: .bold)).foregroundColor(col)
            if let l = label { VStack { Spacer(); Text(l).font(.jk(9, .heavy)).foregroundColor(.white) }.padding(.bottom, 6) }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if dot { Text("!").font(.jk(10, .heavy)).foregroundColor(.white).frame(width: 15, height: 15).background(Rectangle().fill(Color.red)).offset(x: 3, y: -3) }
        }
    }
}

// MARK: loadout picker

struct CSLoadout: View {
    @Binding var gun: String
    var countdown: Int? = nil
    var showBattle = false
    var gunsmith: (() -> Void)? = nil
    let ok: () -> Void
    let battle: () -> Void

    private let cols: [(String, [String])] = [("MELEE", ["knife"]), ("PISTOL", ["pistol", "eagle"]), ("SMG", ["smg", "mp7", "p90"]), ("SHOTGUN", ["shotgun", "pump"]), ("RIFLE", ["rifle", "ak", "m4"]), ("SNIPER", ["awp"])]

    private func header(_ s: String) -> some View {
        Text(s).font(.jk(11, .heavy)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 26).background(Color(red: 0.32, green: 0.33, blue: 0.37))
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.5)).frame(height: 1) }
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let cw = (W - 32 - 8 * 6) / 8.2
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 6) {
                        header("CONSUMABLES")
                        CSSlot(title: "ORB OF CALAMITY", w: cw * 1.2, h: 70, sf: "sparkles", count: "15")
                        CSSlot(title: "BIG SMOKE", w: cw * 1.2, h: 70, sf: "smoke.fill", count: "1")
                        CSSlot(title: "LIGHT MEDKIT", w: cw * 1.2, h: 70, sf: "cross.case.fill", count: "2")
                        HStack(spacing: 4) { Text("GOLD").font(.jk(12, .heavy)).foregroundColor(.white); Text("65").font(.jk(12, .heavy)).foregroundColor(CS.gold) }
                    }
                    .frame(width: cw * 1.2)
                    ForEach(0..<cols.count, id: \.self) { i in
                        let c = cols[i]
                        VStack(spacing: 6) {
                            header(c.0)
                            ForEach(c.1, id: \.self) { id in
                                if id == "knife" {
                                    ZStack {
                                        LinearGradient(colors: [Color(red: 0.12, green: 0.1, blue: 0.05), Color(red: 0.55, green: 0.38, blue: 0.0)], startPoint: .top, endPoint: .bottom)
                                        VStack(spacing: 2) { Text("KABAR [TIER-1]").font(.jk(10, .heavy)).foregroundColor(.white); HudKnifeShape().fill(Color.white).frame(width: 46, height: 30) }
                                        VStack { Spacer(); HStack { Text("EQUIPPED").font(.jk(8, .heavy)).foregroundColor(.black).padding(.horizontal, 5).frame(height: 13).background(Rectangle().fill(CS.gold)); Spacer() } }.padding(3)
                                    }
                                    .frame(width: cw, height: 78).overlay(Rectangle().stroke(CS.gold, lineWidth: 1.2))
                                } else {
                                    CSGunTile(id: id, equipped: gun == id || (id == "pistol" && TWeapons.isPistol(gun) == false), w: cw) {
                                        if !TWeapons.isPistol(id) || true { gun = id }
                                    }
                                }
                            }
                        }
                        .frame(width: cw)
                    }
                    VStack(spacing: 6) {
                        header("CHARACTER")
                        ZStack {
                            LinearGradient(colors: [Color(red: 0.12, green: 0.1, blue: 0.05), Color(red: 0.55, green: 0.38, blue: 0.0)], startPoint: .top, endPoint: .bottom)
                            VStack(spacing: 2) {
                                Text("DEFAULT").font(.jk(10, .heavy)).foregroundColor(.white)
                                PortraitAvatar(key: TacAvatar.myKey, size: 50, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)
                            }
                            VStack { Spacer(); HStack { Text("EQUIPPED").font(.jk(8, .heavy)).foregroundColor(.black).padding(.horizontal, 5).frame(height: 13).background(Rectangle().fill(CS.gold)); Spacer() } }.padding(3)
                        }
                        .frame(width: cw * 1.1, height: 78).overlay(Rectangle().stroke(CS.gold, lineWidth: 1.2))
                    }
                    .frame(width: cw * 1.1)
                }
                .padding(.horizontal, 12).padding(.top, 10)
                .frame(width: W, height: H, alignment: .top)
                Rectangle().fill(Color.white.opacity(0.35)).frame(width: W - 40, height: 1).position(x: W / 2, y: H * 0.62)
                Button { gunsmith?() } label: {
                    Text(gunsmith == nil ? "BLUEPRINT" : "GUNSMITH").font(.jk(14, .heavy)).foregroundColor(.black).frame(width: 170, height: 34).background(Rectangle().fill(CS.gold))
                }
                .buttonStyle(TuiPress())
                .position(x: W / 2, y: H * 0.68)
                CSButton(title: "OKAY", w: 160, h: 46, size: 20) { ok() }.position(x: 100, y: H - 36)
                if let c = countdown {
                    HStack(spacing: 6) {
                        Text("CHOOSE YOUR LOADOUT").font(.jk(15, .heavy))
                        SF("timer", "clock").font(.system(size: 14, weight: .bold))
                        Text("\(max(0, c))").font(.jk(15, .heavy))
                    }
                    .foregroundColor(.white).position(x: W / 2, y: H - 22)
                }
                if showBattle {
                    CSButton(title: "BATTLE!", col: CS.orange, dark: CS.orangeDark, w: 190, h: 46, size: 22) { battle() }.position(x: W - 120, y: H - 36)
                }
            }
        }
    }
}

// MARK: arsenal

struct CSArsenal: View {
    @Binding var gun: String
    let rank: Int
    let cash: Int
    let coins: Int
    let back: () -> Void
    let editLoadout: () -> Void
    let editChar: () -> Void
    let editCos: () -> Void
    let offer: () -> Void
    @State private var hideHelmet = false

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let lw: CGFloat = min(190, W * 0.22)
            let rw: CGFloat = min(100, W * 0.115)
            ZStack {
                AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: rank)
                    .frame(width: W * 0.42, height: H * 0.98).position(x: W * 0.5, y: H * 0.6).allowsHitTesting(false)
                VStack(spacing: 0) {
                    CSHeader(title: "ARSENAL", cash: cash, coins: coins, back: back).padding(.top, 8)
                    Spacer()
                }
                VStack(spacing: 6) {
                    CSSlot(title: "PRIMARY", sub: TWeapons.w(gun).name, lvl: 15, w: lw, h: 70, icon: GunSprites.icon(TWeapons.rig(gun))) { editLoadout() }
                    CSSlot(title: "SECONDARY", sub: "USP", lvl: 1, w: lw, h: 70, icon: GunSprites.icon("pistol")) { editLoadout() }
                    CSSlot(title: "MELEE", sub: "KABAR", lvl: 1, w: lw, h: 70, sf: "scissors") { editLoadout() }
                    Button(action: offer) {
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(colors: [Color(red: 0.12, green: 0.1, blue: 0.3), Color(red: 0.45, green: 0.1, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Text("X20 VALUE").font(.jk(10, .heavy)).foregroundColor(.white).padding(.horizontal, 5).background(Rectangle().fill(Color.red)).padding(4).frame(maxHeight: .infinity, alignment: .topLeading)
                            Text("TWIN TERRORS OFFER").font(.jk(11, .heavy)).foregroundColor(.white).padding(6)
                        }
                        .frame(width: lw, height: 50).overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(TuiPress())
                }
                .position(x: 28 + lw / 2, y: H / 2 + 30)
                HStack(spacing: 6) {
                    Text("Hide Helmet").font(.jk(11, .semibold)).foregroundColor(.white)
                    Button { hideHelmet.toggle() } label: { SF(hideHelmet ? "eye.slash.fill" : "eye.fill").font(.system(size: 16)).foregroundColor(.white) }
                }
                .position(x: W * 0.69, y: H * 0.27)
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        CSSlot(title: "CHARACTER", sub: "DEFAULT", lvl: 1, w: rw * 2 + 6, h: 70, sf: "person.fill") { editChar() }
                    }
                    HStack(spacing: 6) {
                        CSSlot(title: "ARMOR", sub: "BASIC ARMOR", lvl: 2, w: rw, h: 70, sf: "shield.fill") { editCos() }
                        CSSlot(title: "HELMET", sub: "SUNGLASSES", lvl: 3, w: rw, h: 70, sf: "eyeglasses") { editCos() }
                    }
                    HStack(spacing: 6) {
                        CSSlot(title: "BOOTS", w: rw, h: 70, empty: true, bar: CS.blue) { editCos() }
                        CSSlot(title: "GLOVES", sub: "DEFAULT GLOVE", w: rw, h: 70, sf: "hand.raised.fill") { editCos() }
                    }
                    HStack(spacing: 4) {
                        CSSlot(title: "EXPLOSIVES", w: rw * 0.64, h: 50, sf: "burst.fill", count: "x15", bar: .red) { editLoadout() }
                        CSSlot(title: "TACTICALS", w: rw * 0.64, h: 50, sf: "smoke.fill", count: "x1", bar: .green) { editLoadout() }
                        CSSlot(title: "HEALTH KITS", w: rw * 0.64, h: 50, sf: "cross.case.fill", count: "x2", bar: .green) { editLoadout() }
                    }
                }
                .position(x: W - 28 - (rw * 2 + 6) / 2, y: H / 2 + 30)
            }
        }
    }
}

// MARK: league

struct CSLeague: View {
    let rating: Int
    let cash: Int
    let coins: Int
    let back: () -> Void
    @State private var tab = 0

    private let leagues: [(String, Int, Color)] = [("IRON", 20, Color(red: 0.45, green: 0.45, blue: 0.5)), ("BRONZE", 100, Color(red: 0.75, green: 0.5, blue: 0.3)), ("SILVER", 250, Color(red: 0.8, green: 0.85, blue: 0.9)), ("GOLD", 500, CS.gold), ("PLATINUM", 900, Color(red: 0.5, green: 0.9, blue: 0.95)), ("DIAMOND", 1400, Color(red: 0.5, green: 0.7, blue: 1))]

    private func reward(_ k: Int) -> (String, String, Color) {
        switch k % 4 {
        case 0: return ("banknote.fill", "\((k + 2) * 1000)", CS.cash)
        case 1: return ("shippingbox.fill", "STANDARD CHEST x1", Color.orange)
        case 2: return ("banknote.fill", "\((k + 2) * 1000)", CS.cash)
        default: return ("circle.hexagongrid.fill", "\(k + 1)", CS.gold)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            VStack(spacing: 0) {
                CSHeader(title: "LEAGUE", cash: cash, coins: coins, back: back).padding(.top, 8)
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { i in
                        Button { tab = i } label: {
                            Text(i == 0 ? "TROPHY ROAD" : "TOP 100").font(.jk(14, .heavy)).foregroundColor(.white).frame(width: 190, height: 44)
                                .background(Rectangle().fill(tab == i ? CS.blue : Color(red: 0.25, green: 0.27, blue: 0.3)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
                Text("Gain trophies as you get victories from your battles and move on to the next leagues.").font(.jk(13, .medium)).foregroundColor(.white.opacity(0.9)).padding(.top, 8)
                if tab == 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(0..<leagues.count, id: \.self) { li in
                                let l = leagues[li]
                                let nextV = li + 1 < leagues.count ? leagues[li + 1].1 : l.1 + 600
                                VStack(spacing: 0) {
                                    HStack(spacing: 8) {
                                        SF("shield.lefthalf.filled").font(.system(size: 26)).foregroundColor(l.2)
                                        VStack(alignment: .leading) {
                                            Text(l.0).font(.jk(15, .heavy)).foregroundColor(.white)
                                            HStack(spacing: 3) { SF("trophy.fill").font(.system(size: 12)).foregroundColor(CS.gold); Text("\(l.1)+").font(.jk(14, .heavy)).foregroundColor(.white) }
                                        }
                                        Spacer()
                                        Text("+\(5 + li * 5)%").font(.jk(11, .heavy)).foregroundColor(.white).padding(4).background(Rectangle().fill(CS.blue))
                                    }
                                    .padding(8).frame(width: 220).background(Color.black.opacity(0.85)).overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                                    HStack(spacing: 14) {
                                        ForEach(0..<4, id: \.self) { k in
                                            let v = l.1 + (nextV - l.1) * k / 4
                                            let r = reward(li * 4 + k)
                                            VStack(spacing: 6) {
                                                VStack(spacing: 4) {
                                                    SF(k == 0 ? "shippingbox.fill" : r.0, "circle.fill").font(.system(size: 38)).foregroundColor(k == 0 ? Color.red : r.2)
                                                    Text(k == 0 ? "SUPER CHEST x1" : r.1).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                                                }
                                                .frame(width: 96, height: 110).background(Color.black.opacity(0.85)).overlay(Rectangle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                                                .overlay(alignment: .topLeading) { if rating >= v { SF("checkmark").font(.system(size: 14, weight: .black)).foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.1)).padding(4) } }
                                                SF("trophy.fill").font(.system(size: 12)).foregroundColor(.white).frame(width: 26, height: 26).background(Rectangle().fill(CS.blue).rotationEffect(.degrees(45)).scaleEffect(0.75))
                                                Text("\(v)").font(.jk(13, .heavy)).foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .padding(.top, 10)
                                    .padding(.horizontal, 6)
                                }
                            }
                        }
                        .padding(.horizontal, 24).padding(.top, 14)
                    }
                } else {
                    let names = TacRoster.pool.prefix(12).map { $0.name }
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(0..<names.count, id: \.self) { i in
                                HStack {
                                    Text("\(i + 1)").font(.jk(14, .heavy)).foregroundColor(i < 3 ? CS.gold : .white).frame(width: 36)
                                    Text(names[i]).font(.jk(14, .heavy)).foregroundColor(.white)
                                    Spacer()
                                    SF("trophy.fill").font(.system(size: 12)).foregroundColor(CS.gold)
                                    Text("\(3200 - i * 140)").font(.jk(14, .heavy)).foregroundColor(.white)
                                }
                                .padding(.horizontal, 12).frame(width: min(W - 80, 520), height: 34).background(Color.black.opacity(0.6))
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: W, height: H)
        }
    }
}

// MARK: killcam

struct CSKillcam: View {
    let e: TacticalEngine
    let changeLoadout: () -> Void

    var body: some View {
        let k = e.players.first { $0.id == e.lastKiller }
        let kg = k?.gun ?? "pistol"
        return GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Text("YOU").font(.jk(11, .heavy)).foregroundColor(.white)
                        Text("\(e.scores[0])").font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(.white)
                        Text("VS").font(.jk(20, .heavy)).foregroundColor(.white)
                        Text("\(e.rivalScore)").font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(.white)
                        Text("ENEMY").font(.jk(11, .heavy)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).background(Color.black.opacity(0.55))
                    VStack(spacing: 0) {
                        Text("KILLED BY").font(.jk(15, .semibold)).foregroundColor(.white)
                        Text(k?.name ?? "The Storm").font(.jk(26, .heavy)).foregroundColor(Color(red: 1, green: 0.2, blue: 0.15))
                        Text("ENEMY LOADOUT").font(.jk(19, .semibold)).foregroundColor(.white)
                    }
                    .frame(width: 360).background(Color.black.opacity(0.55))
                    Spacer()
                }
                .frame(width: W, height: H, alignment: .top)
                VStack(spacing: 4) {
                    CSSlot(title: "\(TWeapons.w(kg).name) [TIER-1]", w: 190, h: 96, icon: GunSprites.icon(TWeapons.rig(kg)))
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Color(red: 0.3, green: 0.34, blue: 0.2), Color(red: 0.15, green: 0.17, blue: 0.1)], startPoint: .top, endPoint: .bottom)
                        HStack { Text("DEFAULT (COMMON)").font(.jk(11, .heavy)).foregroundColor(.white); Spacer() }.padding(6).frame(maxHeight: .infinity, alignment: .top)
                        if let k = k { PortraitAvatar(key: k.handle, size: 54, look: TacAvatar.look(for: k.handle)).frame(maxWidth: .infinity) }
                    }
                    .frame(width: 190, height: 96)
                }
                .position(x: 110, y: H * 0.56)
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        CSSlot(title: "HELMET", w: 90, h: 92, empty: true)
                        CSSlot(title: "BASIC ARMOR", w: 90, h: 92, sf: "shield.fill")
                    }
                    HStack(spacing: 4) {
                        CSSlot(title: "BOOTS", w: 90, h: 92, empty: true)
                        CSSlot(title: "DEFAULT GLOVE", w: 90, h: 92, sf: "hand.raised.fill")
                    }
                    CSSlot(title: "CLAN", w: 184, h: 70, empty: true)
                }
                .position(x: W - 110, y: H * 0.54)
                CSButton(title: "CHANGE LOADOUT", w: 190, h: 40, size: 13) { changeLoadout() }.position(x: 110, y: H - 34)
                Text("\(max(1, Int(ceil(e.me.respawn))))").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundColor(.white)
                    .frame(width: 130, height: 50).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                    .position(x: W - 90, y: H - 34)
            }
        }
    }
}
