import Foundation

/// Offline reaction engine: ~300,000 pre-written replies (hype, roasts, nitpicks, clap-backs, DMs)
/// stored in Resources/responses.txt. The file is memory-mapped and indexed once; a line is only
/// decoded when it is picked.
enum Corpus {
    private static var data: Data? = nil
    private static var index: [String: [UInt32]] = [:]
    private static var loaded = false
    private static let lock = NSLock()

    static func load() {
        lock.lock()
        defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        guard let url = Bundle.main.url(forResource: "responses", withExtension: "txt"),
              let d = try? Data(contentsOf: url, options: .mappedIfSafe) else { return }
        data = d
        var idx: [String: [UInt32]] = [:]
        var cur = ""
        let n = d.count
        d.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let b = raw.bindMemory(to: UInt8.self)
            var start = 0
            var i = 0
            while i < n {
                if b[i] == 10 {
                    if i > start {
                        if b[start] == 64, start + 1 < n, b[start + 1] == 64 {
                            cur = String(decoding: UnsafeBufferPointer(rebasing: b[(start + 2)..<i]), as: UTF8.self)
                        } else if !cur.isEmpty {
                            idx[cur, default: []].append(UInt32(start))
                        }
                    }
                    start = i + 1
                }
                i += 1
            }
        }
        index = idx
    }

    static var count: Int {
        load()
        return index.values.reduce(0) { $0 + $1.count }
    }

    private static func raw(_ key: String) -> String? {
        load()
        guard let d = data, let offs = index[key], !offs.isEmpty else { return nil }
        let s = Int(offs[Int.random(in: 0..<offs.count)])
        var e = s
        let n = d.count
        while e < n && d[e] != 10 { e += 1 }
        return String(decoding: d[s..<e], as: UTF8.self)
    }

    /// A word or short phrase lifted from the text being reacted to.
    static func quote(from text: String, fallback: String) -> String {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .map(String.init).filter { $0.count > 3 }
        guard !words.isEmpty else { return fallback }
        if words.count >= 2, Bool.random() {
            let i = Int.random(in: 0..<(words.count - 1))
            return words[i] + " " + words[i + 1]
        }
        return words.randomElement() ?? fallback
    }

    /// Picks the spicier or tamer variant of a bucket. heat 0 = polite, 1 = full wild west.
    private static func flavor(_ b: String, _ heat: Double) -> String {
        let r = Double.random(in: 0...1)
        switch b {
        case "comment.neg": return r < heat * 0.55 ? "roast.hard" : (r < heat * 0.55 + 0.22 ? "roast.nitpick" : b)
        case "comment.pos": return r < heat * 0.45 ? "hype.max" : b
        case "rebut.fight": return r < 0.2 + heat * 0.55 ? "rebut.fight.hot" : b
        case "rebut.agree": return r < 0.3 ? "rebut.defend" : b
        case "dm.cold": return r < heat * 0.65 ? "dm.hostile" : b
        default: return b
        }
    }

    /// bucket: comment.pos, comment.neg, rebut.agree, rebut.fight, dm.warm, dm.cold (plus the wild-west
    /// variants roast.hard, roast.nitpick, hype.max, rebut.fight.hot, rebut.defend, dm.hostile,
    /// post.subtweet, post.rant, post.hype which flavor() mixes in).
    static func line(trait: Trait, bucket: String, me: String, topic: String, quote: String, heat: Double = 0.45,
                     accept: ((String) -> Bool)? = nil) -> String? {
        var h = heat
        if trait == .hater || trait == .chaos { h += 0.2 } else if trait == .wholesome { h -= 0.2 }
        h = min(0.95, max(0.0, h))
        let b = flavor(bucket, h)
        var pick: String? = nil
        for _ in 0..<(accept == nil ? 1 : 14) {
            guard let c = raw("\(trait.rawValue)|\(b)") ?? raw("\(trait.rawValue)|\(bucket)") else { return nil }
            pick = c
            if accept?(c) ?? true { break }
        }
        guard var t = pick else { return nil }
        t = t.replacingOccurrences(of: "{me}", with: "@" + me)
        t = t.replacingOccurrences(of: "{topic}", with: topic)
        t = t.replacingOccurrences(of: "{quote}", with: quote)
        return t
    }

    /// A feed post in the character's voice: subtweets, rants and hype.
    static func post(trait: Trait, me: String, topic: String) -> String? {
        let r = Double.random(in: 0...1)
        let bucket: String
        switch trait {
        case .hater, .gossip: bucket = r < 0.5 ? "post.subtweet" : (r < 0.85 ? "post.rant" : "post.hype")
        case .hype, .wholesome: bucket = r < 0.6 ? "post.hype" : (r < 0.8 ? "post.rant" : "post.subtweet")
        case .chaos: bucket = r < 0.5 ? "post.rant" : (r < 0.75 ? "post.subtweet" : "post.hype")
        case .mogul: bucket = r < 0.4 ? "post.hype" : (r < 0.7 ? "post.subtweet" : "post.rant")
        }
        guard var t = raw("\(trait.rawValue)|\(bucket)") else { return nil }
        t = t.replacingOccurrences(of: "{me}", with: "@" + me)
        t = t.replacingOccurrences(of: "{topic}", with: topic)
        t = t.replacingOccurrences(of: "{quote}", with: topic)
        return t
    }
}
