import SwiftUI

// MARK: - Post style

struct PostStyle: Codable, Hashable {
    var font = 0
    var scale = 1.0
    var hex: String? = nil

    static let fonts = ["Default", "Mono", "Serif", "Rounded", "Heavy"]
    static let sizes: [(String, Double)] = [("S", 0.85), ("M", 1.0), ("L", 1.3), ("XL", 1.7)]
    static let palette = ["FFFFFF", "FF4D4D", "FF9F1A", "FFD60A", "30D158", "64D2FF", "0A84FF", "BF5AF2", "FF6EB4", "A3E635"]

    var isDefault: Bool { font == 0 && scale == 1.0 && hex == nil }

    func uiFont(_ base: CGFloat) -> Font {
        let sz = base * CGFloat(scale)
        switch font {
        case 1: return .system(size: sz, weight: .medium, design: .monospaced)
        case 2: return .system(size: sz, weight: .regular, design: .serif)
        case 3: return .system(size: sz, weight: .semibold, design: .rounded)
        case 4: return Font.system(size: sz, weight: .black).italic()
        default: return .jk(sz)
        }
    }

    var color: Color { PostStyle.parse(hex) ?? .white }

    static func parse(_ h: String?) -> Color? {
        guard let h = h, h.count == 6, let v = Int(h, radix: 16) else { return nil }
        return Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}

extension Text {
    func postStyled(_ s: PostStyle?, base: CGFloat = 20) -> some View {
        self.font(s?.uiFont(base) ?? .jk(base)).foregroundColor(s?.color ?? .white)
    }
}

// MARK: - Post generator

enum PostGen {
    static let cats: [(String, String)] = [
        ("Brainrot", "🧠"), ("Hacker", "💻"), ("Shitpost", "🗑️"), ("Doomer", "🌑"), ("Grindset", "📈"), ("Wholesome", "🥰"),
        ("Scene", "📱"), ("Degen", "🪙"), ("Fake news", "📰"), ("Cryptic", "🔮"), ("Roast", "🔥"), ("Poll bait", "🗳️")
    ]

    private static func p(_ a: [String]) -> String { a.randomElement() ?? "" }

    static func make(_ cat: Int, scene: Bool) -> String {
        let n = Int.random(in: 2...99)
        switch cat {
        case 0:
            let a = p(["skibidi", "sigma", "ohio", "gyatt", "rizzler", "mewing", "fanum tax", "aura", "npc", "looksmaxxing", "griddy", "glizzy", "grimace shake", "brainrot"])
            let b = p(["ahh", "coded", "core", "pilled", "maxxing", "adjacent", "behavior", "moment"])
            let c = p(["him", "the main character", "that guy", "built different", "cooked", "the sigma"])
            return p(["\(a) \(b) post fr fr no cap", "bro really thought he was \(c) 💀", "ts \(a) got me down bad gng", "POV: you're in ohio and the \(a) is \(b)", "who let \(a) cook", "-\(n)00 aura for the \(a) \(b)", "nah this \(a) \(b) is actually tuff", "my brain is 40% \(a) and 60% \(b) and i'm not even mad", "the \(a) to \(b) pipeline is real and i'm in it"])
        case 1:
            let x = p(["the algorithm", "your aura", "the timeline", "the firewall", "someone's ex", "your feed", "the rate limit"])
            let l = p(["rust", "bash", "swift", "c", "assembly", "perl", "a single regex"])
            return p(["root@clout:~# sudo rm -rf /feelings --no-preserve-root", "[+] injecting payload into \(x)... done\n[+] access granted", "$ nmap -sV followers.local\n22/open ssh\n443/open clout", "git push --force origin main // no regrets", "0xDEADBEEF: \(x) has been pwned", "bypassed \(x) in \(n) lines of \(l)", "$ cat /etc/passwd | grep your_ex\ncommand not found: closure", "ssh me@mainframe -p \(n)00\nPermission denied (public vibe)", "[!] \(x) is vulnerable. patch drops never.", "whoami\n> a menace with root access"])
        case 2:
            let a = p(["a raccoon", "my landlord", "a goose", "three pigeons", "the wifi", "a haunted fridge", "my own reflection"])
            let b = p(["unionized", "plotting something", "owes me money", "knows what i did", "running for mayor", "my emotional support animal"])
            return p(["\(a) is \(b) and nobody is talking about it", "update: \(a) is still \(b)", "i have been informed \(a) is \(b). acting normal.", "no thoughts. just \(a).", "this is a public service announcement: \(a) is \(b)", "me: i'm fine\n\(a): \(b)"])
        case 3:
            return p(["we're all just npcs waiting for the server to shut down", "another day of pretending the timeline matters", "no one is coming. post anyway.", "the feed doesn't love you back but the likes feel close enough", "everyone you follow is as tired as you are", "still here. still posting. still pretending.", "touch grass? the grass also has a notification badge"])
        case 4:
            let h = p(["4am", "5am", "6am", "the grind"])
            return p(["wake up at \(h). post. repeat. followers are a lagging indicator.", "they sleep. i ship. that's the whole difference.", "discipline > motivation. also > sleep apparently.", "your competition posted 3 times today. you read this. think about it.", "be so consistent the algorithm gets tired of ignoring you", "\(n)% of success is just refusing to log off"])
        case 5:
            return p(["reminder to drink water and text your friend back 💛", "so grateful for everyone who showed up this week.", "small wins count. go celebrate one.", "you're doing better than you think. seriously.", "someone out there is glad you exist. that's it. that's the post.", "compliment someone today. low effort, huge return."])
        case 6:
            let x = p(["cert", "profile", "signer", "ipa", "dylib", "udid"])
            return scene ? p(["\(x) got revoked again. \(n)th time this week. we ride.", "who still pays for a \(x) in this economy", "sideloading is just the app store with extra steps and anxiety", "found a new \(x) trick. not telling. you'll see it in the leak.", "the scene is cooked and i'm still here", "sign it. install it. never speak of it.", "my \(x) lasted \(n) minutes. new personal best."]) : p(["the scene is moving faster than i can keep up with", "hot take: the underground is the only real timeline", "someone out there is building the next big thing in a group chat right now", "loyalty in this scene lasts exactly until the next drop"])
        case 7:
            let t = p(["MOON", "COPE", "RIZZ", "AURA", "GOON", "BAGZ", "REKT"])
            return p(["just aped \(n) gems into $\(t) on a vibe", "wagmi (not financial advice (i am financially unwell))", "$\(t) 100x or i touch grass", "sold the top. bought the bottom. lost it anyway.", "the chart looks like my heart rate", "nobody: ... me: checking $\(t) every \(n) seconds", "dev just locked the liquidity. i have never been this hopeful or this wrong"])
        case 8:
            let a = p(["local man", "area raccoon", "anonymous source", "sources close to the timeline", "a very tired intern"])
            let b = p(["goes viral for doing nothing", "ratios own mother", "pulls rug on entire neighborhood", "posts through it", "discovers the like button", "demands recount of followers"])
            return "BREAKING: \(a) \(b). more at 11."
        case 9:
            return p(["he knows.", "they were all there that night. you weren't.", "the third door was never meant to be opened.", "ask me again at midnight.", "i saw the file. i will not be explaining.", "some of you have already made your choice.", "check the logs."])
        case 10:
            let a = p(["your takes", "your aura", "your last post", "your whole feed", "your follower count", "your profile pic"])
            let b = p(["a participation trophy", "a loading screen", "a typo in a eulogy", "elevator music", "a free trial", "a tutorial nobody finished"])
            return p(["\(a) is giving \(b)", "no offense but \(a) feels like \(b)", "\(a) walked so the algorithm could ignore it", "respectfully, \(a) is \(b)"])
        default:
            let a = p(["pineapple on pizza", "reply guys", "dark mode", "morning people", "group chats", "voice notes", "the like button"])
            let b = p(["a crime", "overrated", "peak civilization", "a personality trait", "fine actually"])
            return p(["poll: \(a) is \(b). defend your answer.", "be honest. \(a): \(b)?", "settling this once and for all. \(a)."])
        }
    }
}

// MARK: - GIFs (built in, animated)

struct GifDef: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let hue: Double
}

enum GifLib {
    static let all: [GifDef] = [
        GifDef(id: "bounce", title: "Clown", emoji: "🤡", hue: 0.0),
        GifDef(id: "spin", title: "Dead", emoji: "💀", hue: 0.75),
        GifDef(id: "shake", title: "Crying", emoji: "😭", hue: 0.58),
        GifDef(id: "pulse", title: "Salute", emoji: "🫡", hue: 0.12),
        GifDef(id: "matrix", title: "Matrix", emoji: "🟩", hue: 0.36),
        GifDef(id: "rain", title: "Money rain", emoji: "💸", hue: 0.33),
        GifDef(id: "rocket", title: "To the moon", emoji: "🚀", hue: 0.62),
        GifDef(id: "fire", title: "On fire", emoji: "🔥", hue: 0.05),
        GifDef(id: "wave", title: "Wave", emoji: "👋", hue: 0.15),
        GifDef(id: "typing", title: "Hacking", emoji: "⌨️", hue: 0.38),
        GifDef(id: "chart", title: "Pump & rug", emoji: "📉", hue: 0.0),
        GifDef(id: "glitch", title: "Glitch", emoji: "📺", hue: 0.9),
        GifDef(id: "heart", title: "Heartbeat", emoji: "❤️", hue: 0.97),
        GifDef(id: "ghost", title: "Ghosted", emoji: "👻", hue: 0.7)
    ]
}

struct GifView: View {
    let id: String
    var caption: String = ""
    var hue: Double = 0.6
    var height: CGFloat = 190

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.6, brightness: 0.38), .black], startPoint: .top, endPoint: .bottom)
                scene(t)
                if !caption.isEmpty {
                    VStack {
                        Spacer()
                        Text(caption).font(.system(size: 18, weight: .heavy)).foregroundColor(.white)
                            .shadow(color: .black, radius: 2).multilineTextAlignment(.center).padding(10)
                    }
                }
            }
        }
        .frame(height: height).frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text("GIF").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3).background(Color.black.opacity(0.6)).clipShape(Capsule()).padding(8)
        }
    }

    private func rainCanvas(_ t: Double, glyphs: [String], color: Color, size: CGFloat, cols: Int) -> some View {
        Canvas { ctx, sz in
            for c in 0..<cols {
                let seed = Double((c * 7919) % 97) / 97
                let speed = 0.25 + seed * 0.35
                let x = (Double(c) + 0.5) / Double(cols) * sz.width
                for k in 0..<7 {
                    let y = ((t * speed + seed - Double(k) * 0.045).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * Double(sz.height + 40) - 20
                    let g = glyphs[(Int(t * 7) + c * 3 + k * 5) % glyphs.count]
                    let a = max(0.08, 1 - Double(k) * 0.16)
                    ctx.draw(Text(g).font(.system(size: size, weight: .bold, design: .monospaced)).foregroundColor(color.opacity(a)), at: CGPoint(x: x, y: y))
                }
            }
        }
    }

    @ViewBuilder private func scene(_ t: Double) -> some View {
        switch id {
        case "bounce":
            Text("🤡").font(.system(size: 78)).offset(y: CGFloat(30 - abs(sin(t * 4)) * 70))
        case "spin":
            Text("💀").font(.system(size: 78)).rotationEffect(.degrees(t * 240)).scaleEffect(1 + 0.15 * CGFloat(sin(t * 6)))
        case "shake":
            Text("😭").font(.system(size: 78)).offset(x: CGFloat(sin(t * 55) * 6), y: CGFloat(cos(t * 47) * 5))
        case "pulse":
            Text("🫡").font(.system(size: 78)).scaleEffect(1 + 0.25 * CGFloat(sin(t * 5)))
        case "matrix":
            rainCanvas(t, glyphs: ["0", "1", "ア", "ウ", "カ", "7", "9", "Z", "X", "ﾊ"], color: Color(red: 0.2, green: 1, blue: 0.4), size: 16, cols: 16)
        case "rain":
            rainCanvas(t, glyphs: ["💸", "💰", "🪙"], color: .white, size: 24, cols: 8)
        case "rocket":
            let p = (t * 0.45).truncatingRemainder(dividingBy: 1)
            ZStack {
                rainCanvas(t * 0.6, glyphs: ["·", "✦", "•"], color: .white, size: 12, cols: 12)
                Text("🚀").font(.system(size: 64)).offset(x: CGFloat(sin(t * 9) * 2), y: CGFloat(110 - 230 * p))
            }
        case "fire":
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Text("🔥").font(.system(size: 46)).scaleEffect(1 + 0.3 * CGFloat(abs(sin(t * 7 + Double(i) * 1.3))), anchor: .bottom)
                        .offset(y: CGFloat(i % 2 == 0 ? 8 : -6))
                }
            }
        case "wave":
            Text("👋").font(.system(size: 80)).rotationEffect(.degrees(sin(t * 6) * 25), anchor: .bottomTrailing)
        case "typing":
            let full = "root@clout:~# sudo make me famous\n[+] cracking the algorithm...\n[+] access granted\n[+] followers: +\(Int(t) % 90 + 10)K"
            let cnt = Int(t * 16) % (full.count + 24)
            let shown = String(full.prefix(min(cnt, full.count)))
            VStack(alignment: .leading) {
                Text(shown + (Int(t * 3) % 2 == 0 ? "█" : " ")).font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.3, green: 1, blue: 0.5))
                Spacer()
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        case "chart":
            chart(t)
        case "glitch":
            let big = Int(t * 6) % 3 == 0
            ZStack {
                Text("AURA NOT FOUND").foregroundColor(.red).offset(x: CGFloat(sin(t * 40) * (big ? 7 : 1.5)))
                Text("AURA NOT FOUND").foregroundColor(.cyan).offset(x: CGFloat(-sin(t * 37) * (big ? 7 : 1.5)))
                Text("AURA NOT FOUND").foregroundColor(.white)
            }
            .font(.system(size: 26, weight: .black, design: .monospaced))
        case "heart":
            Text("❤️").font(.system(size: 80)).scaleEffect(1 + 0.22 * CGFloat(pow(max(0, sin(t * 6)), 4)))
        default:
            Text("👻").font(.system(size: 76)).offset(x: CGFloat(sin(t * 1.6) * 70), y: CGFloat(cos(t * 3) * 14)).opacity(0.55 + 0.4 * abs(sin(t * 1.6)))
        }
    }

    private func chart(_ t: Double) -> some View {
        Canvas { ctx, sz in
            let phase = (t / 6).truncatingRemainder(dividingBy: 1)
            let n = 48
            var path = Path()
            var crashed = false
            for i in 0..<n {
                let x = Double(i) / Double(n - 1)
                if x > phase { break }
                var v = 0.18 + 0.72 * pow(x / 0.7, 1.6) + 0.025 * sin(x * 60)
                if x > 0.7 { v = max(0.04, (0.9 - 4.6 * (x - 0.7))); crashed = true }
                let pt = CGPoint(x: 16 + x * Double(sz.width - 32), y: Double(sz.height) - 24 - v * Double(sz.height - 60))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(crashed ? .red : Color(red: 0.4, green: 1, blue: 0.5)), lineWidth: 3)
            if crashed {
                ctx.draw(Text("RUGGED").font(.system(size: 22, weight: .black)).foregroundColor(.red), at: CGPoint(x: Double(sz.width) / 2, y: 30))
            }
        }
    }
}

struct GifCard: View {
    let m: Media
    var body: some View {
        GifView(id: m.title, caption: m.lines.first ?? "", hue: m.hue)
    }
}

// MARK: - Coin attached to a post

struct CoinPostCard: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let ticker: String

    var body: some View {
        let m = game.s.ex.market ?? Market()
        if let c = m.coins.first(where: { $0.id == ticker }) {
            let ch = Mk.change(c)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    CoinTile(c: c, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("$\(c.id)").font(.jk(18, .heavy))
                        Text(c.name).font(.jk(12)).foregroundColor(T.sub).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Mk.fmtMC(Mk.mc(c))).font(.jk(15, .bold))
                        Text(Mk.pct(ch)).font(.jk(13, .semibold)).foregroundColor(ch >= 0 ? T.lime : T.red)
                    }
                }
                HStack(spacing: 8) {
                    if c.rugged {
                        Text("Delisted").font(.jk(13, .bold)).foregroundColor(T.red)
                    } else {
                        Text("Trust \(c.tr ?? 70) · \(Mk.risk(c))").font(.jk(12, .bold)).foregroundColor(Mk.riskColor(c))
                    }
                    Spacer()
                    if !c.rugged {
                        Button { game.marketBuy(c.id, gems: 5) } label: {
                            Text("Buy 5").font(.jk(13, .bold)).foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 7).background(Color(red: 0.67, green: 0.62, blue: 0.95)).clipShape(Capsule())
                        }
                    }
                    Button { nav.coin = c.id; nav.tab = 5 } label: {
                        Text("Open").font(.jk(13, .bold)).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7).background(Color.white.opacity(0.12)).clipShape(Capsule())
                    }
                }
            }
            .padding(12)
            .background(Color(red: 0.45, green: 0.30, blue: 0.95).opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(red: 0.45, green: 0.30, blue: 0.95).opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Launch animation

struct LaunchRocket: View {
    var ticker: String
    var hue: Double = 0.7
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let p = (t * 0.5).truncatingRemainder(dividingBy: 1)
            ZStack {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.35), .black], startPoint: .top, endPoint: .bottom)
                Canvas { ctx, sz in
                    for i in 0..<26 {
                        let s = Double((i * 7919) % 101) / 101
                        let x = s * Double(sz.width)
                        let y = ((s * 3 + t * (0.1 + s * 0.2)).truncatingRemainder(dividingBy: 1)) * Double(sz.height)
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.3 + s * 0.6)))
                    }
                }
                Text("🚀").font(.system(size: 54)).rotationEffect(.degrees(-8))
                    .offset(x: CGFloat(sin(t * 10) * 1.5), y: CGFloat(60 - 140 * p))
                VStack {
                    Spacer()
                    Text("$\(ticker)").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.white)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Characters use the studio too

extension Game {
    /// Gives an NPC post a font, a GIF, generated text, a snippet or their coin so the feed feels alive.
    func studioDecorate(_ p: inout Post, _ n: NPC, _ st: GameState) {
        let scene = CastGen.isScene(st.world)
        var cats: [Int]
        switch n.trait {
        case .hype: cats = [4, 7, 0, 11]
        case .hater: cats = [10, 2, 3]
        case .gossip: cats = [8, 9, 10]
        case .mogul: cats = scene ? [1, 6, 4, 7] : [4, 7, 6]
        case .chaos: cats = scene ? [0, 2, 1, 7] : [0, 2, 7]
        case .wholesome: cats = [5, 11]
        default: cats = [0, 2, 6]
        }
        let cat = cats.randomElement() ?? 0
        if Double.random(in: 0...1) < 0.5 {
            p.text = String(PostGen.make(cat, scene: scene).prefix(240))
            p.poll = nil
            if cat == 11 { p.tag = "Poll" }
        }
        // hacker output becomes a terminal attachment
        if cat == 1, p.text.contains("\n"), Double.random(in: 0...1) < 0.6 {
            let lines = p.text.components(separatedBy: "\n")
            p.media = Media(kind: "code", title: "terminal.log", lines: Array(lines.prefix(14)), hue: 0.36)
            p.text = ["output below", "ran it. you won't like this.", "logs don't lie", "ok so this happened"].randomElement() ?? "logs"
        }
        // GIFs and memes
        if p.media == nil, p.poll == nil, Double.random(in: 0...1) < 0.3 {
            let pool: [String]
            switch cat {
            case 0: pool = ["bounce", "glitch", "spin"]
            case 1: pool = ["matrix", "typing", "glitch"]
            case 2: pool = ["shake", "bounce", "ghost"]
            case 3, 9: pool = ["ghost", "glitch", "pulse"]
            case 4: pool = ["fire", "rocket", "pulse"]
            case 5: pool = ["heart", "wave"]
            case 7: pool = ["rocket", "rain", "chart"]
            case 8: pool = ["glitch", "pulse"]
            case 10: pool = ["spin", "shake", "fire"]
            default: pool = ["typing", "matrix", "bounce", "wave"]
            }
            let id = pool.randomElement() ?? "bounce"
            let cap = Double.random(in: 0...1) < 0.6 ? (["fr", "cooked", "me rn", "ts tuff", "no way", "ratio", "it's over", "we're so back", "real", "pov"].randomElement() ?? "") : ""
            p.media = Media(kind: "gif", title: id, lines: [cap], hue: GifLib.all.first { $0.id == id }?.hue ?? 0.6)
        }
        // their own coin
        if p.media == nil || p.media?.kind == "gif", let c = (st.ex.market?.coins ?? []).first(where: { $0.creator == n.handle && !$0.rugged }),
           Double.random(in: 0...1) < 0.3 {
            p.coin = c.id
            if !p.text.contains("$\(c.id)") { p.text += " $\(c.id)" }
        }
        // fonts and colors
        if Double.random(in: 0...1) < 0.42 {
            var s = PostStyle()
            switch cat {
            case 1: s.font = 1; s.hex = "30D158"
            case 0: s.font = [3, 4].randomElement() ?? 4; s.hex = PostStyle.palette.randomElement()
            case 10, 2: s.font = 4; s.hex = n.trait == .hater ? "FF4D4D" : PostStyle.palette.randomElement()
            case 5: s.font = 3; s.hex = "FF6EB4"
            case 9, 3: s.font = 2; s.hex = ["BF5AF2", "64D2FF", "FFFFFF"].randomElement()
            case 7: s.font = 3; s.hex = ["A3E635", "FFD60A", "30D158"].randomElement()
            default: s.font = Int.random(in: 0...4); s.hex = PostStyle.palette.randomElement()
            }
            if p.text.count < 60 { s.scale = [1.0, 1.3, 1.7].randomElement() ?? 1.0 }
            else if p.text.count < 110 { s.scale = [1.0, 1.0, 1.3].randomElement() ?? 1.0 }
            if s.hex == "FFFFFF" { s.hex = nil }
            if !s.isDefault { p.style = s }
        }
    }
}
