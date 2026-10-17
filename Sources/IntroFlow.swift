import SwiftUI

// MARK: - Intro (Day 1 story, skills, first quest)

struct IntroFlow: View {
    @EnvironmentObject var game: Game
    @State private var page = 0

    var body: some View {
        let st = game.s
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                if page == 0 { dayPage(st) } else if page == 1 { skillsPage(st) } else { questPage(st) }
                Spacer()
                BigButton(title: page == 0 ? "Next" : (page == 1 ? "Got it" : "Post!")) {
                    if page < 2 { withAnimation { page += 1 } } else { _ = game.publishIntro() }
                }
                .clipShape(Capsule())
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    private func dayPage(_ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill").font(.system(size: 28)).foregroundColor(T.gold)
                Text("Day 1").font(.jk(24, .bold)).foregroundColor(T.gold)
            }
            Text(st.intro?.story ?? "").font(.jk(22)).lineSpacing(6)
        }
    }

    private func skillsPage(_ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill").font(.system(size: 26)).foregroundColor(T.lime)
                Text("Level these skills up").font(.jk(24, .bold)).foregroundColor(T.lime)
            }
            ForEach(st.skills) { sk in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sk.name).font(.jk(22, .semibold))
                    Text(sk.desc).font(.jk(16)).foregroundColor(T.sub)
                }.card(18)
            }
        }
    }

    private func questPage(_ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "target").font(.system(size: 26)).foregroundColor(T.blue)
                Text("First quest").font(.jk(24, .bold)).foregroundColor(T.blue)
            }
            Text(st.intro?.questText ?? "").font(.jk(22)).lineSpacing(4)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(st.persona.name).font(.jk(20, .bold))
                            VerifiedSeal(size: 18)
                        }
                        Text("@\(st.persona.handle)").font(.jk(15)).foregroundColor(T.sub)
                    }
                }
                Text(st.intro?.questPost ?? "").font(.jk(20)).lineSpacing(4)
            }
            .padding(18)
            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Result card (shown on top of a post you just made)

struct ResultCardView: View {
    let o: Outcome
    var onClose: () -> Void
    @State private var all = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles").foregroundColor(T.gold).font(.system(size: 22))
                Text("+\(o.xp) XP").font(.jk(22, .semibold)).foregroundColor(T.gold)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark").foregroundColor(T.sub).padding(6) }
            }
            Divider().background(Color.white.opacity(0.15))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "flame.fill").font(.system(size: 26)).foregroundColor(T.orange)
                Text("Aura").font(.jk(28, .bold))
                Text("\(o.auraDelta >= 0 ? "+" : "")\(o.auraDelta)%").font(.jk(30, .bold))
                    .foregroundColor(o.auraDelta >= 0 ? Color(red: 0.25, green: 0.85, blue: 0.6) : T.red)
            }
            HStack(spacing: 14) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Rectangle().fill(T.lime).frame(width: 4, height: 20)
                            .offset(x: max(0, min(1, Double(o.auraAfter) / 100)) * (g.size.width - 4))
                    }
                }.frame(height: 22)
                Text("\(o.auraAfter)%").font(.jk(22, .semibold)).frame(width: 70, alignment: .trailing)
            }
            if !o.line.isEmpty { Text(o.line).font(.jk(19)).foregroundColor(.white.opacity(0.75)) }
            HStack(spacing: 22) {
                ForEach(o.ups, id: \.self) { u in
                    Text(u).font(.jk(20, .semibold))
                        .foregroundColor(u.contains("↓") ? T.red : Color(red: 0.25, green: 0.85, blue: 0.6))
                }
            }
            Button { all = true } label: {
                Text("View all changes →").font(.jk(17)).foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.6))
            }
        }
        .padding(20)
        .background(Color(red: 0.04, green: 0.16, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color(red: 0.2, green: 0.75, blue: 0.55).opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
        .alert("All changes", isPresented: $all) { Button("OK", role: .cancel) {} } message: { Text(o.detail) }
    }
}

// MARK: - Post detail

struct PostDetailView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var reply = false

    private var stamp: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a · M/d/yy"
        return f.string(from: Date())
    }

    var body: some View {
        let st = game.s
        let post = st.posts.first { $0.id == postID }
        ZStack(alignment: .top) {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    Spacer()
                    Text("Post").font(.jk(22, .semibold))
                    Spacer()
                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.horizontal, 12)
                ScrollView {
                    if let p = post {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Avatar(emoji: p.emoji, key: p.authorHandle, size: 56)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(p.authorName).font(.jk(22, .bold))
                                        if p.verified { VerifiedSeal(size: 20) }
                                    }
                                    Text("@\(p.authorHandle)").font(.jk(18)).foregroundColor(T.sub)
                                }
                                Spacer()
                            }
                            Text(p.text).font(.jk(26)).lineSpacing(4)
                            HStack(spacing: 6) {
                                Text(stamp).foregroundColor(T.sub)
                                Text("· \(short(p.likes * 12 / 10 + 40)) Views").foregroundColor(.white)
                            }.font(.jk(17))
                            HStack(spacing: 10) {
                                Button { reply = true } label: {
                                    Label("Reply", systemImage: "bubble.left.fill").font(.jk(18, .semibold))
                                        .foregroundColor(.white).padding(.horizontal, 22).padding(.vertical, 12)
                                        .background(T.blue).clipShape(Capsule())
                                }
                                Label("\(short(p.reposts))", systemImage: "arrow.2.squarepath").font(.jk(18))
                                    .foregroundColor(T.sub).padding(.horizontal, 18).padding(.vertical, 12)
                                    .background(T.card2).clipShape(Capsule())
                                Button { game.like(p.id) } label: {
                                    Label(short(p.likes), systemImage: p.liked ? "heart.fill" : "heart").font(.jk(18))
                                        .foregroundColor(p.liked ? T.red : T.sub).padding(.horizontal, 18).padding(.vertical, 12)
                                        .background(T.card2).clipShape(Capsule())
                                }
                            }
                        }
                        .padding(16)
                        Divider().background(Color.white.opacity(0.12))
                        if p.comments.isEmpty {
                            Text("No replies yet.").foregroundColor(T.sub).padding(24)
                        }
                        ForEach(p.comments) { c in
                            HStack(alignment: .top, spacing: 12) {
                                Avatar(emoji: c.emoji, key: c.handle, size: 52)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(c.name).font(.jk(18, .bold)).lineLimit(1)
                                        if c.verified { VerifiedSeal(size: 16) }
                                        Text("@\(c.handle)").font(.jk(16)).foregroundColor(T.sub).lineLimit(1)
                                    }
                                    mentionText(c.text).font(.jk(19)).fixedSize(horizontal: false, vertical: true)
                                    HStack(spacing: 14) {
                                        Label("\(short(stableNum(c.handle + c.text, 20, 900)))", systemImage: "heart")
                                        Text("|").foregroundColor(Color.white.opacity(0.2))
                                        Button { reply = true } label: { Text("Reply") }
                                        Spacer()
                                        Image(systemName: "star")
                                    }.font(.system(size: 17)).foregroundColor(T.sub)
                                }
                            }
                            .padding(16)
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            if let r = game.pendingResult, r.postID == postID {
                ResultCardView(o: r) { game.pendingResult = nil }
                    .padding(.horizontal, 12).padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $reply) { ReplySheet(postID: postID).zoomed() }
        .onDisappear { game.pendingResult = nil }
    }
}

// MARK: - Explore

struct ExploreSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var pick: NPC? = nil

    var body: some View {
        NavigationStack {
            List(game.s.npcs.filter { $0.id != "newsdesk" }) { n in
                Button { pick = n } label: {
                    HStack(spacing: 12) {
                        Avatar(emoji: n.emoji, key: n.handle, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.name).font(.jk(16, .bold)).foregroundColor(.white)
                            Text(n.bio).font(.jk(13)).foregroundColor(T.sub).lineLimit(2)
                        }
                        Spacer()
                        Text(short(n.followers)).font(.jk(13, .semibold)).foregroundColor(T.blue)
                    }
                }.listRowBackground(T.card)
            }
            .scrollContentBackground(.hidden)
            .background(T.bg)
            .navigationTitle("Explore").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $pick) { NPCSheet(npc: $0).zoomed() }
        }
    }
}
