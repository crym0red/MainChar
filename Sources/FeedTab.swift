import SwiftUI

struct GameShell: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav

    var body: some View {
        TabView(selection: $nav.tab) {
            FeedTab().tabItem { Label("Feed", systemImage: "house.fill") }.tag(0)
            GoalsTab().tabItem { Label("Goals", systemImage: "target") }.tag(1)
            MessagesTab().tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(game.s.unread.count).tag(2)
            NotifsTab().tabItem { Label("Alerts", systemImage: "bell.fill") }
                .badge(game.unreadNotifs).tag(3)
            ProfileTab().tabItem { Label("Profile", systemImage: "person.fill") }.tag(4)
        }
        .tint(T.blue)
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
    @State private var npcSheet: NPC? = nil
    @State private var replyTo: UUID? = nil
    @State private var confirmExit = false
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let st = game.s
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    header(st)
                    EnergyBar()
                        .padding(.horizontal, 16).padding(.bottom, 10)
                    stories(st)
                    eventPill(st)
                    if !game.aiNote.isEmpty {
                        Text(game.aiNote).font(.system(size: 11)).foregroundColor(T.orange).padding(.bottom, 6)
                    }
                    ForEach(st.posts.filter { !st.hidden.contains($0.id) }) { p in
                        PostRow(post: p, onReply: { replyTo = p.id })
                        Divider().background(Color.white.opacity(0.08))
                    }
                    Color.clear.frame(height: 90)
                }
            }
            .refreshable { game.refreshFeed() }

            Button { compose = ComposeSeed() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    .frame(width: 58, height: 58).background(T.blue).clipShape(Circle())
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            }
            .padding(20)
        }
        .background(T.bg)
        .onReceive(timer) { _ in game.tickEnergy() }
        .sheet(item: $compose) { seed in ComposeSheet(seed: seed) }
        .sheet(isPresented: $showEvent) { EventSheet() }
        .sheet(item: $npcSheet) { n in NPCSheet(npc: n) }
        .sheet(item: Binding(get: { replyTo.map { IDBox(id: $0) } }, set: { replyTo = $0?.id })) { b in
            ReplySheet(postID: b.id)
        }
        .alert("Leave this world?", isPresented: $confirmExit) {
            Button("Leave") { game.exitToHub() }
            Button("Stay", role: .cancel) {}
        } message: { Text("Your progress is saved.") }
        .onChange(of: game.s.threads.count) { _ in }
    }

    private func header(_ st: GameState) -> some View {
        HStack {
            Button { confirmExit = true } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(T.sub)
                    .frame(width: 36, height: 36).background(T.card).clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 0) {
                Text("Day \(st.day)").font(.system(size: 20, weight: .heavy))
                Text(st.world.title).font(.system(size: 11)).foregroundColor(T.sub)
            }
            Spacer()
            Text(short(st.followers)).font(.system(size: 13, weight: .bold)).foregroundColor(T.blue)
                .padding(.horizontal, 10).padding(.vertical, 8).background(T.card).clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
    }

    private func stories(_ st: GameState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(st.npcs.filter { $0.id != "newsdesk" }) { n in
                    Button { npcSheet = n } label: {
                        VStack(spacing: 4) {
                            Avatar(emoji: n.emoji, key: n.handle, size: 56, ring: true)
                            Text(n.name.components(separatedBy: " ").first ?? n.name)
                                .font(.system(size: 11)).foregroundColor(T.sub).lineLimit(1)
                        }.frame(width: 64)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    private func eventPill(_ st: GameState) -> some View {
        Button { showEvent = true } label: {
            HStack(spacing: 8) {
                Circle().fill(T.orange).frame(width: 8, height: 8)
                Text(st.result != nil ? "See what happened" : "New event")
                    .font(.system(size: 14, weight: .bold))
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(T.card2).clipShape(Capsule())
        }
        .padding(.bottom, 12)
    }
}

struct IDBox: Identifiable { let id: UUID }

// MARK: - Energy

struct EnergyBar: View {
    @EnvironmentObject var game: Game

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let (e, secs) = game.liveEnergy(at: ctx.date)
            let st = game.s
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill").foregroundColor(T.gold)
                HStack(spacing: 3) {
                    ForEach(0..<Game.maxEnergy, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < e ? T.gold : Color.white.opacity(0.12))
                            .frame(height: 10)
                    }
                }
                Text("\(e)/\(Game.maxEnergy)").font(.system(size: 12, weight: .bold))
                if st.bonus > 0 { Chip(text: "+\(st.bonus) Bonus", color: T.orange.opacity(0.9)) }
                if let secs = secs {
                    Text(clockString(secs)).font(.system(size: 11, weight: .medium)).foregroundColor(T.sub).monospacedDigit()
                }
                if game.canRefill {
                    Button("Refill") { game.refill() }
                        .font(.system(size: 12, weight: .bold)).foregroundColor(T.blue)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Post row

struct PostRow: View {
    @EnvironmentObject var game: Game
    let post: Post
    var onReply: () -> Void

    var body: some View {
        let saved = game.s.saved.contains(post.id)
        HStack(alignment: .top, spacing: 10) {
            Avatar(emoji: post.emoji, key: post.authorHandle, size: 42)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(post.authorName).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    if post.verified { VerifiedSeal() }
                    Text("@\(post.authorHandle) · D\(post.day)")
                        .font(.system(size: 12)).foregroundColor(T.sub).lineLimit(1)
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
                Text(post.text).font(.system(size: 15)).foregroundColor(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 22) {
                    Button(action: onReply) { Label("\(post.comments.count)", systemImage: "bubble.left") }
                    Label("\(short(post.reposts))", systemImage: "arrow.2.squarepath")
                    Button { game.like(post.id) } label: {
                        Label(short(post.likes), systemImage: post.liked ? "heart.fill" : "heart")
                            .foregroundColor(post.liked ? T.red : T.sub)
                    }
                    Image(systemName: saved ? "bookmark.fill" : "bookmark").foregroundColor(saved ? T.blue : T.sub)
                        .onTapGesture { game.toggleSave(post.id) }
                }
                .font(.system(size: 13)).foregroundColor(T.sub).padding(.top, 2)
                if let c = post.comments.first {
                    Text("\(c.name): \(c.text)").font(.system(size: 12)).foregroundColor(T.sub).lineLimit(2)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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
                                    Text(p.authorName).font(.system(size: 15, weight: .bold))
                                    Text(p.text).font(.system(size: 15))
                                }
                            }
                            Divider()
                            if p.comments.isEmpty { Text("No replies yet.").foregroundColor(T.sub).font(.system(size: 13)) }
                            ForEach(p.comments) { c in
                                HStack(alignment: .top, spacing: 10) {
                                    Avatar(emoji: c.emoji, key: c.handle, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(c.name).font(.system(size: 13, weight: .bold))
                                            if c.verified { VerifiedSeal(size: 11) }
                                        }
                                        Text(c.text).font(.system(size: 14))
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
                Text(live.name).font(.system(size: 22, weight: .heavy))
                if live.followers >= 40000 { VerifiedSeal(size: 18) }
            }
            Text("@\(live.handle) · \(short(live.followers)) followers").font(.system(size: 13)).foregroundColor(T.sub)
            Text(live.bio).font(.system(size: 14)).multilineTextAlignment(.center).padding(.horizontal, 24)
            HStack(spacing: 8) {
                Chip(text: live.trait.rawValue.capitalized)
                if live.followsYou { Chip(text: "Follows you", color: T.blue.opacity(0.8)) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Relationship").font(.system(size: 12)).foregroundColor(T.sub)
                Bar(value: Double(live.affinity) / 100, color: T.lime)
            }.padding(.horizontal, 28)
            BigButton(title: "Message") {
                game.startChat(live.handle)
                nav.chat = live.handle
                nav.tab = 2
                dismiss()
            }.padding(.horizontal, 20)
            Spacer()
        }
        .background(T.bg)
        .presentationDetents([.medium])
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

    private var kinds: [PostKind] {
        PostKind.allCases.filter { $0 != .apology || game.s.aura < 30 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let o = outcome {
                        VStack(spacing: 8) {
                            Text(o.emoji).font(.system(size: 50))
                            Text(o.title).font(.system(size: 22, weight: .heavy))
                            Text(o.detail).font(.system(size: 14)).foregroundColor(T.sub).multilineTextAlignment(.center)
                            BigButton(title: "Done") { dismiss() }.padding(.top, 8)
                        }.frame(maxWidth: .infinity).padding(.top, 30)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(kinds) { k in
                                    Button { kind = k } label: {
                                        Text("\(k.icon) \(k.label)")
                                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(kind == k ? T.blue : T.card).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        Text(kind.blurb).font(.system(size: 13)).foregroundColor(T.sub)
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(8).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: text) { v in if v.count > 240 { text = String(v.prefix(240)) } }
                        HStack {
                            Button { text = kind.suggestion() } label: { Label("Suggest", systemImage: "sparkles") }
                            Spacer()
                            Text("\(240 - text.count)").font(.system(size: 12)).foregroundColor(T.sub)
                        }
                        HStack {
                            Image(systemName: "bolt.fill").foregroundColor(T.gold)
                            Text("\(kind.cost) energy").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if !game.canAfford(kind.cost) {
                                Text("Not enough energy").font(.system(size: 12)).foregroundColor(T.orange)
                            }
                        }
                        BigButton(title: "Post", enabled: !text.trimmed.isEmpty && game.canAfford(kind.cost)) {
                            outcome = game.publish(kind: kind, text: text, quest: seed.quest)
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
                            Text("Aura").font(.system(size: 13, weight: .bold))
                            Spacer()
                            Text("\(st.aura)%").font(.system(size: 13, weight: .bold)).foregroundColor(T.lime)
                        }
                        Bar(value: Double(st.aura) / 100, color: T.lime, height: 10)
                    }.card()

                    if let r = st.result {
                        resultCard(r)
                    } else if let e = st.currentEvent {
                        VStack(spacing: 10) {
                            HStack { Text(e.emoji).font(.system(size: 30)); if e.ai { Chip(text: "AI written") }; Spacer() }
                            Text(game.fill(e.text, st)).font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.card()
                        ForEach(Array(e.choices.enumerated()), id: \.offset) { i, c in
                            Button { game.choose(i) } label: {
                                HStack {
                                    Text(game.fill(c.text, st)).font(.system(size: 15, weight: .semibold))
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
            HStack { Text(r.emoji).font(.system(size: 34)); Spacer() }
            Text(r.text).font(.system(size: 16))
            if r.cancelled { Text("🚫 Cancelled. Lost 30% of followers.").font(.system(size: 14, weight: .bold)).foregroundColor(T.red) }
            if r.iconUnlocked { Text("👑 Icon status! +20% followers.").font(.system(size: 14, weight: .bold)).foregroundColor(T.gold) }
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
