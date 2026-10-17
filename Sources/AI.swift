import Foundation

// MARK: - Config (keys match @AppStorage in Settings)

enum AIConfig {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "ai.enabled") as? Bool ?? true }
    static var customURL: String { (UserDefaults.standard.string(forKey: "ai.url") ?? "").trimmed }
    static var customModel: String { (UserDefaults.standard.string(forKey: "ai.model") ?? "").trimmed }
    static var key: String { (UserDefaults.standard.string(forKey: "ai.key") ?? "").trimmed }
}

enum AIError: LocalizedError {
    case http(Int), badResponse, badEvent, badURL
    var errorDescription: String? {
        switch self {
        case .http(let c): return "HTTP \(c)"
        case .badResponse: return "bad response"
        case .badEvent: return "unreadable result"
        case .badURL: return "bad URL"
        }
    }
}

struct AIProvider {
    let name: String
    let url: String
    let model: String
    let key: String
}

// MARK: - Client

enum AI {
    private static var lastCall = Date.distantPast
    private static var preferred = 0

    /// Free endpoints rate-limit anonymous callers, so space requests out.
    private static func throttle() async {
        let gap: TimeInterval = 4
        let wait = gap - Date().timeIntervalSince(lastCall)
        lastCall = Date().addingTimeInterval(max(0, wait))
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
    }

    /// Provider chain: your own endpoint first (if set), then free keyless public ones.
    private static func chain() -> [AIProvider] {
        var l: [AIProvider] = []
        if !AIConfig.customURL.isEmpty {
            l.append(AIProvider(name: "custom", url: AIConfig.customURL,
                                model: AIConfig.customModel.isEmpty ? "gpt-4o-mini" : AIConfig.customModel,
                                key: AIConfig.key))
        }
        l.append(AIProvider(name: "llm7", url: "https://api.llm7.io/v1/chat/completions", model: "gpt-oss", key: "unused"))
        l.append(AIProvider(name: "pollinations", url: "https://text.pollinations.ai/openai", model: "openai", key: AIConfig.key))
        l.append(AIProvider(name: "llm7-mistral", url: "https://api.llm7.io/v1/chat/completions", model: "mistral-Nemo-Instruct-2407", key: "unused"))
        return l
    }

    static func chat(system: String, user: String, timeout: TimeInterval = 28) async throws -> String {
        await throttle()
        let providers = chain()
        var lastError: Error = AIError.badResponse
        for off in 0..<providers.count {
            let idx = (preferred + off) % providers.count
            do {
                let r = try await post(providers[idx], system: system, user: user, timeout: timeout)
                preferred = idx
                return r
            } catch {
                lastError = error
            }
        }
        if let r = try? await getSimple(system: system, user: user, timeout: timeout), !r.trimmed.isEmpty { return r }
        throw lastError
    }

    private static func post(_ p: AIProvider, system: String, user: String, timeout: TimeInterval) async throws -> String {
        guard let url = URL(string: p.url) else { throw AIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !p.key.isEmpty { req.setValue("Bearer \(p.key)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = [
            "model": p.model,
            "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "temperature": 0.95,
            "private": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIError.http(http.statusCode) }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = obj["choices"] as? [[String: Any]],
           let msg = choices.first?["message"] as? [String: Any],
           let content = msg["content"] as? String, !content.trimmed.isEmpty {
            return content
        }
        if let text = String(data: data, encoding: .utf8), !text.trimmed.isEmpty, !text.trimmed.hasPrefix("{\"") { return text }
        throw AIError.badResponse
    }

    private static func getSimple(system: String, user: String, timeout: TimeInterval) async throws -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#&%+")
        let prompt = (system + "\n\n" + user).addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        guard let url = URL(string: "https://text.pollinations.ai/\(prompt)?model=openai&private=true") else { throw AIError.badURL }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIError.http(http.statusCode) }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func jsonData(_ raw: String) -> Data? {
        guard let a = raw.firstIndex(of: "{"), let b = raw.lastIndex(of: "}"), a < b else { return nil }
        return String(raw[a...b]).data(using: .utf8)
    }

    private static func clean(_ s: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")
        return String(s.lowercased().filter { allowed.contains($0) })
    }

    private static func oneEmoji(_ s: String?, _ fallback: String) -> String {
        let t = (s ?? "").trimmed
        if let c = t.first { return String(c) }
        return fallback
    }

    // MARK: Event

    private struct DTOChoice: Decodable {
        var text: String
        var result: String
        var news: String?
        var aura: Double?
        var fol: Double?
        var stats: [String: Double]?
        var npc: [String: Double]?
    }
    private struct DTOEvent: Decodable {
        var emoji: String?
        var text: String
        var choices: [DTOChoice]
    }

    static func generateEvent(system: String, user: String) async throws -> StoryEvent {
        let raw = try await chat(system: system, user: user)
        guard let e = parseEvent(raw) else { throw AIError.badEvent }
        return e
    }

    static func parseEvent(_ raw: String) -> StoryEvent? {
        guard let data = jsonData(raw), let dto = try? JSONDecoder().decode(DTOEvent.self, from: data) else { return nil }
        guard !dto.text.trimmed.isEmpty, dto.choices.count >= 3 else { return nil }
        var choices: [Choice] = []
        for c in dto.choices.prefix(3) {
            guard !c.text.trimmed.isEmpty, !c.result.trimmed.isEmpty else { return nil }
            let aura = Int(min(12, max(-12, (c.aura ?? 0).rounded())))
            let fol = min(25, max(-20, c.fol ?? 0))
            var stats: [StatDelta] = []
            for (k, v) in c.stats ?? [:] {
                if let kind = StatKind(rawValue: k.lowercased()) {
                    stats.append(StatDelta(kind: kind, v: Int(min(6, max(-6, v.rounded())))))
                }
            }
            var npcs: [NPCDelta] = []
            for (k, v) in c.npc ?? [:] {
                if let t = Trait(rawValue: k.lowercased()) { npcs.append(NPCDelta(trait: t, d: v >= 0 ? 1 : -1)) }
            }
            let news = (c.news ?? "").trimmed.isEmpty ? "{me} is trending" : (c.news ?? "").trimmed
            choices.append(Choice(text: c.text.trimmed, result: c.result.trimmed, news: news,
                                  aura: aura, fol: fol, stats: stats, npc: npcs))
        }
        return StoryEvent(id: "ai-" + UUID().uuidString, emoji: oneEmoji(dto.emoji, "🎭"),
                          text: dto.text.trimmed, choices: choices, ai: true)
    }

    // MARK: World

    private struct WNPC: Decodable { var name: String; var handle: String?; var emoji: String?; var bio: String?; var trait: String?; var followers: Double? }
    private struct WSkill: Decodable { var name: String; var desc: String? }
    private struct WReq: Decodable { var skill: Int; var level: Int }
    private struct WMile: Decodable { var text: String; var reqs: [WReq]? }
    private struct WNews: Decodable { var name: String?; var handle: String?; var emoji: String? }
    private struct WWorld: Decodable {
        var title: String?
        var emoji: String?
        var tagline: String?
        var cast: [WNPC]
        var news: WNews?
        var skills: [WSkill]?
        var milestones: [WMile]?
        var quests: [String]?
    }

    static func generateWorld(goal: String, setting: String) async throws -> WorldDef {
        let (system, user) = AIPrompt.world(goal: goal, setting: setting)
        let raw = try await chat(system: system, user: user, timeout: 45)
        guard let data = jsonData(raw), let w = try? JSONDecoder().decode(WWorld.self, from: data), w.cast.count >= 4 else {
            throw AIError.badEvent
        }
        var used: Set<String> = ["newsdesk"]
        var cast: [NPC] = []
        for c in w.cast.prefix(6) {
            let nm = c.name.trimmed
            if nm.isEmpty { continue }
            var h = clean(c.handle ?? "")
            if h.isEmpty { h = clean(nm.replacingOccurrences(of: " ", with: "")) }
            if h.isEmpty { h = "user\(cast.count + 1)" }
            var base = h, n = 2
            while used.contains(h) { h = base + "\(n)"; n += 1 }
            base = h
            used.insert(h)
            let trait = Trait(rawValue: (c.trait ?? "").lowercased()) ?? Trait.allCases[cast.count % Trait.allCases.count]
            let f = Int(min(2_000_000, max(500, c.followers ?? Double(Int.random(in: 3000...90000)))))
            cast.append(NPC(id: h, name: nm, handle: h, emoji: oneEmoji(c.emoji, "🙂"), bio: (c.bio ?? "").trimmed,
                            trait: trait, followers: f, affinity: Int.random(in: 8...28), followsYou: false))
        }
        guard cast.count >= 4 else { throw AIError.badEvent }

        let newsName = (w.news?.name ?? "").trimmed
        let news = NPC(id: "newsdesk", name: newsName.isEmpty ? "The Daily Feed" : newsName,
                       handle: { let h = clean(w.news?.handle ?? ""); return h.isEmpty ? "dailyfeed" : h }(),
                       emoji: oneEmoji(w.news?.emoji, "📰"), bio: "breaking news, loosely sourced",
                       trait: .gossip, followers: 500_000, affinity: 0, followsYou: false)

        var skills: [Skill] = []
        for s in (w.skills ?? []).prefix(3) where !s.name.trimmed.isEmpty {
            skills.append(Skill(name: s.name.trimmed, desc: (s.desc ?? "").trimmed, value: Int.random(in: 5...11)))
        }
        if skills.count < 3 { skills = WorldDef.genericSkills() }

        var miles: [Milestone] = []
        for m in (w.milestones ?? []).prefix(5) where !m.text.trimmed.isEmpty {
            let reqs = (m.reqs ?? []).prefix(3).map { Req(skill: min(2, max(0, $0.skill)), level: min(40, max(6, $0.level))) }
            miles.append(Milestone(text: m.text.trimmed, reqs: Array(reqs.isEmpty ? [Req(skill: 0, level: 10)] : reqs)))
        }
        if miles.count < 3 { miles = WorldDef.genericMilestones(goal) }

        var quests: [Quest] = []
        for q in (w.quests ?? []).prefix(6) where !q.trimmed.isEmpty {
            quests.append(Quest(text: q.trimmed, xp: Int.random(in: 20...28)))
        }
        if quests.count < 3 { quests = WorldDef.genericQuests() }

        let title = (w.title ?? "").trimmed
        return WorldDef(id: UUID().uuidString, title: title.isEmpty ? String(goal.prefix(24)) : title,
                        emoji: oneEmoji(w.emoji, "🌐"), tagline: (w.tagline ?? "").trimmed.isEmpty ? String(setting.prefix(90)) : (w.tagline ?? "").trimmed,
                        goal: goal, setting: setting, cast: cast, news: news, skills: skills,
                        milestones: miles, quests: quests, preset: false, hue: Double.random(in: 0...1))
    }

    // MARK: Feed posts

    struct GenPost { var handle: String; var text: String; var rHandle: String?; var rText: String? }
    private struct DTOReply: Decodable { var handle: String?; var text: String? }
    private struct DTOPost: Decodable { var handle: String; var text: String; var reply: DTOReply? }
    private struct DTOPosts: Decodable { var posts: [DTOPost] }

    static func generatePosts(system: String, user: String) async throws -> [GenPost] {
        let raw = try await chat(system: system, user: user, timeout: 40)
        guard let data = jsonData(raw), let dto = try? JSONDecoder().decode(DTOPosts.self, from: data) else { throw AIError.badEvent }
        let out = dto.posts.compactMap { p -> GenPost? in
            let t = p.text.trimmed
            if t.isEmpty { return nil }
            let rt = (p.reply?.text ?? "").trimmed
            return GenPost(handle: clean(p.handle), text: String(t.prefix(260)),
                           rHandle: p.reply?.handle.map { clean($0) },
                           rText: rt.isEmpty ? nil : String(rt.prefix(160)))
        }
        if out.isEmpty { throw AIError.badEvent }
        return out
    }

    // MARK: Replies to the player's post

    struct GenReply { var handle: String; var text: String }
    private struct DTOReplyItem: Decodable { var handle: String; var text: String }
    private struct DTOReplies: Decodable { var replies: [DTOReplyItem] }

    static func generateReplies(system: String, user: String) async throws -> [GenReply] {
        let raw = try await chat(system: system, user: user, timeout: 30)
        guard let data = jsonData(raw), let dto = try? JSONDecoder().decode(DTOReplies.self, from: data) else { throw AIError.badEvent }
        let out = dto.replies.compactMap { r -> GenReply? in
            let t = r.text.trimmed
            return t.isEmpty ? nil : GenReply(handle: clean(r.handle), text: String(t.prefix(200)))
        }
        if out.isEmpty { throw AIError.badEvent }
        return out
    }

    // MARK: Intro story

    private struct DTOIntro: Decodable { var story: String; var quest: String; var post: String }

    static func generateIntro(system: String, user: String) async throws -> Intro {
        let raw = try await chat(system: system, user: user, timeout: 20)
        guard let data = jsonData(raw), let d = try? JSONDecoder().decode(DTOIntro.self, from: data),
              !d.story.trimmed.isEmpty, !d.quest.trimmed.isEmpty, !d.post.trimmed.isEmpty else { throw AIError.badEvent }
        return Intro(story: d.story.trimmed, questText: String(d.quest.trimmed.prefix(120)), questPost: String(d.post.trimmed.prefix(240)))
    }

    // MARK: DM reply

    static func reply(system: String, user: String) async throws -> String {
        var t = try await chat(system: system, user: user, timeout: 25).trimmed
        if let a = t.firstIndex(of: "{"), t.hasPrefix("{"), let b = t.lastIndex(of: "}"), a < b,
           let data = jsonData(t),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let m = (obj["message"] ?? obj["reply"] ?? obj["text"]) as? String { t = m.trimmed }
        t = t.replacingOccurrences(of: "\"", with: "")
        if t.isEmpty { throw AIError.badResponse }
        return String(t.prefix(280))
    }
}

// MARK: - Prompts

enum AIPrompt {
    static let topics = [
        "a leaked voice memo", "a fan feud spiraling out of control", "a surprise guest showing up",
        "a rival's big announcement", "a failed prank that went viral", "a charity moment being filmed",
        "an outfit or style controversy", "a fake account impersonating the player", "an awkward live moment",
        "a friend being accused of something", "a surprise announcement", "a mysterious DM",
        "a trending hashtag about the player", "an interview clip taken out of context",
        "a petty feud over something tiny", "a wholesome moment going wrong", "a sponsor drama",
        "an old friendship resurfacing", "a prank by a chaotic character", "a secret getting out"
    ]

    private static func worldBlock(_ s: GameState) -> String {
        "World: \(s.world.title) - \(s.world.tagline)\nSetting: \(String(s.world.setting.prefix(500)))\nPlayer's main goal: \(s.world.goal)"
    }

    private static func castBlock(_ s: GameState) -> String {
        s.npcs.filter { $0.id != "newsdesk" }
            .map { "\($0.name) (@\($0.handle), \($0.trait.rawValue), \(short($0.followers)) followers, bio: \($0.bio))" }
            .joined(separator: "; ")
    }

    static func event(_ s: GameState) -> (String, String) {
        let recent = s.recent.isEmpty ? "none" : s.recent.map { "- \($0)" }.joined(separator: "\n")
        let topic = topics.randomElement() ?? "drama"
        let system = "You write short, funny, dramatic social-media simulation events for a mobile game. Output ONLY valid minified JSON. No markdown, no commentary."
        let user = """
        \(worldBlock(s))
        Player: \(s.persona.name) (@\(s.persona.handle)), vibe: \(s.persona.vibe.label), \(short(s.followers)) followers, aura \(s.aura)%.
        Cast (use these exact names): \(castBlock(s))
        Recent events (do NOT repeat):
        \(recent)

        Write ONE new event about: \(topic). It must fit the world and setting above.
        Rules:
        - PG-13. Fictional characters only. No real people, brands, or celebrities.
        - Refer to the player as {me}. Use cast names for other people.
        - Exactly 3 choices: one safe/kind, one bold/risky, one chaotic/funny.
        - text <= 200 chars. Each choice text <= 90 chars. Each result <= 190 chars and describes the consequence in a fun social-media way. Each news <= 90 chars as a breaking-news headline using {me}.
        - aura: integer -12 to 12 (matches how well it goes). fol: percent change in followers, -20 to 25.
        - stats: object using keys humor, charm, edge, mystery with values -5 to 5.
        - npc: object using keys among hype, hater, wholesome, gossip, mogul, chaos with value 1 (they like it) or -1 (they dislike it), for cast members involved.
        JSON shape:
        {"emoji":"🎭","text":"...","choices":[{"text":"...","result":"...","news":"...","aura":6,"fol":8,"stats":{"humor":3},"npc":{"hater":-1}}, {...}, {...}]}
        """
        return (system, user)
    }

    static func posts(_ s: GameState) -> (String, String) {
        let mine = s.posts.filter { $0.isYou }.prefix(3).map { "- \($0.text)" }.joined(separator: "\n")
        let events = s.recent.suffix(2).map { "- \($0)" }.joined(separator: "\n")
        let system = "You write the live social feed of a fictional online world for a mobile game. Posts must read like real people posting in that specific niche: casual, specific, jargon-aware, never generic motivational filler. Output ONLY valid minified JSON. No markdown."
        let user = """
        \(worldBlock(s))
        Cast (use these exact handles): \(castBlock(s))
        The player is \(s.persona.name) (@\(s.persona.handle)), \(short(s.followers)) followers, aura \(s.aura)%. It is day \(s.day).
        What the player posted recently:
        \(mine.isEmpty ? "- nothing yet" : mine)
        Recent events in their life:
        \(events.isEmpty ? "- nothing yet" : events)

        Write 6 posts from 6 DIFFERENT cast members, in each character's own voice and niche.
        Rules:
        - Talk about the real stuff people in THIS world care about: its tools, places, slang, rivalries, news, memes. Be concrete (name specific in-world things).
        - Vary the format: a flex, a complaint, a question to followers, a hot take, a meme-ish one-liner, a shoutout.
        - At least two should react to the player (mention @\(s.persona.handle) or their recent posts/events) and at least one should be about another cast member.
        - 30 to 200 characters. Mostly lowercase, natural, few emoji, no hashtags spam. PG-13. No real people or brands.
        - For 4 of the posts add a short "reply" from a different cast member (<= 90 chars).
        JSON shape: {"posts":[{"handle":"cast_handle","text":"...","reply":{"handle":"other_handle","text":"..."}}]}
        """
        return (system, user)
    }

    static func replies(_ s: GameState, text: String, delta: Int) -> (String, String) {
        let system = "You write the replies under a post in a fictional online world for a mobile game. Replies must sound like real people in that specific niche. Output ONLY valid minified JSON. No markdown."
        let mood = delta >= 0 ? "mostly positive, a couple of playful or skeptical" : "mixed to negative, some people roast it"
        let user = """
        \(worldBlock(s))
        Cast (use these exact handles): \(castBlock(s))
        The player \(s.persona.name) (@\(s.persona.handle)) just posted: "\(text)"
        Write 4 replies from 4 DIFFERENT cast members, in character, \(mood). Be concrete and use this world's jargon. Some may @mention the player or each other. 20 to 140 characters each, casual, PG-13, no real people or brands.
        JSON shape: {"replies":[{"handle":"cast_handle","text":"..."}]}
        """
        return (system, user)
    }

    static func intro(_ w: WorldDef, _ p: Persona) -> (String, String) {
        let system = "You write the opening of a social-media simulation game. Output ONLY valid minified JSON. No markdown."
        let user = """
        World: \(w.title) - \(w.tagline)
        Setting: \(String(w.setting.prefix(500)))
        Player: \(p.name) (@\(p.handle)), vibe: \(p.vibe.label)
        Goal: \(w.goal)
        Write: "story" = 2 short paragraphs (<= 320 chars total) starting with a one-line scene-setter about this world, then addressing the player as @\(p.handle) and what they are trying to do; "quest" = a first side quest <= 80 chars (an instruction like "Start a fight with..."); "post" = the exact first post the player could publish for that quest, <= 160 chars, first person, casual, specific to this world. PG-13, no real people or brands.
        JSON shape: {"story":"...","quest":"...","post":"..."}
        """
        return (system, user)
    }

    static func dm(_ s: GameState, npc: NPC, history: [DMMessage]) -> (String, String) {
        let hist = history.suffix(6).map { ($0.fromYou ? s.persona.name : npc.name) + ": " + $0.text }.joined(separator: "\n")
        let system = "You roleplay \(npc.name) (@\(npc.handle)), a \(npc.trait.rawValue) character: \(npc.bio). Reply to the player's DM in character, in 1-2 short casual texting sentences, no quotes, no stage directions. PG-13."
        let user = """
        \(worldBlock(s))
        \(s.persona.name) is the player with \(short(s.followers)) followers. Your affinity with them is \(npc.affinity)/100.
        Conversation so far:
        \(hist)
        Write only \(npc.name)'s next message.
        """
        return (system, user)
    }

    static func world(goal: String, setting: String) -> (String, String) {
        let system = "You design believable social-media worlds for a mobile simulation game. Output ONLY valid minified JSON. No markdown, no commentary."
        let user = """
        The player wrote this world.
        Main character goal: \(goal)
        World setting: \(String(setting.prefix(1500)))

        Build the cast and progression so the world feels real and specific to the text above.
        Rules:
        - PG-13. Entirely fictional people. No real people, brands, or copyrighted characters (invented names for in-world products and groups are fine).
        - cast: exactly 6 accounts that would realistically exist in this exact world. Give each a believable full name (mix genders, ages and cultures), a handle that looks like a real username for their niche (lowercase letters, numbers, underscores or dots; may use in-world jargon, e.g. like "dylib_dani" or "nightshift.rae"), one emoji, a bio written the way that person would write their own social bio (<= 70 chars, specific to their niche, never generic like "loves life"), a trait (one each of hype, hater, wholesome, gossip, mogul, chaos), and followers (integer 2000-500000, the mogul the biggest).
        - news: an account that reports on this world (name, handle, emoji).
        - skills: exactly 3 skills a person needs to succeed in THIS world, name (2-3 words) + funny desc <= 70 chars.
        - milestones: exactly 5 steps toward the goal in order, using this world's own language. Each has text <= 70 chars and reqs: list of {"skill":0-2,"level":number}; early ones need level 10-12 in one skill, the last needs levels 16-20 in all three.
        - quests: exactly 6 short post prompts <= 70 chars that fit this world.
        - title: <= 22 chars. emoji: one emoji. tagline: <= 80 chars.
        JSON shape:
        {"title":"","emoji":"","tagline":"","cast":[{"name":"","handle":"","emoji":"","bio":"","trait":"hype","followers":12000}],"news":{"name":"","handle":"","emoji":""},"skills":[{"name":"","desc":""}],"milestones":[{"text":"","reqs":[{"skill":0,"level":11}]}],"quests":[""]}
        """
        return (system, user)
    }
}
