import SwiftUI

struct GameShell: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                T.bg.ignoresSafeArea()
                switch nav.tab {
                case 0: FeedTab()
                case 1: GoalsTab()
                case 2: MessagesTab()
                case 3: NotifsTab()
                case 5: MarketView()
                default: ProfileTab()
                }
            }
            .frame(maxHeight: .infinity)
            AppTabBar()
        }
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
        .onAppear { game.checkStreak(); game.catchUp(); Task { await SyncClient.shared.syncAll(game) } }
        .onChange(of: scenePhase) { phase in
            if phase == .active { game.checkStreak(); game.catchUp(); Task { await SyncClient.shared.syncAll(game) } }
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
            item(5, "chart.line.uptrend.xyaxis")
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
    @State private var quoteID: UUID? = nil
    @State private var confirmExit = false
    @State private var showStore = false
    @State private var liveOpen: LiveOpen? = nil
    @State private var storyNPC: IDBox? = nil
    @State private var goLive = false
    @State private var path: [UUID] = []
    @State private var mode = 0
    @State private var topic: String? = nil
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let liveTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    private let olive = Color(red: 0.47, green: 0.38, blue: 0.08)

    var body: some View {
        let st = game.s
        let list = filteredPosts(st)
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header(st)
                    Divider().background(Color.white.opacity(0.12))
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            stories(st)
                            Divider().background(Color.white.opacity(0.12))
                            if !game.aiNote.isEmpty {
                                Text(game.aiNote).font(.jk(11)).foregroundColor(T.orange).padding(.vertical, 6)
                            }
                            feedControls(st)
                            if list.isEmpty {
                                Text(mode == 1 ? "Nobody here yet. Follow people from their profile." : "Nothing matches that topic.")
                                    .font(.jk(15)).foregroundColor(T.sub).padding(.vertical, 40)
                            }
                            ForEach(list) { p in
                                PostRow(post: p, onReply: { replyTo = p.id }, onOpen: { path.append(p.id) }, onQuote: { quoteID = p.id })
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
        .onReceive(timer) { _ in game.ambientTick() }
        .onReceive(liveTimer) { _ in game.liveTick() }
        .onChange(of: game.openPostID) { id in
            if let id = id { path = [id]; game.openPostID = nil }
        }
        .onAppear {
            game.refreshIfStale()
            game.seedPresence()
            if let id = game.pendingResult?.postID, path.last != id { path = [id] }
        }
        .onChange(of: game.pendingResult) { r in
            if let id = r?.postID { path = [id] }
        }
        .sheet(item: $compose) { seed in ComposeSheet(seed: seed).zoomed().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .fullScreenCover(isPresented: $showStore) { StoreView().zoomed() }
        .sheet(isPresented: $showEvent) { EventSheet().zoomed() }
        .sheet(isPresented: $showExplore) { ExploreSheet().zoomed() }
        .fullScreenCover(item: $liveOpen) { o in LiveView(mode: o.mode, onClose: { liveOpen = nil }).zoomed() }
        .fullScreenCover(item: $storyNPC) { b in NPCStoryViewer(storyID: b.id, onClose: { storyNPC = nil }).zoomed() }
        .confirmationDialog("Go live", isPresented: $goLive, titleVisibility: .visible) {
            ForEach(["Just Chatting", "Hot Takes", "Q&A", "Callout Stream"], id: \.self) { t in
                Button(t) { liveOpen = LiveOpen(mode: .host(t)) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $storyOpen) { o in StoriesFlow(openStory: o.story).zoomed() }
        .sheet(item: $npcSheet) { n in NPCSheet(npc: n).zoomed() }
        .sheet(item: Binding(get: { replyTo.map { IDBox(id: $0) } }, set: { replyTo = $0?.id })) { b in
            ReplySheet(postID: b.id).zoomed()
        }
        .sheet(item: Binding(get: { quoteID.map { IDBox(id: $0) } }, set: { quoteID = $0?.id })) { b in
            QuoteSheet(postID: b.id).zoomed()
        }
        .alert("Leave this world?", isPresented: $confirmExit) {
            Button("Leave") { game.exitToHub() }
            Button("Stay", role: .cancel) {}
        } message: { Text("Your progress is saved.") }
    }

    private func filteredPosts(_ st: GameState) -> [Post] {
        var l = st.posts.filter { !st.hidden.contains($0.id) }
        if mode == 1 {
            let f = Set(st.ex.following ?? [])
            l = l.filter { f.contains($0.authorHandle) || $0.isYou }
        }
        if let t = topic { l = l.filter { game.postMatches($0, topic: t) } }
        return l
    }

    private func feedControls(_ st: GameState) -> some View {
        let trends = game.trendingTopics(st)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 22) {
                ForEach(Array(["For You", "Following"].enumerated()), id: \.offset) { i, t in
                    Button { mode = i } label: {
                        VStack(spacing: 6) {
                            Text(t).font(.jk(17, .semibold)).foregroundColor(mode == i ? .white : T.sub)
                            Rectangle().fill(mode == i ? Color.white : Color.clear).frame(height: 3).clipShape(Capsule())
                        }
                    }
                }
                Spacer()
            }
            if let c = st.ex.community, c.ends > Date() || c.done { CommunityBanner(c: c) }
            if !trends.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill").foregroundColor(T.orange)
                        ForEach(trends, id: \.self) { t in
                            Button { topic = topic == t ? nil : t } label: {
                                Text(t).font(.jk(13, .semibold)).foregroundColor(topic == t ? .black : .white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(topic == t ? Color.white : T.card2).clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func header(_ st: GameState) -> some View {
        HStack(spacing: 10) {
            MCLogo(size: 30)
            Text("Day \(st.day)").font(.jk(14, .semibold)).foregroundColor(T.sub).lineLimit(1).fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 5).background(T.card2).clipShape(Capsule())
            Spacer(minLength: 4)
            Button { showStore = true } label: {
                HStack(spacing: 6) {
                    GemIcon(size: 24)
                    Text("\(st.ex.gems)").font(.jk(17, .semibold)).foregroundColor(gemPurple).lineLimit(1).fixedSize()
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .frame(width: 22, height: 22).background(Color(red: 0.55, green: 0.30, blue: 0.90)).clipShape(Circle())
                }
                .padding(.leading, 12).padding(.trailing, 7).frame(height: 46)
                .fixedSize(horizontal: true, vertical: false)
                .background(T.card2).clipShape(Capsule())
            }
            Button { showStore = true } label: {
                Image(systemName: "storefront.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.85))
                    .frame(width: 46, height: 46).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Button { confirmExit = true } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 20, weight: .semibold))
                    .foregroundColor(T.red).frame(width: 46, height: 46).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
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
                Button { goLive = true } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(T.red, lineWidth: 3).frame(width: 78, height: 78)
                            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 30)).foregroundColor(T.red)
                        }
                        Text("Go live").font(.jk(14)).foregroundColor(T.sub)
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
                ForEach(npcRow(st)) { n in
                    let live = (st.ex.npcLives ?? []).contains { $0.handle == n.handle && $0.ends > Date() }
                    let story = (st.ex.npcStories ?? []).first { $0.handle == n.handle }
                    Button {
                        if live { liveOpen = LiveOpen(mode: .watch(n.handle)) }
                        else if let s = story { storyNPC = IDBox(id: s.id) }
                        else { npcSheet = n }
                    } label: {
                        VStack(spacing: 6) {
                            Avatar(emoji: n.emoji, key: n.handle, size: 74, ring: !live && story == nil)
                                .overlay {
                                    if live { Circle().stroke(T.red, lineWidth: 3.5).frame(width: 82, height: 82) }
                                    else if let s = story {
                                        Circle().stroke(s.seen == true ? Color.white.opacity(0.3) : T.lime, lineWidth: 3.5).frame(width: 82, height: 82)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if live {
                                        Text("LIVE").font(.jk(10, .bold)).foregroundColor(.white)
                                            .padding(.horizontal, 7).padding(.vertical, 2)
                                            .background(T.red).clipShape(Capsule()).offset(y: 8)
                                    }
                                }
                            Text(n.name.components(separatedBy: " ").first ?? n.name)
                                .font(.jk(14)).foregroundColor(T.sub).lineLimit(1)
                        }.frame(width: 84)
                    }
                    .contextMenu { Button("Profile") { npcSheet = n } }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private func npcRow(_ st: GameState) -> [NPC] {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        func rank(_ n: NPC) -> Int {
            if (st.ex.npcLives ?? []).contains(where: { $0.handle == n.handle && $0.ends > Date() }) { return 0 }
            if let s = (st.ex.npcStories ?? []).first(where: { $0.handle == n.handle }) { return s.seen == true ? 2 : 1 }
            return 3
        }
        return cast.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map { $0.element }
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
                        Image(systemName: "theatermasks.fill").font(.system(size: 22)).foregroundColor(.white).rotationEffect(.degrees(-12)).offset(x: -4, y: -8)
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
    @EnvironmentObject var nav: Nav
    let post: Post
    var onReply: () -> Void
    var onOpen: () -> Void
    var onQuote: () -> Void = {}
    @State private var tip = false

    var body: some View {
        let st = game.s
        let saved = st.saved.contains(post.id)
        let isNews = st.npcs.first(where: { $0.handle == post.authorHandle })?.id == "newsdesk"
        HStack(alignment: .top, spacing: 12) {
            Avatar(emoji: post.emoji, key: post.authorHandle, size: 52, photo: !isNews)
                .profileTap(post.authorHandle)
            VStack(alignment: .leading, spacing: 6) {
                if let by = post.rtBy {
                    Label(by == st.persona.name ? "You reposted" : "\(by) reposted", systemImage: "arrow.2.squarepath")
                        .font(.jk(12, .semibold)).foregroundColor(T.sub)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        HStack(spacing: 5) {
                            Text(post.authorName).font(.jk(18, .bold)).lineLimit(1)
                            if post.verified { VerifiedSeal(size: 16) }
                            Text("@\(post.authorHandle)").font(.jk(16)).foregroundColor(T.sub).lineLimit(1)
                        }.profileTap(post.authorHandle)
                        if let ts = post.ts { Text("· " + agoString(ts).replacingOccurrences(of: " ago", with: "")).font(.jk(14)).foregroundColor(T.sub).lineLimit(1).fixedSize() }
                        Spacer(minLength: 0)
                        Menu {
                            Button { game.toggleSave(post.id) } label: {
                                Label(saved ? "Remove favorite" : "Favorite", systemImage: "star")
                            }
                            Button(role: .destructive) { game.hide(post.id) } label: { Label("Hide post", systemImage: "eye.slash") }
                        } label: {
                            Image(systemName: "ellipsis").foregroundColor(T.sub).padding(6)
                        }
                    }
                    if !post.tag.isEmpty {
                        Chip(text: post.tag, color: post.tag == "Breaking" ? T.red.opacity(0.85) : T.card2)
                    }
                    if post.isYou, let ti = st.ex.title { Chip(text: ti, color: T.gold.opacity(0.3)) }
                    Text(post.text).postStyled(post.style)
                        .fixedSize(horizontal: false, vertical: true)
                    if let t = Mk.tickers(post.text).first, (game.s.ex.market?.coins ?? []).contains(where: { $0.id == t }) {
                        Button { nav.coin = t; nav.tab = 5 } label: {
                            Label("Trade $\(t)", systemImage: "chart.line.uptrend.xyaxis").font(.jk(14, .bold))
                                .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(red: 0.45, green: 0.30, blue: 0.95)).clipShape(Capsule())
                        }
                    }
                    PostExtras(post: post, onOpen: onOpen)
                    if post.tag == "Donate" && !post.isYou {
                        Button { tip = true } label: {
                            Label("Donate", systemImage: "dollarsign.circle.fill").font(.jk(14, .bold))
                                .foregroundColor(.black).padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.95, blue: 0.5)).clipShape(Capsule())
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                HStack(spacing: 22) {
                    Button(action: onReply) { Label("\(post.comments.count)", systemImage: "bubble.left") }
                    Menu {
                        Button { game.repost(post.id) } label: { Label("Repost", systemImage: "arrow.2.squarepath") }
                        Button(action: onQuote) { Label("Quote", systemImage: "quote.bubble") }
                    } label: { Label("\(short(post.reposts))", systemImage: "arrow.2.squarepath") }
                    Menu {
                        ForEach(Array(Game.reactionList.enumerated()), id: \.offset) { _, rk in
                        let sym = rk.0, key = rk.1
                            Button { game.react(post.id, key) } label: { Label(key.capitalized, systemImage: sym) }
                        }
                    } label: {
                        Label(short(post.likes), systemImage: post.liked ? "heart.fill" : "heart")
                            .foregroundColor(post.liked ? T.red : T.sub)
                    } primaryAction: { game.like(post.id) }
                    if !post.isYou {
                        Button { tip = true } label: { Image(systemName: "dollarsign.circle").foregroundColor(T.sub) }
                            .sheet(isPresented: $tip) { SendSheet(to: post.authorHandle, ctx: "post").zoomed() }
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
    @State private var replyingTo: String? = nil
    @State private var liked: Set<UUID> = []
    @FocusState private var focus: Bool

    private let quick = ["💀", "fr", "ratio", "facts", "nah", "🔥"]

    private func mentionText(_ s: String, size: CGFloat) -> Text {
        var out = Text("")
        let parts = s.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        for (i, w) in parts.enumerated() {
            let piece = (i == 0 ? "" : " ") + w
            if w.hasPrefix("@") || w.hasPrefix("#") || w.hasPrefix("$") {
                out = out + Text(piece).font(.jk(size, .semibold)).foregroundColor(T.blue)
            } else {
                out = out + Text(piece).font(.jk(size)).foregroundColor(.white)
            }
        }
        return out
    }

    private func send() {
        let body = text.trimmed
        guard !body.isEmpty else { return }
        let full = (replyingTo != nil && !body.lowercased().hasPrefix("@\(replyingTo!.lowercased())")) ? "@\(replyingTo!) " + body : body
        game.reply(to: postID, text: full)
        text = ""
        replyingTo = nil
    }

    var body: some View {
        let st = game.s
        let post = st.posts.first { $0.id == postID }
        let me = st.persona
        VStack(spacing: 0) {
            HStack {
                Text("Replies").font(.jk(20, .bold))
                if let p = post {
                    Text("\(p.comments.count)").font(.jk(13, .bold)).foregroundColor(T.sub)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(T.card2).clipShape(Capsule())
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(width: 32, height: 32).background(T.card2).clipShape(Circle())
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let p = post {
                            header(p)
                            if !(p.queue ?? []).isEmpty {
                                Label("Live · \(p.queue?.count ?? 0) more replies incoming", systemImage: "dot.radiowaves.left.and.right")
                                    .font(.jk(12, .bold)).foregroundColor(T.red)
                                    .padding(.horizontal, 10).padding(.vertical, 5).background(T.red.opacity(0.15)).clipShape(Capsule())
                                    .padding(.horizontal, 16).padding(.bottom, 10)
                            }
                            if p.comments.isEmpty {
                                VStack(spacing: 6) {
                                    Text("💬").font(.system(size: 34))
                                    Text("No replies yet").font(.jk(15, .semibold))
                                    Text("Start the thread.").font(.jk(13)).foregroundColor(T.sub)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 40)
                            }
                            ForEach(p.comments) { c in
                                commentRow(c, mine: c.handle == me.handle)
                                    .id(c.id)
                            }
                            Color.clear.frame(height: 8).id("end")
                        }
                    }
                }
                .onChange(of: post?.comments.count ?? 0) { _ in
                    withAnimation { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            composer(me)
        }
        .background(T.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func header(_ p: Post) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Avatar(emoji: p.emoji, key: p.authorHandle, size: 44).profileTap(p.authorHandle)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(p.authorName).font(.jk(16, .bold)).lineLimit(1)
                        if p.verified { VerifiedSeal(size: 13) }
                        Text("@\(p.authorHandle)").font(.jk(13)).foregroundColor(T.sub).lineLimit(1)
                    }
                    if !p.tag.isEmpty { Chip(text: p.tag) }
                }
                Spacer(minLength: 0)
            }
            Text(p.text).postStyled(p.style, base: 17).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                Label("\(p.comments.count)", systemImage: "bubble.left")
                Label(short(p.reposts), systemImage: "arrow.2.squarepath")
                Label(short(p.likes), systemImage: "heart")
            }
            .font(.jk(13, .semibold)).foregroundColor(T.sub)
        }
        .padding(14)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func commentRow(_ c: Comment, mine: Bool) -> some View {
        let isLiked = liked.contains(c.id)
        let sameName = c.name.lowercased() == c.handle.lowercased()
        return HStack(alignment: .top, spacing: 10) {
            Avatar(emoji: c.emoji, key: c.handle, size: 36).profileTap(c.handle)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(mine ? "You" : c.name).font(.jk(14, .bold)).lineLimit(1)
                    if c.verified { VerifiedSeal(size: 12) }
                    if !sameName && !mine { Text("@\(c.handle)").font(.jk(12)).foregroundColor(T.sub).lineLimit(1) }
                }
                .profileTap(c.handle)
                mentionText(c.text, size: 15).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    Button { if isLiked { liked.remove(c.id) } else { liked.insert(c.id) } } label: {
                        Label(isLiked ? "Liked" : "Like", systemImage: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? T.red : T.sub)
                    }
                    if !mine {
                        Button { replyingTo = c.handle; focus = true } label: {
                            Label("Reply", systemImage: "arrowshape.turn.up.left").foregroundColor(T.sub)
                        }
                    }
                }
                .font(.jk(12, .semibold)).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(mine ? T.blue.opacity(0.08) : Color.clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 62) }
    }

    private func composer(_ me: Persona) -> some View {
        VStack(spacing: 8) {
            if let r = replyingTo {
                HStack(spacing: 6) {
                    Text("Replying to").font(.jk(12)).foregroundColor(T.sub)
                    Text("@\(r)").font(.jk(12, .bold)).foregroundColor(T.blue)
                    Spacer()
                    Button { replyingTo = nil } label: { Image(systemName: "xmark.circle.fill").foregroundColor(T.sub) }
                }
                .padding(.horizontal, 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quick, id: \.self) { q in
                        Button { text += (text.isEmpty || text.hasSuffix(" ") ? "" : " ") + q } label: {
                            Text(q).font(.jk(13, .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6).background(T.card2).clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            HStack(spacing: 10) {
                Avatar(emoji: me.emoji, key: me.handle, size: 34)
                TextField("Add a reply…", text: $text)
                    .focused($focus)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(T.card).clipShape(Capsule())
                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                        .foregroundColor(text.trimmed.isEmpty ? T.sub.opacity(0.6) : T.blue)
                }
                .disabled(text.trimmed.isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8).padding(.bottom, 10)
        .background(T.bg)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
    }
}

// MARK: - NPC sheet

struct NPCSheet: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss
    let npc: NPC
    @State private var tab = 0
    @State private var showWallet = false

    var body: some View {
        let st = game.s
        let live = st.npcs.first { $0.handle == npc.handle } ?? npc
        let neon = HK.neon(live.handle)
        let rel = Rel.info(live.affinity)
        let posts = st.posts.filter { $0.authorHandle == live.handle }
        let replies: [(Post, Comment)] = st.posts.flatMap { p in p.comments.filter { $0.handle == live.handle }.map { (p, $0) } }
        let coins = (st.ex.market?.coins ?? []).filter { $0.creator == live.handle }
        let rank = game.rankings(st).firstIndex { $0.handle == live.handle }.map { $0 + 1 } ?? 0
        let following = game.isFollowing(live.handle)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        LinearGradient(colors: [neon.opacity(0.65), Color(white: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Canvas { ctx, sz in
                            var p = Path()
                            var x: CGFloat = 0
                            while x < sz.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: sz.height)); x += 24 }
                            var y: CGFloat = 0
                            while y < sz.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: sz.width, y: y)); y += 24 }
                            ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 0.6)
                        }
                    }
                    .frame(height: 110)
                    Avatar(emoji: live.emoji, key: live.handle, size: 92)
                        .overlay(Circle().stroke(T.bg, lineWidth: 4).padding(-2))
                        .padding(.leading, 16).offset(y: 46)
                }
                .padding(.bottom, 46)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(live.name).font(.jk(24, .heavy))
                            if live.followers >= 40000 { VerifiedSeal(size: 18) }
                        }
                        Text("@\(live.handle)").font(.jk(14)).foregroundColor(T.sub)
                    }
                    Spacer()
                    Label(rel.0, systemImage: rel.1).font(.jk(12, .bold)).foregroundColor(rel.2)
                        .padding(.horizontal, 10).padding(.vertical, 6).background(rel.2.opacity(0.15)).clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                Text(live.bio).font(.jk(15)).padding(.horizontal, 16)
                HStack(spacing: 14) {
                    Label(Crowd.city(live.handle), systemImage: "mappin.and.ellipse")
                    Label("Joined " + Crowd.joined(live.handle), systemImage: "calendar")
                    Label(live.trait.rawValue.capitalized, systemImage: "sparkles")
                }
                .font(.jk(12)).foregroundColor(T.sub).padding(.horizontal, 16)
                HStack(spacing: 8) {
                    Chip(text: live.trait.rawValue.capitalized)
                    if live.followsYou { Chip(text: "Follows you", color: T.blue.opacity(0.8)) }
                    if live.followsYou && following { Chip(text: "Mutual", color: T.lime.opacity(0.4)) }
                    if rank > 0 && rank <= 10 { Chip(text: "Top \(rank)", color: T.gold.opacity(0.4)) }
                }
                .padding(.horizontal, 16)
                HStack(spacing: 0) {
                    statCell(short(live.followers), "Followers")
                    statCell("\(stableNum(live.handle, 80, 900))", "Following")
                    statCell("\(posts.count)", "Posts")
                    statCell(rank > 0 ? "#\(rank)" : "-", "Rank")
                }
                .padding(.vertical, 12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 16)
                HStack(spacing: 10) {
                    Button { game.toggleFollow(live.handle) } label: {
                        Text(following ? "Following" : "Follow").font(.jk(16, .bold))
                            .foregroundColor(following ? .white : .black)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(following ? Color.white.opacity(0.14) : Color.white).clipShape(Capsule())
                    }
                    Button {
                        game.startChat(live.handle)
                        nav.chat = live.handle
                        nav.tab = 2
                        dismiss()
                    } label: {
                        Text("Message").font(.jk(16, .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(T.blue).clipShape(Capsule())
                    }
                    Button { showWallet = true } label: {
                        Image(systemName: "wallet.pass.fill").font(.system(size: 17, weight: .bold)).foregroundColor(T.gold)
                            .frame(width: 48, height: 46).background(Color.white.opacity(0.12)).clipShape(Capsule())
                    }
                    .fullScreenCover(isPresented: $showWallet) { WalletView(handle: live.handle).zoomed() }
                    if st.ex.gifts > 0 {
                        Button { game.sendGift(live.handle) } label: {
                            Image(systemName: "gift.fill").font(.system(size: 18)).foregroundColor(T.gold)
                                .frame(width: 48, height: 46).background(T.card2).clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                HStack(spacing: 22) {
                    ForEach(Array(["Posts", "Replies", "Coins", "History"].enumerated()), id: \.offset) { i, t in
                        Button { tab = i } label: {
                            VStack(spacing: 6) {
                                Text(t).font(.jk(16, .semibold)).foregroundColor(tab == i ? .white : T.sub)
                                Rectangle().fill(tab == i ? neon : Color.clear).frame(height: 3).clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                Group {
                    switch tab {
                    case 0:
                        if posts.isEmpty { empty("No posts yet.") }
                        ForEach(posts.prefix(20)) { p in
                            Button { game.openPostID = p.id; nav.tab = 0; dismiss() } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(p.text).font(.jk(15)).foregroundColor(.white).multilineTextAlignment(.leading)
                                    HStack(spacing: 14) {
                                        Label("\(p.comments.count)", systemImage: "bubble.left")
                                        Label(short(p.likes), systemImage: "heart")
                                        if !p.tag.isEmpty { Chip(text: p.tag) }
                                    }.font(.jk(12)).foregroundColor(T.sub)
                                }
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                        }
                    case 1:
                        if replies.isEmpty { empty("No replies yet.") }
                        ForEach(Array(replies.prefix(20).enumerated()), id: \.offset) { _, r in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Replying to @\(r.0.authorHandle)").font(.jk(12)).foregroundColor(T.sub)
                                Text(r.1.text).font(.jk(15))
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    case 2:
                        if coins.isEmpty { empty("Hasn't launched a coin.") }
                        ForEach(coins) { c in
                            Button { nav.coin = c.id; nav.tab = 5; dismiss() } label: {
                                HStack(spacing: 12) {
                                    CoinTile(c: c, size: 42)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("$\(c.id)").font(.jk(16, .bold)).foregroundColor(.white)
                                        Text(c.rugged ? "Rugged" : "\(Mk.fmtMC(Mk.mc(c))) MC").font(.jk(12)).foregroundColor(c.rugged ? T.red : T.sub)
                                    }
                                    Spacer()
                                    Text(Mk.pct(Mk.change(c))).font(.jk(14, .bold)).foregroundColor(Mk.change(c) >= 0 ? T.lime : T.red)
                                }
                                .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                        }
                    default:
                        MemoryBlock(handle: live.handle)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
        }
        .background(T.bg)
        .presentationDetents([.large])
    }

    private func statCell(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.jk(18, .bold))
            Text(l).font(.jk(11)).foregroundColor(T.sub)
        }.frame(maxWidth: .infinity)
    }

    private func empty(_ t: String) -> some View {
        Text(t).font(.jk(14)).foregroundColor(T.sub).frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

// MARK: - Compose

struct ComposeExtras {
    var tone = 0
    var poll: [String]? = nil
    var pollQ = ""
    var media: Media? = nil
    var style: PostStyle? = nil
    var coin: String? = nil
    var reach: Double {
        [1.0, 1.25, 1.6][max(0, min(2, tone))] * (poll != nil ? 1.15 : 1) * (media != nil ? 1.1 : 1) * (coin != nil ? 1.2 : 1)
    }
    var auraShift: Int {
        if tone == 1 { return Int.random(in: -3...2) }
        if tone == 2 { return Int.random(in: -6...4) }
        return 0
    }
    var viral: Double { (tone == 2 ? 0.08 : (tone == 1 ? 0.03 : 0)) + (coin != nil ? 0.04 : 0) }
}

struct ComposeSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let seed: ComposeSeed
    @State private var kind: PostKind = .meme
    @State private var text = ""
    @State private var tone = 0
    @State private var panel = 0          // 0 none, 1 poll, 2 snippet, 3 mention, 4 topic, 5 emoji, 6 style, 7 gif, 8 coin
    @State private var pollQ = ""
    @State private var pollOpts = ["", ""]
    @State private var pollOn = false
    @State private var snipTitle = "note.txt"
    @State private var snipBody = ""
    @State private var snipOn = false
    @State private var style = PostStyle()
    @State private var gif: String? = nil
    @State private var gifCaption = ""
    @State private var coinOn = false
    @State private var coinName = ""
    @State private var coinTicker = ""
    @State private var coinSeed = 10
    @State private var coinSymbol = "bolt.fill"
    @State private var launched: String? = nil
    @State private var pendingO: Outcome? = nil
    @State private var outcome: Outcome? = nil
    @FocusState private var focus: Bool
    @EnvironmentObject private var nav: Nav

    private let tones = ["Safe", "Edgy", "Unhinged"]
    private let toneNote = ["Steady reach.", "More reach. Aura can swing.", "Max reach, max chaos. Aura can crater."]
    private let emojis = ["😂", "💀", "🔥", "😭", "🫡", "👀", "🤝", "💅", "🧠", "🚀", "🫠", "🥲", "😤", "🙏", "✨", "🤡", "🗿", "💸", "🤌", "🫶"]

    private var kinds: [PostKind] {
        PostKind.allCases.filter { $0 != .apology || game.s.aura < 30 }
    }
    private var topics: [String] { Array(Topics.forWorld(game.s.world).prefix(12)) }
    private var cast: [NPC] {
        Array(game.s.npcs.filter { $0.id != "newsdesk" }.sorted { $0.affinity > $1.affinity }.prefix(14))
    }
    private var cleanOpts: [String] { pollOpts.map { $0.trimmed }.filter { !$0.isEmpty } }

    private var tickerClean: String { coinTicker.uppercased().filter { $0.isLetter || $0.isNumber } }
    private var coinError: String? {
        guard coinOn else { return nil }
        if coinName.trimmed.isEmpty { return "Name the coin" }
        if tickerClean.count < 2 || tickerClean.count > 6 { return "Ticker must be 2 to 6 characters" }
        if (game.s.ex.market?.coins ?? []).contains(where: { $0.id == tickerClean }) { return "That ticker is taken" }
        let need = coinSeed + Mk.launchFee
        if game.s.ex.gems < need { return "Need \(need) gems, you have \(game.s.ex.gems)" }
        return nil
    }

    private var extras: ComposeExtras {
        var x = ComposeExtras()
        x.tone = tone
        if pollOn, cleanOpts.count >= 2 { x.poll = cleanOpts; x.pollQ = pollQ.trimmed }
        if let g = gif {
            x.media = Media(kind: "gif", title: g, lines: [gifCaption.trimmed], hue: GifLib.all.first { $0.id == g }?.hue ?? 0.6)
        } else if snipOn, !snipBody.trimmed.isEmpty {
            x.media = Media(kind: "code", title: snipTitle.trimmed.isEmpty ? "note.txt" : snipTitle.trimmed,
                            lines: Array(snipBody.components(separatedBy: "\n").prefix(14)),
                            hue: Double(HK.h(snipTitle) % 360) / 360)
        }
        if !style.isDefault { x.style = style }
        if coinOn, coinError == nil { x.coin = tickerClean }
        return x
    }

    var body: some View {
        VStack(spacing: 0) {
            if let t = launched {
                launchScreen(t)
            } else {
                topRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        editor
                        toolRow
                        panelView
                        attachments
                        kindRow
                        toneRow
                    }
                    .padding(.horizontal, 16).padding(.bottom, 24)
                }
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear { if text.isEmpty { text = seed.text } }
        .onDisappear { if let o = pendingO { game.pendingResult = o } }
    }

    // MARK: Pieces

    private var canPost: Bool { !text.trimmed.isEmpty && coinError == nil }

    private var topRow: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .frame(width: 34, height: 34).background(T.card2).clipShape(Circle())
            }
            Text(seed.quest == nil ? "New post" : "Side quest").font(.jk(18, .bold))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundColor(T.gold)
                Text("\(kind.cost)").font(.jk(13, .bold))
            }
            .padding(.horizontal, 10).frame(height: 30).background(T.card2).clipShape(Capsule())
            Button { post() } label: {
                Text(coinOn ? "Post + Launch" : "Post").font(.jk(16, .bold)).foregroundColor(.white)
                    .padding(.horizontal, 20).frame(height: 36)
                    .background(canPost ? (coinOn ? Color(red: 0.45, green: 0.30, blue: 0.95) : T.blue) : T.card2).clipShape(Capsule())
            }
            .disabled(!canPost)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
    }

    private func post() {
        guard canPost else { return }
        let x = extras
        let spec: (String, String, String, Int)? = (coinOn && coinError == nil) ? (coinName.trimmed, tickerClean, coinSymbol, coinSeed) : nil
        guard let o = game.publish(kind: kind, text: text, quest: seed.quest, extras: x) else { return }
        if let c = spec {
            if let err = game.marketLaunch(name: c.0, ticker: c.1, symbol: c.2, seed: c.3, announce: false) {
                game.showToast(err)
            } else {
                pendingO = o
                withAnimation { launched = c.1 }
                return
            }
        }
        game.pendingResult = o
        nav.tab = 0
        dismiss()
    }

    private func launchScreen(_ t: String) -> some View {
        let c = (game.s.ex.market?.coins ?? []).first { $0.id == t }
        let held = (game.s.ex.market?.holds ?? []).first { $0.id == t }
        return ScrollView {
            VStack(spacing: 14) {
                LaunchRocket(ticker: t, hue: c?.hue ?? 0.7)
                Text("$\(t) is live").font(.jk(24, .heavy))
                Text("Your post is out and the coin launched with it. Buy in before the crowd does.")
                    .font(.jk(14)).foregroundColor(T.sub).multilineTextAlignment(.center)
                if let c = c {
                    HStack(spacing: 10) {
                        CoinTile(c: c, size: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name).font(.jk(16, .bold))
                            Text("Pool \(Mk.fmtGems(c.poolV)) gems · \(c.holders) holders").font(.jk(12)).foregroundColor(T.sub)
                        }
                        Spacer()
                        if let h = held { Text("\(Mk.fmtGems(h.qty * c.price)) gems held").font(.jk(12, .bold)).foregroundColor(T.lime) }
                    }
                    .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                HStack(spacing: 8) {
                    ForEach([2, 5, 10, 25], id: \.self) { a in
                        Button { game.marketBuy(t, gems: a) } label: {
                            VStack(spacing: 2) {
                                Text("Buy \(a)").font(.jk(15, .bold))
                                Text("\(game.s.ex.gems) gems").font(.jk(10)).foregroundColor(.white.opacity(0.6))
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color(red: 0.45, green: 0.30, blue: 0.95)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button { nav.coin = t; nav.tab = 5; dismiss() } label: {
                        Text("Open market").font(.jk(15, .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.card2).clipShape(Capsule())
                    }
                    Button { nav.tab = 0; dismiss() } label: {
                        Text("Done").font(.jk(15, .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(T.blue).clipShape(Capsule())
                    }
                }
            }
            .padding(16)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .focused($focus)
                .font(style.uiFont(18))
                .foregroundColor(style.color)
                .frame(minHeight: 96, maxHeight: 150)
                .padding(8)
                .onChange(of: text) { v in if v.count > 240 { text = String(v.prefix(240)) } }
            if text.isEmpty {
                Text("What's the move?").font(.jk(16)).foregroundColor(T.sub).padding(.horizontal, 14).padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
            VStack { Spacer(); HStack { Spacer(); Text("\(240 - text.count)").font(.jk(12)).foregroundColor(T.sub).padding(10) } }
        }
        .frame(height: 112)
        .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toolButton(_ icon: String, _ id: Int, on: Bool = false) -> some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { panel = panel == id ? 0 : id } } label: {
            toolFace(icon, active: panel == id || on)
        }
    }

    private func toolFace(_ icon: String, active: Bool) -> some View {
        Image(systemName: icon).font(.system(size: 18, weight: .semibold))
            .foregroundColor(active ? T.blue : .white)
            .frame(width: 50, height: 42)
            .background(active ? T.blue.opacity(0.18) : T.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var toolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button { text = String(PostGen.make(Int.random(in: 0..<PostGen.cats.count), scene: CastGen.isScene(game.s.world)).prefix(240)) } label: {
                        Label("Surprise me", systemImage: "dice.fill")
                    }
                    Button { text = kind.suggestion() } label: { Label("Match post type", systemImage: "sparkles") }
                    Divider()
                    ForEach(Array(PostGen.cats.enumerated()), id: \.offset) { i, c in
                        Button { text = String(PostGen.make(i, scene: CastGen.isScene(game.s.world)).prefix(240)) } label: { Text("\(c.1) \(c.0)") }
                    }
                } label: { toolFace("sparkles", active: false) }
                toolButton("textformat", 6, on: !style.isDefault)
                toolButton("play.rectangle.fill", 7, on: gif != nil)
                toolButton("bitcoinsign.circle.fill", 8, on: coinOn)
                toolButton("chart.bar.fill", 1, on: pollOn)
                toolButton("chevron.left.forwardslash.chevron.right", 2, on: snipOn)
                toolButton("at", 3)
                toolButton("number", 4)
                toolButton("face.smiling", 5)
            }
        }
    }

    @ViewBuilder private var panelView: some View {
        switch panel {
        case 1: pollPanel
        case 2: snippetPanel
        case 3:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cast) { n in
                        Button { insert("@\(n.handle) ") } label: {
                            VStack(spacing: 4) {
                                Avatar(emoji: n.emoji, key: n.handle, size: 46)
                                Text(n.name.components(separatedBy: " ").first ?? n.name).font(.jk(12, .semibold)).foregroundColor(.white).lineLimit(1)
                            }.frame(width: 60)
                        }
                    }
                }
                .padding(12)
            }
            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case 4:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(topics, id: \.self) { t in
                    Button { insert("#\(t.replacingOccurrences(of: " ", with: "")) ") } label: {
                        Text("#\(t)").font(.jk(13, .semibold)).foregroundColor(.white).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(T.card2).clipShape(Capsule())
                    }
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case 5:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 8) {
                ForEach(emojis, id: \.self) { e in
                    Button { insert(e) } label: { Text(e).font(.system(size: 24)) }
                }
            }
            .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case 6: stylePanel
        case 7: gifPanel
        case 8: coinPanel
        default: EmptyView()
        }
    }

    private func insert(_ s: String) { if text.count + s.count <= 240 { text += s } }

    private var pollPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Attach poll", isOn: $pollOn).font(.jk(15, .semibold)).tint(T.blue)
            TextField("Question (optional)", text: $pollQ).field()
            ForEach(pollOpts.indices, id: \.self) { i in
                HStack {
                    TextField("Option \(i + 1)", text: $pollOpts[i]).field()
                    if pollOpts.count > 2 {
                        Button { pollOpts.remove(at: i) } label: { Image(systemName: "minus.circle.fill").foregroundColor(T.sub) }
                    }
                }
            }
            if pollOpts.count < 4 {
                Button { pollOpts.append("") } label: { Label("Add option", systemImage: "plus.circle.fill").font(.jk(14, .semibold)) }
            }
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var snippetPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Attach snippet", isOn: $snipOn).font(.jk(15, .semibold)).tint(T.blue)
            TextField("File name", text: $snipTitle).field()
            TextEditor(text: $snipBody).scrollContentBackground(.hidden)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 100).padding(6).background(Color.black.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 10))
            if gif != nil { Text("A GIF is attached, it replaces the snippet.").font(.jk(12)).foregroundColor(T.orange) }
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var stylePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FONT").font(.jk(11, .heavy)).foregroundColor(T.sub)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(PostStyle.fonts.enumerated()), id: \.offset) { i, n in
                        Button { style.font = i } label: {
                            Text(n).font(PostStyle(font: i).uiFont(15)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(style.font == i ? T.blue : T.card2).clipShape(Capsule())
                        }
                    }
                }
            }
            Text("SIZE").font(.jk(11, .heavy)).foregroundColor(T.sub)
            HStack(spacing: 8) {
                ForEach(Array(PostStyle.sizes.enumerated()), id: \.offset) { _, z in
                    Button { style.scale = z.1 } label: {
                        Text(z.0).font(.jk(15, .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(style.scale == z.1 ? T.blue : T.card2).clipShape(Capsule())
                    }
                }
            }
            Text("COLOR").font(.jk(11, .heavy)).foregroundColor(T.sub)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PostStyle.palette, id: \.self) { h in
                        Button { style.hex = h == "FFFFFF" ? nil : h } label: {
                            Circle().fill(PostStyle.parse(h) ?? .white).frame(width: 34, height: 34)
                                .overlay(Circle().stroke(Color.white, lineWidth: (style.hex ?? "FFFFFF") == h ? 3 : 0))
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
                .padding(.vertical, 3)
            }
            if !style.isDefault {
                Button { style = PostStyle() } label: { Text("Reset style").font(.jk(13, .semibold)).foregroundColor(T.blue) }
            }
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var gifPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(GifLib.all) { g in
                    Button { gif = gif == g.id ? nil : g.id; if gif != nil { snipOn = false } } label: {
                        ZStack {
                            GifView(id: g.id, hue: g.hue, height: 78).allowsHitTesting(false)
                            VStack { Spacer(); Text(g.title).font(.jk(10, .bold)).foregroundColor(.white).shadow(color: .black, radius: 2).padding(.bottom, 4) }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(gif == g.id ? T.blue : Color.clear, lineWidth: 3))
                    }
                }
            }
            if gif != nil {
                TextField("Caption (optional)", text: $gifCaption).field()
                Button { gif = nil } label: { Text("Remove GIF").font(.jk(13, .semibold)).foregroundColor(T.red) }
            }
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var coinPanel: some View {
        let err = coinError
        return VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch a coin with this post", isOn: $coinOn)
                .font(.jk(15, .semibold)).tint(Color(red: 0.45, green: 0.30, blue: 0.95))
                .onChange(of: coinOn) { on in
                    guard on else { return }
                    if coinName.isEmpty {
                        let w = text.split(separator: " ").prefix(2).map(String.init).joined(separator: " ")
                        coinName = w.isEmpty ? "\(game.s.persona.name.components(separatedBy: " ").first ?? "My") Coin" : String(w.prefix(24))
                    }
                    if coinTicker.isEmpty { coinTicker = String(coinName.uppercased().filter { $0.isLetter }.prefix(4)) }
                }
            if coinOn {
                LaunchRocket(ticker: tickerClean.isEmpty ? "TICK" : tickerClean, hue: Double(HK.h(tickerClean) % 360) / 360)
                TextField("Coin name", text: $coinName).field()
                TextField("Ticker (2 to 6)", text: $coinTicker).field().textInputAutocapitalization(.characters)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Mk.symbols, id: \.self) { s in
                            Button { coinSymbol = s } label: {
                                Image(systemName: s).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(coinSymbol == s ? Color(red: 0.45, green: 0.30, blue: 0.95) : T.card2).clipShape(Circle())
                            }
                        }
                    }
                }
                Text("SEED (GEMS)").font(.jk(11, .heavy)).foregroundColor(T.sub)
                HStack(spacing: 8) {
                    ForEach([10, 25, 50, 100], id: \.self) { a in
                        Button { coinSeed = a } label: {
                            Text("\(a)").font(.jk(15, .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(coinSeed == a ? Color(red: 0.45, green: 0.30, blue: 0.95) : T.card2).clipShape(Capsule())
                        }
                    }
                }
                Text("Costs \(coinSeed + Mk.launchFee) gems: \(Mk.launchFee) launch fee plus \(coinSeed) seed. You get the seed back as your position. The coin launches the moment you post.")
                    .font(.jk(12)).foregroundColor(T.sub)
                if let e = err { Text(e).font(.jk(13, .bold)).foregroundColor(T.red) }
            }
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder private var attachments: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let g = gif {
                ZStack(alignment: .topTrailing) {
                    GifView(id: g, caption: gifCaption, hue: GifLib.all.first { $0.id == g }?.hue ?? 0.6, height: 150)
                    Button { gif = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(.white).padding(8)
                    }
                }
            }
            if coinOn && coinError == nil {
                HStack(spacing: 10) {
                    Image(systemName: coinSymbol).foregroundColor(.white).frame(width: 34, height: 34)
                        .background(Color(red: 0.45, green: 0.30, blue: 0.95)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("$\(tickerClean) launches with this post").font(.jk(14, .bold))
                        Text("\(coinSeed + Mk.launchFee) gems").font(.jk(12)).foregroundColor(T.sub)
                    }
                    Spacer()
                    Button { coinOn = false } label: { Image(systemName: "xmark.circle.fill").foregroundColor(T.sub) }
                }
                .padding(10).background(Color(red: 0.45, green: 0.30, blue: 0.95).opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            HStack(spacing: 8) {
                if pollOn && cleanOpts.count >= 2 { attach("Poll · \(cleanOpts.count) options", "chart.bar.fill") { pollOn = false } }
                if gif == nil && snipOn && !snipBody.trimmed.isEmpty { attach(snipTitle.trimmed.isEmpty ? "note.txt" : snipTitle.trimmed, "doc.text.fill") { snipOn = false } }
                Spacer()
            }
        }
    }

    private func attach(_ t: String, _ icon: String, _ remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12))
            Text(t).font(.jk(13, .semibold)).lineLimit(1)
            Button(action: remove) { Image(systemName: "xmark.circle.fill").foregroundColor(T.sub) }
        }
        .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 7).background(T.card2).clipShape(Capsule())
    }

    private var kindRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(kinds) { k in
                    Button { kind = k } label: {
                        Text("\(k.icon) \(k.label)").font(.jk(14, .semibold)).foregroundColor(.white).lineLimit(1)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(kind == k ? T.blue : T.card).clipShape(Capsule())
                    }
                }
            }
            Text(kind.blurb).font(.jk(12)).foregroundColor(T.sub)
        }
    }

    private var toneRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(tones.enumerated()), id: \.offset) { i, n in
                    Button { tone = i } label: {
                        Text(n).font(.jk(14, .semibold)).foregroundColor(tone == i ? .white : T.sub)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(tone == i ? (i == 2 ? T.red : (i == 1 ? T.orange : T.blue)) : Color.clear).clipShape(Capsule())
                    }
                }
            }
            .padding(3).background(T.card).clipShape(Capsule())
            Text(toneNote[tone]).font(.jk(12)).foregroundColor(T.sub)
        }
    }
}

private extension View {
    func field() -> some View {
        self.font(.jk(15)).padding(10).background(Color.black.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 10))
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
                            HStack { SymbolTile(emoji: e.emoji, size: 52); if e.ai { Chip(text: "AI written") }; Spacer() }
                            Text(game.fill(e.text, st)).font(.jk(17, .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.card()
                        ForEach(Array(e.choices.enumerated()), id: \.offset) { i, c in
                            Button { game.choose(i) } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(game.fill(c.text, st)).font(.jk(15, .semibold))
                                        .foregroundColor(.white).multilineTextAlignment(.leading)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            preview("Aura \(c.aura >= 0 ? "+" : "")\(c.aura)", c.aura >= 0 ? T.lime : T.red)
                                            preview("Followers \(c.fol >= 0 ? "+" : "")\(Int(c.fol))%", c.fol >= 0 ? T.lime : T.red)
                                            ForEach(Array(c.stats.enumerated()), id: \.offset) { _, d in
                                                preview("\(d.kind.label) \(d.v >= 0 ? "↑" : "↓")", d.v >= 0 ? T.blue : T.orange)
                                            }
                                            ForEach(Array(c.npc.enumerated()), id: \.offset) { _, d in
                                                preview("\(d.trait.rawValue.capitalized)s \(d.d >= 0 ? "↑" : "↓")", d.d >= 0 ? T.gold : T.red)
                                            }
                                            if c.aura < 0 { preview("Risky", T.red) }
                                        }
                                    }
                                }
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(LinearGradient(colors: [T.card2, Color.black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.blue.opacity(0.35), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    } else {
                        ProgressView().padding(40)
                    }
                }
                .padding(16)
            }
            .background(LinearGradient(colors: [Color(red: 0.03, green: 0.06, blue: 0.12), T.bg], startPoint: .top, endPoint: .bottom))
            .navigationTitle("Event").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear { game.ensureEvent() }
        }
    }

    private func preview(_ t: String, _ c: Color) -> some View {
        Text(t).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(c)
            .padding(.horizontal, 8).padding(.vertical, 4).background(c.opacity(0.15)).clipShape(Capsule())
    }

    @ViewBuilder
    private func resultCard(_ r: ResultRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { SymbolTile(emoji: r.emoji, size: 52); Spacer() }
            Text(r.text).font(.jk(16))
            if r.cancelled { Text("Cancelled. Lost 30% of followers.").font(.jk(14, .bold)).foregroundColor(T.red) }
            if r.iconUnlocked { Text("Icon status! +20% followers.").font(.jk(14, .bold)).foregroundColor(T.gold) }
            HStack {
                Chip(text: "Aura \(r.auraDelta >= 0 ? "+" : "")\(r.auraDelta)%", color: r.auraDelta >= 0 ? T.lime.opacity(0.35) : T.red.opacity(0.4))
                Chip(text: "\(r.followerDelta >= 0 ? "+" : "")\(short(r.followerDelta)) followers")
            }
            if !r.stats.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(r.stats) { c in Chip(text: "\(c.kind.label) \(c.up ? "↑" : "↓")") }
                }
            }
            if !r.npcs.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(r.npcs.prefix(8)) { n in Chip(text: "\(n.up ? "↑" : "↓") @\(n.handle)") }
                }
                if r.npcs.count > 8 {
                    Text("+\(r.npcs.count - 8) more characters reacted").font(.jk(12)).foregroundColor(T.sub)
                }
            }
        }.card()
        BigButton(title: "Continue to next day") {
            game.continueStory()
            dismiss()
        }
    }
}
