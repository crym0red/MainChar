import SwiftUI

// MARK: - Goals

struct GoalsTab: View {
    @EnvironmentObject var game: Game
    @State private var compose: ComposeSeed? = nil
    @State private var customize = false
    @State private var showLog = false
    @State private var showStore = false
    @State private var how = false

    var body: some View {
        let st = game.s
        let need = Game.xpNeed(st.level)
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header(st, need, proxy)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        mainGoal(st)
                        milestones(st)
                        quests(st)
                        skills(st).id("skills")
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 40)
                }
            }
        }
        .background(T.bg)
        .sheet(item: $compose) { ComposeSheet(seed: $0) }
        .sheet(isPresented: $customize) { CustomizeWorldSheet() }
        .fullScreenCover(isPresented: $showLog) { ActivityLogView() }
        .fullScreenCover(isPresented: $showStore) { StoreView() }
        .alert("How does this work?", isPresented: $how) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Posts, stories and events earn XP. Each level gives skill points, bonus energy and gems. Spend points on skills to unlock milestones and push your main goal forward.")
        }
    }

    // MARK: Header

    private func octoPlus(enabled: Bool = true, size: CGFloat = 52, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "octagon.fill").font(.system(size: size))
                    .foregroundColor(enabled ? T.orange : Color.white.opacity(0.14))
                Image(systemName: "plus").font(.system(size: size * 0.42, weight: .bold)).foregroundColor(.white)
            }
        }
        .disabled(!enabled)
    }

    private func squareButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(.white)
                .frame(width: 60, height: 60).background(T.card2)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func header(_ st: GameState, _ need: Int, _ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Lvl \(st.level)").font(.jk(27, .semibold))
                Bar(value: Double(st.xp) / Double(max(1, need)), color: T.gold, height: 26).frame(width: 130)
                Text("\(st.xp)/\(need) XP").font(.jk(19, .medium)).foregroundColor(T.gold)
                octoPlus(size: 46) { withAnimation { proxy.scrollTo("skills", anchor: .top) } }
                Spacer(minLength: 0)
                squareButton("book.closed.fill") { showLog = true }
                squareButton("storefront.fill") { showStore = true }
            }
            Button { how = true } label: {
                HStack(spacing: 8) {
                    Text("How does this work?").font(.jk(18)).foregroundColor(T.sub)
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 22)).foregroundColor(T.sub)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
    }

    // MARK: Panels

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1.5))
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.jk(26, .medium)).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func needed(_ n: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill").rotationEffect(.degrees(-20))
            Text("+\(n) Needed")
        }
        .font(.jk(20, .medium)).foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.05))
    }

    // MARK: Main goal

    private func mainGoal(_ st: GameState) -> some View {
        let p = game.goalProgress
        let desc = st.world.setting.isEmpty ? st.world.tagline : st.world.setting
        return VStack(alignment: .leading, spacing: 12) {
            title("Main goal")
            panel {
                VStack(alignment: .leading, spacing: 16) {
                    Text(st.world.goal).font(.jk(26, .semibold))
                    HStack(spacing: 14) {
                        Bar(value: max(0.03, p), color: T.blue, height: 22)
                        Text("\(Int(p * 100))%").font(.jk(19, .medium)).foregroundColor(T.sub)
                    }
                    if !desc.isEmpty {
                        Text(desc).font(.jk(20)).foregroundColor(Color.white.opacity(0.88)).lineLimit(3)
                    }
                    Button { customize = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe.europe.africa.fill")
                            Text("Customize World")
                        }
                        .font(.jk(24, .medium)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(Color.white.opacity(0.22)).clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: Milestones

    private func node(_ i: Int, _ m: Milestone, _ n: Int) -> some View {
        let reached = m.done || m.skipped
        let diamond = i == 0 || i == n - 1
        let d: CGFloat = n > 6 ? 40 : 50
        return ZStack {
            if diamond {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(reached ? T.blue : T.card2)
                    .frame(width: d * 0.78, height: d * 0.78).rotationEffect(.degrees(45))
                Image(systemName: reached ? "checkmark" : "person.badge.plus.fill")
                    .font(.system(size: d * 0.34, weight: .bold)).foregroundColor(.white)
            } else {
                Circle().fill(reached ? T.blue : T.card2).frame(width: d, height: d)
                if reached {
                    Image(systemName: "checkmark").font(.system(size: d * 0.34, weight: .bold)).foregroundColor(.white)
                } else {
                    Text("\(i + 1)").font(.jk(d * 0.42, .medium)).foregroundColor(Color.white.opacity(0.85))
                }
            }
        }
        .frame(width: d + 6, height: d + 6)
    }

    private func milestones(_ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Milestones")
            HStack(spacing: 0) {
                ForEach(Array(st.milestones.enumerated()), id: \.element.id) { i, m in
                    node(i, m, st.milestones.count)
                    if i < st.milestones.count - 1 {
                        Capsule().fill(m.done || m.skipped ? T.blue : Color.white.opacity(0.14)).frame(height: 14)
                    }
                }
            }
            title("Next Milestone").padding(.top, 6)
            if let m = game.nextMilestone {
                nextCard(m, st)
            } else {
                panel { Text("All milestones complete. 🎉").font(.jk(20, .semibold)) }
            }
        }
    }

    private func nextCard(_ m: Milestone, _ st: GameState) -> some View {
        let ok = game.canClaim(m, st)
        let cost = game.pointsNeeded(m, st)
        let afford = cost <= st.points
        let usable = ok || afford
        return panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(m.text).font(.jk(26, .semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "star").font(.system(size: 22)).foregroundColor(T.sub)
                }
                .padding(.bottom, 16)
                ForEach(Array(m.reqs.enumerated()), id: \.offset) { _, r in
                    if st.skills.indices.contains(r.skill) {
                        let have = st.skills[r.skill].value
                        let miss = max(0, r.level - have)
                        Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1)
                        HStack {
                            Text(st.skills[r.skill].name).font(.jk(22))
                            Spacer()
                            if miss > 0 { needed(miss) }
                            else { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundColor(T.lime) }
                        }
                        .padding(.vertical, 16)
                    }
                }
                Button {
                    if ok { game.claim(m.id) } else { game.claimWithPoints(m.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: usable ? "lock.open" : "lock")
                        Text(ok ? "Claim" : "Claim with points")
                    }
                    .font(.jk(24, .medium)).foregroundColor(usable ? .white : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(usable ? T.blue : Color.white.opacity(0.14)).clipShape(Capsule())
                }
                .disabled(!usable)
                .padding(.top, 10)
                Button { game.skip(m.id) } label: {
                    Text("Skip milestone").font(.jk(22)).foregroundColor(T.sub)
                        .frame(maxWidth: .infinity).padding(.top, 20).padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: Side quests

    private func quests(_ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Side quests")
            panel {
                VStack(spacing: 0) {
                    ForEach(Array(st.quests.enumerated()), id: \.element.id) { i, q in
                        Button {
                            if !q.done { compose = ComposeSeed(text: "", quest: q.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    if q.done {
                                        Circle().fill(T.blue)
                                        Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                                    } else {
                                        Circle().stroke(Color.white.opacity(0.22), lineWidth: 3)
                                    }
                                }
                                .frame(width: 46, height: 46)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(q.text).font(.jk(22)).foregroundColor(.white).multilineTextAlignment(.leading)
                                    if !q.done {
                                        Text("+\(q.xp) XP").font(.jk(19, .medium)).foregroundColor(T.gold)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "star").font(.system(size: 22)).foregroundColor(T.sub)
                            }
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        if i < st.quests.count - 1 { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1) }
                    }
                }
            }
            .padding(.horizontal, -6)
        }
    }

    // MARK: Skills

    private func skills(_ st: GameState) -> some View {
        let m = game.nextMilestone
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skills").font(.jk(26, .medium))
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill").rotationEffect(.degrees(-20))
                    Text("\(st.points) Points to use")
                }
                .font(.jk(21, .semibold)).foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.05))
            }
            panel {
                VStack(spacing: 0) {
                    ForEach(Array(st.skills.enumerated()), id: \.element.id) { i, sk in
                        let miss: Int = {
                            guard let m = m else { return 0 }
                            return m.reqs.filter { $0.skill == i }.map { max(0, $0.level - sk.value) }.reduce(0, +)
                        }()
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(sk.name).font(.jk(26, .medium))
                                Spacer(minLength: 6)
                                if miss > 0 { needed(miss) }
                                Color.clear.frame(width: 62, height: 1)
                            }
                            HStack(spacing: 12) {
                                Bar(value: Double(sk.value) / 100, color: T.blue, height: 22)
                                Text("\(sk.value)/100").font(.jk(22, .medium)).frame(width: 82, alignment: .trailing)
                                octoPlus(enabled: st.points > 0, size: 50) { game.upgrade(sk.id) }
                            }
                            Text(sk.desc).font(.jk(19)).foregroundColor(T.sub)
                        }
                        .padding(.vertical, 18)
                        if i < st.skills.count - 1 { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1) }
                    }
                }
            }
        }
    }
}

// MARK: - Messages

struct MessagesTab: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var path: [String] = []
    @State private var newChat = false

    var body: some View {
        let st = game.s
        let handles = st.threads.keys.sorted { a, b in
            (st.threads[a]?.isEmpty ?? true ? 1 : 0) < (st.threads[b]?.isEmpty ?? true ? 1 : 0)
        }
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    if handles.isEmpty {
                        EmptyState(emoji: "💬", title: "No messages yet", detail: "Tap + to start a conversation with someone in your world.")
                            .padding(.top, 80)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(handles, id: \.self) { h in
                                if let n = st.npcs.first(where: { $0.handle == h }) {
                                    NavigationLink(value: h) {
                                        HStack(spacing: 12) {
                                            Avatar(emoji: n.emoji, key: n.handle, size: 50)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(n.name).font(.jk(15, .bold)).foregroundColor(.white)
                                                Text(st.threads[h]?.last?.text ?? "Say hi")
                                                    .font(.jk(13)).foregroundColor(T.sub).lineLimit(1)
                                            }
                                            Spacer()
                                            if st.unread.contains(h) { Circle().fill(T.blue).frame(width: 10, height: 10) }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                    }
                                }
                            }
                        }
                    }
                }
                Button { newChat = true } label: {
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        .frame(width: 58, height: 58).background(T.blue).clipShape(Circle())
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }.padding(20)
            }
            .background(T.bg)
            .navigationTitle("Messages")
            .navigationDestination(for: String.self) { ChatView(handle: $0) }
            .sheet(isPresented: $newChat) {
                NewChatSheet { h in
                    game.startChat(h)
                    path = [h]
                }
            }
        }
        .onChange(of: nav.chat) { h in
            if let h = h { path = [h]; nav.chat = nil }
        }
        .onAppear {
            if let h = nav.chat { path = [h]; nav.chat = nil }
        }
    }
}

struct NewChatSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    var pick: (String) -> Void

    var body: some View {
        NavigationStack {
            List(game.s.npcs.filter { $0.id != "newsdesk" }) { n in
                Button {
                    dismiss()
                    pick(n.handle)
                } label: {
                    HStack(spacing: 12) {
                        Avatar(emoji: n.emoji, key: n.handle, size: 42)
                        VStack(alignment: .leading) {
                            Text(n.name).font(.jk(15, .bold)).foregroundColor(.white)
                            Text("@\(n.handle) · \(n.trait.rawValue)").font(.jk(12)).foregroundColor(T.sub)
                        }
                    }
                }
                .listRowBackground(T.card)
            }
            .scrollContentBackground(.hidden)
            .background(T.bg)
            .navigationTitle("New chat").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct ChatView: View {
    @EnvironmentObject var game: Game
    let handle: String
    @State private var text = ""

    var body: some View {
        let st = game.s
        let npc = st.npcs.first { $0.handle == handle }
        let msgs = st.threads[handle] ?? []
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if msgs.isEmpty {
                            Text("Say hi to \(npc?.name ?? handle)").font(.jk(13)).foregroundColor(T.sub).padding(.top, 30)
                        }
                        ForEach(msgs) { m in
                            HStack {
                                if m.fromYou { Spacer(minLength: 50) }
                                Text(m.text).font(.jk(15))
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(m.fromYou ? T.blue : T.card2)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                if !m.fromYou { Spacer(minLength: 50) }
                            }.id(m.id)
                        }
                        if game.typing.contains(handle) {
                            HStack {
                                Text("typing…").font(.jk(13)).foregroundColor(T.sub)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 18))
                                Spacer()
                            }.id("typing")
                        }
                    }.padding(16)
                }
                .onChange(of: msgs.count) { _ in
                    withAnimation { if let l = msgs.last { proxy.scrollTo(l.id, anchor: .bottom) } }
                }
                .onChange(of: game.typing) { _ in
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
            HStack {
                TextField("Message…", text: $text).padding(10).background(T.card).clipShape(Capsule())
                Button {
                    game.sendDM(handle: handle, text: text); text = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                        .foregroundColor(text.trimmed.isEmpty || game.typing.contains(handle) ? T.sub : T.blue)
                }.disabled(text.trimmed.isEmpty || game.typing.contains(handle))
            }.padding(12)
        }
        .background(T.bg)
        .navigationTitle(npc?.name ?? handle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { game.openChat = handle; game.markChatRead(handle) }
        .onDisappear { game.openChat = nil }
    }
}

// MARK: - Notifications

struct NotifsTab: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var openStory: StoryOpen? = nil

    var body: some View {
        let st = game.s
        VStack(spacing: 0) {
            Text("Notifications").font(.jk(30, .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            ScrollView {
                if st.notifs.isEmpty {
                    EmptyState(emoji: "🔔", title: "Nothing yet", detail: "Followers, replies and milestones show up here.")
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(st.notifs) { n in
                            row(n, st)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                        Text("That's everything!").font(.jk(18)).foregroundColor(T.sub)
                            .padding(.vertical, 40)
                    }
                }
            }
        }
        .background(T.bg)
        .onDisappear { game.markNotifsRead() }
        .fullScreenCover(item: $openStory) { o in StoriesFlow(openStory: o.story) }
    }

    @ViewBuilder
    private func icon(_ n: Notif) -> some View {
        switch n.kind {
        case "reply", "story":
            Image(systemName: "arrowshape.turn.up.right.fill").font(.system(size: 28)).foregroundColor(T.blue)
        case "follow":
            Image(systemName: "person.fill").font(.system(size: 28)).foregroundColor(T.blue)
        case "level":
            Image(systemName: "star.fill").font(.system(size: 28)).foregroundColor(T.gold)
        case "milestone":
            Image(systemName: "flag.fill").font(.system(size: 26)).foregroundColor(T.lime)
        default:
            Text(n.emoji).font(.jk(28))
        }
    }

    @ViewBuilder
    private func subLine(_ n: Notif, _ npc: NPC?) -> some View {
        if n.kind == "follow" {
            let bio = npc?.bio ?? n.sub
            if !bio.isEmpty {
                Text(bio).font(.jk(20)).foregroundColor(T.sub).lineLimit(3)
            }
        } else if n.kind == "reply", let r = n.sub.range(of: ": ") {
            let who = String(n.sub[n.sub.startIndex..<r.lowerBound])
            let rest = String(n.sub[r.upperBound...])
            (Text(who).foregroundColor(T.blue) + Text(": \(rest)").foregroundColor(T.sub))
                .font(.jk(21)).lineLimit(2)
        } else if !n.sub.isEmpty {
            Text(n.sub).font(.jk(20)).foregroundColor(T.sub).lineLimit(3)
        }
    }

    private func row(_ n: Notif, _ st: GameState) -> some View {
        let npc = st.npcs.first { $0.handle == n.handle }
        let story = n.kind == "story" ? st.ex.stories.first(where: { $0.id == n.ref }) : nil
        return HStack(alignment: .top, spacing: 16) {
            icon(n).frame(width: 40, alignment: .center).padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                if n.kind == "follow" && !n.handle.isEmpty {
                    Avatar(emoji: n.emoji, key: n.handle, size: 76)
                }
                (Text(n.text).foregroundColor(.white) + Text(" · Day \(n.day)").foregroundColor(T.sub))
                    .font(.jk(23, .medium))
                subLine(n, npc)
                if n.kind == "follow" && !n.handle.isEmpty {
                    Button {
                        game.startChat(n.handle)
                        nav.chat = n.handle
                        nav.tab = 2
                    } label: {
                        Text("Message").font(.jk(23, .medium)).foregroundColor(.white)
                            .padding(.horizontal, 36).padding(.vertical, 16)
                            .background(T.card2).clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 8)
            if let s = story {
                ZStack(alignment: .topTrailing) {
                    StoryThumb(story: s, width: 84, height: 108)
                    Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(.white)
                        .frame(width: 30, height: 30).background(T.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(6)
                }
            } else if n.unread {
                Circle().fill(T.blue).frame(width: 10, height: 10).padding(.top, 10)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .contentShape(Rectangle())
        .onTapGesture {
            if n.kind == "story", let id = n.ref { openStory = StoryOpen(story: id) }
        }
    }
}

// MARK: - Profile

struct ProfileTab: View {
    @EnvironmentObject var game: Game
    @State private var seg = 0
    @State private var edit = false
    @State private var customize = false
    @State private var settings = false
    @State private var showLog = false
    @State private var showStore = false
    @State private var npcSheet: NPC? = nil
    @State private var openStory: StoryOpen? = nil
    @State private var allStories = false
    @State private var showHistory = false
    @State private var unlockInfo = false
    @State private var scrolled = false

    var body: some View {
        let st = game.s
        let p = st.persona
        GeometryReader { geo in
        ZStack(alignment: .top) {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { g in
                    Color.clear.preference(key: ProfileScrollKey.self, value: g.frame(in: .named("profile")).minY)
                }
                .frame(height: 0)
                ZStack(alignment: .topTrailing) {
                    ProfileBanner().id(game.profileRev)
                    HStack(spacing: 10) {
                        topButton("storefront.fill") { showStore = true }
                        topButton("gearshape.fill") { settings = true }
                    }
                    .padding(.trailing, 16).padding(.top, 58)
                }
                .frame(height: 200)

                HStack(alignment: .top) {
                    Avatar(emoji: p.emoji, key: p.handle, size: 150)
                        .id(game.profileRev)
                        .overlay(Circle().stroke(T.bg, lineWidth: 6))
                        .offset(y: -75)
                    Spacer()
                    Button { edit = true } label: {
                        Text("Edit Profile").font(.jk(22, .medium)).foregroundColor(.white)
                            .padding(.horizontal, 30).padding(.vertical, 18)
                            .background(T.card2).clipShape(Capsule())
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 16)
                .frame(height: 75, alignment: .top)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(p.name).font(.jk(34, .bold))
                        if st.followers >= 10000 { VerifiedSeal(size: 28) }
                    }
                    Text("@\(p.handle)").font(.jk(22)).foregroundColor(T.sub)
                    if !p.bio.isEmpty { Text(p.bio).font(.jk(23)).padding(.top, 4) }
                    (Text(short(st.followers)).fontWeight(.semibold).foregroundColor(.white)
                        + Text(" Followers").foregroundColor(T.sub))
                        .font(.jk(25)).padding(.top, 6)
                }
                .padding(.horizontal, 16).padding(.top, 14)

                VStack(spacing: 12) {
                    wideButton("globe.europe.africa.fill", "Customize World") { customize = true }
                    wideButton("book.closed.fill", "Activity Log") { showLog = true }
                }
                .padding(.horizontal, 16).padding(.top, 18)

                tabs.padding(.top, 20)

                Group {
                    if seg == 0 { overview(st) }
                    else if seg == 1 { posts(st) }
                    else { activities(st) }
                }
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 40)
            }
        }
        .coordinateSpace(name: "profile")
        .onPreferenceChange(ProfileScrollKey.self) { scrolled = $0 < -120 }
        .ignoresSafeArea(edges: .top)
        VStack(spacing: 0) {
            T.bg.frame(height: geo.safeAreaInsets.top).opacity(scrolled ? 1 : 0)
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        }
        }
        .background(T.bg)
        .fullScreenCover(isPresented: $edit) { EditProfileSheet() }
        .sheet(isPresented: $customize) { CustomizeWorldSheet() }
        .fullScreenCover(isPresented: $settings) { GameSettingsView() }
        .sheet(item: $npcSheet) { NPCSheet(npc: $0) }
        .fullScreenCover(item: $openStory) { o in StoriesFlow(openStory: o.story) }
        .fullScreenCover(isPresented: $allStories) { AllStoriesSheet() }
        .fullScreenCover(isPresented: $showHistory) { WorldHistoryView() }
        .alert("More characters", isPresented: $unlockInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Characters warm up to you as you post, reply, message them and send gifts. Once they follow you they show up here.")
        }
        .fullScreenCover(isPresented: $showLog) { ActivityLogView() }
        .fullScreenCover(isPresented: $showStore) { StoreView() }
    }

    private func topButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(.white)
                .frame(width: 68, height: 58).background(Color.black.opacity(0.55)).clipShape(Capsule())
        }
    }

    private func wideButton(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.jk(24, .medium)).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(T.card2).clipShape(Capsule())
        }
    }

    private var tabs: some View {
        let names = ["Overview", "Posts", "Activities"]
        return HStack(spacing: 0) {
            ForEach(Array(names.enumerated()), id: \.offset) { i, n in
                Button { seg = i } label: {
                    VStack(spacing: 14) {
                        Text(n).font(.jk(23, .medium)).foregroundColor(seg == i ? T.blue : T.sub)
                        Rectangle().fill(seg == i ? T.blue : Color.clear).frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
    }

    // MARK: Overview

    private func presenceRow(emoji: String, name: String, value: Int, delta: Int, note: String?) -> some View {
        let v = max(0, min(100, value))
        let prev = max(0, min(100, value - delta))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(emoji).font(.jk(32))
                Text(name).font(.jk(26, .medium)).padding(.top, 2)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if delta != 0 {
                        Text(String(format: "%+.1f%%", Double(delta)))
                            .font(.jk(22, .semibold))
                            .foregroundColor(delta > 0 ? T.lime : T.orange)
                    }
                    Text(String(format: "%.1f%%", Double(v))).font(.jk(24, .medium))
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(Color.white.opacity(0.18)).frame(width: g.size.width * CGFloat(v) / 100)
                    if delta != 0 {
                        Capsule().fill(T.gold).frame(width: 6, height: 28)
                            .offset(x: max(0, g.size.width * CGFloat(prev) / 100 - 3))
                    }
                }
            }
            .frame(height: 28)
            if let n = note, !n.isEmpty {
                Text(n).font(.jk(21)).foregroundColor(T.sub)
            }
        }
    }

    private func overview(_ st: GameState) -> some View {
        let auraNote = st.log.first { $0.kind == "outcome" && $0.title == "Aura" }?.body
        func stat(_ k: StatKind) -> some View {
            presenceRow(emoji: k.emoji, name: k.label, value: st.stats[k.rawValue] ?? 30,
                        delta: st.ex.statDelta[k.rawValue] ?? 0, note: st.ex.statNote[k.rawValue])
        }
        return VStack(alignment: .leading, spacing: 18) {
            Text("Social Media Presence").font(.jk(26, .medium))
            VStack(alignment: .leading, spacing: 0) {
                stat(.humor).padding(.vertical, 16)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                presenceRow(emoji: "🌟", name: "Aura", value: st.aura, delta: st.lastAuraDelta, note: auraNote)
                    .padding(.vertical, 16)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                stat(.charm).padding(.vertical, 16)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                stat(.edge).padding(.vertical, 16)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                stat(.mystery).padding(.vertical, 16)
            }
            .padding(.horizontal, 20)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1.5))

            relationships(st)

            VStack(alignment: .leading, spacing: 10) {
                Text("Achievements").font(.jk(22, .medium))
                ForEach(Game.badgeDefs) { b in
                    let got = st.achievements.contains(b.id)
                    HStack {
                        Text(b.emoji).opacity(got ? 1 : 0.3)
                        Text(b.title).foregroundColor(got ? .white : T.sub)
                        Spacer()
                        if got { Image(systemName: "checkmark.circle.fill").foregroundColor(T.lime) }
                    }.font(.system(size: 19))
                }
            }.card()
        }
    }

    private func relNote(_ n: NPC) -> String {
        if n.affinity >= 70 { return "They're basically your biggest fan." }
        if n.affinity >= 40 { return "They like where this is going." }
        return "They're still making up their mind about you."
    }

    private func relationships(_ st: GameState) -> some View {
        let rels = st.npcs.filter { $0.id != "newsdesk" && ($0.followsYou || $0.affinity >= 35) }
        return VStack(alignment: .leading, spacing: 14) {
            Button { showHistory = true } label: {
                HStack {
                    Text("🌍").font(.jk(24))
                    Text("World History").font(.jk(17, .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(T.sub)
                }
                .padding(14).background(RoundedRectangle(cornerRadius: 16).fill(T.card))
            }.buttonStyle(.plain)
            Text("Relationships (\(rels.count))").font(.jk(26, .medium)).padding(.top, 6)
            ForEach(rels) { n in
                Button { npcSheet = n } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Avatar(emoji: n.emoji, key: n.handle, size: 76)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(n.name).font(.jk(25, .semibold)).foregroundColor(.white)
                                    if n.followers >= 40000 { VerifiedSeal(size: 20) }
                                }
                                Text("@\(n.handle)").font(.jk(20)).foregroundColor(T.sub)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 20, weight: .semibold)).foregroundColor(T.sub)
                        }
                        HStack(spacing: 14) {
                            Bar(value: Double(n.affinity) / 100, color: T.lime, height: 24)
                            Text("\(n.affinity)%").font(.jk(22, .medium)).foregroundColor(.white)
                                .frame(width: 70, alignment: .trailing)
                        }
                        Text(relNote(n)).font(.jk(20)).foregroundColor(T.sub).multilineTextAlignment(.leading)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(T.card)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Button { unlockInfo = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 24))
                    Text("How do I unlock more characters?").font(.jk(19))
                }
                .foregroundColor(T.sub)
            }
        }
    }

    private func posts(_ st: GameState) -> some View {
        let mine = st.posts.filter { $0.isYou }
        let stories = st.ex.stories
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Stories").font(.jk(26, .medium))
                Spacer()
                Button { allStories = true } label: {
                    Text("View all").font(.jk(22, .medium)).foregroundColor(T.blue)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if stories.isEmpty {
                        Text("No stories yet. Tap Add story on the feed.").font(.jk(18)).foregroundColor(T.sub)
                            .padding(.vertical, 40)
                    }
                    ForEach(stories.prefix(10)) { s in
                        Button { openStory = StoryOpen(story: s.id) } label: {
                            ZStack(alignment: .bottomLeading) {
                                StoryThumb(story: s, width: 120, height: 190)
                                Text(s.text).font(.jk(16)).foregroundColor(.white).lineLimit(1)
                                    .padding(10).frame(width: 120, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1.5))

            Text("Your Posts").font(.jk(26, .medium)).padding(.top, 6)
            if mine.isEmpty { EmptyState(emoji: "✍️", title: "No posts yet", detail: "Tap the compose button on the Feed.") }
            ForEach(mine) { p in
                PostRow(post: p, onReply: {}, onOpen: {}).padding(.horizontal, -16)
                Divider().background(Color.white.opacity(0.08))
            }
        }
    }

    private func activities(_ st: GameState) -> some View {
        let acts = st.log.filter { ($0.kind ?? "activity") == "activity" }
        return VStack(spacing: 8) {
            if acts.isEmpty { EmptyState(emoji: "📜", title: "Nothing yet", detail: "Your activity fills up as you play.") }
            ForEach(acts) { l in
                HStack(alignment: .top, spacing: 10) {
                    Text(l.emoji).font(.jk(22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.title).font(.jk(14, .bold))
                        Text(l.detail).font(.jk(12)).foregroundColor(T.sub).lineLimit(2)
                    }
                    Spacer()
                    Text("D\(l.day)").font(.jk(11)).foregroundColor(T.sub)
                }.card(12)
            }
        }
    }
}

struct ProfileScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
