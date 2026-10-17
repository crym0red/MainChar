import SwiftUI

// MARK: - Goals

struct GoalsTab: View {
    @EnvironmentObject var game: Game
    @State private var compose: ComposeSeed? = nil
    @State private var customize = false
    @State private var showLog = false
    @State private var showStore = false
    @State private var how = false
    @State private var showRank = false

    var body: some View {
        let st = game.s
        let need = Game.xpNeed(st.level)
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header(st, need, proxy)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        mainGoal(st)
                        rankCard(st)
                        ChallengesCard()
                        milestones(st)
                        quests(st)
                        skills(st).id("skills")
                        rewards(st)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 40)
                }
            }
        }
        .background(T.bg)
        .sheet(item: $compose) { ComposeSheet(seed: $0).zoomed().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $customize) { CustomizeWorldSheet().zoomed() }
        .sheet(isPresented: $showRank) { RankingsSheet().zoomed() }
        .fullScreenCover(isPresented: $showLog) { ActivityLogView().zoomed() }
        .fullScreenCover(isPresented: $showStore) { StoreView().zoomed() }
        .alert("How does this work?", isPresented: $how) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Posts, stories and events earn XP. Every level pays out gems and skill points, every 5th gives an item, every 10th a badge. Skills get pricier the higher they go, and each keystone (10, 25, 50, 75, 100) pays gems and a permanent XP boost.")
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
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
                .frame(width: 46, height: 46).background(T.card2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func header(_ st: GameState, _ need: Int, _ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 10) {
            Button { how = true } label: {
                Text("LVL \(st.level)").font(.jk(16, .heavy)).foregroundColor(.white)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(T.card2).clipShape(Capsule())
            }
            ZStack {
                Bar(value: Double(st.xp) / Double(max(1, need)), color: T.gold, height: 30)
                Text("\(st.xp)/\(need) XP").font(.jk(13, .bold)).foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.6).shadow(color: .black.opacity(0.6), radius: 2)
            }
            .frame(maxWidth: .infinity)
            octoPlus(enabled: st.points > 0, size: 40) { withAnimation { proxy.scrollTo("skills", anchor: .top) } }
            squareButton("book.closed.fill") { showLog = true }
            squareButton("storefront.fill") { showStore = true }
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

    // MARK: Rankings

    private func rankCard(_ st: GameState) -> some View {
        let rows = game.rankings(st)
        let me = game.myRank(st)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                title("Scene rankings")
                Button { showRank = true } label: { Text("View all").font(.jk(16, .semibold)).foregroundColor(T.blue) }
            }
            panel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Season \(st.ex.season ?? 1)", systemImage: "trophy.fill").font(.jk(16, .bold)).foregroundColor(T.gold)
                        Spacer()
                        Text("\(game.seasonDaysLeft(st)) days left").font(.jk(14)).foregroundColor(T.sub)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("#\(me)").font(.jk(40, .heavy))
                        Text("of \(rows.count)").font(.jk(16)).foregroundColor(T.sub)
                    }
                    ForEach(Array(rows.prefix(3).enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.jk(15, .bold)).foregroundColor(T.sub).frame(width: 20)
                            Avatar(emoji: "", key: r.handle, size: 30)
                            Text(r.you ? "You" : r.name).font(.jk(15, .semibold)).lineLimit(1)
                            Spacer()
                            Text(short(r.followers)).font(.jk(14)).foregroundColor(T.sub)
                        }
                    }
                    Text("Seasons last two weeks. Finish high for gems and a badge.").font(.jk(13)).foregroundColor(T.sub)
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
                panel { Text("All milestones complete.").font(.jk(20, .semibold)) }
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

    // MARK: Skill tree

    private func skills(_ st: GameState) -> some View {
        let m = game.nextMilestone
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skill tree").font(.jk(26, .medium))
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill").rotationEffect(.degrees(-20))
                    Text("\(st.points) pts")
                }
                .font(.jk(21, .semibold)).foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.05))
            }
            Text("Every point costs more as a skill climbs. Keystones pay gems and +1% XP forever.")
                .font(.jk(14)).foregroundColor(T.sub)
            ForEach(Array(st.skills.enumerated()), id: \.element.id) { i, sk in
                let miss: Int = {
                    guard let m = m else { return 0 }
                    return m.reqs.filter { $0.skill == i }.map { max(0, $0.level - sk.value) }.reduce(0, +)
                }()
                skillCard(sk, miss, st)
            }
        }
    }

    private func skillCard(_ sk: Skill, _ miss: Int, _ st: GameState) -> some View {
        let cost = Levels.skillCost(sk.value)
        let maxed = sk.value >= 100
        let can = !maxed && st.points >= cost
        let hue = Double(HK.h(sk.name) % 360) / 360
        let tint = Color(hue: hue, saturation: 0.7, brightness: 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(sk.name).font(.jk(24, .semibold))
                Spacer(minLength: 6)
                if miss > 0 { needed(miss) }
                Text("\(sk.value)").font(.jk(26, .heavy)).foregroundColor(tint)
                Text("/100").font(.jk(15)).foregroundColor(T.sub)
            }
            Text(sk.desc).font(.jk(15)).foregroundColor(T.sub)
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: 8)
                    Capsule().fill(tint).frame(width: max(8, w * CGFloat(sk.value) / 100), height: 8)
                    ForEach(Array(Levels.keystones.enumerated()), id: \.offset) { idx, t in
                        let got = sk.value >= t
                        ZStack {
                            Circle().fill(got ? tint : T.card2).frame(width: 30, height: 30)
                            Circle().stroke(got ? Color.white.opacity(0.9) : Color.white.opacity(0.2), lineWidth: 2).frame(width: 30, height: 30)
                            Image(systemName: got ? "star.fill" : "lock.fill").font(.system(size: 12, weight: .bold))
                                .foregroundColor(got ? .black.opacity(0.75) : T.sub)
                        }
                        .offset(x: w * CGFloat(t) / 100 - 15 - (t == 100 ? 0 : 0), y: 0)
                        Text("\(t)").font(.jk(11, .semibold)).foregroundColor(got ? .white : T.sub)
                            .offset(x: w * CGFloat(t) / 100 - 6 - (t >= 100 ? 4 : 0), y: 26)
                    }
                }
                .frame(height: 30, alignment: .leading)
            }
            .frame(height: 52)
            Button { game.upgrade(sk.id) } label: {
                HStack(spacing: 8) {
                    Image(systemName: maxed ? "checkmark.seal.fill" : "arrow.up.circle.fill")
                    Text(maxed ? "Mastered" : "Level up").font(.jk(18, .semibold))
                    if !maxed {
                        Text("\(cost) pt\(cost == 1 ? "" : "s")").font(.jk(15, .bold)).foregroundColor(can ? .white.opacity(0.9) : T.sub)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.black.opacity(0.25)).clipShape(Capsule())
                    }
                }
                .foregroundColor(can || maxed ? .white : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(maxed ? T.lime.opacity(0.5) : (can ? tint.opacity(0.85) : Color.white.opacity(0.12))).clipShape(Capsule())
            }
            .disabled(!can)
        }
        .padding(18)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1.5))
    }

    // MARK: Level rewards

    private func rewards(_ st: GameState) -> some View {
        let upcoming = (1...6).map { st.level + $0 }
        let badges = st.ex.lvBadges ?? []
        return VStack(alignment: .leading, spacing: 12) {
            title("Level rewards")
            panel {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.offset) { i, l in
                        let r = Levels.reward(l)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(r.badge != nil ? T.gold.opacity(0.25) : T.card2).frame(width: 42, height: 42)
                                Image(systemName: r.badge?.symbol ?? r.itemSymbol ?? "diamond.fill")
                                    .font(.system(size: 17, weight: .bold)).foregroundColor(r.badge != nil ? T.gold : T.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Level \(l)").font(.jk(17, .semibold))
                                Text(Levels.summary(r)).font(.jk(13)).foregroundColor(T.sub).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if i < upcoming.count - 1 { Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1) }
                    }
                }
            }
            if !badges.isEmpty {
                Text("Badges earned (\(badges.count))").font(.jk(18, .medium)).padding(.top, 6)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(badges.reversed()) { b in
                        VStack(spacing: 6) {
                            Image(systemName: b.symbol).font(.system(size: 24, weight: .bold)).foregroundColor(T.gold)
                            Text(b.name).font(.jk(12, .semibold)).multilineTextAlignment(.center).lineLimit(2)
                            Text("Lvl \(b.level)").font(.jk(10)).foregroundColor(T.sub)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 6)
                        .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
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
                }.zoomed()
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
                        if let l = msgs.last, !l.fromYou, let chs = l.choices {
                            VStack(alignment: .trailing, spacing: 8) {
                                ForEach(Array(chs.enumerated()), id: \.offset) { i, c in
                                    Button { game.answerArc(handle, i) } label: {
                                        Text(c).font(.jk(14, .semibold)).foregroundColor(.white)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .overlay(Capsule().stroke(T.blue, lineWidth: 1.5))
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .trailing)
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
    @State private var filter = 0

    private func matches(_ n: Notif) -> Bool {
        let money = n.text.contains("$") || n.sub.contains("$") || n.sub.lowercased().contains("gem") || n.text.lowercased().contains("gem")
        switch filter {
        case 1: return ["follow", "reply", "story"].contains(n.kind)
        case 2: return n.kind == "event" && !money
        case 3: return money
        case 4: return ["level", "milestone"].contains(n.kind)
        default: return true
        }
    }

    var body: some View {
        let st = game.s
        VStack(spacing: 0) {
            Text("Notifications").font(.jk(30, .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(["All", "People", "Drama", "Money", "Progress"].enumerated()), id: \.offset) { i, t in
                        Button { filter = i } label: {
                            Text(t).font(.jk(15, .semibold)).foregroundColor(filter == i ? .black : .white)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(filter == i ? Color.white : T.card2).clipShape(Capsule())
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            ScrollView {
                if st.notifs.isEmpty {
                    EmptyState(emoji: "🔔", title: "Nothing yet", detail: "Followers, replies and milestones show up here.")
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(st.notifs.filter(matches)) { n in
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
        .fullScreenCover(item: $openStory) { o in StoriesFlow(openStory: o.story).zoomed() }
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
            EmojiIcon(emoji: n.emoji, size: 24, color: T.blue)
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
                if n.kind == "follow" && !n.handle.isEmpty && !(st.ex.following ?? []).contains(n.handle) {
                    Button { game.toggleFollow(n.handle) } label: {
                        Text("Follow back").font(.jk(20, .medium)).foregroundColor(.black)
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(Color.white).clipShape(Capsule())
                    }
                }
                if let t = Mk.tickers(n.text + " " + n.sub).first, (st.ex.market?.coins ?? []).contains(where: { $0.id == t }) {
                    Button { nav.coin = t; nav.tab = 5 } label: {
                        Label("Open $\(t)", systemImage: "chart.line.uptrend.xyaxis").font(.jk(18, .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Color(red: 0.45, green: 0.30, blue: 0.95)).clipShape(Capsule())
                    }
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
    @State private var settings = false
    @State private var showStore = false
    @State private var npcSheet: NPC? = nil
    @State private var openStory: StoryOpen? = nil
    @State private var allStories = false
    @State private var showHistory = false
    @State private var unlockInfo = false
    @State private var showFollowers = false
    @State private var showAvatarStudio = false
    @State private var scrolled = false

    var body: some View {
        let st = game.s
        let p = st.persona
        VStack(spacing: 0) {
            topBar(st, p)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileBanner().id(game.profileRev)
                    .frame(height: 200)

                HStack(alignment: .top) {
                    Button { showAvatarStudio = true } label: {
                        Avatar(emoji: p.emoji, key: p.handle, size: 150)
                            .id(game.profileRev)
                            .overlay(Circle().stroke(T.bg, lineWidth: 6))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "wand.and.stars").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 44, height: 44).background(T.blue).clipShape(Circle())
                                    .overlay(Circle().stroke(T.bg, lineWidth: 4))
                            }
                    }
                    .buttonStyle(.plain)
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
                    if let ti = st.ex.title { Chip(text: ti, color: T.gold.opacity(0.3)) }
                    if !p.bio.isEmpty { Text(p.bio).font(.jk(23)).padding(.top, 4) }
                    Button { showFollowers = true } label: {
                        HStack(spacing: 6) {
                            (Text(short(st.followers)).fontWeight(.semibold).foregroundColor(.white)
                                + Text(" Followers").foregroundColor(T.sub))
                                .font(.jk(25))
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(T.sub)
                        }
                    }
                    .buttonStyle(.plain).padding(.top, 6)
                }
                .padding(.horizontal, 16).padding(.top, 14)

                statStrip(st).padding(.horizontal, 16).padding(.top, 18)

                achievementsCard(st).padding(.horizontal, 16).padding(.top, 14)

                tabs.padding(.horizontal, 16).padding(.top, 18)

                Group {
                    if seg == 0 { overview(st) }
                    else if seg == 1 { posts(st) }
                    else { activities(st) }
                }
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 40)
            }
        }
        }
        .background(T.bg)
        .fullScreenCover(isPresented: $edit) { EditProfileSheet().zoomed() }
        .fullScreenCover(isPresented: $settings) { GameSettingsView().zoomed() }
        .sheet(item: $npcSheet) { NPCSheet(npc: $0).zoomed() }
        .fullScreenCover(item: $openStory) { o in StoriesFlow(openStory: o.story).zoomed() }
        .fullScreenCover(isPresented: $allStories) { AllStoriesSheet().zoomed() }
        .fullScreenCover(isPresented: $showHistory) { WorldHistoryView().zoomed() }
        .alert("More characters", isPresented: $unlockInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Characters warm up to you as you post, reply, message them and send gifts. Once they follow you they show up here.")
        }
        .fullScreenCover(isPresented: $showStore) { StoreView().zoomed() }
        .fullScreenCover(isPresented: $showFollowers) { FollowersSheet().zoomed() }
        .fullScreenCover(isPresented: $showAvatarStudio) { AvatarStudioView().zoomed() }
    }

    private func achievementsCard(_ st: GameState) -> some View {
        let got = Game.badgeDefs.filter { st.achievements.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Achievements").font(.jk(18, .bold))
                Spacer()
                Text("\(got)/\(Game.badgeDefs.count)").font(.jk(13, .bold)).foregroundColor(T.sub)
            }
            .padding(.bottom, 8)
            ForEach(Game.badgeDefs) { b in
                let done = st.achievements.contains(b.id)
                HStack(spacing: 12) {
                    EmojiIcon(emoji: b.emoji, size: 20, color: done ? T.gold : T.sub)
                        .frame(width: 28)
                    Text(b.title).font(.jk(16, done ? .semibold : .regular)).foregroundColor(done ? .white : T.sub)
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(done ? T.lime : T.sub.opacity(0.5))
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
            }
        }
        .padding(16).background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func topButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
                .frame(width: 46, height: 46).background(T.card2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func topBar(_ st: GameState, _ p: Persona) -> some View {
        HStack(spacing: 10) {
            Text("Profile").font(.jk(26, .heavy))
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "diamond.fill").font(.system(size: 12)).foregroundColor(T.gold)
                Text("\(st.ex.gems)").font(.jk(15, .bold)).lineLimit(1).fixedSize()
            }
            .padding(.horizontal, 14).frame(height: 40).fixedSize().background(T.card2).clipShape(Capsule())
            topButton("storefront.fill") { showStore = true }
            topButton("gearshape.fill") { settings = true }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
    }

    private func statTile(_ icon: String, _ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(tint)
            Text(value).font(.jk(24, .bold)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(.jk(11, .heavy)).foregroundColor(T.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func statStrip(_ st: GameState) -> some View {
        let need = max(1, Levels.need(st.level))
        let mine = st.posts.filter { $0.isYou }.count
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile("sparkles", "\(st.aura)", "Aura", T.gold)
                statTile("bolt.fill", "\(st.level)", "Level", T.blue)
                statTile("square.and.pencil", "\(mine)", "Posts", T.lime)
                statTile("diamond.fill", "\(st.ex.gems)", "Gems", Color(red: 0.67, green: 0.62, blue: 0.95))
            }
            HStack(spacing: 12) {
                Text("Level \(st.level)").font(.jk(14, .bold)).foregroundColor(T.sub)
                Bar(value: min(1, Double(st.xp) / Double(need)), color: T.blue, height: 10)
                Text("\(st.xp)/\(need) XP").font(.jk(14, .semibold)).foregroundColor(T.sub)
            }
            .padding(.horizontal, 4)
        }
    }

    private var tabs: some View {
        let names = ["Overview", "Posts", "Activity"]
        return HStack(spacing: 4) {
            ForEach(Array(names.enumerated()), id: \.offset) { i, n in
                Button { withAnimation(.easeOut(duration: 0.15)) { seg = i } } label: {
                    Text(n).font(.jk(18, .semibold)).foregroundColor(seg == i ? .white : T.sub)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(seg == i ? T.blue : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4).background(T.card).clipShape(Capsule())
    }

    // MARK: Overview

    private func presenceRow(emoji: String, name: String, value: Int, delta: Int, note: String?) -> some View {
        let v = max(0, min(100, value))
        let prev = max(0, min(100, value - delta))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                EmojiIcon(emoji: emoji, size: 22, color: T.blue)
                Text(name).font(.jk(20, .semibold)).padding(.top, 1)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if delta != 0 {
                        Text(String(format: "%+.1f%%", Double(delta)))
                            .font(.jk(15, .semibold))
                            .foregroundColor(delta > 0 ? T.lime : T.orange)
                    }
                    Text(String(format: "%.1f%%", Double(v))).font(.jk(19, .semibold))
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(Color.white.opacity(0.18)).frame(width: g.size.width * CGFloat(v) / 100)
                    if delta != 0 {
                        Capsule().fill(T.gold).frame(width: 5, height: 14)
                            .offset(x: max(0, g.size.width * CGFloat(prev) / 100 - 3))
                    }
                }
            }
            .frame(height: 14)
            if let n = note, !n.isEmpty {
                Text(n).font(.jk(15)).foregroundColor(T.sub)
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
            Text("Social Media Presence").font(.jk(22, .bold))
            VStack(alignment: .leading, spacing: 0) {
                stat(.humor).padding(.vertical, 12)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                presenceRow(emoji: "🌟", name: "Aura", value: st.aura, delta: st.lastAuraDelta, note: auraNote)
                    .padding(.vertical, 12)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                stat(.charm).padding(.vertical, 12)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                stat(.edge).padding(.vertical, 12)
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                stat(.mystery).padding(.vertical, 12)
            }
            .padding(.horizontal, 18)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))

            historyButton

        }
    }

    private var historyButton: some View {
        Button { showHistory = true } label: {
            HStack {
                Image(systemName: "globe.americas.fill").font(.system(size: 22)).foregroundColor(T.blue)
                Text("World History").font(.jk(17, .semibold))
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(T.sub)
            }
            .padding(14).background(RoundedRectangle(cornerRadius: 16).fill(T.card))
        }.buttonStyle(.plain)
    }

    private func posts(_ st: GameState) -> some View {
        let mine = st.posts.filter { $0.isYou }
        let stories = st.ex.stories
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Stories").font(.jk(22, .bold))
                Spacer()
                Button { allStories = true } label: {
                    Text("View all").font(.jk(17, .semibold)).foregroundColor(T.blue)
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

            Text("Your Posts").font(.jk(22, .bold)).padding(.top, 6)
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
                    EmojiIcon(emoji: l.emoji, size: 18, color: T.blue)
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


struct RankingsSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let st = game.s
        let rows = game.rankings(st)
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scene rankings").font(.jk(24, .bold))
                    Text("Season \(st.ex.season ?? 1) · \(game.seasonDaysLeft(st)) days left").font(.jk(13)).foregroundColor(T.sub)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(T.card2).clipShape(Circle())
                }
            }
            .padding(16)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.prefix(60).enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.jk(16, .bold)).foregroundColor(i < 3 ? T.gold : T.sub).frame(width: 30)
                            Avatar(emoji: "", key: r.handle, size: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.you ? "You" : r.name).font(.jk(16, .semibold)).lineLimit(1)
                                Text("@\(r.handle)").font(.jk(12)).foregroundColor(T.sub).lineLimit(1)
                            }
                            Spacer()
                            Text(short(r.followers)).font(.jk(15, .bold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(r.you ? T.blue.opacity(0.18) : Color.clear)
                        .modifier(OptionalProfileTap(handle: r.handle, on: !r.you))
                    }
                }
            }
        }
        .background(T.bg)
    }
}


// MARK: - Followers

struct FollowersSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var npcSheet: NPC? = nil
    @State private var info = false

    private func note(_ n: NPC) -> String {
        if n.affinity >= 70 { return "They're basically your biggest fan." }
        if n.affinity >= 40 { return "They like where this is going." }
        return "Following, still making up their mind."
    }

    var body: some View {
        let st = game.s
        let fans = st.npcs.filter { $0.id != "newsdesk" && $0.followsYou }.sorted { $0.affinity > $1.affinity }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Followers").font(.jk(24, .heavy))
                    Text("\(short(st.followers)) total · \(fans.count) you know").font(.jk(12)).foregroundColor(T.sub)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if fans.isEmpty {
                        EmptyState(emoji: "👥", title: "No followers you know yet", detail: "Post, reply and message characters. Once they follow you they show up here with your relationship.")
                    }
                    ForEach(fans) { n in
                        Button { npcSheet = n } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Avatar(emoji: n.emoji, key: n.handle, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(n.name).font(.jk(18, .semibold)).foregroundColor(.white).lineLimit(1)
                                            if n.followers >= 40000 { VerifiedSeal(size: 16) }
                                        }
                                        Text("@\(n.handle) · \(n.trait.rawValue.capitalized)").font(.jk(13)).foregroundColor(T.sub).lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundColor(T.sub)
                                }
                                HStack(spacing: 12) {
                                    Bar(value: Double(n.affinity) / 100, color: T.lime, height: 12)
                                    Text("\(n.affinity)%").font(.jk(15, .semibold)).foregroundColor(.white).frame(width: 48, alignment: .trailing)
                                }
                                Text(note(n)).font(.jk(14)).foregroundColor(T.sub)
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(T.card)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { info = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.circle.fill").font(.system(size: 20))
                            Text("How do I get more followers?").font(.jk(15))
                        }
                        .foregroundColor(T.sub)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(item: $npcSheet) { NPCSheet(npc: $0).zoomed() }
        .alert("Getting followers", isPresented: $info) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Characters warm up to you as you post, reply, message them and send gifts. Once they follow you they show up here.")
        }
    }
}
