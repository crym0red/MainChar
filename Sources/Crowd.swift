import SwiftUI

/// The anonymous crowd: random accounts that drop short, unpunctuated, brainrot-style comments.
enum Crowd {
    private static let a = ["lowkey", "tiny", "quiet", "sleepy", "feral", "soft", "mid", "ghost", "pixel", "moss", "static", "velvet", "neon", "salty", "crunchy", "dizzy", "lazy", "cold", "rusty", "fuzzy", "cursed", "blessed", "damp", "shy", "loud"]
    private static let b = ["lena", "jay", "owl", "fox", "riot", "byte", "mango", "crab", "toast", "moth", "echo", "sam", "kai", "nova", "dex", "ivy", "milo", "zed", "noodle", "gremlin", "pigeon", "ninja", "raven", "lemon", "bean"]
    private static let first = ["mia", "noah", "liam", "zoe", "eli", "ava", "leo", "ruby", "finn", "nora", "owen", "tess", "cole", "jade", "ty", "bri", "max", "ari", "dre", "kat"]
    private static let last = ["w", "k", "r", "m", "lee", "ray", "cruz", "fox", "vale", "park", "hart", "day", "bell", "ross", "nash"]

    static func make() -> (name: String, handle: String) {
        let n = Int.random(in: 1...99)
        let style = Int.random(in: 0..<5)
        let handle: String
        switch style {
        case 0: handle = "\(a.randomElement()!)\(b.randomElement()!)\(n)"
        case 1: handle = "\(a.randomElement()!)_\(b.randomElement()!)"
        case 2: handle = "\(first.randomElement()!).\(last.randomElement()!)\(n)"
        case 3: handle = "\(first.randomElement()!)\(last.randomElement()!)_\(Int.random(in: 0...2009))"
        default: handle = "\(b.randomElement()!).\(a.randomElement()!)"
        }
        let name = handle.filter { !$0.isNumber }.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " ")
            .split(separator: " ").map { String($0).capitalized }.joined(separator: " ")
        return (name.isEmpty ? handle : name, handle)
    }

    static func npc(for handle: String) -> NPC {
        let name = handle.filter { !$0.isNumber }.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " ")
            .split(separator: " ").map { String($0).capitalized }.joined(separator: " ")
        let h = HK.h(handle)
        let bios = ["just here for the comments", "posting through it", "nobody asked but here i am", "professional lurker", "touch grass later", "chronically online", "mostly vibes", "here for the drama"]
        let t = Trait.allCases[Int(h % UInt32(Trait.allCases.count))]
        return NPC(id: handle, name: name.isEmpty ? handle : name, handle: handle, emoji: "🙂", bio: bios[Int((h >> 4) % UInt32(bios.count))],
                   trait: t, followers: 40 + Int(h % 4000), affinity: Int.random(in: 10...30), followsYou: false)
    }

    static func looksLikeCrowd(_ handle: String) -> Bool { handle.contains(".") || handle.contains("_") || handle.last?.isNumber == true }

    private static let cities = ["Austin", "Lagos", "Manila", "Toronto", "Berlin", "Seoul", "Phoenix", "Lisbon", "Jakarta", "Chicago", "Sao Paulo", "Dublin", "Mumbai", "Atlanta", "Sydney", "Mexico City", "Oslo", "Nairobi", "Denver", "Osaka"]
    static func city(_ handle: String) -> String { cities[Int((HK.h(handle.lowercased()) >> 7) % UInt32(cities.count))] }
    static func joined(_ handle: String) -> String {
        let back = Int((HK.h(handle.lowercased()) >> 11) % 40) + 1
        let d = Calendar.current.date(byAdding: .month, value: -back, to: Date()) ?? Date()
        return d.formatted(.dateTime.month(.abbreviated).year())
    }
}

enum Brainrot {
    private static let single = ["nah", "bruh", "fr", "ong", "cooked", "mid", "real", "fax", "ratio", "first", "wtf", "lmao", "huh", "cap", "w", "l", "ate", "tuff", "sybau", "gng", "twin", "wild", "dead", "crying", "insane", "nahhh", "bffr", "who asked", "no way", "deadass", "idk", "icl", "ngl", "pmo", "ts", "67", "true", "unreal", "oh no", "hold up", "sheesh", "bet", "say less", "yep", "crashout", "aura", "npc behavior", "fell off", "peak", "peak fiction"]
    private static let combo = ["ts tuff gng", "nah this is wild", "bro really said that", "im crying fr", "this aint it twin", "lowkey real", "not me reading this at 3am", "why is this so true", "ong i cant", "nah fr fr", "this post is cooked", "aura points deducted", "aura +1000", "who let him cook", "let him cook", "im not even mad", "me when i see this", "this is so unserious", "thats crazy", "wait what", "no because why", "bro is delusional", "he has a point though", "yall are so unserious", "this the best post today", "i saw this coming", "real ones know", "ok and", "who is this guy", "bro thinks hes him", "ohio moment", "chat is this real", "he fell off", "we are so back", "its over", "the timeline is cooked", "mans said what"]
    private static let tpl = ["{w} ahh post", "{w} is cooked", "not the {w}", "{w} fr", "{w} real", "{w} tuff", "bro and his {w}", "this {w} take", "{w} gng", "{w} moment", "ts about {w}", "nah {w} crazy"]
    private static let keys = "asdfghjklqwertyuiopzxcvbnm"

    private static func gibberish() -> String {
        switch Int.random(in: 0..<5) {
        case 0: return String((0..<Int.random(in: 5...10)).map { _ in "asdfghjkl".randomElement()! })
        case 1:
            let c = ["nah", "bruh", "lmao", "ayo", "heyy", "stoppp", "omgggg", "bruhhh", "yooo", "waittt"].randomElement()!
            return c + String(repeating: c.last!, count: Int.random(in: 2...6))
        case 2: return String((0..<Int.random(in: 4...7)).map { _ in keys.randomElement()! })
        case 3: return ["hdhdhs", "jsjsjsj", "ahahahaha", "sksksk", "ksksks", "ajsjsjs", "hshshs", "lololol", "wkwkwk", "ayoooo"].randomElement()!
        default: return ["h", "m", "k", "o", "bro", "no", "ok"].randomElement()! + String(repeating: ["h", "m", "o", "s"].randomElement()!, count: Int.random(in: 2...5))
        }
    }

    static func line(about text: String = "") -> String {
        let h = Spicy.heat
        if h >= 2, Double.random(in: 0...1) < (h == 3 ? 0.4 : 0.22) { return Spicy.crowd[h].randomElement()! }
        let r = Double.random(in: 0...1)
        var out: String
        if r < 0.28 { out = single.randomElement()! }
        else if r < 0.52 { out = combo.randomElement()! }
        else if r < 0.72 { out = gibberish() }
        else {
            let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 4 }
            if let w = words.randomElement() { out = tpl.randomElement()!.replacingOccurrences(of: "{w}", with: w) } else { out = combo.randomElement()! }
        }
        return out.filter { !"!?.,;:'\"".contains($0) }.lowercased()
    }
}

extension Game {
    /// Anonymous crowd comments for a post.
    func crowdComments(_ n: Int, about text: String) -> [Comment] {
        (0..<n).map { _ in
            let u = Crowd.make()
            return Comment(name: u.name, handle: u.handle, emoji: "🙂", text: Brainrot.line(about: text))
        }
    }

    /// Small, frequent updates so the feed never sits still: likes creep up, strangers pile into comments, people post.
    func liveTick() {
        guard playing, s.intro?.done != false else { return }
        var st = s
        releaseQueued(&st)
        if Double.random(in: 0...1) < 0.05 { spawnArgument(&st, quiet: true) }
        else if Double.random(in: 0...1) < 0.04 { spawnLeak(&st, quiet: true) }
        else if Double.random(in: 0...1) < 0.07 { npcRepost(&st) }
        let recent = Array(st.posts.indices.prefix(14))
        guard !recent.isEmpty else { s = st; return }
        for i in recent.shuffled().prefix(Int.random(in: 1...3)) {
            let l = st.posts[i].likes
            st.posts[i].likes += max(1, Int(Double(l) * Double.random(in: 0.01...0.05)))
            if Double.random(in: 0...1) < 0.3 { st.posts[i].reposts += Int.random(in: 1...3) }
        }
        if Double.random(in: 0...1) < 0.55, let i = recent.randomElement(), st.posts[i].comments.count < 60, (st.posts[i].queue ?? []).isEmpty {
            let p = st.posts[i]
            let c: [Comment]
            if Double.random(in: 0...1) < 0.25, let one = makeComments(st, auraDelta: 1, count: 1, exclude: p.authorHandle, text: p.text).first { c = [one] }
            else { c = crowdComments(Int.random(in: 1...3), about: p.text) }
            st.posts[i].comments.append(contentsOf: c)
            if p.isYou, let first = c.first, Double.random(in: 0...1) < 0.35 {
                notify(&st, "reply", "\(first.name) replied to your post", sub: "\(first.handle): \(first.text)", handle: first.handle, emoji: first.emoji)
            }
        }
        if Double.random(in: 0...1) < 0.16 {
            let away = st.ex.gone ?? [:]
            let cast = st.npcs.filter { $0.id != "newsdesk" && away[$0.handle] == nil }
            if cast.count >= 2 {
                var items: [DigestItem] = []
                simPost(&st, &items, cast, true)
                if st.posts.count > 120 { st.posts.removeLast(st.posts.count - 120) }
            }
        }
        s = st
    }
}
