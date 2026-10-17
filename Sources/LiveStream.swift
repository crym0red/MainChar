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
        while (st.ex.npcStories ?? []).count < 3 && tries < 8 { simStory(&st, &items, cast, true); tries += 1 }
        if (st.ex.npcLives ?? []).isEmpty, Double.random(in: 0...1) < 0.6 { simGoLive(&st, &items, cast, true) }
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
}

struct LiveStats {
    var peak = 0, gems = 0, gain = 0, aura = 0
    var hostile = 0
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
        VStack(spacing: 0) {
            stage(st)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        ForEach(chat) { m in row(m).id(m.id) }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .onChange(of: chat.count) { _ in
                    if let l = chat.last { withAnimation { proxy.scrollTo(l.id, anchor: .bottom) } }
                }
            }
            inputBar
        }
    }

    private func stage(_ st: GameState) -> some View {
        ZStack(alignment: .bottom) {
            StoryStyle.gradient(abs(streamerHandle.hashValue) % 6)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(ended ? "ENDED" : "LIVE").font(.jk(12, .bold))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(ended ? Color.gray : T.red).clipShape(RoundedRectangle(cornerRadius: 6))
                    HStack(spacing: 5) {
                        Image(systemName: "eye").font(.system(size: 12, weight: .semibold))
                        Text(fmt(viewers)).font(.jk(12, .semibold))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Button { if isHost && !ended { confirmEnd = true } else { leave() } } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34).background(Color.black.opacity(0.4)).clipShape(Circle())
                    }
                }
                .foregroundColor(.white).padding(.horizontal, 16).padding(.top, 10)
                Spacer()
                Avatar(emoji: streamer?.emoji ?? st.persona.emoji, key: streamerHandle, size: 104)
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 3))
                Spacer()
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic).font(.jk(17, .bold)).foregroundColor(.white)
                    Text("@\(streamerHandle)").font(.jk(12)).foregroundColor(.white.opacity(0.75))
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
                    }.frame(width: 96, height: 8)
                    Text(mood > 0.66 ? "Heated" : (mood < 0.34 ? "Wholesome" : "Mixed"))
                        .font(.jk(11, .bold)).foregroundColor(mood > 0.66 ? T.orange : .white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .frame(height: 270)
    }

    private func row(_ m: LiveMsg) -> some View {
        Group {
            switch m.kind {
            case 1:
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundColor(T.gold)
                    Text(m.text).font(.jk(13)).foregroundColor(.white)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(T.card2).overlay(Rectangle().fill(T.gold).frame(width: 3), alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            case 2:
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right").foregroundColor(.white)
                    Text(m.text).font(.jk(13, .semibold)).foregroundColor(.white)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(red: 0.36, green: 0.17, blue: 0.77), Color(red: 0.48, green: 0.27, blue: 0.91)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            case 3:
                Text(m.text).font(.jk(12, .semibold)).foregroundColor(T.sub).frame(maxWidth: .infinity, alignment: .center)
            default:
                (Text(m.kind == 4 ? "you " : m.handle + " ").font(.jk(14, .bold))
                    .foregroundColor(m.kind == 4 ? T.blue : (m.kind == 5 ? T.gold : letterColor(m.handle)))
                 + Text(m.text).font(.jk(14)).foregroundColor(Color.white.opacity(0.9)))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(banned ? "You were banned from this chat" : (isHost ? "Say something on mic..." : "Send a message..."), text: $input)
                .font(.jk(15)).padding(.horizontal, 16).frame(height: 44)
                .background(T.card2).clipShape(Capsule())
                .disabled(banned || ended).submitLabel(.send).onSubmit { send() }
            Button { send() } label: {
                Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    .frame(width: 44, height: 44).background(T.blue).clipShape(Circle())
            }.disabled(banned || ended)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(T.bg)
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

    private func add(_ name: String, _ handle: String, _ text: String, _ kind: Int = 0) {
        chat.append(LiveMsg(name: name, handle: handle, text: text, kind: kind))
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
        let n = burst > 0 ? 3 : Int.random(in: 1...2)
        if burst > 0 { burst -= 1 }
        for _ in 0..<n { if let sp = cast.randomElement() { chatLine(sp, st) } }
        if Double.random(in: 0...1) < 0.07, let d = cast.randomElement() {
            let amt = [5, 10, 25].randomElement() ?? 5
            let msg = mood > 0.66 ? ["answer the DM, coward", "say that again", "keep going lol"] : ["love this", "keep it up", "you're the best"]
            add("", d.handle, "\(d.handle) donated \(amt) gems: \"\(msg.randomElement() ?? "")\"", 1)
            if isHost { gems += amt }
        }
        if !raided, ticks > 5, Double.random(in: 0...1) < 0.04,
           let r = cast.filter({ !isHost || $0.affinity >= 45 }).max(by: { $0.followers < $1.followers }) {
            raided = true
            let add = max(20, r.followers / 400)
            viewers += add
            peak = max(peak, viewers)
            self.add("", r.handle, "\(r.name) raided with \(fmt(add)) viewers", 2)
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

    var body: some View {
        let st = game.s
        let story = (st.ex.npcStories ?? []).first { $0.id == storyID }
        let npc = story.flatMap { s in st.npcs.first { $0.handle == s.handle } }
        ZStack {
            if let story = story, let npc = npc {
                StoryStyle.gradient(story.bg).ignoresSafeArea()
                Color.black.opacity(0.2).ignoresSafeArea()
                Text(story.text).font(.jk(30, .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center).padding(.horizontal, 28)
                    .shadow(color: .black.opacity(0.35), radius: 4)
                VStack(spacing: 14) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.28))
                            Capsule().fill(Color.white.opacity(0.9)).frame(width: g.size.width * progress)
                        }
                    }.frame(height: 5)
                    HStack(spacing: 10) {
                        Avatar(emoji: npc.emoji, key: npc.handle, size: 48)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(npc.name).font(.jk(16, .bold)).foregroundColor(.white)
                            Text(agoString(story.date)).font(.jk(12)).foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(width: 38, height: 38).background(Color.black.opacity(0.35)).clipShape(Circle())
                        }
                    }
                    Spacer()
                    if let r = reply {
                        Text(r).font(.jk(15)).foregroundColor(.white).padding(12)
                            .background(Color.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 8) {
                        TextField("Reply to \(npc.name.components(separatedBy: " ").first ?? npc.name)...", text: $input)
                            .font(.jk(15)).padding(.horizontal, 16).frame(height: 46)
                            .background(Color.black.opacity(0.4)).clipShape(Capsule()).foregroundColor(.white)
                            .submitLabel(.send).onSubmit { send(npc) }
                        Button { send(npc) } label: {
                            Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                .frame(width: 46, height: 46).background(T.blue).clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
            } else {
                VStack(spacing: 16) {
                    Text("This story is gone.").font(.jk(18, .semibold))
                    BigButton(title: "Close", action: onClose).padding(.horizontal, 60)
                }
            }
        }
        .onAppear {
            game.markStorySeen(storyID)
            withAnimation(.linear(duration: 12)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { if reply == nil && input.isEmpty && !closed { closed = true; onClose() } }
        }
    }

    private func send(_ n: NPC) {
        let t = input.trimmed
        guard !t.isEmpty else { return }
        input = ""
        reply = game.storyReply(n.handle, text: t)
    }
}
