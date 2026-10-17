import Foundation

// MARK: - Developer-scene drama engine (sideloading / jailbreak worlds only)

extension Game {
    private static let appA = ["Mini", "Zip", "Sign", "Side", "Sky", "Nova", "Ghost", "Atlas", "Vault", "Pulse", "Flux", "Onyx", "Echo", "Rune", "Kite", "Hex"]
    private static let appB = ["Sign", "Store", "Load", "Kit", "Forge", "Box", "Drop", "Jb", "Hook", "Patch", "Inject", "Pack"]

    private func appName() -> String { (Game.appA.randomElement() ?? "Nova") + (Game.appB.randomElement() ?? "Sign") }

    private func pick(_ cast: [NPC], _ t: Trait, not: [String] = []) -> NPC? {
        cast.filter { $0.trait == t && !not.contains($0.handle) }.randomElement()
    }
    private func anyNPC(_ cast: [NPC], not: [String] = []) -> NPC? {
        cast.filter { !not.contains($0.handle) }.randomElement()
    }
    private func cm(_ n: NPC, _ text: String) -> Comment {
        Comment(name: n.name, handle: n.handle, emoji: n.emoji, text: text, verified: n.followers >= 40000)
    }
    private func fill(_ s: String, _ app: String, _ a: String = "", _ b: String = "") -> String {
        s.replacingOccurrences(of: "{app}", with: app).replacingOccurrences(of: "{a}", with: a).replacingOccurrences(of: "{b}", with: b)
    }

    /// One scene storyline. Called from the world sim.
    func simScene(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool) {
        guard cast.count >= 6 else { return }
        let app = appName()
        switch Int.random(in: 0..<5) {
        case 0: sceneRelease(&st, &items, cast, quiet, app)
        case 1: sceneLeak(&st, &items, cast, quiet, app)
        case 2: sceneViral(&st, &items, cast, quiet, app)
        case 3: sceneRevoke(&st, &items, cast, quiet, app)
        default: sceneBroken(&st, &items, cast, quiet, app)
        }
    }

    private func publishScene(_ st: inout GameState, _ author: NPC, _ text: String, tag: String, comments: [Comment],
                              viral: Bool = false) -> Post {
        var p = makePost(author, text, st)
        p.tag = tag
        stampPost(&p, st)
        p.comments = comments
        p.likes = max(p.likes * (viral ? 6 : 2), 40)
        p.reposts = p.likes / (viral ? 4 : 7)
        p.viral = viral
        st.posts.insert(p, at: 0)
        return p
    }

    // 1) a developer announces something, rivals tear into it
    private func sceneRelease(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool, _ app: String) {
        guard let dev = pick(cast, [.hype, .mogul, .wholesome, .chaos].randomElement() ?? .hype) ?? anyNPC(cast),
              let rival = pick(cast, .hater, not: [dev.handle]) ?? pick(cast, .mogul, not: [dev.handle]) ?? anyNPC(cast, not: [dev.handle]) else { return }
        let text = [
            "just shipped \(app) 1.0, a new on-device signer. no ads, no revokes, no excuses.",
            "\(app) is live. one tap installs, rootless, no cert drama. go break it.",
            "new release: \(app). i rewrote the whole install pipeline so you don't have to suffer.",
            "\(app) v1 is out. sideload anything in under 10 seconds. try it."
        ].randomElement() ?? "shipped \(app)"
        var c: [Comment] = []
        c.append(cm(rival, fill(["\(app)? so it's zsign with a logo.", "ads in v1.0, wow, speedrunning the enshittification.", "first revoke in 3... 2... @\(dev.handle) you know it's coming.", "i've seen better code in a bootloop."].randomElement() ?? "mid", app)))
        if let g = pick(cast, .gossip, not: [dev.handle, rival.handle]) { c.append(cm(g, ["allegedly this is a fork of @\(rival.handle)'s project. the commit history says otherwise.", "the discord has been quiet since @\(dev.handle) announced this. suspicious.", "funny how \(app) appeared right after @\(rival.handle)'s repo went private."].randomElement() ?? "👀")) }
        if let m = pick(cast, .mogul, not: [dev.handle, rival.handle]) { c.append(cm(m, ["cute. my signing service does this at scale, with support.", "show me the retention numbers and then we can talk.", "no monetization plan? that's a hobby, not a product."].randomElement() ?? "ok")) }
        if let w = pick(cast, .wholesome, not: [dev.handle, rival.handle]) { c.append(cm(w, ["congrats!! tested it on my old iphone and it works 🥹", "love seeing free tools in this scene. please ignore the haters.", "installed without a single error. thank you for this."].randomElement() ?? "congrats")) }
        if let x = pick(cast, .chaos, not: [dev.handle, rival.handle]) { c.append(cm(x, ["installed. phone is warm. no regrets.", "it bricked my sandbox but spiritually it works.", "i tapped it and the wallpaper changed. is that the feature?"].randomElement() ?? "💀")) }
        c.append(cm(dev, "@\(rival.handle) the source is public. open an issue or sit down."))
        let step = escalateFeud(&st, a: dev, b: rival, cause: "\(app)")
        let p = publishScene(&st, dev, text, tag: "Release", comments: c.shuffled())
        logEvent(&st, &items, quiet: quiet, emoji: "🛠️", title: "\(dev.name) released \(app)",
                 detail: "\(rival.name) tore into it. \(step.sidesA) back \(dev.name), \(step.sidesB) back \(rival.name).", post: p.id,
                 handles: [dev.handle, rival.handle], weight: 45 + step.heat * 4,
                 history: "\(dev.name) released \(app) and \(rival.name) went after it right away.")
    }

    // 2) a beta leaks, the creator blames someone
    private func sceneLeak(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool, _ app: String) {
        guard let creator = pick(cast, [.hype, .mogul, .wholesome].randomElement() ?? .hype) ?? anyNPC(cast),
              let suspect = pick(cast, [.gossip, .hater, .chaos].randomElement() ?? .gossip, not: [creator.handle]) ?? anyNPC(cast, not: [creator.handle]) else { return }
        let text = [
            "someone leaked the \(app) beta. you know who you are. it was private for a reason.",
            "the \(app) test build is all over the telegram groups. whoever leaked it, we're done.",
            "\(app) beta leaked before it was even stable. months of work. thanks a lot."
        ].randomElement() ?? "someone leaked \(app)"
        var c: [Comment] = []
        if let g = pick(cast, .gossip, not: [creator.handle, suspect.handle]) ?? anyNPC(cast, not: [creator.handle, suspect.handle]) {
            c.append(cm(g, "allegedly @\(suspect.handle) had the build first. i have screenshots of the group chat."))
        }
        c.append(cm(suspect, ["it wasn't me. check who else had the link.", "@\(creator.handle) you're accusing the wrong person and you know it.", "prove it. i'll wait."].randomElement() ?? "not me"))
        if let h = pick(cast, .hater, not: [creator.handle, suspect.handle]) { c.append(cm(h, "leaks are the only reason anyone tests your stuff.")) }
        if let w = pick(cast, .wholesome, not: [creator.handle, suspect.handle]) { c.append(cm(w, "please don't harass anyone until you actually know who it was.")) }
        if let m = pick(cast, .mogul, not: [creator.handle, suspect.handle]) { c.append(cm(m, "this is why NDAs exist. lawyer up or move on.")) }
        if let x = pick(cast, .chaos, not: [creator.handle, suspect.handle]) { c.append(cm(x, "i downloaded it three times. for science.")) }
        let step = escalateFeud(&st, a: creator, b: suspect, cause: "the \(app) beta leak")
        let p = publishScene(&st, creator, text, tag: "Drama", comments: c.shuffled())
        logEvent(&st, &items, quiet: quiet, emoji: "🕵️", title: "\(app) beta leaked",
                 detail: "\(creator.name) suspects \(suspect.name). \(step.sidesA) side with \(creator.name), \(step.sidesB) with \(suspect.name).", post: p.id,
                 handles: [creator.handle, suspect.handle], weight: 60 + step.heat * 4,
                 history: "The \(app) beta leaked and \(creator.name) pointed at \(suspect.name).")
    }

    // 3) a tweak blows up, a mogul offers a sponsorship
    private func sceneViral(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool, _ app: String) {
        guard let dev = pick(cast, [.hype, .wholesome, .chaos].randomElement() ?? .hype) ?? anyNPC(cast),
              let mogul = pick(cast, .mogul, not: [dev.handle]) ?? anyNPC(cast, not: [dev.handle]) else { return }
        let text = [
            "my tweak \(app) just passed 100K installs??? i made this in a weekend.",
            "\(app) is trending and i don't know how to feel. thank you all.",
            "woke up to \(app) everywhere. the repo got 5K stars overnight."
        ].randomElement() ?? "\(app) went viral"
        var c: [Comment] = []
        c.append(cm(mogul, "DM me. sponsorship, serious money. we should talk before someone else does."))
        if let h = pick(cast, .hype, not: [dev.handle, mogul.handle]) { c.append(cm(h, "BANGER. i've had it installed since day one.")) }
        if let h = pick(cast, .hater, not: [dev.handle, mogul.handle]) { c.append(cm(h, "it's mid but ok. congrats on the hype cycle.")) }
        if let g = pick(cast, .gossip, not: [dev.handle, mogul.handle]) { c.append(cm(g, "@\(mogul.handle) slid into the DMs within 5 minutes. the scene is eating itself.")) }
        if let w = pick(cast, .wholesome, not: [dev.handle, mogul.handle]) { c.append(cm(w, "so proud of you. don't let the sponsors change the project.")) }
        c.append(cm(dev, "@\(mogul.handle) i'll think about it. no paywalls, that's my line."))
        if let i = st.npcs.firstIndex(where: { $0.handle == dev.handle }) {
            st.npcs[i].followers = Int(Double(st.npcs[i].followers) * Double.random(in: 1.05...1.12))
        }
        let p = publishScene(&st, dev, text, tag: "Viral", comments: c.shuffled(), viral: true)
        logEvent(&st, &items, quiet: quiet, emoji: "📈", title: "\(app) went viral",
                 detail: "\(mogul.name) offered \(dev.name) a sponsorship.", post: p.id,
                 handles: [dev.handle, mogul.handle], weight: 50,
                 history: "\(dev.name)'s \(app) went viral and \(mogul.name) offered a sponsorship.")
    }

    // 4) a certificate gets revoked, everyone complains and blames
    private func sceneRevoke(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool, _ app: String) {
        guard let owner = pick(cast, .mogul) ?? anyNPC(cast),
              let critic = pick(cast, .hater, not: [owner.handle]) ?? anyNPC(cast, not: [owner.handle]) else { return }
        let text = [
            "heads up: our enterprise cert just got revoked. new one is being issued. thanks for your patience.",
            "cert revoked again. apple did this, not us. signing is down for a few hours.",
            "all \(app) installs are failing right now because of a revoke. working on it."
        ].randomElement() ?? "cert revoked"
        var c: [Comment] = []
        c.append(cm(critic, "told you enterprise certs are a rental. @\(owner.handle) sold everyone a lease."))
        if let g = pick(cast, .gossip, not: [owner.handle, critic.handle]) { c.append(cm(g, "who reported it? asking for a friend. also asking for a refund.")) }
        if let w = pick(cast, .wholesome, not: [owner.handle, critic.handle]) { c.append(cm(w, "tip: reinstall, then trust it again in Settings > General > VPN & Device Management. you got this.")) }
        if let x = pick(cast, .chaos, not: [owner.handle, critic.handle]) { c.append(cm(x, "my whole homescreen turned into grey icons. it's a vibe actually.")) }
        if let h = pick(cast, .hype, not: [owner.handle, critic.handle]) { c.append(cm(h, "come back stronger @\(owner.handle). we ride at dawn.")) }
        c.append(cm(owner, "@\(critic.handle) it's a revoke, not a crime. a new cert is on the way."))
        let step = escalateFeud(&st, a: owner, b: critic, cause: "the revoked cert")
        let p = publishScene(&st, owner, text, tag: "Revoked", comments: c.shuffled())
        // a wave of complaints from other users
        let wave = cast.filter { $0.handle != owner.handle && $0.handle != critic.handle }.shuffled().prefix(2)
        for n in wave {
            let t: String
            switch n.trait {
            case .wholesome: t = "if your app got revoked: don't panic. re-sign it or wait for the new cert. be nice to the devs today."
            case .hater: t = "revoked again. shocker. maybe stop trusting free certs from strangers."
            case .gossip: t = "so many revoked apps today. the timing is not a coincidence."
            case .mogul: t = "this is why you pay for a real developer account. just saying."
            case .chaos: t = "my apps all died at once. funeral at noon. wear black."
            default: t = "revoked and still posting. the grind doesn't stop."
            }
            var q = makePost(n, t, st)
            q.tag = "Revoked"
            stampPost(&q, st)
            st.posts.insert(q, at: 0)
        }
        logEvent(&st, &items, quiet: quiet, emoji: "🚫", title: "A certificate got revoked",
                 detail: "\(owner.name)'s signing is down. \(critic.name) is blaming them. \(step.sidesA) back \(owner.name), \(step.sidesB) back \(critic.name).", post: p.id,
                 handles: [owner.handle, critic.handle], weight: 55 + step.heat * 4,
                 history: "\(owner.name)'s certificate was revoked and \(critic.name) blamed them.")
    }

    // 5) a broken update, "works on my device"
    private func sceneBroken(_ st: inout GameState, _ items: inout [DigestItem], _ cast: [NPC], _ quiet: Bool, _ app: String) {
        guard let dev = pick(cast, [.hype, .chaos, .mogul].randomElement() ?? .hype) ?? anyNPC(cast) else { return }
        let text = [
            "\(app) 2.1 is out! faster, smaller, fixes for the latest iOS.",
            "pushed \(app) 2.1 a minute ago. rewrote the injector. let me know what breaks.",
            "\(app) update is live. changelog is long, go read it. or don't."
        ].randomElement() ?? "\(app) updated"
        var c: [Comment] = []
        if let x = pick(cast, .chaos, not: [dev.handle]) { c.append(cm(x, ["works on my device 🤷", "works on my device. skill issue.", "it works if you don't open it. try that."].randomElement() ?? "works on my device")) }
        if let x = cast.filter({ $0.trait == .chaos && $0.handle != dev.handle }).dropFirst().randomElement() { c.append(cm(x, "bootloop speedrun any%. i got 11 seconds.")) }
        if let h = pick(cast, .hater, not: [dev.handle]) { c.append(cm(h, "tested on production again? bold strategy.")) }
        if let w = pick(cast, .wholesome, not: [dev.handle]) { c.append(cm(w, "if it crashes for you, roll back to 2.0 from the releases page. it worked for me.")) }
        if let g = pick(cast, .gossip, not: [dev.handle]) { c.append(cm(g, "the issues page has 41 new tabs open. just saying.")) }
        c.append(cm(dev, "fix is coming in 10 minutes. sorry. testing is for people with time."))
        let critic = pick(cast, .hater, not: [dev.handle])
        var step: FeudStep? = nil
        if let k = critic, Double.random(in: 0...1) < 0.5 { step = escalateFeud(&st, a: dev, b: k, cause: "the broken \(app) update") }
        let p = publishScene(&st, dev, text, tag: "Update", comments: c.shuffled())
        logEvent(&st, &items, quiet: quiet, emoji: "💥", title: "\(app) update broke things",
                 detail: "\(dev.name)'s update is crashing devices. The chaos crowd says it works on theirs.", post: p.id,
                 handles: [dev.handle] + (step != nil ? [critic?.handle ?? ""] : []), weight: 40,
                 history: "\(dev.name) pushed a broken \(app) update. 'works on my device' flooded the replies.")
    }
}
