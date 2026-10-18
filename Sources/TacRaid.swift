import SwiftUI
import UIKit

// MARK: - persistent stash

struct RaidItem: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var kind: String        // val, gun, part, intel
    var name: String
    var value: Int
    var ref = ""
    var issued = false
}

enum TacStash {
    static let cap = 40
    private static let key = "ms.stash.v1"

    static var items: [RaidItem] {
        get {
            guard let d = UserDefaults.standard.data(forKey: key), let a = try? JSONDecoder().decode([RaidItem].self, from: d) else { return [] }
            return a
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(d, forKey: key) }
        }
    }

    static var totalValue: Int { items.reduce(0) { $0 + $1.value } }

    // backpack
    static let packNames = ["SMALL PACK", "FIELD PACK", "ASSAULT PACK", "TACTICAL PACK"]
    static let packCaps = [6, 10, 14, 20]
    static let packCosts = [0, 80, 220, 500]
    private static let packKey = "ms.pack.tier"
    static var packTier: Int {
        get { max(0, min(3, UserDefaults.standard.integer(forKey: packKey))) }
        set { UserDefaults.standard.set(max(0, min(3, newValue)), forKey: packKey) }
    }
    static var packCap: Int { packCaps[packTier] }

    // raid weapon (a stash gun risked in the next raid)
    private static let kitKey = "ms.kit.id"
    static var kitId: String? {
        get { UserDefaults.standard.string(forKey: kitKey) }
        set { if let v = newValue { UserDefaults.standard.set(v, forKey: kitKey) } else { UserDefaults.standard.removeObject(forKey: kitKey) } }
    }

    /// moves an extracted bag into the stash. Parts unlock instantly, overflow is sold. Returns the gems the overflow was worth.
    @discardableResult
    static func commit(_ bag: [RaidItem]) -> Int {
        var cur = items
        var sold = 0
        for it in bag {
            if it.kind == "part" { if !it.ref.isEmpty { TAtt.own(it.ref) }; continue }
            if it.kind == "intel" { sold += it.value; continue }
            if it.kind == "ammo" || it.kind == "med" { continue }
            if it.kind == "gun" && it.issued { continue }
            if cur.count < cap { cur.append(it) } else { sold += it.value }
        }
        items = cur
        return sold
    }

    static func remove(_ id: String) {
        items = items.filter { $0.id != id }
    }
}

// MARK: - raid rules

struct RaidZone {
    let pos: CGPoint
    let name: String
    let key: Bool
    let hold: CGFloat
    let loud: Bool
}

extension TacticalEngine {
    static let raidZones: [RaidZone] = [
        RaidZone(pos: CGPoint(x: 2740 + 3200, y: 440), name: "EAST GATE", key: false, hold: 8, loud: false),
        RaidZone(pos: CGPoint(x: 1500 + 3200, y: 900), name: "CENTRAL YARD", key: false, hold: 14, loud: true),
        RaidZone(pos: CGPoint(x: 1500 + 3200, y: 1650), name: "SOUTH DOCK", key: true, hold: 8, loud: false)
    ]

    var bagValue: Int { raidBag.reduce(0) { $0 + $1.value } }
    var raidBagFull: Bool { raidBag.count >= TacStash.packCap }

    static func isBagKind(_ id: String) -> Bool {
        let k = id.split(separator: ":").first.map(String.init) ?? ""
        return ["val", "part", "intel", "g", "med", "ammo"].contains(k)
    }

    var contractText: String {
        switch contractKind {
        case 0: return "ELIMINATE 4 HOSTILES  \(min(4, me.kills))/4"
        case 1: return raidBag.contains(where: { $0.kind == "intel" }) ? "INTEL SECURED" : "RECOVER THE INTEL (OFFICE)"
        default: return "SECURE 3 VALUABLES  \(min(3, raidBag.filter { $0.kind == "val" }.count))/3"
        }
    }

    func raidNote(_ s: String) { raidMsg = s; raidMsgT = 2.5 }

    func raidStart() {
        loot = TMap.lootSpots.map { Loot(pos: $0.0, id: $0.1, taken: false) }
        raidBag = [RaidItem(kind: "ammo", name: "Ammo Box", value: 20), RaidItem(kind: "ammo", name: "Ammo Box", value: 20)]
        raidEquipped = nil
        raidBagOpen = false
        if let kid = TacStash.kitId, let it = TacStash.items.first(where: { $0.id == kid }), it.kind == "gun" {
            raidEquipped = it
            TacStash.remove(kid)
            setGun(me, it.ref)
        }
        TacStash.kitId = nil
        raidHasKey = false
        raidZoneT = 0
        raidZoneIdx = -1
        raidExtracted = false
        raidLoudT = 0
        contractKind = Int.random(in: 0..<3)
        contractDone = false
        contractReward = [40, 60, 50][contractKind]
        brPlace = 0
        brEndT = 3
        raidNote("DEPLOYED  ·  FIND LOOT, EXTRACT ALIVE")
    }

    var raidGems: Int {
        (won ? 25 : 5) + kills * 3 + (won && contractDone ? contractReward : 0)
    }

    private func raidCollect(_ id: String) {
        let parts = id.split(separator: ":").map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        switch parts[0] {
        case "val":
            let v = parts.count > 2 ? (Int(parts[2]) ?? 100) : 100
            raidBag.append(RaidItem(kind: "val", name: arg, value: v))
            raidNote("+ \(arg.uppercased())  ($\(v))")
        case "part":
            raidBag.append(RaidItem(kind: "part", name: TAtt.def(arg)?.name ?? arg, value: 0, ref: arg))
            raidNote("+ \((TAtt.def(arg)?.name ?? arg).uppercased())")
        case "intel":
            raidBag.append(RaidItem(kind: "intel", name: "Intel", value: 150))
            raidNote("INTEL RECOVERED")
        case "key":
            raidHasKey = true
            raidNote("ACCESS CARD  ·  SOUTH DOCK UNLOCKED")
        case "g":
            raidBag.append(RaidItem(kind: "gun", name: TGuns.get(arg).name, value: max(40, Int(TWeapons.w(arg).price) / 5), ref: arg))
            raidNote("+ \(TGuns.get(arg).name.uppercased())  ·  EQUIP FROM BAG")
        case "med":
            raidBag.append(RaidItem(kind: "med", name: "Medkit", value: 25))
            raidNote("+ MEDKIT")
        case "ammo":
            raidBag.append(RaidItem(kind: "ammo", name: "Ammo Box", value: 20))
            raidNote("+ AMMO BOX")
        default:
            break
        }
    }

    func raidFeedAmmo() {
        guard let i = raidBag.firstIndex(where: { $0.kind == "ammo" }) else { return }
        raidBag.remove(at: i)
        me.spare = min(8, me.spare + 2)
        raidNote("+2 MAGS FROM BACKPACK")
    }

    func raidUse(_ id: String) {
        guard let i = raidBag.firstIndex(where: { $0.id == id }) else { return }
        let it = raidBag[i]
        switch it.kind {
        case "med":
            guard me.hp < 100 else { raidNote("ALREADY AT FULL HEALTH"); return }
            raidBag.remove(at: i)
            me.hp = min(100, me.hp + 45)
            pop(me.pos, "+45", .green)
        case "ammo":
            guard !TWeapons.isPistol(me.gun), me.spare < 6 else { raidNote("AMMO FULL"); return }
            raidBag.remove(at: i)
            me.spare = min(8, me.spare + 2)
            pop(me.pos, "AMMO", .yellow)
        case "gun":
            raidBag.remove(at: i)
            let cur = me.gun
            let prev = raidEquipped ?? RaidItem(kind: "gun", name: TGuns.get(cur).name + " (issued)", value: 0, ref: cur, issued: true)
            raidBag.append(prev)
            raidEquipped = it
            setGun(me, it.ref)
            raidNote("EQUIPPED \(TGuns.get(it.ref).name.uppercased())")
        default:
            break
        }
    }

    func raidDrop(_ id: String) {
        raidBag.removeAll { $0.id == id }
    }

    func raidAlertBots() {
        for p in players where !p.isPlayer && p.alive { p.lastSeen = me.pos; p.hunt = 6 }
    }

    func raidTick(_ dt: CGFloat) {
        for i in loot.indices where !loot[i].taken {
            let lp = loot[i].pos
            let lf = TMap.floorOf(lp)
            for p in players where p.alive && TMap.floorOf(p.pos) == lf && tDist(p.pos, lp) < 28 {
                if lootUse(p, loot[i].id, apply: true) {
                    loot[i].taken = true
                    if p.isPlayer { raidCollect(loot[i].id) }
                    break
                } else if p.isPlayer && raidBagFull && TacticalEngine.isBagKind(loot[i].id) && raidMsgT <= 0 {
                    raidNote("BACKPACK FULL  ·  OPEN BAG TO DROP ITEMS")
                }
            }
        }
        raidMsgT = max(0, raidMsgT - dt)
        if !contractDone {
            switch contractKind {
            case 0: contractDone = me.kills >= 4
            case 1: contractDone = raidBag.contains(where: { $0.kind == "intel" })
            default: contractDone = raidBag.filter { $0.kind == "val" }.count >= 3
            }
            if contractDone { raidNote("CONTRACT COMPLETE  ·  EXTRACT TO CLAIM +\(contractReward)") }
        }
        if me.alive && !raidExtracted {
            var inZ = -1
            for (i, z) in TacticalEngine.raidZones.enumerated() where tDist(me.pos, z.pos) < 55 { inZ = i }
            if inZ != raidZoneIdx {
                raidZoneIdx = inZ
                raidZoneT = 0
                if inZ >= 0 {
                    let z = TacticalEngine.raidZones[inZ]
                    if z.key && !raidHasKey { raidNote("ACCESS CARD REQUIRED") }
                    else if z.loud { raidNote("LOUD EXTRACTION  ·  HOSTILES ALERTED"); raidAlertBots() }
                    else { raidNote("EXTRACTING  ·  HOLD POSITION") }
                }
            }
            if inZ >= 0 {
                let z = TacticalEngine.raidZones[inZ]
                if !(z.key && !raidHasKey) {
                    raidZoneT += dt
                    if z.loud {
                        raidLoudT -= dt
                        if raidLoudT <= 0 { raidLoudT = 3; raidAlertBots() }
                    }
                    if raidZoneT >= z.hold {
                        raidExtracted = true
                        phase = 4
                        over = true
                        won = true
                        banner = "EXTRACTED"
                        bannerT = 3
                    }
                }
            }
        }
        if !me.alive {
            brEndT -= dt
            if brEndT <= 0 { phase = 4; over = true; won = false; banner = "K.I.A."; bannerT = 3 }
        }
    }

    /// bots patrol rooms, scavenge nearby loot and sometimes hunt the player
    func raidGoal(_ p: TPlayer) -> CGPoint {
        if p.roam != .zero && p.goalT > time && tDist(p.pos, p.roam) > 40 { return p.roam }
        p.goalT = time + CGFloat.random(in: 4...8)
        var dest = p.roam
        var best: CGPoint? = nil
        var bs = CGFloat.greatestFiniteMagnitude
        for l in loot where !l.taken {
            if !lootUse(p, l.id, apply: false) { continue }
            let d = tDist(l.pos, p.pos)
            if d < 700 && d < bs { bs = d; best = l.pos }
        }
        if let b = best {
            dest = b
        } else if me.alive && Int.random(in: 0..<100) < 30 && tDist(p.pos, me.pos) < 1300 {
            dest = me.pos
        } else if let r = TMap.rooms.randomElement() {
            dest = CGPoint(x: r.r.midX + CGFloat.random(in: -50...50), y: r.r.midY + CGFloat.random(in: -50...50))
        }
        p.roam = dest
        return dest
    }
}

// MARK: - HUD

struct HudRaidBar: View {
    let e: TacticalEngine
    var body: some View {
        let inZ = e.raidZoneIdx
        return VStack(spacing: 3) {
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    SF(e.contractDone ? "checkmark.circle.fill" : "doc.text.fill").font(.system(size: 12, weight: .bold)).foregroundColor(e.contractDone ? TUI.green : TUI.gold)
                    Text(e.contractText).font(.jk(11, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
                HStack(spacing: 4) {
                    SF("bag.fill", "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(TUI.accent)
                    Text("\(e.raidBag.count)").font(.system(size: 16, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text("$\(e.bagValue)").font(.jk(11, .heavy)).foregroundColor(TUI.green)
                }
                if e.raidHasKey {
                    SF("key.fill", "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(TUI.gold)
                }
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
                HStack(spacing: 4) {
                    SF("scope", "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(TUI.gold)
                    Text("\(e.me.kills)").font(.system(size: 16, weight: .heavy, design: .rounded)).monospacedDigit()
                }
            }
            .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).hudFloat(18)
            if inZ >= 0 {
                let z = TacticalEngine.raidZones[inZ]
                let need = z.key && !e.raidHasKey
                VStack(spacing: 2) {
                    Text(need ? "\(z.name)  ·  ACCESS CARD REQUIRED" : "EXTRACTING  ·  \(z.name)").font(.jk(10, .heavy)).foregroundColor(need ? TUI.red : TUI.green)
                    Capsule().fill(Color.white.opacity(0.22)).frame(width: 180, height: 7)
                        .overlay(alignment: .leading) { Capsule().fill(TUI.green).frame(width: 180 * min(1, e.raidZoneT / max(1, z.hold)), height: 7) }
                }
            } else if e.raidMsgT > 0 {
                Text(e.raidMsg).font(.jk(10, .heavy)).foregroundColor(.white).shadow(color: .black.opacity(0.8), radius: 2)
            }
        }
    }
}

// MARK: - stash screen

struct CSStash: View {
    @EnvironmentObject var game: Game
    let back: () -> Void
    @State private var tick = 0

    private func icon(_ k: String) -> String {
        switch k { case "gun": return "scope"; case "part": return "wrench.and.screwdriver.fill"; case "intel": return "doc.text.fill"; default: return "diamond.fill" }
    }

    private func sell(_ it: RaidItem) {
        var st = game.s
        st.ex.gems += it.value
        game.s = st
        TacStash.remove(it.id)
        tick += 1
    }

    private var packPanel: some View {
        let t = TacStash.packTier
        let next = t + 1 < TacStash.packNames.count ? t + 1 : nil
        return HStack(spacing: 10) {
            SF("bag.fill", "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(TUI.accent)
            Text("\(TacStash.packNames[t])  ·  \(TacStash.packCap) SLOTS").font(.jk(12, .heavy)).foregroundColor(.white)
            if let n = next {
                Button {
                    let cost = TacStash.packCosts[n]
                    guard game.s.ex.gems >= cost else { return }
                    var st = game.s
                    st.ex.gems -= cost
                    game.s = st
                    TacStash.packTier = n
                    tick += 1
                } label: {
                    HStack(spacing: 4) {
                        Text("UPGRADE  \(TacStash.packNames[n])").font(.jk(10, .heavy))
                        SF("diamond.fill").font(.system(size: 9))
                        Text("\(TacStash.packCosts[n])").font(.jk(10, .heavy))
                    }
                    .foregroundColor(game.s.ex.gems >= TacStash.packCosts[n] ? .black : .white.opacity(0.6)).padding(.horizontal, 8).frame(height: 24)
                    .background(Rectangle().fill(game.s.ex.gems >= TacStash.packCosts[n] ? CS.gold : Color.white.opacity(0.15)))
                }
                .buttonStyle(TuiPress())
            } else {
                Text("MAX").font(.jk(10, .heavy)).foregroundColor(TUI.green)
            }
            Spacer()
            if let k = TacStash.kitId, let it = TacStash.items.first(where: { $0.id == k }) {
                Text("RAID WEAPON: \(it.name.uppercased())").font(.jk(10, .heavy)).foregroundColor(Color(red: 0.4, green: 0.95, blue: 0.4))
            } else {
                Text("RAID WEAPON: ISSUED").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 28).padding(.top, 6)
    }

    private func sellAll() {
        let total = TacStash.totalValue
        var st = game.s
        st.ex.gems += total
        game.s = st
        TacStash.items = []
        TacStash.kitId = nil
        tick += 1
    }

    var body: some View {
        _ = tick
        let items = TacStash.items
        return GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                VStack(spacing: 0) {
                    CSHeader(title: "STASH", cash: game.s.ex.gems, coins: (game.s.ex.tac ?? TacData()).wins, back: back).padding(.top, 8)
                    packPanel
                    HStack(spacing: 14) {
                        Text("\(items.count)/\(TacStash.cap) SLOTS").font(.jk(12, .heavy)).foregroundColor(.white.opacity(0.8))
                        Text("VALUE $\(TacStash.totalValue)").font(.jk(12, .heavy)).foregroundColor(TUI.green)
                        Spacer()
                        CSButton(title: "SELL ALL", col: CS.orange, dark: CS.orangeDark, w: 130, h: 32, size: 12) { sellAll() }
                    }
                    .padding(.horizontal, 28).padding(.top, 8)
                    if items.isEmpty {
                        Spacer()
                        VStack(spacing: 6) {
                            SF("bag.fill", "circle.fill").font(.system(size: 34)).foregroundColor(.white.opacity(0.35))
                            Text("Your stash is empty").font(.jk(16, .heavy)).foregroundColor(.white.opacity(0.8))
                            Text("Deploy on an Extraction raid, loot the Warehouse Yard and extract alive to keep what you find.").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.55)).multilineTextAlignment(.center)
                        }
                        .frame(width: min(W - 80, 420))
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                                ForEach(items) { it in
                                    HStack(spacing: 8) {
                                        SF(icon(it.kind), "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(it.kind == "gun" ? TUI.blue : TUI.gold).frame(width: 26)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(it.name).font(.jk(12, .heavy)).foregroundColor(.white).lineLimit(1)
                                            Text(it.kind == "gun" ? "WEAPON" : "VALUABLE").font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer(minLength: 0)
                                        if it.kind == "gun" {
                                            let on = TacStash.kitId == it.id
                                            Button { TacStash.kitId = on ? nil : it.id; tick += 1 } label: {
                                                Text(on ? "KIT ✓" : "EQUIP").font(.jk(10, .heavy)).foregroundColor(on ? .black : .white).padding(.horizontal, 7).frame(height: 24).background(Rectangle().fill(on ? Color(red: 0.4, green: 0.95, blue: 0.4) : CS.blue))
                                            }
                                            .buttonStyle(TuiPress())
                                        }
                                        Button { sell(it) } label: {
                                            Text("$\(it.value)").font(.jk(11, .heavy)).foregroundColor(.black).padding(.horizontal, 8).frame(height: 24).background(Rectangle().fill(CS.gold))
                                        }
                                        .buttonStyle(TuiPress())
                                    }
                                    .padding(8).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 28).padding(.vertical, 10)
                        }
                    }
                }
            }
            .frame(width: W, height: H)
        }
    }
}


// MARK: - in-raid backpack

struct RaidBagPanel: View {
    let e: TacticalEngine

    private func icon(_ k: String) -> String {
        switch k { case "gun": return "scope"; case "med": return "cross.case.fill"; case "ammo": return "shippingbox.fill"; case "part": return "wrench.and.screwdriver.fill"; case "intel": return "doc.text.fill"; default: return "diamond.fill" }
    }

    private func label(_ it: RaidItem) -> String {
        switch it.kind { case "gun": return "EQUIP"; case "med": return "USE"; case "ammo": return "LOAD"; default: return "" }
    }

    var body: some View {
        let cap = TacStash.packCap
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { e.raidBagOpen = false }
            VStack(spacing: 8) {
                HStack {
                    SF("bag.fill", "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(TUI.accent)
                    Text(TacStash.packNames[TacStash.packTier]).font(.jk(14, .heavy)).foregroundColor(.white)
                    Text("\(e.raidBag.count)/\(cap)").font(.jk(13, .heavy)).foregroundColor(e.raidBagFull ? TUI.red : TUI.green)
                    Spacer()
                    Text("EQUIPPED: \(TGuns.get(e.me.gun).name.uppercased())").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7))
                    Button { e.raidBagOpen = false } label: {
                        SF("xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white).frame(width: 30, height: 30).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(TuiPress())
                }
                if e.raidBag.isEmpty {
                    Text("Backpack is empty").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(e.raidBag) { it in
                                HStack(spacing: 8) {
                                    SF(icon(it.kind), "circle.fill").font(.system(size: 15, weight: .bold)).foregroundColor(it.kind == "gun" ? TUI.blue : TUI.gold).frame(width: 24)
                                    Text(it.name).font(.jk(12, .heavy)).foregroundColor(.white).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if it.value > 0 { Text("$\(it.value)").font(.jk(10, .heavy)).foregroundColor(TUI.green) }
                                    if !label(it).isEmpty {
                                        Button { e.raidUse(it.id) } label: {
                                            Text(label(it)).font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 8).frame(height: 22).background(Rectangle().fill(CS.gold))
                                        }
                                        .buttonStyle(TuiPress())
                                    }
                                    Button { e.raidDrop(it.id) } label: {
                                        Text("DROP").font(.jk(10, .heavy)).foregroundColor(.white).padding(.horizontal, 8).frame(height: 22).background(Rectangle().fill(Color.white.opacity(0.18)))
                                    }
                                    .buttonStyle(TuiPress())
                                }
                                .padding(8).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }
                    .frame(maxHeight: 190)
                }
            }
            .padding(14).frame(width: 440).background(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.96)).overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
    }
}
