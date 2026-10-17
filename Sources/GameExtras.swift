import SwiftUI

// MARK: - Store items

enum StoreItem: String, CaseIterable, Identifiable {
    case energy, coffee, gift, viral, boost
    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy: return "Energy"
        case .coffee: return "Coffee"
        case .gift: return "Gift"
        case .viral: return "Viral Moment"
        case .boost: return "Clout Boost"
        }
    }
    var desc: String {
        switch self {
        case .energy: return "Add more in-game actions"
        case .coffee: return "Add 8 energy to your bonus actions"
        case .gift: return "A gift to send to a character to boost your relationship."
        case .viral: return "Greatly boost the outcomes of your next action"
        case .boost: return "Boost the outcomes of your actions for the next 15 minutes"
        }
    }
    var price: Int {
        switch self {
        case .energy: return 3
        case .coffee: return 24
        case .gift: return 6
        case .viral: return 2
        case .boost: return 12
        }
    }
    var emoji: String {
        switch self {
        case .energy: return "⚡️"
        case .coffee: return "☕️"
        case .gift: return "💝"
        case .viral: return "💣"
        case .boost: return "🧪"
        }
    }
}

// MARK: - Extra game systems: gems, streaks, boosts, stories, undo

extension Game {
    static func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    func showToast(_ m: String) {
        toast = m
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if self.toast == m { self.toast = nil }
        }
    }

    // MARK: Boost multiplier

    /// Consumes a Viral Moment if armed, otherwise applies an active Clout Boost.
    func takePower(_ st: inout GameState) -> Double {
        if st.ex.viralArmed {
            st.ex.viralArmed = false
            return 3.0
        }
        if let b = st.ex.boostUntil, b > Date() { return 1.5 }
        return 1.0
    }

    // MARK: Outcome copy

    func outcomeText(_ st: GameState, followers: Int, aura: Int, story: Bool) -> String {
        let what = story ? "story" : "post"
        let topic = Topics.forWorld(st.world).first ?? "the scene"
        let who = st.npcs.filter { $0.id != "newsdesk" }.randomElement()?.name ?? "someone"
        let pool: [String]
        if aura == 0 {
            pool = [
                "Following your \(what), a handful of \(topic) fans quietly hit follow.",
                "After your \(what), \(who) passed it around and new faces started trickling in.",
                "Your \(what) travelled further than expected. \(short(abs(followers))) people decided you were worth following."
            ]
        } else if aura > 0 {
            pool = [
                "Your \(what) landed well. The timeline gave you the benefit of the doubt.",
                "Following your \(what), \(who) and a few others dropped in with good energy.",
                "People in the \(topic) corner of your world are starting to take you seriously."
            ]
        } else {
            pool = [
                "Following your \(what), the comments section turned into a chaotic dance of nitpicks and side-eyes.",
                "Not everyone liked that. \(who) is already drafting a response.",
                "The replies got spicy. Your aura took a small hit."
            ]
        }
        return pool.randomElement() ?? ""
    }

    // MARK: Streak

    func checkStreak() {
        guard playing else { return }
        var st = s
        let today = Game.dayKey(Date())
        if st.ex.lastStreakDay == today { return }
        let had = st.ex.lastStreakDay
        var yKey = ""
        if let y = Calendar.current.date(byAdding: .day, value: -1, to: Date()) { yKey = Game.dayKey(y) }
        if had.isEmpty {
            st.ex.streak = 1
        } else if had == yKey {
            st.ex.streak += 1
            var gems = 1
            switch st.ex.streak {
            case 3: gems += 3
            case 7: gems += 5
            case 14: gems += 8
            case 30: gems += 15
            default: break
            }
            st.ex.gems += gems
            notify(&st, "milestone", "\(st.ex.streak) day streak", sub: "+\(gems) gems for coming back", emoji: "🔥")
        } else {
            st.ex.streak = 1
        }
        st.ex.lastStreakDay = today
        s = st
    }

    // MARK: Store

    @discardableResult
    func buy(_ item: StoreItem) -> Bool {
        var st = s
        if item == .viral && st.ex.viralArmed {
            showToast("Viral Moment is already armed")
            return false
        }
        guard st.ex.gems >= item.price else {
            showToast("Not enough gems")
            return false
        }
        switch item {
        case .energy: st.bonus += 1
        case .coffee: st.bonus += 8
        case .gift: st.ex.gifts += 1
        case .viral: st.ex.viralArmed = true
        case .boost:
            let base = max(Date(), st.ex.boostUntil ?? Date())
            st.ex.boostUntil = base.addingTimeInterval(15 * 60)
        }
        st.ex.gems -= item.price
        s = st
        showToast("\(item.title) added")
        return true
    }

    func sendGift(_ handle: String) {
        var st = s
        guard st.ex.gifts > 0, let j = st.npcs.firstIndex(where: { $0.handle == handle }) else { return }
        st.ex.gifts -= 1
        st.npcs[j].affinity = min(100, st.npcs[j].affinity + 15)
        let n = st.npcs[j]
        if n.affinity >= 40, !n.followsYou {
            st.npcs[j].followsYou = true
            notify(&st, "follow", "\(n.name) is now following you", sub: n.bio, handle: n.handle, emoji: n.emoji)
        }
        remember(&st, n.handle, "gift", "you sent me a gift", mood: 2)
        logIt(&st, "💝", "Sent a gift to \(n.name)", "gift")
        s = st
        showToast("Gift sent to \(n.name)")
    }

    // MARK: Milestones with points

    func pointsNeeded(_ m: Milestone, _ st: GameState) -> Int {
        var total = 0
        for r in m.reqs where st.skills.indices.contains(r.skill) {
            total += max(0, r.level - st.skills[r.skill].value)
        }
        return total
    }

    func claimWithPoints(_ id: UUID) {
        var st = s
        guard let i = st.milestones.firstIndex(where: { $0.id == id }), !st.milestones[i].done else { return }
        let m = st.milestones[i]
        let need = pointsNeeded(m, st)
        guard need <= st.points else {
            showToast("You need \(need) skill points")
            return
        }
        for r in m.reqs where st.skills.indices.contains(r.skill) {
            let miss = max(0, r.level - st.skills[r.skill].value)
            st.skills[r.skill].value += miss
        }
        st.points -= need
        s = st
        claim(id)
    }

    // MARK: Undo

    func undo() {
        guard let snap = undoSnap else { return }
        s = snap
        undoSnap = nil
        pendingResult = nil
        showToast("Undid last action")
    }

    // MARK: Stories

    @discardableResult
    func postStory(id: UUID, text: String, bg: Int, hasImage: Bool) -> UUID? {
        let t = text.trimmed
        guard !t.isEmpty || hasImage else { return nil }
        let snap = s
        guard spend(1) else {
            showToast("Not enough energy")
            return nil
        }
        undoSnap = snap
        var st = s
        let delta = Int.random(in: -2...3)
        let power = takePower(&st)
        let comments = makeComments(st, auraDelta: delta, count: Int.random(in: 6...10), text: t, angry: ContentPrefs.isHostile(t))
        let story = UserStory(id: id, text: t, bg: bg, hasImage: hasImage, day: st.day, comments: comments)
        st.ex.stories.insert(story, at: 0)
        if st.ex.stories.count > 30 { st.ex.stories.removeLast(st.ex.stories.count - 30) }

        let before = st.followers
        st.followers += max(1, Int(Double(st.followers) * 0.01 * power))
        st.aura += delta
        st.lastAuraDelta = delta
        st.stats["charm"] = min(100, (st.stats["charm"] ?? 30) + 1)
        st.ex.statDelta["charm"] = 1
        st.ex.statNote["charm"] = "Your story kept the cast talking."
        gainXP(&st, 5)

        let first = comments.first
        notify(&st, "story", "\(Game.joinNames(comments.map { $0.handle })) replied to your private story",
               sub: first?.text ?? "", handle: first?.handle ?? "", emoji: first?.emoji ?? "💬")
        if !st.notifs.isEmpty { st.notifs[0].ref = story.id }

        _ = settleAura(&st)
        let label = t.isEmpty ? "Photo story" : t
        logIt(&st, "📸", "Story", "story", kind: "story", ref: story.id, body: label)
        logIt(&st, "🌟", "Aura", "story", kind: "outcome", ref: story.id,
              body: outcomeText(st, followers: 0, aura: delta == 0 ? 1 : delta, story: true),
              delta: Double(delta), handle: first?.handle)
        let net = st.followers - before
        if net > 0 {
            logIt(&st, "👥", "Followers", "story", kind: "outcome", ref: story.id,
                  body: outcomeText(st, followers: net, aura: 0, story: true),
                  delta: Double(net), handle: comments.last?.handle)
        }

        let sid = st.id
        s = st
        checkBadges()
        fetchStoryReplies(storyID: id, text: label, sid: sid, delta: delta)
        return id
    }

    private func fetchStoryReplies(storyID: UUID, text: String, sid: UUID, delta: Int) {
        guard aiOK, let i = saveIndex(sid) else { return }
        let (sys, usr) = AIPrompt.replies(store.saves[i], text: text, delta: delta)
        Task {
            do {
                let items = try await AI.generateReplies(system: sys, user: usr)
                self.applyStoryReplies(items, storyID, sid)
            } catch {
                self.markDown()
            }
        }
    }

    private func applyStoryReplies(_ items: [AI.GenReply], _ storyID: UUID, _ sid: UUID) {
        guard let k = saveIndex(sid) else { return }
        var st = store.saves[k]
        guard let i = st.ex.stories.firstIndex(where: { $0.id == storyID }) else { return }
        var out: [Comment] = []
        for r in items {
            guard let n = st.npcs.first(where: { $0.handle == r.handle && $0.id != "newsdesk" }) else { continue }
            out.append(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: r.text, verified: n.followers >= 40000))
        }
        guard !out.isEmpty else { return }
        // Keep anything the player already wrote.
        let mine = st.ex.stories[i].comments.filter { $0.handle == st.persona.handle }
        st.ex.stories[i].comments = out + mine
        store.saves[k] = st
    }

    @discardableResult
    func commentOnStory(_ id: UUID, text: String, replyTo: String? = nil) -> Bool {
        let t = text.trimmed
        guard !t.isEmpty, s.ex.stories.contains(where: { $0.id == id }) else { return false }
        guard spend(1) else {
            showToast("Not enough energy")
            return false
        }
        var st = s
        guard let i = st.ex.stories.firstIndex(where: { $0.id == id }) else { return false }
        st.ex.stories[i].comments.append(Comment(name: st.persona.name, handle: st.persona.handle, emoji: st.persona.emoji, text: t))
        gainXP(&st, 2)
        let sid = st.id
        s = st
        scheduleChain(sid: sid, host: .story(id), target: replyTo, playerText: t)
        return true
    }

    func deleteStory(_ id: UUID) {
        var st = s
        st.ex.stories.removeAll { $0.id == id }
        s = st
        StoryImages.remove(id)
    }

    // MARK: Character-to-character chains (offline engine)

    enum ChainHost {
        case post(UUID)
        case story(UUID)
    }

    func offlineDM(_ n: NPC, text: String, _ st: GameState) -> String {
        var warm = n.affinity >= 50
        if n.affinity < 50 && n.affinity >= 30 { warm = Bool.random() }
        if n.trait == .hater && n.affinity < 70 { warm = Double.random(in: 0...1) < 0.2 }
        return voiceLine(st, n, bucket: warm ? "dm.warm" : "dm.cold", target: nil, toPlayer: true, text: text, heat: 0.45, angry: ContentPrefs.isHostile(text))?.0
            ?? (Lines.dm[n.trait]?.randomElement() ?? "👀")
    }

    /// Builds the replies a player's comment would trigger: the addressed character answers, then others pile on each other.
    private func buildChain(_ st: GameState, target: String?, playerText: String) -> [Comment] {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard !cast.isEmpty else { return [] }
        let me = st.persona.handle
        var mention: String? = target
        if mention == nil, let w = playerText.split(separator: " ").first, w.hasPrefix("@") {
            mention = String(w.dropFirst())
        }
        let first = cast.first(where: { $0.handle == mention }) ?? cast.randomElement()!
        let angry = ContentPrefs.isHostile(playerText)
        var neg: Bool
        if first.affinity >= 55 { neg = Double.random(in: 0...1) < 0.2 }
        else if first.affinity < 35 { neg = Double.random(in: 0...1) < 0.75 }
        else { neg = Bool.random() }
        if first.trait == .hater && first.affinity < 70 { neg = Double.random(in: 0...1) < 0.85 }
        if angry { neg = Double.random(in: 0...1) < (first.trait == .wholesome ? 0.8 : 0.97) }

        var out: [Comment] = []
        var lastNeg: [String: Bool] = [:]
        func add(_ n: NPC, _ body: String) {
            out.append(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: body, verified: n.followers >= 40000))
        }
        let r0 = voiceLine(st, first, bucket: neg ? "comment.neg" : "comment.pos", target: nil, toPlayer: true, text: playerText, heat: angry ? 0.95 : 0.5, angry: angry)
        let l0 = r0?.0 ?? ((neg ? Lines.neg[first.trait] : Lines.pos[first.trait])?.randomElement() ?? "👀")
        if let r = r0 { neg = !r.1 }
        add(first, "@\(me) " + l0)
        lastNeg[first.handle] = neg

        let others = cast.filter { $0.handle != first.handle }.shuffled().prefix(angry ? Int.random(in: 3...5) : Int.random(in: 1...3))
        var prev = first
        for n in others {
            let pn = lastNeg[prev.handle] ?? false
            let myNeg = angry ? Double.random(in: 0...1) < 0.85 : (n.trait == .hater ? Double.random(in: 0...1) < 0.7 : Double.random(in: 0...1) < 0.4)
            let agree = pn == myNeg ? Double.random(in: 0...1) < 0.85 : Double.random(in: 0...1) < 0.15
            let r = voiceLine(st, n, bucket: agree ? "rebut.agree" : "rebut.fight", target: prev.handle, toPlayer: false, text: playerText, heat: angry ? 0.95 : 0.5, angry: angry)
            add(n, "@\(prev.handle) " + (r?.0 ?? (agree ? "exactly this" : "no, that's wrong")))
            lastNeg[n.handle] = r.map { !$0.1 } ?? (agree ? pn : !pn)
            prev = n
        }
        return out
    }

    func scheduleChain(sid: UUID, host: ChainHost, target: String?, playerText: String) {
        guard let k = saveIndex(sid) else { return }
        let comments = buildChain(store.saves[k], target: target, playerText: playerText)
        guard !comments.isEmpty else { return }
        Task {
            for (i, c) in comments.enumerated() {
                let secs = Double.random(in: 1.0...2.4)
                try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
                self.appendChain(sid, host, c, notifyPlayer: i == 0)
            }
        }
    }

    private func appendChain(_ sid: UUID, _ host: ChainHost, _ c: Comment, notifyPlayer: Bool) {
        guard let k = saveIndex(sid) else { return }
        var st = store.saves[k]
        switch host {
        case .post(let id):
            guard let i = st.posts.firstIndex(where: { $0.id == id }) else { return }
            st.posts[i].comments.append(c)
        case .story(let id):
            guard let i = st.ex.stories.firstIndex(where: { $0.id == id }) else { return }
            st.ex.stories[i].comments.append(c)
        }
        if let j = st.npcs.firstIndex(where: { $0.handle == c.handle }) {
            st.npcs[j].affinity = max(0, min(100, st.npcs[j].affinity + 1))
        }
        if notifyPlayer {
            notify(&st, "reply", "\(c.name) replied to your comment", sub: "\(c.handle): \(c.text)", handle: c.handle, emoji: c.emoji)
        }
        store.saves[k] = st
    }
}
