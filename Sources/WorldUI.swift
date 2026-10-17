import SwiftUI

func agoString(_ d: Date?) -> String {
    guard let d = d else { return "" }
    let m = max(0, Int(Date().timeIntervalSince(d) / 60))
    if m < 2 { return "just now" }
    if m < 60 { return "\(m)m ago" }
    if m < 60 * 24 { return "\(m / 60)h ago" }
    return "\(m / 1440)d ago"
}

struct AvatarStack: View {
    @EnvironmentObject var game: Game
    let handles: [String]
    var size: CGFloat = 34

    var body: some View {
        let npcs = game.s.npcs
        HStack(spacing: -size * 0.3) {
            ForEach(Array(handles.prefix(3).enumerated()), id: \.offset) { _, h in
                let n = npcs.first { $0.handle == h }
                Avatar(emoji: n?.emoji ?? "👤", key: h, size: size)
                    .overlay(Circle().stroke(T.bg, lineWidth: 2))
            }
        }
    }
}

// MARK: - "While you were away" recap

struct AwayDigestSheet: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss

    private func away(_ m: Int) -> String {
        if m < 60 { return "\(m) minutes" }
        let h = m / 60
        if h < 48 { return "\(h) hour\(h == 1 ? "" : "s")" }
        return "\(h / 24) days"
    }

    private func close() { game.dismissDigest(); dismiss() }

    private func open(_ id: UUID?) {
        guard let id = id else { return }
        game.dismissDigest()
        nav.tab = 0
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { game.openPostID = id }
    }

    var body: some View {
        let d = game.s.ex.digest
        let items = d?.items ?? []
        let hero = items.max { ($0.weight ?? 0) < ($1.weight ?? 0) }
        let rest = items.filter { $0.id != hero?.id }
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { close() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                            .padding(10).background(Circle().fill(T.card))
                    }
                }.padding(.horizontal, 16).padding(.top, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("While you were away").font(.jk(30, .bold))
                        Text("You were gone \(away(d?.minutes ?? 0)). Here's what happened.")
                            .font(.jk(16)).foregroundColor(T.sub)
                        if let d = d {
                            HStack(spacing: 10) {
                                stat("Followers", (d.followerDelta >= 0 ? "+" : "-") + short(abs(d.followerDelta)), d.followerDelta >= 0, d.followerDelta == 0)
                                stat("Aura", (d.auraDelta >= 0 ? "+" : "") + "\(d.auraDelta)%", d.auraDelta >= 0, d.auraDelta == 0)
                            }
                        }
                        if let h = hero { heroCard(h) }
                        if !rest.isEmpty {
                            Text("Also happened").font(.jk(18, .semibold)).padding(.top, 4)
                            ForEach(rest) { row($0) }
                        }
                        if let m = d?.more, m > 0 {
                            Text("+\(m) more posts are waiting in your feed.")
                                .font(.jk(14)).foregroundColor(T.sub)
                        }
                    }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
                }
                Button { close() } label: {
                    Text("Catch up on the feed").font(.jk(17, .semibold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Capsule().fill(Color.white))
                }.padding(16)
            }
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
    }

    private func impact(_ it: DigestItem) -> some View {
        HStack(spacing: 8) {
            if let f = it.fol, f != 0 {
                Text("\(f > 0 ? "+" : "-")\(short(abs(f))) followers").foregroundColor(f > 0 ? T.lime : T.red)
            }
            if let a = it.aura, a != 0 {
                Text("aura \(a > 0 ? "+" : "")\(a)%").foregroundColor(a > 0 ? T.lime : T.red)
            }
        }.font(.jk(12, .semibold))
    }

    private func heroCard(_ it: DigestItem) -> some View {
        Button { open(it.postID) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("BIGGEST MOMENT").font(.jk(11, .heavy)).foregroundColor(T.orange)
                    Spacer()
                    Text(agoString(it.at)).font(.jk(12)).foregroundColor(T.sub)
                }
                HStack(spacing: 12) {
                    if let h = it.handles, !h.isEmpty { AvatarStack(handles: h, size: 46) }
                    else { Text(it.emoji).font(.jk(36)) }
                    Text(it.title).font(.jk(22, .bold)).multilineTextAlignment(.leading)
                }
                Text(it.detail).font(.jk(15)).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.leading)
                impact(it)
                if it.postID != nil {
                    Text("Open the post ›").font(.jk(14, .semibold)).foregroundColor(T.blue)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(T.card)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(T.orange.opacity(0.5), lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    private func stat(_ t: String, _ v: String, _ good: Bool, _ flat: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.jk(13)).foregroundColor(T.sub)
            Text(flat ? "No change" : v).font(.jk(24, .bold))
                .foregroundColor(flat ? T.sub : (good ? T.lime : T.red))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
    }

    private func row(_ it: DigestItem) -> some View {
        Button { open(it.postID) } label: {
            HStack(alignment: .top, spacing: 12) {
                if let h = it.handles, !h.isEmpty { AvatarStack(handles: h, size: 34) }
                else { Text(it.emoji).font(.jk(26)) }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(it.emoji) \(it.title)").font(.jk(16, .semibold)).multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Text(agoString(it.at)).font(.jk(12)).foregroundColor(T.sub)
                    }
                    Text(it.detail).font(.jk(14)).foregroundColor(T.sub).multilineTextAlignment(.leading)
                    impact(it)
                }
                if it.postID != nil { Image(systemName: "chevron.right").foregroundColor(T.sub).padding(.top, 4) }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
        }.buttonStyle(.plain)
    }
}

// MARK: - World history

struct WorldHistoryView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss
    @State private var msg: String? = nil

    private func open(_ id: UUID?) {
        guard let id = id else { return }
        nav.tab = 0
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { game.openPostID = id }
    }

    var body: some View {
        let st = game.s
        let hist = st.ex.history ?? []
        let feuds = (st.ex.rivalries ?? []).filter { $0.heat >= 1 }
            .sorted { ($0.status == "resolved" ? 1 : 0, -$0.heat) < ($1.status == "resolved" ? 1 : 0, -$1.heat) }
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)) }
                    Spacer()
                }.padding(16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("World History").font(.jk(30, .bold))
                        Text("The big moments that shaped \(st.world.title).")
                            .font(.jk(15)).foregroundColor(T.sub)
                        if let hot = st.ex.hot, !hot.isEmpty {
                            HStack {
                                Text("🔥 Trending now").font(.jk(15, .semibold))
                                Spacer()
                                Text(hot.capitalized).font(.jk(15)).foregroundColor(T.orange)
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(T.card))
                            Text("Posts about what's trending have a better shot at going viral.")
                                .font(.jk(13)).foregroundColor(T.sub)
                        }
                        if !feuds.isEmpty {
                            Text("Feuds").font(.jk(20, .semibold)).padding(.top, 6)
                            ForEach(feuds) { feud($0, st) }
                        }
                        Text("Timeline").font(.jk(20, .semibold)).padding(.top, 6)
                        if hist.isEmpty {
                            Text("Nothing historic yet. Go viral, get cancelled, or leave the world alone for a while and see what happens.")
                                .font(.jk(15)).foregroundColor(T.sub)
                        }
                        ForEach(hist) { h in
                            Button { open(h.postID) } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    if let hs = h.handles, !hs.isEmpty, hs != ["newsdesk"] { AvatarStack(handles: hs, size: 32) }
                                    else { Text(h.emoji).font(.jk(26)) }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Day \(h.day) · \(agoString(h.date))").font(.jk(12, .semibold)).foregroundColor(T.sub)
                                        Text("\(h.emoji) \(h.title)").font(.jk(16, .semibold)).multilineTextAlignment(.leading)
                                        Text(h.detail).font(.jk(14)).foregroundColor(T.sub).multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    if h.postID != nil { Image(systemName: "chevron.right").foregroundColor(T.sub) }
                                }
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 14).fill(T.card))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 30)
                }
            }
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .alert(msg ?? "", isPresented: Binding(get: { msg != nil }, set: { if !$0 { msg = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func feud(_ r: Rivalry, _ st: GameState) -> some View {
        let a = st.npcs.first { $0.handle == r.a }
        let b = st.npcs.first { $0.handle == r.b }
        let done = r.status == "resolved"
        let sa = (r.sides ?? [:]).filter { $0.value == r.a && $0.key != st.persona.handle }.count
        let sb = (r.sides ?? [:]).filter { $0.value == r.b && $0.key != st.persona.handle }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarStack(handles: [r.a, r.b], size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(a?.name ?? r.a) vs \(b?.name ?? r.b)").font(.jk(16, .semibold))
                    Text(done ? "Resolved\(r.resolvedBy == "you" ? " by you" : "")" : game.feudLabel(r.rel ?? 0))
                        .font(.jk(13)).foregroundColor(done ? T.lime : T.orange)
                }
                Spacer()
                Text("🔥 \(r.heat)").font(.jk(15, .semibold)).foregroundColor(T.orange)
            }
            if let c = r.cause {
                Text("Over \(c). \(sa) back \(a?.name ?? r.a), \(sb) back \(b?.name ?? r.b).")
                    .font(.jk(13)).foregroundColor(T.sub)
            }
            if !done {
                Button { msg = game.mediate(r.id) } label: {
                    Text("Step in").font(.jk(14, .semibold)).foregroundColor(.black)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(T.card))
    }
}
