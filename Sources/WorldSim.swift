import SwiftUI

// MARK: - Living world: the world keeps moving while you're away

extension Game {
    // MARK: Time stamps

    /// Call when the app leaves the foreground.
    func stampSim() {
        guard playing else { return }
        var st = s
        st.ex.lastSim = Date()
        s = st
        flush()
    }

    func dismissDigest() {
        var st = s
        st.ex.digest = nil
        s = st
    }

    // MARK: History

    func addHistory(_ st: inout GameState, _ emoji: String, _ title: String, _ detail: String) {
        var h = st.ex.history ?? []
        h.insert(HistoryItem(day: st.day, emoji: emoji, title: title, detail: detail), at: 0)
        if h.count > 150 { h.removeLast(h.count - 150) }
        st.ex.history = h
    }

    private func bumpRivalry(_ st: inout GameState, _ a: String, _ b: String, cause: String) -> Int {
        var r = st.ex.rivalries ?? []
        let key = [a, b].sorted().joined(separator: "|")
        if let i = r.firstIndex(where: { $0.id == key }) {
            r[i].heat += 1
            r[i].cause = cause
            r[i].lastDay = st.day
            let h = r[i].heat
            st.ex.rivalries = r
            return h
        }
        r.append(Rivalry(id: key, a: a, b: b, heat: 1, cause: cause, lastDay: st.day))
        st.ex.rivalries = r
        return 1
    }

    // MARK: Catch-up when you come back

    func catchUp() {
        guard playing, s.intro?.done != false else { return }
        var st = s
        let now = Date()
        let last = st.ex.lastSim ?? now
        let away = now.timeIntervalSince(last)
        st.ex.lastSim = now
        guard away >= 20 * 60 else {
            s = st
            return
        }
        if away >= 3600 { checkIgnored(&st) }
        let ticks = min(16, max(3, Int(away / 2400)))
        var items: [DigestItem] = []
        let f0 = st.followers
        let a0 = st.aura
        for _ in 0..<ticks { simTick(&st, &items, quiet: false) }

        // popularity drifts with your aura while you're gone
        let hrs = min(away / 3600, 12) / 12
        var pct = Double.random(in: -0.01...0.03)
        if st.aura >= 60 { pct += 0.01 } else if st.aura < 30 { pct -= 0.015 }
        st.followers = max(10, Int(Double(st.followers) * (1 + pct * hrs)))
        if st.aura > 55 { st.aura -= Int.random(in: 0...2) }
        else if st.aura < 45 { st.aura += Int.random(in: 0...2) }
        _ = settleAura(&st)

        let fd = st.followers - f0
        let ad = st.aura - a0
        let sign = fd >= 0 ? "+" : "-"
        let asign = ad >= 0 ? "+" : ""
        items.insert(DigestItem(emoji: fd >= 0 ? "📈" : "📉",
                                title: "Your popularity \(fd >= 0 ? "grew" : "dipped")",
                                detail: "\(sign)\(short(abs(fd))) followers · aura \(asign)\(ad)%"), at: 0)
        items = Array(items.prefix(10))
        st.ex.digest = Digest(items: items, followerDelta: fd, auraDelta: ad, minutes: Int(away / 60))
        notify(&st, "event", "While you were away", sub: items.dropFirst().first?.title ?? "Your world kept moving", emoji: "🌍")
        if st.posts.count > 120 { st.posts.removeLast(st.posts.count - 120) }
        s = st
        checkBadges()
    }

    /// Small live events while the app is open.
    func ambientTick() {
        guard playing, s.intro?.done != false else { return }
        guard Double.random(in: 0...1) < 0.12 else { return }
        var st = s
        var items: [DigestItem] = []
        simTick(&st, &items, quiet: true)
        if st.posts.count > 120 { st.posts.removeLast(st.posts.count - 120) }
        s = st
    }

    // MARK: One simulation step

    private func simTick(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard cast.count >= 2 else { return }
        if let sp = st.ex.spotlight, sp > 0 {
            st.ex.spotlight = sp - 1
            if sp - 1 == 0 { fadeHype(&st, &items, quiet) }
            let q = Double.random(in: 0...1)
            if q < 0.30 { simScrutiny(&st, &items, cast, quiet); return }
            if q < 0.42 { simOffer(&st, &items, cast, quiet); return }
        }
        let r = Double.random(in: 0...1)
        if r < 0.24 { simPost(&st, &items, cast, quiet) }
        else if r < 0.46 { simBeef(&st, &items, cast, quiet) }
        else if r < 0.56 { simResurface(&st, &items, cast, quiet) }
        else if r < 0.62 { simMajor(&st, &items, quiet) }
        else if r < 0.80 { if !simMemoryPost(&st, &items, cast, quiet) { simPost(&st, &items, cast, quiet) } }
        else if r < 0.92 { if !simMemoryDM(&st, &items, cast, quiet) { simBeef(&st, &items, cast, quiet) } }
        else { simPost(&st, &items, cast, quiet) }
    }

    private func simPost(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard let n = cast.randomElement() else { return }
        let topics = Topics.forWorld(st.world)
        let text = Topics.line(trait: n.trait, topics: topics) ?? Lines.feed[n.trait]?.randomElement() ?? "just vibing"
        var p = makePost(n, text, st)
        p.day = st.day
        st.posts.insert(p, at: 0)
        if !quiet && items.count < 10 && Bool.random() {
            items.append(DigestItem(emoji: n.emoji, title: "\(n.name) posted", detail: String(text.prefix(90)), postID: p.id))
        }
    }

    private func simBeef(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        var pa: NPC? = nil
        var pb: NPC? = nil
        var oldCause: String? = nil
        if Double.random(in: 0...1) < 0.5, let r = (st.ex.rivalries ?? []).randomElement(),
           let x = cast.first(where: { $0.handle == r.a }), let y = cast.first(where: { $0.handle == r.b }) {
            let flip = Bool.random()
            pa = flip ? x : y
            pb = flip ? y : x
            oldCause = r.cause
        }
        if pa == nil {
            pa = cast.randomElement()
            let others = cast.filter { $0.handle != pa?.handle }.shuffled()
            pb = others.first(where: { $0.trait != pa?.trait }) ?? others.first
        }
        guard let a = pa, let b = pb else { return }
        let topic = oldCause ?? Topics.forWorld(st.world).randomElement() ?? "the scene"
        let templates = oldCause != nil ? [
            "still not over what @\(b.handle) said about \(topic). not even a little.",
            "@\(b.handle) really thought we were done talking about \(topic). round two.",
            "the \(topic) situation with @\(b.handle) is NOT resolved. receipts coming.",
            "everyone moved on from \(topic) except me and @\(b.handle). funny how that works."
        ] : [
            "not naming names but @\(b.handle) knows exactly what they did 🙄",
            "@\(b.handle) we need to talk about \(topic). publicly.",
            "unpopular opinion: @\(b.handle) ruined \(topic) and i'm tired of pretending otherwise",
            "@\(b.handle) delete that post. i'm not asking twice.",
            "some people (@\(b.handle)) really think they run \(topic). they don't.",
            "apologies to everyone who had to witness what @\(b.handle) just did",
            "@\(b.handle) said what they said about \(topic) and i said what i said. receipts incoming.",
            "the way @\(b.handle) talks about \(topic) is sending me. be so serious."
        ]
        let text = templates.randomElement() ?? templates[0]
        var p = makePost(a, text, st)
        p.tag = "Drama"
        p.day = st.day
        p.likes = max(p.likes * 3, 60)
        p.reposts = p.likes / 5
        p.comments = beefComments(st, a: a, b: b, topic: topic, text: text)
        st.posts.insert(p, at: 0)
        for h in [a.handle, b.handle] {
            if let j = st.npcs.firstIndex(where: { $0.handle == h }) {
                st.npcs[j].followers = Int(Double(st.npcs[j].followers) * Double.random(in: 1.01...1.05))
            }
        }
        let heat = bumpRivalry(&st, a.handle, b.handle, cause: topic)
        let sides = Set(p.comments.map { $0.handle }).count
        if !quiet {
            let line = heat >= 2 ? "Round \(heat) of their feud." : "\(sides) characters jumped in and everyone's picking a side."
            items.append(DigestItem(emoji: "🔥", title: "\(a.name) and \(b.name) got into an argument",
                                    detail: line, postID: p.id))
        } else {
            notify(&st, "event", "\(a.name) and \(b.name) are fighting", sub: String(text.prefix(90)), handle: a.handle, emoji: "🔥")
        }
        if heat >= 2 || Double.random(in: 0...1) < 0.4 {
            addHistory(&st, "🔥", "\(a.name) vs \(b.name)",
                       heat >= 2 ? "Their feud flared up again over \(topic)." : "A public argument over \(topic) split the timeline.")
        }
    }

    private func beefComments(_ st: GameState, a: NPC, b: NPC, topic: String, text: String) -> [Comment] {
        let quote = Corpus.quote(from: text, fallback: topic)
        let me = st.persona.handle
        var out: [Comment] = []
        func add(_ n: NPC, _ to: String, _ bucket: String) {
            let l = Corpus.line(trait: n.trait, bucket: bucket, me: me, topic: topic, quote: quote)
                ?? (bucket == "rebut.agree" ? "exactly this" : "no, that's wrong")
            out.append(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: "@\(to) " + l, verified: n.followers >= 40000))
        }
        add(b, a.handle, "rebut.fight")
        add(a, b.handle, "rebut.fight")
        let rest = st.npcs.filter { $0.id != "newsdesk" && $0.handle != a.handle && $0.handle != b.handle }
            .shuffled().prefix(Int.random(in: 2...5))
        for n in rest {
            let withA = Bool.random()
            let ally = withA ? a : b
            let enemy = withA ? b : a
            if Bool.random() { add(n, ally.handle, "rebut.agree") } else { add(n, enemy.handle, "rebut.fight") }
        }
        if Bool.random() { add(b, a.handle, "rebut.fight") }
        return out
    }

    private func simResurface(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard let old = st.posts.filter({ $0.isYou }).randomElement(), let n = cast.randomElement() else {
            simPost(&st, &items, cast, quiet)
            return
        }
        let snippet = String(old.text.prefix(70))
        let nasty = n.trait == .hater || n.trait == .gossip || n.trait == .chaos
        let bad = ["found this old post by @\(st.persona.handle) 💀 \"\(snippet)\"",
                   "remember when @\(st.persona.handle) posted \"\(snippet)\"? i do. i always will.",
                   "resurfacing this because the timeline deserves to see it again: \"\(snippet)\""]
        let good = ["this post by @\(st.persona.handle) aged like fine wine: \"\(snippet)\"",
                    "reminder that @\(st.persona.handle) posted \"\(snippet)\" and was right",
                    "going back to this post from @\(st.persona.handle). still the best take: \"\(snippet)\""]
        let text = (nasty ? bad : good).randomElement() ?? bad[0]
        let delta = nasty ? Int.random(in: -4 ... -1) : Int.random(in: 1...4)
        var p = makePost(n, text, st)
        p.tag = "Resurfaced"
        p.day = st.day
        p.likes = max(p.likes * 2, 40)
        p.comments = makeComments(st, auraDelta: delta, count: Int.random(in: 3...6), exclude: n.handle, text: old.text)
        st.posts.insert(p, at: 0)
        st.aura += delta
        st.lastAuraDelta = delta
        if delta > 0 { st.followers += max(1, st.followers / 60) } else { st.followers = max(10, st.followers - max(1, st.followers / 90)) }
        logIt(&st, "🌟", "Aura", "post", kind: "outcome", ref: old.id,
              body: "\(n.name) \(nasty ? "dug up" : "brought back") an old post of yours and the timeline reacted.",
              delta: Double(delta), handle: n.handle)
        if !quiet {
            items.append(DigestItem(emoji: "⏪", title: "Your old post resurfaced",
                                    detail: "\(n.name) \(nasty ? "dug it up" : "revived it"): \"\(snippet)\" (aura \(delta >= 0 ? "+" : "")\(delta)%)",
                                    postID: p.id))
        } else {
            notify(&st, "event", "\(n.name) resurfaced your old post", sub: snippet, handle: n.handle, emoji: "⏪")
        }
        if abs(delta) >= 3 {
            addHistory(&st, "⏪", "An old post came back",
                       "\(n.name) \(nasty ? "resurfaced" : "celebrated") \"\(snippet)\" and it changed the mood about \(st.persona.name).")
        }
    }

    private func simMajor(_ st: inout GameState, _ items: inout [DigestItem], _ quiet: Bool) {
        guard let news = st.npcs.first(where: { $0.id == "newsdesk" }) else { return }
        let topic = Topics.forWorld(st.world).randomElement() ?? "the scene"
        st.ex.hot = topic
        let T = topic.capitalized
        let pool: [(String, String, String)] = [
            ("📣", "\(T) Fest announced", "BREAKING: \(T) Fest announced. Everyone in the scene is making plans."),
            ("🕵️", "A leak shook the \(topic) scene", "BREAKING: a leak is rattling the \(topic) scene. Insiders say nothing will be the same."),
            ("🏆", "\(T) awards drama", "BREAKING: the \(topic) awards are in chaos. Nominees are furious and the timeline is split."),
            ("🚨", "Big \(topic) scandal", "BREAKING: a major \(topic) scandal broke overnight. Names are being named."),
            ("🤝", "Surprise \(topic) collab", "BREAKING: two rivals just announced a surprise \(topic) collab. Nobody saw it coming.")
        ]
        guard let e = pool.randomElement() else { return }
        var p = makePost(news, e.3, st)
        p.tag = "Breaking"
        p.day = st.day
        p.likes = max(p.likes * 2, 200)
        p.reposts = p.likes / 5
        p.comments = makeComments(st, auraDelta: 0, count: Int.random(in: 4...7), exclude: "", text: e.3)
        st.posts.insert(p, at: 0)
        addHistory(&st, e.0, e.1, "The whole world is still talking about it.")
        if !quiet {
            items.append(DigestItem(emoji: e.0, title: e.1, detail: "Added to your world's history.", postID: p.id))
        } else {
            notify(&st, "event", e.1, sub: "Breaking news in your world", handle: "", emoji: e.0)
        }
    }
}
