import SwiftUI
import UIKit

// MARK: - Attachment data

enum TAttSlot: String, CaseIterable {
    case mag, muzzle, optic, grip, camo
    var title: String {
        switch self { case .mag: return "MAGAZINE"; case .muzzle: return "MUZZLE"; case .optic: return "OPTIC"; case .grip: return "GRIP"; case .camo: return "CAMO" }
    }
    var icon: String {
        switch self { case .mag: return "rectangle.stack.fill"; case .muzzle: return "speaker.slash.fill"; case .optic: return "scope"; case .grip: return "hand.raised.fill"; case .camo: return "paintpalette.fill" }
    }
}

struct TAttDef {
    let id: String
    let slot: TAttSlot
    let name: String
    let desc: String
    let cost: Int
    var color: (CGFloat, CGFloat, CGFloat)? = nil
}

struct TAttMods {
    var magMul: CGFloat = 1
    var reloadMul: CGFloat = 1
    var recoilMul: CGFloat = 1
    var dmgMul: CGFloat = 1
    var rangeMul: CGFloat = 1
    var scopeMul: CGFloat = 1
    var silenced = false
    var zoomFOV: CGFloat = 26
}

enum TAtt {
    static let defs: [TAttDef] = [
        TAttDef(id: "mag_ext", slot: .mag, name: "Extended Mag", desc: "+50% magazine, slightly slower reload", cost: 60),
        TAttDef(id: "mag_drum", slot: .mag, name: "Drum Mag", desc: "+100% magazine, much slower reload", cost: 150),
        TAttDef(id: "sil", slot: .muzzle, name: "Silencer", desc: "Quiet shots bots can't hear, no muzzle flash, -8% damage", cost: 100),
        TAttDef(id: "comp", slot: .muzzle, name: "Compensator", desc: "-25% recoil", cost: 60),
        TAttDef(id: "dot", slot: .optic, name: "Red Dot", desc: "Tighter spread when scoped, 2.5x zoom", cost: 50),
        TAttDef(id: "x4", slot: .optic, name: "4x Scope", desc: "Strong zoom, tight spread, +20% range", cost: 140),
        TAttDef(id: "vgrip", slot: .grip, name: "Vertical Grip", desc: "-30% recoil", cost: 60),
        TAttDef(id: "agrip", slot: .grip, name: "Angled Grip", desc: "-15% recoil, faster reload", cost: 60),
        TAttDef(id: "c_desert", slot: .camo, name: "Desert", desc: "Sand finish", cost: 40, color: (0.78, 0.64, 0.4)),
        TAttDef(id: "c_forest", slot: .camo, name: "Forest", desc: "Green finish", cost: 40, color: (0.2, 0.36, 0.15)),
        TAttDef(id: "c_arctic", slot: .camo, name: "Arctic", desc: "White finish", cost: 40, color: (0.86, 0.9, 0.94)),
        TAttDef(id: "c_urban", slot: .camo, name: "Urban", desc: "Grey finish", cost: 40, color: (0.36, 0.38, 0.42)),
        TAttDef(id: "c_crimson", slot: .camo, name: "Crimson", desc: "Red finish", cost: 60, color: (0.72, 0.1, 0.12)),
        TAttDef(id: "c_violet", slot: .camo, name: "Violet", desc: "Purple finish", cost: 60, color: (0.5, 0.2, 0.8)),
        TAttDef(id: "c_gold", slot: .camo, name: "Gold", desc: "Gold finish", cost: 120, color: (1.0, 0.8, 0.25))
    ]

    static func def(_ id: String) -> TAttDef? { defs.first { $0.id == id } }

    private static let ownKey = "ms.att.own"
    private static let eqKey = "ms.att.eq"
    private static var ownCache: Set<String>? = nil
    private static var eqCache: [String: [String: String]]? = nil

    static var owned: Set<String> {
        if let c = ownCache { return c }
        let c = Set((UserDefaults.standard.array(forKey: ownKey) as? [String]) ?? [])
        ownCache = c
        return c
    }

    static var equipped: [String: [String: String]] {
        if let c = eqCache { return c }
        let c = (UserDefaults.standard.dictionary(forKey: eqKey) as? [String: [String: String]]) ?? [:]
        eqCache = c
        return c
    }

    static func own(_ id: String) {
        var o = owned
        o.insert(id)
        ownCache = o
        UserDefaults.standard.set(Array(o), forKey: ownKey)
    }

    static func eq(_ gun: String, _ slot: TAttSlot) -> String? { equipped[gun]?[slot.rawValue] }

    static func setEq(_ gun: String, _ slot: TAttSlot, _ id: String?) {
        var e = equipped
        var g = e[gun] ?? [:]
        if let id = id { g[slot.rawValue] = id } else { g.removeValue(forKey: slot.rawValue) }
        e[gun] = g
        eqCache = e
        UserDefaults.standard.set(e, forKey: eqKey)
    }

    static func mods(_ gun: String) -> TAttMods {
        var m = TAttMods()
        for s in TAttSlot.allCases {
            guard let id = eq(gun, s) else { continue }
            switch id {
            case "mag_ext": m.magMul = 1.5; m.reloadMul *= 1.08
            case "mag_drum": m.magMul = 2; m.reloadMul *= 1.25
            case "sil": m.silenced = true; m.dmgMul *= 0.92
            case "comp": m.recoilMul *= 0.75
            case "dot": m.scopeMul = 0.8; m.zoomFOV = 22
            case "x4": m.scopeMul = 0.55; m.zoomFOV = 14; m.rangeMul = 1.2
            case "vgrip": m.recoilMul *= 0.7
            case "agrip": m.recoilMul *= 0.85; m.reloadMul *= 0.92
            default: break
            }
        }
        return m
    }

    static func camoColor(_ gun: String) -> Color? {
        guard let id = eq(gun, .camo), let c = def(id)?.color else { return nil }
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    /// recolours the shared first-person gun materials (or restores them) to match the equipped camo
    static func applyCamo(_ gun: String) {
        let keys = ["poly", "tan", "olive", "bake", "steel", "blued"]
        let c = eq(gun, .camo).flatMap { def($0)?.color }
        for k in keys {
            guard let m = TwGunLib.mats[k] else { continue }
            if let c = c {
                let f: CGFloat = (k == "steel" || k == "blued") ? 0.8 : 1
                m.diffuse.contents = UIColor(red: c.0 * f, green: c.1 * f, blue: c.2 * f, alpha: 1)
            } else if let d = TwGunLib.defs[k]?["c"] as? [Double], d.count == 3 {
                m.diffuse.contents = UIColor(red: CGFloat(d[0]), green: CGFloat(d[1]), blue: CGFloat(d[2]), alpha: 1)
            }
        }
    }

    static func viewSig(_ gun: String) -> String { (eq(gun, .camo) ?? "-") + "|" + (mods(gun).silenced ? "s" : "n") }
}

// MARK: - Gunsmith screen

struct CSGunsmith: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let back: () -> Void
    @State private var gid = "rifle"
    @State private var slot: TAttSlot = .mag
    @State private var tick = 0

    private var ids: [String] { TWeapons.all.map { $0.id } }

    private func stat(_ label: String, _ a: String, _ b: String, _ up: Bool?) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.65)).frame(width: 56, alignment: .leading)
            Text(a).font(.jk(11, .heavy)).foregroundColor(.white)
            if a != b {
                SF("arrow.right").font(.system(size: 9)).foregroundColor(.white.opacity(0.6))
                Text(b).font(.jk(11, .heavy)).foregroundColor(up == true ? Color(red: 0.4, green: 0.95, blue: 0.4) : (up == false ? TUI.red : .white))
            }
        }
    }

    var body: some View {
        _ = tick
        let g = TWeapons.w(gid)
        let m = TAtt.mods(gid)
        let gems = game.s.ex.gems
        return GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                VStack(spacing: 0) {
                    CSHeader(title: "GUNSMITH", cash: gems, coins: (game.s.ex.tac ?? TacData()).wins, back: back).padding(.top, 8)
                    Spacer()
                }
                // gun list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(ids, id: \.self) { id in
                            CSGunTile(id: id, equipped: gid == id, w: 150, h: 58) { gid = id }
                        }
                    }
                }
                .frame(width: 150, height: H - 130)
                .position(x: 16 + 75, y: 60 + (H - 130) / 2)
                // centre
                VStack(spacing: 6) {
                    Image(uiImage: GunSprites.icon(TWeapons.rig(gid))).renderingMode(.template).resizable().scaledToFit()
                        .foregroundColor(TAtt.camoColor(gid) ?? .white).frame(width: 260, height: 90)
                        .shadow(color: .black.opacity(0.6), radius: 4)
                    Text(g.name).font(.jk(18, .heavy)).foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 3) {
                        stat("DAMAGE", "\(Int(g.dmg * CGFloat(g.pellets)))", "\(Int(g.dmg * CGFloat(g.pellets) * m.dmgMul))", m.dmgMul >= 1 ? (m.dmgMul > 1 ? true : nil) : false)
                        stat("RANGE", "\(Int(g.range))", "\(Int(g.range * m.rangeMul))", m.rangeMul > 1 ? true : nil)
                        stat("MAGAZINE", "\(g.mag)", "\(Int(CGFloat(g.mag) * m.magMul))", m.magMul > 1 ? true : nil)
                        stat("RECOIL", "100%", "\(Int(m.recoilMul * 100))%", m.recoilMul < 1 ? true : nil)
                        stat("RELOAD", String(format: "%.1fs", g.reload), String(format: "%.1fs", g.reload * m.reloadMul), m.reloadMul < 1 ? true : (m.reloadMul > 1 ? false : nil))
                        stat("NOISE", "LOUD", m.silenced ? "SILENT" : "LOUD", m.silenced ? true : nil)
                    }
                    .padding(8).background(Color.black.opacity(0.55)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    HStack(spacing: 4) {
                        ForEach(TAttSlot.allCases, id: \.self) { s in
                            Button { slot = s } label: {
                                VStack(spacing: 1) {
                                    SF(s.icon, "circle.fill").font(.system(size: 15, weight: .bold))
                                    Text(s.title).font(.jk(7, .heavy))
                                }
                                .foregroundColor(slot == s ? .black : .white)
                                .frame(width: 58, height: 36)
                                .background(Rectangle().fill(slot == s ? CS.gold : Color.white.opacity(0.12)))
                                .overlay(alignment: .topTrailing) { if TAtt.eq(gid, s) != nil { Circle().fill(Color.green).frame(width: 7, height: 7).padding(3) } }
                            }
                            .buttonStyle(TuiPress())
                        }
                    }
                }
                .position(x: W / 2 - 10, y: H / 2 + 20)
                // options
                VStack(spacing: 5) {
                    Text(slot.title).font(.jk(14, .heavy)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 5) {
                            optionRow(nil)
                            ForEach(TAtt.defs.filter { $0.slot == slot }, id: \.id) { d in optionRow(d) }
                        }
                    }
                    if !TWeapons.isPistol(gid) || true {
                        CSButton(title: nav.tacGun == gid ? "USING THIS GUN" : "USE THIS GUN", col: CS.orange, dark: CS.orangeDark, w: 236, h: 36, size: 13) { nav.tacGun = gid }
                    }
                }
                .frame(width: 236, height: H - 100)
                .position(x: W - 16 - 118, y: 56 + (H - 100) / 2)
            }
        }
        .onAppear { gid = nav.tacGun }
    }

    @ViewBuilder private func optionRow(_ d: TAttDef?) -> some View {
        let cur = TAtt.eq(gid, slot)
        let isOn = d == nil ? cur == nil : cur == d?.id
        let own = d == nil || TAtt.owned.contains(d?.id ?? "")
        let gems = game.s.ex.gems
        Button {
            if let d = d {
                if !own {
                    guard gems >= d.cost else { return }
                    var st = game.s
                    st.ex.gems -= d.cost
                    game.s = st
                    TAtt.own(d.id)
                }
                TAtt.setEq(gid, slot, isOn ? nil : d.id)
            } else {
                TAtt.setEq(gid, slot, nil)
            }
            tick += 1
            _ = TwViewModelSync.refresh
        } label: {
            HStack(spacing: 8) {
                if let c = d?.color { Rectangle().fill(Color(red: c.0, green: c.1, blue: c.2)).frame(width: 18, height: 18).overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1)) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(d?.name ?? "None").font(.jk(12, .heavy)).foregroundColor(.white)
                    if let d = d { Text(d.desc).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.65)).lineLimit(2).multilineTextAlignment(.leading) }
                }
                Spacer(minLength: 0)
                if let d = d {
                    if isOn { Text("ON").font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 6).frame(height: 18).background(Rectangle().fill(Color(red: 0.4, green: 0.95, blue: 0.4))) }
                    else if own { Text("EQUIP").font(.jk(10, .heavy)).foregroundColor(.white).padding(.horizontal, 6).frame(height: 18).background(Rectangle().fill(CS.blue)) }
                    else {
                        HStack(spacing: 3) { SF("diamond.fill").font(.system(size: 9)); Text("\(d.cost)").font(.jk(10, .heavy)) }
                            .foregroundColor(gems >= d.cost ? .black : .white.opacity(0.6)).padding(.horizontal, 6).frame(height: 18)
                            .background(Rectangle().fill(gems >= d.cost ? CS.gold : Color.white.opacity(0.15)))
                    }
                } else if isOn {
                    Text("ON").font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 6).frame(height: 18).background(Rectangle().fill(Color(red: 0.4, green: 0.95, blue: 0.4)))
                }
            }
            .padding(8).frame(maxWidth: .infinity).background(Color.black.opacity(isOn ? 0.85 : 0.55)).overlay(Rectangle().stroke(isOn ? CS.gold : Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }
}

enum TwViewModelSync { static let refresh = 0 }
