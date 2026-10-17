import SwiftUI

// MARK: - "While you were away" digest

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

    var body: some View {
        let d = game.s.ex.digest
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { game.dismissDigest(); dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                            .padding(10).background(Circle().fill(T.card))
                    }
                }.padding(.horizontal, 16).padding(.top, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("🌍").font(.system(size: 48))
                        Text("While you were away").font(.system(size: 30, weight: .bold))
                        Text("Your world kept moving for \(away(d?.minutes ?? 0)).")
                            .font(.system(size: 16)).foregroundColor(T.sub)
                        if let d = d {
                            HStack(spacing: 10) {
                                stat("Followers", (d.followerDelta >= 0 ? "+" : "-") + short(abs(d.followerDelta)), d.followerDelta >= 0)
                                stat("Aura", (d.auraDelta >= 0 ? "+" : "") + "\(d.auraDelta)%", d.auraDelta >= 0)
                            }
                            ForEach(d.items.filter { $0.title != "Your popularity grew" && $0.title != "Your popularity dipped" }) { it in
                                row(it)
                            }
                        }
                    }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 30)
                }
                Button { game.dismissDigest(); dismiss() } label: {
                    Text("Catch up on the feed").font(.system(size: 17, weight: .semibold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Capsule().fill(Color.white))
                }.padding(16)
            }
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
    }

    private func stat(_ t: String, _ v: String, _ good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.system(size: 13)).foregroundColor(T.sub)
            Text(v).font(.system(size: 24, weight: .bold)).foregroundColor(good ? T.lime : T.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
    }

    private func row(_ it: DigestItem) -> some View {
        Button {
            if let id = it.postID {
                game.dismissDigest()
                nav.tab = 0
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { game.openPostID = id }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(it.emoji).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 4) {
                    Text(it.title).font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.leading)
                    Text(it.detail).font(.system(size: 14)).foregroundColor(T.sub).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if it.postID != nil { Image(systemName: "chevron.right").foregroundColor(T.sub) }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
        }.buttonStyle(.plain)
    }
}

// MARK: - World history

struct WorldHistoryView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let st = game.s
        let hist = st.ex.history ?? []
        let rivals = (st.ex.rivalries ?? []).filter { $0.heat >= 2 }.sorted { $0.heat > $1.heat }
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)) }
                    Spacer()
                }.padding(16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("World History").font(.system(size: 30, weight: .bold))
                        Text("The big moments that shaped \(st.world.title).")
                            .font(.system(size: 15)).foregroundColor(T.sub)
                        if let hot = st.ex.hot, !hot.isEmpty {
                            HStack {
                                Text("🔥 Trending now").font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text(hot.capitalized).font(.system(size: 15)).foregroundColor(T.orange)
                            }
                            .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(T.card))
                            Text("Posts about what's trending have a better shot at going viral.")
                                .font(.system(size: 13)).foregroundColor(T.sub)
                        }
                        if !rivals.isEmpty {
                            Text("Feuds").font(.system(size: 20, weight: .semibold)).padding(.top, 6)
                            ForEach(rivals) { r in
                                let a = st.npcs.first { $0.handle == r.a }
                                let b = st.npcs.first { $0.handle == r.b }
                                HStack {
                                    Text("\(a?.emoji ?? "👤") \(a?.name ?? r.a)  vs  \(b?.emoji ?? "👤") \(b?.name ?? r.b)")
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                    Text("🔥 \(r.heat)").font(.system(size: 15, weight: .semibold)).foregroundColor(T.orange)
                                }
                                .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(T.card))
                            }
                        }
                        Text("Timeline").font(.system(size: 20, weight: .semibold)).padding(.top, 6)
                        if hist.isEmpty {
                            Text("Nothing historic yet. Go viral, get cancelled, or leave the world alone for a while and see what happens.")
                                .font(.system(size: 15)).foregroundColor(T.sub)
                        }
                        ForEach(hist) { h in
                            HStack(alignment: .top, spacing: 12) {
                                Text(h.emoji).font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Day \(h.day)").font(.system(size: 12, weight: .semibold)).foregroundColor(T.sub)
                                    Text(h.title).font(.system(size: 16, weight: .semibold))
                                    Text(h.detail).font(.system(size: 14)).foregroundColor(T.sub)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(T.card))
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 30)
                }
            }
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
    }
}
