import SwiftUI

private struct VLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        return p
    }
}

struct ActivityLogView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var filter = 0
    @State private var hideDMs = false
    @State private var openStory: StoryOpen? = nil
    @State private var expanded: Set<UUID> = []
    @State private var rated: Set<UUID> = []
    private let tabs = ["All", "Posts", "Stories", "Activities"]
    private let pink = Color(red: 1.0, green: 0.38, blue: 0.62)

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a • M/d/yy"
        return f
    }()

    private func kindOf(_ e: LogEntry) -> String { e.kind ?? "activity" }

    private func visible(_ e: LogEntry) -> Bool {
        let k = kindOf(e)
        if hideDMs && k == "dm" { return false }
        switch filter {
        case 1: return k == "post" || (k == "outcome" && e.detail == "post")
        case 2: return k == "story" || (k == "outcome" && e.detail == "story")
        case 3: return k == "activity" || k == "dm"
        default: return true
        }
    }

    private struct DayGroup: Identifiable {
        let id: Int
        let day: Int
        var items: [LogEntry]
    }

    private func groups(_ log: [LogEntry]) -> [DayGroup] {
        var out: [DayGroup] = []
        for e in log where visible(e) {
            if let last = out.last, last.day == e.day {
                out[out.count - 1].items.append(e)
            } else {
                out.append(DayGroup(id: out.count, day: e.day, items: [e]))
            }
        }
        return out
    }

    var body: some View {
        let st = game.s
        let gs = groups(st.log)
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                filters
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if gs.isEmpty {
                            EmptyState(emoji: "📜", title: "Nothing here yet", detail: "Posts, stories and outcomes show up as you play.")
                                .padding(.top, 60)
                        }
                        ForEach(gs) { g in
                            daySeparator(g.day)
                            ForEach(g.items) { e in entry(e, st) }
                        }
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 16)
                }
            }
            if game.undoSnap != nil {
                Button { game.undo() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 22, weight: .semibold))
                        Text("Undo last action").font(.system(size: 22, weight: .medium))
                    }
                    .foregroundColor(T.orange)
                    .padding(.horizontal, 28).padding(.vertical, 18)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.22)).clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.bottom, 28)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .toastOverlay()
        .fullScreenCover(item: $openStory) { o in StoriesFlow(openStory: o.story) }
    }

    // MARK: Pieces

    private var header: some View {
        ZStack {
            Text("Activity Log").font(.system(size: 24, weight: .semibold))
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 8)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                    Button { filter = i } label: {
                        Text(t).font(.system(size: 20, weight: .medium))
                            .foregroundColor(filter == i ? .black : .white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(filter == i ? Color.white : Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(filter == i ? 0 : 0.35), lineWidth: 1.5))
                    }
                }
                Button { hideDMs.toggle() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: hideDMs ? "checkmark.square.fill" : "square")
                            .font(.system(size: 26)).foregroundColor(hideDMs ? T.blue : T.sub)
                        Text("Hide DMs").font(.system(size: 19)).foregroundColor(T.sub)
                    }
                }
                .padding(.leading, 6)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private func daySeparator(_ day: Int) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            HStack(spacing: 8) {
                Image(systemName: "sun.max").foregroundColor(T.sub)
                Text("Day \(day)").foregroundColor(.white)
            }
            .font(.system(size: 19, weight: .medium))
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, -16)
    }

    private func icon(_ k: String) -> String {
        switch k {
        case "story": return "camera.fill"
        case "post": return "bubble.fill"
        case "outcome": return "arrow.right.to.line"
        case "dm": return "bubble.left.fill"
        default: return "sparkles"
        }
    }

    private func color(_ k: String) -> Color {
        switch k {
        case "story": return pink
        case "post": return T.blue
        case "outcome": return Color.white.opacity(0.85)
        case "dm": return T.lime
        default: return T.sub
        }
    }

    private func label(_ k: String) -> String {
        switch k {
        case "story": return "Story"
        case "post": return "Post"
        case "outcome": return "Outcome"
        case "dm": return "Message"
        default: return "Activity"
        }
    }

    private func entry(_ e: LogEntry, _ st: GameState) -> some View {
        let k = kindOf(e)
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon(k)).font(.system(size: 22)).foregroundColor(k == "outcome" ? .white : color(k))
                .frame(width: 58, height: 58).background(T.card).clipShape(Circle())
            VStack(alignment: .leading, spacing: 10) {
                Text(label(k)).font(.system(size: 22, weight: .medium)).foregroundColor(color(k))
                card(e, k, st)
                if k == "outcome" { outcomeFooter(e) }
            }
            .padding(.bottom, 24)
        }
        .background(alignment: .topLeading) {
            VLine()
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 8]))
                .frame(width: 6)
                .padding(.top, 66)
                .padding(.bottom, 8)
                .offset(x: 26)
        }
    }

    @ViewBuilder
    private func card(_ e: LogEntry, _ k: String, _ st: GameState) -> some View {
        switch k {
        case "story": storyCard(e, st)
        case "post": postCard(e, st)
        case "outcome": outcomeCard(e, st)
        default: plainCard(e, k)
        }
    }

    private func storyCard(_ e: LogEntry, _ st: GameState) -> some View {
        let story = st.ex.stories.first { $0.id == e.refID }
        return Button {
            if story != nil { openStory = StoryOpen(story: e.refID) }
        } label: {
            HStack(spacing: 14) {
                if let s = story {
                    StoryThumb(story: s, width: 58, height: 76)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(pink.opacity(0.8), lineWidth: 2))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(T.card2).frame(width: 58, height: 76)
                }
                Text(e.body ?? "Story").font(.system(size: 24, weight: .medium)).foregroundColor(.white)
                    .multilineTextAlignment(.leading).lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundColor(T.sub)
            }
            .padding(14)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func postCard(_ e: LogEntry, _ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 56)
                VStack(alignment: .leading, spacing: 0) {
                    Text(st.persona.name).font(.system(size: 22, weight: .bold))
                    Text("@\(st.persona.handle)").font(.system(size: 17)).foregroundColor(T.sub)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(T.sub)
            }
            Text(e.body ?? "").font(.system(size: 24)).foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func outcomeCard(_ e: LogEntry, _ st: GameState) -> some View {
        let d = e.delta ?? 0
        let good = d >= 0
        let isAura = e.title == "Aura"
        let value = isAura ? String(format: "%+.1f%%", d) : (d >= 0 ? "+\(Int(d))" : "\(Int(d))")
        let npc = st.npcs.first { $0.handle == e.handle }
        let open = expanded.contains(e.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(e.emoji).font(.system(size: 34))
                Text(e.title).font(.system(size: 26, weight: .bold))
                Text(value).font(.system(size: 26, weight: .bold)).foregroundColor(good ? T.lime : T.red)
                Spacer()
                if let n = npc {
                    Avatar(emoji: n.emoji, key: n.handle, size: 54)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: good ? "heart.circle.fill" : "heart.slash.circle.fill")
                                .font(.system(size: 20)).foregroundColor(good ? T.lime : T.red)
                                .background(Circle().fill(Color.black)).offset(x: 4, y: 4)
                        }
                }
            }
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            Text(e.body ?? "").font(.system(size: 21)).foregroundColor(.white)
                .lineLimit(open ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if open { expanded.remove(e.id) } else { expanded.insert(e.id) }
            } label: {
                Text(open ? "View less" : "View more").font(.system(size: 19, weight: .medium)).foregroundColor(T.sub)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(good ? Color(red: 0.10, green: 0.27, blue: 0.22) : Color(red: 0.34, green: 0.16, blue: 0.17))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(good ? T.lime.opacity(0.35) : T.red.opacity(0.4), lineWidth: 1.5))
    }

    private func outcomeFooter(_ e: LogEntry) -> some View {
        HStack {
            Text(e.time.map { ActivityLogView.timeFmt.string(from: $0) } ?? "Day \(e.day)")
                .font(.system(size: 17)).foregroundColor(T.sub)
            Spacer()
            Button {
                if rated.contains(e.id) { rated.remove(e.id) } else { rated.insert(e.id) }
            } label: {
                HStack(spacing: 8) {
                    Text("Rate outcome")
                    Image(systemName: rated.contains(e.id) ? "star.fill" : "star")
                        .foregroundColor(rated.contains(e.id) ? T.gold : T.sub)
                }
                .font(.system(size: 17)).foregroundColor(T.sub)
            }
        }
    }

    private func plainCard(_ e: LogEntry, _ k: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(e.emoji).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title).font(.system(size: 21, weight: .semibold))
                let sub = k == "dm" ? (e.body ?? "") : e.detail
                if !sub.isEmpty { Text(sub).font(.system(size: 17)).foregroundColor(T.sub).lineLimit(3) }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
