import SwiftUI

// MARK: - Individual world events. Every event writes the feed, history and recap through logEvent,
// so the three can never disagree.

extension Game {
    func stampPost(_ p: inout Post, _ st: GameState) {
        p.ts = st.ex.simNow ?? Date()
        p.day = st.day
    }

    func logEvent(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool,
                  emoji: String, title: String, detail: String,
                  post: UUID? = nil, handles: [String] = [], weight: Int = 10, history: String? = nil) {
        let at = st.ex.simNow ?? Date()
        if let h = history { addHistory(&st, emoji, title, h, post: post, handles: handles) }
        if quiet {
            if weight >= 30 { notify(&st, "event", title, sub: String(detail.prefix(90)), handle: handles.first ?? "", emoji: emoji) }
        } else {
            items.append(DigestItem(emoji: emoji, title: title, detail: detail, postID: post,
                                    handles: handles, at: at, weight: weight))
        }
    }

    // MARK: Plain posts and feud chatter

    func simPost(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        if Double.random(in: 0...1) < 0.3, let r = activeFeuds(st).randomElement(),
           let a = cast.first(where: { $0.handle == r.a }), let b = cast.first(where: { $0.handle == r.b }),
           let n = cast.filter({ r.sides?[$0.handle] != nil }).randomElement() {
            let ally = r.sides?[n.handle] == a.handle ? a : b
            let enemy = ally.handle == a.handle ? b : a
            let cause = r.cause ?? "all of this"
            let text = ["team @\(ally.handle). @\(enemy.handle) still hasn't apologised about \(cause).",
                        "\(cause) aside, @\(enemy.handle) owes @\(ally.handle) an apology and we all know it.",
                        "can we talk about how @\(enemy.handle) handled \(cause)? asking for @\(ally.handle).",
                        "not picking sides but if i did it'd be @\(ally.handle) 👀"].randomElement() ?? "👀"
            var p = makePost(n, text, st)
            p.tag = "Feud"
            stampPost(&p, st)
            st.posts.insert(p, at: 0)
            logEvent(&st, &items, quiet: quiet, emoji: "🗯️", title: "\(n.name) picked a side",
                     detail: "Team \(ally.name) in the \(ally.name) vs \(enemy.name) feud.", post: p.id,
                     handles: [n.handle, ally.handle, enemy.handle], weight: 20)
            return
        }
        guard let n = cast.randomElement() else { return }
        let topics = Topics.forWorld(st.world)
        var text: String? = nil
        if Double.random(in: 0...1) < 0.6, let tp = topics.randomElement() {
            text = Corpus.post(trait: n.trait, me: st.persona.handle, topic: tp)
        }
        let body = text ?? Topics.line(trait: n.trait, topics: topics) ?? Lines.feed[n.trait]?.randomElement() ?? "just vibing"
        var p = makePost(n, body, st)
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
        logEvent(&st, &items, quiet: quiet, emoji: n.emoji, title: "\(n.name) posted",
                 detail: String(body.prefix(90)), post: p.id, handles: [n.handle], weight: 8)
    }

    // MARK: Arguments

    func simBeef(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        if Double.random(in: 0...1) < 0.18, simTruce(&st, &items, cast, quiet) { return }
        var pa: NPC? = nil
        var pb: NPC? = nil
        var oldCause: String? = nil
        if Double.random(in: 0...1) < 0.5, let r = activeFeuds(st).randomElement(),
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
            "@\(b.handle) said what they said about \(topic) and i said what i said. receipts incoming."
        ]
        let text = templates.randomElement() ?? templates[0]
        let step = escalateFeud(&st, a: a, b: b, cause: topic)
        var p = makePost(a, text, st)
        p.tag = "Drama"
        stampPost(&p, st)
        p.likes = max(p.likes * 3, 60)
        p.reposts = p.likes / 5
        p.comments = beefComments(st, a: a, b: b, topic: topic, text: text)
        st.posts.insert(p, at: 0)

        let label = feudLabel(step.rel)
        var title = "\(a.name) and \(b.name) got into an argument"
        if step.reignited { title = "\(a.name) and \(b.name) reignited their feud" }
        else if step.heat >= 2 { title = "\(a.name) vs \(b.name): round \(step.heat)" }
        let detail = "\(step.sidesA) sided with \(a.name), \(step.sidesB) with \(b.name). Relationship: \(label.lowercased())."
        var hist: String? = nil
        if step.reignited { hist = "Old wounds reopened over \(topic). \(step.sidesA) back \(a.name), \(step.sidesB) back \(b.name)." }
        else if step.heat == 1 { hist = "They fell out over \(topic). \(step.sidesA) sided with \(a.name), \(step.sidesB) with \(b.name)." }
        else if step.heat == 3 || step.heat == 5 || step.heat == 8 {
            hist = "The feud over \(topic) hit round \(step.heat) and the timeline split \(step.sidesA) to \(step.sidesB). They are now \(label.lowercased())."
        }
        logEvent(&st, &items, quiet: quiet, emoji: "🔥", title: title, detail: detail, post: p.id,
                 handles: [a.handle, b.handle], weight: min(88, 55 + step.heat * 5), history: hist)
    }

    private func beefComments(_ st: GameState, a: NPC, b: NPC, topic: String, text: String) -> [Comment] {
        let sides = st.ex.rivalries?.first(where: { $0.id == Game.rivalKey(a.handle, b.handle) })?.sides ?? [:]
        var out: [Comment] = []
        func add(_ n: NPC, _ to: String, _ bucket: String) {
            let l = voiceLine(st, n, bucket: bucket, target: to, toPlayer: false, text: text, heat: 0.85, topic: topic)?.0
                ?? (bucket == "rebut.agree" ? "exactly this" : "no, that's wrong")
            out.append(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: "@\(to) " + l, verified: n.followers >= 40000))
        }
        add(b, a.handle, "rebut.fight")
        add(a, b.handle, "rebut.fight")
        let rest = st.npcs.filter { $0.id != "newsdesk" && $0.handle != a.handle && $0.handle != b.handle }
            .shuffled().prefix(Int.random(in: 3...6))
        for n in rest {
            let allyH = sides[n.handle] ?? (Bool.random() ? a.handle : b.handle)
            let ally = allyH == a.handle ? a : b
            let enemy = allyH == a.handle ? b : a
            if Bool.random() { add(n, ally.handle, "rebut.agree") } else { add(n, enemy.handle, "rebut.fight") }
        }
        return out
    }

    // MARK: Old posts coming back

    func simResurface(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard let old = st.posts.filter({ $0.isYou }).randomElement(), let n = cast.randomElement() else {
            simPost(&st, &items, cast, quiet)
            return
        }
        let snippet = String(old.text.prefix(70))
        let f = feeling(st, n.handle)
        let nasty = f <= -2 || (f < 2 && (n.trait == .hater || n.trait == .gossip || n.trait == .chaos))
        let me = st.persona.handle
        let bad = ["found this old post by @\(me) 💀 \"\(snippet)\"",
                   "remember when @\(me) posted \"\(snippet)\"? i do. i always will.",
                   "resurfacing this because the timeline deserves to see it again: \"\(snippet)\""]
        let good = ["this post by @\(me) aged like fine wine: \"\(snippet)\"",
                    "reminder that @\(me) posted \"\(snippet)\" and was right",
                    "going back to this post from @\(me). still the best take: \"\(snippet)\""]
        let text = (nasty ? bad : good).randomElement() ?? bad[0]
        let delta = nasty ? -Int.random(in: 1...4) : Int.random(in: 1...4)
        var p = makePost(n, text, st)
        p.tag = "Resurfaced"
        stampPost(&p, st)
        p.likes = max(p.likes * 2, 40)
        p.comments = makeComments(st, auraDelta: delta, count: Int.random(in: 3...6), exclude: n.handle, text: old.text)
        st.posts.insert(p, at: 0)
        st.aura += delta
        st.lastAuraDelta = delta
        if delta > 0 { st.followers += max(1, st.followers / 60) } else { st.followers = max(10, st.followers - max(1, st.followers / 90)) }
        logIt(&st, "🌟", "Aura", "post", kind: "outcome", ref: old.id,
              body: "\(n.name) \(nasty ? "dug up" : "brought back") an old post of yours and the timeline reacted.",
              delta: Double(delta), handle: n.handle)
        logEvent(&st, &items, quiet: quiet, emoji: "⏪", title: "Your old post resurfaced",
                 detail: "\(n.name) \(nasty ? "dug it up" : "revived it"): \"\(snippet)\"",
                 post: p.id, handles: [n.handle], weight: 45 + abs(delta) * 4,
                 history: abs(delta) >= 3 ? "\(n.name) \(nasty ? "resurfaced" : "celebrated") \"\(snippet)\" and it changed the mood about \(st.persona.name)." : nil)
    }

    // MARK: Big world news

    func simMajor(_ st: inout GameState, _ items: inout [DigestItem], _ quiet: Bool) {
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
        var p = makePost(news, e.2, st)
        p.tag = "Breaking"
        stampPost(&p, st)
        p.likes = max(p.likes * 2, 200)
        p.reposts = p.likes / 5
        p.comments = makeComments(st, auraDelta: 0, count: Int.random(in: 4...7), exclude: "", text: e.2)
        st.posts.insert(p, at: 0)
        logEvent(&st, &items, quiet: quiet, emoji: e.0, title: e.1,
                 detail: "Everyone is talking about \(topic). Posts about it are more likely to blow up.",
                 post: p.id, handles: ["newsdesk"], weight: 70, history: "The whole world is still talking about it.")
    }

    // MARK: Memory-driven events

    func simMemoryPost(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) -> Bool {
        let cands = cast.map { ($0, feeling(st, $0.handle)) }.filter { abs($0.1) >= 2 }
        guard let (n, f) = cands.randomElement(), let m = strongestMemory(st, n.handle, positive: f > 0) else { return false }
        let pos = f > 0
        let text = MemLines.post(m, positive: pos, me: st.persona.handle)
        var p = makePost(n, text, st)
        p.tag = pos ? "Shoutout" : "Callout"
        stampPost(&p, st)
        p.likes = max(p.likes * 2, 50)
        p.comments = makeComments(st, auraDelta: pos ? 3 : -3, count: Int.random(in: 3...6), exclude: n.handle, text: text)
        st.posts.insert(p, at: 0)
        let d = pos ? Int.random(in: 1...3) : -Int.random(in: 1...3)
        st.aura += d
        st.lastAuraDelta = d
        if pos { st.followers += max(1, st.followers / 80) } else { st.followers = max(10, st.followers - max(1, st.followers / 100)) }
        markAired(&st, m.id)
        logEvent(&st, &items, quiet: quiet, emoji: pos ? "🫶" : "🗣️",
                 title: pos ? "\(n.name) gave you a shoutout" : "\(n.name) called you out",
                 detail: "They remembered that \(m.text).", post: p.id, handles: [n.handle],
                 weight: 55 + min(15, abs(f) * 3),
                 history: abs(f) >= 4 ? "\(n.name) \(pos ? "publicly stood by" : "turned on") \(st.persona.name). They remembered that \(m.text)." : nil)
        return true
    }

    func simMemoryDM(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) -> Bool {
        let cands = cast.filter { n in
            guard abs(feeling(st, n.handle)) >= 2 else { return false }
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
            items.append(DigestItem(emoji: "💬", title: "\(n.name) messaged you", detail: String(msg.prefix(90)),
                                    handles: [n.handle], at: st.ex.simNow ?? Date(), weight: 35))
        }
        return true
    }

    // MARK: Consequences of going viral

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
        stampPost(&p, st)
        p.likes = max(p.likes * 2, 60)
        p.comments = makeComments(st, auraDelta: -2, count: Int.random(in: 3...6), exclude: n.handle, text: t)
        st.posts.insert(p, at: 0)
        let d = -Int.random(in: 1...3)
        st.aura += d
        st.lastAuraDelta = d
        logEvent(&st, &items, quiet: quiet, emoji: "🌪️", title: "Backlash after going viral",
                 detail: "\(n.name) turned on you.", post: p.id, handles: [n.handle], weight: 48)
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
        if !quiet {
            items.append(DigestItem(emoji: "💼", title: "\(n.name) made you an offer", detail: "+2 gems. Check your DMs.",
                                    handles: [n.handle], at: st.ex.simNow ?? Date(), weight: 45))
        }
    }

    func fadeHype(_ st: inout GameState, _ items: inout [DigestItem], _ quiet: Bool) {
        let churn = max(0, (st.ex.spotGain ?? 0) / 4)
        st.ex.spotGain = nil
        guard churn > 0 else { return }
        st.followers = max(10, st.followers - churn)
        logEvent(&st, &items, quiet: quiet, emoji: "📉", title: "The viral hype faded",
                 detail: "-\(short(churn)) followers who only came for the moment.", weight: 30,
                 history: "Casual followers from \(st.persona.name)'s viral moment drifted away.")
    }
}
