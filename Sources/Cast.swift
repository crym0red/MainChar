import Foundation

/// Fills every world out to a full cast so the feed, stories and live row always feel crowded.
enum CastGen {
    static let target = 44

    private static let last = ["Mercer","Delgado","Foster","Reyes","Hayes","Costa","Ivanov","Bishop","Okafor","Nakamura","Lindqvist","Park","Hossain","Moreau","Castillo","Whitaker","Brandt","Silva","Novak","Adeyemi","Kowalski","Tanaka","Rivera","Sterling","Quinn","Maddox","Voss","Navarro","Holloway","Ferreira","Ahmed","Sokolov","Grant","Ellison","Rahman","Kim","Duarte","Vega","Hart","Lowell","Santos","Petrov","Wells","Cruz","Blake","Marsh","Chen","Idris","Fox","Ward"]

    private static let emoji: [Trait: [String]] = [
        .hype: ["🔥", "🚀", "⚡️", "🎉", "💪", "🏆"],
        .hater: ["🙄", "🥱", "😒", "🗑️", "👎", "🧂"],
        .wholesome: ["🌻", "🫶", "🌈", "☕️", "🧸", "🌸"],
        .gossip: ["👀", "☕️", "🧵", "📸", "🤫", "🐍"],
        .mogul: ["💼", "💰", "📈", "🏢", "🕶️", "🥂"],
        .chaos: ["🤡", "💀", "🌀", "🦝", "🧨", "👹"]
    ]

    private static let bios: [Trait: [String]] = [
        .hype: ["{t} is my whole personality", "first to every drop. {t} supremacy", "hyping {t} 24/7", "if it's {t}, i'm already there", "built different. {t} forever"],
        .hater: ["{t} is overrated. fight me", "unimpressed by {t} since forever", "your fave's {t} is mid", "here to say what everyone's thinking about {t}", "{t} takes nobody asked for"],
        .wholesome: ["just here for good {t} vibes", "{t} enthusiast, hugs enthusiast", "be kind, even about {t}", "making {t} a nicer place", "proud of everyone in {t}"],
        .gossip: ["knows who did what in {t}", "receipts on all the {t} drama", "i didn't say it, i just posted it. {t}", "{t} tea, served hot", "group chat admin for {t}"],
        .mogul: ["building the biggest name in {t}", "i fund {t}. you're welcome", "{t} is a business. act like it", "deals, not drama. mostly {t}", "ceo of {t} (unofficially)"],
        .chaos: ["{t} but make it unhinged", "chaos agent. {t} is my playground", "{t} lives in my head rent free", "posting through it. {t}", "no thoughts, only {t}"]
    ]

    private static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    // MARK: Sideloading / jailbreak scene

    static func isScene(_ w: WorldDef) -> Bool {
        let s = (w.title + " " + w.goal + " " + w.setting + " " + w.tagline).lowercased()
        return ["sideload", "jailbreak", "hacker", "dylib", "tweak", "ipa", "signer", "ios dev"].contains { s.contains($0) }
    }

    private static let sceneA = ["binary", "zero_day", "pixel", "glitch", "os", "cyber", "sideload", "ping", "void", "kernel", "root", "dylib", "hook", "patch",
                                 "sandbox", "cert", "ipa", "swizzle", "tweak", "palera", "dopamine", "troll", "payload", "exploit", "fuzz", "stack", "heap",
                                 "byte", "hex", "opcode", "daemon", "rootless", "udid", "mach", "arm64", "theos", "frida", "ghidra", "lldb", "jailbreak",
                                 "revoke", "entitle", "provision", "plist", "signer", "bootrom", "nand", "ramdisk", "sep"]
    private static let sceneB = ["bouncer", "dreamer", "purist", "weaver", "optimizer", "sage", "sam", "stalker", "smith", "witch", "goblin", "wizard",
                                 "monk", "whisperer", "hunter", "dev", "ninja", "nomad", "pilot", "junkie", "maker", "gremlin", "ghost", "cook", "fiend",
                                 "wrangler", "tinkerer", "nerd", "lord", "king"]
    private static let sceneBios: [Trait: [String]] = [
        .hype: ["shipped another tweak. you're welcome", "new dylib dropping tonight", "every release is a banger", "jailbreak is back and so am i", "if it injects, i ship it", "iOS 26 support in 3... 2..."],
        .hater: ["your signer is a rental with extra steps", "revoked again? skill issue", "another 'new' jailbreak that's a repack", "certs expire, so does your credibility", "nobody asked for your fork", "bootloop merchants log off"],
        .wholesome: ["free sideloading for everyone, no paywall", "helping newbies install their first IPA", "documenting everything so you don't have to ask", "be kind, it's just an app", "open source or it didn't happen", "patch notes with love"],
        .gossip: ["knows who leaked the cert", "who got revoked this week? i know", "receipts from every repo drama", "the discord is talking", "i saw the commit history, babe", "dm me the leak"],
        .mogul: ["selling certs at scale", "i fund the tweaks you use", "signing service, 40k users", "enterprise certs, wholesale", "your favorite repo runs on my servers", "monetizing the scene since forever"],
        .chaos: ["ran it on prod. it works somehow", "kernel panic enthusiast", "i sideload at 3am and break things", "crashes are a lifestyle", "pushed to main on a friday", "it compiles, ship it"]
    ]

    private static func titleCase(_ h: String) -> String {
        h.split(separator: "_").map { cap(String($0)) }.joined(separator: " ")
    }

    static func pad(_ npcs: inout [NPC], world: WorldDef, avoid: [String] = []) {
        if isScene(world) { padScene(&npcs, avoid: avoid) } else { padGeneric(&npcs, topics: Topics.forWorld(world), avoid: avoid) }
    }

    private static func pickTrait() -> Trait {
        let weights: [(Trait, Int)] = [(.hype, 20), (.hater, 20), (.wholesome, 15), (.gossip, 17), (.mogul, 10), (.chaos, 18)]
        var r = Int.random(in: 0..<100)
        for (t, w) in weights { if r < w { return t }; r -= w }
        return .hype
    }

    private static func followers() -> Int {
        let roll = Double.random(in: 0...1)
        if roll < 0.70 { return Int.random(in: 800...40_000) }
        if roll < 0.92 { return Int.random(in: 40_000...400_000) }
        return Int.random(in: 400_000...2_000_000)
    }

    private static func padScene(_ npcs: inout [NPC], avoid: [String]) {
        let real = npcs.filter { $0.id != "newsdesk" }.count
        guard real < target else { return }
        var used = Set(npcs.map { $0.handle.lowercased() } + avoid.map { $0.lowercased() })
        var made = 0, guardN = 0
        while real + made < target && guardN < 800 {
            guardN += 1
            guard let a = sceneA.randomElement(), let b = sceneB.randomElement() else { continue }
            var h = "\(a)_\(b)"
            if Double.random(in: 0...1) < 0.25 { h += "_\(Int.random(in: 2...99))" }
            if Double.random(in: 0...1) < 0.15 { h = h.replacingOccurrences(of: "_", with: "") }
            if used.contains(h.lowercased()) { continue }
            used.insert(h.lowercased())
            let t = pickTrait()
            let name = h.contains("_") && Double.random(in: 0...1) < 0.5 ? titleCase(h.components(separatedBy: "_").prefix(2).joined(separator: "_")) : h
            npcs.append(NPC(id: h, name: name, handle: h, emoji: emoji[t]?.randomElement() ?? "🙂",
                            bio: sceneBios[t]?.randomElement() ?? "sideloading since day one", trait: t,
                            followers: followers(), affinity: Int.random(in: 8...28), followsYou: false))
            made += 1
        }
    }

    private static func padGeneric(_ npcs: inout [NPC], topics: [String], avoid: [String] = []) {
        let real = npcs.filter { $0.id != "newsdesk" }.count
        guard real < target else { return }
        let fems = AvatarLoader.femNames.filter { $0 != "alex_m" }.sorted()
        let mals = AvatarLoader.malNames.filter { $0 != "alex_m" }.sorted()
        var used = Set(npcs.map { $0.handle.lowercased() } + avoid.map { $0.lowercased() })
        var names = Set(npcs.map { $0.name.lowercased() })
        let weights: [(Trait, Int)] = [(.hype, 20), (.hater, 20), (.wholesome, 15), (.gossip, 17), (.mogul, 10), (.chaos, 18)]
        func trait() -> Trait {
            var r = Int.random(in: 0..<100)
            for (t, w) in weights { if r < w { return t }; r -= w }
            return .hype
        }
        var made = 0
        var guardN = 0
        while real + made < target && guardN < 500 {
            guardN += 1
            let woman = Bool.random()
            guard let f = (woman ? fems : mals).randomElement(), let l = last.randomElement() else { continue }
            let name = cap(f) + " " + l
            if names.contains(name.lowercased()) { continue }
            let lf = l.lowercased()
            let styles = ["\(f)_\(lf)", "\(f).\(lf)", "\(f)_\(lf)\(Int.random(in: 2...99))", "\(f)\(Int.random(in: 2...99))", "\(f)_\(lf.prefix(3))"]
            guard let h = styles.randomElement(), !used.contains(h) else { continue }
            used.insert(h); names.insert(name.lowercased())
            let t = trait()
            let topic = topics.randomElement() ?? "the scene"
            let bio = (bios[t]?.randomElement() ?? "{t}").replacingOccurrences(of: "{t}", with: topic.lowercased())
            let roll = Double.random(in: 0...1)
            let fol: Int
            if roll < 0.70 { fol = Int.random(in: 800...40_000) }
            else if roll < 0.92 { fol = Int.random(in: 40_000...400_000) }
            else { fol = Int.random(in: 400_000...2_000_000) }
            npcs.append(NPC(id: h, name: name, handle: h, emoji: emoji[t]?.randomElement() ?? "🙂", bio: bio, trait: t,
                            followers: fol, affinity: Int.random(in: 8...28), followsYou: false))
            made += 1
        }
    }
}
