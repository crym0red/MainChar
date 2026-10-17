import Foundation

// MARK: - Config (keys match @AppStorage in Settings)

enum AIConfig {
    static let defaultURL = "https://text.pollinations.ai/openai"
    static let defaultModel = "openai"

    static var enabled: Bool { UserDefaults.standard.object(forKey: "ai.enabled") as? Bool ?? true }
    static var url: String {
        let v = UserDefaults.standard.string(forKey: "ai.url") ?? ""
        return v.trimmed.isEmpty ? defaultURL : v.trimmed
    }
    static var model: String {
        let v = UserDefaults.standard.string(forKey: "ai.model") ?? ""
        return v.trimmed.isEmpty ? defaultModel : v.trimmed
    }
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

// MARK: - Client

enum AI {
    private static var lastCall = Date.distantPast

    /// Anonymous Pollinations allows roughly one request per 15s. Space calls out so they queue instead of failing.
    private static func throttle() async {
        let gap: TimeInterval = AIConfig.key.isEmpty ? 15 : 1
        let wait = gap - Date().timeIntervalSince(lastCall)
        lastCall = Date().addingTimeInterval(max(0, wait))
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
    }

    static func chat(system: String, user: String, timeout: TimeInterval = 30) async throws -> String {
        await throttle()
        do {
            return try await post(system: system, user: user, timeout: timeout)
        } catch {
            if let r = try? await getSimple(system: system, user: user, timeout: timeout), !r.trimmed.isEmpty { return r }
            throw error
        }
    }

    private static func post(system: String, user: String, timeout: TimeInterval) async throws -> String {
        guard let url = URL(string: AIConfig.url) else { throw AIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !AIConfig.key.isEmpty { req.setValue("Bearer \(AIConfig.key)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = [
            "model": AIConfig.model,
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
        guard let url = URL(string: "https://text.pollinations.ai/\(prompt)?model=\(AIConfig.model)&private=true") else { throw AIError.badURL }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        if !AIConfig.key.isEmpty { req.setValue("Bearer \(AIConfig.key)", forHTTPHeaderField: "Authorization") }
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
        let raw = try await chat(system: system, user: user, timeout: 60)
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

    private struct DTOPost: Decodable { var handle: String; var text: String }
    private struct DTOPosts: Decodable { var posts: [DTOPost] }

    static func generatePosts(system: String, user: String) async throws -> [(String, String)] {
        let raw = try await chat(system: system, user: user)
        guard let data = jsonData(raw), let dto = try? JSONDecoder().decode(DTOPosts.self, from: data) else { throw AIError.badEvent }
        let out = dto.posts.compactMap { p -> (String, String)? in
            let t = p.text.trimmed
            return t.isEmpty ? nil : (clean(p.handle), String(t.prefix(240)))
        }
        if out.isEmpty { throw AIError.badEvent }
        return out
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
        let system = "You write short in-character social media posts for a mobile social-sim game. Output ONLY valid minified JSON. No markdown."
        let user = """
        \(worldBlock(s))
        Cast (use these exact handles): \(castBlock(s))
        The player is \(s.persona.name) (@\(s.persona.handle)) with \(short(s.followers)) followers. It is day \(s.day).
        Write 4 posts from 4 DIFFERENT cast members. Each post in that character's voice, <= 140 chars, fits the world, PG-13, no real people or brands. Some may mention @\(s.persona.handle).
        JSON shape: {"posts":[{"handle":"cast_handle","text":"..."}]}
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
        let system = "You design worlds for a mobile social-media simulation game. Output ONLY valid minified JSON. No markdown, no commentary."
        let user = """
        The player wrote this world.
        Main character goal: \(goal)
        World setting: \(String(setting.prefix(1500)))

        Create the cast and progression for this world. Rules:
        - PG-13. Entirely fictional people. No real people, brands, or copyrighted characters.
        - cast: exactly 6 characters, one for each trait: hype, hater, wholesome, gossip, mogul, chaos. Each has name, handle (lowercase letters/numbers/underscores, no spaces), one emoji, a bio <= 60 chars in their voice, trait, followers (integer 2000-500000).
        - news: a gossip/news account for this world: name, handle, emoji.
        - skills: exactly 3, each with a name (2-3 words) and a funny desc <= 70 chars that fits the world.
        - milestones: exactly 5 steps toward the goal in order. Each has text <= 70 chars and reqs: list of {"skill":0-2,"level":number}; early ones need level 10-12 in one skill, the last needs levels 16-20 in all three.
        - quests: exactly 6 short post prompts <= 70 chars that fit the world.
        - title: <= 22 chars. emoji: one emoji. tagline: <= 80 chars.
        JSON shape:
        {"title":"","emoji":"","tagline":"","cast":[{"name":"","handle":"","emoji":"","bio":"","trait":"hype","followers":12000}],"news":{"name":"","handle":"","emoji":""},"skills":[{"name":"","desc":""}],"milestones":[{"text":"","reqs":[{"skill":0,"level":11}]}],"quests":[""]}
        """
        return (system, user)
    }
}
