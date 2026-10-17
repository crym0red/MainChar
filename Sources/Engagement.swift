import SwiftUI

enum Themes {
    static let all: [(name: String, hue: Double, level: Int)] = [
        ("Neon Blue", 0.58, 1), ("Violet", 0.75, 5), ("Mint", 0.42, 10), ("Ember", 0.07, 15),
        ("Rose", 0.93, 25), ("Gold", 0.13, 40), ("Ice", 0.5, 60), ("Void", 0.0, 100)
    ]
    static func color(_ i: Int) -> Color {
        let k = min(max(i, 0), all.count - 1)
        if k == 7 { return Color(white: 0.85) }
        return Color(hue: all[k].hue, saturation: 0.75, brightness: 1)
    }
}

extension Game {
    static let reactionList: [(String, String)] = [("flame.fill", "fire"), ("heart.fill", "love"), ("bolt.slash.fill", "dead"),
                                                   ("theatermasks.fill", "clown"), ("100.circle.fill", "facts")]

    // MARK: Post decoration (polls, media, quotes)

    func decorate(_ p: inout Post, author: NPC, st: GameState) {
        let scene = CastGen.isScene(st.world)
        let r = Double.random(in: 0...1)
        let hue = Double(HK.h(author.handle) % 360) / 360
        if r < 0.07 {
            let bank: [(String, [String])] = scene
                ? [("Which signer actually survives revokes?", ["On-device", "Server-side", "Neither"]),
                   ("Next big jailbreak drop?", ["This week", "Never", "Already leaked"]),
                   ("Best sideload store right now?", ["Mine", "Yours", "They all log"])]
                : [("Is clout worth the drama?", ["Yes", "No", "Depends"]),
                   ("Who is winning this week?", ["Me", "You", "Nobody"]),
                   ("Hot take or cold take?", ["Hot", "Cold", "Lukewarm"])]
            if let b = bank.randomElement() {
                p.poll = Poll(q: b.0, opts: b.1, votes: b.1.map { _ in Int.random(in: 5...400) })
            }
        } else if r < 0.20 {
            if scene {
                let kinds: [Media] = [
                    Media(kind: "code", title: "patch.diff", lines: ["- if (revoked) crash();", "+ if (revoked) resign();", "  return ok;"], hue: hue),
                    Media(kind: "leak", title: "Leaked build", lines: ["v2.4.0-beta", "cert: expires in 2 days", "status: spreading"], hue: hue),
                    Media(kind: "stats", title: "Installs this week", lines: ["12,408 installs", "+312% vs last week", "0 revokes"], hue: hue)
                ]
                p.media = kinds.randomElement()
            } else {
                p.media = Media(kind: "stats", title: "This week", lines: ["+\(Int.random(in: 20...900))% reach", "\(Int.random(in: 1...90))K views", "trending"], hue: hue)
            }
        } else if r < 0.27,
                  let q = st.posts.filter({ $0.authorHandle != author.handle && $0.quote == nil }).randomElement() {
            p.quote = Quote(handle: q.authorHandle, name: q.authorName, text: String(q.text.prefix(120)))
        }
    }

    // MARK: Reactions, reposts, votes, quotes

    func react(_ id: UUID, _ key: String) {
        var st = s
        guard let i = st.posts.firstIndex(where: { $0.id == id }) else { return }
        var r = st.posts[i].reacts ?? [:]
        if let old = st.posts[i].myReact {
            let c = max(0, (r[old] ?? 1) - 1)
            r[old] = c == 0 ? nil : c
        }
        if st.posts[i].myReact == key {
            st.posts[i].myReact = nil
        } else {
            st.posts[i].myReact = key
            r[key, default: 0] += 1
            bump(&st, "react")
            if let j = st.npcs.firstIndex(where: { $0.handle == st.posts[i].authorHandle }) {
                let d = key == "clown" ? -2 : (key == "dead" ? -1 : 1)
                st.npcs[j].affinity = clampI(st.npcs[j].affinity + d, 0, 100)
            }
        }
        st.posts[i].reacts = r.isEmpty ? nil : r
        s = st
    }

    func repost(_ id: UUID) {
        var st = s
        guard let i = st.posts.firstIndex(where: { $0.id == id }) else { return }
        st.posts[i].reposts += 1
        bump(&st, "react")
        if let j = st.npcs.firstIndex(where: { $0.handle == st.posts[i].authorHandle }) {
            st.npcs[j].affinity = clampI(st.npcs[j].affinity + 1, 0, 100)
        }
        s = st
        showToast("Reposted")
    }

    func vote(_ id: UUID, _ opt: Int) {
        var st = s
        guard let i = st.posts.firstIndex(where: { $0.id == id }), var p = st.posts[i].poll,
              p.mine == nil, p.votes.indices.contains(opt) else { return }
        p.votes[opt] += 1
        p.mine = opt
        st.posts[i].poll = p
        gainXP(&st, 3)
        s = st
    }

    func quotePost(_ id: UUID, text: String) {
        var st = s
        let t = text.trimmed
        guard !t.isEmpty, let src = st.posts.first(where: { $0.id == id }) else { return }
        let hostile = ContentPrefs.isHostile(t)
        var comments = makeComments(st, auraDelta: hostile ? -3 : 1, count: Int.random(in: 2...4), text: t, angry: hostile)
        let base = max(10, st.followers / 20)
        var p = Post(authorHandle: st.persona.handle, authorName: st.persona.name, emoji: st.persona.emoji, text: t,
                     likes: Int.random(in: base / 2...base * 2), reposts: 2, comments: comments, day: st.day, isYou: true,
                     verified: st.followers >= 10000, tag: "Quote")
        p.quote = Quote(handle: src.authorHandle, name: src.authorName, text: String(src.text.prefix(120)))
        stampPost(&p, st)
        if let n = st.npcs.first(where: { $0.handle == src.authorHandle }) {
            let friendly = n.affinity >= 40 && !hostile
            let line = friendly ? "ha, fair point @\(st.persona.handle)." : "stay out of my mentions @\(st.persona.handle)."
            comments.insert(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: line, verified: n.followers >= 40000), at: 0)
            p.comments = comments
            if let j = st.npcs.firstIndex(where: { $0.handle == n.handle }) {
                st.npcs[j].affinity = clampI(st.npcs[j].affinity + (friendly ? 2 : -3), 0, 100)
            }
        }
        st.posts.insert(p, at: 0)
        st.aura = min(95, max(5, st.aura + (hostile ? -1 : 1)))
        gainXP(&st, 6)
        bump(&st, "post")
        s = st
    }

    // MARK: Challenges and community events

    func bump(_ st: inout GameState, _ kind: String, _ n: Int = 1) {
        var ch = st.ex.challenges ?? []
        for i in ch.indices where ch[i].kind == kind && ch[i].progress < ch[i].goal {
            ch[i].progress = min(ch[i].goal, ch[i].progress + n)
        }
        st.ex.challenges = ch
        if var c = st.ex.community, !c.done, c.kind == kind, c.ends > Date() {
            c.progress = min(c.goal, c.progress + n)
            if c.progress >= c.goal {
                c.done = true
                st.ex.gems += c.gems
                notify(&st, "milestone", "Community event complete: \(c.title)", sub: "+\(c.gems) gems", emoji: "🏆")
            }
            st.ex.community = c
        }
    }

    func ensureChallenges() {
        guard playing else { return }
        var st = s
        let today = Game.dayKey(Date())
        let cal = Calendar.current
        let wk = "\(cal.component(.yearForWeekOfYear, from: Date()))-\(cal.component(.weekOfYear, from: Date()))"
        var ch = st.ex.challenges ?? []
        var changed = false
        if st.ex.challengeDay != today {
            ch.removeAll { !$0.weekly }
            let pool: [(String, String, Int, Int, Int)] = [
                ("Post 2 times", "post", 2, 5, 20), ("React to 5 posts", "react", 5, 4, 15), ("Follow 2 people", "follow", 2, 4, 15),
                ("Make a trade", "trade", 1, 6, 20), ("Post a story", "story", 1, 5, 15), ("Go live once", "live", 1, 8, 25)
            ]
            for (i, p) in pool.shuffled().prefix(3).enumerated() {
                ch.append(Challenge(id: "d\(today)-\(i)", text: p.0, kind: p.1, goal: p.2, progress: 0, gems: p.3, xp: p.4, weekly: false))
            }
            st.ex.challengeDay = today
            changed = true
        }
        if st.ex.challengeWeek != wk {
            ch.removeAll { $0.weekly }
            let pool: [(String, String, Int, Int, Int)] = [
                ("Post 15 times", "post", 15, 40, 120), ("Make 8 trades", "trade", 8, 45, 120), ("Go live 3 times", "live", 3, 50, 150),
                ("Follow 8 people", "follow", 8, 35, 100), ("React to 30 posts", "react", 30, 30, 90)
            ]
            for (i, p) in pool.shuffled().prefix(2).enumerated() {
                ch.append(Challenge(id: "w\(wk)-\(i)", text: p.0, kind: p.1, goal: p.2, progress: 0, gems: p.3, xp: p.4, weekly: true))
            }
            st.ex.challengeWeek = wk
            changed = true
        }
        if changed { st.ex.challenges = ch; s = st }
    }

    func claimChallenge(_ id: String) {
        var st = s
        guard var ch = st.ex.challenges, let i = ch.firstIndex(where: { $0.id == id }),
              ch[i].progress >= ch[i].goal, !ch[i].claimed else { return }
        ch[i].claimed = true
        st.ex.gems += ch[i].gems
        let xp = ch[i].xp
        st.ex.challenges = ch
        gainXP(&st, xp)
        s = st
        showToast("+\(ch[i].gems) gems")
    }

    func checkCommunity(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        let now = Date()
        if let c = st.ex.community {
            if c.ends > now { return }
            st.ex.community = nil
        }
        guard Double.random(in: 0...1) < 0.25 else { return }
        let pool: [(String, String, String, String, Int, Int, Double)] = [
            ("Hype Week", "flame.fill", "Post 3 times before it ends", "post", 3, 30, 6),
            ("Market Frenzy", "chart.line.uptrend.xyaxis", "Make 2 trades before it ends", "trade", 2, 25, 6),
            ("Stream Night", "dot.radiowaves.left.and.right", "Go live once tonight", "live", 1, 35, 8),
            ("Show Some Love", "heart.fill", "React to 5 posts", "react", 5, 20, 6)
        ]
        guard let e = pool.randomElement() else { return }
        st.ex.community = Community(id: UUID().uuidString, title: e.0, detail: e.2, symbol: e.1,
                                    ends: now.addingTimeInterval(e.6 * 3600), kind: e.3, goal: e.4, progress: 0, gems: e.5)
        if let news = st.npcs.first(where: { $0.id == "newsdesk" }) {
            var p = makePost(news, "COMMUNITY EVENT: \(e.0). \(e.2). Everyone who finishes gets \(e.5) gems.", st)
            p.tag = "Event"
            stampPost(&p, st)
            st.posts.insert(p, at: 0)
            logEvent(&st, &items, quiet: quiet, emoji: "📣", title: "\(e.0) is live", detail: e.2, post: p.id, weight: 30)
        }
    }

    // MARK: Event consequences

    func scheduleChain(_ st: inout GameState, npc: String?, choice: String) {
        guard let h = npc else { return }
        var c = st.ex.chains ?? []
        c.append(Chain(handle: h, choice: choice, due: Date().addingTimeInterval(Double.random(in: 3...30) * 3600)))
        if c.count > 6 { c.removeFirst(c.count - 6) }
        st.ex.chains = c
    }

    func processChains(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        guard var cs = st.ex.chains, !cs.isEmpty else { return }
        let now = Date()
        guard let i = cs.firstIndex(where: { $0.due <= now }) else { return }
        let c = cs.remove(at: i)
        st.ex.chains = cs
        guard let n = st.npcs.first(where: { $0.handle == c.handle }) else { return }
        let q = String(c.choice.prefix(70))
        let text = ["still thinking about when you picked \"\(q)\". the timeline hasn't forgotten.",
                    "ok but remember \"\(q)\"? receipts are still up.",
                    "\"\(q)\". that's all i'll say. @\(st.persona.handle)."].randomElement() ?? "remember?"
        var p = makePost(n, text, st)
        p.tag = "Callback"
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
        logEvent(&st, &items, quiet: quiet, emoji: "🧵", title: "\(n.name) brought up your past choice", detail: String(text.prefix(90)),
                 post: p.id, handles: [n.handle], weight: 40, history: "\(n.name) brought up something you did earlier.")
    }

    // MARK: DM arcs

    func simDMArc(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        let busy = Set(st.threads.filter { $0.value.last?.choices != nil }.map { $0.key })
        guard let n = cast.filter({ !busy.contains($0.handle) }).randomElement() else { return }
        let me = st.persona.name.components(separatedBy: " ").first ?? ""
        var arc = "offer"
        var text = "got a collab in mind and you're my first pick. interested?"
        var ch = ["I'm in", "Not interested", "What's the split?"]
        switch n.trait {
        case .hater, .chaos:
            arc = "threat"; text = "i know what you posted last week. delete it or the screenshots go public."
            ch = ["Do your worst", "Fine, deleting it", "Who is this?"]
        case .gossip:
            arc = "secret"; text = "psst \(me). i know who is behind the last rug. want the receipts?"
            ch = ["Spill it", "Keep it to yourself", "Name your price"]
        case .wholesome:
            arc = "apology"; text = "i've been thinking about how things got weird between us. can we start over?"
            ch = ["Apology accepted", "Too late", "Prove it"]
        default: break
        }
        var th = st.threads[n.handle] ?? []
        th.append(DMMessage(fromYou: false, text: text, choices: ch, arc: arc))
        st.threads[n.handle] = th
        st.unread.insert(n.handle)
        notify(&st, "reply", "\(n.name) sent you a message", sub: "\(n.handle): \(text)", handle: n.handle, emoji: n.emoji)
        logEvent(&st, &items, quiet: quiet, emoji: "💬", title: "\(n.name) slid into your DMs", detail: String(text.prefix(90)),
                 handles: [n.handle], weight: 28)
    }

    func answerArc(_ handle: String, _ choice: Int) {
        var st = s
        guard var th = st.threads[handle], let mi = th.lastIndex(where: { $0.choices != nil }),
              let ch = th[mi].choices, ch.indices.contains(choice) else { return }
        let arc = th[mi].arc ?? "offer"
        th[mi].choices = nil
        th.append(DMMessage(fromYou: true, text: ch[choice]))
        var reply = "ok."
        var d = 0, gems = 0, aura = 0
        switch (arc, choice) {
        case ("offer", 0): reply = "let's get it. sending the first payout now."; d = 10; gems = 10
        case ("offer", 1): reply = "your loss."; d = -4
        case ("offer", _): reply = "70/30, my favor. take it or leave it."; d = 2; gems = 4
        case ("threat", 0): reply = "oh it's on."; d = -10; aura = 2
        case ("threat", 1): reply = "smart."; d = 2; aura = -2
        case ("threat", _): reply = "you'll find out."; d = -2
        case ("secret", 0): reply = "it was someone in your own feed. check who has gone quiet lately."; d = 6
        case ("secret", 1): reply = "suit yourself."; d = -1
        case ("secret", _):
            if st.ex.gems >= 5 { st.ex.gems -= 5; reply = "worth it. look at who posted right before the dump."; d = 4; aura = 1 }
            else { reply = "come back with gems." }
        case ("apology", 0): reply = "thank you. really. fresh start."; d = 15
        case ("apology", 1): reply = "fair. i understand."; d = -5
        default: reply = "i will. watch me."; d = 3
        }
        th.append(DMMessage(fromYou: false, text: reply))
        st.threads[handle] = th
        if let j = st.npcs.firstIndex(where: { $0.handle == handle }) {
            st.npcs[j].affinity = clampI(st.npcs[j].affinity + d, 0, 100)
        }
        st.ex.gems += gems
        st.aura = min(95, max(5, st.aura + aura))
        if arc == "threat" && choice == 0 { remember(&st, handle, "insult", "you dared me to leak it", mood: -2) }
        gainXP(&st, 6)
        s = st
    }

    // MARK: Leaving and coming back

    func retireTick(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        var gone = st.ex.gone ?? [:]
        let now = Date()
        if let back = gone.first(where: { $0.value <= now })?.key {
            gone[back] = nil
            if let j = st.npcs.firstIndex(where: { $0.handle == back }) {
                st.npcs[j].followers = Int(Double(st.npcs[j].followers) * 1.1)
                let n = st.npcs[j]
                let text = ["i'm back. did anyone miss me or nah?", "took a break, touched grass, came back meaner.", "redemption arc starts now. watch."].randomElement() ?? "back"
                var p = makePost(n, text, st)
                p.tag = "Comeback"
                stampPost(&p, st)
                st.posts.insert(p, at: 0)
                logEvent(&st, &items, quiet: quiet, emoji: "🔥", title: "\(n.name) is back", detail: text, post: p.id,
                         handles: [n.handle], weight: 30, history: "\(n.name) came back after a break.")
            }
        }
        if gone.count < 5, Double.random(in: 0...1) < 0.03,
           let n = st.npcs.filter({ $0.id != "newsdesk" && gone[$0.handle] == nil }).randomElement() {
            let text = ["deleting this app. you all are exhausting.", "i'm done. this scene isn't worth it anymore.", "logging off for a while. don't text me."].randomElement() ?? "bye"
            var p = makePost(n, text, st)
            p.tag = "Goodbye"
            stampPost(&p, st)
            st.posts.insert(p, at: 0)
            gone[n.handle] = now.addingTimeInterval(Double.random(in: 1...4) * 86400)
            logEvent(&st, &items, quiet: quiet, emoji: "🚪", title: "\(n.name) left the scene", detail: text, post: p.id,
                     handles: [n.handle], weight: 35, history: "\(n.name) rage-quit the scene.")
        }
        st.ex.gone = gone.isEmpty ? nil : gone
    }

    /// Everything long-running that should tick whether or not the player is looking.
    func engagementTick(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        processChains(&st, &items, quiet: quiet)
        checkCommunity(&st, &items, quiet: quiet)
        retireTick(&st, &items, quiet: quiet)
    }
}
