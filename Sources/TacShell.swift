import SwiftUI
import UIKit

enum LobbyAct {
    case nav(Int), screen(Int), season(Int), avatar, friends, ranks, stats, loadout
}

/// shared look of the new lobby
enum LS {
    static let navy = Color(red: 0.035, green: 0.06, blue: 0.1)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.125)
    static let card = Color(red: 0.075, green: 0.115, blue: 0.18)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.05)
    static let orange2 = Color(red: 0.95, green: 0.4, blue: 0.0)
    static let green = Color(red: 0.2, green: 0.72, blue: 0.3)
    static let line = Color.white.opacity(0.13)
    static let navW: CGFloat = 118
    static let topH: CGFloat = 44

    static func area(_ size: CGSize) -> CGSize { CGSize(width: size.width - navW, height: size.height - topH) }
}

// MARK: - perks (apply to the player's own gun)

enum TPerk {
    static let names = ["Quick Hands", "Scavenger", "Hardline", "Tracker"]
    static let icons = ["hand.raised.fill", "shippingbox.fill", "shield.fill", "eye.fill"]
    static let info = ["Reload 15% faster", "+1 spare magazine", "Spawn with 130 armor", "Spot 30% further"]
    private static let key = "ms.perks"
    static var on: Set<Int> {
        get { Set((UserDefaults.standard.array(forKey: key) as? [Int]) ?? [0, 1]) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }
    static var reloadMul: CGFloat { on.contains(0) ? 0.85 : 1 }
    static var spareBonus: Int { on.contains(1) ? 1 : 0 }
    static var armor: CGFloat { on.contains(2) ? 130 : 100 }
    static var spotMul: CGFloat { on.contains(3) ? 1.3 : 1 }
}

// MARK: - backdrop (low-poly harbor at golden hour)

struct HarborBackdrop: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.2, green: 0.42, blue: 0.72), Color(red: 0.55, green: 0.68, blue: 0.84), Color(red: 0.96, green: 0.76, blue: 0.52)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.62)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.55, y: h * 0.3, width: w * 0.5, height: w * 0.5)), with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.6).opacity(0.55), .clear]), center: CGPoint(x: w * 0.8, y: h * 0.55), startRadius: 0, endRadius: w * 0.25))
            // water
            ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.1)), with: .color(Color(red: 0.16, green: 0.3, blue: 0.45)))
            // far ship
            var ship = Path()
            ship.move(to: CGPoint(x: w * 0.22, y: h * 0.58))
            ship.addLine(to: CGPoint(x: w * 0.5, y: h * 0.58))
            ship.addLine(to: CGPoint(x: w * 0.46, y: h * 0.5))
            ship.addLine(to: CGPoint(x: w * 0.26, y: h * 0.5))
            ship.closeSubpath()
            ctx.fill(ship, with: .color(Color(red: 0.2, green: 0.26, blue: 0.34)))
            ctx.fill(Path(CGRect(x: w * 0.36, y: h * 0.4, width: w * 0.06, height: h * 0.1)), with: .color(Color(red: 0.8, green: 0.82, blue: 0.86).opacity(0.8)))
            // cranes
            let crane = Color(red: 0.1, green: 0.17, blue: 0.27)
            for (i, cx) in ([0.12, 0.42, 0.7, 0.9] as [CGFloat]).enumerated() {
                let x = w * cx, top = h * (0.22 + 0.05 * CGFloat(i % 2)), base = h * 0.66
                ctx.fill(Path(CGRect(x: x - 14, y: top, width: 3, height: base - top)), with: .color(crane))
                ctx.fill(Path(CGRect(x: x + 11, y: top, width: 3, height: base - top)), with: .color(crane))
                ctx.fill(Path(CGRect(x: x - 14, y: top, width: 28, height: 3)), with: .color(crane))
                ctx.fill(Path(CGRect(x: x - 60, y: top - 6, width: 120, height: 5)), with: .color(crane))
                ctx.fill(Path(CGRect(x: x - 4, y: top - 12, width: 8, height: 7)), with: .color(Color(red: 0.85, green: 0.45, blue: 0.1)))
            }
            // containers
            let cols: [Color] = [Color(red: 0.8, green: 0.35, blue: 0.1), Color(red: 0.15, green: 0.35, blue: 0.7), Color(red: 0.7, green: 0.15, blue: 0.15), Color(red: 0.2, green: 0.5, blue: 0.3), Color(red: 0.75, green: 0.6, blue: 0.2)]
            var s: UInt64 = 7
            func rnd() -> Int { s = s &* 6364136223846793005 &+ 1442695040888963407; return Int(s >> 33) }
            for gx in stride(from: CGFloat(-10), to: w + 40, by: 34) {
                let rows = 1 + rnd() % 3
                for r in 0..<rows {
                    ctx.fill(Path(CGRect(x: gx, y: h * 0.68 - CGFloat(r + 1) * 17, width: 32, height: 16)), with: .color(cols[rnd() % cols.count].opacity(0.9)))
                }
            }
            // ground
            ctx.fill(Path(CGRect(x: 0, y: h * 0.68, width: w, height: h * 0.32)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.5, green: 0.4, blue: 0.3), Color(red: 0.28, green: 0.24, blue: 0.2)]),
                startPoint: CGPoint(x: 0, y: h * 0.68), endPoint: CGPoint(x: 0, y: h)))
            for gx in stride(from: CGFloat(0), to: w, by: 60) {
                ctx.fill(Path(CGRect(x: gx, y: h * 0.68, width: 1, height: h * 0.32)), with: .color(Color.black.opacity(0.12)))
            }
        }
        .overlay(Color.black.opacity(0.32))
        .ignoresSafeArea()
    }
}

// MARK: - shell: top bar + left nav around any lobby page

struct LobbyShell<Content: View>: View {
    @EnvironmentObject var game: Game
    let active: Int
    let size: CGSize
    let t: TacData
    let act: (LobbyAct) -> Void
    let content: Content

    init(active: Int, size: CGSize, t: TacData, act: @escaping (LobbyAct) -> Void, @ViewBuilder content: () -> Content) {
        self.active = active; self.size = size; self.t = t; self.act = act; self.content = content()
    }

    private let items: [(String, String)] = [("house.fill", "PLAY"), ("person.fill", "CUSTOMIZE"), ("scope", "LOADOUT"), ("wrench.fill", "WORKSHOP"),
                                              ("shield.lefthalf.filled", "CLAN"), ("person.3.fill", "SQUAD"), ("cart.fill", "STORE"), ("gearshape.fill", "SETTINGS")]

    private func navItem(_ i: Int) -> some View {
        let on = i == active
        return Button { act(.nav(i)) } label: {
            HStack(spacing: 9) {
                SF(items[i].0, "circle.fill").font(.system(size: 15, weight: .bold)).foregroundColor(on ? LS.orange : .white.opacity(0.85)).frame(width: 22)
                Text(items[i].1).font(.jk(12, .heavy)).foregroundColor(on ? LS.orange : .white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: 39)
            .background(on ? LinearGradient(colors: [LS.orange.opacity(0.3), LS.orange.opacity(0.05)], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing))
            .overlay(alignment: .leading) { Rectangle().fill(on ? LS.orange : .clear).frame(width: 3) }
        }
        .buttonStyle(TuiPress())
    }

    var body: some View {
        let W = size.width, H = size.height
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let next = min(TacRank.ranks.count - 1, ri + 1)
        let a = LS.area(size)
        return ZStack {
            HarborBackdrop()
            content
                .frame(width: a.width, height: a.height)
                .position(x: LS.navW + a.width / 2, y: LS.topH + a.height / 2)
            // left nav
            VStack(spacing: 0) {
                ForEach(0..<items.count, id: \.self) { navItem($0) }
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .frame(width: LS.navW, height: H - LS.topH)
            .background(LS.navy.opacity(0.88))
            .position(x: LS.navW / 2, y: LS.topH + (H - LS.topH) / 2)
            // top bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    SF("triangle.fill").font(.system(size: 19, weight: .black)).foregroundColor(LS.orange)
                    Text("MAINSHOT").font(.jk(19, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(width: LS.navW - 4, alignment: .leading)
                Spacer(minLength: 0)
                Button { act(.ranks) } label: {
                    HStack(spacing: 8) {
                        PortraitAvatar(key: TacAvatar.myKey, size: 32, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)
                            .clipShape(RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.4), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TacProfile.name).font(.jk(12, .heavy)).foregroundColor(.white).lineLimit(1).frame(maxWidth: 110, alignment: .leading)
                            HStack(spacing: 5) {
                                Text("Lv. \(ri + 1)").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.85))
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.2))
                                    Rectangle().fill(LS.orange).frame(width: 80 * CGFloat(TacRank.progress(xp)))
                                }
                                .frame(width: 80, height: 4)
                                Text("\(xp) / \(TacRank.ranks[next].xp)").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.7)).fixedSize()
                            }
                        }
                    }
                }
                .buttonStyle(TuiPress())
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 0.85, green: 0.55, blue: 0.1)], startPoint: .top, endPoint: .bottom)).frame(width: 18, height: 18)
                    Text(game.s.ex.gems.formatted()).font(.jk(14, .heavy)).foregroundColor(.white).monospacedDigit()
                }
                HStack(spacing: 5) {
                    SF("diamond.fill").font(.system(size: 15, weight: .bold)).foregroundColor(Color(red: 0.3, green: 0.75, blue: 1))
                    Text("\(t.wins)").font(.jk(14, .heavy)).foregroundColor(.white).monospacedDigit()
                    Button { act(.season(2)) } label: {
                        SF("plus").font(.system(size: 12, weight: .black)).foregroundColor(.white).frame(width: 24, height: 24).background(Color.white.opacity(0.16))
                    }
                    .buttonStyle(TuiPress())
                }
                Button { act(.friends) } label: { SF("person.2.fill").font(.system(size: 16)).foregroundColor(.white) }.buttonStyle(TuiPress())
                Button { act(.friends) } label: { SF("envelope.fill").font(.system(size: 16)).foregroundColor(.white) }.buttonStyle(TuiPress())
                Button { act(.stats) } label: { SF("gearshape.fill").font(.system(size: 16)).foregroundColor(.white) }.buttonStyle(TuiPress())
            }
            .padding(.horizontal, 12).frame(width: W, height: LS.topH)
            .background(LS.navy.opacity(0.92))
            .overlay(alignment: .bottom) { Rectangle().fill(LS.line).frame(height: 1) }
            .position(x: W / 2, y: LS.topH / 2)
        }
    }
}

// MARK: - small shared pieces

struct LSPanel<C: View>: View {
    var title: String? = nil
    var trailing: String? = nil
    @ViewBuilder let content: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                HStack {
                    Text(title).font(.jk(10, .heavy)).foregroundColor(.white)
                    Spacer()
                    if let tr = trailing { Text(tr).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7)) }
                }
                .padding(.horizontal, 8).frame(height: 22)
            }
            content()
        }
        .background(LS.panel.opacity(0.92))
        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
    }
}

struct LSTab: View {
    let icon: String?
    let label: String
    let on: Bool
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            HStack(spacing: 6) {
                if let i = icon { SF(i, "circle.fill").font(.system(size: 12, weight: .bold)) }
                Text(label).font(.jk(12, .heavy))
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.65))
            .padding(.horizontal, 14).frame(height: 28)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(TuiPress())
    }
}

struct LSTitle: View {
    let title: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.jk(24, .heavy)).foregroundColor(.white)
            Text(sub).font(.jk(10, .medium)).foregroundColor(.white.opacity(0.75))
        }
        .shadow(color: .black.opacity(0.7), radius: 3)
    }
}

struct LSSmallButton: View {
    let icon: String
    let label: String
    var on = false
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            HStack(spacing: 5) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold))
                Text(label).font(.jk(10, .semibold))
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.85))
            .padding(.horizontal, 9).frame(height: 26)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.45))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [text], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct RenameOverlay: View {
    @Binding var text: String
    let done: (Bool) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { done(false) }
            VStack(spacing: 8) {
                Text("RENAME").font(.jk(12, .heavy)).foregroundColor(.white)
                TextField("Name", text: $text).textFieldStyle(.roundedBorder).frame(width: 240)
                HStack(spacing: 8) {
                    LSSmallButton(icon: "xmark", label: "CANCEL") { done(false) }
                    LSSmallButton(icon: "checkmark", label: "OK", on: true) { done(true) }
                }
            }
            .padding(14).background(LS.panel).overlay(Rectangle().stroke(LS.orange, lineWidth: 1))
        }
    }
}
