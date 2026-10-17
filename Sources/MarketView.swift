import SwiftUI

struct TickerID: Identifiable { let id: String }

struct Spark: View {
    let values: [Double]
    var color: Color = T.lime
    var fill = false
    var dot = false
    var body: some View {
        GeometryReader { g in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(1e-12, hi - lo)
            let n = max(1, values.count - 1)
            let pt: (Int) -> CGPoint = { i in
                CGPoint(x: g.size.width * CGFloat(i) / CGFloat(n),
                        y: g.size.height * (1 - CGFloat((values[i] - lo) / span)) * 0.9 + g.size.height * 0.05)
            }
            ZStack {
                if values.count > 1 {
                    if fill {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: g.size.height))
                            for i in values.indices { p.addLine(to: pt(i)) }
                            p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                            p.closeSubpath()
                        }.fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    }
                    Path { p in
                        p.move(to: pt(0))
                        for i in values.indices.dropFirst() { p.addLine(to: pt(i)) }
                    }.stroke(color, style: StrokeStyle(lineWidth: dot ? 3.2 : (fill ? 2.4 : 1.8), lineCap: .round, lineJoin: .round))
                    if dot {
                        Circle().fill(color).frame(width: 10, height: 10)
                            .position(pt(values.count - 1))
                    }
                }
            }
        }
    }
}

struct CoinTile: View {
    let c: Coin
    var size: CGFloat = 46
    var body: some View {
        let col = Color(hue: c.hue, saturation: 0.7, brightness: 0.95)
        ZStack {
            Circle().fill(LinearGradient(colors: [col.opacity(0.9), col.opacity(0.45)], startPoint: .top, endPoint: .bottom))
            Image(systemName: c.symbol).font(.system(size: size * 0.44, weight: .bold)).foregroundColor(.white)
            if c.rugged {
                Circle().fill(Color.black.opacity(0.55))
                Image(systemName: "xmark").font(.system(size: size * 0.4, weight: .heavy)).foregroundColor(T.red)
            }
        }
        .frame(width: size, height: size)
    }
}

extension Mk {
    static func age(_ c: Coin) -> String {
        let s = Int(Date().timeIntervalSince(c.born))
        if s < 3600 { return "\(max(1, s / 60))m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }
    static func labelColor(_ score: Int) -> Color {
        switch label(score) {
        case "Low": return Color(red: 0.4, green: 0.95, blue: 0.5)
        case "Medium": return T.gold
        case "High": return T.orange
        default: return T.red
        }
    }
    static func riskColor(_ c: Coin) -> Color {
        switch risk(c) {
        case "Low": return Color(red: 0.4, green: 0.95, blue: 0.5)
        case "Medium": return T.gold
        case "High": return T.orange
        case "Yours": return Color(red: 0.67, green: 0.62, blue: 0.95)
        default: return T.red
        }
    }
    static func ago(_ d: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(d)))
        if s < 5 { return "now" }
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}

struct MarketView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var seg = 0
    @State private var sort = 0
    @State private var query = ""
    @State private var detail: TickerID? = nil
    @State private var launch = false
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)
    private let green = Color(red: 0.4, green: 0.95, blue: 0.5)
    private let segs = ["Market", "Holdings", "Yours", "Watch"]
    private let sorts = ["Hot", "Cap", "New", "Risky"]

    var body: some View {
        let st = game.s
        let m = st.ex.market ?? Market()
        let prices = Dictionary(m.coins.map { ($0.id, $0.price) }, uniquingKeysWith: { a, _ in a })
        let value = m.holds.reduce(0.0) { acc, h in acc + h.qty * (prices[h.id] ?? 0) }
        let cost = m.holds.reduce(0.0) { $0 + $1.cost }
        let pnl = m.realized + (value - cost)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill").font(.system(size: 24, weight: .semibold)).foregroundColor(lav)
                    .rotationEffect(.degrees(-20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Market").font(.jk(26, .heavy))
                    Text("\(m.coins.filter { !$0.rugged }.count) coins live").font(.jk(12)).foregroundColor(T.sub)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "diamond.fill").font(.system(size: 12)).foregroundColor(T.gold)
                    Text("\(st.ex.gems)").font(.jk(15, .bold)).lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 14).frame(height: 40).fixedSize().background(T.card2).clipShape(Capsule())
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                portfolio(m, st, value: value, pnl: pnl)
                trending(m)
                segBar
                if seg == 0 { sortBar }
                search
                list(m)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 30)
        }
        }
        .background(T.bg)
        .onReceive(timer) { _ in game.marketTick() }
        .onAppear { game.marketEnsureNow(); openPending() }
        .onChange(of: nav.coin) { _ in openPending() }
        .fullScreenCover(item: $detail) { CoinDetail(ticker: $0.id).zoomed() }
        .sheet(isPresented: $launch) { LaunchSheet().zoomed() }
    }

    private func pill(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(.jk(14, .bold))
            }
            .foregroundColor(.black).padding(.horizontal, 14).frame(height: 38).background(lav).clipShape(Capsule())
        }
    }

    private func openPending() {
        if let t = nav.coin { detail = TickerID(id: t); nav.coin = nil }
    }

    private func portfolio(_ m: Market, _ st: GameState, value: Double, pnl: Double) -> some View {
        let total = value + Double(st.ex.gems)
        let held: [(Coin, Double)] = m.holds.compactMap { h -> (Coin, Double)? in
            guard let c = m.coins.first(where: { $0.id == h.id }) else { return nil }
            return (c, h.qty * c.price)
        }.filter { $0.1 > 0.01 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PORTFOLIO").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    Text("\(Mk.fmtGems(total)) gems").font(.jk(30, .heavy))
                    Text("\(pnl >= 0 ? "+" : "")\(Mk.fmtGems(pnl)) all-time").font(.jk(13, .semibold))
                        .foregroundColor(pnl >= 0 ? green : T.red)
                }
                Spacer()
                VStack(spacing: 8) {
                    pill("gift.fill", "Airdrop") { game.marketAirdrop() }
                    pill("plus", "Launch") { launch = true }
                }
            }
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(Array(held.enumerated()), id: \.offset) { _, e in
                        Capsule().fill(Color(hue: e.0.hue, saturation: 0.7, brightness: 0.95))
                            .frame(width: max(4, g.size.width * CGFloat(e.1 / max(1, total))))
                    }
                    Capsule().fill(Color.white.opacity(0.14))
                }
            }
            .frame(height: 8)
            HStack(spacing: 10) {
                statCell("Fees paid", "-\(Mk.fmtGems(m.feesPaid ?? 0))", T.red)
                statCell("Positions", "\(held.count)", .white)
                statCell("Launched", "\(m.launched)", lav)
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [lav.opacity(0.28), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func statCell(_ k: String, _ v: String, _ col: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k.uppercased()).font(.jk(9, .heavy)).foregroundColor(T.sub)
            Text(v).font(.jk(15, .bold)).foregroundColor(col).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(Color.black.opacity(0.28)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func trending(_ m: Market) -> some View {
        let hot = m.coins.filter { !$0.rugged }.sorted { Mk.change($0) > Mk.change($1) }.prefix(6)
        if !hot.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Trending").font(.jk(20, .bold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(hot), id: \.id) { c in
                            let ch = Mk.change(c)
                            let col: Color = ch >= 0 ? green : T.red
                            Button { detail = TickerID(id: c.id) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        CoinTile(c: c, size: 30)
                                        Text(c.id).font(.jk(16, .bold)).foregroundColor(.white)
                                    }
                                    Spark(values: Array(c.hist.suffix(30)), color: col, fill: true).frame(height: 34)
                                    Text(Mk.pct(ch)).font(.jk(15, .bold)).foregroundColor(col)
                                }
                                .padding(12).frame(width: 140, alignment: .leading)
                                .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var segBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(segs.enumerated()), id: \.offset) { i, t in
                    Button { seg = i } label: {
                        Text(t).font(.jk(15, .semibold)).foregroundColor(seg == i ? .black : .white)
                            .padding(.horizontal, 16).frame(height: 36)
                            .background(seg == i ? Color.white : Color.white.opacity(0.08)).clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var sortBar: some View {
        HStack(spacing: 8) {
            Text("Sort").font(.jk(12, .semibold)).foregroundColor(T.sub)
            ForEach(Array(sorts.enumerated()), id: \.offset) { i, t in
                Button { sort = i } label: {
                    Text(t).font(.jk(13, .bold)).foregroundColor(sort == i ? .black : T.sub)
                        .padding(.horizontal, 12).frame(height: 28)
                        .background(sort == i ? lav : Color.white.opacity(0.07)).clipShape(Capsule())
                }
            }
            Spacer()
        }
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(T.sub)
            TextField("Search ticker or name", text: $query).font(.jk(15)).autocorrectionDisabled().textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(T.sub) }
            }
        }
        .padding(.horizontal, 14).frame(height: 44).background(Color.white.opacity(0.07)).clipShape(Capsule())
    }

    @ViewBuilder
    private func list(_ m: Market) -> some View {
        let q = query.lowercased().trimmed
        let coins: [Coin] = {
            var base: [Coin]
            switch seg {
            case 1: base = m.coins.filter { c in m.holds.contains(where: { $0.id == c.id }) }
            case 2: base = m.coins.filter { $0.mine }
            case 3: base = m.coins.filter { (m.watch ?? []).contains($0.id) && !$0.rugged }
            default:
                switch sort {
                case 1: base = m.coins.sorted { Mk.mc($0) > Mk.mc($1) }
                case 2: base = m.coins.sorted { $0.born > $1.born }
                case 3: base = m.coins.sorted { $0.rugP > $1.rugP }
                default: base = m.coins.sorted { Mk.change($0) > Mk.change($1) }
                }
                base = base.filter { !$0.rugged }
            }
            if !q.isEmpty { base = base.filter { $0.id.lowercased().contains(q) || $0.name.lowercased().contains(q) } }
            return base
        }()
        if coins.isEmpty {
            let titles = ["Nothing listed", "No positions", "No coins launched", "Nothing watched"]
            let details = ["Try another search.", "Buy into a coin from the Market tab.", "Launching costs 50 gems plus a seed. The market is volatile.", "Tap the heart on a coin to watch it."]
            EmptyState(emoji: "💸", title: titles[seg], detail: details[seg])
        } else {
            VStack(spacing: 8) {
                ForEach(Array(coins.enumerated()), id: \.element.id) { i, c in
                    Button { detail = TickerID(id: c.id) } label: { row(c, m, rank: seg == 0 && sort < 2 && !c.rugged ? i + 1 : nil) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ c: Coin, _ m: Market, rank: Int?) -> some View {
        let ch = Mk.change(c)
        let col: Color = c.rugged ? T.red : (ch >= 0 ? green : T.red)
        let chat = m.chats?[c.id]?.filter { Date().timeIntervalSince($0.at) < 300 }.count ?? 0
        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CoinTile(c: c, size: 50)
                if let r = rank, r <= 3 {
                    ZStack {
                        Image(systemName: "seal.fill").font(.system(size: 22))
                            .foregroundColor([T.gold, Color(white: 0.8), T.orange][r - 1])
                        Text("\(r)").font(.jk(10, .heavy)).foregroundColor(.black)
                    }.offset(x: 6, y: 6)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.id).font(.jk(19, .bold)).foregroundColor(.white).lineLimit(1)
                    if c.rugged { tag("DELISTED", T.red, .white) }
                    else if c.mine { tag("YOURS", lav, .black) }
                    else { tag(Mk.risk(c).uppercased(), Mk.riskColor(c).opacity(0.22), Mk.riskColor(c)) }
                    if (m.watch ?? []).contains(c.id) { Image(systemName: "heart.fill").font(.system(size: 10)).foregroundColor(T.red) }
                }
                if c.rugged {
                    Text("Delisted. Nothing left to sell.").font(.jk(13, .semibold)).foregroundColor(T.red).lineLimit(1)
                } else {
                    Text("\(Mk.fmtMC(Mk.mc(c))) MC · \(c.holders) holders").font(.jk(13)).foregroundColor(T.sub).lineLimit(1)
                }
                HStack(spacing: 8) {
                    Text(Mk.age(c)).font(.jk(11, .semibold)).foregroundColor(T.sub)
                    if chat > 0 {
                        Label("\(chat)", systemImage: "bubble.left.fill").font(.jk(11, .semibold)).foregroundColor(lav)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Spark(values: Array(c.hist.suffix(30)), color: col).frame(width: 62, height: 24)
                Text(Mk.usdPrice(c.price)).font(.jk(15, .semibold)).foregroundColor(.white)
                Text(Mk.pct(ch)).font(.jk(13, .semibold)).foregroundColor(col)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tag(_ t: String, _ bg: Color, _ fg: Color) -> some View {
        Text(t).font(.jk(9, .heavy)).foregroundColor(fg).padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct CoinDetail: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let ticker: String
    @State private var range = 0
    @State private var trade = false
    @State private var chat = false
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)
    private let green = Color(red: 0.4, green: 0.95, blue: 0.5)
    private let ranges = ["LIVE", "1D", "1W", "1M", "1Y", "ALL"]

    var body: some View {
        let st = game.s
        let m = st.ex.market ?? Market()
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            if let c = m.coins.first(where: { $0.id == ticker }) {
                ScrollView { content(c, m, st).padding(.bottom, 110) }
                bar(c)
            } else {
                VStack {
                    EmptyState(emoji: "💸", title: "Coin delisted", detail: "It rugged and vanished from the market.").padding(.top, 80)
                    BigButton(title: "Back", action: { dismiss() }).padding(.horizontal, 60)
                }
            }
        }
        .sheet(isPresented: $trade) { TradeSheet(ticker: ticker).zoomed() }
        .sheet(isPresented: $chat) { CoinChatSheet(ticker: ticker).zoomed() }
    }

    private func slice(_ c: Coin) -> [Double] {
        let n = [20, 30, 45, 60, 60, 60][range]
        return Array(c.hist.suffix(n))
    }

    private func stat(_ k: String, _ v: String, _ col: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k.uppercased()).font(.jk(10, .heavy)).foregroundColor(T.sub)
            Text(v).font(.jk(16, .bold)).foregroundColor(col).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func content(_ c: Coin, _ m: Market, _ st: GameState) -> some View {
        let ch = Mk.change(c)
        let col: Color = c.rugged ? T.red : (ch >= 0 ? green : T.red)
        let delta = ((c.hist.first.map { c.price - $0 }) ?? 0) * Mk.supply
        let held = m.holds.first { $0.id == c.id }
        let watching = (m.watch ?? []).contains(c.id)
        let npc = st.npcs.first { $0.handle == c.creator }
        let isMe = c.creator == st.persona.handle
        let ti = game.trustInfo(c)
        let prior = ti.rugs
        let cname = isMe ? "You" : (npc?.name ?? c.creator)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white).frame(width: 44, height: 44)
                }
                Spacer()
                Button { game.marketToggleWatch(c.id) } label: {
                    Image(systemName: watching ? "heart.fill" : "heart").font(.system(size: 20)).foregroundColor(watching ? T.red : .white)
                        .frame(width: 54, height: 54).background(Color.white.opacity(0.08)).clipShape(Circle())
                }
                Button { chat = true } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 18)).foregroundColor(.white)
                        .frame(width: 54, height: 54).background(Color.white.opacity(0.08)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    CoinTile(c: c, size: 44)
                    Text(c.id).font(.jk(40, .heavy))
                    Text(c.name.uppercased()).font(.jk(14, .semibold)).foregroundColor(T.sub).lineLimit(1)
                }
                Text(Mk.fmtMC(Mk.mc(c))).font(.jk(44, .heavy))
                Text("\(delta >= 0 ? "+" : "-")\(Mk.fmtMC(abs(delta))) (\(Mk.pct(ch)))")
                    .font(.jk(22, .semibold)).foregroundColor(col)
            }
            .padding(.horizontal, 16)
            if c.rugged {
                VStack(alignment: .leading, spacing: 6) {
                    Label(c.crashed == true ? "Delisted. The market collapsed it." : "Rugged. The liquidity is gone.", systemImage: "exclamationmark.triangle.fill")
                        .font(.jk(15, .bold)).foregroundColor(T.red)
                    if c.crashed != true {
                        Text("\(cname) pulled the pool and pocketed \(Mk.fmtGems(c.looted ?? c.poolV)) gems from every holder.")
                            .font(.jk(14)).foregroundColor(.white.opacity(0.85))
                    }
                    if let h = held { Text("Your position lost \(Mk.fmtGems(h.cost)) gems.").font(.jk(13, .semibold)).foregroundColor(T.red) }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.red.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
            Spark(values: slice(c), color: col, fill: true, dot: true).frame(height: 260).padding(.vertical, 10)
            HStack(spacing: 4) {
                ForEach(Array(ranges.enumerated()), id: \.offset) { i, r in
                    Button { range = i } label: {
                        HStack(spacing: 4) {
                            if i == 0 { Circle().fill(range == 0 ? green : T.sub).frame(width: 6, height: 6) }
                            Text(r).font(.jk(16, .semibold))
                        }
                        .foregroundColor(range == i ? .white : T.sub)
                        .padding(.horizontal, 12).frame(height: 38)
                        .background(range == i ? Color.white.opacity(0.1) : Color.clear).clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                stat("Pool", "\(Mk.fmtGems(c.poolV)) gems", T.gold)
                stat("Holders", "\(c.holders)")
                stat("Risk", Mk.risk(c), Mk.riskColor(c))
                stat("Age", Mk.age(c))
                stat("Peak", Mk.usdPrice(c.peak))
                stat("Fee", "3%")
            }
            .padding(.horizontal, 16)
            if !c.rugged { trustCard(ti).padding(.horizontal, 16) }
            HStack(spacing: 12) {
                if isMe {
                    Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 40)
                } else {
                    Avatar(emoji: npc?.emoji ?? "🙂", key: c.creator, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deployer").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    Text(cname).font(.jk(16, .bold))
                }
                Spacer()
                if prior > 0 {
                    Text("\(prior) prior rug\(prior == 1 ? "" : "s")").font(.jk(12, .heavy)).foregroundColor(T.red)
                        .padding(.horizontal, 10).padding(.vertical, 5).background(T.red.opacity(0.15)).clipShape(Capsule())
                } else {
                    Text("Clean record").font(.jk(12, .heavy)).foregroundColor(green)
                        .padding(.horizontal, 10).padding(.vertical, 5).background(green.opacity(0.15)).clipShape(Capsule())
                }
            }
            .padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .profileTap(c.creator)
            if c.mine && !c.rugged { boosters(c, m).padding(.horizontal, 16) }
            Button { trade = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: held != nil ? "wallet.pass.fill" : "arrow.left.arrow.right")
                    Text(held != nil ? "Your position: \(Mk.fmtGems((held?.qty ?? 0) * c.price)) gems" : "Trade \(c.id)").font(.jk(19, .semibold))
                }
                .foregroundColor(.white.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 58)
                .background(Color.white.opacity(0.07)).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            CoinChatPreview(ticker: c.id, open: $chat).padding(.horizontal, 16)
        }
    }

    private func trustCard(_ ti: TrustInfo) -> some View {
        let col = Mk.labelColor(ti.score)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("COMMUNITY TRUST").font(.jk(11, .heavy)).foregroundColor(T.sub)
                Spacer()
                Text("\(ti.score)").font(.jk(28, .heavy)).foregroundColor(col)
                Text("/100 · \(Mk.label(ti.score))").font(.jk(13, .bold)).foregroundColor(T.sub)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(col).frame(width: g.size.width * CGFloat(ti.score) / 100)
                }
            }
            .frame(height: 8)
            ForEach(ti.parts) { p in
                HStack(spacing: 8) {
                    Text(p.delta == 0 ? "0" : (p.delta > 0 ? "+\(p.delta)" : "\(p.delta)"))
                        .font(.jk(13, .heavy))
                        .foregroundColor(p.delta < 0 ? T.red : (p.delta > 0 ? green : T.sub))
                        .frame(width: 36, alignment: .leading)
                    Text(p.note).font(.jk(13)).foregroundColor(.white.opacity(0.85)).lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            Text(Mk.advice(ti.score)).font(.jk(12, .semibold)).foregroundColor(col)
        }
        .padding(14)
        .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func boosters(_ c: Coin, _ m: Market) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BOOSTERS").font(.jk(11, .heavy)).foregroundColor(T.sub)
                Spacer()
                if !c.fxOn("lock") {
                    Label("Exposed to crashes", systemImage: "exclamationmark.triangle.fill").font(.jk(11, .bold)).foregroundColor(T.orange)
                }
            }
            ForEach(Booster.allCases) { b in
                let owned = m.inv?[b.rawValue] ?? 0
                let left = Int((c.fx?[b.rawValue] ?? .distantPast).timeIntervalSinceNow / 60)
                Button { game.useBooster(b, on: c.id) } label: {
                    HStack(spacing: 12) {
                        SymbolTile(emoji: b.emoji, size: 40, tint: T.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).font(.jk(15, .bold)).foregroundColor(.white)
                            Text(left > 0 ? "Active · \(left >= 60 ? "\(left / 60)h \(left % 60)m" : "\(left)m") left" : b.desc)
                                .font(.jk(12)).foregroundColor(left > 0 ? T.lime : T.sub).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 6)
                        if owned > 0 {
                            Text("Use · \(owned)").font(.jk(13, .bold)).foregroundColor(.black)
                                .padding(.horizontal, 12).padding(.vertical, 7).background(lav).clipShape(Capsule())
                        } else {
                            HStack(spacing: 4) {
                                GemIcon(size: 16)
                                Text("\(b.price)").font(.jk(14, .bold)).foregroundColor(gemPurple)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7).background(Color.white.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                    .padding(12).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bar(_ c: Coin) -> some View {
        HStack(spacing: 14) {
            Text("\(Mk.fmtMC(Mk.mc(c))) market cap").font(.jk(20, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Button { trade = true } label: {
                Text(c.rugged ? (c.crashed == true ? "Delisted" : "Rugged") : "Buy").font(.jk(24, .bold)).foregroundColor(c.rugged ? .white : .black)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(c.rugged ? T.red.opacity(0.7) : lav).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
        .background(LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

// MARK: - Coin chat

struct CoinBubble: View {
    let msg: CoinMsg
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)

    private func styled(_ s: String) -> Text {
        var out = Text("")
        for (i, sub) in s.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            let w = String(sub)
            var t = Text((i == 0 ? "" : " ") + w)
            if w.hasPrefix("$") { t = t.foregroundColor(lav) } else if w.hasPrefix("@") { t = t.foregroundColor(T.gold) }
            out = out + t
        }
        return out
    }

    var body: some View {
        if msg.sys {
            Text(msg.text).font(.jk(13, .bold)).foregroundColor(T.red).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(10)
                .background(T.red.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14))
        } else if msg.me {
            HStack {
                Spacer(minLength: 50)
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 6) {
                        if msg.dev { badge("DEV") }
                        Text("You").font(.jk(12, .bold)).foregroundColor(T.sub)
                        Text(Mk.ago(msg.at)).font(.jk(11)).foregroundColor(T.sub)
                    }
                    styled(msg.text).font(.jk(16)).foregroundColor(.black)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(lav).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                Avatar(emoji: msg.emoji, key: msg.handle, size: 34).profileTap(msg.handle)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(msg.name).font(.jk(12, .bold)).foregroundColor(T.sub).lineLimit(1)
                        if msg.dev { badge("DEV") }
                        Text(Mk.ago(msg.at)).font(.jk(11)).foregroundColor(T.sub)
                    }
                    styled(msg.text).font(.jk(16)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Spacer(minLength: 30)
            }
        }
    }

    private func badge(_ t: String) -> some View {
        Text(t).font(.jk(9, .heavy)).foregroundColor(.black).padding(.horizontal, 5).padding(.vertical, 2)
            .background(lav).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct CoinChatPreview: View {
    @EnvironmentObject var game: Game
    let ticker: String
    @Binding var open: Bool
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    private let green = Color(red: 0.4, green: 0.95, blue: 0.5)
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)

    var body: some View {
        let m = game.s.ex.market
        let log = m?.chats?[ticker] ?? []
        let holders = m?.coins.first(where: { $0.id == ticker })?.holders ?? 0
        VStack(alignment: .leading, spacing: 12) {
            Button { open = true } label: {
                HStack {
                    HStack(spacing: 6) {
                        Text("Live Chat").font(.jk(28, .bold))
                        Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(green).frame(width: 9, height: 9)
                        Text("\(holders) here").font(.jk(18, .semibold)).foregroundColor(green)
                    }
                }
                .foregroundColor(.white)
            }
            VStack(spacing: 10) {
                ForEach(log.suffix(6)) { CoinBubble(msg: $0) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CoinTalk.quick, id: \.self) { q in
                        Button { game.coinSay(ticker, q) } label: {
                            Text(q).font(.jk(14, .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 14).frame(height: 36).background(Color.white.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                }
            }
            Button { open = true } label: {
                HStack {
                    Text("Say something to the room").font(.jk(16)).foregroundColor(T.sub)
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundColor(lav)
                }
                .padding(.horizontal, 16).frame(height: 50)
                .background(Color.white.opacity(0.07)).clipShape(Capsule())
            }
        }
        .onReceive(timer) { _ in if !open { game.coinChatTick(ticker) } }
        .onAppear { game.coinChatSeed(ticker) }
    }
}

struct CoinChatSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let ticker: String
    @State private var text = ""
    @FocusState private var focus: Bool
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)
    private let green = Color(red: 0.4, green: 0.95, blue: 0.5)

    private func send() {
        let t = text.trimmed
        guard !t.isEmpty else { return }
        game.coinSay(ticker, t)
        text = ""
    }

    var body: some View {
        let m = game.s.ex.market
        let log = m?.chats?[ticker] ?? []
        let c = m?.coins.first(where: { $0.id == ticker })
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let c = c { CoinTile(c: c, size: 36) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("$\(ticker) chat").font(.jk(20, .bold))
                    HStack(spacing: 6) {
                        Circle().fill(c?.rugged == true ? T.red : green).frame(width: 7, height: 7)
                        Text(c?.rugged == true ? "Room is mourning" : "\(c?.holders ?? 0) here").font(.jk(12, .semibold)).foregroundColor(T.sub)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.1)).clipShape(Circle())
                }
            }
            .padding(16)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(log) { CoinBubble(msg: $0).id($0.id) }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
                .onChange(of: log.count) { _ in
                    if let id = log.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
                .onAppear {
                    if let id = log.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CoinTalk.quick, id: \.self) { q in
                        Button { game.coinSay(ticker, q) } label: {
                            Text(q).font(.jk(14, .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 14).frame(height: 34).background(Color.white.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            HStack(spacing: 10) {
                TextField("Message the room", text: $text).font(.jk(16)).focused($focus)
                    .submitLabel(.send).onSubmit { send(); focus = true }
                    .padding(.horizontal, 16).frame(height: 48)
                    .background(Color.white.opacity(0.08)).clipShape(Capsule())
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundColor(.black)
                        .frame(width: 48, height: 48).background(text.trimmed.isEmpty ? Color.white.opacity(0.2) : lav).clipShape(Circle())
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .presentationDetents([.large])
        .onReceive(timer) { _ in game.coinChatTick(ticker) }
        .onAppear { game.coinChatSeed(ticker) }
    }
}

struct TradeSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let ticker: String
    @State private var buyAmt = 5
    @State private var sellPct = 50
    @State private var confirmRug = false
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)

    var body: some View {
        let st = game.s
        let m = st.ex.market ?? Market()
        ScrollView {
            if let c = m.coins.first(where: { $0.id == ticker }) {
                content(c, m, st)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func content(_ c: Coin, _ m: Market, _ st: GameState) -> some View {
        let held = m.holds.first { $0.id == c.id }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                CoinTile(c: c, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.jk(20, .bold))
                    Text("$\(c.id) · \(Mk.fmtGems(c.price * 1000)) gems per 1K · risk \(Mk.risk(c))").font(.jk(12)).foregroundColor(T.sub)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.1)).clipShape(Circle())
                }
            }
            if let n = st.npcs.first(where: { $0.handle == c.creator }) {
                HStack(spacing: 10) {
                    Avatar(emoji: n.emoji, key: n.handle, size: 34)
                    Text("Deployer \(n.name)").font(.jk(14, .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(T.sub)
                }
                .padding(12).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 14))
                .profileTap(n.handle)
            }
            if let h = held {
                let v = h.qty * c.price
                let p = v - h.cost
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR POSITION").font(.jk(11, .heavy)).foregroundColor(T.sub)
                        Text("\(Mk.fmtGems(v)) gems").font(.jk(22, .bold))
                    }
                    Spacer()
                    Text("\(p >= 0 ? "+" : "")\(Mk.fmtGems(p))").font(.jk(18, .bold)).foregroundColor(p >= 0 ? T.lime : T.red)
                }
                .padding(14).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if !c.rugged {
                VStack(alignment: .leading, spacing: 10) {
                    Text("BUY").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    chips([2, 5, 10, 25, 50, 100], selected: buyAmt, label: { "\($0)" }) { buyAmt = $0 }
                    Button { game.marketBuy(c.id, gems: buyAmt) } label: {
                        Text("Buy with \(buyAmt) gems · fee \(Mk.fmtGems(Mk.fee(Double(buyAmt))))").font(.jk(17, .bold)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(st.ex.gems >= buyAmt ? lav : Color.white.opacity(0.12)).clipShape(Capsule())
                    }
                    .disabled(st.ex.gems < buyAmt)
                    Text("You have \(st.ex.gems) gems. 3% fee (min 1 gem) on every buy and sell. Big buys move the price. If \(c.mine ? "you rug" : "the deployer rugs"), the whole pool goes to \(c.mine ? "you" : "them").").font(.jk(12)).foregroundColor(T.sub)
                }
                .padding(14).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if held != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SELL").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    chips([25, 50, 75, 100], selected: sellPct, label: { "\($0)%" }) { sellPct = $0 }
                    Button { game.marketSell(c.id, frac: Double(sellPct) / 100) } label: {
                        Text("Sell \(sellPct)%").font(.jk(18, .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(T.red.opacity(0.8)).clipShape(Capsule())
                    }
                    Text("3% sell fee, min 1 gem. Slippage applies.").font(.jk(12)).foregroundColor(T.sub)
                }
                .padding(14).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if c.mine && !c.rugged {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CREATOR TOOLS").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    Button { game.marketShill(c.id) } label: {
                        Label("Shill it on the feed", systemImage: "megaphone.fill").font(.jk(16, .bold))
                            .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(lav).clipShape(Capsule())
                    }
                    Button { confirmRug = true } label: {
                        Label("Pull the rug", systemImage: "exclamationmark.triangle.fill").font(.jk(16, .bold))
                            .foregroundColor(T.red).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(T.red.opacity(0.15)).clipShape(Capsule())
                    }
                    Text("Rugging pays you the whole pool, \(Mk.fmtGems(c.poolV)) gems from every holder. The scene will turn on you.").font(.jk(12)).foregroundColor(T.sub)
                }
                .padding(14).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 16))
                .alert("Pull the rug on $\(c.id)?", isPresented: $confirmRug) {
                    Button("Rug it", role: .destructive) { game.marketRugOwn(c.id); dismiss() }
                    Button("Hold", role: .cancel) {}
                } message: { Text("You take the whole pool, \(Mk.fmtGems(c.poolV)) gems. Holders lose 98%. You take an aura and follower hit and make enemies.") }
            }
        }
        .padding(16).padding(.bottom, 20)
    }

    private func chips(_ vals: [Int], selected: Int, label: @escaping (Int) -> String, _ pick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(vals, id: \.self) { v in
                Button { pick(v) } label: {
                    Text(label(v)).font(.jk(14, .bold)).foregroundColor(selected == v ? .black : .white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(selected == v ? lav : Color.white.opacity(0.1)).clipShape(Capsule())
                }
            }
        }
    }
}

struct LaunchSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ticker = ""
    @State private var symbol = Mk.symbols[0]
    @State private var seed = 10
    @State private var err: String? = nil
    private let purple = Color(red: 0.45, green: 0.30, blue: 0.95)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Launch a coin").font(.jk(24, .bold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(T.card2).clipShape(Circle())
                    }
                }
                field("Name", "Dylib Inu", $name)
                field("Ticker", "DYLIB", $ticker).textInputAutocapitalization(.characters)
                Text("ICON").font(.jk(11, .heavy)).foregroundColor(T.sub)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Mk.symbols, id: \.self) { s in
                        Button { symbol = s } label: {
                            Image(systemName: s).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(symbol == s ? purple : T.card2).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                Text("SEED LIQUIDITY (GEMS) · +50 LAUNCH FEE").font(.jk(11, .heavy)).foregroundColor(T.sub)
                HStack(spacing: 8) {
                    ForEach([10, 25, 50, 100], id: \.self) { v in
                        Button { seed = v } label: {
                            Text("\(v)").font(.jk(15, .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(seed == v ? purple : T.card2).clipShape(Capsule())
                        }
                    }
                }
                Text("Launching costs a 50 gem fee that is gone for good, plus your seed. The market is volatile: without a Crash Lock or Market Maker from the store, a crash can wipe your coin out. Your seed goes into the pool and you start holding it. Other characters buy in when your hype is up, and their gems sit in the pool. Shill and chat to keep it moving. Pull the rug and the whole pool is yours, and the scene will remember.")
                    .font(.jk(13)).foregroundColor(T.sub)
                if let e = err { Text(e).font(.jk(14, .semibold)).foregroundColor(T.red) }
                BigButton(title: "Launch $\(ticker.uppercased().filter { $0.isLetter || $0.isNumber }) · \(seed + Mk.launchFee) gems", color: purple) {
                    if let e = game.marketLaunch(name: name, ticker: ticker, symbol: symbol, seed: seed) { err = e } else { dismiss() }
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .presentationDetents([.large])
    }

    private func field(_ label: String, _ ph: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.jk(11, .heavy)).foregroundColor(T.sub)
            TextField(ph, text: text).font(.jk(17)).padding(.horizontal, 14).frame(height: 48)
                .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
        }
    }
}
