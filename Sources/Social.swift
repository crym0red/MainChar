import SwiftUI

struct RankRow: Identifiable {
    let id: String
    let name: String
    let handle: String
    let followers: Int
    let you: Bool
}

enum Rel {
    static func info(_ a: Int) -> (String, String, Color) {
        switch a {
        case 80...: return ("Ride or die", "heart.circle.fill", Color(red: 1, green: 0.45, blue: 0.6))
        case 60..<80: return ("Close friend", "heart.fill", Color(red: 1, green: 0.55, blue: 0.65))
        case 40..<60: return ("Friend", "person.2.fill", T.lime)
        case 25..<40: return ("Acquaintance", "person.fill", T.blue)
        case 10..<25: return ("Stranger", "questionmark.circle.fill", T.sub)
        case 1..<10: return ("Rival", "bolt.shield.fill", T.orange)
        default: return ("Nemesis", "flame.fill", T.red)
        }
    }
}

extension Game {
    static let seasonDays = 14.0

    func isFollowing(_ h: String) -> Bool { (s.ex.following ?? []).contains(h) }

    func toggleFollow(_ h: String) {
        var st = s
        var f = st.ex.following ?? []
        if let i = f.firstIndex(of: h) {
            f.remove(at: i)
            if let j = st.npcs.firstIndex(where: { $0.handle == h }) { st.npcs[j].affinity = max(0, st.npcs[j].affinity - 3) }
        } else {
            f.append(h)
            if let j = st.npcs.firstIndex(where: { $0.handle == h }) {
                st.npcs[j].affinity = min(100, st.npcs[j].affinity + 3)
                if st.npcs[j].affinity >= 35, !st.npcs[j].followsYou, Double.random(in: 0...1) < 0.5 {
                    st.npcs[j].followsYou = true
                    notify(&st, "follow", "\(st.npcs[j].name) followed you back", sub: "@\(h)", handle: h, emoji: st.npcs[j].emoji)
                }
            }
        }
        st.ex.following = f
        st.following = f.count
        if f.contains(h) { bump(&st, "follow") }
        s = st
    }

    func rankings(_ st: GameState) -> [RankRow] {
        var rows = st.npcs.filter { $0.id != "newsdesk" }.map { RankRow(id: $0.handle, name: $0.name, handle: $0.handle, followers: $0.followers, you: false) }
        rows.append(RankRow(id: "you", name: st.persona.name, handle: st.persona.handle, followers: st.followers, you: true))
        return rows.sorted { $0.followers > $1.followers }
    }

    func myRank(_ st: GameState) -> Int {
        (rankings(st).firstIndex { $0.you } ?? 0) + 1
    }

    func seasonDaysLeft(_ st: GameState) -> Int {
        guard let start = st.ex.seasonStart else { return Int(Game.seasonDays) }
        return max(0, Int(ceil(Game.seasonDays - Date().timeIntervalSince(start) / 86400)))
    }

    func trendingTopics(_ st: GameState) -> [String] {
        let stop: Set<String> = ["about", "their", "there", "would", "could", "should", "really", "still", "never", "every", "where", "which", "these", "those", "first", "other", "think", "people", "going", "doing", "being"]
        var count: [String: Int] = [:]
        for p in st.posts.prefix(50) {
            if !p.tag.isEmpty, p.tag != "Feud" { count["#" + p.tag, default: 0] += 2 }
            for t in Mk.tickers(p.text) { count["$" + t, default: 0] += 3 }
            var seen = Set<String>()
            for w in p.text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }) {
                let ws = String(w)
                if ws.count >= 6, !stop.contains(ws), !seen.contains(ws) { seen.insert(ws); count[ws, default: 0] += 1 }
            }
        }
        return count.filter { $0.value >= 3 }.sorted { $0.value > $1.value }.prefix(7).map { $0.key }
    }

    func postMatches(_ p: Post, topic: String) -> Bool {
        if topic.hasPrefix("#") { return p.tag.lowercased() == topic.dropFirst().lowercased() }
        if topic.hasPrefix("$") { return p.text.contains(topic) }
        return p.text.lowercased().contains(topic.lowercased())
    }

    /// Slow world growth: followers drift, newcomers arrive.
    func growWorld(_ st: inout GameState, _ items: inout [DigestItem], _ quiet: Bool) {
        let idx = st.npcs.indices.filter { st.npcs[$0].id != "newsdesk" }
        for i in idx.shuffled().prefix(3) {
            let t = st.npcs[i].trait
            let bias: Double = (t == .hype || t == .mogul) ? 0.012 : 0.0
            st.npcs[i].followers = max(500, Int(Double(st.npcs[i].followers) * (1 + Double.random(in: -0.01...0.03) + bias)))
        }
        guard idx.count < 90, Double.random(in: 0...1) < 0.04 else { return }
        var arr = st.npcs
        CastGen.pad(&arr, world: st.world, avoid: [st.persona.handle], target: idx.count + 1)
        guard let n = arr.last, n.id != "newsdesk", !st.npcs.contains(where: { $0.id == n.id }) else { return }
        st.npcs.append(n)
        let text = ["just joined. hi. what did i miss?", "new here. who do i need to know and who do i avoid?", "finally made an account. let the chaos begin."].randomElement() ?? "hi"
        var p = makePost(n, text, st)
        p.tag = "New"
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
        logEvent(&st, &items, quiet: quiet, emoji: "👤", title: "\(n.name) joined the scene", detail: String(text.prefix(80)),
                 post: p.id, handles: [n.handle], weight: 12, history: "\(n.name) joined the scene.")
    }

    /// Every two weeks the rankings close, rewards go out and a new season starts.
    func checkSeason(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        let now = Date()
        guard let start = st.ex.seasonStart else {
            st.ex.seasonStart = now
            st.ex.season = st.ex.season ?? 1
            return
        }
        guard now.timeIntervalSince(start) >= Game.seasonDays * 86400 else { return }
        let n = st.ex.season ?? 1
        let rank = myRank(st)
        let gems = 40 + max(0, 21 - rank) * 5
        st.ex.gems += gems
        var badges = st.ex.lvBadges ?? []
        let name = rank <= 10 ? "Season \(n) · Top \(rank)" : "Season \(n) finisher"
        badges.append(LevelBadge(id: "season-\(n)", level: st.level, name: name, symbol: rank <= 3 ? "trophy.fill" : "medal.fill"))
        st.ex.lvBadges = badges
        st.ex.season = n + 1
        st.ex.seasonStart = now
        notify(&st, "milestone", "Season \(n) is over", sub: "You finished #\(rank). +\(gems) gems and a badge.", emoji: "🏆")
        logEvent(&st, &items, quiet: quiet, emoji: "🏆", title: "Season \(n) ended", detail: "You finished #\(rank) in the scene rankings. +\(gems) gems.",
                 weight: 85, history: "Season \(n) ended. You finished #\(rank).")
    }
}
