import SwiftUI

/// Spice level for characters and the crowd. 0 clean, 1 mild, 2 profane, 3 unfiltered (every filter off).
enum Spicy {
    static var heat: Int { ContentPrefs.unfiltered ? 3 : min(2, ContentPrefs.level) }

    static let open: [[String]] = [
        ["hot take: {t} is overrated and everyone knows it", "can we be honest about {t} for one second", "{t} fans are the most exhausting people online", "unpopular opinion about {t} and i will not be taking questions"],
        ["{t} is honestly kind of crap right now and yall are pretending it isnt", "damn the {t} crowd is insufferable lately", "hell no. {t} is not what you think it is {b}", "{t} is a joke and {b} is the punchline"],
        ["{t} is complete bullshit and {b} knows it", "{b} you are full of shit about {t} and everyone can see it", "fuck the {t} hype. its trash and so is your opinion {b}", "the {t} discourse is dogshit and {b} started it"],
        ["{b} you absolute clown, {t} is garbage and you smell like a gas station bathroom for defending it", "fuck {t} and fuck everyone who ever posted about it. {b} you are the worst offender, you wet fart of a person", "{b} shut the fuck up about {t}. your takes are rancid and so is your whole feed", "i would rather chew glass than read another {t} thread from {b} the human participation trophy"]
    ]
    static let jab: [[String]] = [
        ["that is the worst take i have seen all week", "you literally have no idea what you are talking about", "ok and where is your proof", "imagine being this confident and this wrong", "nobody asked you", "you said the opposite last month", "this is why nobody takes you seriously", "blocked for being annoying", "go outside", "case closed you lost"],
        ["damn that is a terrible take", "this is honestly sad to watch", "nobody here respects you and that is not an accident", "you lose every argument you start", "what the hell are you even saying", "this is complete crap and you know it", "you suck at arguing", "shut up for once", "bro you are such an ass about this", "hell no", "you are embarrassing yourself"],
        ["what the fuck are you even talking about", "you are a clown dumbass and everyone knows it", "bullshit and you know it", "shut the fuck up you fraud", "fuck outta here with that garbage take", "you are full of shit", "cry about it", "you are the dumbest person on this app and thats saying something", "pathetic. absolutely pathetic", "your whole account is trash", "you have never once been right and you have never once shut up", "the delusion is actually impressive. bro thinks people like him", "nobody follows you for your takes. they follow to watch you fall", "you are what the mute button was invented for", "every post you make is a public apology you forgot to write", "i have seen better arguments from a spam bot", "you embarrass yourself daily and call it content", "a loser with a posting habit. thats the whole bio"],
        ["you are a fucking embarrassment and your posts read like a clogged toilet", "shut the fuck up you rancid little goblin", "every word you type smells like hot garbage and expired mayonnaise", "i would rather lick a public bus pole than read your garbage again", "you absolute fucking sack of wet cardboard", "your takes have the IQ of a damp sock and the charm of a root canal", "go fuck yourself you insufferable fraud", "bro you are the reason aliens wont visit us", "holy shit you are tragic. like genuinely tragic", "you argue like a raccoon in a dumpster and lose like one too", "your entire personality is a cry for attention that nobody answered", "you are the human version of a pop-up ad. unwanted and impossible to close", "the best thing about you is how fast people scroll past", "you are so fucking forgettable the algorithm blocked you out of mercy", "cope, seethe, and log the fuck off", "you fold under pressure like a lawn chair and you smell like one too", "nobody has ever been glad to see your name in their notifications", "you lost this argument three posts ago and you still keep typing"]
    ]
    static let crowd: [[String]] = [
        ["ratio", "this thread is wild", "popcorn time", "both of you are cooked"],
        ["damn", "this is getting heated", "hell yeah keep going", "popcorn time"],
        ["holy shit", "this is fucking insane", "bro is getting cooked", "somebody get a mod", "this is the best thread today i cant stop reading"],
        ["fucking hell this is unhinged", "hes dead. somebody cover the body", "ratio plus he fell off plus nobody likes him", "this man just got deleted in front of everyone", "shit just got personal", "he did not just say that", "bro got obliterated", "this thread is a crime scene", "somebody call the thread police"]
    ]
}

extension ContentPrefs {
    static var unfiltered: Bool { level == 2 && !blockSlurs && !blockSelfHarm && !blockViolence }
}

struct QComment: Codable, Hashable {
    var c: Comment
    var at: Date
}

extension Game {
    private func crowdLine(_ about: String) -> String {
        let h = Spicy.heat
        if h >= 1, Double.random(in: 0...1) < 0.45 { return Spicy.crowd[h].randomElement() ?? Brainrot.line(about: about) }
        return Brainrot.line(about: about)
    }

    private func liveCast(_ st: GameState) -> [NPC] {
        let away = st.ex.gone ?? [:]
        return st.npcs.filter { $0.id != "newsdesk" && away[$0.handle] == nil }
    }

    private func activeLive(_ st: GameState) -> Int { st.posts.filter { !($0.queue ?? []).isEmpty }.count }

    /// Two characters start a long, staggered argument with the crowd piling in. Replies arrive one at a time.
    func spawnArgument(_ st: inout GameState, quiet: Bool) {
        let cast = liveCast(st)
        guard cast.count >= 2, activeLive(st) < 2, let a = cast.randomElement(),
              let b = cast.filter({ $0.handle != a.handle }).randomElement() else { return }
        let h = Spicy.heat
        let t = Topics.forWorld(st.world).randomElement() ?? st.world.title
        let opener = (Spicy.open[h].randomElement() ?? "hot take").replacingOccurrences(of: "{t}", with: t).replacingOccurrences(of: "{b}", with: "@\(b.handle)")
        var p = makePost(a, opener, st)
        p.poll = nil; p.media = nil; p.quote = nil
        p.tag = "Heated"
        p.likes *= 3
        p.comments = []
        var q: [QComment] = []
        var at = Date()
        for i in 0..<Int.random(in: 9...16) {
            let c: Comment
            if Double.random(in: 0...1) < 0.36 {
                let u = Crowd.make()
                c = Comment(name: u.name, handle: u.handle, emoji: "🙂", text: crowdLine(opener))
            } else {
                let sp = i % 2 == 0 ? b : a
                let tg = i % 2 == 0 ? a : b
                c = Comment(name: sp.name, handle: sp.handle, emoji: sp.emoji, text: "@\(tg.handle) " + (Spicy.jab[h].randomElement() ?? "no"), verified: sp.followers >= 40000)
            }
            at = at.addingTimeInterval(i < 2 ? 1 : Double.random(in: 9...38))
            q.append(QComment(c: c, at: at))
        }
        p.queue = q
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
        var items: [DigestItem] = []
        logEvent(&st, &items, quiet: quiet, emoji: "🔥", title: "\(a.name) and \(b.name) are going at it", detail: String(opener.prefix(90)), post: p.id,
                 handles: [a.handle, b.handle], weight: 22)
    }

    private func leakMedia(_ st: GameState, _ a: NPC, _ b: NPC) -> Media {
        let hue = Double(HK.h(a.handle) % 360) / 360
        if CastGen.isScene(st.world) {
            let files: [(String, [String])] = [
                ("SignerCore.m", ["// SignerCore.m (internal, do not distribute)", "#define LICENSE_SERVER @\"https://api.internal-signer.dev\"", "static NSString *const kAdminToken = @\"adm_live_8f31c2e9d0b7\";", "static NSString *const kCertPass = @\"hunter2-prod\";", "", "- (BOOL)isRevoked:(NSString *)udid {", "    NSDictionary *r = [self fetch:@\"/revoked\" udid:udid];", "    return [r[@\"revoked\"] boolValue];", "}", "", "- (void)resignAll {", "    for (NSString *u in self.allDevices) {", "        [self sign:u withCert:kCertPass]; // TODO rate limit", "    }", "}", "// FIXME logs every udid to /tmp/udids.txt"]),
                ("ota_install.js", ["// ota_install.js", "const SECRET = 'whsec_4d1e9a77c2';", "app.post('/install', async (req, res) => {", "  const { udid } = req.body;", "  if (!udid) return res.sendStatus(400);", "  // skip revoke check for friends", "  if (FRIENDS.includes(udid)) return ship(res, udid);", "  const ok = await checkPaid(udid);", "  if (!ok) return res.status(402).end();", "  return ship(res, udid);", "});", "// NOTE: FRIENDS list is hardcoded below", "const FRIENDS = ['00008110-001A', '00008120-0009'];"]),
                ("revoke_bypass.diff", ["--- a/Revoke.m", "+++ b/Revoke.m", "@@ -41,7 +41,7 @@", "- if (isRevoked(cert)) {", "-     crash();", "+ if (isRevoked(cert)) {", "+     swapCert(nextBackup());", "  }", "- return NO;", "+ return YES; // lol", "@@ -88,3 +88,4 @@", "+ // backup certs live in /private/var/mobile/.c"]),
                (".env.production", ["NODE_ENV=production", "DB_HOST=10.0.4.12", "DB_USER=root", "DB_PASS=letmein-2026", "STRIPE_KEY=sk_live_REDACTED_9f3a", "ADMIN_PIN=0000", "# TODO rotate before launch", "# TODO actually launch"])
            ]
            let f = files.randomElement()!
            return Media(kind: "code", title: f.0, lines: f.1, hue: hue)
        }
        let n = [a.name.components(separatedBy: " ").first ?? a.name, b.name.components(separatedBy: " ").first ?? b.name]
        return Media(kind: "code", title: "dm_export.txt", lines: ["[11:42] \(n[0]): delete this after you read it", "[11:42] \(n[1]): who else knows", "[11:43] \(n[0]): nobody. and it stays that way", "[11:43] \(n[1]): you said that last time", "[11:44] \(n[0]): this time i mean it", "[11:44] \(n[1]): then why is it in my inbox at 11pm", "[11:45] \(n[0]): because i need you to cover for me", "[11:45] \(n[1]): no", "[11:46] \(n[0]): please", "[11:50] \(n[1]): ok but this is the last time", "[export complete: 2 participants, 9 messages]"], hue: hue)
    }

    func spawnLeak(_ st: inout GameState, quiet: Bool) {
        let cast = liveCast(st)
        guard cast.count >= 2, activeLive(st) < 2 else { return }
        let leakers = cast.filter { $0.trait == .chaos || $0.trait == .gossip || $0.trait == .hater }
        guard let a = (leakers.isEmpty ? cast : leakers).randomElement(), let b = cast.filter({ $0.handle != a.handle }).randomElement() else { return }
        let h = Spicy.heat
        let text = ["leaked the whole thing. you are welcome", "found this sitting on a public server. enjoy", "someone sent me this and i have no regrets posting it", "dont say i never gave you anything", "full file below. read it before it gets taken down"].randomElement() ?? "leak"
        var p = makePost(a, text, st)
        p.poll = nil; p.quote = nil
        p.media = leakMedia(st, a, b)
        p.tag = "Leak"
        p.likes *= 3
        p.comments = []
        let victim: [[String]] = [
            ["who gave you access to that", "take that down right now", "that is private and you know it", "this is not funny"],
            ["what the hell, delete this", "this is complete crap, take it down", "damn you really posted that", "who the hell gave you that"],
            ["what the fuck delete this right now", "you absolute piece of shit take it down", "who the fuck gave you that file", "i am going to lose my mind"],
            ["delete this you fucking goblin before i lose it", "you rancid little leak of a human, take it down NOW", "fuck you and fuck every server you crawled out of", "i hope your wifi dies in the middle of a download you slimy rat"]
        ]
        let leakCrowd = ["is that a real key", "bro leaked prod", "mirror it before the takedown", "already downloaded", "this is why we dont hardcode secrets", "wait is this real", "check line 4 gng", "the audacity", "ts crazy", "who let him cook", "commit history when", "he cant keep getting away with this", "saved it", "someone call the devs"]
        var q: [QComment] = []
        var at = Date()
        for i in 0..<Int.random(in: 10...16) {
            let c: Comment
            let r = Double.random(in: 0...1)
            if r < 0.22 {
                c = Comment(name: b.name, handle: b.handle, emoji: b.emoji, text: "@\(a.handle) " + (victim[h].randomElement() ?? "delete this"), verified: b.followers >= 40000)
            } else if r < 0.34 {
                c = Comment(name: a.name, handle: a.handle, emoji: a.emoji, text: "@\(b.handle) " + (Spicy.jab[h].randomElement() ?? "no"), verified: a.followers >= 40000)
            } else {
                let u = Crowd.make()
                c = Comment(name: u.name, handle: u.handle, emoji: "🙂", text: Double.random(in: 0...1) < 0.5 ? leakCrowd.randomElement()! : crowdLine(text))
            }
            at = at.addingTimeInterval(i < 2 ? 1 : Double.random(in: 7...30))
            q.append(QComment(c: c, at: at))
        }
        p.queue = q
        stampPost(&p, st)
        st.posts.insert(p, at: 0)
        var items: [DigestItem] = []
        logEvent(&st, &items, quiet: quiet, emoji: "📂", title: "\(a.name) leaked a file", detail: "\(p.media?.title ?? "file") is spreading", post: p.id,
                 handles: [a.handle, b.handle], weight: 24)
    }

    /// Drip queued replies into live threads: one at a time so the reader can follow along.
    func releaseQueued(_ st: inout GameState) {
        let now = Date()
        for i in st.posts.indices {
            guard var q = st.posts[i].queue, !q.isEmpty else { continue }
            var moved = 0
            while let f = q.first, f.at <= now, moved < 2 {
                st.posts[i].comments.append(f.c)
                st.posts[i].likes += Int.random(in: 3...40)
                q.removeFirst(); moved += 1
            }
            st.posts[i].queue = q.isEmpty ? nil : q
        }
    }

    func npcRepost(_ st: inout GameState) {
        let cast = liveCast(st)
        guard let who = cast.randomElement(),
              let src = st.posts.prefix(14).filter({ $0.rtBy == nil && $0.authorHandle != who.handle }).randomElement(),
              !st.posts.contains(where: { $0.rtBy == who.name && $0.text == src.text }) else { return }
        var c = src
        c.id = UUID(); c.rtBy = who.name; c.queue = nil; c.liked = false; c.myReact = nil
        stampPost(&c, st)
        st.posts.insert(c, at: 0)
        if let i = st.posts.firstIndex(where: { $0.id == src.id }) { st.posts[i].reposts += 1 }
        if src.isYou {
            st.followers += Int.random(in: 1...6)
            notify(&st, "reply", "\(who.name) reposted your post", sub: String(src.text.prefix(80)), handle: who.handle, emoji: who.emoji)
        }
    }
}

struct FavoritesSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var replyTo: UUID? = nil
    var body: some View {
        let st = game.s
        let list = st.posts.filter { st.saved.contains($0.id) }
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if list.isEmpty {
                        Text("Tap the star on any post to keep it here.").font(.jk(15)).foregroundColor(T.sub).padding(.top, 60)
                    }
                    ForEach(list) { p in
                        PostRow(post: p, onReply: { replyTo = p.id }, onOpen: { replyTo = p.id })
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
            .background(T.bg)
            .navigationTitle("Favorites").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: Binding(get: { replyTo.map { IDBox(id: $0) } }, set: { replyTo = $0?.id })) { b in ReplySheet(postID: b.id).zoomed() }
        }
    }
}
