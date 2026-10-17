import SwiftUI

// MARK: - Feuds: escalation, sides, truce, mediation

struct FeudStep {
    var heat: Int
    var reignited: Bool
    var sidesA: Int
    var sidesB: Int
    var rel: Int
}

extension Game {
    static func rivalKey(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }

    func activeFeuds(_ st: GameState) -> [Rivalry] {
        (st.ex.rivalries ?? []).filter { $0.status != "resolved" && $0.heat >= 1 }
    }

    func feudLabel(_ rel: Int) -> String {
        switch rel {
        case ...(-60): return "Sworn enemies"
        case -59 ... -30: return "Bitter rivals"
        case -29 ... -10: return "Tense"
        default: return "Cold"
        }
    }

    func takeSide(_ st: inout GameState, _ ally: String, _ enemy: String) {
        var rs = st.ex.rivalries ?? []
        let key = Game.rivalKey(ally, enemy)
        guard let i = rs.firstIndex(where: { $0.id == key }) else { return }
        var sides = rs[i].sides ?? [:]
        sides[st.persona.handle] = ally
        rs[i].sides = sides
        st.ex.rivalries = rs
    }

    /// Escalates (or starts, or reignites) a feud and returns what changed.
    func escalateFeud(_ st: inout GameState, a: NPC, b: NPC, cause: String) -> FeudStep {
        var rs = st.ex.rivalries ?? []
        let key = Game.rivalKey(a.handle, b.handle)
        var idx = rs.firstIndex(where: { $0.id == key })
        if idx == nil {
            rs.append(Rivalry(id: key, a: a.handle, b: b.handle, heat: 0, cause: cause, lastDay: st.day))
            idx = rs.count - 1
        }
        let i = idx ?? 0
        var r = rs[i]
        let now = st.ex.simNow ?? Date()
        var reignited = false
        if r.status == "resolved" { reignited = true; r.status = nil }
        r.heat += 1
        r.cause = cause
        r.lastDay = st.day
        r.lastAt = now
        if r.started == nil { r.started = now }
        r.rel = max(-100, (r.rel ?? 0) - Int.random(in: 6...12) - (reignited ? 8 : 0))
        var sides = r.sides ?? [:]
        for n in st.npcs where n.id != "newsdesk" && n.handle != a.handle && n.handle != b.handle && sides[n.handle] == nil {
            if n.trait == a.trait && n.trait != b.trait { sides[n.handle] = a.handle }
            else if n.trait == b.trait && n.trait != a.trait { sides[n.handle] = b.handle }
            else { sides[n.handle] = Bool.random() ? a.handle : b.handle }
        }
        r.sides = sides
        rs[i] = r
        st.ex.rivalries = rs

        let sa = sides.filter { $0.value == a.handle && $0.key != st.persona.handle }.count
        let sb = sides.filter { $0.value == b.handle && $0.key != st.persona.handle }.count
        // followers take sides: the bigger camp gains, the smaller one bleeds
        let aWins = sa == sb ? Bool.random() : sa > sb
        let win = aWins ? a.handle : b.handle
        let lose = aWins ? b.handle : a.handle
        if let w = st.npcs.firstIndex(where: { $0.handle == win }) {
            st.npcs[w].followers = Int(Double(st.npcs[w].followers) * Double.random(in: 1.01...1.03))
        }
        if let l = st.npcs.firstIndex(where: { $0.handle == lose }) {
            st.npcs[l].followers = max(50, Int(Double(st.npcs[l].followers) * Double.random(in: 0.985...1.0)))
        }
        return FeudStep(heat: r.heat, reignited: reignited, sidesA: sa, sidesB: sb, rel: r.rel ?? 0)
    }

    private func resolveFeud(_ st: inout GameState, _ id: String, by: String) {
        var rs = st.ex.rivalries ?? []
        guard let i = rs.firstIndex(where: { $0.id == id }) else { return }
        rs[i].status = "resolved"
        rs[i].resolvedBy = by
        rs[i].rel = min(0, (rs[i].rel ?? 0) + 30)
        rs[i].lastAt = st.ex.simNow ?? Date()
        st.ex.rivalries = rs
    }

    /// Two characters end their feud on their own.
    func simTruce(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) -> Bool {
        let cands = activeFeuds(st).filter { $0.heat >= 2 }
        guard let r = cands.randomElement(),
              let a = cast.first(where: { $0.handle == r.a }),
              let b = cast.first(where: { $0.handle == r.b }) else { return false }
        let cause = r.cause ?? "all of it"
        let text = ["ok i'm done fighting with @\(b.handle). \(cause) isn't worth it. truce?",
                    "@\(b.handle) i said things i shouldn't have about \(cause). can we move on?",
                    "life's too short. @\(b.handle) let's squash the \(cause) thing."].randomElement() ?? "truce"
        var p = makePost(a, text, st)
        p.tag = "Peace"
        stampPost(&p, st)
        p.likes = max(p.likes * 2, 80)
        var c = makeComments(st, auraDelta: 2, count: Int.random(in: 2...4), exclude: a.handle, text: text)
        c.insert(Comment(name: b.name, handle: b.handle, emoji: b.emoji, text: "@\(a.handle) fine. truce. i was being dramatic too 🤝",
                         verified: b.followers >= 40000), at: 0)
        p.comments = c
        st.posts.insert(p, at: 0)
        resolveFeud(&st, r.id, by: "time")
        logEvent(&st, &items, quiet: quiet, emoji: "🕊️", title: "\(a.name) and \(b.name) made up",
                 detail: "Their feud over \(cause) is over after \(r.heat) rounds.", post: p.id,
                 handles: [a.handle, b.handle], weight: 65,
                 history: "The feud over \(cause) ended after \(r.heat) rounds. \(a.name) and \(b.name) buried it.")
        return true
    }

    /// The player steps in to settle a feud. Returns a message for the UI.
    func mediate(_ id: String) -> String {
        let st0 = s
        guard let r = (st0.ex.rivalries ?? []).first(where: { $0.id == id }), r.status != "resolved",
              let a = st0.npcs.first(where: { $0.handle == r.a }),
              let b = st0.npcs.first(where: { $0.handle == r.b }) else { return "That feud is already over." }
        var st = s
        let charm = Double(st.stats["charm"] ?? 30)
        let warmth = Double(feeling(st, a.handle) + feeling(st, b.handle))
        let chance = min(0.85, max(0.15, 0.40 + charm / 250 + warmth * 0.04 - Double(r.heat) * 0.04))
        let cause = r.cause ?? "the whole thing"
        if Double.random(in: 0...1) < chance {
            resolveFeud(&st, id, by: "you")
            remember(&st, a.handle, "mediated", "you settled my beef with \(b.name)", mood: 2)
            remember(&st, b.handle, "mediated", "you settled my beef with \(a.name)", mood: 2)
            st.aura = min(95, st.aura + 3)
            st.lastAuraDelta = 3
            st.followers += max(1, st.followers / 100)
            var pid: UUID? = nil
            if let news = st.npcs.first(where: { $0.id == "newsdesk" }) {
                var p = makePost(news, "PEACE: \(a.name) and \(b.name) end their feud over \(cause) after \(st.persona.name) stepped in.", st)
                p.tag = "Peace"
                stampPost(&p, st)
                p.likes = max(p.likes * 2, 120)
                st.posts.insert(p, at: 0)
                pid = p.id
            }
            addHistory(&st, "🕊️", "\(st.persona.name) settled \(a.name) vs \(b.name)",
                       "After \(r.heat) rounds over \(cause), \(st.persona.name) got them talking and the feud ended.", post: pid, handles: [a.handle, b.handle])
            logIt(&st, "🕊️", "Settled a feud", "\(a.name) vs \(b.name)", kind: "activity")
            s = st
            return "Feud settled. \(a.name) and \(b.name) both owe you one."
        }
        remember(&st, a.handle, "meddled", "you got involved in my fight with \(b.name)", mood: -1)
        remember(&st, b.handle, "meddled", "you got involved in my fight with \(a.name)", mood: -1)
        st.aura = max(5, st.aura - 1)
        st.lastAuraDelta = -1
        s = st
        return "They didn't want to hear it. Both are annoyed you got involved."
    }
}

// MARK: - Feuds in the NPC sheet

struct FeudBlock: View {
    @EnvironmentObject var game: Game
    let handle: String

    var body: some View {
        let st = game.s
        let mine = game.activeFeuds(st).filter { $0.a == handle || $0.b == handle }
        if !mine.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(mine) { r in
                    let other = r.a == handle ? r.b : r.a
                    let o = st.npcs.first { $0.handle == other }
                    HStack(spacing: 6) {
                        Text("⚔️").font(.jk(12))
                        Text("Feuding with \(o?.name ?? other) · \(game.feudLabel(r.rel ?? 0))")
                            .font(.jk(13)).foregroundColor(T.orange)
                    }
                }
            }.padding(.horizontal, 28)
        }
    }
}
