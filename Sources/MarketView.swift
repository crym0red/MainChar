import SwiftUI

struct TickerID: Identifiable { let id: String }

struct Spark: View {
    let values: [Double]
    var color: Color = T.lime
    var fill = false
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
                    }.stroke(color, style: StrokeStyle(lineWidth: fill ? 2.4 : 1.8, lineCap: .round, lineJoin: .round))
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

struct MarketView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var seg = 0
    @State private var detail: TickerID? = nil
    @State private var launch = false
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    private let purple = Color(red: 0.45, green: 0.30, blue: 0.95)

    var body: some View {
        let st = game.s
        let m = st.ex.market ?? Market()
        let prices = Dictionary(m.coins.map { ($0.id, $0.price) }, uniquingKeysWith: { a, _ in a })
        let value = m.holds.reduce(0.0) { acc, h in acc + h.qty * (prices[h.id] ?? 0) }
        let cost = m.holds.reduce(0.0) { $0 + $1.cost }
        let pnl = m.realized + (value - cost)
        VStack(spacing: 0) {
            HStack {
                Text("Degen Wallet").font(.jk(24, .bold))
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "diamond.fill").font(.system(size: 12)).foregroundColor(T.gold)
                    Text("\(st.ex.gems)").font(.jk(15, .bold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8).background(T.card2).clipShape(Capsule())
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 16) {
                    walletCard(st, m, value, pnl)
                    Picker("", selection: $seg) {
                        Text("Market").tag(0); Text("Holdings").tag(1); Text("Yours").tag(2)
                    }.pickerStyle(.segmented)
                    list(m)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
        }
        .background(T.bg)
        .onReceive(timer) { _ in game.marketTick() }
        .onAppear { game.marketEnsureNow(); openPending() }
        .onChange(of: nav.coin) { _ in openPending() }
        .sheet(item: $detail) { CoinDetail(ticker: $0.id).zoomed() }
        .sheet(isPresented: $launch) { LaunchSheet().zoomed() }
    }

    private func openPending() {
        if let t = nav.coin { detail = TickerID(id: t); nav.coin = nil }
    }

    private func walletCard(_ st: GameState, _ m: Market, _ value: Double, _ pnl: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PORTFOLIO").font(.jk(11, .heavy)).foregroundColor(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Mk.fmtGems(value + Double(st.ex.gems))).font(.jk(40, .heavy))
                Text("gems").font(.jk(16, .semibold)).foregroundColor(.white.opacity(0.7))
            }
            HStack(spacing: 6) {
                Image(systemName: pnl >= 0 ? "arrow.up.right" : "arrow.down.right").font(.system(size: 12, weight: .bold))
                Text("\(pnl >= 0 ? "+" : "")\(Mk.fmtGems(pnl)) all-time")
                    .font(.jk(14, .bold))
            }
            .foregroundColor(pnl >= 0 ? Color(red: 0.55, green: 1, blue: 0.7) : Color(red: 1, green: 0.55, blue: 0.6))
            HStack(spacing: 10) {
                walletBtn("gift.fill", "Airdrop") { game.marketAirdrop() }
                walletBtn("plus.circle.fill", "Launch coin") { launch = true }
            }
        }
        .foregroundColor(.white)
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [purple, Color(red: 0.2, green: 0.12, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func walletBtn(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.jk(15, .bold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.white.opacity(0.2)).clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func list(_ m: Market) -> some View {
        let coins: [Coin] = {
            switch seg {
            case 1: return m.coins.filter { c in m.holds.contains(where: { $0.id == c.id }) }
            case 2: return m.coins.filter { $0.mine }
            default: return m.coins.sorted { a, b in
                if a.rugged != b.rugged { return !a.rugged }
                return a.born > b.born
            }
            }
        }()
        if coins.isEmpty {
            EmptyState(emoji: "💸", title: seg == 1 ? "No positions" : (seg == 2 ? "No coins launched" : "Nothing listed"),
                       detail: seg == 2 ? "Launch your own coin and see who buys in." : "Buy into a coin from the Market tab.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(coins.enumerated()), id: \.element.id) { i, c in
                    Button { detail = TickerID(id: c.id) } label: { row(c, m) }.buttonStyle(.plain)
                    if i < coins.count - 1 { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func row(_ c: Coin, _ m: Market) -> some View {
        let ch = Mk.change(c)
        let up = ch >= 0
        let held = m.holds.first { $0.id == c.id }
        return HStack(spacing: 12) {
            CoinTile(c: c)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(c.name).font(.jk(16, .bold)).foregroundColor(.white).lineLimit(1)
                    if c.rugged { tag("RUGGED", T.red) }
                    else if c.mine { tag("YOURS", purple) }
                    else if Date().timeIntervalSince(c.born) < 3600 { tag("NEW", T.blue) }
                }
                Text(held != nil ? "$\(c.id) · \(Mk.fmtGems((held?.qty ?? 0) * c.price)) gems held" : "$\(c.id) · \(c.holders) holders")
                    .font(.jk(12)).foregroundColor(T.sub).lineLimit(1)
            }
            Spacer(minLength: 4)
            Spark(values: c.hist, color: c.rugged ? T.red : (up ? T.lime : T.red)).frame(width: 58, height: 28)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Mk.fmtPrice(c.price)).font(.jk(14, .semibold)).foregroundColor(.white)
                Text("\(up ? "+" : "")\(Int(ch * 100))%").font(.jk(12, .bold)).foregroundColor(c.rugged ? T.red : (up ? T.lime : T.red))
            }
            .frame(width: 74, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }

    private func tag(_ t: String, _ c: Color) -> some View {
        Text(t).font(.jk(9, .heavy)).foregroundColor(.white)
            .padding(.horizontal, 5).padding(.vertical, 2).background(c).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct CoinDetail: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let ticker: String
    @State private var buyAmt = 5
    @State private var sellPct = 50
    @State private var confirmRug = false
    private let purple = Color(red: 0.45, green: 0.30, blue: 0.95)

    var body: some View {
        let st = game.s
        let m = st.ex.market ?? Market()
        ScrollView {
            if let c = m.coins.first(where: { $0.id == ticker }) {
                content(c, m, st)
            } else {
                EmptyState(emoji: "💸", title: "Coin delisted", detail: "It rugged and vanished from the market.").padding(.top, 60)
            }
        }
        .background(T.bg)
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func content(_ c: Coin, _ m: Market, _ st: GameState) -> some View {
        let ch = Mk.change(c)
        let up = ch >= 0
        let held = m.holds.first { $0.id == c.id }
        let col = c.rugged ? T.red : (up ? T.lime : T.red)
        let npc = st.npcs.first { $0.handle == c.creator }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                CoinTile(c: c, size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.jk(22, .bold))
                    Text("$\(c.id)").font(.jk(14, .semibold)).foregroundColor(T.sub)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(T.card2).clipShape(Circle())
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Mk.fmtPrice(c.price)).font(.jk(36, .heavy))
                Text("gems").font(.jk(14)).foregroundColor(T.sub)
                Text("\(up ? "+" : "")\(Int(ch * 100))%").font(.jk(16, .bold)).foregroundColor(col)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(col.opacity(0.15)).clipShape(Capsule())
            }
            if c.rugged {
                Label("This coin was rugged. The liquidity is gone.", systemImage: "exclamationmark.triangle.fill")
                    .font(.jk(14, .semibold)).foregroundColor(T.red)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(T.red.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spark(values: c.hist, color: col, fill: true).frame(height: 170)
                .padding(.vertical, 6)
            HStack(spacing: 10) {
                stat("Liquidity", Mk.fmtGems(c.liq))
                stat("Holders", "\(c.holders)")
                stat("Peak", Mk.fmtPrice(c.peak))
                stat("Risk", Mk.risk(c))
            }
            if let n = npc {
                HStack(spacing: 10) {
                    Avatar(emoji: n.emoji, key: n.handle, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Deployer").font(.jk(11)).foregroundColor(T.sub)
                        Text("\(n.name) @\(n.handle)").font(.jk(14, .semibold))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(T.sub)
                }
                .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                .profileTap(n.handle)
            }
            if let h = held {
                let v = h.qty * c.price
                let p = v - h.cost
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR POSITION").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    HStack {
                        Text("\(Mk.fmtGems(v)) gems").font(.jk(22, .bold))
                        Spacer()
                        Text("\(p >= 0 ? "+" : "")\(Mk.fmtGems(p))").font(.jk(16, .bold)).foregroundColor(p >= 0 ? T.lime : T.red)
                    }
                    Text("cost \(Mk.fmtGems(h.cost)) gems").font(.jk(12)).foregroundColor(T.sub)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if !c.rugged {
                VStack(alignment: .leading, spacing: 10) {
                    Text("BUY").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    chips([1, 5, 10, 25, 50, 100], selected: buyAmt, label: { "\($0)" }) { buyAmt = $0 }
                    Button { game.marketBuy(c.id, gems: buyAmt) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Buy with \(buyAmt) gems").font(.jk(17, .bold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(st.ex.gems >= buyAmt ? T.lime.opacity(0.85) : Color.white.opacity(0.12)).clipShape(Capsule())
                    }
                    .disabled(st.ex.gems < buyAmt)
                    Text("2% fee. Big buys move the price.").font(.jk(12)).foregroundColor(T.sub)
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if held != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SELL").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    chips([25, 50, 75, 100], selected: sellPct, label: { "\($0)%" }) { sellPct = $0 }
                    Button { game.marketSell(c.id, frac: Double(sellPct) / 100) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Sell \(sellPct)%").font(.jk(17, .bold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(T.red.opacity(0.8)).clipShape(Capsule())
                    }
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if c.mine && !c.rugged {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CREATOR TOOLS").font(.jk(11, .heavy)).foregroundColor(T.sub)
                    Button { game.marketShill(c.id) } label: {
                        Label("Shill it on the feed", systemImage: "megaphone.fill").font(.jk(16, .bold))
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(purple).clipShape(Capsule())
                    }
                    Button { confirmRug = true } label: {
                        Label("Pull the rug", systemImage: "exclamationmark.triangle.fill").font(.jk(16, .bold))
                            .foregroundColor(T.red).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(T.red.opacity(0.15)).clipShape(Capsule())
                    }
                    Text("Rugging cashes out the pool, but the scene will turn on you.").font(.jk(12)).foregroundColor(T.sub)
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
                .alert("Pull the rug on $\(c.id)?", isPresented: $confirmRug) {
                    Button("Rug it", role: .destructive) { game.marketRugOwn(c.id) }
                    Button("Hold", role: .cancel) {}
                } message: { Text("You cash out. Holders lose 98%. You take an aura and follower hit and make enemies.") }
            }
        }
        .padding(16).padding(.bottom, 20)
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(t).font(.jk(10, .semibold)).foregroundColor(T.sub)
            Text(v).font(.jk(13, .bold)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func chips(_ vals: [Int], selected: Int, label: @escaping (Int) -> String, _ pick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(vals, id: \.self) { v in
                Button { pick(v) } label: {
                    Text(label(v)).font(.jk(14, .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(selected == v ? purple : T.card2).clipShape(Capsule())
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
                Text("SEED LIQUIDITY (GEMS)").font(.jk(11, .heavy)).foregroundColor(T.sub)
                HStack(spacing: 8) {
                    ForEach([5, 10, 25, 50], id: \.self) { v in
                        Button { seed = v } label: {
                            Text("\(v)").font(.jk(15, .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(seed == v ? purple : T.card2).clipShape(Capsule())
                        }
                    }
                }
                Text("Your seed goes into the pool and you start holding it. Other characters buy in when your hype is up. Shill to keep it moving. You can pull the rug any time, and the scene will remember.")
                    .font(.jk(13)).foregroundColor(T.sub)
                if let e = err { Text(e).font(.jk(14, .semibold)).foregroundColor(T.red) }
                BigButton(title: "Launch $\(ticker.uppercased().filter { $0.isLetter || $0.isNumber }) for \(seed) gems", color: purple) {
                    if let e = game.marketLaunch(name: name, ticker: ticker, symbol: symbol, seed: seed) { err = e } else { dismiss() }
                }
            }
            .padding(16)
        }
        .background(T.bg)
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
