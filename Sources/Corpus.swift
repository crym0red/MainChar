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

    /// bucket: comment.pos, comment.neg, rebut.agree, rebut.fight, dm.warm, dm.cold
    static func line(trait: Trait, bucket: String, me: String, topic: String, quote: String) -> String? {
        guard var t = raw("\(trait.rawValue)|\(bucket)") else { return nil }
        t = t.replacingOccurrences(of: "{me}", with: "@" + me)
        t = t.replacingOccurrences(of: "{topic}", with: topic)
        t = t.replacingOccurrences(of: "{quote}", with: quote)
        return t
    }
}
