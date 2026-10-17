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
}

enum Mk {
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
        let s = c.rugP * 1000 + Double(HK.h(c.id) % 20) / 10
        if c.mine { return "Yours" }
        return s < 1.5 ? "Low" : (s < 3.5 ? "Medium" : (s < 5.5 ? "High" : "Degen"))
    }

    static func tickers(_ text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: "\\$([A-Z0-9]{2,6})") else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }
}

enum CoinEvent { case rug, pump(Double) }

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
        case .chaos, .hater: rugP = 0.006
        case .mogul: rugP = 0.004
        case .hype: rugP = 0.003
        case .gossip: rugP = 0.002
        default: rugP = 0.0008
        }
        rugP *= Double.random(in: 0.6...1.4)
        let start = Double.random(in: 0.0008...0.04)
        var c = Coin(id: t, name: a + " " + b, creator: npc.handle, symbol: Mk.symbols.randomElement() ?? "star.fill",
                     hue: Double.random(in: 0...1), price: start, hist: [start], born: Date(),
                     liq: Double.random(in: 25...320), rugP: rugP, holders: Int.random(in: 6...80), start: start)
        c.vol = Double.random(in: 0.03...0.09)
        c.peak = start
        if backfill {
            for _ in 0..<45 { _ = stepCoin(&c, quiet: true) }
            c.born = Date().addingTimeInterval(-Double.random(in: 1800...40000))
            c.rugged = false
        }
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
        c.drift = c.drift * 0.97 - 0.0004
        if Double.random(in: 0...1) < 0.012 { c.drift += Double.random(in: 0.03...0.11) }
        if Double.random(in: 0...1) < 0.006 { c.drift -= Double.random(in: 0.04...0.10) }
        let r = max(-0.35, min(0.35, c.drift + c.vol * Mk.gauss()))
        c.price = max(1e-7, c.price * exp(r))
        c.peak = max(c.peak, c.price)
        c.liq = max(5, c.liq * (1 + r * 0.3))
        c.holders = max(1, c.holders + Int(r * 400) + Int.random(in: -2...3))
        c.hist.append(c.price)
        if c.hist.count > 60 { c.hist.removeFirst() }
        if quiet { return nil }
        let age = Date().timeIntervalSince(c.born) / 3600
        if !c.mine, Double.random(in: 0...1) < c.rugP * (1 + min(age, 12) / 6) {
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
        for _ in 0..<steps {
            for i in m.coins.indices {
                if let e = stepCoin(&m.coins[i]) { events.append((m.coins[i], e)) }
            }
        }
        // prune old dead coins and orphan holdings
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let heldIDs = Set(m.holds.map { $0.id })
        m.coins.removeAll { c in c.rugged && (c.ruggedAt ?? .distantPast) < cutoff && !heldIDs.contains(c.id) }
        if m.coins.count > 16 { m.coins.removeAll { c in c.rugged && !c.mine && !heldIDs.contains(c.id) } }
        let liveIDs = Set(m.coins.map { $0.id })
        m.holds.removeAll { h in !liveIDs.contains(h.id) }
        st.ex.market = m
        for (c, e) in events.prefix(3) { coinHeadline(&st, &items, c, e, quiet: quiet) }
    }

    func marketAmbient() {
        guard playing, s.intro?.done != false else { return }
        var st = s
        var items: [DigestItem] = []
        marketAdvance(&st, &items, steps: 5, quiet: true)
        checkSeason(&st, &items, quiet: true)
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
        case .rug:
            guard let author = news ?? cast.first else { return }
            let cn = creator?.name ?? "the deployer"
            var text = "BREAKING: $\(c.id) rugged. \(cn) pulled the liquidity and the price is down 98%. Holders are cooked."
            if let ch = creator { text += " @\(ch.handle) has not responded." }
            var p = makePost(author, text, st)
            p.tag = "Breaking"
            stampPost(&p, st)
            var cs: [Comment] = []
            if let h = cast.filter({ $0.trait == .hater }).randomElement() { cs.append(mkCm(h, "told you. every single time. \(cn) did it again.")) }
            if let h = cast.filter({ $0.trait == .wholesome }).randomElement() { cs.append(mkCm(h, "so sorry to everyone who lost money on $\(c.id). please be careful out there.")) }
            if let h = cast.filter({ $0.trait == .gossip }).randomElement() { cs.append(mkCm(h, "allegedly \(cn) sold before the announcement. receipts incoming.")) }
            if let h = cast.filter({ $0.trait == .chaos }).randomElement() { cs.append(mkCm(h, "i was in. i am now a different person.")) }
            p.comments = cs
            p.likes = max(p.likes * 4, 160)
            p.viral = true
            st.posts.insert(p, at: 0)
            var detail = "\(cn) pulled the liquidity. Down 98%."
            var w = 60
            if let h = held {
                detail += " You lost \(Mk.fmtGems(h.cost)) gems."
                w = 90
                notify(&st, "event", "You got rugged on $\(c.id)", sub: "-\(Mk.fmtGems(h.cost)) gems", handle: c.creator, emoji: "📉")
                var m = st.ex.market ?? Market()
                m.rugsTaken += 1
                m.realized -= h.cost
                st.ex.market = m
                if h.cost >= 10 { st.aura = max(5, st.aura - 2) }
            }
            if let ch = creator, let v = cast.filter({ $0.handle != ch.handle }).randomElement() {
                _ = escalateFeud(&st, a: ch, b: v, cause: "the $\(c.id) rug")
            }
            logEvent(&st, &items, quiet: quiet, emoji: "💸", title: "$\(c.id) was rugged", detail: detail, post: p.id,
                     handles: creator.map { [$0.handle] } ?? [], weight: w,
                     history: "$\(c.id) rugged. \(cn) took the liquidity and vanished.")
        }
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
        guard amt > 0, st.ex.gems >= amt else { showToast("Not enough gems"); return }
        st.ex.gems -= amt
        let net = Double(amt) * 0.98
        let qty = net / max(1e-9, m.coins[i].price)
        m.coins[i].price *= 1 + min(0.5, net / max(5, m.coins[i].liq) * 0.8)
        m.coins[i].liq += net * 0.5
        m.coins[i].holders += 1
        if let h = m.holds.firstIndex(where: { $0.id == ticker }) {
            m.holds[h].qty += qty; m.holds[h].cost += Double(amt)
        } else { m.holds.append(Holding(id: ticker, qty: qty, cost: Double(amt))) }
        st.ex.market = m
        s = st
    }

    func marketSell(_ ticker: String, frac: Double) {
        var st = s
        guard var m = st.ex.market, let i = m.coins.firstIndex(where: { $0.id == ticker }),
              let h = m.holds.firstIndex(where: { $0.id == ticker }) else { return }
        let f = max(0.01, min(1, frac))
        let sellQty = m.holds[h].qty * f
        var gross = sellQty * m.coins[i].price
        if m.coins[i].rugged { gross = min(gross, m.coins[i].liq * f) }
        let net = gross * 0.98
        if !m.coins[i].rugged { m.coins[i].price *= max(0.5, 1 - gross / max(5, m.coins[i].liq) * 0.8) }
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
        s = st
        showToast(profit >= 0 ? "Sold for +\(Mk.fmtGems(profit)) profit" : "Sold at \(Mk.fmtGems(profit)) loss")
    }

    func marketLaunch(name: String, ticker: String, symbol: String, seed: Int) -> String? {
        var st = s
        marketEnsure(&st)
        var m = st.ex.market ?? Market()
        let t = ticker.uppercased().filter { $0.isLetter || $0.isNumber }
        guard t.count >= 2, t.count <= 6 else { return "Ticker must be 2 to 6 characters" }
        guard !m.coins.contains(where: { $0.id == t }) else { return "That ticker is taken" }
        guard !name.trimmed.isEmpty else { return "Give it a name" }
        guard st.ex.gems >= seed else { return "Not enough gems" }
        st.ex.gems -= seed
        var c = Coin(id: t, name: String(name.trimmed.prefix(24)), creator: st.persona.handle, symbol: symbol,
                     hue: Double(HK.h(t) % 360) / 360, price: 0.01, hist: [0.01], born: Date(),
                     liq: Double(seed) + 10, rugP: 0, holders: 1, start: 0.01)
        c.mine = true
        c.vol = 0.06
        c.peak = 0.01
        c.drift = 0.02
        m.coins.append(c)
        m.holds.append(Holding(id: t, qty: Double(seed) * 0.98 / 0.01, cost: Double(seed)))
        m.launched += 1
        st.ex.market = m
        var p = Post(authorHandle: st.persona.handle, authorName: st.persona.name, emoji: st.persona.emoji,
                     text: "just launched $\(t) (\(c.name)). liquidity is in. don't say i didn't tell you.",
                     likes: 12, reposts: 2, comments: makeComments(st, auraDelta: 1, count: 3, text: "launched a coin"),
                     day: st.day, isYou: true)
        p.tag = "Coin"
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
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
        let c = m.coins[i]
        var proceeds = 0.0
        if let h = m.holds.firstIndex(where: { $0.id == ticker }) {
            proceeds = min(c.liq * 0.85, m.holds[h].qty * c.price)
            m.realized += proceeds - m.holds[h].cost
            m.holds.remove(at: h)
        }
        m.coins[i].price *= 0.015
        m.coins[i].liq = 3
        m.coins[i].rugged = true
        m.coins[i].ruggedAt = Date()
        m.coins[i].hist.append(m.coins[i].price)
        m.rugsPulled += 1
        m.dust += proceeds
        let whole = Int(m.dust)
        m.dust -= Double(whole)
        st.ex.gems += whole
        st.ex.market = m
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        for n in cast.shuffled().prefix(5) {
            if let j = st.npcs.firstIndex(where: { $0.handle == n.handle }) { st.npcs[j].affinity = max(0, st.npcs[j].affinity - 12) }
        }
        st.aura = max(5, st.aura - 8)
        st.followers = max(10, Int(Double(st.followers) * 0.93))
        let news = st.npcs.first { $0.id == "newsdesk" } ?? cast.first
        if let author = news {
            var p = makePost(author, "BREAKING: $\(ticker) rugged. @\(st.persona.handle) pulled the liquidity and the price is down 98%. Holders want answers.", st)
            p.tag = "Breaking"
            stampPost(&p, st)
            var cs: [Comment] = []
            for n in cast.shuffled().prefix(3) {
                cs.append(mkCm(n, ["@\(st.persona.handle) you really did it huh.", "bag holders unite. @\(st.persona.handle) owes us all.", "never trusting a launch again. thanks a lot @\(st.persona.handle)."].randomElement() ?? "wow"))
            }
            p.comments = cs
            p.likes = max(p.likes * 4, 200)
            p.viral = true
            st.posts.insert(p, at: 0)
            if let v = cast.randomElement() {
                let me = NPC(id: "me", name: st.persona.name, handle: st.persona.handle, emoji: st.persona.emoji, bio: "", trait: .hype, followers: st.followers, affinity: 50, followsYou: false)
                _ = escalateFeud(&st, a: v, b: me, cause: "the $\(ticker) rug")
            }
        }
        notify(&st, "event", "You rugged $\(ticker)", sub: "+\(Mk.fmtGems(proceeds)) gems, the scene will remember", emoji: "💸")
        s = st
        showToast("Rugged. +\(Mk.fmtGems(proceeds)) gems")
    }
}
