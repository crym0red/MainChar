import SwiftUI

// MARK: - Stories and live streams for every character

struct NPCStory: Codable, Hashable, Identifiable {
    var id = UUID()
    var handle: String
    var text: String
    var bg: Int
    var date: Date = Date()
    var seen: Bool? = nil
}

struct NPCLive: Codable, Hashable, Identifiable {
    var id = UUID()
    var handle: String
    var topic: String
    var started: Date = Date()
    var ends: Date
    var viewers: Int
}

enum LiveMode: Hashable {
    case host(String)
    case watch(String)
}

struct LiveOpen: Identifiable {
    let id = UUID()
    var mode: LiveMode
}

extension Game {
    // MARK: World sim: characters post stories and go live

    func pruneLive(_ st: inout GameState) {
        let now = Date()
        st.ex.npcStories = (st.ex.npcStories ?? []).filter { now.timeIntervalSince($0.date) < 86400 }
        st.ex.npcLives = (st.ex.npcLives ?? []).filter { $0.ends > now }
    }

    func simStory(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard let n = cast.randomElement() else { return }
        let topics = Topics.forWorld(st.world)
        var text = Corpus.post(trait: n.trait, me: st.persona.handle, topic: topics.randomElement() ?? "this")
            ?? Lines.feed[n.trait]?.randomElement() ?? "just vibing"
        if text.count > 120 { text = String(text.prefix(117)) + "..." }
        var l = st.ex.npcStories ?? []
        l.removeAll { $0.handle == n.handle }
        l.insert(NPCStory(handle: n.handle, text: text, bg: Int.random(in: 0..<6), date: st.ex.simNow ?? Date()), at: 0)
        st.ex.npcStories = Array(l.prefix(12))
        logEvent(&st, &items, quiet: quiet, emoji: n.emoji, title: "\(n.name) posted a story",
                 detail: "\"\(String(text.prefix(80)))\"", handles: [n.handle], weight: 8)
    }

    func simGoLive(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        let live = st.ex.npcLives ?? []
        guard let n = cast.filter({ c in !live.contains { $0.handle == c.handle } }).randomElement() else { return }
        var topic = ["Just Chatting", "Hot Takes", "Q&A", "Callout Stream"].randomElement() ?? "Just Chatting"
        if activeFeuds(st).contains(where: { $0.a == n.handle || $0.b == n.handle }) { topic = "Callout Stream" }
        let viewers = max(40, n.followers / Int.random(in: 40...120))
        let peak = viewers * Int.random(in: 1...3)
        if quiet {
            var l = live
            l.insert(NPCLive(handle: n.handle, topic: topic, ends: Date().addingTimeInterval(Double.random(in: 420...720)), viewers: viewers), at: 0)
            st.ex.npcLives = l
        }
        logEvent(&st, &items, quiet: quiet, emoji: "🔴", title: quiet ? "\(n.name) is live" : "\(n.name) went live",
                 detail: "\(topic). Peaked at \(peak) viewers.", handles: [n.handle], weight: quiet ? 35 : 22,
                 history: quiet ? nil : "\(n.name) streamed \(topic.lowercased()) and peaked at \(peak) viewers.")
    }

    /// Makes sure the stories row and live badges have something in them when the feed opens.
    func seedPresence() {
        guard playing, s.intro?.done != false else { return }
        var st = s
        pruneLive(&st)
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard cast.count >= 2 else { return }
        var items: [DigestItem] = []
        var tries = 0
        while (st.ex.npcStories ?? []).count < 10 && tries < 20 { simStory(&st, &items, cast, true); tries += 1 }
        tries = 0
        while (st.ex.npcLives ?? []).count < 3 && tries < 6 { simGoLive(&st, &items, cast, true); tries += 1 }
        if st.posts.count < 16 {
            st.posts.insert(contentsOf: fallbackPosts(st, 14), at: 0)
        }
        s = st
    }

    func markStorySeen(_ id: UUID) {
        var st = s
        var l = st.ex.npcStories ?? []
        if let i = l.firstIndex(where: { $0.id == id }) { l[i].seen = true }
        st.ex.npcStories = l
        s = st
    }

    /// The character answers a reply to their story. Cussing starts a fight.
    func storyReply(_ handle: String, text: String) -> String {
        var st = s
        guard let j = st.npcs.firstIndex(where: { $0.handle == handle }) else { return "👀" }
        let n = st.npcs[j]
        let angry = ContentPrefs.isHostile(text)
        var warm = n.affinity >= 45
        if n.trait == .hater && n.affinity < 70 { warm = Double.random(in: 0...1) < 0.25 }
        if angry { warm = false }
        let out = voiceLine(st, n, bucket: warm ? "dm.warm" : "dm.cold", target: nil, toPlayer: true, text: text,
                            heat: angry ? 0.95 : 0.45, angry: angry)?.0 ?? (warm ? "lol thanks" : "ok.")
        if angry {
            st.npcs[j].affinity = max(0, n.affinity - 12)
            remember(&st, handle, "insult", "you cussed them out over their story", mood: -3)
        } else {
            st.npcs[j].affinity = min(100, n.affinity + 1)
        }
        s = st
        return out
    }

    func liveInsult(_ handle: String) {
        var st = s
        if let j = st.npcs.firstIndex(where: { $0.handle == handle }) { st.npcs[j].affinity = max(0, st.npcs[j].affinity - 10) }
        remember(&st, handle, "insult", "you cussed them out on their live stream", mood: -3)
        s = st
    }

    func liveKind(_ handle: String) {
        var st = s
        if let j = st.npcs.firstIndex(where: { $0.handle == handle }) { st.npcs[j].affinity = min(100, st.npcs[j].affinity + 1) }
        s = st
    }

    func finishLive(topic: String, peak: Int, gems: Int, gain: Int, aura: Int, rival: String?) {
        var st = s
        st.followers += gain
        st.aura = min(95, max(5, st.aura + aura))
        st.lastAuraDelta = aura
        st.ex.gems += gems
        gainXP(&st, 10)
        bump(&st, "live")
        var items: [DigestItem] = []
        logEvent(&st, &items, quiet: true, emoji: "🔴", title: "You went live: \(topic)",
                 detail: "Peak \(peak) viewers, +\(gain) followers, \(gems) gems.", weight: 20,
                 history: "You streamed \(topic.lowercased()) and peaked at \(peak) viewers.")
        if let r = rival {
            remember(&st, r, "insult", "you cussed them out on your stream", mood: -3)
            if let n = st.npcs.filter({ $0.id != "newsdesk" && $0.handle != r }).randomElement() {
                var p = makePost(n, "that clip of @\(st.persona.handle) losing it on stream tho 💀", st)
                p.tag = "Clip"
                stampPost(&p, st)
                st.posts.insert(p, at: 0)
            }
        }
        s = st
    }
}

// MARK: - Live view (hosting your own stream or watching a character's)

struct LiveMsg: Identifiable {
    let id = UUID()
    var name: String
    var handle: String
    var text: String
    var kind: Int   // 0 chat, 1 donation, 2 raid, 3 system, 4 you, 5 streamer
    var icon: String? = nil
}

struct LiveGift: Identifiable {
    let name: String, symbol: String, cost: Int, color: Color
    var id: String { name }
    static let all: [LiveGift] = [
        LiveGift(name: "Coffee", symbol: "cup.and.saucer.fill", cost: 1, color: Color(red: 0.85, green: 0.65, blue: 0.45)),
        LiveGift(name: "Heart", symbol: "heart.fill", cost: 2, color: Color(red: 1, green: 0.4, blue: 0.55)),
        LiveGift(name: "Bug bounty", symbol: "ladybug.fill", cost: 3, color: T.lime),
        LiveGift(name: "Signed cert", symbol: "checkmark.seal.fill", cost: 5, color: T.blue),
        LiveGift(name: "Server rack", symbol: "server.rack", cost: 10, color: Color(red: 0.6, green: 0.55, blue: 1)),
        LiveGift(name: "Rocket", symbol: "paperplane.fill", cost: 25, color: T.orange),
        LiveGift(name: "Crown", symbol: "crown.fill", cost: 50, color: T.gold),
        LiveGift(name: "Root access", symbol: "terminal.fill", cost: 100, color: Color(red: 0.2, green: 1, blue: 0.5))
    ]
}

struct Floater: Identifiable {
    let id = UUID()
    let symbol: String
    let color: Color
    let dx: CGFloat
    var size: CGFloat = 26
}

struct FloatingIcon: View {
    let f: Floater
    @State private var go = false
    var body: some View {
        Image(systemName: f.symbol).font(.system(size: f.size, weight: .bold)).foregroundColor(f.color)
            .shadow(color: f.color.opacity(0.7), radius: 6)
            .offset(x: go ? f.dx : 0, y: go ? -250 : 0)
            .opacity(go ? 0 : 1).scaleEffect(go ? 1.4 : 0.6)
            .onAppear { withAnimation(.easeOut(duration: 2.1)) { go = true } }
    }
}

extension Game {
    func liveGift(_ handle: String, cost: Int, name: String) -> Bool {
        var st = s
        guard st.ex.gems >= cost else { showToast("Not enough gems"); return false }
        st.ex.gems -= cost
        if let j = st.npcs.firstIndex(where: { $0.handle == handle }) {
            st.npcs[j].affinity = min(100, st.npcs[j].affinity + max(1, cost / 2))
            remember(&st, handle, "gift", "you gifted me \(name) on stream", mood: 2)
        }
        s = st
        return true
    }
}

struct LiveStats {
    var peak = 0, gems = 0, gain = 0, aura = 0
    var hostile = 0
}

struct OptionalProfileTap: ViewModifier {
    let handle: String
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.profileTap(handle) } else { content }
    }
}

struct LiveView: View {
    @EnvironmentObject var game: Game
    let mode: LiveMode
    var onClose: () -> Void

    @State private var chat: [LiveMsg] = []
    @State private var viewers = 0
    @State private var peak = 0
    @State private var mood = 0.45
    @State private var moodSum = 0.0
    @State private var ticks = 0
    @State private var gems = 0
    @State private var burst = 0
    @State private var input = ""
    @State private var banned = false
    @State private var ended = false
    @State private var raided = false
    @State private var hostileSpoken = 0
    @State private var rival: String? = nil
    @State private var lastSaid = ""
    @State private var stats = LiveStats()
    @State private var started = false
    @State private var confirmEnd = false
    @State private var showGifts = false
    @State private var showSend = false
    @State private var floaters: [Floater] = []
    @State private var hype = 0.0
    @State private var pulse = false
    @State private var following = false
    @State private var ticker: LiveMsg? = nil
    private let reactions: [(String, Color)] = [("flame.fill", T.orange), ("heart.fill", Color(red: 1, green: 0.4, blue: 0.55)), ("bolt.fill", T.gold), ("hands.clap.fill", T.blue), ("100.circle.fill", T.lime), ("eye.fill", Color(red: 0.7, green: 0.5, blue: 1))]
    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    private var isHost: Bool { if case .host = mode { return true }; return false }
    private var topic: String {
        switch mode {
        case .host(let t): return t
        case .watch(let h): return game.s.ex.npcLives?.first(where: { $0.handle == h })?.topic ?? lastTopic
        }
    }
    @State private var lastTopic = "Just Chatting"
    private var streamer: NPC? {
        if case .watch(let h) = mode { return game.s.npcs.first { $0.handle == h } }
        return nil
    }
    private var streamerName: String { streamer?.name ?? game.s.persona.name }
    private var streamerHandle: String { streamer?.handle ?? game.s.persona.handle }

    var body: some View {
        let st = game.s
        ZStack {
            T.bg.ignoresSafeArea()
            if ended && isHost { recap } else { liveBody(st) }
        }
        .onReceive(timer) { _ in tick() }
        .onAppear { start() }
        .alert("End stream?", isPresented: $confirmEnd) {
            Button("End", role: .destructive) { finish() }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: Screens

    private func liveBody(_ st: GameState) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                stage(st)
                chatList
                dock
            }
            ZStack(alignment: .bottomTrailing) {
                ForEach(floaters) { f in FloatingIcon(f: f) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 24).padding(.bottom, 130)
            .allowsHitTesting(false)
            if showGifts { giftPanel }
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(chat) { m in row(m).id(m.id) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .overlay(alignment: .top) {
                if let t = ticker {
                    HStack(spacing: 8) {
                        Image(systemName: t.icon ?? "gift.fill").foregroundColor(T.gold)
                        Text(t.text).font(.jk(13, .semibold)).foregroundColor(.white).lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .overlay(Capsule().stroke(T.gold.opacity(0.7), lineWidth: 1))
                    .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: chat.count) { _ in
                if let l = chat.last { withAnimation { proxy.scrollTo(l.id, anchor: .bottom) } }
            }
        }
    }

    private func stage(_ st: GameState) -> some View {
        let neon = HK.neon(streamerHandle)
        return ZStack {
            LinearGradient(colors: [neon.opacity(0.45), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Avatar(emoji: "", key: streamerHandle, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(streamerName).font(.jk(13, .bold)).lineLimit(1)
                            Text("@\(streamerHandle)").font(.jk(11)).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                        }
                    }
                    .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                    .background(Color.black.opacity(0.45)).clipShape(Capsule())
                    .profileTap(streamerHandle)
                    if !isHost {
                        Button {
                            following.toggle()
                            if following { game.liveKind(streamerHandle) }
                        } label: {
                            Text(following ? "Following" : "Follow").font(.jk(12, .bold))
                                .padding(.horizontal, 11).padding(.vertical, 7)
                                .background(following ? Color.white.opacity(0.18) : T.blue).clipShape(Capsule())
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Circle().fill(ended ? Color.gray : T.red).frame(width: 7, height: 7)
                        Text(ended ? "ENDED" : "LIVE").font(.jk(11, .heavy))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.45)).clipShape(Capsule())
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill").font(.system(size: 11))
                        Text(fmt(viewers)).font(.jk(12, .semibold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.45)).clipShape(Capsule())
                    Button { if isHost && !ended { confirmEnd = true } else { leave() } } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                            .frame(width: 30, height: 30).background(Color.black.opacity(0.45)).clipShape(Circle())
                    }
                }
                .foregroundColor(.white).padding(.horizontal, 12).padding(.top, 8)
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(neon.opacity(0.7), lineWidth: 2).frame(width: 124, height: 124)
                        .scaleEffect(pulse ? 1.45 : 1).opacity(pulse ? 0 : 0.8)
                    Circle().stroke(neon.opacity(0.5), lineWidth: 2).frame(width: 124, height: 124)
                        .scaleEffect(pulse ? 1.2 : 0.95).opacity(pulse ? 0.1 : 0.6)
                    Avatar(emoji: "", key: streamerHandle, size: 112)
                        .shadow(color: neon.opacity(0.8), radius: 16)
                }
                .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(topic).font(.jk(16, .bold)).foregroundColor(.white).lineLimit(1)
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").font(.system(size: 11)).foregroundColor(T.orange)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.18))
                                    Capsule().fill(LinearGradient(colors: [T.orange, T.gold], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(6, g.size.width * CGFloat(hype)))
                                }
                            }.frame(width: 110, height: 6)
                            Text("HYPE").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("CHAT MOOD").font(.jk(10, .bold)).foregroundColor(.white.opacity(0.7))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.2))
                                Capsule().fill(mood > 0.66 ? T.orange : (mood < 0.34 ? T.lime : T.blue))
                                    .frame(width: max(8, g.size.width * CGFloat(mood)))
                            }
                        }.frame(width: 90, height: 6)
                        Text(mood > 0.66 ? "Heated" : (mood < 0.34 ? "Wholesome" : "Mixed"))
                            .font(.jk(11, .bold)).foregroundColor(mood > 0.66 ? T.orange : .white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 10)
            }
        }
        .frame(height: 290)
    }

    private func row(_ m: LiveMsg) -> some View {
        Group {
            switch m.kind {
            case 1:
                HStack(spacing: 10) {
                    Image(systemName: m.icon ?? "gift.fill").font(.system(size: 16, weight: .bold)).foregroundColor(T.gold)
                    Text(m.text).font(.jk(13, .semibold)).foregroundColor(.white)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [T.gold.opacity(0.22), T.card2], startPoint: .leading, endPoint: .trailing))
                .overlay(Rectangle().fill(T.gold).frame(width: 3), alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            case 2:
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch").foregroundColor(.white)
                    Text(m.text).font(.jk(13, .semibold)).foregroundColor(.white)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(red: 0.36, green: 0.17, blue: 0.77), Color(red: 0.48, green: 0.27, blue: 0.91)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            case 3:
                HStack(spacing: 6) {
                    Image(systemName: m.icon ?? "info.circle.fill").font(.system(size: 11))
                    Text(m.text).font(.jk(12, .semibold))
                }
                .foregroundColor(T.sub).frame(maxWidth: .infinity, alignment: .center)
            default:
                HStack(alignment: .top, spacing: 8) {
                    if m.kind == 4 {
                        Avatar(emoji: "", key: m.handle, size: 24)
                    } else {
                        Avatar(emoji: "", key: m.handle, size: 24).profileTap(m.handle)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(m.kind == 4 ? "you" : m.handle).font(.jk(13, .bold))
                                .foregroundColor(m.kind == 4 ? T.blue : (m.kind == 5 ? T.gold : HK.neon(m.handle)))
                            if m.kind == 5 {
                                Text("HOST").font(.jk(9, .heavy)).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(T.gold).foregroundColor(.black).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .modifier(OptionalProfileTap(handle: m.handle, on: m.kind != 4))
                        Text(m.text).font(.jk(14)).foregroundColor(Color.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var dock: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(reactions.enumerated()), id: \.offset) { _, r in
                        Button { react(r.0, r.1, 3) } label: {
                            Image(systemName: r.0).font(.system(size: 17, weight: .bold)).foregroundColor(r.1)
                                .frame(width: 44, height: 38).background(T.card2).clipShape(Capsule())
                        }
                    }
                    Button { hypeBurst() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                            Text("Hype it up").font(.jk(13, .bold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 14).frame(height: 38)
                        .background(LinearGradient(colors: [T.orange, Color(red: 0.95, green: 0.3, blue: 0.35)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
            }
            HStack(spacing: 8) {
                if !isHost {
                    Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showGifts = true } } label: {
                        Image(systemName: "gift.fill").font(.system(size: 18, weight: .bold)).foregroundColor(T.gold)
                            .frame(width: 44, height: 44).background(T.card2).clipShape(Circle())
                    }.disabled(ended)
                    Button { showSend = true } label: {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: 20, weight: .bold)).foregroundColor(Color(red: 0.4, green: 0.95, blue: 0.5))
                            .frame(width: 44, height: 44).background(T.card2).clipShape(Circle())
                    }.disabled(ended)
                    .sheet(isPresented: $showSend) {
                        SendSheet(to: streamerHandle, ctx: "live", onSent: { a, v in
                            add("you", game.s.persona.handle, "donated \(Wallets.fmt(a, v))", 1, icon: "dollarsign.circle.fill")
                            spawn("dollarsign.circle.fill", T.gold, 4, size: 30)
                        }).zoomed()
                    }
                }
                TextField(banned ? "You were banned from this chat" : (isHost ? "Say something on mic..." : "Send a message..."), text: $input)
                    .font(.jk(15)).padding(.horizontal, 16).frame(height: 44)
                    .background(T.card2).clipShape(Capsule())
                    .disabled(banned || ended).submitLabel(.send).onSubmit { send() }
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(T.blue).clipShape(Circle())
                }.disabled(banned || ended)
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8).padding(.bottom, 8).background(T.bg)
    }

    private var giftPanel: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { withAnimation { showGifts = false } }
            VStack(spacing: 12) {
                HStack {
                    Text("Send a gift").font(.jk(18, .bold))
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "diamond.fill").font(.system(size: 12)).foregroundColor(T.gold)
                        Text("\(game.s.ex.gems)").font(.jk(14, .bold))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6).background(T.card2).clipShape(Capsule())
                    Button { withAnimation { showGifts = false } } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 30, height: 30).background(T.card2).clipShape(Circle())
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(LiveGift.all) { g in
                        Button { sendGift(g) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: g.symbol).font(.system(size: 26, weight: .semibold)).foregroundColor(g.color)
                                    .frame(height: 30)
                                Text(g.name).font(.jk(11, .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                                HStack(spacing: 3) {
                                    Image(systemName: "diamond.fill").font(.system(size: 9))
                                    Text("\(g.cost)").font(.jk(12, .bold))
                                }.foregroundColor(T.gold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 14))
                            .opacity(game.s.ex.gems >= g.cost ? 1 : 0.4)
                        }
                    }
                }
            }
            .padding(16).padding(.bottom, 10)
            .background(T.card.ignoresSafeArea(edges: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .transition(.move(edge: .bottom))
        }
    }

    // MARK: Reactions and gifts

    private func spawn(_ symbol: String, _ color: Color, _ n: Int, size: CGFloat = 26) {
        for i in 0..<n {
            let f = Floater(symbol: symbol, color: color, dx: CGFloat.random(in: -70...20), size: size)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09) {
                floaters.append(f)
                if floaters.count > 40 { floaters.removeFirst(floaters.count - 40) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { floaters.removeAll { $0.id == f.id } }
            }
        }
    }

    private func react(_ symbol: String, _ color: Color, _ n: Int) {
        guard !ended else { return }
        spawn(symbol, color, n)
        addHype(0.03 * Double(n))
    }

    private func hypeBurst() {
        guard !ended else { return }
        for r in reactions { spawn(r.0, r.1, 2, size: 30) }
        addHype(0.25)
        burst = max(burst, 3)
        mood = min(0.95, mood + 0.05)
    }

    private func addHype(_ v: Double) {
        withAnimation { hype = min(1, hype + v) }
        if hype >= 1 {
            withAnimation { hype = 0 }
            let bump = max(15, viewers / 6)
            viewers += bump
            peak = max(peak, viewers)
            burst = max(burst, 4)
            add("", "", "HYPE TRAIN: chat is going wild (+\(bump) viewers)", 3, icon: "flame.fill")
            spawn("flame.fill", T.orange, 10, size: 32)
        }
    }

    private func pin(_ m: LiveMsg) {
        withAnimation { ticker = m }
        let id = m.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            if ticker?.id == id { withAnimation { ticker = nil } }
        }
    }

    private func sendGift(_ g: LiveGift) {
        guard case .watch(let h) = mode, !ended else { return }
        guard game.liveGift(h, cost: g.cost, name: g.name) else { return }
        withAnimation { showGifts = false }
        let m = LiveMsg(name: "you", handle: game.s.persona.handle, text: "you sent \(g.name) (\(g.cost) gems)", kind: 1, icon: g.symbol)
        chat.append(m)
        pin(m)
        spawn(g.symbol, g.color, min(14, 3 + g.cost / 4), size: 30 + CGFloat(min(g.cost, 50)) / 4)
        addHype(min(0.6, 0.08 + Double(g.cost) * 0.02))
        mood = max(0.05, mood - 0.1)
        if let s = streamer {
            let line = game.voiceLine(game.s, s, bucket: "dm.warm", target: nil, toPlayer: true, text: "thanks for the \(g.name)", heat: 0.2)?.0 ?? "appreciate you"
            add(s.name, s.handle, "@\(game.s.persona.handle) " + line, 5)
        }
    }

    private var recap: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STREAM ENDED").font(.jk(13, .bold)).foregroundColor(T.blue)
            Text(stats.hostile > 0 ? "\(topic) went off the rails" : "\(topic) went well").font(.jk(28, .bold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                stat("Peak viewers", fmt(stats.peak), .white)
                stat("New followers", "+\(stats.gain)", T.lime)
                stat("Donations", "\(stats.gems) gems", T.gold)
                stat("Aura", stats.aura >= 0 ? "+\(stats.aura)" : "\(stats.aura)", stats.aura >= 0 ? T.lime : T.orange)
            }
            if let r = rival, let n = game.s.npcs.first(where: { $0.handle == r }) {
                HStack(spacing: 12) {
                    Avatar(emoji: n.emoji, key: n.handle, size: 40)
                    Text("\(n.name) holds a grudge now. A clip of it is on the feed.").font(.jk(14))
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
            BigButton(title: "Back to feed", action: onClose)
        }
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 12)
    }

    private func stat(_ t: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.jk(12, .semibold)).foregroundColor(T.sub)
            Text(v).font(.jk(24, .bold)).foregroundColor(c)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func fmt(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
    }

    // MARK: Engine

    private func add(_ name: String, _ handle: String, _ text: String, _ kind: Int = 0, icon: String? = nil) {
        chat.append(LiveMsg(name: name, handle: handle, text: text, kind: kind, icon: icon))
        if chat.count > 90 { chat.removeFirst(chat.count - 90) }
    }

    private func start() {
        guard !started else { return }
        started = true
        let st = game.s
        switch mode {
        case .host(let t):
            
            viewers = max(12, st.followers / 12)
            lastSaid = t
            add("", "", "You're live: \(t)", 3)
        case .watch(let h):
            guard let l = st.ex.npcLives?.first(where: { $0.handle == h }) else { onClose(); return }
            viewers = l.viewers
            lastTopic = l.topic
            lastSaid = l.topic
            add("", "", "\(streamer?.name ?? h) is live: \(l.topic)", 3)
        }
        peak = viewers
    }

    private func tick() {
        guard started, !ended else { return }
        ticks += 1
        let st = game.s
        if case .watch(let h) = mode, !(st.ex.npcLives ?? []).contains(where: { $0.handle == h && $0.ends > Date() }) {
            ended = true
            add("", "", "The stream has ended.", 3)
            return
        }
        let cast = st.npcs.filter { $0.id != "newsdesk" && $0.handle != streamerHandle }
        let drift = Double(viewers) * (mood > 0.7 ? 0.05 : (mood < 0.3 ? -0.02 : 0.01)) + Double.random(in: -4...4)
        viewers = max(3, viewers + Int(drift))
        peak = max(peak, viewers)
        moodSum += mood
        mood += (0.45 - mood) * 0.08
        if let s = streamer, ticks % 5 == 0 {
            let line = Corpus.post(trait: s.trait, me: st.persona.handle, topic: Topics.forWorld(st.world).randomElement() ?? "this")
                ?? Lines.feed[s.trait]?.randomElement() ?? "ok chat"
            add(s.name, s.handle, String(line.prefix(140)), 5)
            lastSaid = line
            if s.trait == .hater || s.trait == .chaos { mood = min(0.95, mood + 0.12) }
            if s.trait == .wholesome { mood = max(0.05, mood - 0.1) }
        }
        if Double.random(in: 0...1) < 0.7 {
            let r = mood > 0.66 ? [reactions[0], reactions[2]].randomElement()! : reactions.randomElement()!
            spawn(r.0, r.1, Int.random(in: 1...2))
        }
        hype = max(0, hype - 0.01)
        let n = burst > 0 ? 3 : Int.random(in: 1...2)
        if burst > 0 { burst -= 1 }
        for _ in 0..<n { if let sp = cast.randomElement() { chatLine(sp, st) } }
        if Double.random(in: 0...1) < 0.07, let d = cast.randomElement() {
            let amt = [5, 10, 25].randomElement() ?? 5
            let msg = mood > 0.66 ? ["answer the DM, coward", "say that again", "keep going lol"] : ["love this", "keep it up", "you're the best"]
            let gm = LiveMsg(name: "", handle: d.handle, text: "\(d.handle) donated \(amt) gems: \"\(msg.randomElement() ?? "")\"", kind: 1, icon: ["gift.fill", "heart.fill", "crown.fill", "server.rack"].randomElement())
            chat.append(gm)
            pin(gm)
            spawn(gm.icon ?? "gift.fill", T.gold, 4, size: 30)
            if isHost { gems += amt }
        }
        if !raided, ticks > 5, Double.random(in: 0...1) < 0.04,
           let r = cast.filter({ !isHost || $0.affinity >= 45 }).max(by: { $0.followers < $1.followers }) {
            raided = true
            let add = max(20, r.followers / 400)
            viewers += add
            peak = max(peak, viewers)
            self.add("", r.handle, "\(r.name) raided with \(fmt(add)) viewers", 2)
            spawn("arrow.triangle.branch", Color(red: 0.7, green: 0.5, blue: 1), 6, size: 30)
        }
        if isHost && ticks >= 45 { finish() }
    }

    private func chatLine(_ sp: NPC, _ st: GameState) {
        var tmp = st
        if let s = streamer { tmp.persona.handle = s.handle; tmp.persona.name = s.name }
        let neg = Double.random(in: 0...1) < mood
        guard let r = game.voiceLine(tmp, sp, bucket: neg ? "comment.neg" : "comment.pos", target: nil,
                                     toPlayer: isHost, text: lastSaid, heat: 0.3 + mood * 0.65, angry: mood > 0.85) else { return }
        add(sp.name, sp.handle, r.0)
    }

    private func send() {
        let t = input.trimmed
        guard !t.isEmpty, !banned, !ended else { return }
        input = ""
        let st = game.s
        add("you", st.persona.handle, t, 4)
        let angry = ContentPrefs.isHostile(t)
        if isHost {
            lastSaid = t
            let cast = st.npcs.filter { $0.id != "newsdesk" }
            if angry {
                mood = 0.95; burst = 5; hostileSpoken += 1
                if let sp = cast.randomElement() {
                    if rival == nil { rival = sp.handle }
                    if let r = game.voiceLine(st, sp, bucket: "comment.neg", target: nil, toPlayer: true, text: t, heat: 0.95, angry: true) {
                        add(sp.name, sp.handle, "@\(st.persona.handle) " + r.0)
                    }
                }
            } else {
                mood = max(0.05, mood - 0.2); burst = 1
            }
        } else if let s = streamer {
            if angry {
                mood = 0.95; burst = 4
                game.liveInsult(s.handle)
                if let r = game.voiceLine(st, s, bucket: "comment.neg", target: nil, toPlayer: true, text: t, heat: 0.95, angry: true) {
                    add(s.name, s.handle, "@\(st.persona.handle) " + r.0, 5)
                }
                if Double.random(in: 0...1) < 0.5 {
                    banned = true
                    add("", "", "\(s.name) banned you from chat", 3)
                }
            } else {
                mood = max(0.05, mood - 0.15)
                game.liveKind(s.handle)
                if Double.random(in: 0...1) < 0.5,
                   let r = game.voiceLine(st, s, bucket: "dm.warm", target: nil, toPlayer: true, text: t, heat: 0.3) {
                    add(s.name, s.handle, "@\(st.persona.handle) " + r.0, 5)
                }
            }
        }
    }

    private func finish() {
        guard !ended else { return }
        ended = true
        let st = game.s
        let avg = ticks > 0 ? moodSum / Double(ticks) : 0.45
        let gain = max(1, min(Int(Double(peak) * 0.12), max(5, st.followers / 20)))
        let aura = max(-5, min(4, Int(((0.45 - avg) * 10).rounded()) + (gems > 0 ? 1 : 0)))
        stats = LiveStats(peak: peak, gems: gems, gain: gain, aura: aura, hostile: hostileSpoken)
        if case .host(let t) = mode { game.finishLive(topic: t, peak: peak, gems: gems, gain: gain, aura: aura, rival: rival) }
    }

    private func leave() {
        if isHost && !ended { finish() }
        onClose()
    }
}

// MARK: - A character's story

struct NPCStoryViewer: View {
    @EnvironmentObject var game: Game
    let storyID: UUID
    var onClose: () -> Void
    @State private var progress: CGFloat = 0
    @State private var input = ""
    @State private var reply: String? = nil
    @State private var closed = false
    @State private var floaters: [Floater] = []
    @State private var reacted: String? = nil
    @State private var tipOpen = false
    @FocusState private var typing: Bool
    private let reactions: [(String, Color)] = [("flame.fill", T.orange), ("heart.fill", Color(red: 1, green: 0.4, blue: 0.55)), ("bolt.fill", T.gold), ("hands.clap.fill", T.blue), ("100.circle.fill", T.lime), ("eye.fill", Color(red: 0.7, green: 0.5, blue: 1))]

    var body: some View {
        let st = game.s
        let story = (st.ex.npcStories ?? []).first { $0.id == storyID }
        let npc = story.flatMap { s in st.npcs.first { $0.handle == s.handle } }
        ZStack {
            if let story = story, let npc = npc {
                let neon = HK.neon(npc.handle)
                StoryStyle.gradient(story.bg).ignoresSafeArea()
                LinearGradient(colors: [Color.black.opacity(0.45), Color.clear, Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                Canvas { ctx, sz in
                    var p = Path()
                    var x: CGFloat = 0
                    while x < sz.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: sz.height)); x += 36 }
                    var y: CGFloat = 0
                    while y < sz.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: sz.width, y: y)); y += 36 }
                    ctx.stroke(p, with: .color(.white.opacity(0.05)), lineWidth: 0.6)
                }.ignoresSafeArea().allowsHitTesting(false)
                VStack(spacing: 10) {
                    Image(systemName: "quote.opening").font(.system(size: 22, weight: .bold)).foregroundColor(neon)
                    Text(story.text).font(.jk(28, .bold)).foregroundColor(.white).multilineTextAlignment(.center)
                    HStack(spacing: 6) {
                        Image(systemName: HK.glyph(npc.handle)).font(.system(size: 11, weight: .bold))
                        Text("@\(npc.handle)").font(.jk(12, .semibold))
                    }.foregroundColor(neon)
                }
                .padding(.horizontal, 22).padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.42)))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(neon.opacity(0.55), lineWidth: 1.2))
                .padding(.horizontal, 24)
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { progress = 0; restart() }
                    Color.clear.contentShape(Rectangle()).onTapGesture { if !closed { closed = true; onClose() } }
                }
                .padding(.top, 110).padding(.bottom, 170)
                VStack(spacing: 12) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.28))
                            Capsule().fill(Color.white.opacity(0.95)).frame(width: g.size.width * progress)
                        }
                    }.frame(height: 4)
                    HStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Avatar(emoji: npc.emoji, key: npc.handle, size: 42, ring: false)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(npc.name).font(.jk(15, .bold)).foregroundColor(.white)
                                    if npc.followers >= 40000 { VerifiedSeal(size: 12) }
                                }
                                Text(agoString(story.date)).font(.jk(12)).foregroundColor(.white.opacity(0.75))
                            }
                        }
                        .profileTap(npc.handle)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(Color.black.opacity(0.4)).clipShape(Circle())
                        }
                    }
                    Spacer()
                    if let r = reply {
                        HStack(alignment: .top, spacing: 8) {
                            Avatar(emoji: npc.emoji, key: npc.handle, size: 26)
                            Text(r).font(.jk(14)).foregroundColor(.white)
                            Spacer(minLength: 0)
                        }
                        .padding(10).background(Color.black.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    HStack(spacing: 8) {
                        Button { tipOpen = true } label: {
                            Image(systemName: "dollarsign.circle.fill").font(.system(size: 20, weight: .bold)).foregroundColor(Color(red: 0.4, green: 0.95, blue: 0.5))
                                .frame(width: 46, height: 40).background(Color.black.opacity(0.38)).clipShape(Capsule())
                        }
                        .sheet(isPresented: $tipOpen) { SendSheet(to: npc.handle, ctx: "story").zoomed() }
                        ForEach(Array(reactions.enumerated()), id: \.offset) { _, r in
                            Button { react(r.0, r.1, npc) } label: {
                                Image(systemName: r.0).font(.system(size: 18, weight: .bold)).foregroundColor(r.1)
                                    .frame(maxWidth: .infinity).frame(height: 40)
                                    .background(Color.black.opacity(reacted == r.0 ? 0.65 : 0.38)).clipShape(Capsule())
                                    .overlay(Capsule().stroke(reacted == r.0 ? r.1 : Color.clear, lineWidth: 1.5))
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Reply to \(npc.name.components(separatedBy: " ").first ?? npc.name)...", text: $input)
                            .font(.jk(15)).padding(.horizontal, 16).frame(height: 46)
                            .background(Color.black.opacity(0.45)).clipShape(Capsule()).foregroundColor(.white)
                            .focused($typing).submitLabel(.send).onSubmit { send(npc) }
                        Button { send(npc) } label: {
                            Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                .frame(width: 46, height: 46).background(T.blue).clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
                ZStack(alignment: .bottomTrailing) {
                    ForEach(floaters) { f in FloatingIcon(f: f) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 40).padding(.bottom, 120).allowsHitTesting(false)
            } else {
                VStack(spacing: 16) {
                    Text("This story is gone.").font(.jk(18, .semibold))
                    BigButton(title: "Close", action: onClose).padding(.horizontal, 60)
                }
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear {
            game.markStorySeen(storyID)
            restart()
        }
    }

    private func restart() {
        progress = 0
        withAnimation(.linear(duration: 12)) { progress = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.2) {
            if reply == nil && input.isEmpty && !typing && !closed && reacted == nil { closed = true; onClose() }
        }
    }

    private func react(_ symbol: String, _ color: Color, _ n: NPC) {
        reacted = symbol
        game.liveKind(n.handle)
        for i in 0..<7 {
            let f = Floater(symbol: symbol, color: color, dx: CGFloat.random(in: -80...30), size: 28)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                floaters.append(f)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { floaters.removeAll { $0.id == f.id } }
            }
        }
    }

    private func send(_ n: NPC) {
        let t = input.trimmed
        guard !t.isEmpty else { return }
        input = ""
        reply = game.storyReply(n.handle, text: t)
    }
}
