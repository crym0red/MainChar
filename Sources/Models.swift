import SwiftUI

// MARK: - Helpers

extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

func short(_ n: Int) -> String {
    let d = Double(abs(n)), sign = n < 0 ? "-" : ""
    if abs(n) >= 1_000_000 { return sign + String(format: "%.1fM", d / 1_000_000) }
    if abs(n) >= 10_000 { return sign + String(format: "%.1fK", d / 1000) }
    if abs(n) >= 1000 { return sign + String(format: "%.1fK", d / 1000) }
    return "\(n)"
}

// MARK: - Core types

enum Trait: String, Codable, CaseIterable {
    case hype, hater, wholesome, gossip, mogul, chaos
    var vibe: Vibe {
        switch self {
        case .hype, .chaos: return .clown
        case .hater, .mogul: return .menace
        case .wholesome: return .sweetheart
        case .gossip: return .mystery
        }
    }
}

enum StatKind: String, Codable, CaseIterable {
    case humor, charm, edge, mystery
    var label: String { rawValue.capitalized }
    var emoji: String {
        switch self { case .humor: return "🤣"; case .charm: return "😘"; case .edge: return "😈"; case .mystery: return "🕶️" }
    }
}

enum Vibe: String, Codable, CaseIterable, Identifiable {
    case menace, sweetheart, mystery, clown
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var emoji: String {
        switch self { case .menace: return "😈"; case .sweetheart: return "🥹"; case .mystery: return "🕶️"; case .clown: return "🤡" }
    }
    var blurb: String {
        switch self {
        case .menace: return "Bigger reach. Risky aura."
        case .sweetheart: return "Steady, safe growth."
        case .mystery: return "Quiet energy. Fewer enemies."
        case .clown: return "Funny posts hit harder."
        }
    }
    var likeMult: Double {
        switch self { case .menace: return 1.15; case .sweetheart: return 1.0; case .mystery: return 0.95; case .clown: return 1.1 }
    }
}

struct NPC: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var handle: String
    var emoji: String
    var bio: String
    var trait: Trait
    var followers: Int
    var affinity: Int
    var followsYou: Bool
}

struct Comment: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var handle: String
    var emoji: String
    var text: String
    var verified: Bool = false
}

struct Post: Identifiable, Codable, Hashable {
    var id = UUID()
    var authorHandle: String
    var authorName: String
    var emoji: String
    var text: String
    var likes: Int
    var reposts: Int
    var comments: [Comment]
    var day: Int
    var isYou: Bool
    var verified: Bool = false
    var viral: Bool = false
    var liked: Bool = false
    var tag: String = ""
}

struct DMMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var fromYou: Bool
    var text: String
}

struct Persona: Codable, Hashable {
    var name: String
    var handle: String
    var bio: String
    var emoji: String
    var vibe: Vibe
}

struct Outcome: Identifiable, Equatable {
    let id = UUID()
    var emoji: String
    var title: String
    var detail: String
    var xp: Int = 0
    var auraDelta: Int = 0
    var auraAfter: Int = 0
    var line: String = ""
    var ups: [String] = []
    var postID: UUID? = nil
}

struct Intro: Codable, Hashable {
    var story: String
    var questText: String
    var questPost: String
    var done: Bool = false
}

struct Badge: Identifiable { let id: String; let title: String; let emoji: String }

struct StatChange: Codable, Hashable, Identifiable {
    var kind: StatKind
    var up: Bool
    var id: String { kind.rawValue }
}

struct NPCChange: Codable, Hashable, Identifiable {
    var emoji: String
    var handle: String
    var up: Bool
    var id: String { handle }
}

struct ResultRecord: Codable {
    var emoji: String
    var text: String
    var auraDelta: Int
    var auraAfter: Int
    var followerDelta: Int
    var stats: [StatChange]
    var npcs: [NPCChange]
    var cancelled: Bool
    var iconUnlocked: Bool
}

// MARK: - Progression

struct Skill: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var desc: String
    var value: Int
}

struct Req: Codable, Hashable {
    var skill: Int
    var level: Int
}

struct Milestone: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var reqs: [Req]
    var done: Bool = false
    var skipped: Bool = false
}

struct Quest: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var xp: Int
    var done: Bool = false
}

struct Notif: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: String          // follow, reply, story, level, milestone, event
    var text: String
    var sub: String
    var handle: String
    var emoji: String
    var day: Int
    var unread: Bool = true
    var ref: UUID? = nil      // story id for "story" notifications
}

struct LogEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var day: Int
    var emoji: String
    var title: String
    var detail: String
    // New optional fields (so older saves still decode)
    var kind: String? = nil       // post, story, outcome, dm, activity
    var time: Date? = nil
    var delta: Double? = nil
    var refID: UUID? = nil
    var body: String? = nil
    var handle: String? = nil
}

struct Story: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var bg: Int
    var hasImage: Bool = false
    var day: Int
    var date: Date = Date()
    var comments: [Comment] = []
}

/// Everything added after v1 lives here so older saves keep decoding.
struct Extras: Codable, Hashable {
    var stories: [Story] = []
    var gems = 5
    var streak = 1
    var lastStreakDay = ""
    var gifts = 0
    var viralArmed = false
    var boostUntil: Date? = nil
    var statDelta: [String: Int] = [:]
    var statNote: [String: String] = [:]
}

// MARK: - World

struct WorldDef: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var emoji: String
    var tagline: String
    var goal: String
    var setting: String
    var cast: [NPC]
    var news: NPC
    var skills: [Skill]
    var milestones: [Milestone]
    var quests: [Quest]
    var preset: Bool
    var hue: Double
}

// MARK: - Post kinds

enum PostKind: String, Codable, CaseIterable, Identifiable {
    case meme, wholesome, hotTake, drama, flex, collab, apology
    var id: String { rawValue }
    var label: String {
        switch self {
        case .meme: return "Meme"
        case .wholesome: return "Wholesome"
        case .hotTake: return "Hot Take"
        case .drama: return "Drama"
        case .flex: return "Flex"
        case .collab: return "Collab"
        case .apology: return "Apology"
        }
    }
    var icon: String {
        switch self {
        case .meme: return "😂"
        case .wholesome: return "🥰"
        case .hotTake: return "🌶️"
        case .drama: return "🍿"
        case .flex: return "💅"
        case .collab: return "🤝"
        case .apology: return "🙏"
        }
    }
    var blurb: String {
        switch self {
        case .meme: return "Safe reach."
        case .wholesome: return "Aura goes up. Slow follower gain."
        case .hotTake: return "Good reach. Aura swings."
        case .drama: return "2 energy. Huge reach. Huge aura swing."
        case .flex: return "Strong follows. Aura dips."
        case .collab: return "Tag someone. They may follow you."
        case .apology: return "Big aura recovery. Unlocks below 30% aura."
        }
    }
    var cost: Int { self == .drama ? 2 : 1 }
    var reach: Double {
        switch self {
        case .meme: return 1.0
        case .wholesome: return 0.8
        case .hotTake: return 1.4
        case .drama: return 2.2
        case .flex: return 1.2
        case .collab: return 1.3
        case .apology: return 0.7
        }
    }
    var aura: ClosedRange<Int> {
        switch self {
        case .meme: return 0...2
        case .wholesome: return 2...5
        case .hotTake: return -6...6
        case .drama: return -10...12
        case .flex: return -4...2
        case .collab: return 1...4
        case .apology: return 6...12
        }
    }
    var followMult: Double {
        switch self { case .wholesome: return 0.8; case .flex: return 1.3; case .drama: return 1.2; case .apology: return 0.5; default: return 1.0 }
    }
    var risky: Bool { self == .hotTake || self == .drama }
    func suggestion() -> String {
        let pool: [String]
        switch self {
        case .meme: pool = ["me pretending i have a plan vs the plan", "nobody: ... me at 3am: one more scroll", "my brain has 47 tabs open and one is playing music"]
        case .wholesome: pool = ["reminder to drink water and text your friend back 💛", "so grateful for everyone who showed up this week.", "small wins count. go celebrate one."]
        case .hotTake: pool = ["unpopular opinion: group chats are the real social media", "hot take: mornings are overrated and so are most 'rules'", "we need to stop pretending everyone likes the same thing"]
        case .drama: pool = ["i said what i said. receipts coming soon 👀", "some of y'all are two-faced and it SHOWS", "not naming names but you know exactly who you are"]
        case .flex: pool = ["new week, new numbers. thank you for the support 📈", "built different. posted different. famous different.", "they said i couldn't. now look."]
        case .collab: pool = ["we made something. you're gonna want to see this 👇", "collab szn. drop your guesses below", "tagging my favorite chaos partner for a reason"]
        case .apology: pool = ["i got carried away and i'm sorry. taking time to do better.", "no excuses. i hurt people and i'm listening.", "i should have thought before posting. i'm sorry."]
        }
        return pool.randomElement() ?? ""
    }
}

// MARK: - Story event types

struct StatDelta: Codable, Hashable { var kind: StatKind; var v: Int }
struct NPCDelta: Codable, Hashable { var trait: Trait; var d: Int }

struct Choice: Codable, Hashable {
    var text: String
    var result: String
    var news: String
    var aura: Int
    var fol: Double
    var stats: [StatDelta]
    var npc: [NPCDelta]
}

struct StoryEvent: Codable, Hashable {
    var id: String
    var emoji: String
    var text: String
    var choices: [Choice]
    var ai: Bool = false
}

// MARK: - Save state

struct GameState: Codable, Identifiable {
    var id = UUID()
    var world: WorldDef
    var persona: Persona
    var followers: Int
    var following = 0
    var energy = 10
    var bonus = 2
    var lastEnergyTick = Date()
    var aura = 25
    var lastAuraDelta = 0
    var day = 1
    var level = 1
    var xp = 0
    var points = 2
    var posts: [Post] = []
    var npcs: [NPC] = []
    var threads: [String: [DMMessage]] = [:]
    var unread: Set<String> = []
    var achievements: Set<String> = []
    var stats: [String: Int] = ["humor": 30, "charm": 30, "edge": 30, "mystery": 30]
    var skills: [Skill] = []
    var milestones: [Milestone] = []
    var quests: [Quest] = []
    var saved: Set<UUID> = []
    var hidden: Set<UUID> = []
    var notifs: [Notif] = []
    var log: [LogEntry] = []
    var currentEvent: StoryEvent? = nil
    var result: ResultRecord? = nil
    var seen: [String] = []
    var recent: [String] = []
    var cancelledCount = 0
    var viralCount = 0
    var totalPosts = 0
    var redeemed = 0
    var eventsDone = 0
    var icon = 0
    var lastPlayed = Date()
    var intro: Intro? = nil
    var x: Extras? = nil
    var ex: Extras {
        get { x ?? Extras() }
        set { x = newValue }
    }

    static let blank = GameState(
        world: WorldDef.blank,
        persona: Persona(name: "", handle: "", bio: "", emoji: "🙂", vibe: .clown),
        followers: 0)
}

struct Store: Codable {
    var saves: [GameState] = []
    var presets: [WorldDef] = []
    var activeID: UUID? = nil
}
