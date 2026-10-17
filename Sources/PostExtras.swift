import SwiftUI

// MARK: - Post attachments

struct MediaCard: View {
    let m: Media
    @State private var open = false
    var body: some View {
        let c = Color(hue: m.hue, saturation: 0.7, brightness: 1)
        let shown: [String] = (open || m.lines.count <= 8) ? m.lines : Array(m.lines.prefix(7))
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: m.kind == "code" ? "chevron.left.forwardslash.chevron.right" : (m.kind == "leak" ? "lock.open.fill" : "chart.bar.fill"))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(c)
                Text(m.title.uppercased()).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(c)
                Spacer()
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, l in
                Text(l).font(.system(size: 14, weight: m.kind == "stats" ? .bold : .regular, design: .monospaced))
                    .foregroundColor(l.hasPrefix("+ ") ? T.lime : (l.hasPrefix("- ") ? T.red : .white))
            }
            if m.lines.count > 8 {
                Button { withAnimation { open.toggle() } } label: {
                    Text(open ? "Collapse file" : "Show full file (\(m.lines.count) lines)").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(c)
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.opacity(0.5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuoteCard: View {
    let q: Quote
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Avatar(emoji: "", key: q.handle, size: 20)
                Text(q.name).font(.jk(14, .bold)).lineLimit(1)
                Text("@\(q.handle)").font(.jk(13)).foregroundColor(T.sub).lineLimit(1)
            }
            Text(q.text).font(.jk(15)).foregroundColor(.white.opacity(0.9))
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

struct PollCard: View {
    @EnvironmentObject var game: Game
    let post: Post
    let poll: Poll
    var body: some View {
        let total = max(1, poll.votes.reduce(0, +))
        VStack(alignment: .leading, spacing: 8) {
            Text(poll.q).font(.jk(16, .bold))
            ForEach(Array(poll.opts.enumerated()), id: \.offset) { i, o in
                Button { game.vote(post.id, i) } label: {
                    ZStack(alignment: .leading) {
                        if poll.mine != nil {
                            GeometryReader { g in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(poll.mine == i ? T.blue.opacity(0.6) : Color.white.opacity(0.12))
                                    .frame(width: g.size.width * CGFloat(poll.votes[i]) / CGFloat(total))
                            }
                        }
                        HStack {
                            Text(o).font(.jk(15, .semibold)).foregroundColor(.white)
                            Spacer()
                            if poll.mine != nil {
                                Text("\(poll.votes[i] * 100 / total)%").font(.jk(14, .bold)).foregroundColor(.white)
                            }
                        }.padding(.horizontal, 12).padding(.vertical, 9)
                    }
                    .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                }.disabled(poll.mine != nil)
            }
            Text("\(short(total)) votes").font(.jk(12)).foregroundColor(T.sub)
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Everything extra that hangs under a post's text: attachments, context chips, thread preview, reactions.
struct PostExtras: View {
    @EnvironmentObject var game: Game
    let post: Post
    var onOpen: () -> Void = {}

    private func chips(_ st: GameState) -> [(String, String, Color)] {
        var out: [(String, String, Color)] = []
        if post.isYou { return out }
        if (st.ex.following ?? []).contains(post.authorHandle) { out.append(("person.fill.checkmark", "Following", T.blue)) }
        if let c = (st.ex.market?.coins ?? []).first(where: { $0.creator == post.authorHandle && !$0.rugged }) {
            out.append(("chart.line.uptrend.xyaxis", "Deployed $\(c.id)", Color(red: 0.45, green: 0.30, blue: 0.95)))
        }
        if let n = st.npcs.first(where: { $0.handle == post.authorHandle }), n.id != "newsdesk", n.affinity < 10 {
            out.append(("bolt.fill", "Rival", T.orange))
        }
        if game.activeFeuds(st).contains(where: { $0.a == post.authorHandle || $0.b == post.authorHandle }) {
            out.append(("flame.fill", "Feud", T.red))
        }
        return out
    }

    var body: some View {
        let st = game.s
        VStack(alignment: .leading, spacing: 8) {
            if let m = post.media { if m.kind == "gif" { GifCard(m: m) } else { MediaCard(m: m) } }
            if let t = post.coin { CoinPostCard(ticker: t) }
            if let q = post.quote { QuoteCard(q: q) }
            if let p = post.poll { PollCard(post: post, poll: p) }
            if !(post.queue ?? []).isEmpty {
                Label("Live: replies arriving", systemImage: "dot.radiowaves.left.and.right").font(.jk(11, .bold)).foregroundColor(T.red)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(T.red.opacity(0.15)).clipShape(Capsule())
            }
            let cs = chips(st)
            if !cs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(cs.enumerated()), id: \.offset) { _, c in
                        Label(c.1, systemImage: c.0).font(.jk(11, .bold)).foregroundColor(c.2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(c.2.opacity(0.15)).clipShape(Capsule())
                    }
                }
            }
            if let r = post.reacts, !r.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(Game.reactionList.enumerated()), id: \.offset) { _, rk in
                        let sym = rk.0, key = rk.1
                        if let n = r[key] {
                            Label("\(n)", systemImage: sym).font(.jk(12, .bold))
                                .foregroundColor(post.myReact == key ? .white : T.sub)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(post.myReact == key ? T.blue.opacity(0.5) : T.card2).clipShape(Capsule())
                        }
                    }
                }
            }
            if post.comments.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(post.comments.prefix(2)) { c in
                        (Text("@\(c.handle) ").foregroundColor(T.blue).fontWeight(.semibold) + Text(c.text).foregroundColor(T.sub))
                            .font(.jk(14)).lineLimit(1)
                    }
                    Button(action: onOpen) {
                        Text("View thread (\(post.comments.count))").font(.jk(13, .semibold)).foregroundColor(T.blue)
                    }
                }
                .padding(.leading, 10)
                .overlay(Rectangle().fill(Color.white.opacity(0.15)).frame(width: 2), alignment: .leading)
            }
        }
    }
}

struct QuoteSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var text = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let p = game.s.posts.first(where: { $0.id == postID }) {
                    QuoteCard(q: Quote(handle: p.authorHandle, name: p.authorName, text: String(p.text.prefix(160))))
                }
                TextField("Add your take", text: $text, axis: .vertical)
                    .lineLimit(3...6).padding(12).background(T.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
            }
            .padding(16).background(T.bg)
            .navigationTitle("Quote").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { game.quotePost(postID, text: text); dismiss() }
                        .disabled(text.trimmed.isEmpty)
                }
            }
        }
    }
}

// MARK: - Community banner and challenges

struct CommunityBanner: View {
    let c: Community
    var body: some View {
        let left = max(0, c.ends.timeIntervalSinceNow)
        HStack(spacing: 12) {
            Image(systemName: c.symbol).font(.system(size: 22, weight: .bold)).foregroundColor(T.gold)
                .frame(width: 40, height: 40).background(T.gold.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(c.title).font(.jk(15, .bold))
                    Spacer()
                    Text(c.done ? "Complete" : "\(Int(left / 3600))h \(Int(left / 60) % 60)m").font(.jk(12, .bold)).foregroundColor(c.done ? T.lime : T.sub)
                }
                Text(c.detail).font(.jk(12)).foregroundColor(T.sub)
                Bar(value: Double(c.progress) / Double(max(1, c.goal)), color: T.gold, height: 6)
            }
            Label("\(c.gems)", systemImage: "diamond.fill").font(.jk(13, .bold)).foregroundColor(T.blue)
        }
        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ChallengesCard: View {
    @EnvironmentObject var game: Game
    var body: some View {
        let ch = game.s.ex.challenges ?? []
        VStack(alignment: .leading, spacing: 10) {
            Text("Challenges").font(.jk(20, .bold))
            ForEach(["Daily", "Weekly"], id: \.self) { title in
                let list = ch.filter { $0.weekly == (title == "Weekly") }
                if !list.isEmpty {
                    Text(title).font(.jk(13, .bold)).foregroundColor(T.sub)
                    ForEach(list) { c in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(c.text).font(.jk(15, .semibold))
                                Bar(value: Double(c.progress) / Double(max(1, c.goal)), color: c.progress >= c.goal ? T.lime : T.blue, height: 6)
                                Text("\(c.progress)/\(c.goal)  ·  \(c.gems) gems  ·  \(c.xp) XP").font(.jk(11)).foregroundColor(T.sub)
                            }
                            if c.claimed {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(T.lime).font(.system(size: 22))
                            } else if c.progress >= c.goal {
                                Button { game.claimChallenge(c.id) } label: {
                                    Text("Claim").font(.jk(13, .bold)).foregroundColor(.black)
                                        .padding(.horizontal, 14).padding(.vertical, 8).background(T.lime).clipShape(Capsule())
                                }
                            }
                        }
                        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .onAppear { game.ensureChallenges() }
    }
}

// MARK: - Profile style

struct ProfileStyleSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let st = game.s
        let cur = st.ex.theme ?? 0
        let badges = (st.ex.lvBadges ?? []).map { $0.name }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Theme").font(.jk(18, .bold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(Themes.all.enumerated()), id: \.offset) { i, t in
                            let locked = st.level < t.level
                            Button {
                                if locked { game.showToast("Unlocks at level \(t.level)") }
                                else { var x = game.s; x.ex.theme = i; game.s = x; game.profileRev += 1 }
                            } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(LinearGradient(colors: [Themes.color(i), T.bg], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(height: 54)
                                        .overlay(Image(systemName: locked ? "lock.fill" : (cur == i ? "checkmark.circle.fill" : "")).foregroundColor(.white))
                                    Text(locked ? "\(t.name) · L\(t.level)" : t.name).font(.jk(13, .semibold)).foregroundColor(locked ? T.sub : .white)
                                }
                                .padding(8).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(cur == i ? T.blue : Color.clear, lineWidth: 2))
                            }
                        }
                    }
                    Text("Title").font(.jk(18, .bold)).padding(.top, 6)
                    Button { var x = game.s; x.ex.title = nil; game.s = x } label: {
                        row("None", st.ex.title == nil)
                    }
                    ForEach(badges, id: \.self) { b in
                        Button { var x = game.s; x.ex.title = b; game.s = x } label: { row(b, st.ex.title == b) }
                    }
                    if badges.isEmpty {
                        Text("Earn level badges to unlock titles.").font(.jk(13)).foregroundColor(T.sub)
                    }
                }.padding(16)
            }
            .background(T.bg)
            .navigationTitle("Profile Style").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func row(_ t: String, _ on: Bool) -> some View {
        HStack {
            Text(t).font(.jk(15, .semibold)).foregroundColor(.white)
            Spacer()
            if on { Image(systemName: "checkmark").foregroundColor(T.blue) }
        }.padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
