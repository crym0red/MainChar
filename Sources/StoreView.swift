import SwiftUI

let gemPurple = Color(red: 0.66, green: 0.40, blue: 0.95)

struct GemIcon: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            Image(systemName: "hexagon.fill").font(.system(size: size)).foregroundColor(gemPurple)
            Image(systemName: "hexagon.fill").font(.system(size: size * 0.62)).foregroundColor(Color.white.opacity(0.28))
        }
    }
}

// MARK: - Toast

struct ToastModifier: ViewModifier {
    @EnvironmentObject var game: Game

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let t = game.toast {
                Text(t).font(.jk(15, .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.black.opacity(0.85)).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.toast)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastModifier()) }
}

// MARK: - Store

struct StoreView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss
    @State private var confirm: StoreItem? = nil
    @State private var streakInfo = false
    @State private var gemInfo = false

    var body: some View {
        let st = game.s
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
                Spacer()
                Text("Store").font(.jk(24, .semibold))
                Spacer()
                HStack(spacing: 6) {
                    GemIcon(size: 30)
                    Text("\(st.ex.gems)").font(.jk(22, .medium)).foregroundColor(gemPurple)
                    Button { gemInfo = true } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                            .frame(width: 44, height: 40).background(gemPurple.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    streakCard(st)
                    section("Boosts", [.gift, .wave, .xp, .spotlight], st)
                    section("Powerups", [.viral, .boost, .shield, .squad], st)
                    section("Wild West", [.slate, .stir], st)
                }
                .padding(.horizontal, 16).padding(.bottom, 40)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .toastOverlay()
        .alert("Buy \(confirm?.title ?? "")?", isPresented: Binding(get: { confirm != nil }, set: { _ in })) {
            Button("Buy for \(confirm?.price ?? 0) gems") {
                if let c = confirm { game.buy(c) }
                confirm = nil
            }
            Button("Cancel", role: .cancel) { confirm = nil }
        } message: {
            Text(confirm?.desc ?? "")
        }
        .alert("Earn gems", isPresented: $gemInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Gems are earned by playing: +2 for every level up, +3 for each milestone, and +1 for every day you come back. Streak bonuses at 3, 7, 14 and 30 days.")
        }
        .alert("Streak rewards", isPresented: $streakInfo) {
            Button("Go to goals") { dismiss(); nav.tab = 1 }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Come back every day for +1 gem. Bonus gems at 3 days (+3), 7 days (+5), 14 days (+8) and 30 days (+15). Milestones you claim in Goals pay +3 gems each.")
        }
    }

    private func streakCard(_ st: GameState) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(st.ex.streak) day streak").font(.jk(28, .semibold))
                Text("Claim milestone rewards over time!").font(.jk(17)).foregroundColor(T.sub)
                Button { streakInfo = true } label: {
                    Text("View milestones").font(.jk(19, .medium)).foregroundColor(T.orange)
                }
            }
            Spacer()
            Image(systemName: "flame.fill").font(.system(size: 56)).foregroundColor(T.orange)
        }
        .padding(20)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func section(_ title: String, _ items: [StoreItem], _ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.jk(24, .medium)).padding(.top, 14)
            ForEach(items) { it in
                Button { confirm = it } label: { row(it, st) }.buttonStyle(.plain)
            }
        }
    }

    private func status(_ it: StoreItem, _ st: GameState) -> String? {
        switch it {
        case .gift: return st.ex.gifts > 0 ? "You have \(st.ex.gifts)" : nil
        case .viral: return st.ex.viralArmed ? "Armed for your next action" : nil
        case .shield: return st.ex.shield == true ? "Active · blocks your next loss" : nil
        case .squad: return st.ex.squad == true ? "Waiting for your next post" : nil
        case .spotlight: return (st.ex.spotlight ?? 0) > 0 ? "On you now" : nil
        case .boost:
            if let b = st.ex.boostUntil, b > Date() {
                let m = Int(b.timeIntervalSinceNow / 60) + 1
                return "Active · about \(m) min left"
            }
            return nil
        default: return nil
        }
    }

    private func row(_ it: StoreItem, _ st: GameState) -> some View {
        HStack(spacing: 16) {
            SymbolTile(emoji: it.emoji, size: 64, tint: T.gold).frame(width: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(it.title).font(.jk(24, .medium)).foregroundColor(.white)
                Text(it.desc).font(.jk(18)).foregroundColor(T.sub).multilineTextAlignment(.leading)
                if let s = status(it, st) {
                    Text(s).font(.jk(14, .semibold)).foregroundColor(T.lime)
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                GemIcon(size: 26)
                Text("\(it.price)").font(.jk(24, .medium)).foregroundColor(gemPurple)
            }
            .opacity(st.ex.gems >= it.price ? 1 : 0.5)
        }
        .padding(.vertical, 18).padding(.horizontal, 14)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
