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

struct CoinScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ScrubChart: View {
    let values: [Double]
    var color: Color
    @Binding var sel: Int?
    var label: (Int) -> String

    private func geo(_ size: CGSize) -> (lo: Double, span: Double) {
        let base = values.first ?? 0
        let lo = min(values.min() ?? 0, base)
        let hi = max(values.max() ?? 1, base)
        return (lo, max(1e-12, hi - lo))
    }
    private func yFor(_ v: Double, _ size: CGSize) -> CGFloat {
        let g = geo(size)
        let top: CGFloat = 30
        let usable = max(10, size.height - top - 8)
        return top + usable * (1 - CGFloat((v - g.lo) / g.span))
    }
    private func pt(_ i: Int, _ size: CGSize) -> CGPoint {
        let n = max(1, values.count - 1)
        return CGPoint(x: size.width * CGFloat(i) / CGFloat(n), y: yFor(values[i], size))
    }
    private func line(_ from: Int, _ to: Int, _ size: CGSize) -> Path {
        var p = Path()
        guard values.count > 1, from < to else { return p }
        p.move(to: pt(from, size))
        for i in (from + 1)...to { p.addLine(to: pt(i, size)) }
        return p
    }
    private func area(_ size: CGSize) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        p.move(to: CGPoint(x: 0, y: size.height))
        for i in values.indices { p.addLine(to: pt(i, size)) }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.closeSubpath()
        return p
    }

    var body: some View {
        GeometryReader { g in
            let size = g.size
            let last = max(0, values.count - 1)
            let cur = sel ?? last
            ZStack(alignment: .topLeading) {
                if values.count > 1 {
                    area(size).fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .opacity(sel == nil ? 1 : 0.5)
                    // dashed open-price baseline
                    Path { p in
                        let y = yFor(values[0], size)
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    // line: bright up to the cursor, dim after
                    line(0, last, size)
                        .stroke(color.opacity(sel == nil ? 1 : 0.3), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    if sel != nil {
                        line(0, cur, size)
                            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    let p = pt(cur, size)
                    if sel != nil {
                        Path { q in
                            q.move(to: CGPoint(x: p.x, y: 26))
                            q.addLine(to: CGPoint(x: p.x, y: size.height))
                        }.stroke(Color.white.opacity(0.55), lineWidth: 1)
                        Text(label(cur)).font(.jk(12, .bold)).foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.white.opacity(0.12)).clipShape(Capsule())
                            .position(x: min(max(p.x, 46), size.width - 46), y: 12)
                    }
                    Circle().fill(color.opacity(0.25)).frame(width: 22, height: 22).position(p)
                    Circle().fill(color).frame(width: 10, height: 10).position(p)
                    Circle().stroke(Color.black, lineWidth: 2).frame(width: 10, height: 10).position(p)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard values.count > 1, size.width > 0 else { return }
                        let n = values.count - 1
                        let raw = Int((v.location.x / size.width * CGFloat(n)).rounded())
                        let k = min(max(0, raw), n)
                        if sel != k {
                            sel = k
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                    .onEnded { _ in sel = nil }
            )
        }
    }
}

struct CoinHolder: Identifiable {
    var id: String
    var handle: String
    var name: String
    var emoji: String
    var pct: Double
    var pnl: Double
    var tags: [String]
    var me: Bool
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
    @State private var sel: Int? = nil
    @State private var scroll: CGFloat = 0
    @State private var allHolders = false
    private let lav = Color(red: 0.67, green: 0.62, blue: 0.95)
    private let green = Color(red: 0.4, green: 0.95, blue: 0.5)
    private let ranges = ["LIVE", "1D", "1W", "1M", "1Y", "ALL"]

    var body: some View {
        let st = game.s
        let m = st.ex.market ?? Market()
        ZStack {
            Color.black.ignoresSafeArea()
            if let c = m.coins.first(where: { $0.id == ticker }) {
                ScrollView {
                    content(c, m, st).padding(.top, 56).padding(.bottom, 120)
                }
                .coordinateSpace(name: "coinScroll")
                .onPreferenceChange(CoinScrollKey.self) { scroll = $0 }
                VStack { topBar(c, m); Spacer() }
                VStack { Spacer(); bar(c, m) }
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
        let vals = slice(c)
        let startV = vals.first ?? c.price
        let curV = sel.map { vals[min($0, vals.count - 1)] } ?? (vals.last ?? c.price)
        let sch = startV > 0 ? curV / startV - 1 : 0
        let sdelta = (curV - startV) * Mk.supply
        let scol: Color = c.rugged ? T.red : (sch >= 0 ? green : T.red)
        VStack(alignment: .leading, spacing: 14) {
            Color.clear.frame(height: 0)
                .background(GeometryReader { gp in
                    Color.clear.preference(key: CoinScrollKey.self, value: gp.frame(in: .named("coinScroll")).minY)
                })
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    CoinTile(c: c, size: 44)
                    Text(c.id).font(.jk(40, .heavy))
                    Text(c.name.uppercased()).font(.jk(14, .semibold)).foregroundColor(T.sub).lineLimit(1)
                }
                Text(Mk.fmtMC(curV * Mk.supply)).font(.jk(44, .heavy))
                Text("\(sdelta >= 0 ? "+" : "-")\(Mk.fmtMC(abs(sdelta))) (\(Mk.pct(sch)))")
                    .font(.jk(22, .semibold)).foregroundColor(scol)
                if sel != nil {
                    Text("\(Mk.usdPrice(curV)) per coin · vs \(rangeName()) open \(Mk.fmtMC(startV * Mk.supply))")
                        .font(.jk(12, .semibold)).foregroundColor(T.sub)
                } else {
                    Text("\(Mk.usdPrice(c.price)) per coin · drag the chart to scrub")
                        .font(.jk(12, .semibold)).foregroundColor(T.sub)
                }
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
            ScrubChart(values: vals, color: scol, sel: $sel, label: { when($0, vals.count) })
                .frame(height: 280).padding(.top, 6)
            HStack(spacing: 4) {
                ForEach(Array(ranges.enumerated()), id: \.offset) { i, r in
                    Button { range = i; sel = nil } label: {
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
            if let h = held { positionCard(c, h).padding(.horizontal, 16) }
            summaryCard(c, ti, cname).padding(.horizontal, 16)
            holdersCard(c, m, st, ti).padding(.horizontal, 16)
            if !c.rugged { trustCard(ti).padding(.horizontal, 16) }
            aboutCard(c, ti, cname).padding(.horizontal, 16)
            securityCard(c, ti).padding(.horizontal, 16)
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

    private func bar(_ c: Coin, _ m: Market) -> some View {
        let held = m.holds.first { $0.id == c.id }
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Mk.fmtMC(Mk.mc(c))).font(.jk(22, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(held != nil ? "your stack \(Mk.fmtGems((held?.qty ?? 0) * c.price)) gems" : "market cap")
                    .font(.jk(13, .semibold)).foregroundColor(T.sub).lineLimit(1).minimumScaleFactor(0.7)
            }
            Button { trade = true } label: {
                Text(c.rugged ? (c.crashed == true ? "Delisted" : "Rugged") : (held != nil ? "Trade" : "Buy")).font(.jk(24, .bold)).foregroundColor(c.rugged ? .white : .black)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(c.rugged ? T.red.opacity(0.7) : lav).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 12)
        .background(
            ZStack(alignment: .top) {
                Color.black.opacity(0.94)
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            }.ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: sticky top bar
    private func topBar(_ c: Coin, _ m: Market) -> some View {
        let show = Double(min(1, max(0, (-scroll - 70) / 40)))
        let watching = (m.watch ?? []).contains(c.id)
        let ch = Mk.change(c)
        return ZStack {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Color.white.opacity(0.08)).clipShape(Circle())
                }
                Spacer()
                Button { game.marketToggleWatch(c.id) } label: {
                    Image(systemName: watching ? "heart.fill" : "heart").font(.system(size: 18)).foregroundColor(watching ? T.red : .white)
                        .frame(width: 44, height: 44).background(Color.white.opacity(0.08)).clipShape(Circle())
                }
                Button { chat = true } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 16)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Color.white.opacity(0.08)).clipShape(Circle())
                }
            }
            HStack(spacing: 6) {
                CoinTile(c: c, size: 22)
                Text(c.id).font(.jk(17, .heavy))
                Text(Mk.fmtMC(Mk.mc(c))).font(.jk(17, .semibold)).foregroundColor(c.rugged ? T.red : (ch >= 0 ? green : T.red))
            }
            .opacity(show).offset(y: CGFloat((1 - show) * 8))
        }
        .padding(.horizontal, 12).frame(height: 56)
        .background(
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.96 * show)
                Rectangle().fill(Color.white.opacity(0.08 * show)).frame(height: 1)
            }
        )
    }

    // MARK: chart helpers
    private func rangeName() -> String { ranges[range] == "LIVE" ? "session" : ranges[range] }

    private func when(_ i: Int, _ n: Int) -> String {
        let step: [Double] = [1, 5, 30, 180, 1440, 2880]
        let mins = Double(max(0, n - 1 - i)) * step[range]
        if mins < 1 { return "Now" }
        if mins < 60 { return "\(Int(mins))m ago" }
        if mins < 1440 { return "\(Int(mins / 60))h ago" }
        return "\(Int(mins / 1440))d ago"
    }

    private func sectionHead(_ t: String, _ trailing: String? = nil, _ tcol: Color = .gray) -> some View {
        HStack {
            Text(t).font(.jk(11, .heavy)).foregroundColor(T.sub)
            Spacer()
            if let tr = trailing { Text(tr).font(.jk(12, .bold)).foregroundColor(tcol) }
        }
    }

    // MARK: your position
    private func positionCard(_ c: Coin, _ h: Holding) -> some View {
        let value = h.qty * c.price
        let pnl = value - h.cost
        let pct = h.cost > 0 ? pnl / h.cost : 0
        let col: Color = pnl >= 0 ? green : T.red
        return VStack(alignment: .leading, spacing: 12) {
            sectionHead("YOUR POSITION")
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    GemIcon(size: 22)
                    Text(Mk.fmtGems(value)).font(.jk(30, .heavy))
                }
                Spacer()
                Text("\(pnl >= 0 ? "+" : "-")\(Mk.fmtGems(abs(pnl))) (\(Mk.pct(pct)))").font(.jk(16, .bold)).foregroundColor(col)
            }
            HStack(spacing: 8) {
                miniStat("Bought at", Mk.fmtGems(h.cost) + " gems")
                miniStat("Share", String(format: "%.2f%%", h.qty / Mk.supply * 100))
                miniStat("Rank", "#\(yourRank(c, h))")
            }
        }
        .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func yourRank(_ c: Coin, _ h: Holding) -> Int {
        let st = game.s
        let m = st.ex.market ?? Market()
        let list = holderList(c, m, st, game.trustInfo(c))
        return (list.firstIndex { $0.me } ?? list.count) + 1
    }

    private func miniStat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k.uppercased()).font(.jk(9, .heavy)).foregroundColor(T.sub)
            Text(v).font(.jk(14, .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: summary
    private func summaryText(_ c: Coin, _ ti: TrustInfo, _ cname: String) -> String {
        let ch = Mk.change(c)
        let dir = ch >= 0 ? "up" : "down"
        var out = "$\(c.id) (\(c.name)) was deployed by \(cname) \(Mk.age(c)) ago and is \(dir) \(Mk.pct(abs(ch)).replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")) this session at a \(Mk.fmtMC(Mk.mc(c))) market cap. "
        out += "\(c.holders) holders are in with \(Mk.fmtGems(c.poolV)) gems of liquidity. "
        if c.rugged {
            out += c.crashed == true ? "The market collapsed it and it is delisted." : "The deployer pulled the pool. It is dead."
        } else if ti.rugs > 0 {
            out += "\(cname) has \(ti.rugs) prior rug\(ti.rugs == 1 ? "" : "s"). " + Mk.advice(ti.score)
        } else {
            out += Mk.advice(ti.score)
        }
        return out
    }

    private func summaryCard(_ c: Coin, _ ti: TrustInfo, _ cname: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundColor(lav)
                Text("SUMMARY").font(.jk(11, .heavy)).foregroundColor(T.sub)
            }
            Text(summaryText(c, ti, cname)).font(.jk(15)).foregroundColor(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
            Text("Generated from market insights").font(.jk(11, .semibold)).foregroundColor(T.sub)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: top holders
    private func holderList(_ c: Coin, _ m: Market, _ st: GameState, _ ti: TrustInfo) -> [CoinHolder] {
        let pool = st.npcs.filter { $0.handle != c.creator }
        guard !pool.isEmpty else { return [] }
        let count = max(3, min(10, c.holders))
        var picks: [NPC] = []
        var seen = Set<String>()
        var k: UInt32 = 0
        while picks.count < min(count, pool.count) && k < 400 {
            let n = pool[Int(HK.h(c.id + "#\(k)") % UInt32(pool.count))]
            if seen.insert(n.handle).inserted { picks.append(n) }
            k += 1
        }
        let top = min(0.45, ti.conc * 0.5 + 0.05)
        var out: [CoinHolder] = []
        for (i, n) in picks.enumerated() {
            let jit = 0.75 + Double(HK.h(c.id + n.handle) % 50) / 100
            let pct = max(0.002, top * pow(0.72, Double(i)) * jit)
            let entry = c.price * (0.25 + Double(HK.h(n.handle + c.id) % 150) / 100)
            let pnl = entry > 0 ? c.price / entry - 1 : 0
            var tags: [String] = []
            if i == 0 && (c.whale ?? 0) > 0.3 { tags.append("Whale") }
            if HK.h(n.handle + c.id + "s") % 9 == 0 { tags.append("Sniper") }
            out.append(CoinHolder(id: n.handle, handle: n.handle, name: n.name, emoji: n.emoji, pct: pct, pnl: pnl, tags: tags, me: false))
        }
        if let dev = st.npcs.first(where: { $0.handle == c.creator }), !c.mine {
            let pct = max(0.01, top * 0.45)
            out.append(CoinHolder(id: dev.handle, handle: dev.handle, name: dev.name, emoji: dev.emoji, pct: pct, pnl: Mk.change(c), tags: ["Deployer"], me: false))
        }
        if let h = m.holds.first(where: { $0.id == c.id }) {
            let cost = h.cost > 0 ? h.cost : 1
            out.append(CoinHolder(id: st.persona.handle, handle: st.persona.handle, name: "You", emoji: st.persona.emoji,
                                  pct: h.qty / Mk.supply, pnl: (h.qty * c.price) / cost - 1, tags: ["You"], me: true))
        }
        return out.sorted { $0.pct > $1.pct }
    }

    private func rankColor(_ i: Int) -> Color {
        switch i {
        case 0: return T.gold
        case 1: return Color(white: 0.78)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.3)
        default: return Color.white.opacity(0.18)
        }
    }

    private func holdersCard(_ c: Coin, _ m: Market, _ st: GameState, _ ti: TrustInfo) -> some View {
        let all = holderList(c, m, st, ti)
        let shown = allHolders ? all : Array(all.prefix(5))
        let conc = all.prefix(10).reduce(0) { $0 + $1.pct }
        let ccol: Color = conc > 0.5 ? T.red : (conc > 0.3 ? T.orange : green)
        return VStack(alignment: .leading, spacing: 10) {
            sectionHead("TOP HOLDERS", "Top \(min(10, all.count)) hold \(String(format: "%.0f", conc * 100))%", ccol)
            if all.isEmpty {
                Text("No holders yet.").font(.jk(14)).foregroundColor(T.sub)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { i, h in
                HStack(spacing: 10) {
                    Text("\(i + 1)").font(.jk(12, .heavy)).foregroundColor(i < 3 ? .black : .white)
                        .frame(width: 22, height: 22).background(rankColor(i)).clipShape(Circle())
                    Avatar(emoji: h.emoji, key: h.handle, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(h.name).font(.jk(15, .bold)).lineLimit(1)
                            ForEach(h.tags, id: \.self) { t in
                                Text(t.uppercased()).font(.jk(8, .heavy)).foregroundColor(t == "You" ? .black : (t == "Whale" ? .black : .white))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(t == "You" ? lav : (t == "Whale" ? T.blue : (t == "Deployer" ? T.orange : Color.white.opacity(0.18))))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule().fill(h.me ? lav : T.blue.opacity(0.8))
                                    .frame(width: max(4, g.size.width * CGFloat(min(1, h.pct / max(0.01, all.first?.pct ?? 0.1)))))
                            }
                        }.frame(height: 4)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Mk.fmtMC(h.pct * Mk.mc(c))).font(.jk(15, .bold))
                        Text("\(String(format: "%.1f", h.pct * 100))% · \(Mk.pct(h.pnl))").font(.jk(11, .bold))
                            .foregroundColor(h.pnl >= 0 ? green : T.red)
                    }
                }
                .padding(.vertical, 2)
                .profileTap(h.handle)
            }
            if all.count > 5 {
                Button { withAnimation { allHolders.toggle() } } label: {
                    Text(allHolders ? "Show less" : "Show all \(all.count)").font(.jk(14, .bold)).foregroundColor(lav)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(Color.white.opacity(0.06)).clipShape(Capsule())
                }
            }
        }
        .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: about + security
    private func kv(_ k: String, _ v: String, _ col: Color = .white) -> some View {
        HStack {
            Text(k).font(.jk(14)).foregroundColor(T.sub)
            Spacer()
            Text(v).font(.jk(14, .bold)).foregroundColor(col).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func aboutCard(_ c: Coin, _ ti: TrustInfo, _ cname: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead("ABOUT")
            kv("Name", c.name)
            kv("Ticker", "$\(c.id)")
            kv("Deployer", cname)
            kv("Launched", "\(Mk.age(c)) ago")
            kv("Total supply", "1,000,000")
            kv("Liquidity", "\(Mk.fmtGems(c.poolV)) gems")
            kv("All-time high", Mk.fmtMC(c.peak * Mk.supply))
            kv("Trade fee", "3%")
        }
        .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func secRow(_ ok: Bool, _ t: String, _ d: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16)).foregroundColor(ok ? green : T.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.jk(14, .bold))
                Text(d).font(.jk(12)).foregroundColor(T.sub)
            }
            Spacer(minLength: 0)
        }
    }

    private func securityCard(_ c: Coin, _ ti: TrustInfo) -> some View {
        let verified = ti.score >= 52 && ti.rugs == 0 && !c.rugged
        return VStack(alignment: .leading, spacing: 12) {
            sectionHead("SECURITY", verified ? "Verified" : "Unverified", verified ? green : T.orange)
            secRow(ti.rugs == 0, ti.rugs == 0 ? "Clean deployer" : "\(ti.rugs) prior rug\(ti.rugs == 1 ? "" : "s")",
                   ti.rugs == 0 ? "No rugs on record for this deployer." : "This deployer has pulled liquidity before.")
            secRow(ti.conc < 0.4, ti.conc < 0.4 ? "Spread out holders" : "Whale concentration",
                   ti.conc < 0.4 ? "No single wallet can crash the price alone." : "One wallet can move the price hard.")
            secRow(c.poolV >= 30, c.poolV >= 30 ? "Healthy liquidity" : "Thin liquidity",
                   "\(Mk.fmtGems(c.poolV)) gems in the pool.")
            secRow(!c.rugged, c.rugged ? "Liquidity pulled" : "Liquidity in pool",
                   c.rugged ? "The pool is empty." : "The deployer has not touched the pool.")
        }
        .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
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
