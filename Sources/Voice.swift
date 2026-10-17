import Foundation

// MARK: - Voice engine: context, continuity, character voice, memory, repetition control

struct CharVoice: Codable {
    var recent: [UInt32] = []
    var sig: [String] = []
    var hooks: [String] = []
}
struct Stance: Codable { var v: Int; var at: Date }
struct VoiceStore: Codable {
    var chars: [String: CharVoice] = [:]
    var stance: [String: Stance] = [:]
    var global: [UInt32] = []
}

enum VoiceT {
    static func fnv(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for b in s.utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return h
    }
    /// words that make an insult recognisable, so the same one isn't reused a few lines apart
    static let sigWords: [String] = ["clown","bozo","goblin","cryptid","liability","fraud","snake","fake","cringe","trash","mid","cooked","washed",
        "embarrassing","delusional","ratio","cope","L","menace","amateur","hack","has-been","mess","hypocrite","liar","tryhard","irrelevant","unhinged"]
    static func sig(_ s: String) -> [String] {
        let l = " " + s.lowercased().replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: ".", with: " ") + " "
        return sigWords.filter { l.contains(" " + $0.lowercased() + " ") || l.contains(" " + $0.lowercased() + "s ") }
    }

    // trait-flavored callbacks to remembered events ({t} = the memory)
    static let memNeg: [Trait: [String]] = [
        .mogul: ["let's not pretend {t}. it's in my file", "{t}. i don't forget a bad investment", "after {t}, why would i back you now?"],
        .wholesome: ["i'm still a bit hurt that {t}", "i forgive easily but {t} stayed with me", "i keep thinking about how {t}. be kinder next time"],
        .hater: ["{t}. and you wonder why nobody likes you", "didn't forget that {t}. never will", "this is exactly what you did when {t}"],
        .gossip: ["the group chat still talks about how {t}", "everyone remembers {t}. everyone", "receipts: {t}. i have them"],
        .chaos: ["i'm not over how {t}. i think about it in the shower", "{t}. my villain arc has a start date and it's that", "YOU. {t}. NEVER FORGETTING"],
        .hype: ["bro, {t}. i can't just let that go", "L. {t}. remember that?", "{t}. i was there, chat was there"]]
    static let memPos: [Trait: [String]] = [
        .mogul: ["{t}. that's why i keep you on my short list", "you've earned my respect: {t}", "{t}. loyalty has a price and you paid it"],
        .wholesome: ["i'm still smiling about how {t} 🥹", "{t}. you're one of the good ones", "{t} and i'll never forget it 💛"],
        .hater: ["fine, you're alright. {t}. don't let it go to your head", "{t}. i hate that i respect it", "you're the only one i tolerate, because {t}"],
        .gossip: ["i've been telling everyone how {t}", "the group chat loves you since {t}", "{t}. i'm on your side, always"],
        .chaos: ["{t}. i'd die for you. it's the lore", "OKAY BUT {t}. i'm still emotional", "{t} and i've been feral about it since"],
        .hype: ["{t}. that's my guy for life", "bro {t}. W forever", "never forgetting how {t}. we ride"]]
    // callbacks to something the player said that annoyed them ({h} = the phrase)
    static let hook: [Trait: [String]] = [
        .mogul: ["you said \"{h}\" and the market noticed", "\"{h}\" is not a strategy"],
        .wholesome: ["i can't stop thinking about \"{h}\". it was unkind", "\"{h}\" really stuck with me, and not in a good way"],
        .hater: ["\"{h}\". that's the best you've got? embarrassing", "still laughing at \"{h}\""],
        .gossip: ["\"{h}\" is already in the group chat, btw", "so you really said \"{h}\". noted"],
        .chaos: ["\"{h}\" LIVES IN MY HEAD RENT FREE and i hate it", "\"{h}\"?? sir??"],
        .hype: ["\"{h}\" was an L and you know it", "bro said \"{h}\" with his chest"]]
    // lines about an ongoing feud ({c} cause, {r} rival)
    static let feud: [Trait: [String]] = [
        .mogul: ["this is about {c} and your numbers are bad, @{r}", "still waiting on you to admit {c} was a mistake, @{r}"],
        .wholesome: ["i just wish we could talk about {c} like adults, @{r}", "@{r} this whole {c} thing is exhausting"],
        .hater: ["@{r} nobody forgot {c}. shut up", "{c} again? you're a broken record, @{r}"],
        .gossip: ["and the whole {c} thing, @{r}? the receipts are public", "let's talk about {c}, @{r}, since you love an audience"],
        .chaos: ["@{r} {c}!!! DON'T CHANGE THE SUBJECT", "this is still about {c} and i'll die on this hill"],
        .hype: ["@{r} bro you're still on {c}? take the L", "{c}, @{r}. we've been here. you lost"]]
}

extension Game {
    private func vkey(_ st: GameState, _ a: String) -> String { String(st.id.uuidString.prefix(6)) + "|" + a }

    private func isNeg(_ b: String) -> Bool {
        b == "comment.neg" || b == "rebut.fight" || b == "dm.cold"
    }
    private func flip(_ b: String) -> String {
        switch b {
        case "comment.neg": return "comment.pos"
        case "comment.pos": return "comment.neg"
        case "rebut.fight": return "rebut.agree"
        case "rebut.agree": return "rebut.fight"
        case "dm.cold": return "dm.warm"
        case "dm.warm": return "dm.cold"
        default: return b
        }
    }

    /// Picks a reply for an NPC with full context. Returns (text, positive).
    func voiceLine(_ st: GameState, _ n: NPC, bucket b0: String, target: String?, toPlayer: Bool,
                   text: String, heat h0: Double, topic tIn: String? = nil, angry: Bool = false) -> (String, Bool)? {
        let me = st.persona.handle
        let vk = vkey(st, n.handle)
        let sk = vkey(st, n.handle + ">" + (target ?? "me"))
        var cv = voice.chars[vk] ?? CharVoice()
        var bucket = b0
        var heat = h0

        if angry {
            if toPlayer || b0.hasPrefix("dm") {
                switch bucket {
                case "comment.pos", "comment.neg": bucket = "roast.hard"
                case "rebut.agree", "rebut.fight": bucket = "rebut.fight.hot"
                case "dm.warm", "dm.cold": bucket = "dm.hostile"
                default: break
                }
            } else if bucket == "rebut.fight" { bucket = "rebut.fight.hot" }
            heat = 0.95
        }
        // 1) continuity: what they said to this target a moment ago decides what they say now
        var sv = 0
        if let s = voice.stance[sk], Date().timeIntervalSince(s.at) < 1800 { sv = s.v }
        let feudRow = target.flatMap { t in
            activeFeuds(st).first(where: { $0.id == Game.rivalKey(n.handle, t) })
        }
        let memF = toPlayer ? feeling(st, n.handle) : 0
        let override = angry || feudRow != nil || abs(memF) >= 4
        if !override {
            if sv <= -2, !isNeg(bucket), Double.random(in: 0...1) < 0.7 { bucket = flip(bucket) }
            else if sv >= 2, isNeg(bucket), Double.random(in: 0...1) < 0.6 { bucket = flip(bucket) }
        }
        // 2) relationship and feud set the temperature
        if toPlayer { heat += Double(-n.affinity + 50) / 250.0 }
        if let f = feudRow { heat = min(0.95, heat + 0.1 + Double(f.heat) * 0.05) }
        heat = min(0.95, max(0.05, heat))

        // 3) topic the text is actually about
        let topics = Topics.forWorld(st.world)
        let low = text.lowercased()
        let topic = tIn ?? topics.first(where: { low.contains($0.lowercased()) }) ?? topics.randomElement() ?? "this"
        let quote = Corpus.quote(from: text, fallback: topic)

        var out: String? = nil
        var positive = !(isNeg(bucket) || bucket == "roast.hard" || bucket == "rebut.fight.hot" || bucket == "dm.hostile")

        // 4) personal callbacks: feud > memory > hook
        let r = Double.random(in: 0...1)
        if let f = feudRow, r < 0.45, !angry || !toPlayer, let tpl = VoiceT.feud[n.trait]?.randomElement() {
            let rival = st.npcs.first(where: { $0.handle == target })?.handle ?? (target ?? "")
            out = tpl.replacingOccurrences(of: "{c}", with: f.cause ?? topic).replacingOccurrences(of: "{r}", with: rival)
            positive = false
        } else if toPlayer, abs(memF) >= 2, r < 0.35, !angry, let m = strongestMemory(st, n.handle, positive: memF > 0) {
            let tpl = ((memF > 0 ? VoiceT.memPos : VoiceT.memNeg)[n.trait] ?? []).randomElement()
            if let tpl = tpl {
                out = tpl.replacingOccurrences(of: "{t}", with: m.text)
                positive = memF > 0
            }
        } else if toPlayer, positive == false, r < 0.4, let h = cv.hooks.last,
                  let tpl = VoiceT.hook[n.trait]?.randomElement() {
            out = tpl.replacingOccurrences(of: "{h}", with: h)
            positive = false
        }

        // 5) otherwise: corpus line, filtered by what this character and the feed already said
        if out == nil {
            let recent = Set(cv.recent), glob = Set(voice.global)
            let avoid = Set(cv.sig.suffix(4))
            out = Corpus.line(trait: n.trait, bucket: bucket, me: me, topic: topic, quote: quote, heat: heat, accept: { c in
                let hh = VoiceT.fnv(c)
                if recent.contains(hh) || glob.contains(hh) { return false }
                if !avoid.isEmpty, !avoid.isDisjoint(with: VoiceT.sig(c)) { return false }
                return true
            })
        }
        guard let line = out, ContentPrefs.allows(line) else { return nil }

        // 6) remember what was said
        let hh = VoiceT.fnv(line)
        cv.recent.append(hh); if cv.recent.count > 60 { cv.recent.removeFirst(cv.recent.count - 60) }
        cv.sig.append(contentsOf: VoiceT.sig(line)); if cv.sig.count > 8 { cv.sig.removeFirst(cv.sig.count - 8) }
        if toPlayer, !positive {
            let w = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" }).map(String.init)
            if w.count >= 3 {
                let i = Int.random(in: 0...(w.count - 3))
                cv.hooks.append(w[i...(i + 2)].joined(separator: " "))
                if cv.hooks.count > 4 { cv.hooks.removeFirst() }
            }
        }
        voice.chars[vk] = cv
        voice.global.append(hh); if voice.global.count > 150 { voice.global.removeFirst(voice.global.count - 150) }
        let nv = positive ? max(0, sv) + 1 : min(0, sv) - 1
        voice.stance[sk] = Stance(v: max(-3, min(3, nv)), at: Date())
        if voice.stance.count > 400 {
            let cut = Date().addingTimeInterval(-1800)
            voice.stance = voice.stance.filter { $0.value.at > cut }
        }
        return (line, positive)
    }
}
