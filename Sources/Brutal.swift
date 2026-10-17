import SwiftUI

// MARK: - Roast engine: personalised, unforgiving pile-ons aimed at the player (or any rugged deployer).
// No slurs, no threats, no self-harm lines; every line still passes ContentPrefs.allows.

enum Roast {
    struct Ctx {
        var handle: String
        var name: String
        var followers: Int
        var aura: Int
        var level: Int
        var last: String      // snippet of the target's last post
        var rugs: Int
        var loot: Double
        var holders: Int
        var trust: Int
        var coin: String
    }

    static func ctx(_ st: GameState, handle: String? = nil, name: String? = nil, rugs: Int = 0, loot: Double = 0,
                    holders: Int = 0, trust: Int = 0, coin: String = "") -> Ctx {
        let me = st.persona
        let last = st.posts.first(where: { $0.isYou })?.text ?? ""
        let snip = last.count > 46 ? String(last.prefix(46)) + "…" : last
        return Ctx(handle: handle ?? me.handle, name: name ?? me.name, followers: st.followers, aura: st.aura, level: st.level,
                   last: snip, rugs: rugs, loot: loot, holders: holders, trust: trust, coin: coin)
    }

    private static func fill(_ t: String, _ c: Ctx) -> String {
        t.replacingOccurrences(of: "{h}", with: c.handle)
            .replacingOccurrences(of: "{n}", with: c.name)
            .replacingOccurrences(of: "{f}", with: short(c.followers))
            .replacingOccurrences(of: "{a}", with: "\(c.aura)")
            .replacingOccurrences(of: "{lv}", with: "\(c.level)")
            .replacingOccurrences(of: "{last}", with: c.last.isEmpty ? "that whole feed" : "\"\(c.last)\"")
            .replacingOccurrences(of: "{rugs}", with: "\(c.rugs)")
            .replacingOccurrences(of: "{loot}", with: Mk.fmtGems(c.loot))
            .replacingOccurrences(of: "{holders}", with: "\(c.holders)")
            .replacingOccurrences(of: "{tr}", with: "\(c.trust)")
            .replacingOccurrences(of: "{c}", with: c.coin)
    }

    static let mild: [String] = [
        "that was genuinely embarrassing to watch, {n}",
        "{f} followers and not one of them is proud of this",
        "{last} is the kind of post that ages like milk",
        "level {lv} energy. all of it. every post",
        "i'm not mad, {n}, i'm just disappointed. mostly at how boring you are",
        "this is why people mute you",
        "you really thought that landed",
        "the main character of a show that got cancelled in week one"
    ]

    static let hot: [String] = [
        "{f} followers and you still manage to have zero credibility. that's actually talent",
        "{last}. you posted that. on purpose. with your whole chest",
        "{n} is what happens when ambition meets zero self awareness",
        "aura {a}. i've seen houseplants with more presence",
        "level {lv} and already insufferable. imagine the ceiling",
        "every time you post a little piece of this app dies",
        "you're a cautionary tale with a profile picture",
        "the only thing you've ever pumped is your own ego and even that's overvalued",
        "not even the bots like your posts. they just stop following out of mercy",
        "your whole feed reads like an apology you're too proud to write",
        "this account is a landfill with a verified-wannabe logo on it",
        "i've seen more personality in a terms of service page",
        "you peaked at the tutorial and it's been downhill since",
        "the audacity of posting after that is the only impressive thing about you",
        "your mom has the app and she's already muted you",
        "everyone's screenshotting this. not to share. to show their therapist",
        "you post like someone who reads their own replies out loud and claps",
        "you have the charisma of a loading screen",
        "delete the app. it's the most useful thing you could do for this community",
        "{n}'s content is why the 'mute' button exists",
        "ratio'd by your own followers. that takes commitment",
        "you could've stayed quiet and been a mystery. now you're just a punchline",
        "so much confidence, so little to show for it. {f} followers of pure disappointment",
        "I've been reading this thread for five minutes and you've lost every single exchange",
        "bro really built a personality out of being wrong in public",
        "cope harder {n}. the timeline is not on your side",
        "embarrassing. like physically hard to look at",
        "no one is coming to save your reputation. we checked",
        "take the L and log off. you're not built for this",
        "you're the reason the block button got an update"
    ]

    static let crude: [String] = [
        "{n} is a fucking embarrassment and the {f} followers are hostages",
        "holy shit {n}, have you ever had a good take or are you just built different, in a bad way",
        "you're so fucking irrelevant the algorithm hides your posts out of kindness",
        "{last} is the dumbest shit i've read all year and i read the comments on gas station reviews",
        "shut the fuck up and log off, {n}. nobody here owes you attention",
        "every post you make is a hate crime against literacy",
        "you absolute waste of server space. aura {a}. fucking tragic",
        "congratulations, you made everyone worse for having read that",
        "you're not controversial, you're just painfully, relentlessly shit at this",
        "{f} followers and a personality like wet cardboard. impressive in the worst way"
    ]

    static let rug: [String] = [
        "you pulled {loot} gems out of {holders} people and still look broke. that's impressive",
        "trust score was {tr} and you rugged anyway. you didn't even do the crime well",
        "{rugs} rug{s} on record and you still think you're the main character",
        "$ {c} was never a coin, it was a confession with a ticker",
        "you took {loot} gems and left {holders} people with a chart that looks like a cliff",
        "scammers usually at least have a personality. you didn't even bring that",
        "the wallet trail reads like a ransom note nobody asked for",
        "pulled liquidity and the last shred of respect in one move. efficient, at least",
        "{holders} holders and not one of them will ever trust a launch of yours again. gg",
        "imagine rugging your own community and still ending up with no aura",
        "give the gems back, {n}. you're not smart enough to keep them",
        "every future launch of yours is pre-ratio'd. we're all just waiting",
        "{n} didn't rug $ {c}. {n} rugged their own legacy",
        "you'll never be able to say 'trust me' again without someone posting this thread"
    ]

    static func line(_ c: Ctx, heat: Int, rug isRug: Bool = false) -> String {
        for _ in 0..<8 {
            var pool: [String]
            switch heat {
            case 0, 1: pool = mild
            case 2: pool = hot
            default: pool = hot + crude
            }
            if isRug { pool += rug + (heat >= 2 ? rug : []) }
            var t = fill(pool.randomElement() ?? "ratio", c)
            t = t.replacingOccurrences(of: "{s}", with: c.rugs == 1 ? "" : "s").replacingOccurrences(of: "$ ", with: "$")
            if ContentPrefs.allows(t) { return t }
        }
        return "ratio"
    }
}

extension Game {
    /// A character dedicates a whole post to ripping the target apart; the crowd piles on one reply at a time.
    func roastPost(_ st: GameState, by n: NPC, _ c: Roast.Ctx, rug: Bool, tag: String = "Roast", quote: Quote? = nil, replies: Int = Int.random(in: 8...14)) -> Post {
        let heat = Spicy.heat
        var p = makePost(n, "@\(c.handle) " + Roast.line(c, heat: heat, rug: rug), st)
        p.tag = tag
        p.poll = nil; p.media = nil
        p.quote = quote
        stampPost(&p, st)
        p.likes = max(p.likes * 4, 260)
        p.reposts = p.likes / 4
        p.comments = []
        let cast = st.npcs.filter { $0.id != "newsdesk" && $0.handle != n.handle && $0.handle != c.handle }.shuffled()
        var q: [QComment] = []
        var at = Date()
        for i in 0..<replies {
            let cm: Comment
            if cast.isEmpty || i % 3 == 2 {
                let u = Crowd.make()
                cm = Comment(name: u.name, handle: u.handle, emoji: "🙂", text: (i % 2 == 0 ? "@\(c.handle) " : "") + Roast.line(c, heat: heat, rug: rug))
            } else {
                let s = cast[i % cast.count]
                cm = Comment(name: s.name, handle: s.handle, emoji: s.emoji, text: "@\(c.handle) " + Roast.line(c, heat: heat, rug: rug), verified: s.followers >= 40000)
            }
            at = at.addingTimeInterval(i < 2 ? 1 : Double.random(in: 5...24))
            q.append(QComment(c: cm, at: at))
        }
        p.queue = q
        return p
    }

    /// Out of nowhere somebody quote-posts you and the timeline joins in.
    func simCallout(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard Spicy.heat >= 1, activeLive(st) < 3 else { return }
        let pool = cast.filter { $0.trait == .hater || $0.trait == .gossip || $0.trait == .chaos }
        guard let n = (pool.isEmpty ? cast : pool).randomElement() else { return }
        let c = Roast.ctx(st)
        var qt: Quote? = nil
        if let mine = st.posts.first(where: { $0.isYou }) {
            qt = Quote(handle: mine.authorHandle, name: mine.authorName, text: String(mine.text.prefix(140)))
        }
        let p = roastPost(st, by: n, c, rug: false, tag: "Callout", quote: qt)
        st.posts.insert(p, at: 0)
        st.aura = max(0, st.aura - Int.random(in: 2...5))
        logEvent(&st, &items, quiet: quiet, emoji: "💀", title: "\(n.name) is dragging you", detail: String(p.text.prefix(90)), post: p.id,
                 handles: [n.handle, c.handle], weight: 42)
    }

    private func activeLive(_ st: GameState) -> Int { st.posts.filter { !($0.queue ?? []).isEmpty }.count }
}
