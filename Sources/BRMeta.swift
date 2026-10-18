import SwiftUI

struct BRStats {
    var kills = 0, heads = 0, place = 30
    var won = false
    var plates = 0, dives = 0, vehM = 0, nadeKills = 0, gulagWins = 0, secs = 0
}

struct BRCosm: Identifiable {
    let id: String
    let name: String
    let cost: Int
    let c: (Double, Double, Double)
}

struct BRContract {
    let id: Int
    let title: String
    let goal: Int
    let reward: Int
}

/// Settings, unlocks and daily contracts for the battle royale (kept in UserDefaults).
enum BRMeta {
    static let rarNames = ["COMMON", "RARE", "EPIC", "LEGENDARY"]
    static func rarColor(_ r: Int) -> Color {
        switch r {
        case 1: return Color(red: 0.3, green: 0.62, blue: 1)
        case 2: return Color(red: 0.72, green: 0.42, blue: 1)
        case 3: return Color(red: 1, green: 0.66, blue: 0.15)
        default: return Color.white
        }
    }

    static func f(_ k: String, _ d: Double) -> CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: k) as? Double ?? d)
    }

    // MARK: cosmetics
    static let skins: [BRCosm] = [
        BRCosm(id: "stock", name: "Factory", cost: 0, c: (1, 1, 1)),
        BRCosm(id: "ember", name: "Ember", cost: 40, c: (1, 0.45, 0.25)),
        BRCosm(id: "frost", name: "Frost", cost: 40, c: (0.45, 0.8, 1)),
        BRCosm(id: "toxic", name: "Toxic", cost: 60, c: (0.5, 1, 0.35)),
        BRCosm(id: "royal", name: "Royal", cost: 80, c: (0.75, 0.45, 1)),
        BRCosm(id: "gold", name: "Gold", cost: 150, c: (1, 0.82, 0.25))
    ]
    static let outfits: [BRCosm] = [
        BRCosm(id: "ranger", name: "Ranger", cost: 0, c: (0.9, 0.9, 0.2)),
        BRCosm(id: "crimson", name: "Crimson", cost: 30, c: (0.85, 0.2, 0.2)),
        BRCosm(id: "azure", name: "Azure", cost: 30, c: (0.2, 0.5, 0.95)),
        BRCosm(id: "jade", name: "Jade", cost: 50, c: (0.2, 0.75, 0.5)),
        BRCosm(id: "shadow", name: "Shadow", cost: 70, c: (0.3, 0.3, 0.36)),
        BRCosm(id: "violet", name: "Violet", cost: 90, c: (0.65, 0.3, 0.9))
    ]

    static func owned() -> Set<String> {
        var s = Set(UserDefaults.standard.stringArray(forKey: "br.owned") ?? [])
        s.insert("stock")
        s.insert("ranger")
        return s
    }
    static func own(_ id: String) {
        var s = owned()
        s.insert(id)
        UserDefaults.standard.set(Array(s), forKey: "br.owned")
    }
    static var skin: String {
        get { UserDefaults.standard.string(forKey: "br.skin") ?? "stock" }
        set { UserDefaults.standard.set(newValue, forKey: "br.skin") }
    }
    static var outfit: String {
        get { UserDefaults.standard.string(forKey: "br.outfit") ?? "ranger" }
        set { UserDefaults.standard.set(newValue, forKey: "br.outfit") }
    }
    static func skinTint() -> Color? {
        guard skin != "stock", let c = skins.first(where: { $0.id == skin }) else { return nil }
        return Color(red: c.c.0, green: c.c.1, blue: c.c.2)
    }
    static func outfitColor(shade: Int = 0) -> BRCol {
        let c = outfits.first(where: { $0.id == outfit })?.c ?? (0.9, 0.9, 0.2)
        let k = 1 - Double(shade % 3) * 0.1
        return (CGFloat(c.0 * k), CGFloat(c.1 * k), CGFloat(c.2 * k))
    }

    // MARK: contracts
    static let pool: [BRContract] = [
        BRContract(id: 0, title: "Eliminate 5 players", goal: 5, reward: 15),
        BRContract(id: 1, title: "Land 3 headshots", goal: 3, reward: 15),
        BRContract(id: 2, title: "Finish in the top 5", goal: 1, reward: 20),
        BRContract(id: 3, title: "Win a match", goal: 1, reward: 40),
        BRContract(id: 4, title: "Apply 4 armor plates", goal: 4, reward: 12),
        BRContract(id: 5, title: "Dolphin dive 2 times", goal: 2, reward: 10),
        BRContract(id: 6, title: "Drive 800 m", goal: 800, reward: 15),
        BRContract(id: 7, title: "2 grenade eliminations", goal: 2, reward: 20),
        BRContract(id: 8, title: "Win the gulag", goal: 1, reward: 20),
        BRContract(id: 9, title: "Survive 5 minutes", goal: 300, reward: 10)
    ]

    static func today() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)\(c.month ?? 0)\(c.day ?? 0)"
    }

    static func daily() -> [BRContract] {
        var seed = 0
        for u in today().unicodeScalars { seed = (seed &* 31 &+ Int(u.value)) & 0xFFFFFF }
        var idx = Array(0..<pool.count)
        var out: [BRContract] = []
        for _ in 0..<3 {
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFFFFFF
            let k = seed % idx.count
            out.append(pool[idx.remove(at: k)])
        }
        return out
    }

    static func progress(_ c: BRContract) -> Int {
        UserDefaults.standard.integer(forKey: "br.c.\(today()).\(c.id)")
    }

    static func value(_ c: BRContract, _ s: BRStats) -> Int {
        switch c.id {
        case 0: return s.kills
        case 1: return s.heads
        case 2: return s.place <= 5 ? 1 : 0
        case 3: return s.won ? 1 : 0
        case 4: return s.plates
        case 5: return s.dives
        case 6: return s.vehM
        case 7: return s.nadeKills
        case 8: return s.gulagWins
        default: return s.secs
        }
    }

    /// Adds a finished match to today's contracts. Returns bonus gems and a line per contract.
    static func record(_ s: BRStats) -> (Int, [(String, Bool)]) {
        var gems = 0
        var lines: [(String, Bool)] = []
        for c in daily() {
            let old = progress(c)
            let new = min(c.goal, old + value(c, s))
            UserDefaults.standard.set(new, forKey: "br.c.\(today()).\(c.id)")
            let done = new >= c.goal
            if old < c.goal && done { gems += c.reward }
            lines.append(("\(c.title)  \(new)/\(c.goal)" + (old < c.goal && done ? "  +\(c.reward)" : ""), done))
        }
        return (gems, lines)
    }
}

extension Game {
    func brSpend(_ n: Int) -> Bool {
        guard s.ex.gems >= n else { return false }
        var st = s
        st.ex.gems -= n
        s = st
        return true
    }
}

// MARK: settings panel (pause menu + locker)

struct BRSettingsPanel: View {
    var onChange: () -> Void = {}
    @AppStorage("br.sens") private var sens = 1.0
    @AppStorage("br.ads") private var ads = 1.0
    @AppStorage("br.vol") private var vol = 0.8
    @AppStorage("br.lefty") private var lefty = false
    @AppStorage("br.fps") private var fps = true

    var body: some View {
        VStack(spacing: 10) {
            row("LOOK SENSITIVITY", $sens, 0.4...2.2)
            row("ADS SENSITIVITY", $ads, 0.4...2.0)
            row("VOLUME", $vol, 0...1)
            Toggle("LEFT-HANDED LAYOUT", isOn: $lefty).font(.jk(11, .heavy))
            Toggle("SHOW FPS", isOn: $fps).font(.jk(11, .heavy))
        }
        .onChange(of: sens) { _ in onChange() }
        .onChange(of: ads) { _ in onChange() }
        .onChange(of: vol) { _ in onChange() }
        .onChange(of: lefty) { _ in onChange() }
        .onChange(of: fps) { _ in onChange() }
    }

    private func row(_ t: String, _ v: Binding<Double>, _ r: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7))
            Slider(value: v, in: r).tint(Color(red: 0.85, green: 0.93, blue: 0.2))
        }
    }
}

// MARK: locker (lobby)

struct BRLockerView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var tick = 0
    private let lime = Color(red: 0.85, green: 0.93, blue: 0.2)

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack {
                    Text("LOCKER").font(.jk(22, .heavy)).foregroundColor(.white)
                    Spacer()
                    Text("\(game.s.ex.gems) GEMS").font(.jk(13, .heavy)).foregroundColor(lime)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(width: 34, height: 34).background(Color.white.opacity(0.12)).clipShape(Circle())
                    }
                }
                HStack(spacing: 0) {
                    ForEach(Array(["GUN SKINS", "OUTFITS", "CONTRACTS", "SETTINGS"].enumerated()), id: \.offset) { i, n in
                        Button { tab = i } label: {
                            Text(n).font(.jk(11, .heavy)).foregroundColor(tab == i ? .black : .white.opacity(0.8))
                                .frame(maxWidth: .infinity).frame(height: 30).background(tab == i ? lime : Color.white.opacity(0.08))
                        }
                        .buttonStyle(.plain)
                    }
                }
                ScrollView {
                    VStack(spacing: 8) {
                        if tab == 0 { cosmList(BRMeta.skins, current: BRMeta.skin) { BRMeta.skin = $0 } }
                        if tab == 1 { cosmList(BRMeta.outfits, current: BRMeta.outfit) { BRMeta.outfit = $0 } }
                        if tab == 2 { contracts }
                        if tab == 3 { BRSettingsPanel().foregroundColor(.white).padding(.horizontal, 6) }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .id(tick)
    }

    private func cosmList(_ items: [BRCosm], current: String, pick: @escaping (String) -> Void) -> some View {
        let own = BRMeta.owned()
        return VStack(spacing: 6) {
            ForEach(items) { it in
                let has = own.contains(it.id)
                let on = current == it.id
                HStack {
                    Circle().fill(Color(red: it.c.0, green: it.c.1, blue: it.c.2)).frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    Text(it.name).font(.jk(14, .heavy)).foregroundColor(.white)
                    Spacer()
                    Button {
                        if has { pick(it.id) }
                        else if game.brSpend(it.cost) { BRMeta.own(it.id); pick(it.id) }
                        tick += 1
                    } label: {
                        Text(on ? "EQUIPPED" : (has ? "EQUIP" : "\(it.cost) GEMS")).font(.jk(11, .heavy))
                            .foregroundColor(on ? .black : (has || game.s.ex.gems >= it.cost ? .white : .white.opacity(0.4)))
                            .padding(.horizontal, 12).frame(height: 28)
                            .background(on ? lime : Color.white.opacity(0.14)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var contracts: some View {
        VStack(spacing: 6) {
            Text("DAILY CONTRACTS  -  reset every day").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.6))
            ForEach(BRMeta.daily(), id: \.id) { c in
                let p = BRMeta.progress(c)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(c.title).font(.jk(13, .heavy)).foregroundColor(.white)
                        Spacer()
                        Text(p >= c.goal ? "DONE" : "+\(c.reward) GEMS").font(.jk(11, .heavy)).foregroundColor(p >= c.goal ? lime : .white.opacity(0.7))
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12)).frame(height: 6)
                        GeometryReader { g in
                            Capsule().fill(lime).frame(width: g.size.width * CGFloat(min(1, Double(p) / Double(c.goal))), height: 6)
                        }.frame(height: 6)
                    }
                    Text("\(p) / \(c.goal)").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.6))
                }
                .padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
