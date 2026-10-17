import SwiftUI

struct Fandom: Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let setting: String
}

enum Fandoms {
    static let all: [Fandom] = [
        Fandom(id: "fame", emoji: "✨", name: "Fame & Influencers", setting: "A glossy world of red carpets, brand deals and paparazzi where one viral clip can make or break a career."),
        Fandom(id: "wizard", emoji: "🧙", name: "Wizard School", setting: "A hidden castle school for young wizards where houses feud, secrets travel by owl and every spell goes viral."),
        Fandom(id: "idol", emoji: "🎤", name: "Idol Groups", setting: "A hyper-competitive idol agency where trainees, fan clubs and comeback schedules decide who becomes a star."),
        Fandom(id: "highschool", emoji: "🏫", name: "High School", setting: "A loud, clique-ruled high school where the group chat is the real principal and every rumor has a screenshot."),
        Fandom(id: "heroes", emoji: "🦸", name: "Superheroes", setting: "A city of masked heroes and rival villains where public image matters as much as powers."),
        Fandom(id: "campus", emoji: "🏘️", name: "Off Campus", setting: "Off-campus houses, bad landlords, parties and rivalries at a university where everyone is posting everything."),
        Fandom(id: "anime", emoji: "⚔️", name: "Anime Battles", setting: "A tournament world of rival fighters, sensei, training arcs and dramatic fan theories."),
        Fandom(id: "streamer", emoji: "📺", name: "Streamers & YouTubers", setting: "The creator economy: subs, sponsors, collabs, drama channels and a 24/7 chat that never forgives."),
        Fandom(id: "crime", emoji: "🕶️", name: "Crime Family", setting: "Rival families, quiet favors and loyalty tests in a city where reputation is the only currency that matters."),
        Fandom(id: "regency", emoji: "👑", name: "Regency Society", setting: "A glittering high-society season of balls, matchmaking and anonymous gossip pamphlets that ruin reputations."),
        Fandom(id: "mystery", emoji: "🚲", name: "80s Small-Town Mystery", setting: "A sleepy 1980s town with a secret lab, strange lights, arcade rivalries and kids who know too much."),
        Fandom(id: "politics", emoji: "🗳️", name: "Campaign Trail", setting: "A heated election where candidates, staffers and pundits fight for every headline and every vote."),
        Fandom(id: "vampire", emoji: "🧛", name: "Vampire Town", setting: "A foggy town split between humans, vampires and the families who pretend not to notice."),
        Fandom(id: "space", emoji: "🚀", name: "Space Crew", setting: "A long-haul starship crew with cramped quarters, shifting alliances and one very unreliable AI."),
        Fandom(id: "hackers", emoji: "💻", name: "Sideloaders & Hackers", setting: "An underground scene of sideloaders, dylib makers and signer builders competing for reputation, followers and the best tools."),
        Fandom(id: "ninja", emoji: "🍥", name: "Ninja Village", setting: "A hidden village of rival ninja clans, mentor teams and exams where every mission is public.")
    ]
}

private enum Step { case fandom, custom, building, player, first, ripple }

struct CreateFlow: View {
    @EnvironmentObject var game: Game
    let initialWorld: WorldDef?
    var close: () -> Void

    @State private var step: Step = .fandom
    @State private var query = ""
    @State private var trending = false
    @State private var fandomName = ""
    @State private var goal = ""
    @State private var setting = ""
    @State private var world: WorldDef? = nil
    @State private var selected: String? = nil      // npc handle, or "me"
    @State private var persona: Persona? = nil
    @State private var playAs: String? = nil
    @State private var first: String? = nil
    @State private var charSheet = false

    init(initialWorld: WorldDef?, close: @escaping () -> Void) {
        self.initialWorld = initialWorld
        self.close = close
        _step = State(initialValue: initialWorld == nil ? .fandom : .player)
        _world = State(initialValue: initialWorld)
    }

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .ripple && step != .building { topBar }
                switch step {
                case .fandom: fandomStep
                case .custom: customStep
                case .building: buildingStep
                case .player: playerStep
                case .first: firstStep
                case .ripple:
                    if let w = world, let p = persona {
                        RippleView(world: w, persona: p, asNPC: playAs, first: first)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $charSheet) {
            CreateCharacterSheet { p in
                persona = p
                playAs = nil
                step = .first
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { back() } label: {
                Image(systemName: "arrow.left").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(initialWorld == nil ? "Create from scratch" : (world?.title ?? "Play")).font(.jk(18, .semibold))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12).padding(.top, 8)
    }

    private func back() {
        switch step {
        case .fandom: close()
        case .custom: step = .fandom
        case .building: break
        case .player: if initialWorld == nil { step = .fandom } else { close() }
        case .first: step = .player
        case .ripple: break
        }
    }

    // MARK: Fandom

    private var fandoms: [Fandom] {
        var list = Fandoms.all
        if trending { list = Array(list.reversed()) }
        let q = query.trimmed
        if !q.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(q) } }
        return list
    }

    private var fandomStep: some View {
        VStack(spacing: 14) {
            Text("What fandom is your world in?").font(.jk(24, .bold)).multilineTextAlignment(.center).padding(.top, 10)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(T.sub)
                TextField("Search for fandoms", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            HStack(spacing: 10) {
                pill("Popular", !trending) { trending = false }
                pill("Trending", trending) { trending = true }
                Spacer()
            }.padding(.horizontal, 16)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(fandoms) { f in
                        Button {
                            fandomName = f.name
                            goal = ""
                            setting = f.setting
                            startBuilding()
                        } label: {
                            HStack(spacing: 14) {
                                Text(f.emoji).font(.jk(26)).frame(width: 52, height: 52)
                                    .background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                                Text(f.name).font(.jk(18, .medium)).foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 82)
                    }
                    VStack(spacing: 10) {
                        Text("Can't find the fandom you want?").font(.jk(15)).foregroundColor(T.sub)
                        Button {
                            fandomName = query.trimmed
                            step = .custom
                        } label: {
                            Text(query.trimmed.isEmpty ? "Create a new one here" : "Create \"\(query.trimmed)\"")
                                .font(.jk(17, .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 28).padding(.vertical, 14)
                                .background(T.blue).clipShape(Capsule())
                        }
                    }.padding(.vertical, 22)
                }
            }
        }
    }

    private func pill(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.jk(16, .medium)).foregroundColor(on ? .white : T.sub)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(on ? T.blue : T.card).clipShape(Capsule())
        }
    }

    // MARK: Custom fandom

    private var customStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Create a new fandom").font(.jk(22, .semibold)).padding(.top, 10)
                Text("What world or universe does your story take place in?").font(.jk(15)).foregroundColor(T.sub).multilineTextAlignment(.center)
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("e.g. Sideloading", text: $fandomName)
                        .padding(16).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
                        .onChange(of: fandomName) { v in if v.count > 50 { fandomName = String(v.prefix(50)) } }
                    Text("\(fandomName.count)/50").font(.jk(12)).foregroundColor(T.sub)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your goal (optional)").font(.jk(13, .semibold)).foregroundColor(T.orange)
                    TextField("Become the biggest name in this world", text: $goal, axis: .vertical).lineLimit(1...3)
                        .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                        .onChange(of: goal) { v in if v.count > 150 { goal = String(v.prefix(150)) } }
                    Text("Describe the setting (optional)").font(.jk(13, .semibold)).foregroundColor(T.blue).padding(.top, 6)
                    TextField("Tell the AI about the people, places and rivalries", text: $setting, axis: .vertical).lineLimit(3...8)
                        .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                        .onChange(of: setting) { v in if v.count > 2000 { setting = String(v.prefix(2000)) } }
                    DisclosureGroup("Need inspiration?") {
                        VStack(spacing: 8) {
                            ForEach(Inspiration.prompts, id: \.self) { p in
                                Button { setting = String(p.prefix(2000)) } label: {
                                    Text(p).font(.jk(13)).foregroundColor(.white.opacity(0.9)).multilineTextAlignment(.leading)
                                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }.padding(.top, 8)
                    }.foregroundColor(T.blue).padding(.top, 6)
                }
                BigButton(title: "Next: Build the world", enabled: !fandomName.trimmed.isEmpty) { startBuilding() }
                    .clipShape(Capsule())
                Text("You can always edit your world and characters once it's created!")
                    .font(.jk(14)).foregroundColor(T.sub).multilineTextAlignment(.center).padding(.top, 8)
            }
            .padding(16)
        }
    }

    // MARK: Building

    private var buildingStep: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.6)
            Text("Building \(fandomName)…").font(.jk(20, .bold))
            Text("Writing the cast, rivalries and goals").font(.jk(14)).foregroundColor(T.sub)
            Spacer()
        }
    }

    private func startBuilding() {
        let name = fandomName.trimmed
        guard !name.isEmpty else { return }
        let g = goal.trimmed.isEmpty ? "Become the biggest name in \(name)" : goal.trimmed
        let s = setting.trimmed.isEmpty ? "A social media world set in \(name)." : setting.trimmed
        step = .building
        Task {
            var (w, _) = await game.buildWorld(goal: g, setting: s)
            if w.title.trimmed.isEmpty { w.title = name }
            game.savePreset(w)
            world = w
            step = .player
        }
    }

    // MARK: Player

    private func castRow(_ n: NPC, isOn: Bool) -> some View {
        HStack(spacing: 14) {
            Avatar(emoji: n.emoji, key: n.handle, size: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(n.name).font(.jk(18, .medium)).foregroundColor(.white)
                Text(n.bio).font(.jk(14)).foregroundColor(T.sub).lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 28)).foregroundColor(isOn ? T.blue : Color.white.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var playerStep: some View {
        let cast = world?.cast ?? []
        return VStack(spacing: 0) {
            Text("Who do you want to play as?").font(.jk(24, .bold)).padding(.vertical, 12)
            ScrollView {
                VStack(spacing: 0) {
                    Button { selected = "me" } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(T.blue.opacity(0.35))
                                Image(systemName: "person.fill").font(.system(size: 26)).foregroundColor(T.blue)
                            }.frame(width: 58, height: 58)
                            Text("Play as yourself").font(.jk(20, .medium)).foregroundColor(T.blue)
                            Spacer()
                            if selected == "me" { Image(systemName: "largecircle.fill.circle").font(.system(size: 28)).foregroundColor(T.blue) }
                        }.padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    Divider().background(Color.white.opacity(0.08))
                    ForEach(cast) { n in
                        Button { selected = n.handle } label: { castRow(n, isOn: selected == n.handle) }
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
            BigButton(title: continueTitle, enabled: selected != nil) {
                guard let sel = selected else { return }
                if sel == "me" {
                    charSheet = true
                } else if let n = cast.first(where: { $0.handle == sel }) {
                    persona = Persona(name: n.name, handle: n.handle, bio: n.bio, emoji: n.emoji, vibe: n.trait.vibe)
                    playAs = n.handle
                    step = .first
                }
            }
            .clipShape(Capsule()).padding(16)
        }
    }

    private var continueTitle: String {
        guard let sel = selected else { return "Select a character" }
        if sel == "me" { return "Continue as yourself" }
        let n = world?.cast.first { $0.handle == sel }?.name ?? "character"
        return "Continue with \(n)"
    }

    // MARK: First follower

    private var firstStep: some View {
        let cast = (world?.cast ?? []).filter { $0.handle != playAs }
        let nm = persona?.name ?? "you"
        return VStack(spacing: 0) {
            Text("Who is \(nm)'s first follower?").font(.jk(24, .bold)).multilineTextAlignment(.center)
                .padding(.vertical, 12).padding(.horizontal, 16)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(cast) { n in
                        Button { first = n.handle } label: { castRow(n, isOn: first == n.handle) }
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
            BigButton(title: firstTitle(cast), enabled: first != nil) { step = .ripple }
                .clipShape(Capsule()).padding(16)
        }
    }

    private func firstTitle(_ cast: [NPC]) -> String {
        guard let f = first, let n = cast.first(where: { $0.handle == f }) else { return "Select a character" }
        return "Continue with \(n.name)"
    }
}

// MARK: - Ripple (loading) screen

struct RippleView: View {
    @EnvironmentObject var game: Game
    let world: WorldDef
    let persona: Persona
    let asNPC: String?
    let first: String?
    @State private var intro: Intro? = nil
    @State private var introDone = false
    @State private var started = Date()
    @State private var finished = false
    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var firstNPC: NPC? { world.cast.first { $0.handle == first } }

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                var path = Path()
                var x: CGFloat = 0
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += 46 }
                var y: CGFloat = 0
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 46 }
                ctx.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").font(.system(size: 26))
                    Text("Planting the first ripple").font(.jk(26, .regular))
                }.foregroundColor(.white)
                Spacer()
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSince(started)
                    let ang = t * 0.9
                    let r: CGFloat = 125
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.5).frame(width: r * 2, height: r * 2)
                        Avatar(emoji: persona.emoji, key: persona.handle, size: 120, ring: true)
                        if let f = firstNPC {
                            Avatar(emoji: f.emoji, key: f.handle, size: 68, ring: true)
                                .offset(x: CGFloat(cos(ang + 3.2)) * r, y: CGFloat(sin(ang + 3.2)) * r)
                        }
                    }
                }
                .frame(height: 300)
                Spacer()
                GeometryReader { g in
                    let elapsed = Date().timeIntervalSince(started)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(T.blue).frame(width: g.size.width * progress(elapsed))
                    }
                }
                .frame(height: 12).padding(.horizontal, 40)
                .id(tickCount)
                Spacer().frame(height: 40)
                HStack(spacing: 10) {
                    Text("💡").font(.jk(22))
                    Text("Finish side quests to level up faster").font(.jk(16))
                }
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(T.card2).clipShape(Capsule())
                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            started = Date()
            Task {
                intro = await game.buildIntro(world: world, persona: persona)
                introDone = true
            }
        }
        .onReceive(tick) { _ in
            tickCount += 1
            let el = Date().timeIntervalSince(started)
            if !finished, (introDone && el > 3.2) || el > 14 {
                finished = true
                game.start(world: world, persona: persona, asNPC: asNPC, first: first, intro: intro)
            }
        }
    }

    @State private var tickCount = 0

    private func progress(_ el: Double) -> CGFloat {
        if finished { return 1 }
        let cap = introDone ? 1.0 : 0.9
        return CGFloat(min(cap, el / (introDone ? 3.2 : 14.0) * (introDone ? 1 : 0.9)))
    }
}
