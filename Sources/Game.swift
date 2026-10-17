import SwiftUI

func clampI(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(hi, max(lo, v)) }

@MainActor
final class Game: ObservableObject {
    @Published var store: Store { didSet { schedulePersist(); SyncClient.shared.poke(self) } }
    @Published var typing: Set<String> = []
    @Published var aiNote = ""
    @Published var openChat: String? = nil
    @Published var pendingResult: Outcome? = nil
    @Published var toast: String? = nil
    @Published var profileRev = 0
    @Published var openPostID: UUID? = nil
    @Published var undoSnap: GameState? = nil

    var prefetched: StoryEvent?
    var voice = VoiceStore()
    private var prefetching = false
    private var fetchingPosts = false
    private var aiDownUntil = Date.distantPast
    private var saveTask: Task<Void, Never>?
    private let key = "clout.store.v4"

    init() {
        if let d = UserDefaults.standard.data(forKey: "clout.store.v4"),
           let st = try? JSONDecoder().decode(Store.self, from: d) {
            store = st
        } else {
            store = Store()
        }
        for i in store.saves.indices {
            var st = store.saves[i]
            let w = st.world
            if CastGen.isScene(w), st.ex.castGen != 2 {
                // replace the generic filler characters with scene characters
                let keep = Set(w.cast.map { $0.handle } + ["newsdesk"])
                let gone = Set(st.npcs.filter { !keep.contains($0.handle) && !keep.contains($0.id) }.map { $0.handle })
                if !gone.isEmpty {
                    st.npcs.removeAll { gone.contains($0.handle) }
                    st.ex.npcStories = (st.ex.npcStories ?? []).filter { !gone.contains($0.handle) }
                    st.ex.npcLives = (st.ex.npcLives ?? []).filter { !gone.contains($0.handle) }
                    st.ex.rivalries = (st.ex.rivalries ?? []).filter { !gone.contains($0.a) && !gone.contains($0.b) }
                    st.ex.memories = (st.ex.memories ?? []).filter { !gone.contains($0.handle) }
                }
                st.ex.castGen = 2
            }
            CastGen.pad(&st.npcs, world: w, avoid: [st.persona.handle])
            store.saves[i] = st
        }
        if let d = UserDefaults.standard.data(forKey: "clout.voice.v1"),
           let v = try? JSONDecoder().decode(VoiceStore.self, from: d) { voice = v }
        tickEnergy()
    }

    // MARK: Persistence

    private func schedulePersist() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled { self.flush() }
        }
    }

    func flush() {
        if let d = try? JSONEncoder().encode(store) { UserDefaults.standard.set(d, forKey: key) }
        if let d = try? JSONEncoder().encode(voice) { UserDefaults.standard.set(d, forKey: "clout.voice.v1") }
    }

    // MARK: Active save

    var activeIndex: Int? {
        guard let id = store.activeID else { return nil }
        return store.saves.firstIndex { $0.id == id }
    }
    var playing: Bool { activeIndex != nil }

    var s: GameState {
        get { if let i = activeIndex { return store.saves[i] }; return .blank }
        set { if let i = activeIndex { store.saves[i] = newValue } }
    }

    func saveIndex(_ id: UUID) -> Int? { store.saves.firstIndex { $0.id == id } }

    // MARK: AI availability

    var aiOK: Bool { AIConfig.enabled && Date() > aiDownUntil }
    func markDown() {
        aiDownUntil = Date().addingTimeInterval(60)
        aiNote = "AI is offline right now. Using built-in content."
    }

    func testAI() async -> String {
        do {
            let r = try await AI.chat(system: "Reply with one short word.", user: "Say ok.")
            aiDownUntil = .distantPast
            aiNote = ""
            return "Connected: " + String(r.trimmed.prefix(40))
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: Energy

    static let maxEnergy = 10
    static let regenSeconds: Double = 600

    func tickEnergy() {
        for i in store.saves.indices {
            var st = store.saves[i]
            if st.energy >= Game.maxEnergy { continue }
            let gained = Int(Date().timeIntervalSince(st.lastEnergyTick) / Game.regenSeconds)
            if gained > 0 {
                st.energy = min(Game.maxEnergy, st.energy + gained)
                st.lastEnergyTick = st.lastEnergyTick.addingTimeInterval(Double(gained) * Game.regenSeconds)
                if st.energy >= Game.maxEnergy { st.lastEnergyTick = Date() }
                store.saves[i] = st
            }
        }
    }

    /// Pure display helper: (energy, seconds until next point, or nil if full)
    func liveEnergy(at now: Date) -> (Int, Int?) {
        let st = s
        if st.energy >= Game.maxEnergy { return (Game.maxEnergy, nil) }
        let el = now.timeIntervalSince(st.lastEnergyTick)
        let gained = Int(el / Game.regenSeconds)
        let e = min(Game.maxEnergy, st.energy + max(0, gained))
        if e >= Game.maxEnergy { return (e, nil) }
        let into = el - Double(max(0, gained)) * Game.regenSeconds
        return (e, max(0, Int(Game.regenSeconds - into)))
    }

    func spend(_ n: Int) -> Bool { true }

    func canAfford(_ n: Int) -> Bool {
        return true
    }

    var refillReadyAt: Date { Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "clout.refillAt")) }
    var canRefill: Bool { s.energy < Game.maxEnergy && Date() >= refillReadyAt }
    func refill() {
        guard canRefill else { return }
        var st = s
        st.energy = Game.maxEnergy
        st.lastEnergyTick = Date()
        s = st
        UserDefaults.standard.set(Date().addingTimeInterval(3 * 3600).timeIntervalSince1970, forKey: "clout.refillAt")
    }

    // MARK: XP / notifications

    static func xpNeed(_ level: Int) -> Int { Levels.need(level) }

    func notify(_ st: inout GameState, _ kind: String, _ text: String, sub: String = "", handle: String = "", emoji: String = "🔔") {
        st.notifs.insert(Notif(kind: kind, text: text, sub: sub, handle: handle, emoji: emoji, day: st.day), at: 0)
        if st.notifs.count > 60 { st.notifs.removeLast(st.notifs.count - 60) }
    }

    func gainXP(_ st: inout GameState, _ n: Int) {
        let keys = st.ex.keys?.count ?? 0
        st.xp += n + n * min(40, keys) / 100
        while st.xp >= Game.xpNeed(st.level) {
            st.xp -= Game.xpNeed(st.level)
            st.level += 1
            st.bonus += 1
            applyLevelReward(&st, level: st.level)
        }
        checkKeystones(&st)
    }

    func logIt(_ st: inout GameState, _ emoji: String, _ title: String, _ detail: String,
               kind: String = "activity", ref: UUID? = nil, body: String? = nil,
               delta: Double? = nil, handle: String? = nil) {
        var e = LogEntry(day: st.day, emoji: emoji, title: title, detail: detail)
        e.kind = kind
        e.time = Date()
        e.refID = ref
        e.body = body
        e.delta = delta
        e.handle = handle
        st.log.insert(e, at: 0)
        if st.log.count > 200 { st.log.removeLast(st.log.count - 200) }
    }

    static func joinNames(_ n: [String]) -> String {
        switch n.count {
        case 0: return "Someone"
        case 1: return n[0]
        case 2: return "\(n[0]) and \(n[1])"
        case 3: return "\(n[0]), \(n[1]) and \(n[2])"
        default:
            let rest = n.count - 3
            return "\(n[0]), \(n[1]), \(n[2]) and \(rest == 1 ? "one other" : "\(rest) others")"
        }
    }

    func markNotifsRead() {
        var st = s
        guard st.notifs.contains(where: { $0.unread }) else { return }
        for i in st.notifs.indices { st.notifs[i].unread = false }
        s = st
    }

    var unreadNotifs: Int { s.notifs.filter { $0.unread }.count }

    // MARK: Aura

    func settleAura(_ st: inout GameState) -> (Bool, Bool) {
        if st.aura <= 0 {
            st.followers = max(15, Int(Double(st.followers) * 0.7))
            st.aura = 15
            st.cancelledCount += 1
            notify(&st, "event", "You got cancelled", sub: "Lost 30% of your followers. Aura reset to 15%.", emoji: "🚫")
            addHistory(&st, "🚫", "\(st.persona.name) got cancelled", "The timeline turned on them. Aura reset to 15%.")
            logIt(&st, "🚫", "Cancelled", "Lost 30% of followers")
            return (true, false)
        }
        if st.aura >= 100 {
            st.followers = Int(Double(st.followers) * 1.2)
            st.aura = 70
            st.icon += 1
            notify(&st, "event", "Icon status unlocked", sub: "+20% followers. Aura settled at 70%.", emoji: "👑")
            addHistory(&st, "👑", "\(st.persona.name) reached icon status", "Aura hit 100%. The whole world noticed.")
            logIt(&st, "👑", "Icon status", "+20% followers")
            return (false, true)
        }
        return (false, false)
    }

    // MARK: Text helpers

    func npcName(_ t: Trait, _ st: GameState) -> String {
        st.npcs.first { $0.trait == t && $0.id != "newsdesk" }?.name
            ?? st.npcs.first { $0.id != "newsdesk" }?.name ?? "someone"
    }

    func fill(_ t: String, _ st: GameState) -> String {
        var r = t.replacingOccurrences(of: "{me}", with: st.persona.name)
        for tr in Trait.allCases {
            r = r.replacingOccurrences(of: "{\(tr.rawValue)}", with: npcName(tr, st))
        }
        return r
    }

    func fill(_ t: String) -> String { fill(t, s) }

    // MARK: Starting games / worlds

    func start(world: WorldDef, persona: Persona, asNPC: String? = nil, first: String? = nil, intro: Intro? = nil) {
        var w = world
        w.news.id = "newsdesk"
        var npcs = w.cast
        var followers = 150
        if let h = asNPC, let idx = npcs.firstIndex(where: { $0.handle == h }) {
            followers = max(150, min(5000, npcs[idx].followers / 20))
            npcs.remove(at: idx)
        }
        if let f = first, let j = npcs.firstIndex(where: { $0.handle == f }) {
            npcs[j].followsYou = true
            npcs[j].affinity = 45
        }
        CastGen.pad(&npcs, world: w, avoid: [persona.handle])
        npcs.append(w.news)
        var st = GameState(world: w, persona: persona, followers: followers)
        st.intro = intro ?? fallbackIntro(w, persona)
        st.npcs = npcs
        st.ex.castGen = 2
        st.skills = w.skills
        st.milestones = w.milestones.map { var m = $0; m.done = false; m.skipped = false; return m }
        st.quests = w.quests.map { var q = $0; q.done = false; return q }
        st.posts = fallbackPosts(st, 5)
        notify(&st, "event", "Welcome to \(w.title)", sub: w.goal, emoji: w.emoji)
        if let f = first, let n = st.npcs.first(where: { $0.handle == f }) {
            notify(&st, "follow", "\(n.name) is now following you", sub: n.bio, handle: n.handle, emoji: n.emoji)
        }
        st.ex.lastStreakDay = Game.dayKey(Date())
        store.saves.insert(st, at: 0)
        store.activeID = st.id
        prefetch()
        fetchAIPosts()
    }

    func resume(_ id: UUID) {
        guard saveIndex(id) != nil else { return }
        store.activeID = id
        tickEnergy()
        prefetch()
    }

    func exitToHub() { store.activeID = nil; flush() }

    func deleteSave(_ id: UUID) {
        store.saves.removeAll { $0.id == id }
        if store.activeID == id { store.activeID = nil }
    }

    func savePreset(_ w: WorldDef) {
        store.presets.removeAll { $0.id == w.id }
        store.presets.insert(w, at: 0)
    }

    func deletePreset(_ id: String) { store.presets.removeAll { $0.id == id } }

    func resetAll() {
        store = Store()
        prefetched = nil
        flush()
    }

    func buildWorld(goal: String, setting: String) async -> (WorldDef, Bool) {
        if AIConfig.enabled {
            if let w = try? await AI.generateWorld(goal: goal, setting: setting) { return (w, true) }
            markDown()
        }
        return (WorldDef.generic(goal: goal, setting: setting), false)
    }

    func updateWorld(title: String, goal: String, setting: String) {
        var st = s
        if !title.trimmed.isEmpty { st.world.title = title.trimmed }
        st.world.goal = goal.trimmed
        st.world.setting = setting.trimmed
        s = st
    }

    func updatePersona(_ p: Persona) {
        var st = s
        st.persona = p
        s = st
    }

    // MARK: Feed

    func fallbackPosts(_ st: GameState, _ n: Int) -> [Post] {
        let pool = st.npcs.filter { $0.id != "newsdesk" }.shuffled()
        guard !pool.isEmpty else { return [] }
        let topics = Topics.forWorld(st.world)
        var out: [Post] = []
        for npc in pool.prefix(n) {
            var text: String? = nil
            if Double.random(in: 0...1) < 0.55, let tp = topics.randomElement() {
                text = Corpus.post(trait: npc.trait, me: st.persona.handle, topic: tp)
            }
            if text == nil, Double.random(in: 0...1) < 0.85 { text = Topics.line(trait: npc.trait, topics: topics) }
            if text == nil { text = Lines.feed[npc.trait]?.randomElement() }
            out.append(makePost(npc, text ?? "just vibing", st))
        }
        return out
    }

    func makePost(_ npc: NPC, _ text: String, _ st: GameState) -> Post {
        let likes = max(8, Int(Double(npc.followers) * Double.random(in: 0.01...0.06)))
        let cmts = Int.random(in: 0...2)
        var p = Post(authorHandle: npc.handle, authorName: npc.name, emoji: npc.emoji, text: text,
                     likes: likes, reposts: likes / 8,
                     comments: makeComments(st, auraDelta: 1, count: cmts, exclude: npc.handle, text: text),
                     day: st.day, isYou: false, verified: npc.followers >= 40000 || npc.id == "newsdesk")
        if npc.id != "newsdesk" { decorate(&p, author: npc, st: st) }
        return p
    }

    func makeComments(_ st: GameState, auraDelta: Int, count: Int, exclude: String = "", text: String = "", angry: Bool = false) -> [Comment] {
        let pool = Array(st.npcs.filter { $0.id != "newsdesk" && $0.handle != exclude }.shuffled().prefix(count))
        let heat = auraDelta < 0 ? 0.75 : 0.5
        var out: [Comment] = []
        var negOf: [String: Bool] = [:]
        for n in pool {
            let roll = Double.random(in: 0...1)
            var neg: Bool
            if angry { neg = roll < (n.trait == .wholesome ? 0.8 : 0.96) } else {
            switch n.trait {
            case .hater: neg = roll < 0.82
            case .wholesome: neg = auraDelta < 0 ? roll < 0.35 : roll < 0.06
            case .chaos, .gossip: neg = auraDelta < 0 ? roll < 0.7 : roll < 0.3
            default: neg = auraDelta < 0 ? roll < 0.62 : roll < 0.2
            } }
            var body: String
            if let target = out.randomElement(), Double.random(in: 0...1) < 0.6 {
                let tn = negOf[target.handle] ?? false
                let agree = tn == neg ? Double.random(in: 0...1) < 0.85 : Double.random(in: 0...1) < 0.12
                let bucket = agree ? "rebut.agree" : "rebut.fight"
                let r = voiceLine(st, n, bucket: bucket, target: target.handle, toPlayer: false, text: text, heat: heat, angry: angry)
                body = "@\(target.handle) " + (r?.0 ?? (agree ? "exactly this" : "no, that's wrong"))
                neg = r.map { !$0.1 } ?? (agree ? tn : !tn)
            } else {
                let bucket = neg ? "comment.neg" : "comment.pos"
                let r = voiceLine(st, n, bucket: bucket, target: nil, toPlayer: true, text: text, heat: heat, angry: angry)
                body = r?.0 ?? ((neg ? Lines.neg[n.trait] : Lines.pos[n.trait])?.randomElement() ?? "👀")
                if let r = r { neg = !r.1 }
            }
            negOf[n.handle] = neg
            out.append(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: body, verified: n.followers >= 40000))
        }
        if count >= 2 {
            for c in crowdComments(Int.random(in: 1...max(2, count)), about: text) { out.insert(c, at: Int.random(in: 0...out.count)) }
        }
        return out
    }

    private var lastPostFetch = Date.distantPast

    func refreshFeed(ai: Bool = true) {
        var st = s
        if !aiOK || st.posts.count < 6 {
            st.posts.insert(contentsOf: fallbackPosts(st, 3), at: 0)
            if st.posts.count > 80 { st.posts.removeLast(st.posts.count - 80) }
            s = st
        }
        if ai { fetchAIPosts() }
    }

    func refreshIfStale() {
        if playing, Date().timeIntervalSince(lastPostFetch) > 150 { fetchAIPosts() }
    }

    func fetchAIPosts() {
        guard playing, aiOK, !fetchingPosts else { return }
        fetchingPosts = true
        lastPostFetch = Date()
        let st = s
        let (sys, usr) = AIPrompt.posts(st)
        let sid = st.id
        Task {
            do {
                let items = try await AI.generatePosts(system: sys, user: usr)
                self.applyAIPosts(items, sid)
            } catch {
                self.markDown()
                self.addFallback(sid)
            }
            self.fetchingPosts = false
        }
    }

    private func addFallback(_ sid: UUID) {
        guard let i = saveIndex(sid) else { return }
        var st = store.saves[i]
        st.posts.insert(contentsOf: fallbackPosts(st, 3), at: 0)
        if st.posts.count > 80 { st.posts.removeLast(st.posts.count - 80) }
        store.saves[i] = st
    }

    private func applyAIPosts(_ items: [AI.GenPost], _ sid: UUID) {
        guard let i = saveIndex(sid) else { return }
        var st = store.saves[i]
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        var added: [Post] = []
        for g in items {
            guard let npc = cast.first(where: { $0.handle == g.handle }) ?? cast.randomElement() else { continue }
            var p = makePost(npc, g.text, st)
            p.comments = []
            if let rt = g.rText, let rh = g.rHandle,
               let r = cast.first(where: { $0.handle == rh && $0.handle != npc.handle }) {
                p.comments = [Comment(name: r.name, handle: r.handle, emoji: r.emoji, text: rt, verified: r.followers >= 40000)]
            }
            added.append(p)
        }
        guard !added.isEmpty else { return }
        aiNote = ""
        st.posts.insert(contentsOf: added, at: 0)
        if st.posts.count > 80 { st.posts.removeLast(st.posts.count - 80) }
        store.saves[i] = st
    }

    func like(_ id: UUID) {
        var st = s
        guard let i = st.posts.firstIndex(where: { $0.id == id }) else { return }
        st.posts[i].liked.toggle()
        st.posts[i].likes += st.posts[i].liked ? 1 : -1
        s = st
    }

    func toggleSave(_ id: UUID) {
        var st = s
        if st.saved.contains(id) { st.saved.remove(id) } else { st.saved.insert(id) }
        s = st
    }

    func hide(_ id: UUID) {
        var st = s
        st.hidden.insert(id)
        s = st
    }

    func reply(to id: UUID, text: String) {
        let t = text.trimmed
        guard !t.isEmpty else { return }
        var st = s
        guard let i = st.posts.firstIndex(where: { $0.id == id }) else { return }
        st.posts[i].comments.append(Comment(name: st.persona.name, handle: st.persona.handle, emoji: st.persona.emoji, text: t))
        if let j = st.npcs.firstIndex(where: { $0.handle == st.posts[i].authorHandle }) {
            st.npcs[j].affinity = min(100, st.npcs[j].affinity + 2)
        }
        let replied = st.posts[i]
        rememberReply(&st, post: replied, text: t)
        if ContentPrefs.isHostile(t), let j = st.npcs.firstIndex(where: { $0.handle == replied.authorHandle && $0.id != "newsdesk" }) {
            st.npcs[j].affinity = max(0, st.npcs[j].affinity - 12)
            remember(&st, replied.authorHandle, "insult", "you cussed them out", mood: -3, ref: nil)
        }
        gainXP(&st, 3)
        let sid = st.id
        let target = st.npcs.first(where: { $0.handle == st.posts[i].authorHandle && $0.id != "newsdesk" })?.handle
        s = st
        scheduleChain(sid: sid, host: .post(id), target: target, playerText: t)
    }

    // MARK: Posting

    @discardableResult
    func publish(kind: PostKind, text: String, quest: UUID? = nil, free: Bool = false) -> Outcome? {
        let t = text.trimmed
        guard !t.isEmpty else { return nil }
        let snap = s
        guard free || spend(kind.cost) else { return nil }
        if !free { undoSnap = snap }
        var st = s
        var delta = Int.random(in: kind.aura)
        var squadBoost = false
        if st.ex.squad == true { delta = max(delta, 3) + 2; st.ex.squad = false; squadBoost = true }
        if delta < 0, st.ex.shield == true { delta = 0; st.ex.shield = false; showToast("Cert Shield absorbed the hit") }
        let base = Double(max(30, st.followers)) / 10.0
        var mult = kind.reach * st.persona.vibe.likeMult * Double.random(in: 0.7...1.3)
        mult *= 1 + Double(st.stats["humor"] ?? 30) / 300
        mult *= takePower(&st)
        var likes = max(3, Int(base * mult))
        let viral = Double.random(in: 0...1) < (kind == .drama ? 0.3 : 0.07) + viralBoost(st, t)
        if viral { likes *= 4 }
        if squadBoost { likes *= 2 }
        var gain = max(1, Int(Double(likes) * 0.06 * kind.followMult))
        if delta < 0 { gain = max(1, gain * 3 / 4) }
        let before = st.followers
        let mad = ContentPrefs.isHostile(t) && !squadBoost
        let comments = makeComments(st, auraDelta: mad ? min(delta, -3) : delta, count: Int.random(in: mad ? 6...9 : 4...7), text: t, angry: mad)
        let post = Post(authorHandle: st.persona.handle, authorName: st.persona.name, emoji: st.persona.emoji,
                        text: t, likes: likes, reposts: likes / 7, comments: comments, day: st.day, isYou: true,
                        verified: st.followers >= 10000, viral: viral, tag: kind.label)
        st.posts.insert(post, at: 0)
        st.followers += gain
        st.aura += delta
        st.lastAuraDelta = delta
        st.totalPosts += 1
        bump(&st, "post")
        if viral { st.viralCount += 1 }
        rememberPost(&st, post: post, comments: comments, delta: delta, kind: kind, text: t)
        if viral { goViral(&st, post) }

        let stat: StatKind
        switch kind {
        case .meme: stat = .humor
        case .wholesome, .collab: stat = .charm
        case .hotTake, .drama: stat = .edge
        case .flex: stat = .charm
        case .apology: stat = .mystery
        }
        st.stats[stat.rawValue] = clampI((st.stats[stat.rawValue] ?? 30) + 1, 0, 100)
        st.ex.statDelta[stat.rawValue] = 1
        st.ex.statNote[stat.rawValue] = "\"\(String(t.prefix(32)))\" gave your \(stat.label.lowercased()) a bump."

        var xp = 8 + (viral ? 10 : 0)
        if let qid = quest, let qi = st.quests.firstIndex(where: { $0.id == qid && !$0.done }) {
            st.quests[qi].done = true
            xp += st.quests[qi].xp
            notify(&st, "milestone", "Side quest complete", sub: st.quests[qi].text, emoji: "✅")
        }
        gainXP(&st, xp)

        if kind == .collab, let i = st.npcs.indices.filter({ !st.npcs[$0].followsYou && st.npcs[$0].id != "newsdesk" }).randomElement() {
            st.npcs[i].followsYou = true
            notify(&st, "follow", "\(st.npcs[i].name) followed you", sub: "@\(st.npcs[i].handle)", handle: st.npcs[i].handle, emoji: st.npcs[i].emoji)
        }
        if let c = comments.first {
            notify(&st, "reply", "\(Game.joinNames(comments.map { $0.name })) replied to you",
                   sub: "\(c.handle): \(c.text)", handle: c.handle, emoji: c.emoji)
        }
        let (cancelled, icon) = settleAura(&st)
        let netNow = st.followers - before
        logIt(&st, kind.icon, st.persona.name, kind.label, kind: "post", ref: post.id, body: t, handle: st.persona.handle)
        if netNow != 0 {
            logIt(&st, "👥", "Followers", "post", kind: "outcome", ref: post.id,
                  body: outcomeText(st, followers: netNow, aura: 0, story: false), delta: Double(netNow), handle: comments.first?.handle)
        }
        if delta != 0 {
            logIt(&st, "🌟", "Aura", "post", kind: "outcome", ref: post.id,
                  body: outcomeText(st, followers: 0, aura: delta, story: false), delta: Double(delta), handle: comments.last?.handle)
        }
        let net = st.followers - before
        let auraNow = st.aura
        let sid = st.id
        s = st
        checkBadges()
        fetchReplies(postID: post.id, text: t, sid: sid, delta: delta)

        var detail = "+\(short(likes)) likes · \(net >= 0 ? "+" : "")\(short(net)) followers · aura \(delta >= 0 ? "+" : "")\(delta)%"
        var title = viral ? "Went viral!" : "Posted"
        var emoji = viral ? "🔥" : kind.icon
        if cancelled { title = "Cancelled"; emoji = "🚫"; detail = "Aura hit 0. Lost 30% of followers." }
        if icon { title = "Icon status!"; emoji = "👑"; detail = "Aura hit 100%. +20% followers." }
        let good = ["That one landed.", "People are talking.", "Quietly effective.", "The timeline noticed.", "Sowing seeds is always a vibe."]
        let bad = ["Not everyone liked that.", "Bold. Risky.", "The replies are getting spicy.", "That might come back to haunt you."]
        var o = Outcome(emoji: emoji, title: title, detail: detail)
        o.xp = xp
        o.auraDelta = delta
        o.auraAfter = auraNow
        o.postID = post.id
        o.line = (delta >= 0 ? good : bad).randomElement() ?? ""
        o.ups = ["\(stat.label) ↑", net >= 0 ? "Followers ↑" : "Followers ↓"]
        return o
    }

    // MARK: Replies to your posts (AI)

    private func fetchReplies(postID: UUID, text: String, sid: UUID, delta: Int) {
        guard aiOK, let i = saveIndex(sid) else { return }
        let (sys, usr) = AIPrompt.replies(store.saves[i], text: text, delta: delta)
        Task {
            do {
                let items = try await AI.generateReplies(system: sys, user: usr)
                self.applyReplies(items, postID, sid)
            } catch {
                self.markDown()
            }
        }
    }

    private func applyReplies(_ items: [AI.GenReply], _ postID: UUID, _ sid: UUID) {
        guard let i = saveIndex(sid) else { return }
        var st = store.saves[i]
        guard let pi = st.posts.firstIndex(where: { $0.id == postID }) else { return }
        var out: [Comment] = []
        for r in items {
            guard let n = st.npcs.first(where: { $0.handle == r.handle && $0.id != "newsdesk" }) else { continue }
            out.append(Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: r.text, verified: n.followers >= 40000))
        }
        guard !out.isEmpty else { return }
        st.posts[pi].comments = out
        store.saves[i] = st
    }

    // MARK: Intro

    func buildIntro(world: WorldDef, persona: Persona) async -> Intro? {
        guard AIConfig.enabled else { return nil }
        let (sys, usr) = AIPrompt.intro(world, persona)
        return try? await AI.generateIntro(system: sys, user: usr)
    }

    private func fallbackIntro(_ w: WorldDef, _ p: Persona) -> Intro {
        let t = Topics.forWorld(w).first ?? "the scene"
        let tag = w.tagline.isEmpty ? "" : w.tagline + " "
        return Intro(story: "Welcome to \(w.title).\n\n\(tag)As @\(p.handle), you're chasing one thing: \(w.goal)",
                     questText: w.quests.first?.text ?? "Introduce yourself to the timeline.",
                     questPost: "new here. came for \(t), staying until people know my name.")
    }

    func publishIntro() -> Outcome? {
        guard var it = s.intro, !it.done else { return nil }
        let o = publish(kind: .meme, text: it.questPost, free: true)
        it.done = true
        s.intro = it
        pendingResult = o
        return o
    }

    // MARK: Events

    func ensureEvent() {
        guard playing, s.currentEvent == nil, s.result == nil else { return }
        if let p = prefetched {
            s.currentEvent = p
            prefetched = nil
        } else {
            useScripted()
        }
        prefetch()
    }

    private func useScripted() {
        var st = s
        let pool = Story.all.filter { !st.seen.contains($0.id) }
        let e: StoryEvent
        if let p = pool.randomElement() {
            e = p
        } else {
            st.seen = []
            e = Story.all[Int.random(in: 0..<Story.all.count)]
        }
        st.seen.append(e.id)
        st.currentEvent = e
        s = st
    }

    func prefetch() {
        guard playing, aiOK, prefetched == nil, !prefetching else { return }
        prefetching = true
        let (sys, usr) = AIPrompt.event(s)
        Task {
            do {
                self.prefetched = try await AI.generateEvent(system: sys, user: usr)
            } catch {
                self.markDown()
            }
            self.prefetching = false
        }
    }

    func choose(_ i: Int) {
        var st = s
        guard let e = st.currentEvent, st.result == nil, e.choices.indices.contains(i) else { return }
        let c = e.choices[i]
        undoSnap = st
        let before = st.followers
        st.aura += c.aura
        st.lastAuraDelta = c.aura
        st.followers = max(0, Int((Double(st.followers) * (1 + c.fol / 100)).rounded()))

        var sc: [StatChange] = []
        for d in c.stats {
            st.stats[d.kind.rawValue] = clampI((st.stats[d.kind.rawValue] ?? 30) + d.v * 2, 0, 100)
            sc.append(StatChange(kind: d.kind, up: d.v > 0))
        }
        var nc: [NPCChange] = []
        for d in c.npc {
            for j in st.npcs.indices where st.npcs[j].trait == d.trait && st.npcs[j].id != "newsdesk" {
                st.npcs[j].affinity = clampI(st.npcs[j].affinity + d.d * 8, 0, 100)
                nc.append(NPCChange(emoji: st.npcs[j].emoji, handle: st.npcs[j].handle, up: d.d > 0))
                if d.d > 0, st.npcs[j].affinity >= 40, !st.npcs[j].followsYou {
                    st.npcs[j].followsYou = true
                    notify(&st, "follow", "\(st.npcs[j].name) followed you", sub: "@\(st.npcs[j].handle)", handle: st.npcs[j].handle, emoji: st.npcs[j].emoji)
                }
            }
        }

        if let news = st.npcs.first(where: { $0.id == "newsdesk" }) {
            let likes = max(40, Int(Double(max(st.followers, 100)) * Double.random(in: 0.2...0.6)))
            var p = makePost(news, fill(c.news, st), st)
            p.likes = likes
            p.reposts = likes / 6
            p.tag = "Breaking"
            st.posts.insert(p, at: 0)
        }

        let (cancelled, icon) = settleAura(&st)
        let rec = ResultRecord(emoji: e.emoji, text: fill(c.result, st), auraDelta: c.aura, auraAfter: st.aura,
                               followerDelta: st.followers - before, stats: sc, npcs: nc,
                               cancelled: cancelled, iconUnlocked: icon)
        logIt(&st, e.emoji, "Event", String(fill(e.text, st).prefix(80)))
        st.recent.append(String(fill(e.text, st).prefix(100)))
        if st.recent.count > 6 { st.recent.removeFirst(st.recent.count - 6) }
        st.eventsDone += 1
        gainXP(&st, 15 + max(0, c.aura))
        scheduleChain(&st, npc: nc.first?.handle, choice: fill(c.text, st))
        st.result = rec
        s = st
        checkBadges()
    }

    func continueStory() {
        var st = s
        st.day += 1
        st.currentEvent = nil
        st.result = nil
        if Bool.random(),
           let i = st.npcs.indices.filter({ !st.npcs[$0].followsYou && st.npcs[$0].id != "newsdesk" }).randomElement() {
            st.npcs[i].followsYou = true
            notify(&st, "follow", "\(st.npcs[i].name) followed you", sub: "@\(st.npcs[i].handle)", handle: st.npcs[i].handle, emoji: st.npcs[i].emoji)
        }
        s = st
        refreshFeed()
        prefetch()
    }

    // MARK: DMs

    func startChat(_ handle: String) {
        var st = s
        if st.threads[handle] == nil {
            st.threads[handle] = []
            s = st
        }
    }

    func markChatRead(_ handle: String) {
        if s.unread.contains(handle) {
            var st = s
            st.unread.remove(handle)
            s = st
        }
    }

    func sendDM(handle: String, text: String) {
        let t = text.trimmed
        guard !t.isEmpty, !typing.contains(handle) else { return }
        var st = s
        guard let n = st.npcs.first(where: { $0.handle == handle }) else { return }
        st.threads[handle, default: []].append(DMMessage(fromYou: true, text: t))
        logIt(&st, "💬", "Messaged \(n.name)", "dm", kind: "dm", body: t, handle: n.handle)
        remember(&st, n.handle, "chat", "you actually texted me", mood: 1)
        s = st
        typing.insert(handle)
        let sid = st.id
        let hist = st.threads[handle] ?? []
        let (sys, usr) = AIPrompt.dm(st, npc: n, history: hist)
        let useAI = aiOK
        let offline = offlineDM(n, text: t, st)
        Task {
            var reply: String? = nil
            if useAI {
                do { reply = try await AI.reply(system: sys, user: usr) } catch { self.markDown() }
            }
            if reply == nil { try? await Task.sleep(nanoseconds: 1_300_000_000) }
            let msg = reply ?? offline
            self.deliver(sid, handle, msg)
        }
    }

    private func deliver(_ sid: UUID, _ handle: String, _ text: String) {
        typing.remove(handle)
        guard let i = saveIndex(sid) else { return }
        var st = store.saves[i]
        st.threads[handle, default: []].append(DMMessage(fromYou: false, text: text))
        if let j = st.npcs.firstIndex(where: { $0.handle == handle }) {
            st.npcs[j].affinity = min(100, st.npcs[j].affinity + 3)
        }
        if openChat != handle { st.unread.insert(handle) }
        store.saves[i] = st
    }

    // MARK: Goals

    func upgrade(_ skillID: UUID) {
        var st = s
        guard let i = st.skills.firstIndex(where: { $0.id == skillID }), st.skills[i].value < 100 else { return }
        let cost = Levels.skillCost(st.skills[i].value)
        guard st.points >= cost else { showToast("Need \(cost) skill points"); return }
        st.skills[i].value += 1
        st.points -= cost
        checkKeystones(&st)
        s = st
    }

    func canClaim(_ m: Milestone, _ st: GameState) -> Bool {
        m.reqs.allSatisfy { r in
            st.skills.indices.contains(r.skill) && st.skills[r.skill].value >= r.level
        }
    }

    var nextMilestone: Milestone? { s.milestones.first { !$0.done && !$0.skipped } }

    var goalProgress: Double {
        let ms = s.milestones
        guard !ms.isEmpty else { return 0 }
        return Double(ms.filter { $0.done || $0.skipped }.count) / Double(ms.count)
    }

    func claim(_ id: UUID) {
        var st = s
        guard let i = st.milestones.firstIndex(where: { $0.id == id }), !st.milestones[i].done,
              canClaim(st.milestones[i], st) else { return }
        st.milestones[i].done = true
        st.followers = Int(Double(st.followers) * 1.15)
        st.bonus += 1
        st.ex.gems += 3
        notify(&st, "milestone", "Milestone reached", sub: st.milestones[i].text, emoji: "🏁")
        addHistory(&st, "🏁", "Milestone reached", st.milestones[i].text)
        logIt(&st, "🏁", "Milestone", st.milestones[i].text)
        gainXP(&st, 40)
        s = st
        checkBadges()
    }

    func skip(_ id: UUID) {
        var st = s
        guard let i = st.milestones.firstIndex(where: { $0.id == id }), !st.milestones[i].done else { return }
        st.milestones[i].skipped = true
        s = st
    }

    // MARK: Badges

    static let badgeDefs: [Badge] = [
        Badge(id: "first", title: "First Post", emoji: "🎉"),
        Badge(id: "k1", title: "1K Followers", emoji: "🌱"),
        Badge(id: "k10", title: "10K Followers", emoji: "📈"),
        Badge(id: "k100", title: "100K Followers", emoji: "💯"),
        Badge(id: "m1", title: "1M Followers", emoji: "🏆"),
        Badge(id: "viral", title: "Went Viral", emoji: "🔥"),
        Badge(id: "icon", title: "Icon Status", emoji: "👑"),
        Badge(id: "cancel", title: "Got Cancelled", emoji: "🚫"),
        Badge(id: "lvl5", title: "Level 5", emoji: "⭐️"),
        Badge(id: "goal", title: "Goal Reached", emoji: "🎯")
    ]

    func checkBadges() {
        var st = s
        var earned: [String] = []
        if st.totalPosts >= 1 { earned.append("first") }
        if st.followers >= 1000 { earned.append("k1") }
        if st.followers >= 10_000 { earned.append("k10") }
        if st.followers >= 100_000 { earned.append("k100") }
        if st.followers >= 1_000_000 { earned.append("m1") }
        if st.viralCount > 0 { earned.append("viral") }
        if st.icon > 0 { earned.append("icon") }
        if st.cancelledCount > 0 { earned.append("cancel") }
        if st.level >= 5 { earned.append("lvl5") }
        if !st.milestones.isEmpty && st.milestones.allSatisfy({ $0.done || $0.skipped }) { earned.append("goal") }
        var changed = false
        for id in earned where !st.achievements.contains(id) {
            st.achievements.insert(id)
            changed = true
            if let b = Game.badgeDefs.first(where: { $0.id == id }) {
                notify(&st, "milestone", "Achievement: \(b.title)", emoji: b.emoji)
            }
        }
        if changed { s = st }
    }
}
