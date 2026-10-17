import SwiftUI

/// Maps stored emoji strings to SF Symbols so the UI never renders emoji.
enum SymbolMap {
    static let table: [String: String] = [
        "🔥": "flame.fill", "👀": "eye.fill", "👑": "crown.fill", "🚫": "nosign", "💛": "heart.fill", "🙂": "person.fill",
        "☕": "cup.and.saucer.fill", "📈": "chart.line.uptrend.xyaxis", "🕶": "eyeglasses", "🥹": "heart.fill", "🎭": "theatermasks.fill",
        "📰": "newspaper.fill", "🏆": "trophy.fill", "🙄": "face.dashed", "📸": "camera.fill", "💀": "bolt.slash.fill",
        "🤝": "hand.raised.fill", "👥": "person.2.fill", "🌟": "star.fill", "💬": "bubble.left.and.bubble.right.fill",
        "🌐": "globe", "🚀": "paperplane.fill", "⚡": "bolt.fill", "🎉": "party.popper.fill", "💪": "figure.strengthtraining.traditional",
        "😒": "face.dashed", "🌻": "sun.max.fill", "🫶": "heart.fill", "💼": "briefcase.fill", "🎤": "mic.fill", "💝": "gift.fill",
        "🕊": "leaf.fill", "🏁": "flag.checkered", "🕵": "magnifyingglass", "📜": "scroll.fill", "🗑": "trash.fill",
        "🧸": "teddybear.fill", "🧵": "link", "🤡": "theatermasks.fill", "🌀": "tornado", "🦝": "pawprint.fill", "🧨": "burst.fill",
        "⚔": "bolt.shield.fill", "💻": "laptopcomputer", "🔔": "bell.fill", "⭐": "star.fill", "🌊": "water.waves", "📣": "megaphone.fill",
        "🔴": "record.circle.fill", "😈": "flame.fill", "🍿": "popcorn.fill", "👇": "arrow.down.circle.fill", "🌍": "globe.americas.fill",
        "😎": "sunglasses.fill", "🗡": "bolt.shield.fill", "😭": "drop.fill", "💎": "diamond.fill", "📡": "antenna.radiowaves.left.and.right",
        "🔮": "sparkles", "🥱": "moon.zzz.fill", "👎": "hand.thumbsdown.fill", "🧂": "circle.grid.cross.fill", "🌈": "rainbow",
        "🤫": "speaker.slash.fill", "🐍": "scribble.variable", "💰": "dollarsign.circle.fill", "🏢": "building.2.fill", "🥂": "wineglass.fill",
        "👹": "flame.fill", "✨": "sparkles", "🧙": "wand.and.stars", "🏫": "building.columns.fill", "🦸": "bolt.shield.fill",
        "🏘": "house.fill", "📺": "tv.fill", "🚲": "bicycle", "🗳": "checkmark.rectangle.fill", "🧛": "moon.stars.fill", "🍥": "fork.knife",
        "💡": "lightbulb.fill", "✅": "checkmark.circle.fill", "🌱": "leaf.fill", "💯": "100.circle.fill", "🎯": "scope", "💣": "burst.fill",
        "🧪": "testtube.2", "🧬": "atom", "🔦": "flashlight.on.fill", "🛡": "shield.lefthalf.filled", "🧼": "bubbles.and.sparkles.fill",
        "🥄": "fork.knife", "❤": "heart.fill", "💢": "exclamationmark.triangle.fill", "🤣": "face.smiling.fill", "😘": "heart.fill",
        "😂": "face.smiling.fill", "🥰": "heart.fill", "🌶": "flame.fill", "💅": "sparkles", "🙏": "hands.clap.fill", "✍": "pencil.line",
        "🛠": "wrench.and.screwdriver.fill", "🤷": "questionmark.circle.fill", "💥": "burst.fill", "🗯": "bubble.left.fill",
        "🚨": "light.beacon.max.fill", "🗣": "waveform", "🌪": "tornado", "📉": "chart.line.downtrend.xyaxis", "💸": "banknote.fill",
        "🕰": "clock.fill", "📹": "video.fill", "🎬": "film.fill", "😔": "cloud.rain.fill", "🌷": "leaf.fill", "🍪": "circle.fill",
        "😤": "flame.fill", "📢": "megaphone.fill", "🫢": "eye.slash.fill", "🏦": "building.columns.fill", "🎲": "dice.fill",
        "🤪": "face.smiling.fill", "👤": "person.fill", "🎸": "guitars.fill", "🎧": "headphones", "🎓": "graduationcap.fill",
        "🎀": "gift.fill", "🏀": "basketball.fill", "🍵": "cup.and.saucer.fill", "🌆": "building.2.fill", "🖤": "heart.fill",
        "🍜": "fork.knife", "🌙": "moon.fill", "🐉": "flame.fill", "🦉": "moon.stars.fill", "⏪": "backward.fill", "🔒": "lock.fill",
        "🔓": "lock.open.fill", "📦": "shippingbox.fill", "🧑": "person.fill", "🤖": "cpu", "👻": "eye.slash.fill", "🔑": "key.fill",
        "🎮": "gamecontroller.fill", "📱": "iphone", "🔗": "link", "🗂": "folder.fill", "🏷": "tag.fill", "🥳": "party.popper.fill",
        "😅": "face.smiling.fill", "😬": "face.dashed", "🙃": "face.smiling.fill", "🤔": "questionmark.circle.fill", "😡": "flame.fill",
        "😱": "exclamationmark.triangle.fill", "🥲": "face.smiling.fill", "🫡": "hand.raised.fill", "💔": "heart.slash.fill", "🔁": "arrow.2.squarepath"
    ]

    static func strip(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{FE0F}", with: "").replacingOccurrences(of: "\u{200D}", with: "")
    }

    static func name(_ emoji: String) -> String {
        let e = strip(emoji.trimmingCharacters(in: .whitespaces))
        if let n = table[e] { return n }
        if let f = e.first, let n = table[String(f)] { return n }
        return "sparkle"
    }

    static func isEmoji(_ c: Character) -> Bool {
        guard let u = c.unicodeScalars.first else { return false }
        return u.value > 0x2100 && (u.properties.isEmojiPresentation || u.properties.isEmoji && c.unicodeScalars.count > 1 || u.value >= 0x1F000 || (0x2600...0x27BF).contains(u.value) || (0x2B00...0x2BFF).contains(u.value))
    }
}

extension String {
    /// Text with emoji characters removed (arrows and plain symbols stay).
    var noEmoji: String {
        let out = String(self.filter { !SymbolMap.isEmoji($0) })
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

struct EmojiIcon: View {
    let emoji: String
    var size: CGFloat = 24
    var color: Color = .white
    var body: some View {
        Image(systemName: SymbolMap.name(emoji))
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .frame(minWidth: size, minHeight: size)
    }
}

/// Rounded tile with a symbol, used where a big emoji used to sit.
struct SymbolTile: View {
    let emoji: String
    var size: CGFloat = 44
    var tint: Color = T.blue
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(tint.opacity(0.18))
            Image(systemName: SymbolMap.name(emoji)).font(.system(size: size * 0.46, weight: .semibold)).foregroundColor(tint)
        }
        .frame(width: size, height: size)
    }
}
