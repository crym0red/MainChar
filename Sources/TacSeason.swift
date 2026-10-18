import SwiftUI
import UIKit

struct TacSeasonData: Codable, Hashable {
    var xp = 0
    var premium = false
    var claimed: [Int] = []
    var claimedP: [Int] = []
    var owned: [String] = []
    var fx = "fx_none"
    var charm = "charm_none"
    var gloves = "gl_black"
    var map = "map_desert"
    var faction = 0
}

struct TacCos: Identifiable {
    let id: String
    let kind: String
    let label: String
    let emoji: String
    let rgb: (CGFloat, CGFloat, CGFloat)
}

enum TacSeason {
    static let name = "FALLEN GRACE"
    static let tiers = 30
    static let xpPerTier = 120

    static let catalog: [TacCos] = [
        TacCos(id: "fx_none", kind: "fx", label: "None", emoji: "", rgb: (0, 0, 0)),
        TacCos(id: "fx_gold", kind: "fx", label: "Gold Rush", emoji: "\u{1FA99}", rgb: (0, 0, 0)),
        TacCos(id: "fx_bolt", kind: "fx", label: "Lightning", emoji: "\u{26A1}\u{FE0F}", rgb: (0, 0, 0)),
        TacCos(id: "fx_skull", kind: "fx", label: "Reaper", emoji: "\u{1F480}", rgb: (0, 0, 0)),
        TacCos(id: "fx_fire", kind: "fx", label: "Inferno", emoji: "\u{1F525}", rgb: (0, 0, 0)),
        TacCos(id: "fx_heart", kind: "fx", label: "Heartbreak", emoji: "\u{1F496}", rgb: (0, 0, 0)),
        TacCos(id: "fx_star", kind: "fx", label: "Supernova", emoji: "\u{1F320}", rgb: (0, 0, 0)),
        TacCos(id: "charm_none", kind: "charm", label: "None", emoji: "", rgb: (0, 0, 0)),
        TacCos(id: "charm_clover", kind: "charm", label: "Lucky Clover", emoji: "\u{1F340}", rgb: (0, 0, 0)),
        TacCos(id: "charm_pumpkin", kind: "charm", label: "Jack", emoji: "\u{1F383}", rgb: (0, 0, 0)),
        TacCos(id: "charm_crown", kind: "charm", label: "Crown", emoji: "\u{1F451}", rgb: (0, 0, 0)),
        TacCos(id: "charm_rocket", kind: "charm", label: "Rocket", emoji: "\u{1F680}", rgb: (0, 0, 0)),
        TacCos(id: "charm_bunny", kind: "charm", label: "Bunny", emoji: "\u{1F430}", rgb: (0, 0, 0)),
        TacCos(id: "gl_black", kind: "gl", label: "Tactical Black", emoji: "", rgb: (0.165, 0.153, 0.137)),
        TacCos(id: "gl_tan", kind: "gl", label: "Desert Tan", emoji: "", rgb: (0.62, 0.5, 0.33)),
        TacCos(id: "gl_red", kind: "gl", label: "Crimson", emoji: "", rgb: (0.6, 0.1, 0.1)),
        TacCos(id: "gl_camo", kind: "gl", label: "Woodland", emoji: "", rgb: (0.25, 0.33, 0.17)),
        TacCos(id: "gl_blue", kind: "gl", label: "Navy", emoji: "", rgb: (0.12, 0.2, 0.45)),
        TacCos(id: "map_desert", kind: "map", label: "Desert Dust", emoji: "", rgb: (0, 0, 0)),
        TacCos(id: "map_station", kind: "map", label: "Station (Night)", emoji: "", rgb: (0, 0, 0)),
        TacCos(id: "map_grace", kind: "map", label: "Fallen Grace", emoji: "", rgb: (0, 0, 0))
    ]
    static func cos(_ id: String) -> TacCos { catalog.first { $0.id == id } ?? catalog[0] }
    static let baseOwned = ["fx_none", "charm_none", "gl_black", "map_desert"]
    static let freeCos = ["fx_gold", "charm_clover", "gl_tan", "fx_bolt", "map_station", "gl_red"]
    static let premCos = ["fx_skull", "charm_pumpkin", "gl_camo", "fx_fire", "charm_crown", "gl_blue", "fx_heart", "map_grace", "charm_rocket", "fx_star"]

    struct Reward { let gems: Int; let cos: String? }
    static func reward(_ t: Int, premium: Bool) -> Reward {
        if premium {
            if t % 3 == 0 { return Reward(gems: 0, cos: premCos[(t / 3 - 1) % premCos.count]) }
            return Reward(gems: 25, cos: nil)
        }
        if t % 5 == 0 { return Reward(gems: 0, cos: freeCos[(t / 5 - 1) % freeCos.count]) }
        return Reward(gems: 10, cos: nil)
    }

    static func tier(_ xp: Int) -> Int { min(tiers, xp / xpPerTier) }
    static func league(_ rating: Int) -> String {
        if rating < 1000 { return "BRONZE" }
        if rating < 1200 { return "SILVER" }
        if rating < 1400 { return "GOLD" }
        if rating < 1600 { return "PLATINUM" }
        if rating < 1900 { return "DIAMOND" }
        return "LEGEND"
    }

    static let factions: [(String, (CGFloat, CGFloat, CGFloat))] = [
        ("SWAT", (0.16, 0.2, 0.3)), ("GIGN", (0.12, 0.2, 0.42)), ("SPETSNAZ", (0.3, 0.34, 0.2)), ("SEAL", (0.2, 0.3, 0.4))
    ]
    static let enemyFactions: [(String, (CGFloat, CGFloat, CGFloat))] = [
        ("ANARCHIST", (0.5, 0.15, 0.12)), ("GANGSTER", (0.35, 0.22, 0.4)), ("BALKANS", (0.45, 0.38, 0.22))
    ]
    static let themes = ["map_desert", "map_station", "map_grace"]
}

extension Game {
    var sx: TacSeasonData { s.ex.tac?.sx ?? TacSeasonData() }
    func updateSX(_ f: (inout TacSeasonData) -> Void) {
        var st = s
        var d = st.ex.tac ?? TacData()
        var x = d.sx ?? TacSeasonData()
        f(&x)
        d.sx = x
        st.ex.tac = d
        s = st
    }
    func tacOwns(_ id: String) -> Bool { TacSeason.baseOwned.contains(id) || sx.owned.contains(id) }
}

struct TacSeasonView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var drawMsg = ""

    private let lime = Color(red: 0.8, green: 0.95, blue: 0.2)

    var body: some View {
        let x = game.sx
        let tier = TacSeason.tier(x.xp)
        let rating = game.s.ex.tac?.rating ?? 1000
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundColor(.white) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SEASON  \(TacSeason.name)").font(.jk(18, .heavy)).foregroundColor(.white)
                        Text("Tier \(tier)/\(TacSeason.tiers)   \(TacSeason.league(rating))  \(rating)").font(.jk(12, .semibold)).foregroundColor(lime)
                    }
                    Spacer()
                    Text("\(game.s.ex.gems) gems").font(.jk(14, .heavy)).foregroundColor(.yellow)
                }
                .padding(.horizontal, 16).padding(.top, 8)
                HStack(spacing: 0) {
                    ForEach(Array(["BATTLE PASS", "LOCKER", "LUCKY DRAW"].enumerated()), id: \.offset) { i, n in
                        Button { tab = i } label: {
                            Text(n).font(.jk(12, .heavy)).foregroundColor(tab == i ? .black : .white.opacity(0.8))
                                .frame(maxWidth: .infinity).frame(height: 34).background(tab == i ? lime : Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 16)
                if tab == 0 { passTab(x, tier) } else if tab == 1 { lockerTab(x) } else { drawTab() }
                Spacer(minLength: 0)
            }
        }
        .statusBarHidden(true)
    }

    private func rewardLabel(_ r: TacSeason.Reward) -> String {
        if let c = r.cos { let k = TacSeason.cos(c); return k.emoji.isEmpty ? k.label : k.emoji }
        return "\(r.gems)"
    }

    private func passTab(_ x: TacSeasonData, _ tier: Int) -> some View {
        VStack(spacing: 8) {
            let into = x.xp - tier * TacSeason.xpPerTier
            HStack {
                Capsule().fill(Color.white.opacity(0.15)).frame(height: 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(lime).frame(width: g.size.width * CGFloat(tier >= TacSeason.tiers ? 1 : Double(into) / Double(TacSeason.xpPerTier))) }
                    }
                Text("\(x.xp) XP").font(.jk(11, .bold)).foregroundColor(.white.opacity(0.8))
                if !x.premium {
                    Button {
                        if game.s.ex.gems >= 300 {
                            var st = game.s; st.ex.gems -= 300; game.s = st
                            game.updateSX { $0.premium = true }
                        }
                    } label: {
                        Text("PREMIUM 300").font(.jk(11, .heavy)).foregroundColor(.black).padding(.horizontal, 10).frame(height: 26).background(Color.yellow).clipShape(Capsule())
                    }
                } else {
                    Text("PREMIUM").font(.jk(11, .heavy)).foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...TacSeason.tiers, id: \.self) { t in
                        let reached = tier >= t
                        VStack(spacing: 6) {
                            Text("\(t)").font(.jk(12, .heavy)).foregroundColor(reached ? lime : .white.opacity(0.5))
                            cell(TacSeason.reward(t, premium: true), locked: !x.premium, got: x.claimedP.contains(t), can: reached && x.premium && !x.claimedP.contains(t)) { claim(t, true) }
                            cell(TacSeason.reward(t, premium: false), locked: false, got: x.claimed.contains(t), can: reached && !x.claimed.contains(t)) { claim(t, false) }
                        }
                        .frame(width: 62)
                    }
                }
                .padding(.horizontal, 16)
            }
            Text("Earn XP from every match: 40 base + 10 per kill + 60 for a win.").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.6))
        }
    }

    private func cell(_ r: TacSeason.Reward, locked: Bool, got: Bool, can: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 2) {
                Text(rewardLabel(r)).font(.jk(r.cos != nil && TacSeason.cos(r.cos!).emoji.isEmpty ? 10 : 18, .heavy)).foregroundColor(.white).multilineTextAlignment(.center).minimumScaleFactor(0.6)
                Text(got ? "CLAIMED" : (can ? "CLAIM" : (locked ? "LOCKED" : "")))
                    .font(.jk(9, .heavy)).foregroundColor(can ? .black : .white.opacity(0.6))
                    .padding(.horizontal, 4).background(can ? lime : Color.clear).clipShape(Capsule())
            }
            .frame(width: 58, height: 70)
            .background(Color.white.opacity(got ? 0.04 : 0.1))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(can ? lime : Color.white.opacity(0.15), lineWidth: can ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!can)
    }

    private func claim(_ t: Int, _ prem: Bool) {
        let r = TacSeason.reward(t, premium: prem)
        game.updateSX { d in
            if prem { if d.claimedP.contains(t) { return }; d.claimedP.append(t) } else { if d.claimed.contains(t) { return }; d.claimed.append(t) }
            if let c = r.cos, !d.owned.contains(c) { d.owned.append(c) }
        }
        if r.gems > 0 { var st = game.s; st.ex.gems += r.gems; game.s = st }
    }

    private func lockerTab(_ x: TacSeasonData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array([("fx", "KILL EFFECT"), ("charm", "CHARM"), ("gl", "GLOVES"), ("map", "MAP")].enumerated()), id: \.offset) { _, grp in
                    Text(grp.1).font(.jk(12, .heavy)).foregroundColor(lime)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TacSeason.catalog.filter { $0.kind == grp.0 }) { c in
                                let own = game.tacOwns(c.id)
                                let sel = (grp.0 == "fx" ? x.fx : (grp.0 == "charm" ? x.charm : (grp.0 == "gl" ? x.gloves : x.map))) == c.id
                                Button {
                                    guard own else { return }
                                    game.updateSX { d in
                                        if grp.0 == "fx" { d.fx = c.id } else if grp.0 == "charm" { d.charm = c.id } else if grp.0 == "gl" { d.gloves = c.id } else { d.map = c.id }
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        if grp.0 == "gl" {
                                            Circle().fill(Color(red: c.rgb.0, green: c.rgb.1, blue: c.rgb.2)).frame(width: 26, height: 26)
                                        } else {
                                            Text(c.emoji.isEmpty ? "\u{2205}" : c.emoji).font(.system(size: 22))
                                        }
                                        Text(c.label).font(.jk(10, .bold)).foregroundColor(.white).lineLimit(1)
                                    }
                                    .frame(width: 92, height: 62)
                                    .background(Color.white.opacity(own ? 0.1 : 0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(sel ? lime : Color.white.opacity(0.12), lineWidth: sel ? 2 : 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .opacity(own ? 1 : 0.4)
                                }
                            }
                        }
                    }
                }
                Text("FACTION").font(.jk(12, .heavy)).foregroundColor(lime)
                HStack(spacing: 8) {
                    ForEach(0..<TacSeason.factions.count, id: \.self) { i in
                        Button { game.updateSX { $0.faction = i } } label: {
                            Text(TacSeason.factions[i].0).font(.jk(11, .heavy)).foregroundColor(.white)
                                .frame(width: 92, height: 38)
                                .background(Color(red: TacSeason.factions[i].1.0, green: TacSeason.factions[i].1.1, blue: TacSeason.factions[i].1.2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(x.faction == i ? lime : Color.clear, lineWidth: 2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func drawTab() -> some View {
        VStack(spacing: 14) {
            Text("LUCKY DRAW").font(.jk(22, .heavy)).foregroundColor(.white)
            Text("Spend 40 gems for a random cosmetic you don't own yet.").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.7))
            Button {
                let pool = TacSeason.catalog.filter { !game.tacOwns($0.id) }
                guard game.s.ex.gems >= 40 else { drawMsg = "Not enough gems"; return }
                var st = game.s; st.ex.gems -= 40; game.s = st
                if let c = pool.randomElement() {
                    game.updateSX { $0.owned.append(c.id) }
                    drawMsg = "You got: \(c.emoji) \(c.label)"
                } else {
                    var s2 = game.s; s2.ex.gems += 20; game.s = s2
                    drawMsg = "Collection complete, 20 gems back"
                }
            } label: {
                Text("DRAW  40").font(.jk(18, .heavy)).foregroundColor(.black).frame(width: 200, height: 52).background(Color.yellow).clipShape(Capsule())
            }
            Text(drawMsg).font(.jk(15, .bold)).foregroundColor(lime)
        }
        .padding(.top, 30)
    }
}
