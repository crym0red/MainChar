import SwiftUI

// MARK: - Goals

struct GoalsTab: View {
    @EnvironmentObject var game: Game
    @State private var compose: ComposeSeed? = nil
    @State private var customize = false

    var body: some View {
        let st = game.s
        let need = Game.xpNeed(st.level)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Level header
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(T.blue)
                        Text("\(st.level)").font(.system(size: 20, weight: .heavy))
                    }.frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Lvl \(st.level)").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("\(st.xp)/\(need) XP").font(.system(size: 12, weight: .semibold)).foregroundColor(T.gold)
                        }
                        Bar(value: Double(st.xp) / Double(need), color: T.gold, height: 10)
                    }
                    Chip(text: "⚡ \(st.points)", color: T.orange)
                }.card()

                // Main goal
                VStack(alignment: .leading, spacing: 10) {
                    Text("Main goal").font(.system(size: 13, weight: .bold)).foregroundColor(T.orange)
                    Text(st.world.goal).font(.system(size: 17, weight: .bold))
                    HStack {
                        Bar(value: game.goalProgress, color: T.orange, height: 10)
                        Text("\(Int(game.goalProgress * 100))%").font(.system(size: 13, weight: .bold))
                    }
                    Button { customize = true } label: {
                        Label("Customize World", systemImage: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }.card()

                // Milestones
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Milestones")
                    HStack(spacing: 0) {
                        ForEach(Array(st.milestones.enumerated()), id: \.element.id) { i, m in
                            ZStack {
                                Circle().fill(m.done ? T.lime : (m.skipped ? T.card2 : T.card))
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                if m.done { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.black) }
                                else if m.skipped { Image(systemName: "forward.fill").font(.system(size: 9)).foregroundColor(T.sub) }
                                else { Text("\(i + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(T.sub) }
                            }.frame(width: 26, height: 26)
                            if i < st.milestones.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 2)
                            }
                        }
                    }
                    if let m = game.nextMilestone {
                        let ok = game.canClaim(m, st)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Next milestone").font(.system(size: 12, weight: .bold)).foregroundColor(T.blue)
                            Text(m.text).font(.system(size: 16, weight: .semibold))
                            ForEach(Array(m.reqs.enumerated()), id: \.offset) { _, r in
                                if st.skills.indices.contains(r.skill) {
                                    let have = st.skills[r.skill].value
                                    HStack {
                                        Image(systemName: have >= r.level ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(have >= r.level ? T.lime : T.sub)
                                        Text(st.skills[r.skill].name).font(.system(size: 13))
                                        Spacer()
                                        Text("\(have)/\(r.level)").font(.system(size: 13, weight: .bold))
                                            .foregroundColor(have >= r.level ? T.lime : T.sub)
                                    }
                                }
                            }
                            HStack(spacing: 10) {
                                BigButton(title: "Claim", color: T.lime, enabled: ok, textColor: .black) { game.claim(m.id) }
                                Button { game.skip(m.id) } label: {
                                    Text("Skip").font(.system(size: 15, weight: .semibold)).foregroundColor(T.sub)
                                        .frame(width: 80).padding(.vertical, 15)
                                        .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }.card()
                    } else {
                        Text("All milestones complete. 🎉").font(.system(size: 15, weight: .semibold)).card()
                    }
                }

                // Side quests
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle("Side quests")
                    ForEach(st.quests) { q in
                        Button {
                            if !q.done { compose = ComposeSeed(text: "", quest: q.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: q.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(q.done ? T.lime : T.sub)
                                Text(q.text).font(.system(size: 14)).foregroundColor(q.done ? T.sub : .white)
                                    .strikethrough(q.done).multilineTextAlignment(.leading)
                                Spacer()
                                Chip(text: "+\(q.xp) XP", color: T.gold.opacity(0.25), fg: T.gold)
                            }.card(12)
                        }
                    }
                }

                // Skills
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionTitle("Skills")
                        Text("\(st.points) pts").font(.system(size: 13, weight: .bold)).foregroundColor(T.orange)
                    }
                    ForEach(st.skills) { sk in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sk.name).font(.system(size: 15, weight: .bold))
                                Text(sk.desc).font(.system(size: 12)).foregroundColor(T.sub)
                            }
                            Spacer()
                            Text("\(sk.value)").font(.system(size: 20, weight: .heavy)).foregroundColor(T.blue)
                            Button { game.upgrade(sk.id) } label: {
                                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(st.points > 0 ? T.orange : Color.white.opacity(0.12)).clipShape(Circle())
                            }.disabled(st.points <= 0)
                        }.card(12)
                    }
                }
            }
            .padding(16).padding(.bottom, 30)
        }
        .background(T.bg)
        .sheet(item: $compose) { ComposeSheet(seed: $0) }
        .sheet(isPresented: $customize) { CustomizeWorldSheet() }
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
                                                Text(n.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                                Text(st.threads[h]?.last?.text ?? "Say hi")
                                                    .font(.system(size: 13)).foregroundColor(T.sub).lineLimit(1)
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
                            Text(n.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Text("@\(n.handle) · \(n.trait.rawValue)").font(.system(size: 12)).foregroundColor(T.sub)
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
                            Text("Say hi to \(npc?.name ?? handle)").font(.system(size: 13)).foregroundColor(T.sub).padding(.top, 30)
                        }
                        ForEach(msgs) { m in
                            HStack {
                                if m.fromYou { Spacer(minLength: 50) }
                                Text(m.text).font(.system(size: 15))
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(m.fromYou ? T.blue : T.card2)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                if !m.fromYou { Spacer(minLength: 50) }
                            }.id(m.id)
                        }
                        if game.typing.contains(handle) {
                            HStack {
                                Text("typing…").font(.system(size: 13)).foregroundColor(T.sub)
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

    var body: some View {
        let st = game.s
        NavigationStack {
            ScrollView {
                if st.notifs.isEmpty {
                    EmptyState(emoji: "🔔", title: "Nothing yet", detail: "Followers, replies and milestones show up here.")
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(st.notifs) { n in
                            HStack(alignment: .top, spacing: 12) {
                                Avatar(emoji: n.emoji, key: n.handle.isEmpty ? n.kind : n.handle, size: 44, photo: !n.handle.isEmpty)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(n.text).font(.system(size: 14, weight: .semibold))
                                    if !n.sub.isEmpty { Text(n.sub).font(.system(size: 12)).foregroundColor(T.sub).lineLimit(2) }
                                    Text("Day \(n.day)").font(.system(size: 11)).foregroundColor(T.sub)
                                }
                                Spacer()
                                if n.unread { Circle().fill(T.blue).frame(width: 9, height: 9).padding(.top, 6) }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
            }
            .background(T.bg)
            .navigationTitle("Notifications")
            .onDisappear { game.markNotifsRead() }
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

    var body: some View {
        let st = game.s
        let p = st.persona
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [T.blue, Color(red: 0.15, green: 0.35, blue: 0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 110)
                    Avatar(emoji: p.emoji, key: p.handle, size: 84, ring: false)
                        .overlay(Circle().stroke(T.bg, lineWidth: 4))
                        .offset(x: 16, y: 42)
                }
                .padding(.bottom, 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(p.name).font(.system(size: 22, weight: .heavy))
                        if st.followers >= 10000 { VerifiedSeal(size: 18) }
                    }
                    Text("@\(p.handle) · \(p.vibe.label) \(p.vibe.emoji) · \(st.world.title)")
                        .font(.system(size: 13)).foregroundColor(T.sub)
                    if !p.bio.isEmpty { Text(p.bio).font(.system(size: 14)).padding(.top, 2) }
                    HStack(spacing: 18) {
                        stat(short(st.followers), "Followers")
                        stat("\(st.npcs.filter { $0.followsYou }.count)", "Fans in world")
                        stat("\(st.totalPosts)", "Posts")
                    }.padding(.top, 8)
                }.padding(.horizontal, 16)

                HStack(spacing: 8) {
                    pill("Edit Profile") { edit = true }
                    pill("Customize World") { customize = true }
                    pill("Settings") { settings = true }
                }.padding(.horizontal, 16)

                Picker("", selection: $seg) {
                    Text("Overview").tag(0); Text("Posts").tag(1); Text("Activities").tag(2)
                }.pickerStyle(.segmented).padding(.horizontal, 16)

                Group {
                    if seg == 0 { overview(st) }
                    else if seg == 1 { posts(st) }
                    else { activities(st) }
                }.padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(T.bg)
        .sheet(isPresented: $edit) { EditProfileSheet() }
        .sheet(isPresented: $customize) { CustomizeWorldSheet() }
        .sheet(isPresented: $settings) { SettingsSheet() }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.system(size: 17, weight: .heavy))
            Text(l).font(.system(size: 11)).foregroundColor(T.sub)
        }
    }

    private func pill(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(T.card2).clipShape(Capsule())
        }
    }

    private func presenceRow(_ name: String, _ value: Double, _ color: Color, _ trailing: String, _ tc: Color = T.sub) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(trailing).font(.system(size: 12, weight: .bold)).foregroundColor(tc)
            }
            Bar(value: value, color: color, height: 9)
        }
    }

    private func overview(_ st: GameState) -> some View {
        let mine = st.posts.filter { $0.isYou }.prefix(5)
        let avg = mine.isEmpty ? 0 : Double(mine.map { $0.likes }.reduce(0, +)) / Double(mine.count)
        let eng = min(1, avg / Double(max(st.followers, 100)) * 2)
        let fol = min(1, log10(Double(max(st.followers, 10))) / 7)
        let d = st.lastAuraDelta
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Social Media Presence").font(.system(size: 16, weight: .bold))
                presenceRow("Followers", fol, T.blue, short(st.followers))
                presenceRow("Aura", Double(st.aura) / 100, T.lime,
                            "\(st.aura)%" + (d == 0 ? "" : "  (\(d > 0 ? "+" : "")\(d))"), d >= 0 ? T.lime : T.red)
                presenceRow("Engagement", eng, T.orange, "\(Int(eng * 100))%")
                presenceRow("Influence", min(1, Double(st.level) / 20), T.gold, "Lvl \(st.level)")
            }.card()
            VStack(alignment: .leading, spacing: 10) {
                Text("Personality").font(.system(size: 16, weight: .bold))
                ForEach(StatKind.allCases, id: \.self) { k in
                    presenceRow("\(k.emoji) \(k.label)", Double(st.stats[k.rawValue] ?? 30) / 100, T.blue, "\(st.stats[k.rawValue] ?? 30)")
                }
            }.card()
            VStack(alignment: .leading, spacing: 8) {
                Text("Achievements").font(.system(size: 16, weight: .bold))
                ForEach(Game.badgeDefs) { b in
                    let got = st.achievements.contains(b.id)
                    HStack {
                        Text(b.emoji).opacity(got ? 1 : 0.3)
                        Text(b.title).foregroundColor(got ? .white : T.sub)
                        Spacer()
                        if got { Image(systemName: "checkmark.circle.fill").foregroundColor(T.lime) }
                    }.font(.system(size: 14))
                }
            }.card()
        }
    }

    private func posts(_ st: GameState) -> some View {
        let mine = st.posts.filter { $0.isYou }
        return VStack(spacing: 0) {
            if mine.isEmpty { EmptyState(emoji: "✍️", title: "No posts yet", detail: "Tap the compose button on the Feed.") }
            ForEach(mine) { p in
                PostRow(post: p, onReply: {}, onOpen: {}).padding(.horizontal, -16)
                Divider().background(Color.white.opacity(0.08))
            }
        }
    }

    private func activities(_ st: GameState) -> some View {
        VStack(spacing: 8) {
            if st.log.isEmpty { EmptyState(emoji: "📜", title: "Nothing yet", detail: "Your activity log fills up as you play.") }
            ForEach(st.log) { l in
                HStack(alignment: .top, spacing: 10) {
                    Text(l.emoji).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.title).font(.system(size: 14, weight: .bold))
                        Text(l.detail).font(.system(size: 12)).foregroundColor(T.sub).lineLimit(2)
                    }
                    Spacer()
                    Text("D\(l.day)").font(.system(size: 11)).foregroundColor(T.sub)
                }.card(12)
            }
        }
    }
}

struct EditProfileSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var p = Persona(name: "", handle: "", bio: "", emoji: "🙂", vibe: .clown)
    private let emojis = ["😎", "🤩", "😈", "🥹", "🕶️", "🤡", "👑", "🦄", "🐸", "🔥", "🌸", "👽"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(emojis, id: \.self) { e in
                            Button { p.emoji = e } label: {
                                Text(e).font(.system(size: 28)).padding(6)
                                    .background(p.emoji == e ? T.blue.opacity(0.4) : Color.clear).clipShape(Circle())
                            }.buttonStyle(.plain)
                        } }
                    }
                }
                Section("Name") { TextField("Name", text: $p.name) }
                Section("Bio") { TextField("Bio", text: $p.bio, axis: .vertical).lineLimit(1...3) }
                Section("Vibe") {
                    Picker("Vibe", selection: $p.vibe) {
                        ForEach(Vibe.allCases) { Text("\($0.emoji) \($0.label)").tag($0) }
                    }
                }
            }
            .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { game.updatePersona(p); dismiss() }.disabled(p.name.trimmed.isEmpty)
                }
            }
            .onAppear { p = game.s.persona }
        }
    }
}
