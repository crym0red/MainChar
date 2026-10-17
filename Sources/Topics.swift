import Foundation
import NaturalLanguage

/// Pulls the real subjects out of a world's goal/setting text so offline content stays on-topic.
enum Topics {
    private static let stop: Set<String> = [
        "people", "person", "other", "others", "thing", "things", "world", "way", "time", "lot", "one", "day", "days",
        "everyone", "someone", "everything", "place", "goal", "setting", "life", "group", "kind", "type", "stuff",
        "member", "members", "main", "character", "player", "story", "game", "year", "years", "name", "top", "best",
        "biggest", "part", "side", "end", "city", "town", "school", "lot", "bit", "idea", "anyone", "something"
    ]

    private static var cache: [String: [String]] = [:]

    static func extract(_ text: String, limit: Int = 4) -> [String] {
        if let c = cache[text] { return c }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var counts: [String: Int] = [:]
        var order: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let w = text[range].lowercased()
            let isNoun = tag == .noun
            let isGerund = tag == .verb && w.hasSuffix("ing") && w.count > 5
            if (isNoun || isGerund), w.count >= 3, !stop.contains(w), w.rangeOfCharacter(from: .letters) != nil {
                if counts[w] == nil { order.append(w) }
                counts[w, default: 0] += 1
            }
            return true
        }
        var out = order.sorted { a, b in
            let ca = counts[a] ?? 0, cb = counts[b] ?? 0
            return ca != cb ? ca > cb : a.count > b.count
        }
        out = Array(out.prefix(limit))
        if out.isEmpty {
            out = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
                .filter { $0.count > 4 && !stop.contains($0) }.prefix(limit).map { $0 }
        }
        if out.isEmpty { out = ["the scene"] }
        cache[text] = out
        return out
    }

    static func forWorld(_ w: WorldDef) -> [String] {
        extract(w.goal + ". " + w.setting)
    }

    static let templates: [Trait: [String]] = [
        .hype: [
            "just shipped something new for {t}. we're so back",
            "{t} szn is real and i'm not stopping",
            "who's grinding on {t} tonight?? drop your links",
            "new personal best in {t} 🔥",
            "{t} or {u}? pick a side below",
            "if you're sleeping on {t} right now you're missing it"
        ],
        .hater: [
            "most of what people call {t} is just copy paste. say it louder",
            "{t} discourse again. same people being wrong about the same things",
            "not impressed by anyone's {t} setup. try harder",
            "unpopular opinion: half of you shouldn't be touching {t}",
            "{u} is overrated and so are the people who won't shut up about it"
        ],
        .wholesome: [
            "helped a newbie get started with {t} today. this community is great",
            "reminder that everyone starts somewhere with {t}. be nice",
            "shoutout to everyone sharing what they know about {t} for free 💛",
            "took a break from {t} to touch grass. recommend",
            "proud of everyone who stuck with {t} this week"
        ],
        .gossip: [
            "hearing a certain someone lied about their {t} numbers. receipts soon",
            "did anyone else see the {t} drama today?? 👀",
            "the {t} scene is smaller than you think and everyone talks",
            "dm me if you want the real story behind the {t} thing",
            "not naming names but the {u} situation is about to get messy"
        ],
        .mogul: [
            "{t} is a market now and i'm already positioned",
            "turning my {t} into something that pays. thread soon",
            "partnership talks around {t} are going well. stay tuned",
            "cost of doing {t} properly is going up. plan accordingly",
            "hiring someone who actually knows {u}. dm me"
        ],
        .chaos: [
            "what if {t} but we do it at 3am with no plan",
            "{t} update: it broke. i'm delighted",
            "renamed everything to {t}. no regrets",
            "currently doing {t} wrong on purpose to see what happens",
            "{t} and {u} in the same room. what could go wrong"
        ]
    ]

    static func line(trait: Trait, topics: [String]) -> String? {
        guard let tpl = templates[trait]?.randomElement() else { return nil }
        let t = topics.first ?? "the scene"
        let u = topics.count > 1 ? topics[1...].randomElement() ?? t : t
        let tt = topics.randomElement() ?? t
        return tpl.replacingOccurrences(of: "{t}", with: tt).replacingOccurrences(of: "{u}", with: u == tt ? t : u)
    }

    static let bios: [Trait: String] = [
        .hype: "lives for {t}. loud about it",
        .hater: "strong opinions on {t}. none of them nice",
        .wholesome: "here to help with {t}",
        .gossip: "knows who did what in {t}",
        .mogul: "monetizing {t} since day one",
        .chaos: "breaks {t} for fun"
    ]

    static let firsts = ["Maya", "Jonah", "Priya", "Theo", "Luna", "Marcus", "Zara", "Eli", "Nadia", "Caleb", "Ines", "Kai",
                         "Sofia", "Dev", "Harper", "Omar", "Tessa", "Rafael", "Mina", "Declan", "Aaliyah", "Bruno", "Yuki", "Cass"]
    static let lasts = ["Reyes", "Okafor", "Lindqvist", "Patel", "Moreau", "Hayes", "Tanaka", "Brandt", "Costa", "Novak",
                        "Adeyemi", "Foster", "Kim", "Delgado", "Walsh", "Haddad", "Ivanov", "Sato", "Mercer", "Bishop"]
    static let emojis: [Trait: [String]] = [
        .hype: ["🔥", "⚡️", "🚀", "💪"], .hater: ["😒", "🙄", "🗑️", "😤"], .wholesome: ["🌻", "💛", "🧸", "☕️"],
        .gossip: ["👀", "☕️", "📢", "🫢"], .mogul: ["💼", "📈", "💎", "🏦"], .chaos: ["🌀", "🎲", "🤪", "🧨"]
    ]
}
