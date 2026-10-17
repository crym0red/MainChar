import SwiftUI

// MARK: - Models

struct Coin: Codable, Identifiable, Hashable {
    var id: String            // ticker
    var name: String
    var creator: String       // npc handle or player handle
    var symbol: String
    var hue: Double
    var price: Double
    var hist: [Double]
    var born: Date
    var liq: Double
    var rugged = false
    var ruggedAt: Date? = nil
    var drift: Double = 0
    var vol: Double = 0.05
    var rugP: Double = 0.002
    var mine = false
    var holders: Int = 10
    var peak: Double = 0
    var pumpedAt: Date? = nil
    var lastShill: Date? = nil
    var start: Double = 0
    var pool: Double? = nil
    var looted: Double? = nil
    var fx: [String: Date]? = nil
    var crashed: Bool? = nil
    var whale: Double? = nil
    var susp: Int? = nil
    var interest: Double? = nil
    var tr: Int? = nil
    func fxOn(_ k: String) -> Bool { (fx?[k] ?? .distantPast) > Date() }
    var poolV: Double { pool ?? liq }
}

struct CoinMsg: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var handle: String
    var name: String
    var emoji: String
    var text: String
    var at: Date
    var me = false
    var dev = false
    var sys = false
}

struct Holding: Codable, Hashable, Identifiable {
    var id: String            // ticker
    var qty: Double
    var cost: Double
}

struct Market: Codable, Hashable {
    var coins: [Coin] = []
    var holds: [Holding] = []
    var realized: Double = 0
    var dust: Double = 0
    var launched = 0
    var rugsPulled = 0
    var rugsTaken = 0
    var airdropDay: String? = nil
    var chats: [String: [CoinMsg]]? = nil
    var watch: [String]? = nil
    var lords: [String: Double]? = nil
    var lootEarned: Double? = nil
    var lootLost: Double? = nil
    var inv: [String: Int]? = nil
    var feesPaid: Double? = nil
    var dev: [String: DevRec]? = nil
}

struct DevRec: Codable, Hashable {
    var rugs = 0
    var loot = 0.0
    var boycott: Date? = nil
}

struct TrustPart: Identifiable, Hashable {
    var id: String
    var delta: Int
    var note: String
}

struct TrustInfo {
    var score: Int
    var parts: [TrustPart]
    var rugs: Int
    var loot: Double
    var conc: Double
}

enum Booster: String, CaseIterable, Identifiable {
    case lock, whale, maker, hype, pump
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lock: return "Crash Lock"
        case .whale: return "Whale Shield"
        case .maker: return "Market Maker"
        case .hype: return "Hype Engine"
        case .pump: return "Influencer Pump"
        }
    }
    var desc: String {
        switch self {
        case .lock: return "Blocks market crashes on one of your coins for 6 hours."
        case .whale: return "Blocks whale dumps on one of your coins for 6 hours."
        case .maker: return "Cuts volatility by more than half and stops the slow bleed for 6 hours."
        case .hype: return "Steady buying pressure and new holders for 2 hours."
        case .pump: return "An instant spike of 35 to 70% and a rush of new holders."
        }
    }
    var price: Int {
        switch self {
        case .lock: return 30
        case .whale: return 25
        case .maker: return 40
        case .hype: return 20
        case .pump: return 15
        }
    }
    var hours: Int {
        switch self {
        case .lock, .whale, .maker: return 6
        case .hype: return 2
        case .pump: return 0
        }
    }
    var emoji: String {
        switch self {
        case .lock: return "🔒"
        case .whale: return "🛡"
        case .maker: return "🏦"
        case .hype: return "🔥"
        case .pump: return "📣"
        }
    }
}

enum Mk {
    static let launchFee = 50
    static let feeRate = 0.03
    static func fee(_ x: Double) -> Double { max(1, x * feeRate) }
    static let sceneA = ["Dylib", "Sideload", "Kernel", "Rootless", "Jelbrek", "Revoke", "Entitle", "Signer", "Tweak", "Patch", "Sandbox", "Cert", "Ghost", "Zero"]
    static let genA = ["Moon", "Froggo", "Chad", "Rizz", "Aura", "Clout", "Degen", "Ape", "Pump", "Turbo", "Cope", "Based"]
    static let tail = ["Coin", "Inu", "Cash", "Token", "Swap", "DAO", "Fi", "Moon", "Gold"]
    static let symbols = ["bitcoinsign.circle.fill", "bolt.fill", "flame.fill", "pawprint.fill", "moon.fill", "lock.open.fill",
                          "terminal.fill", "cpu", "leaf.fill", "crown.fill", "ladybug.fill", "star.fill"]

    static let supply = 1_000_000.0
    static func mc(_ c: Coin) -> Double { c.price * supply }
    static func fmtMC(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "$%.1fK", v / 1_000) }
        return String(format: "$%.0f", v)
    }
    static func usdPrice(_ p: Double) -> String {
        let d = p / 1000
        return d >= 0.01 ? String(format: "$%.4f", d) : String(format: "$%.8f", d)
    }
    static func pct(_ ch: Double) -> String {
        let v = ch * 100
        let sign = v >= 0 ? "+" : "-"
        let a = abs(v)
        if a >= 100 {
            let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
            return sign + (f.string(from: NSNumber(value: a)) ?? "\(Int(a))") + "%"
        }
        return sign + String(format: "%.2f", a) + "%"
    }

    static func gauss() -> Double {
        let u = Double.random(in: 0.0001...1), v = Double.random(in: 0...1)
        return sqrt(-2 * log(u)) * cos(2 * Double.pi * v)
    }

    static func fmtPrice(_ p: Double) -> String {
        if p >= 1 { return String(format: "%.2f", p) }
        if p >= 0.01 { return String(format: "%.4f", p) }
        return String(format: "%.6f", p)
    }

    static func fmtGems(_ v: Double) -> String {
        abs(v) >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    static func change(_ c: Coin) -> Double {
        guard let f = c.hist.first, f > 0 else { return 0 }
        return c.price / f - 1
    }

    static func risk(_ c: Coin) -> String {
        if c.mine { return "Yours" }
        return label(c.tr ?? 70)
    }

    static func label(_ score: Int) -> String {
        score >= 72 ? "Low" : (score >= 52 ? "Medium" : (score >= 32 ? "High" : "Degen"))
    }

    static func advice(_ score: Int) -> String {
        if score >= 72 { return "Rug risk is low. Deployers with this profile rarely pull." }
        if score >= 52 { return "Rug risk is moderate. Watch the whales and the deployer." }
        if score >= 32 { return "Rug risk is high. Only gamble what you can lose." }
        return "Degen territory. A rug is likely. Size accordingly."
    }

    static func devSeed(_ handle: String, _ trait: Trait?) -> (rugs: Int, loot: Double) {
        let h = HK.h(handle) % 4
        var r = 0
        switch trait {
        case .chaos?, .hater?: r = 1 + h % 3
        case .mogul?: r = h % 3
        case .hype?: r = h % 2
        case .gossip?: r = h == 0 ? 1 : 0
        default: r = 0
        }
        return (r, Double(r) * Double(40 + h * 25))
    }

    static func conc(_ c: Coin) -> Double {
        min(0.9, (c.whale ?? 0.25) * (30 / max(30, Double(c.holders))).squareRoot())
    }

    static func trust(_ c: Coin, _ trait: Trait?, _ m: Market) -> TrustInfo {
        let rec = m.dev?[c.creator]
        var rugs = rec?.rugs ?? 0
        var loot = rec?.loot ?? 0
        if c.mine {
            rugs = max(rugs, m.rugsPulled)
            loot = max(loot, m.lootEarned ?? 0)
        } else {
            let sd = devSeed(c.creator, trait)
            rugs += sd.rugs
            loot += sd.loot
        }
        let boycott = (rec?.boycott ?? .distantPast) > Date()
        var parts: [TrustPart] = []
        parts.append(TrustPart(id: "dev", delta: -min(50, rugs * 17), note: rugs == 0 ? "Clean deployer record" : "\(rugs) prior rug\(rugs == 1 ? "" : "s") by this deployer"))
        if loot > 0 { parts.append(TrustPart(id: "loot", delta: -min(10, Int(loot / 40)), note: "Pocketed \(fmtGems(loot)) gems in past payouts")) }
        let cn = conc(c)
        parts.append(TrustPart(id: "conc", delta: -Int(cn * 45), note: "Top wallets hold \(Int(cn * 100))% of supply"))
        let su = c.susp ?? 0
        parts.append(TrustPart(id: "susp", delta: -min(20, su * 5), note: su == 0 ? "No suspicious moves" : "\(su) flagged wallet move\(su == 1 ? "" : "s")"))
        let it = c.interest ?? 0.7
        parts.append(TrustPart(id: "int", delta: Int((it - 0.5) * 20), note: "Community interest \(Int(it * 100))%"))
        let ageH = Date().timeIntervalSince(c.born) / 3600
        parts.append(TrustPart(id: "age", delta: min(10, Int(ageH * 2)), note: ageH < 1 ? "Brand new launch" : "Survived \(ageH < 24 ? "\(Int(ageH))h" : "\(Int(ageH / 24))d")"))
        if boycott { parts.append(TrustPart(id: "boy", delta: -15, note: "Community boycott after the last rug")) }
        var sum = 0
        for p in parts { sum += p.delta }
        return TrustInfo(score: max(3, min(98, 85 + sum)), parts: parts, rugs: rugs, loot: loot, conc: cn)
    }

    static func tickers(_ text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: "\\$([A-Z0-9]{2,6})") else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }
}

enum CoinEvent { case rug, crash, pump(Double) }

// MARK: - Engine

extension Game {
    private func mkCm(_ n: NPC, _ text: String) -> Comment {
        Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: text, verified: n.followers >= 40000)
    }

    func makeCoin(_ st: GameState, by npc: NPC, backfill: Bool) -> Coin {
        let scene = CastGen.isScene(st.world)
        let a = (scene ? Mk.sceneA : Mk.genA).randomElement() ?? "Moon"
        let b = Mk.tail.randomElement() ?? "Coin"
        let have = Set((st.ex.market?.coins ?? []).map { $0.id })
        var t = String(a.uppercased().filter { $0.isLetter }.prefix(4))
        if have.contains(t) { t = String(t.prefix(3)) + String(b.uppercased().prefix(1)) }
        if have.contains(t) { t += String(Int.random(in: 2...9)) }
        var rugP: Double
        switch npc.trait {
        case .chaos, .hater: rugP = 0.0004
        case .mogul: rugP = 0.00025
        case .hype: rugP = 0.0002
        case .gossip: rugP = 0.00012
        default: rugP = 0.00004
        }
        rugP *= Double.random(in: 0.6...1.4)
        let start = Double.random(in: 0.0008...0.04)
        var c = Coin(id: t, name: a + " " + b, creator: npc.handle, symbol: Mk.symbols.randomElement() ?? "star.fill",
                     hue: Double.random(in: 0...1), price: start, hist: [start], born: Date(),
                     liq: Double.random(in: 25...320), rugP: rugP, holders: Int.random(in: 6...80), start: start)
        c.vol = Double.random(in: 0.07...0.16)
        c.peak = start
        if backfill {
            for _ in 0..<45 { _ = stepCoin(&c, quiet: true) }
            c.born = Date().addingTimeInterval(-Double.random(in: 1800...40000))
            c.rugged = false
            c.price = max(c.price, start * 0.25)
            c.hist[c.hist.count - 1] = c.price
            c.pool = c.liq
        }
        c.pool = c.pool ?? c.liq
        c.whale = Double.random(in: 0.12...0.6) + ((npc.trait == .chaos || npc.trait == .hater) ? 0.1 : 0)
        c.interest = Double.random(in: 0.55...0.9)
        c.susp = 0
        c.tr = Mk.trust(c, npc.trait, st.ex.market ?? Market()).score
        return c
    }

    func marketEnsure(_ st: inout GameState) {
        var m = st.ex.market ?? Market()
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard !cast.isEmpty else { return }
        var guardN = 0
        while m.coins.filter({ !$0.rugged }).count < 5, guardN < 8 {
            guardN += 1
            var tmp = st; tmp.ex.market = m
            if let n = cast.randomElement() { m.coins.append(makeCoin(tmp, by: n, backfill: true)) }
        }
        st.ex.market = m
    }

    func marketEnsureNow() {
        var st = s
        marketEnsure(&st)
        s = st
    }

    /// One price step. Returns an event worth a headline.
    func stepCoin(_ c: inout Coin, quiet: Bool = false) -> CoinEvent? {
        guard !c.rugged else {
            c.hist.append(c.price)
            if c.hist.count > 60 { c.hist.removeFirst() }
            return nil
        }
        let locked = c.mine && c.fxOn("lock")
        let shielded = c.mine && c.fxOn("whale")
        let steady = c.mine && c.fxOn("maker")
        let tr = Double(c.tr ?? 70) / 100
        c.drift = c.drift * 0.96 - (c.mine ? 0.0006 : 0.0004) + (c.mine ? 0 : (tr - 0.5) * 0.0004)
        c.interest = max(0, (c.interest ?? 0.7) - 0.0003)
        if (c.interest ?? 0.7) < 0.3 { c.drift -= 0.0004 }
        if Double.random(in: 0...1) < 0.012 {
            c.drift += Double.random(in: 0.02...0.07)
            c.interest = min(1, (c.interest ?? 0.7) + 0.06)
        }
        if !c.mine, Double.random(in: 0...1) < 0.01 {
            c.whale = min(0.85, (c.whale ?? 0.25) + 0.05)
            c.drift += 0.008
        }
        if !c.mine, tr < 0.5, Double.random(in: 0...1) < 0.004 { c.susp = min(8, (c.susp ?? 0) + 1) }
        let crashP = c.mine ? (locked ? 0 : 0.005) : 0.005
        if Double.random(in: 0...1) < crashP { c.drift -= Double.random(in: 0.03...0.09) }
        if c.mine && c.fxOn("hype") { c.drift += 0.0003 }
        let v = max(c.vol, c.mine ? 0.11 : 0.08) * (steady ? 0.45 : 1)
        let r = max(-0.4, min(0.4, c.drift + v * Mk.gauss()))
        c.price = max(1e-7, c.price * exp(r))
        if !shielded, Double.random(in: 0...1) < (c.mine ? 0.008 : 0.004) {
            if !c.mine, Mk.conc(c) > 0.3 { c.susp = min(8, (c.susp ?? 0) + 1) }
            c.whale = max(0.03, (c.whale ?? 0.25) * 0.7)
            c.price = max(1e-7, c.price * Double.random(in: 0.72...0.9))
            c.pool = max(2, c.poolV * 0.92)
        }
        c.peak = max(c.peak, c.price)
        c.liq = max(5, c.liq * (1 + r * 0.3))
        c.pool = max(2, c.poolV + r * Double(max(1, c.holders)) * (c.mine ? 0.2 : 0.05))
        c.holders = max(1, c.holders + Int(r * 400) + Int.random(in: -2...3))
        c.hist.append(c.price)
        if c.hist.count > 60 { c.hist.removeFirst() }
        if quiet { return nil }
        let age = Date().timeIntervalSince(c.born) / 3600
        let base = c.start > 0 ? c.start : (c.hist.first ?? c.price)
        if c.price < base * 0.04, age > 0.02 {
            c.rugged = true
            c.crashed = true
            c.looted = 0
            c.ruggedAt = Date()
            c.hist.append(c.price)
            return .crash
        }
        let rugOdds = (0.00003 + pow(1 - tr, 2) * 0.0009) * (1 + min(age, 12) / 6)
        if !c.mine, Double.random(in: 0...1) < rugOdds {
            c.looted = c.poolV
            c.price *= 0.015
            c.liq = 3
            c.rugged = true
            c.ruggedAt = Date()
            c.hist.append(c.price)
            return .rug
        }
        let w = c.hist.suffix(30).first ?? c.price
        let ch = w > 0 ? c.price / w - 1 : 0
        if ch > 0.8, c.pumpedAt == nil || Date().timeIntervalSince(c.pumpedAt ?? .distantPast) > 900 {
            c.pumpedAt = Date()
            return .pump(ch)
        }
        return nil
    }

    func marketAdvance(_ st: inout GameState, _ items: inout [DigestItem], steps: Int, quiet: Bool) {
        marketEnsure(&st)
        guard var m = st.ex.market, steps > 0 else { return }
        var events: [(Coin, CoinEvent)] = []
        let traits = Dictionary(st.npcs.map { ($0.handle, $0.trait) }, uniquingKeysWith: { a, _ in a })
        for _ in 0..<steps {
            for i in m.coins.indices {
                if !m.coins[i].rugged {
                    let t = Mk.trust(m.coins[i], traits[m.coins[i].creator], m).score
                    m.coins[i].tr = t
                }
                if let e = stepCoin(&m.coins[i]) { events.append((m.coins[i], e)) }
            }
        }
        // prune old dead coins and orphan holdings
        let cutoff = Date().addingTimeInterval(-15 * 60)
        let heldIDs = Set(m.holds.map { $0.id })
        m.coins.removeAll { c in c.rugged && (c.ruggedAt ?? .distantPast) < cutoff && !heldIDs.contains(c.id) }
        if m.coins.count > 16 { m.coins.removeAll { c in c.rugged && !c.mine && !heldIDs.contains(c.id) } }
        let liveIDs = Set(m.coins.map { $0.id })
        m.holds.removeAll { h in !liveIDs.contains(h.id) }
        if var ch = m.chats { for k in Array(ch.keys) where !liveIDs.contains(k) { ch[k] = nil }; m.chats = ch }
        if var w = m.watch { w.removeAll { !liveIDs.contains($0) }; m.watch = w }
        st.ex.market = m
        func rank(_ e: CoinEvent) -> Int { if case .rug = e { return 0 }; if case .crash = e { return 1 }; return 2 }
        let ordered = events.sorted { rank($0.1) < rank($1.1) }
        for (c, e) in ordered.prefix(3) { coinHeadline(&st, &items, c, e, quiet: quiet) }
        if var mm = st.ex.market {
            var changed = false
            for (c, e) in events {
                if case .rug = e {
                    var d = mm.dev ?? [:]
                    var r = d[c.creator] ?? DevRec()
                    r.rugs += 1
                    r.loot += c.looted ?? c.poolV
                    r.boycott = Date().addingTimeInterval(3 * 3600)
                    d[c.creator] = r
                    mm.dev = d
                    changed = true
                }
            }
            if changed { st.ex.market = mm }
        }
    }

    func marketAmbient() {
        guard playing, s.intro?.done != false else { return }
        var st = s
        var items: [DigestItem] = []
        marketAdvance(&st, &items, steps: 5, quiet: true)
        checkSeason(&st, &items, quiet: true)
        engagementTick(&st, &items, quiet: true)
        s = st
    }

    func marketTick() {
        guard playing else { return }
        var st = s
        var items: [DigestItem] = []
        marketAdvance(&st, &items, steps: 1, quiet: true)
        s = st
    }

    // MARK: Headlines and feed

    private func coinHeadline(_ st: inout GameState, _ items: inout [DigestItem], _ c: Coin, _ e: CoinEvent, quiet: Bool) {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        let news = st.npcs.first { $0.id == "newsdesk" }
        let creator = st.npcs.first { $0.handle == c.creator }
        let held = st.ex.market?.holds.first { $0.id == c.id }
        switch e {
        case .pump(let ch):
            let pct = Int(ch * 100)
            let text = ["BREAKING: $\(c.id) is up \(pct)% in the last hour. Chat calls it the next 100x. Invest now. Not financial advice.",
                        "$\(c.id) just ripped \(pct)%. Volume is exploding and the scene is piling in. Get in before it's gone.",
                        "MARKET ALERT: $\(c.id) +\(pct)%. Early holders are printing. Late buyers are watching the chart."].randomElement() ?? "$\(c.id) +\(pct)%"
            guard let author = news ?? cast.first else { return }
            var p = makePost(author, text, st)
            p.tag = "Breaking"
            stampPost(&p, st)
            var cs: [Comment] = []
            if let h = cast.filter({ $0.trait == .hype }).randomElement() { cs.append(mkCm(h, "aped in at the bottom. told you all. $\(c.id) to the moon.")) }
            if let h = cast.filter({ $0.trait == .hater }).randomElement() { cs.append(mkCm(h, "this is the top. exit liquidity is you. $\(c.id) is a rug with extra steps.")) }
            if let h = cast.filter({ $0.trait == .chaos }).randomElement() { cs.append(mkCm(h, "sold my phone to buy more $\(c.id). no regrets yet.")) }
            p.comments = cs
            p.likes = max(p.likes * 3, 120)
            st.posts.insert(p, at: 0)
            var detail = "Up \(pct)% and the feed is shouting about it."
            if let h = held { detail += " You hold \(Mk.fmtGems(h.qty * c.price)) gems of it." }
            logEvent(&st, &items, quiet: quiet, emoji: "📈", title: "$\(c.id) pumped \(pct)%", detail: detail, post: p.id,
                     handles: creator.map { [$0.handle] } ?? [], weight: held != nil ? 55 : 35,
                     history: "$\(c.id) pumped \(pct)% and the whole feed noticed.")
        case .crash:
            var mm = st.ex.market ?? Market()
            coinChatBurst(&mm, c, st, loot: 0)
            st.ex.market = mm
            if c.mine {
                notify(&st, "event", "$\(c.id) was delisted", sub: "The market killed it. A Crash Lock or Market Maker would have helped.", handle: st.persona.handle, emoji: "📉")
                st.aura = max(5, st.aura - 3)
            } else if let h = held {
                notify(&st, "event", "$\(c.id) collapsed", sub: "-\(Mk.fmtGems(h.cost)) gems. The market killed it.", handle: c.creator, emoji: "📉")
            }
        case .rug:
            let cn = creator?.name ?? "the deployer"
            let loot = c.looted ?? c.poolV
            var detail = "\(cn) pulled the liquidity and pocketed \(Mk.fmtGems(loot)) gems. Down 98%."
            var w = 60
            var mm = st.ex.market ?? Market()
            var lords = mm.lords ?? [:]
            lords[c.creator, default: 0] += loot
            mm.lords = lords
            coinChatBurst(&mm, c, st, loot: loot)
            if let h = held {
                detail += " You lost \(Mk.fmtGems(h.cost)) gems and \(cn) kept them."
                w = 90
                notify(&st, "event", "You got rugged on $\(c.id)", sub: "-\(Mk.fmtGems(h.cost)) gems. \(cn) pocketed \(Mk.fmtGems(loot)) gems total", handle: c.creator, emoji: "📉")
                mm.rugsTaken += 1
                mm.lootLost = (mm.lootLost ?? 0) + h.cost
                if h.cost >= 10 { st.aura = max(5, st.aura - 2) }
            }
            st.ex.market = mm
            let pid = rugAftermath(&st, &items, c, loot: loot, mine: false, held: held, quiet: quiet)
            if let ch = creator, let v = cast.filter({ $0.handle != ch.handle }).randomElement() {
                _ = escalateFeud(&st, a: ch, b: v, cause: "the $\(c.id) rug")
            }
            logEvent(&st, &items, quiet: quiet, emoji: "💸", title: "$\(c.id) was rugged", detail: detail, post: pid,
                     handles: creator.map { [$0.handle] } ?? [], weight: w,
                     history: "$\(c.id) rugged. \(cn) took the liquidity and vanished.")
        }
    }

    // MARK: Rug aftermath

    private func rugQueue(_ speakers: [NPC], _ lines: [String]) -> [QComment] {
        var q: [QComment] = []
        var at = Date()
        for (i, line) in lines.enumerated() {
            let c: Comment
            if speakers.isEmpty || i % 3 == 2 {
                let u = Crowd.make()
                c = Comment(name: u.name, handle: u.handle, emoji: "🙂", text: line)
            } else {
                let n = speakers[i % speakers.count]
                c = Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: line, verified: n.followers >= 40000)
            }
            at = at.addingTimeInterval(i < 2 ? 1 : Double.random(in: 7...30))
            q.append(QComment(c: c, at: at))
        }
        return q
    }

    /// The public fall: breaking post, receipts, victims, deployer response, revenge promises, a fight.
    @discardableResult
    func rugAftermath(_ st: inout GameState, _ items: inout [DigestItem], _ c: Coin, loot: Double, mine: Bool, held: Holding?, quiet: Bool) -> UUID? {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard let news = st.npcs.first(where: { $0.id == "newsdesk" }) ?? cast.first else { return nil }
        let creator = st.npcs.first { $0.handle == c.creator }
        let me = st.persona
        let dh = mine ? me.handle : c.creator
        let dn = mine ? me.name : (creator?.name ?? "the deployer")
        let others = cast.filter { $0.handle != c.creator }
        let victims = others.filter { $0.trait == .chaos || $0.trait == .wholesome || $0.trait == .hype }.shuffled()
        let haters = others.filter { $0.trait == .hater || $0.trait == .gossip }.shuffled()
        let big = mine || held != nil || loot >= 40
        let score = c.tr ?? 40
        let tm = st.ex.market ?? Market()
        let dv = Mk.trust(c, creator?.trait, tm)
        let prior = mine ? max(0, dv.rugs - 1) : dv.rugs
        let heat = Spicy.heat
        let hue = Double(HK.h(c.id) % 360) / 360
        let t = c.id
        func jab() -> String { "@\(dh) " + (Spicy.jab[heat].randomElement() ?? "unreal") }

        // 1. breaking
        var text = "BREAKING: $\(t) rugged. \(dn) pulled the liquidity, walked off with \(Mk.fmtGems(loot)) gems from \(c.holders) holders and the price is down 98%."
        text += mine ? " @\(dh) has not responded." : (creator != nil ? " @\(dh) has not responded." : "")
        var brk = makePost(news, text, st)
        brk.tag = "Breaking"
        stampPost(&brk, st)
        brk.likes = max(brk.likes * 4, 200)
        brk.viral = true
        brk.comments = []
        brk.queue = rugQueue(Array(cast.shuffled().prefix(4)), [
            "\(dn) did this on purpose. the wallet history says everything.",
            "the trust score was \(score) and everyone aped anyway.",
            "so sorry to everyone who lost money on $\(t). please be careful out there.",
            jab(),
            "i was in. i am now a different person.",
            prior > 0 ? "\(prior) prior rug\(prior == 1 ? "" : "s") on this deployer and nobody checked." : "first time for \(dn) and somehow it still hurts.",
            "allegedly \(dn) moved supply before the dump. receipts incoming.",
            jab()
        ])

        var out: [Post] = []

        // 2. receipts
        if let g = haters.first {
            let lines = [
                "[-42m] deployer funded a fresh wallet",
                "[-27m] top wallets hold \(Int(dv.conc * 100))% of supply",
                "[-14m] \(max(1, c.susp ?? 1)) flagged transfers out of the dev wallet",
                "[-3m]  liquidity removed: \(Mk.fmtGems(loot)) gems",
                "[now]  trust score at rug: \(score)/100",
                "deployer history: \(prior) prior rug\(prior == 1 ? "" : "s"), \(Mk.fmtGems(dv.loot)) gems pocketed before"
            ]
            var p = makePost(g, ["receipts on $\(t). \(dn)'s wallet, read it before it gets deleted 🧾", "i pulled the \(dn) wallet trail for $\(t). it is exactly what you think.", "not saying i called it. but the \(t) receipts are right here."].randomElement() ?? "receipts",  st)
            p.tag = "Receipts"
            p.poll = nil
            p.media = Media(kind: "code", title: "\(t)_onchain.log", lines: lines, hue: hue)
            stampPost(&p, st)
            p.likes = max(p.likes * 3, 120)
            p.comments = []
            p.queue = rugQueue(Array(cast.shuffled().prefix(3)), ["this is damning.", "the 27 minute line gets me. everyone saw this coming.", jab(), "pinning this to my profile so nobody forgets", "someone get this to the newsdesk"])
            out.append(p)
        }

        // 3. victim quote post
        if let v = victims.first {
            let lost = held.map { Mk.fmtGems($0.cost) } ?? "\(Int.random(in: 20...90))"
            var p = makePost(v, ["i put \(lost) gems into $\(t) because the chart looked healthy. never again.", "\(lost) gems. gone. i'm not even mad, i'm just numb.", "me watching $\(t) go to zero with \(lost) gems in it 🫠"].randomElement() ?? "gone", st)
            p.tag = "Rugged"
            p.poll = nil; p.media = nil
            p.quote = Quote(handle: news.handle, name: news.name, text: String(text.prefix(140)))
            stampPost(&p, st)
            p.comments = []
            p.queue = rugQueue(Array(cast.shuffled().prefix(3)), ["it happens to the best of us. well, the worst of us.", "same. down bad.", "f", "this scene is cooked"])
            out.append(p)
        }

        // 4. deployer response
        if big, !mine, let d = creator {
            var p = makePost(d, ["$\(t) was not a rug. the liquidity was rebalanced. stop harassing me.", "i'm not responding to accusations. the work speaks for itself.", "everyone loses sometimes. it's called a market. move on."].randomElement() ?? "no comment", st)
            p.tag = "Response"
            p.poll = nil; p.media = nil
            if let rc = out.first(where: { $0.tag == "Receipts" }) {
                p.quote = Quote(handle: rc.authorHandle, name: rc.authorName, text: String(rc.text.prefix(140)))
            }
            stampPost(&p, st)
            p.comments = []
            p.queue = rugQueue(Array(cast.shuffled().prefix(4)), ["rebalanced?? you took \(Mk.fmtGems(loot)) gems.", "lmao 'the work speaks for itself'", jab(), "delete the account at this point", "the audacity is almost impressive"])
            out.append(p)
        }

        // 5. revenge promise
        if let r = (victims.dropFirst().first ?? haters.first ?? victims.first) {
            var p = makePost(r, ["@\(dh) i know your wallet and i know your handle. next coin you launch, i am in the chat every single minute.", "revenge arc starts now. @\(dh) remember my name.", "this isn't over @\(dh). every launch you make from here, i'm telling everyone.", "i lost real gems and a little faith in humanity. @\(dh) only one of those is coming back."].randomElement() ?? "revenge", st)
            p.tag = "Revenge"
            p.poll = nil; p.media = nil; p.quote = nil
            stampPost(&p, st)
            p.comments = []
            p.queue = rugQueue(Array(cast.shuffled().prefix(4)), ["+1. boycotting your next launch.", "count me in.", "we are not forgetting this", "your next coin is dead on arrival @\(dh)", "organize the chat. everyone shows up."])
            out.append(p)
        }

        // 6. the argument
        var argPost: Post? = nil
        if big, let a = (haters.first ?? victims.first), let b = (others.filter({ ($0.trait == .hype || $0.trait == .mogul) && $0.handle != a.handle }).first ?? others.first(where: { $0.handle != a.handle })) {
            var p = makePost(b, "unpopular opinion: everybody who bought $\(t) knew the risk. the trust score said \(score). nobody forced anyone @\(a.handle).", st)
            p.tag = "Heated"
            p.poll = nil; p.media = nil; p.quote = nil
            p.likes *= 3
            p.comments = []
            var q: [QComment] = []
            var at = Date()
            for i in 0..<Int.random(in: 9...14) {
                let cm: Comment
                if Double.random(in: 0...1) < 0.3 {
                    let u = Crowd.make()
                    cm = Comment(name: u.name, handle: u.handle, emoji: "🙂", text: Spicy.crowd[heat].randomElement() ?? Brainrot.line(about: t))
                } else {
                    let sp = i % 2 == 0 ? a : b
                    let tg = i % 2 == 0 ? b : a
                    cm = Comment(name: sp.name, handle: sp.handle, emoji: sp.emoji, text: "@\(tg.handle) " + (Spicy.jab[heat].randomElement() ?? "no"), verified: sp.followers >= 40000)
                }
                at = at.addingTimeInterval(i < 2 ? 1 : Double.random(in: 9...34))
                q.append(QComment(c: cm, at: at))
            }
            p.queue = q
            stampPost(&p, st)
            out.append(p)
            argPost = p
        }

        for p in out { st.posts.insert(p, at: 0) }
        st.posts.insert(brk, at: 0)
        if let r = out.first(where: { $0.tag == "Revenge" }) {
            logEvent(&st, &items, quiet: quiet, emoji: "🗡️", title: "\(r.authorName) swore revenge on \(dn)", detail: String(r.text.prefix(90)), post: r.id,
                     handles: [r.authorHandle, dh], weight: 24)
        }
        if let a = argPost {
            logEvent(&st, &items, quiet: quiet, emoji: "🔥", title: "The $\(t) rug started a fight", detail: String(a.text.prefix(90)), post: a.id,
                     handles: [a.authorHandle, dh], weight: 26)
        }
        return brk.id
    }

    // MARK: You're away

    func marketSnapshot(_ st: GameState) -> [String: Coin] {
        Dictionary((st.ex.market?.coins ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func awayPost(_ st: inout GameState, _ author: NPC, _ text: String, tag: String, replies: [String]) -> Post {
        var p = makePost(author, text, st)
        p.tag = tag
        p.poll = nil; p.media = nil; p.quote = nil
        stampPost(&p, st)
        let cast = st.npcs.filter { $0.id != "newsdesk" && $0.handle != author.handle }.shuffled()
        p.comments = Array(replies.enumerated().map { (i, r) -> Comment in
            if i < cast.count { return mkCm(cast[i], r) }
            let u = Crowd.make()
            return Comment(name: u.name, handle: u.handle, emoji: "🙂", text: r)
        })
        return p
    }

    /// Everything the market did while you were gone, as digest items and feed posts.
    func marketAwayReport(_ st: inout GameState, _ items: inout [DigestItem], before: [String: Coin], away: TimeInterval) {
        let hrs = away / 3600
        guard hrs >= 0.2, let m0 = st.ex.market else { return }
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard !cast.isEmpty else { return }
        let hat = cast.filter { $0.trait == .hater || $0.trait == .gossip }
        let ch = cast.filter { $0.trait == .chaos || $0.trait == .hype }
        var reports = 0

        // your bags
        var bv = 0.0, nv = 0.0
        var names: [String] = []
        for h in m0.holds {
            if let b = before[h.id], let c = m0.coins.first(where: { $0.id == h.id }) {
                bv += h.qty * b.price
                nv += h.qty * c.price
                names.append("$\(h.id)")
            }
        }
        if bv > 1, abs(nv / bv - 1) > 0.12 {
            let up = nv > bv
            logEvent(&st, &items, quiet: false, emoji: up ? "📈" : "📉", title: "Your bags \(up ? "pumped" : "bled") while you were away",
                     detail: "\(names.prefix(3).joined(separator: ", ")) moved \(Mk.pct(nv / bv - 1)). Worth \(Mk.fmtGems(nv)) gems now.", weight: 55)
            reports += 1
        }

        // whales and interest
        for c in m0.coins.shuffled() {
            guard reports < 5, let b = before[c.id], !b.rugged, !c.rugged else { continue }
            let held = m0.holds.contains { $0.id == c.id }
            let dw = (c.whale ?? 0.25) - (b.whale ?? 0.25)
            let cn = Int(Mk.conc(c) * 100)
            if dw > 0.1, let g = hat.randomElement() {
                let p = awayPost(&st, g, "whales have been quietly stacking $\(c.id). top wallets now hold \(cn)% of supply. either they know something or they ARE the something.", tag: "Coin",
                                 replies: ["concentration like that is how rugs are born.", "or it's accumulation. stop fearing everything.", "checking the deployer history now"])
                st.posts.insert(p, at: 0)
                logEvent(&st, &items, quiet: false, emoji: "🐋", title: "Whales are loading $\(c.id)", detail: "Top wallets now hold \(cn)% of supply. Trust score \(c.tr ?? 50).", post: p.id,
                         handles: [g.handle], weight: held ? 48 : 30)
                reports += 1
            } else if dw < -0.1, let g = (ch + hat).randomElement() {
                let p = awayPost(&st, g, "whale wallets just unloaded $\(c.id) onto retail. concentration down to \(cn)%. if you're still holding, you were the exit.", tag: "Coin",
                                 replies: ["bag holders assemble", "the dump was telegraphed 3 hours ago", "i sold 10 minutes before. don't ask"])
                st.posts.insert(p, at: 0)
                logEvent(&st, &items, quiet: false, emoji: "🐳", title: "Whales dumped $\(c.id)", detail: "Big wallets sold into the crowd. The chart is \(Mk.pct(c.price / max(1e-9, b.price) - 1)) since you left.", post: p.id,
                         handles: [g.handle], weight: held ? 50 : 30)
                reports += 1
            } else if (c.interest ?? 0.7) < 0.3, (b.interest ?? 0.7) >= 0.3, let g = cast.randomElement() {
                let p = awayPost(&st, g, "does anyone still talk about $\(c.id) or did we all just quietly leave", tag: "Coin",
                                 replies: ["gm to the 3 holders left", "chat went silent at like 2am", "it's over, but i'm not selling out of spite"])
                st.posts.insert(p, at: 0)
                logEvent(&st, &items, quiet: false, emoji: "😴", title: "The community lost interest in $\(c.id)", detail: "Chat went quiet. Interest is down to \(Int((c.interest ?? 0) * 100))% and trust slipped to \(c.tr ?? 50).", post: p.id,
                         handles: [g.handle], weight: held ? 42 : 24)
                reports += 1
            }
        }

        // deployers who rugged come back with a new project
        var relaunched = 0
        for c in m0.coins where !c.mine && c.rugged && c.crashed != true {
            guard relaunched < 1, let b = before[c.id], !b.rugged, let d = cast.first(where: { $0.handle == c.creator }),
                  (st.ex.market?.coins.count ?? 0) < 16 else { continue }
            var mm = st.ex.market ?? Market()
            var nc = makeCoin(st, by: d, backfill: false)
            nc.tr = Mk.trust(nc, d.trait, mm).score
            mm.coins.append(nc)
            st.ex.market = mm
            let p = awayPost(&st, d, "new project. $\(nc.id). $\(c.id) was a lesson, not a failure. liquidity locked this time 🔒", tag: "Coin",
                             replies: ["@\(d.handle) we see you. trust score on $\(nc.id) is \(nc.tr ?? 30).", "locked liquidity from the guy who pulled \(Mk.fmtGems(c.looted ?? c.poolV)) gems yesterday lol", "i will be in the chat. every minute."])
            st.posts.insert(p, at: 0)
            logEvent(&st, &items, quiet: false, emoji: "🪙", title: "\(d.name) is back with $\(nc.id)", detail: "Fresh launch right after the $\(c.id) rug. Trust score \(nc.tr ?? 30).", post: p.id,
                     handles: [d.handle], weight: 40)
            relaunched += 1
        }

        // other deployers keep launching
        for _ in 0..<min(2, Int(hrs / 3)) { simCoinLaunch(&st, &items, cast, false) }
    }

    func trustInfo(_ c: Coin) -> TrustInfo {
        let trait = s.npcs.first { $0.handle == c.creator }?.trait
        return Mk.trust(c, trait, s.ex.market ?? Market())
    }

    /// NPCs launch coins and shill the ones already out there.
    func simCoinLaunch(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        marketEnsure(&st)
        guard var m = st.ex.market, let n = cast.randomElement() else { return }
        let live = m.coins.filter { !$0.rugged }
        if live.count >= 9 || (!live.isEmpty && Double.random(in: 0...1) < 0.45) {
            guard let c = live.filter({ !$0.mine }).randomElement(), let ch = cast.first(where: { $0.handle == c.creator }) ?? Optional(n) else { return }
            let text = ["$\(c.id) is still early. liquidity looks healthy. dyor but also buy.",
                        "everyone sleeping on $\(c.id). i'm not selling a single token.",
                        "$\(c.id) holders are the new elite. you've been warned."].randomElement() ?? "$\(c.id)"
            var p = makePost(ch, text, st)
            p.tag = "Coin"
            stampPost(&p, st)
            st.posts.insert(p, at: 0)
            if let i = m.coins.firstIndex(where: { $0.id == c.id }) { m.coins[i].drift += 0.03; st.ex.market = m }
            logEvent(&st, &items, quiet: quiet, emoji: "📣", title: "\(ch.name) is shilling $\(c.id)", detail: String(text.prefix(90)),
                     post: p.id, handles: [ch.handle], weight: 14)
            return
        }
        let c = makeCoin(st, by: n, backfill: false)
        m.coins.append(c)
        st.ex.market = m
        let text = ["just launched $\(c.id) (\(c.name)). liquidity locked. early is early.",
                    "$\(c.id) is live. no presale, no team tokens, fully on the community.",
                    "new coin: $\(c.id). i built it in a night. do with that what you will."].randomElement() ?? "$\(c.id)"
        var p = makePost(n, text, st)
        p.tag = "Coin"
        stampPost(&p, st)
        var cs: [Comment] = []
        if let h = cast.filter({ $0.trait == .hater && $0.handle != n.handle }).randomElement() { cs.append(mkCm(h, "rug countdown starts now. see you in the recap.")) }
        if let h = cast.filter({ $0.trait == .hype && $0.handle != n.handle }).randomElement() { cs.append(mkCm(h, "aping in. all of it.")) }
        p.comments = cs
        st.posts.insert(p, at: 0)
        logEvent(&st, &items, quiet: quiet, emoji: "🪙", title: "\(n.name) launched $\(c.id)", detail: String(text.prefix(90)),
                 post: p.id, handles: [n.handle], weight: 22, history: "\(n.name) launched $\(c.id).")
    }

    // MARK: Player actions

    func marketAirdrop() {
        var st = s
        marketEnsure(&st)
        var m = st.ex.market ?? Market()
        let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
        guard m.airdropDay != String(day) else { showToast("Airdrop already claimed today"); return }
        m.airdropDay = String(day)
        st.ex.gems += 10
        st.ex.market = m
        s = st
        showToast("Airdrop: +10 gems")
    }

    func marketBuy(_ ticker: String, gems amt: Int) {
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }) else { return }
        guard !m.coins[i].rugged else { showToast("This coin is rugged"); return }
        guard amt >= 2 else { showToast("Minimum buy is 2 gems"); return }
        guard st.ex.gems >= amt else { showToast("Not enough gems"); return }
        st.ex.gems -= amt
        let fee = Mk.fee(Double(amt))
        let net = Double(amt) - fee
        m.feesPaid = (m.feesPaid ?? 0) + fee
        let qty = net / max(1e-9, m.coins[i].price)
        m.coins[i].price *= 1 + min(0.5, net / max(5, m.coins[i].liq) * 0.8)
        m.coins[i].liq += net * 0.5
        m.coins[i].pool = m.coins[i].poolV + net
        m.coins[i].holders += 1
        if let h = m.holds.firstIndex(where: { $0.id == ticker }) {
            m.holds[h].qty += qty; m.holds[h].cost += Double(amt)
        } else { m.holds.append(Holding(id: ticker, qty: qty, cost: Double(amt))) }
        st.ex.market = m
        bump(&st, "trade")
        s = st
        showToast("Bought. Fee \(Mk.fmtGems(fee)) gems")
    }

    func marketSell(_ ticker: String, frac: Double) {
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }),
              let h = m.holds.firstIndex(where: { $0.id == ticker }) else { return }
        let f = max(0.01, min(1, frac))
        let sellQty = m.holds[h].qty * f
        var gross = sellQty * m.coins[i].price
        if m.coins[i].rugged { gross = min(gross, m.coins[i].liq * f) } else { gross = min(gross, m.coins[i].poolV * 0.85) }
        let fee = min(gross, Mk.fee(gross))
        let net = gross - fee
        m.feesPaid = (m.feesPaid ?? 0) + fee
        if !m.coins[i].rugged { m.coins[i].price *= max(0.5, 1 - gross / max(5, m.coins[i].liq) * 0.8) }
        if !m.coins[i].rugged { m.coins[i].pool = max(1, m.coins[i].poolV - net) }
        let costPart = m.holds[h].cost * f
        let profit = net - costPart
        m.realized += profit
        m.holds[h].qty -= sellQty
        m.holds[h].cost -= costPart
        if m.holds[h].qty < 1e-9 || f >= 0.999 { m.holds.remove(at: h) }
        m.dust += net
        let whole = Int(m.dust)
        m.dust -= Double(whole)
        st.ex.gems += whole
        st.ex.market = m
        if profit > 1 { gainXP(&st, min(60, Int(profit))) }
        bump(&st, "trade")
        s = st
        showToast((profit >= 0 ? "Sold for +\(Mk.fmtGems(profit)) profit" : "Sold at \(Mk.fmtGems(profit)) loss") + ". Fee \(Mk.fmtGems(fee))")
    }

    func marketLaunch(name: String, ticker: String, symbol: String, seed: Int, announce: Bool = true) -> String? {
        var st = s
        marketEnsure(&st)
        var m = st.ex.market ?? Market()
        let t = ticker.uppercased().filter { $0.isLetter || $0.isNumber }
        guard t.count >= 2, t.count <= 6 else { return "Ticker must be 2 to 6 characters" }
        guard !m.coins.contains(where: { $0.id == t }) else { return "That ticker is taken" }
        guard !name.trimmed.isEmpty else { return "Give it a name" }
        guard seed >= 10 else { return "Seed at least 10 gems" }
        guard st.ex.gems >= seed + Mk.launchFee else { return "Need \(seed + Mk.launchFee) gems: \(Mk.launchFee) launch fee plus \(seed) seed" }
        st.ex.gems -= seed + Mk.launchFee
        m.feesPaid = (m.feesPaid ?? 0) + Double(Mk.launchFee)
        var c = Coin(id: t, name: String(name.trimmed.prefix(24)), creator: st.persona.handle, symbol: symbol,
                     hue: Double(HK.h(t) % 360) / 360, price: 0.01, hist: [0.01], born: Date(),
                     liq: Double(seed) + 10, rugP: 0, holders: 1, start: 0.01)
        c.mine = true
        c.vol = 0.12
        c.peak = 0.01
        c.drift = 0.01
        c.pool = Double(seed)
        c.whale = 0.3
        c.interest = 0.8
        c.susp = 0
        c.tr = Mk.trust(c, nil, m).score
        m.coins.append(c)
        m.holds.append(Holding(id: t, qty: Double(seed) * 0.98 / 0.01, cost: Double(seed)))
        m.launched += 1
        st.ex.market = m
        if announce {
            var p = Post(authorHandle: st.persona.handle, authorName: st.persona.name, emoji: st.persona.emoji,
                         text: "just launched $\(t) (\(c.name)). liquidity is in. don't say i didn't tell you.",
                         likes: 12, reposts: 2, comments: makeComments(st, auraDelta: 1, count: 3, text: "launched a coin"),
                         day: st.day, isYou: true)
            p.tag = "Coin"
            stampPost(&p, st)
            st.posts.insert(p, at: 0)
        }
        gainXP(&st, 15)
        s = st
        showToast("$\(t) is live")
        return nil
    }

    func marketShill(_ ticker: String) {
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }), m.coins[i].mine, !m.coins[i].rugged else { return }
        if let l = m.coins[i].lastShill, Date().timeIntervalSince(l) < 600 { showToast("Wait a few minutes between shills"); return }
        m.coins[i].lastShill = Date()
        m.coins[i].drift += Double.random(in: 0.05...0.12) * (1 + Double(st.aura) / 200)
        m.coins[i].holders += Int.random(in: 3...15)
        m.coins[i].interest = min(1, (m.coins[i].interest ?? 0.7) + 0.15)
        st.ex.market = m
        var p = Post(authorHandle: st.persona.handle, authorName: st.persona.name, emoji: st.persona.emoji,
                     text: ["$\(ticker) is only getting started. buy now or watch from the sidelines.", "if you're not in $\(ticker) yet, that's a you problem.", "$\(ticker) holders eat first. that's all i'll say."].randomElement() ?? "$\(ticker)",
                     likes: 20, reposts: 4, comments: makeComments(st, auraDelta: 1, count: 2, text: "$\(ticker)"),
                     day: st.day, isYou: true)
        p.tag = "Coin"
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
        s = st
        showToast("Shilled $\(ticker)")
    }

    func marketRugOwn(_ ticker: String) {
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }), m.coins[i].mine, !m.coins[i].rugged else { return }
        let loot = m.coins[i].poolV
        let held = m.holds.first { $0.id == ticker }
        let holders = m.coins[i].holders
        m.realized += loot - (held?.cost ?? 0)
        m.holds.removeAll { $0.id == ticker }
        m.coins[i].looted = loot
        m.coins[i].price *= 0.015
        m.coins[i].liq = 3
        m.coins[i].rugged = true
        m.coins[i].ruggedAt = Date()
        m.coins[i].hist.append(m.coins[i].price)
        m.rugsPulled += 1
        m.lootEarned = (m.lootEarned ?? 0) + loot
        var lords = m.lords ?? [:]
        lords[st.persona.handle, default: 0] += loot
        m.lords = lords
        m.dust += loot
        let whole = Int(m.dust)
        m.dust -= Double(whole)
        st.ex.gems += whole
        let dead = m.coins[i]
        coinChatBurst(&m, dead, st, loot: loot)
        st.ex.market = m
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        for n in cast.shuffled().prefix(5) {
            if let j = st.npcs.firstIndex(where: { $0.handle == n.handle }) { st.npcs[j].affinity = max(0, st.npcs[j].affinity - 12) }
        }
        st.aura = max(5, st.aura - 8)
        st.followers = max(10, Int(Double(st.followers) * 0.93))
        var tmpItems: [DigestItem] = []
        rugAftermath(&st, &tmpItems, dead, loot: loot, mine: true, held: held, quiet: true)
        if var mm = st.ex.market {
            var d = mm.dev ?? [:]
            var r = d[st.persona.handle] ?? DevRec()
            r.rugs += 1
            r.loot += loot
            r.boycott = Date().addingTimeInterval(3 * 3600)
            d[st.persona.handle] = r
            mm.dev = d
            st.ex.market = mm
        }
        if let v = cast.randomElement() {
            let me = NPC(id: "me", name: st.persona.name, handle: st.persona.handle, emoji: st.persona.emoji, bio: "", trait: .hype, followers: st.followers, affinity: 50, followsYou: false)
            _ = escalateFeud(&st, a: v, b: me, cause: "the $\(ticker) rug")
        }
        notify(&st, "event", "You rugged $\(ticker)", sub: "+\(Mk.fmtGems(loot)) gems from \(holders) holders, the scene will remember", emoji: "💸")
        s = st
        showToast("Rugged. +\(Mk.fmtGems(loot)) gems")
    }

    func buyBooster(_ b: Booster) {
        var st = s
        guard st.ex.gems >= b.price else { showToast("Not enough gems"); return }
        var m = st.ex.market ?? Market()
        var inv = m.inv ?? [:]
        inv[b.rawValue, default: 0] += 1
        m.inv = inv
        st.ex.gems -= b.price
        st.ex.market = m
        s = st
        showToast("\(b.title) added")
    }

    func useBooster(_ b: Booster, on ticker: String) {
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }), m.coins[i].mine, !m.coins[i].rugged else { return }
        var inv = m.inv ?? [:]
        if (inv[b.rawValue] ?? 0) > 0 {
            inv[b.rawValue] = (inv[b.rawValue] ?? 1) - 1
        } else {
            guard st.ex.gems >= b.price else { showToast("Not enough gems"); return }
            st.ex.gems -= b.price
        }
        m.inv = inv
        var fx = m.coins[i].fx ?? [:]
        if b == .pump {
            m.coins[i].price *= Double.random(in: 1.35...1.7)
            m.coins[i].holders += Int.random(in: 20...60)
            m.coins[i].drift += 0.04
        } else {
            let base = max(Date(), fx[b.rawValue] ?? Date())
            fx[b.rawValue] = base.addingTimeInterval(Double(b.hours) * 3600)
            if b == .hype { m.coins[i].holders += Int.random(in: 8...25) }
        }
        m.coins[i].fx = fx
        st.ex.market = m
        s = st
        showToast("\(b.title) active on $\(ticker)")
    }

    func marketToggleWatch(_ t: String) {
        var st = s
        var m = st.ex.market ?? Market()
        var w = m.watch ?? []
        if let i = w.firstIndex(of: t) { w.remove(at: i) } else { w.append(t) }
        m.watch = w
        st.ex.market = m
        s = st
    }
}

// MARK: - Coin chat

enum CoinTalk {
    static let base: [Trait: [String]] = [
        .hype: ["$T to the moon", "load the bag now", "this is only the start", "aping more, no stop loss", "anyone selling this is ngmi", "$T 100x szn"],
        .hater: ["you will 100% lose money", "rug incoming, mark my words", "exit liquidity enjoyer", "this chart is fake", "dev wallet looks sus"],
        .wholesome: ["be careful with your money friends", "small bag, big hopes", "dyor and stay safe", "love this community honestly", "gm everyone"],
        .gossip: ["deployer wallet looks suspicious", "heard the dev is dumping", "insiders loaded early", "someone in my dms says this is a rug", "allegedly the dev has done this before"],
        .mogul: ["liquidity is thin, size accordingly", "i'm market making this one", "not a serious asset", "pool depth is the only metric that matters"],
        .chaos: ["sold my rent for this lol", "bought the top again", "chart go brrr", "my wife left but the chart is green", "i have no idea what this does"]
    ]
    static let up = ["green candle szn", "we are so back", "told you not to sell", "number go up", "who sold i need names", "$T printing", "this is what winning feels like"]
    static let down = ["its over", "bleeding", "who is dumping", "dev do something", "down bad", "should have sold at the top", "pain", "this is fine"]
    static let dead = ["rugged. unreal.", "dev wallet is empty", "i'm done with this scene", "told you it was a rug", "gone. all of it", "never trusting a launch again", "we got got", "revenge arc loading", "i'm telling everyone", "dev your next launch is cooked"]
    static let toDev = ["dev where is the roadmap", "dev say something", "dev are you holding", "lock the liquidity dev", "dev we believe in you", "dev dont rug us"]
    static let rage: [[String]] = [
        ["so much for that", "wow thanks dev", "lesson learned"],
        ["what the hell dev", "this is crap i trusted you", "damn the dev really did it"],
        ["fuck this i got rugged", "dev is a piece of shit", "we got fucked lol", "bullshit i want my gems back"],
        ["fucking scammer dev i hope your wallet gets drained", "this dev is a gutless fuck and everyone here knows it", "rugged by a raccoon in a hoodie, fuck this coin and fuck you", "dev you absolute sack of shit give us our gems back"]
    ]
    static let quick = ["🚀 moon", "rug?", "gm", "buying more", "dev doxx", "sold lol"]
}

extension Game {
    func coinSpeaker(_ c: Coin, _ st: GameState) -> (npc: NPC, dev: Bool) {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        if !c.mine, !c.rugged, let dv = cast.first(where: { $0.handle == c.creator }), Double.random(in: 0...1) < 0.08 { return (dv, true) }
        if cast.isEmpty || Double.random(in: 0...1) < 0.5 { return (Crowd.npc(for: Crowd.make().handle), false) }
        let n = cast.randomElement() ?? Crowd.npc(for: Crowd.make().handle)
        return (n, n.handle == c.creator)
    }

    func coinLine(_ c: Coin, _ who: NPC, dev: Bool, _ st: GameState, replyTo: String? = nil) -> String {
        let heat = Spicy.heat
        let n = c.hist.count
        let ch = n > 8 ? c.price / max(1e-9, c.hist[n - 8]) - 1 : 0
        let crowd = Crowd.looksLikeCrowd(who.handle)
        var t: String
        if dev {
            let bank = c.rugged ? ["i have nothing to say", "..."] : (ch < -0.08 ? ["relax. liquidity is locked", "dips are for buying", "not selling. ever"] : ["building. ignore the noise", "roadmap drops soon", "told you it was early", "wen listing? soon"])
            t = bank.randomElement() ?? "gm"
        } else if c.rugged {
            let bank = CoinTalk.dead + CoinTalk.rage[min(3, heat)]
            t = crowd && Double.random(in: 0...1) < 0.5 ? Brainrot.line(about: c.name) : (bank.randomElement() ?? "rugged")
        } else if c.mine, Double.random(in: 0...1) < 0.25 {
            t = "@\(st.persona.handle) " + (CoinTalk.toDev.randomElement() ?? "dev say something")
        } else if crowd, Double.random(in: 0...1) < 0.5 {
            t = Brainrot.line(about: c.name + " " + c.id)
        } else if ch > 0.08, Double.random(in: 0...1) < 0.5 {
            t = CoinTalk.up.randomElement() ?? "green"
        } else if ch < -0.08, Double.random(in: 0...1) < 0.5 {
            t = CoinTalk.down.randomElement() ?? "red"
        } else if !c.mine, (c.tr ?? 70) < 45, who.trait == .gossip || who.trait == .hater, Double.random(in: 0...1) < 0.5 {
            t = ["trust score on $T is \(c.tr ?? 40). you were warned", "check the deployer history before you ape", "whales hold \(Int(Mk.conc(c) * 100))% of $T. that's not a community, that's a hostage situation", "dev wallet is moving again"].randomElement() ?? "sus"
        } else if who.trait == .hater, heat >= 1, Double.random(in: 0...1) < 0.4 {
            t = Spicy.jab[heat].randomElement() ?? "cope"
        } else {
            t = (CoinTalk.base[who.trait] ?? ["gm"]).randomElement() ?? "gm"
        }
        t = t.replacingOccurrences(of: "$T", with: "$\(c.id)")
        if let r = replyTo, Double.random(in: 0...1) < 0.6, !t.hasPrefix("@") { t = "@\(r) " + t }
        return t
    }

    private func putChat(_ m: inout Market, _ ticker: String, _ log: [CoinMsg]) {
        var l = log
        if l.count > 40 { l.removeFirst(l.count - 40) }
        var chats = m.chats ?? [:]
        chats[ticker] = l
        m.chats = chats
    }

    func coinChatTick(_ ticker: String) {
        var st = s
        guard var m = st.ex.market, let c = m.coins.first(where: { $0.id == ticker }) else { return }
        var log = m.chats?[ticker] ?? []
        let now = Date()
        var replyTo: String? = nil
        var p = c.rugged ? 0.3 : 0.55
        if let li = log.lastIndex(where: { $0.me }), now.timeIntervalSince(log[li].at) < 45, log.count - li - 1 < 3 {
            replyTo = st.persona.handle
            p = 0.9
        }
        guard Double.random(in: 0...1) < p else { return }
        let sp = coinSpeaker(c, st)
        let text = coinLine(c, sp.npc, dev: sp.dev, st, replyTo: replyTo)
        log.append(CoinMsg(handle: sp.npc.handle, name: sp.npc.name, emoji: sp.npc.emoji, text: text, at: now, dev: sp.dev))
        putChat(&m, ticker, log)
        st.ex.market = m
        s = st
    }

    func coinChatSeed(_ ticker: String) {
        var st = s
        guard var m = st.ex.market, let c = m.coins.first(where: { $0.id == ticker }) else { return }
        var log = m.chats?[ticker] ?? []
        guard log.count < 6 else { return }
        let now = Date()
        var older: [CoinMsg] = []
        for k in 0..<(8 - log.count) {
            let sp = coinSpeaker(c, st)
            older.append(CoinMsg(handle: sp.npc.handle, name: sp.npc.name, emoji: sp.npc.emoji, text: coinLine(c, sp.npc, dev: sp.dev, st),
                                 at: now.addingTimeInterval(-Double(k + 1) * Double.random(in: 14...40)), dev: sp.dev))
        }
        log = (older + log).sorted { $0.at < $1.at }
        putChat(&m, ticker, log)
        st.ex.market = m
        s = st
    }

    func coinSay(_ ticker: String, _ text: String) {
        let t = String(text.trimmed.prefix(140))
        guard !t.isEmpty else { return }
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }) else { return }
        var log = m.chats?[ticker] ?? []
        log.append(CoinMsg(handle: st.persona.handle, name: st.persona.name, emoji: st.persona.emoji, text: t, at: Date(), me: true, dev: m.coins[i].mine))
        let low = t.lowercased()
        if !m.coins[i].rugged {
            if ["moon", "buy", "pump", "bull", "hold", "gem", "lfg"].contains(where: { low.contains($0) }) { m.coins[i].drift = min(0.2, m.coins[i].drift + 0.004) }
            if ["rug", "sell", "dump", "scam", "exit", "dead"].contains(where: { low.contains($0) }) { m.coins[i].drift = max(-0.2, m.coins[i].drift - 0.006) }
        }
        putChat(&m, ticker, log)
        st.ex.market = m
        s = st
    }

    func coinChatBurst(_ m: inout Market, _ c: Coin, _ st: GameState, loot: Double) {
        var log = m.chats?[c.id] ?? []
        let now = Date()
        log.append(CoinMsg(handle: "system", name: "System", emoji: "🚨", text: c.crashed == true ? "$\(c.id) collapsed and was delisted." : "$\(c.id) rugged. The deployer pocketed \(Mk.fmtGems(loot)) gems.", at: now.addingTimeInterval(-8), sys: true))
        for k in 0..<6 {
            let sp = coinSpeaker(c, st)
            log.append(CoinMsg(handle: sp.npc.handle, name: sp.npc.name, emoji: sp.npc.emoji, text: coinLine(c, sp.npc, dev: false, st),
                               at: now.addingTimeInterval(-6 + Double(k))))
        }
        putChat(&m, c.id, log)
    }
}
