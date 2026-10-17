import SwiftUI

enum T {
    static let bg = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let card = Color(red: 0.15, green: 0.15, blue: 0.17)
    static let card2 = Color(red: 0.20, green: 0.20, blue: 0.22)
    static let blue = Color(red: 0.27, green: 0.60, blue: 0.93)
    static let orange = Color(red: 0.96, green: 0.55, blue: 0.10)
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.20)
    static let lime = Color(red: 0.62, green: 0.85, blue: 0.20)
    static let red = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let sub = Color.white.opacity(0.6)
}

func hueFor(_ s: String) -> Double {
    var h: UInt32 = 5381
    for u in s.unicodeScalars { h = h &* 33 &+ u.value }
    return Double(h % 360) / 360
}

struct Avatar: View {
    let emoji: String
    let key: String
    var size: CGFloat = 40
    var ring: Bool = false
    var body: some View {
        ZStack {
            Circle().fill(Color(hue: hueFor(key), saturation: 0.45, brightness: 0.48))
            Text(emoji).font(.system(size: size * 0.5))
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(ring ? T.blue : Color.clear, lineWidth: 2.5))
    }
}

struct VerifiedSeal: View {
    var size: CGFloat = 14
    var body: some View {
        Image(systemName: "checkmark.seal.fill").font(.system(size: size)).foregroundColor(T.blue)
    }
}

struct Bar: View {
    var value: Double
    var color: Color = T.blue
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(color).frame(width: max(0, min(1, value)) * g.size.width)
            }
        }
        .frame(height: height)
    }
}

extension View {
    func card(_ pad: CGFloat = 14) -> some View {
        self.padding(pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct BigButton: View {
    let title: String
    var color: Color = T.blue
    var enabled: Bool = true
    var textColor: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(enabled ? color : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!enabled)
    }
}

struct Chip: View {
    let text: String
    var color: Color = T.card2
    var fg: Color = .white
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }
}

struct SectionTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyState: View {
    let emoji: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 44))
            Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(detail).font(.system(size: 14)).foregroundColor(T.sub).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}

final class Nav: ObservableObject {
    @Published var tab = 0
    @Published var chat: String? = nil
}

func clockString(_ secs: Int) -> String { String(format: "%d:%02d", secs / 60, secs % 60) }
