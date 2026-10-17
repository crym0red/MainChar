import SwiftUI

private func npc(_ name: String, _ h: String, _ e: String, _ bio: String, _ t: Trait, _ f: Int) -> NPC {
    NPC(id: h, name: name, handle: h, emoji: e, bio: bio, trait: t, followers: f,
        affinity: Int.random(in: 8...28), followsYou: false)
}

private func sk(_ name: String, _ desc: String, _ v: Int) -> Skill { Skill(name: name, desc: desc, value: v) }

private func ms(_ text: String, _ reqs: [(Int, Int)]) -> Milestone {
    Milestone(text: text, reqs: reqs.map { Req(skill: $0.0, level: $0.1) })
}

private func qu(_ text: String, _ xp: Int) -> Quest { Quest(text: text, xp: xp) }

extension WorldDef {
    static let blank = WorldDef(id: "blank", title: "", emoji: "🌐", tagline: "", goal: "", setting: "",
                                cast: [], news: npc("News", "newsdesk", "📰", "", .gossip, 1000),
                                skills: [], milestones: [], quests: [], preset: false, hue: 0.6)

    static let presets: [WorldDef] = [stage, campus, neon, academy]

    // MARK: Encore

    static let stage = WorldDef(
        id: "preset-encore", title: "Encore", emoji: "🎤",
        tagline: "Become a popstar. Tours, feuds, comeback eras.",
        goal: "Become the biggest popstar alive",
        setting: "A glittering pop scene of tours, feuds, fan wars and comeback eras, where every post can make or break a career.",
        cast: [
            npc("Rowan Hale", "rowanhale", "🎸", "4x platinum. still humble (no)", .mogul, 480000),
            npc("Nova Lin", "novalin", "🎤", "new era loading", .hype, 320000),
            npc("Mic Ellis", "micdrop", "🎧", "your fave's fave's producer", .hater, 98000),
            npc("Bea Sutton", "beabackstage", "🧵", "tour manager. i see everything", .gossip, 72000),
            npc("Cleo Vance", "cleosings", "🌻", "sunshine with a setlist", .wholesome, 264000),
            npc("Wren Wilder", "wrenwilder", "🔥", "chaos is a feature", .chaos, 151000)
        ],
        news: npc("Spill Daily", "spilldaily", "📰", "breaking news, loosely sourced", .gossip, 2_000_000),
        skills: [
            sk("Stage Presence", "Owns the room before the lights even come on.", 10),
            sk("Hit Writing", "Can hum a chorus that lives rent-free in millions of heads.", 8),
            sk("Fan Wrangling", "Turns casual listeners into a screaming army.", 6)
        ],
        milestones: [
            ms("Post a clip that wins over your first big crowd", [(0, 11)]),
            ms("Release a surprise single", [(1, 10), (2, 8)]),
            ms("Survive your first public feud", [(2, 10)]),
            ms("Headline a sold-out tour", [(0, 14), (1, 12)]),
            ms("Win Artist of the Year", [(0, 18), (1, 16), (2, 14)])
        ],
        quests: [
            qu("Post a teaser for a song you haven't written yet.", 24),
            qu("Thank your fans with something personal.", 22),
            qu("Roast a rival's outfit (nicely).", 26),
            qu("Post a behind-the-scenes rehearsal moment.", 22),
            qu("Hint at a collab without naming anyone.", 26),
            qu("Post a cryptic lyric as your caption.", 24)
        ],
        preset: true, hue: 0.92)

    // MARK: Maple Hall U

    static let campus = WorldDef(
        id: "preset-maple", title: "Maple Hall U", emoji: "🎓",
        tagline: "College drama, finals week, one very public group chat.",
        goal: "Become the most talked-about person on campus",
        setting: "A noisy college campus where the group chat never sleeps, finals are always next week, and one post can follow you through four years.",
        cast: [
            npc("Mina Park", "minaparkk", "🎀", "student gov. wants everyone to eat vegetables", .wholesome, 4200),
            npc("Dex Okafor", "dexdoesthings", "🏀", "walking hype machine", .hype, 18000),
            npc("Tessa Vale", "tessatea", "☕", "i know what you did at the mixer", .gossip, 9500),
            npc("Brandon Kell", "brandonkell", "😒", "opinions > grades", .hater, 6300),
            npc("Priya Nair", "priyabuilds", "💻", "dropout in progress. startup incoming", .mogul, 52000),
            npc("Juno", "junoisferal", "🦝", "chaos gremlin. dm for crimes", .chaos, 12000)
        ],
        news: npc("Maple Tea", "mapletea", "🍵", "campus news, hot and unfiltered", .gossip, 80000),
        skills: [
            sk("Social Battery", "Somehow still going at 2am on a Tuesday.", 9),
            sk("Meme Fluency", "Speaks fluent group chat.", 7),
            sk("Plausible Deniability", "Never actually said that. Probably.", 5)
        ],
        milestones: [
            ms("Get invited to the party everyone is talking about", [(0, 10)]),
            ms("Go viral in the campus group chat", [(1, 10)]),
            ms("Survive a rumor with your reputation intact", [(2, 8)]),
            ms("Get elected to something. Anything.", [(0, 14), (2, 11)]),
            ms("Become a campus legend", [(0, 18), (1, 16), (2, 14)])
        ],
        quests: [
            qu("Post a meme about finals week.", 22),
            qu("Hype up a friend's event.", 22),
            qu("Post a suspiciously vague update about last night.", 26),
            qu("Compliment the dining hall (bravely).", 24),
            qu("Confess a harmless campus crime.", 26),
            qu("Post a study-group selfie caption.", 20)
        ],
        preset: true, hue: 0.12)

    // MARK: Neon District

    static let neon = WorldDef(
        id: "preset-neon", title: "Neon District", emoji: "🌆",
        tagline: "Cyber-city creators, stream wars, sponsored everything.",
        goal: "Build a streaming empire in the Neon District",
        setting: "A rain-soaked cyber city where creators fight for subscribers, sponsors own the skyline, and every stream is a battle for attention.",
        cast: [
            npc("Kaito Reyes", "kaito.exe", "🕶️", "streaming 20h a day. send help", .hype, 41000),
            npc("Sable", "sablevoid", "🖤", "everything is mid", .hater, 15000),
            npc("Lux Moreau", "luxlive", "💎", "brand deals > feelings", .mogul, 210000),
            npc("Pixel Pete", "pixelpete", "🍜", "ramen + pixel art", .wholesome, 7200),
            npc("Vera Quill", "veraleaks", "📡", "sources say. always sources", .gossip, 33000),
            npc("Glitch", "g1itchgirl", "⚡", "404 brain not found", .chaos, 19000)
        ],
        news: npc("NeonLeaks", "neonleaks", "📡", "the district's loudest feed", .gossip, 600000),
        skills: [
            sk("Stream Hype", "Turns an empty chat into a stadium.", 9),
            sk("Brand Instinct", "Smells a sponsor from six blocks away.", 7),
            sk("Glitch Luck", "Breaks things and somehow wins.", 5)
        ],
        milestones: [
            ms("Hit your first 100 concurrent viewers", [(0, 10)]),
            ms("Land a sponsor that isn't a scam", [(1, 10)]),
            ms("Win a stream war", [(0, 12), (2, 8)]),
            ms("Launch your own merch drop", [(1, 14), (0, 13)]),
            ms("Build a streaming empire", [(0, 18), (1, 16), (2, 14)])
        ],
        quests: [
            qu("Post a clip from your best stream moment.", 24),
            qu("Call out a sponsor's terrible ad.", 26),
            qu("Announce a mystery stream.", 22),
            qu("Post a setup tour caption.", 20),
            qu("Challenge a rival to a stream-off.", 26),
            qu("Thank your top supporters.", 22)
        ],
        preset: true, hue: 0.78)

    // MARK: Duskwood Academy

    static let academy = WorldDef(
        id: "preset-duskwood", title: "Duskwood Academy", emoji: "🔮",
        tagline: "Magic school. House rivalries and cursed gossip.",
        goal: "Rise to the top of Duskwood Academy",
        setting: "A magic academy of floating staircases, rival houses and cursed gossip, where reputation is the strongest spell of all.",
        cast: [
            npc("Elowen Thorne", "elowenthorne", "🌙", "moon magic & mending", .wholesome, 8800),
            npc("Caspian Vale", "caspianvale", "🗡️", "house pride. nothing else", .hater, 14000),
            npc("Ondine", "ondinesplash", "🌊", "water-wizard. party starter", .hype, 26000),
            npc("Mordecai Finch", "finchfacts", "🔮", "i read fortunes and rumors", .gossip, 17000),
            npc("Seraphine Ward", "seraphward", "👑", "headmaster's favorite. obviously", .mogul, 90000),
            npc("Pip", "pipandpuff", "🐉", "tiny dragon. big problems", .chaos, 31000)
        ],
        news: npc("The Duskwood Post", "duskpost", "🦉", "owl-delivered news", .gossip, 120000),
        skills: [
            sk("Spellwork", "Mostly casts what you meant to cast.", 9),
            sk("House Politics", "Knows exactly who owes whom.", 7),
            sk("Rumor Craft", "Can make a whisper travel three towers.", 5)
        ],
        milestones: [
            ms("Win a house point in front of everyone", [(0, 10)]),
            ms("Form an alliance across houses", [(1, 10)]),
            ms("Outlast a cursed rumor", [(2, 8)]),
            ms("Win the Midnight Duel", [(0, 14), (1, 12)]),
            ms("Be named Head of Duskwood", [(0, 18), (1, 16), (2, 14)])
        ],
        quests: [
            qu("Post about the weirdest class you've taken.", 22),
            qu("Hype up your house before the tournament.", 22),
            qu("Hint that the library is haunted.", 24),
            qu("Share a harmless prank.", 24),
            qu("Praise a rival's spell (through gritted teeth).", 26),
            qu("Post a midnight study-room confession.", 24)
        ],
        preset: true, hue: 0.58)

    // MARK: Generic fallback (custom worlds when the AI is offline)

    static func generic(goal: String, setting: String) -> WorldDef {
        let topics = Topics.extract(goal + ". " + setting)
        let t0 = topics.first ?? "the scene"
        let words = goal.split(separator: " ").prefix(3).joined(separator: " ")
        let title = words.isEmpty ? "My World" : words.capitalized
        var firsts = Topics.firsts.shuffled()
        var lasts = Topics.lasts.shuffled()
        var used = Set<String>()
        var cast: [NPC] = []
        let plan: [(Trait, Int)] = [(.hype, 24000), (.hater, 9000), (.wholesome, 6000), (.gossip, 18000), (.mogul, 60000), (.chaos, 14000)]
        for (i, (trait, f)) in plan.enumerated() {
            let first = firsts.removeFirst(), last = lasts.removeFirst()
            var h: String
            switch i % 4 {
            case 0: h = "\(first)\(last)"
            case 1: h = "\(first)_\(last)"
            case 2: h = "\(t0.replacingOccurrences(of: " ", with: ""))\(first)"
            default: h = "\(first).\(last)\(Int.random(in: 2...99))"
            }
            h = h.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            while used.contains(h) { h += "\(Int.random(in: 2...9))" }
            used.insert(h)
            let bio = (Topics.bios[trait] ?? "").replacingOccurrences(of: "{t}", with: topics.randomElement() ?? t0)
            let emoji = Topics.emojis[trait]?.randomElement() ?? "🙂"
            cast.append(npc("\(first) \(last)", h, emoji, bio, trait, f))
        }
        let newsName = "The \(t0.capitalized) Report"
        let newsHandle = (t0.replacingOccurrences(of: " ", with: "") + "report").lowercased().filter { $0.isLetter || $0.isNumber }
        return WorldDef(
            id: UUID().uuidString, title: title, emoji: "🌐",
            tagline: String(setting.prefix(90)),
            goal: goal, setting: setting, cast: cast,
            news: npc(newsName, newsHandle, "📰", "everything happening in \(t0), reported loosely", .gossip, 500_000),
            skills: genericSkills(), milestones: genericMilestones(goal), quests: genericQuests(t0),
            preset: false, hue: Double.random(in: 0...1))
    }

    static func genericSkills() -> [Skill] {
        [sk("Charisma", "Walks into a room and the room notices.", Int.random(in: 7...11)),
         sk("Hustle", "Always has three plans and one backup plan.", Int.random(in: 5...9)),
         sk("Mystique", "People talk about you more than to you.", Int.random(in: 4...8))]
    }

    static func genericMilestones(_ goal: String) -> [Milestone] {
        [ms("Get noticed for the first time", [(0, 10)]),
         ms("Win over your first rival", [(1, 10)]),
         ms("Survive a rumor", [(2, 9)]),
         ms("Become a name everyone knows", [(0, 14), (1, 12)]),
         ms(goal.isEmpty ? "Reach the top" : String(goal.prefix(80)), [(0, 18), (1, 16), (2, 14)])]
    }

    static func genericQuests(_ topic: String = "your world") -> [Quest] {
        [qu("Show off your latest win in \(topic).", 22),
         qu("Thank someone who helped you with \(topic).", 22),
         qu("Hint at a big announcement.", 24),
         qu("Share a harmless secret about \(topic).", 24),
         qu("Compliment a rival.", 26),
         qu("Post your hot take on \(topic).", 24)]
    }
}

enum Inspiration {
    static let prompts: [String] = [
        "A neon-soaked megacity where reputation is currency and every citizen's feed decides what doors open for them.",
        "A tiny seaside town where a viral video turned the local diner into the center of the internet overnight.",
        "A fractured digital wasteland where code is currency and reputation is written in decrypted bytes.",
        "A magic boarding school where house rivalries play out as public feuds, and the gossip is cursed.",
        "A chaotic reality show island where every contestant is also a content creator.",
        "A 1990s teen drama town where everyone has a pager, a secret and a rivalry."
    ]
}
