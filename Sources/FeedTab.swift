import SwiftUI

struct GameShell: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            switch nav.tab {
            case 0: FeedTab()
            case 1: GoalsTab()
            case 2: MessagesTab()
            case 3: NotifsTab()
            default: ProfileTab()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { AppTabBar() }
        .tint(.white)
        .fullScreenCover(isPresented: Binding(get: { game.playing && game.s.intro?.done == false }, set: { _ in })) {
            IntroFlow().zoomed()
        }
        .toastOverlay()
        .background(Color.clear.fullScreenCover(isPresented: Binding(
            get: { game.playing && game.s.ex.digest != nil && game.s.intro?.done != false },
            set: { if !$0 { game.dismissDigest() } })) {
            AwayDigestSheet().zoomed()
        })
        .onAppear { game.checkStreak(); game.catchUp() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { game.checkStreak(); game.catchUp() }
            else { game.stampSim() }
        }
    }
}

struct AppTabBar: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav

    private func item(_ i: Int, _ icon: String, dot: Bool = false) -> some View {
        Button { nav.tab = i } label: {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(nav.tab == i ? .white : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(alignment: .topTrailing) {
                    if dot { Circle().fill(T.red).frame(width: 13, height: 13).offset(x: -22, y: 4) }
                }
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let st = game.s
        HStack(spacing: 0) {
            item(0, "house.fill")
            item(1, "target")
            item(2, "ellipsis.message.fill", dot: !st.unread.isEmpty)
            item(3, "bell.fill", dot: game.unreadNotifs > 0)
            item(4, "person.fill", dot: st.points > 0)
        }
        .padding(.top, 8)
        .background(T.bg.ignoresSafeArea(edges: .bottom))
    }
}

struct ComposeSeed: Identifiable {
    let id = UUID()
    var text: String = ""
    var quest: UUID? = nil
}

// MARK: - Feed

struct FeedTab: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var compose: ComposeSeed? = nil
    @State private var showEvent = false
    @State private var showExplore = false
    @State private var storyOpen: StoryOpen? = nil
    @State private var npcSheet: NPC? = nil
    @State private var replyTo: UUID? = nil
    @State private var confirmExit = false
    @State private var showStore = false
    @State private var path: [UUID] = []
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let olive = Color(red: 0.47, green: 0.38, blue: 0.08)

    var body: some View {
        let st = game.s
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header(st)
                    energyRow(st)
                    Divider().background(Color.white.opacity(0.12))
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            stories(st)
                            Divider().background(Color.white.opacity(0.12))
                            if !game.aiNote.isEmpty {
                                Text(game.aiNote).font(.jk(11)).foregroundColor(T.orange).padding(.vertical, 6)
                            }
                            ForEach(st.posts.filter { !st.hidden.contains($0.id) }) { p in
                                PostRow(post: p, onReply: { replyTo = p.id }, onOpen: { path.append(p.id) })
                                Divider().background(Color.white.opacity(0.1))
                            }
                            Color.clear.frame(height: 150)
                        }
                    }
                    .refreshable { game.refreshFeed() }
                }
                floating(st)
            }
            .background(T.bg)
            .navigationDestination(for: UUID.self) { PostDetailView(postID: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onReceive(timer) { _ in game.tickEnergy(); game.ambientTick() }
        .onChange(of: game.openPostID) { id in
            if let id = id { path = [id]; game.openPostID = nil }
        }
        .onAppear {
            game.refreshIfStale()
            if let id = game.pendingResult?.postID, path.last != id { path = [id] }
        }
        .onChange(of: game.pendingResult) { r in
            if let id = r?.postID { path = [id] }
        }
        .sheet(item: $compose) { seed in ComposeSheet(seed: seed).zoomed() }
        .fullScreenCover(isPresented: $showStore) { StoreView().zoomed() }
        .sheet(isPresented: $showEvent) { EventSheet().zoomed() }
        .sheet(isPresented: $showExplore) { ExploreSheet().zoomed() }
        .fullScreenCover(item: $storyOpen) { o in StoriesFlow(openStory: o.story).zoomed() }
        .sheet(item: $npcSheet) { n in NPCSheet(npc: n).zoomed() }
        .sheet(item: Binding(get: { replyTo.map { IDBox(id: $0) } }, set: { replyTo = $0?.id })) { b in
            ReplySheet(postID: b.id).zoomed()
        }
        .alert("Leave this world?", isPresented: $confirmExit) {
            Button("Leave") { game.exitToHub() }
            Button("Stay", role: .cancel) {}
        } message: { Text("Your progress is saved.") }
    }

    private func header(_ st: GameState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill").font(.system(size: 30)).foregroundColor(T.gold)
            Text("Day \(st.day)").font(.jk(25, .medium))
            Spacer()
            Button { game.refill() } label: {
                HStack(spacing: 6) {
                    Text(game.canRefill ? "Free refill" : "Refill used").font(.jk(16, .medium))
                    Image(systemName: "bolt.fill").foregroundColor(T.gold)
                }
                .foregroundColor(game.canRefill ? .white : T.sub)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(T.card2).clipShape(Capsule())
                .overlay(alignment: .topTrailing) {
                    if game.canRefill { Circle().fill(T.red).frame(width: 12, height: 12).offset(x: 2, y: -2) }
                }
            }
            .disabled(!game.canRefill)
            Button { showStore = true } label: {
                Image(systemName: "storefront.fill").font(.system(size: 22)).foregroundColor(.white.opacity(0.85))
                    .frame(width: 50, height: 50).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Button { confirmExit = true } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 20, weight: .semibold))
                    .foregroundColor(T.red).frame(width: 50, height: 50).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
    }

    private func energyRow(_ st: GameState) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let (e, secs) = game.liveEnergy(at: ctx.date)
            let s2 = game.s
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 18) {
                    Text("Bonus").foregroundColor(T.sub)
                    if let secs = secs {
                        Text("Refill in \(clockString(secs))").foregroundColor(T.sub).monospacedDigit()
                    } else {
                        Text("Energy full").foregroundColor(T.sub)
                    }
                }
                .font(.jk(17)).padding(.leading, 62)
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill").font(.system(size: 38)).foregroundColor(T.gold)
                    HStack(spacing: 3) {
                        Text("\(s2.bonus)").font(.jk(20, .bold)).foregroundColor(T.gold)
                            .frame(width: 64, height: 40).background(olive).clipShape(RoundedRectangle(cornerRadius: 5))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05))
                                RoundedRectangle(cornerRadius: 5).fill(olive)
                                    .frame(width: g.size.width * CGFloat(e) / CGFloat(Game.maxEnergy))
                                Text("\(e)/\(Game.maxEnergy)").font(.jk(20, .bold)).foregroundColor(T.gold).padding(.leading, 14)
                            }
                        }.frame(height: 40)
                    }
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.28), lineWidth: 2))
                    Button { game.refill() } label: {
                        Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(T.gold)
                            .frame(width: 46, height: 46).background(olive).clipShape(RoundedRectangle(cornerRadius: 12))
                    }.disabled(!game.canRefill)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        GemIcon(size: 30)
                        Text("\(s2.ex.gems)").font(.jk(17, .medium)).foregroundColor(gemPurple)
                    }
                    Button { showStore = true } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(Color(red: 0.55, green: 0.30, blue: 0.90))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)
        }
    }

    private func stories(_ st: GameState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                Button { storyOpen = StoryOpen() } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 72)
                            Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundColor(T.blue)
                                .background(Circle().fill(T.bg))
                        }
                        Text("Your story").font(.jk(14)).foregroundColor(T.sub)
                    }.frame(width: 80)
                }
                Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 84)
                Button { showExplore = true } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(T.blue, lineWidth: 3).frame(width: 78, height: 78)
                            Image(systemName: "globe").font(.system(size: 34)).foregroundColor(T.blue)
                        }
                        Text("Explore").font(.jk(14)).foregroundColor(T.sub)
                    }.frame(width: 84)
                }
                ForEach(st.npcs.filter { $0.id != "newsdesk" }) { n in
                    Button { npcSheet = n } label: {
                        VStack(spacing: 6) {
                            Avatar(emoji: n.emoji, key: n.handle, size: 74, ring: true)
                            Text(n.name.components(separatedBy: " ").first ?? n.name)
                                .font(.jk(14)).foregroundColor(T.sub).lineLimit(1)
                        }.frame(width: 80)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private func floating(_ st: GameState) -> some View {
        VStack(spacing: 12) {
            if st.points > 0 {
                Button { nav.tab = 1 } label: {
                    HStack {
                        Image(systemName: "trophy.fill").foregroundColor(T.gold)
                        Text("Level up!").font(.jk(22, .bold)).foregroundColor(T.gold)
                        Spacer()
                        Text("Upgrade skills").font(.jk(19, .medium)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                    .background(LinearGradient(colors: [Color(red: 0.45, green: 0.36, blue: 0.08), Color(red: 0.30, green: 0.24, blue: 0.06)],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(T.gold.opacity(0.7), lineWidth: 2))
                }
                .padding(.horizontal, 20)
            }
            ZStack {
                Button { showEvent = true } label: {
                    HStack(spacing: 10) {
                        Text("🎭").font(.jk(28)).rotationEffect(.degrees(-12)).offset(x: -4, y: -8)
                        Text("Event").font(.jk(26, .medium)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 44).padding(.vertical, 16)
                    .background(T.blue).clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }
                HStack {
                    Spacer()
                    Button { compose = ComposeSeed() } label: {
                        Image(systemName: "plus").font(.system(size: 28, weight: .medium)).foregroundColor(.white)
                            .frame(width: 62, height: 62).background(T.blue).clipShape(Circle())
                            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                    }
                }.padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 10)
    }
}

struct IDBox: Identifiable { let id: UUID }

// MARK: - Post row

struct PostRow: View {
    @EnvironmentObject var game: Game
    let post: Post
    var onReply: () -> Void
    var onOpen: () -> Void

    var body: some View {
        let st = game.s
        let saved = st.saved.contains(post.id)
        let isNews = st.npcs.first(where: { $0.handle == post.authorHandle })?.id == "newsdesk"
        HStack(alignment: .top, spacing: 12) {
            Avatar(emoji: post.emoji, key: post.authorHandle, size: 52, photo: !isNews)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(post.authorName).font(.jk(18, .bold)).lineLimit(1)
                        if post.verified { VerifiedSeal(size: 16) }
                        Text("@\(post.authorHandle)").font(.jk(16)).foregroundColor(T.sub).lineLimit(1)
                        Spacer(minLength: 0)
                        Menu {
                            Button { game.toggleSave(post.id) } label: {
                                Label(saved ? "Remove bookmark" : "Bookmark", systemImage: "bookmark")
                            }
                            Button(role: .destructive) { game.hide(post.id) } label: { Label("Hide post", systemImage: "eye.slash") }
                        } label: {
                            Image(systemName: "ellipsis").foregroundColor(T.sub).padding(6)
                        }
                    }
                    if !post.tag.isEmpty {
                        Chip(text: post.tag, color: post.tag == "Breaking" ? T.red.opacity(0.85) : T.card2)
                    }
                    Text(post.text).font(.jk(20)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                HStack(spacing: 22) {
                    Button(action: onReply) { Label("\(post.comments.count)", systemImage: "bubble.left") }
                    Label("\(short(post.reposts))", systemImage: "arrow.2.squarepath")
                    Button { game.like(post.id) } label: {
                        Label(short(post.likes), systemImage: post.liked ? "heart.fill" : "heart")
                            .foregroundColor(post.liked ? T.red : T.sub)
                    }
                    Spacer()
                    Image(systemName: saved ? "star.fill" : "star").foregroundColor(saved ? T.gold : T.sub)
                        .onTapGesture { game.toggleSave(post.id) }
                }
                .font(.system(size: 17)).foregroundColor(T.sub).padding(.top, 2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

struct ReplySheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var text = ""

    var body: some View {
        NavigationStack {
            let post = game.s.posts.first { $0.id == postID }
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let p = post {
                            HStack(alignment: .top, spacing: 10) {
                                Avatar(emoji: p.emoji, key: p.authorHandle, size: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.authorName).font(.jk(15, .bold))
                                    Text(p.text).font(.jk(15))
                                }
                            }
                            Divider()
                            if p.comments.isEmpty { Text("No replies yet.").foregroundColor(T.sub).font(.jk(13)) }
                            ForEach(p.comments) { c in
                                HStack(alignment: .top, spacing: 10) {
                                    Avatar(emoji: c.emoji, key: c.handle, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(c.name).font(.jk(13, .bold))
                                            if c.verified { VerifiedSeal(size: 11) }
                                        }
                                        Text(c.text).font(.jk(14))
                                    }
                                }
                            }
                        }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    TextField("Reply…", text: $text).padding(10).background(T.card).clipShape(Capsule())
                    Button {
                        game.reply(to: postID, text: text); text = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                            .foregroundColor(text.trimmed.isEmpty ? T.sub : T.blue)
                    }.disabled(text.trimmed.isEmpty)
                }.padding(12)
            }
            .background(T.bg)
            .navigationTitle("Replies").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - NPC sheet

struct NPCSheet: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss
    let npc: NPC

    var body: some View {
        let live = game.s.npcs.first { $0.handle == npc.handle } ?? npc
        VStack(spacing: 12) {
            Avatar(emoji: live.emoji, key: live.handle, size: 84, ring: true).padding(.top, 24)
            HStack(spacing: 5) {
                Text(live.name).font(.jk(22, .heavy))
                if live.followers >= 40000 { VerifiedSeal(size: 18) }
            }
            Text("@\(live.handle) · \(short(live.followers)) followers").font(.jk(13)).foregroundColor(T.sub)
            Text(live.bio).font(.jk(14)).multilineTextAlignment(.center).padding(.horizontal, 24)
            HStack(spacing: 8) {
                Chip(text: live.trait.rawValue.capitalized)
                if live.followsYou { Chip(text: "Follows you", color: T.blue.opacity(0.8)) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Relationship").font(.jk(12)).foregroundColor(T.sub)
                Bar(value: Double(live.affinity) / 100, color: T.lime)
            }.padding(.horizontal, 28)
            MemoryBlock(handle: live.handle)
            if game.s.ex.gifts > 0 {
                BigButton(title: "Send gift 💝 (\(game.s.ex.gifts) left)", color: T.card2) {
                    game.sendGift(live.handle)
                }.padding(.horizontal, 20)
            }
            BigButton(title: "Message") {
                game.startChat(live.handle)
                nav.chat = live.handle
                nav.tab = 2
                dismiss()
            }.padding(.horizontal, 20)
            Spacer()
        }
        .background(T.bg)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Compose

struct ComposeSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let seed: ComposeSeed
    @State private var kind: PostKind = .meme
    @State private var text = ""
    @State private var outcome: Outcome? = nil
    @EnvironmentObject private var nav: Nav

    private var kinds: [PostKind] {
        PostKind.allCases.filter { $0 != .apology || game.s.aura < 30 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let o = outcome {
                        VStack(spacing: 8) {
                            Text(o.emoji).font(.jk(50))
                            Text(o.title).font(.jk(22, .heavy))
                            Text(o.detail).font(.jk(14)).foregroundColor(T.sub).multilineTextAlignment(.center)
                            BigButton(title: "Done") { dismiss() }.padding(.top, 8)
                        }.frame(maxWidth: .infinity).padding(.top, 30)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(kinds) { k in
                                    Button { kind = k } label: {
                                        Text("\(k.icon) \(k.label)")
                                            .font(.jk(14, .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(kind == k ? T.blue : T.card).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        Text(kind.blurb).font(.jk(13)).foregroundColor(T.sub)
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(8).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: text) { v in if v.count > 240 { text = String(v.prefix(240)) } }
                        HStack {
                            Button { text = kind.suggestion() } label: { Label("Suggest", systemImage: "sparkles") }
                            Spacer()
                            Text("\(240 - text.count)").font(.jk(12)).foregroundColor(T.sub)
                        }
                        HStack {
                            Image(systemName: "bolt.fill").foregroundColor(T.gold)
                            Text("\(kind.cost) energy").font(.jk(13, .semibold))
                            Spacer()
                            if !game.canAfford(kind.cost) {
                                Text("Not enough energy").font(.jk(12)).foregroundColor(T.orange)
                            }
                        }
                        BigButton(title: "Post", enabled: !text.trimmed.isEmpty && game.canAfford(kind.cost)) {
                            if let o = game.publish(kind: kind, text: text, quest: seed.quest) {
                                game.pendingResult = o
                                nav.tab = 0
                                dismiss()
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(T.bg)
            .navigationTitle(seed.quest == nil ? "New post" : "Side quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { if text.isEmpty { text = seed.text } }
        }
    }
}

// MARK: - Event

struct EventSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let st = game.s
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Aura").font(.jk(13, .bold))
                            Spacer()
                            Text("\(st.aura)%").font(.jk(13, .bold)).foregroundColor(T.lime)
                        }
                        Bar(value: Double(st.aura) / 100, color: T.lime, height: 10)
                    }.card()

                    if let r = st.result {
                        resultCard(r)
                    } else if let e = st.currentEvent {
                        VStack(spacing: 10) {
                            HStack { Text(e.emoji).font(.jk(30)); if e.ai { Chip(text: "AI written") }; Spacer() }
                            Text(game.fill(e.text, st)).font(.jk(17, .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.card()
                        ForEach(Array(e.choices.enumerated()), id: \.offset) { i, c in
                            Button { game.choose(i) } label: {
                                HStack {
                                    Text(game.fill(c.text, st)).font(.jk(15, .semibold))
                                        .foregroundColor(.white).multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(16)
                                .background(T.card2)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    } else {
                        ProgressView().padding(40)
                    }
                }
                .padding(16)
            }
            .background(T.bg)
            .navigationTitle("Event").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear { game.ensureEvent() }
        }
    }

    @ViewBuilder
    private func resultCard(_ r: ResultRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(r.emoji).font(.jk(34)); Spacer() }
            Text(r.text).font(.jk(16))
            if r.cancelled { Text("🚫 Cancelled. Lost 30% of followers.").font(.jk(14, .bold)).foregroundColor(T.red) }
            if r.iconUnlocked { Text("👑 Icon status! +20% followers.").font(.jk(14, .bold)).foregroundColor(T.gold) }
            HStack {
                Chip(text: "Aura \(r.auraDelta >= 0 ? "+" : "")\(r.auraDelta)%", color: r.auraDelta >= 0 ? T.lime.opacity(0.35) : T.red.opacity(0.4))
                Chip(text: "\(r.followerDelta >= 0 ? "+" : "")\(short(r.followerDelta)) followers")
            }
            if !r.stats.isEmpty {
                HStack { ForEach(r.stats) { c in Chip(text: "\(c.kind.emoji) \(c.kind.label) \(c.up ? "↑" : "↓")") } }
            }
            if !r.npcs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(r.npcs) { n in Chip(text: "\(n.emoji) \(n.up ? "↑" : "↓")") }
                }
            }
        }.card()
        BigButton(title: "Continue to next day") {
            game.continueStory()
            dismiss()
        }
    }
}
