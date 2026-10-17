import SwiftUI

// MARK: - Character memory: relationships, grudges, reputation

enum MemLines {
    static let dmNeg = [
        "i haven't forgotten that {t}.",
        "not over the fact that {t}. just saying.",
        "we need to talk. {t}.",
        "ngl still thinking about how {t}.",
        "don't act like {t} didn't happen."
    ]
    static let dmPos = [
        "i still think about how {t} 🥹",
        "you're one of the good ones. {t}. i don't forget that.",
        "random but {t} and i appreciate it.",
        "just wanted to say thanks. {t}.",
        "hey you. {t}. i haven't forgotten."
    ]
    static let postNeg = [
        "{me} i haven't forgotten that {t}. the timeline should know.",
        "reminder that {t}. {me}, we're not done.",
        "some people think everything gets forgotten. {t}. i remember, {me}.",
        "not naming names but {me} knows {t}. 🙄",
        "still not over it. {t}. {me} you know what you did."
    ]
    static let postPos = [
        "real ones remember: {t}. shoutout {me} 🫶",
        "{me} {t}. never forgetting that.",
        "{t}, and that's exactly why {me} is the one to watch.",
        "gonna say it publicly: {t}. thank you {me} 💛",
        "{me} is a real one. {t}. that's it, that's the post."
    ]

    static func fill(_ tpl: String, _ m: Memory, me: String) -> String {
        tpl.replacingOccurrences(of: "{t}", with: m.text).replacingOccurrences(of: "{me}", with: "@" + me)
    }
    static func dm(_ m: Memory, positive: Bool) -> String {
        fill((positive ? dmPos : dmNeg).randomElement() ?? "hey", m, me: "")
    }
    static func post(_ m: Memory, positive: Bool, me: String) -> String {
        fill((positive ? postPos : postNeg).randomElement() ?? "hm", m, me: me)
    }
}

extension Game {
    // MARK: Writing memories

    func remember(_ st: inout GameState, _ handle: String, _ kind: String, _ text: String,
                  mood: Int, ref: UUID? = nil) {
        guard handle != st.persona.handle,
              let j = st.npcs.firstIndex(where: { $0.handle == handle && $0.id != "newsdesk" }) else { return }
        var m = st.ex.memories ?? []
        if let r = ref, m.contains(where: { $0.handle == handle && $0.kind == kind && $0.ref == r }) { return }
        if ref == nil, m.contains(where: { $0.handle == handle && $0.kind == kind && $0.day == st.day }) { return }
        m.insert(Memory(handle: handle, kind: kind, text: text, mood: mood, day: st.day, ref: ref), at: 0)
        var count = 0
        m = m.filter { x in
            if x.handle == handle { count += 1; return count <= 12 }
            return true
        }
        if m.count > 160 { m.removeLast(m.count - 160) }
        st.ex.memories = m
        st.npcs[j].affinity = min(100, max(0, st.npcs[j].affinity + mood * 3))
    }

    /// How a character currently feels about you (older memories fade).
    func feeling(_ st: GameState, _ handle: String) -> Int {
        var total = 0.0
        for m in (st.ex.memories ?? []) where m.handle == handle {
            let age = max(0, st.day - m.day)
            let w = age <= 3 ? 1.0 : (age <= 10 ? 0.6 : 0.3)
            total += Double(m.mood) * w
        }
        return Int(total.rounded())
    }

    func feelingLabel(_ f: Int) -> (String, Color) {
        switch f {
        case 4...: return ("Devoted", T.lime)
        case 2...3: return ("Fond of you", T.lime)
        case -1...1: return ("Neutral", T.sub)
        case -3 ... -2: return ("Holding a grudge", T.orange)
        default: return ("Wants you cancelled", T.red)
        }
    }

    func strongestMemory(_ st: GameState, _ handle: String, positive: Bool) -> Memory? {
        (st.ex.memories ?? [])
            .filter { $0.handle == handle && (positive ? $0.mood > 0 : $0.mood < 0) && ($0.aired ?? 0) < 2 }
            .max { abs($0.mood) < abs($1.mood) }
    }

    func markAired(_ st: inout GameState, _ id: UUID) {
        var m = st.ex.memories ?? []
        if let i = m.firstIndex(where: { $0.id == id }) { m[i].aired = (m[i].aired ?? 0) + 1 }
        st.ex.memories = m
    }

    static func briefFor(_ st: GameState, _ handle: String) -> String {
        let ms = (st.ex.memories ?? []).filter { $0.handle == handle }.prefix(4)
        guard !ms.isEmpty else { return "" }
        var tot = 0
        for m in ms { tot += m.mood }
        let f = tot
        return "History with the player (you remember this and may bring it up naturally): "
            + ms.map { $0.text }.joined(separator: "; ") + ". Overall you feel " + (f > 1 ? "warm" : (f < -1 ? "resentful" : "mixed")) + " toward them."
    }

    // MARK: Hooks from the player's actions

    func rememberPost(_ st: inout GameState, post: Post, comments: [Comment], delta: Int, kind: PostKind, text: String) {
        let snip = String(text.prefix(36))
        for c in comments {
            guard let n = st.npcs.first(where: { $0.handle == c.handle }) else { continue }
            if delta <= -3 {
                if n.trait == .wholesome { remember(&st, n.handle, "worried", "your post \"\(snip)\" worried me", mood: -1, ref: post.id) }
                else { remember(&st, n.handle, "cringe", "your post \"\(snip)\" was embarrassing", mood: -1, ref: post.id) }
            } else if delta >= 3 {
                if n.trait == .hater { remember(&st, n.handle, "salty", "your post \"\(snip)\" stole the spotlight", mood: -1, ref: post.id) }
                else { remember(&st, n.handle, "hyped", "your post \"\(snip)\" was fire", mood: 1, ref: post.id) }
            }
        }
        if kind == .apology {
            for n in st.npcs where n.id != "newsdesk" && feeling(st, n.handle) <= -1 {
                remember(&st, n.handle, "apology", "you publicly apologised", mood: 3)
            }
        }
    }

    func rememberReply(_ st: inout GameState, post: Post, text: String) {
        guard !post.isYou, let a = st.npcs.first(where: { $0.handle == post.authorHandle && $0.id != "newsdesk" }) else { return }
        if post.tag == "Drama" {
            let b = st.npcs.first { $0.handle != a.handle && $0.id != "newsdesk" && post.text.contains("@" + $0.handle) }
            if let b = b {
                remember(&st, a.handle, "sided", "you backed me in my fight with @\(b.handle)", mood: 2)
                remember(&st, b.handle, "betrayed", "you took @\(a.handle)'s side against me", mood: -2)
                return
            }
        }
        remember(&st, a.handle, "engaged", "you replied to my post \"\(String(post.text.prefix(30)))\"", mood: 1, ref: post.id)
    }

    /// Characters who commented on your posts and never got an answer.
    func checkIgnored(_ st: inout GameState) {
        let me = st.persona.handle
        for p in st.posts.prefix(14) where p.isYou {
            if p.comments.contains(where: { $0.handle == me }) { continue }
            for c in p.comments.prefix(2) {
                remember(&st, c.handle, "ignored", "you never answered my comment on \"\(String(p.text.prefix(30)))\"", mood: -1, ref: p.id)
            }
        }
    }

    // MARK: Reputation and virality

    func viralBoost(_ st: GameState, _ text: String) -> Double {
        var b = 0.0
        let allies = st.npcs.filter { $0.id != "newsdesk" && $0.followsYou && $0.affinity >= 60 }.count
        b += min(0.06, Double(allies) * 0.012)
        let enemies = st.npcs.filter { $0.id != "newsdesk" && feeling(st, $0.handle) <= -2 }.count
        b -= min(0.03, Double(enemies) * 0.01)
        if let hot = st.ex.hot, !hot.isEmpty {
            let key = hot.split(separator: " ").first.map(String.init) ?? hot
            if text.lowercased().contains(key.lowercased()) { b += 0.08 }
        }
        if (st.ex.spotlight ?? 0) > 0 { b += 0.03 }
        b += Double(st.aura - 50) / 1000
        return max(-0.05, b)
    }

    func goViral(_ st: inout GameState, _ p: Post) {
        let snip = String(p.text.prefix(60))
        addHistory(&st, "🔥", "A post by \(st.persona.name) went viral", snip)
        st.ex.spotlight = 6
        st.ex.spotGain = (st.ex.spotGain ?? 0) + max(5, Int(Double(p.likes) * 0.06))
        st.ex.fame = (st.ex.fame ?? 0) + 1
        for n in st.npcs where n.id != "newsdesk" {
            if n.trait == .hater || n.trait == .gossip {
                remember(&st, n.handle, "jealous", "your post \"\(String(snip.prefix(30)))\" went viral and now you think you're untouchable", mood: -1)
            } else if n.affinity >= 40 {
                remember(&st, n.handle, "viral_fan", "your post \"\(String(snip.prefix(30)))\" blew up and I was there for it", mood: 1)
            }
        }
        if let news = st.npcs.first(where: { $0.id == "newsdesk" }) {
            var np = makePost(news, "TRENDING: \(st.persona.name) just broke the timeline with \"\(String(snip.prefix(50)))\". Everyone is talking.", st)
            np.tag = "Trending"
            np.likes = max(np.likes, p.likes / 2)
            st.posts.insert(np, at: 0)
        }
        notify(&st, "event", "You're going viral", sub: "The spotlight is on you. Expect attention, good and bad.", emoji: "🔥")
    }

    // MARK: Sim events driven by memory

    func simMemoryPost(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) -> Bool {
        let cands = cast.map { ($0, feeling(st, $0.handle)) }.filter { abs($0.1) >= 2 }
        guard let (n, f) = cands.randomElement(), let m = strongestMemory(st, n.handle, positive: f > 0) else { return false }
        let pos = f > 0
        let text = MemLines.post(m, positive: pos, me: st.persona.handle)
        var p = makePost(n, text, st)
        p.tag = pos ? "Shoutout" : "Callout"
        p.day = st.day
        p.likes = max(p.likes * 2, 50)
        p.comments = makeComments(st, auraDelta: pos ? 3 : -3, count: Int.random(in: 3...6), exclude: n.handle, text: text)
        st.posts.insert(p, at: 0)
        let d = pos ? Int.random(in: 1...3) : -Int.random(in: 1...3)
        st.aura += d
        st.lastAuraDelta = d
        if pos { st.followers += max(1, st.followers / 80) } else { st.followers = max(10, st.followers - max(1, st.followers / 100)) }
        markAired(&st, m.id)
        _ = settleAura(&st)
        if quiet {
            notify(&st, "event", pos ? "\(n.name) gave you a shoutout" : "\(n.name) called you out", sub: String(text.prefix(90)), handle: n.handle, emoji: pos ? "🫶" : "🗣️")
        } else {
            items.append(DigestItem(emoji: pos ? "🫶" : "🗣️",
                                    title: pos ? "\(n.name) gave you a shoutout" : "\(n.name) called you out",
                                    detail: "They remembered that \(m.text) (aura \(d >= 0 ? "+" : "")\(d)%)", postID: p.id))
        }
        if abs(f) >= 4 {
            addHistory(&st, pos ? "🫶" : "🗣️", pos ? "\(n.name) publicly stood by \(st.persona.name)" : "\(n.name) turned on \(st.persona.name)",
                       "They remembered that \(m.text).")
        }
        return true
    }

    func simMemoryDM(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) -> Bool {
        let cands = cast.filter { n in
            let f = feeling(st, n.handle)
            guard abs(f) >= 2 else { return false }
            if let last = st.threads[n.handle]?.last, !last.fromYou { return false }
            return true
        }
        guard let n = cands.randomElement() else { return false }
        let pos = feeling(st, n.handle) > 0
        guard let m = strongestMemory(st, n.handle, positive: pos) else { return false }
        let msg = MemLines.dm(m, positive: pos)
        st.threads[n.handle, default: []].append(DMMessage(fromYou: false, text: msg))
        st.unread.insert(n.handle)
        markAired(&st, m.id)
        notify(&st, "reply", "\(n.name) messaged you", sub: "\(n.handle): \(msg)", handle: n.handle, emoji: n.emoji)
        if !quiet {
            items.append(DigestItem(emoji: "💬", title: "\(n.name) messaged you", detail: String(msg.prefix(90))))
        }
        return true
    }

    func simScrutiny(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        let pool = cast.filter { $0.trait == .hater || $0.trait == .gossip || $0.trait == .chaos }
        guard let n = pool.randomElement() else { return }
        let me = st.persona.handle
        let t = ["is anyone else tired of hearing about @\(me)? the timeline is NOT that deep.",
                 "everyone acting like @\(me) invented posting. relax.",
                 "@\(me) is only famous because the algorithm picked them. discuss.",
                 "going viral once doesn't make you interesting, @\(me).",
                 "watching @\(me) get too much attention is my villain origin story."].randomElement() ?? "hm"
        var p = makePost(n, t, st)
        p.tag = "Backlash"
        p.day = st.day
        p.likes = max(p.likes * 2, 60)
        p.comments = makeComments(st, auraDelta: -2, count: Int.random(in: 3...6), exclude: n.handle, text: t)
        st.posts.insert(p, at: 0)
        let d = -Int.random(in: 1...3)
        st.aura += d
        st.lastAuraDelta = d
        _ = settleAura(&st)
        if quiet {
            notify(&st, "event", "Backlash from \(n.name)", sub: String(t.prefix(90)), handle: n.handle, emoji: "🌪️")
        } else {
            items.append(DigestItem(emoji: "🌪️", title: "Backlash after going viral",
                                    detail: "\(n.name) turned on you (aura \(d)%)", postID: p.id))
        }
    }

    func simOffer(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard let n = cast.first(where: { $0.trait == .mogul }) ?? cast.randomElement() else { return }
        if let last = st.threads[n.handle]?.last, !last.fromYou { return }
        let msg = ["saw that post blow up. let's talk deal.", "your numbers are insane right now. call me.",
                   "everyone's watching you. want to turn that into something?"].randomElement() ?? "call me"
        st.threads[n.handle, default: []].append(DMMessage(fromYou: false, text: msg))
        st.unread.insert(n.handle)
        st.ex.gems += 2
        st.followers += max(1, st.followers / 50)
        notify(&st, "reply", "\(n.name) wants to work with you", sub: "\(n.handle): \(msg)", handle: n.handle, emoji: n.emoji)
        remember(&st, n.handle, "offer", "you were the talk of the timeline", mood: 1)
        if !quiet { items.append(DigestItem(emoji: "💼", title: "\(n.name) made you an offer", detail: "+2 gems, new followers. Check your DMs.")) }
    }

    func fadeHype(_ st: inout GameState, _ items: inout [DigestItem], _ quiet: Bool) {
        let churn = max(0, (st.ex.spotGain ?? 0) / 4)
        st.ex.spotGain = nil
        guard churn > 0 else { return }
        st.followers = max(10, st.followers - churn)
        addHistory(&st, "📉", "The hype around \(st.persona.name) cooled", "Casual followers from the viral moment drifted away.")
        if quiet {
            notify(&st, "event", "The hype faded", sub: "-\(short(churn)) followers who only came for the viral moment", emoji: "📉")
        } else {
            items.append(DigestItem(emoji: "📉", title: "The viral hype faded", detail: "-\(short(churn)) followers who only came for the moment"))
        }
    }
}

// MARK: - What a character remembers (NPC sheet)

struct MemoryBlock: View {
    @EnvironmentObject var game: Game
    let handle: String

    var body: some View {
        let st = game.s
        let f = game.feeling(st, handle)
        let lab = game.feelingLabel(f)
        let ms = (st.ex.memories ?? []).filter { $0.handle == handle }.prefix(3)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("They remember").font(.system(size: 12)).foregroundColor(T.sub)
                Spacer()
                Text(lab.0).font(.system(size: 12, weight: .semibold)).foregroundColor(lab.1)
            }
            if ms.isEmpty {
                Text("Nothing yet. Post, reply and message them and they'll start to remember.")
                    .font(.system(size: 13)).foregroundColor(T.sub)
            }
            ForEach(Array(ms)) { m in
                HStack(alignment: .top, spacing: 6) {
                    Text(m.mood >= 0 ? "💛" : "💢").font(.system(size: 12))
                    Text(m.text.prefix(1).uppercased() + m.text.dropFirst())
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.padding(.horizontal, 28)
    }
}
