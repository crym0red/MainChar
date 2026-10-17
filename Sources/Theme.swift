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

// MARK: - Profile pictures (illustrated faces from the free DiceBear API, cached on disk)

enum AvatarMem {
    static let cache = NSCache<NSString, UIImage>()
}

actor AvatarLoader {
    static let shared = AvatarLoader()
    private var tasks: [String: Task<Data?, Never>] = [:]
    private var failedAt: [String: Date] = [:]
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    static var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func fileURL(_ seed: String) -> URL {
        let safe = seed.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return dir.appendingPathComponent(safe + ".png")
    }

    func image(seed: String) async -> UIImage? {
        let file = AvatarLoader.fileURL(seed)
        if let d = try? Data(contentsOf: file), let img = UIImage(data: d) { return img }
        if let f = failedAt[seed], Date().timeIntervalSince(f) < 45 { return nil }
        let task: Task<Data?, Never>
        if let t = tasks[seed] { task = t } else {
            task = Task { await self.download(seed: seed, file: file) }
            tasks[seed] = task
        }
        let data = await task.value
        tasks[seed] = nil
        if let d = data, let img = UIImage(data: d) { return img }
        failedAt[seed] = Date()
        return nil
    }

    private func acquire() async {
        if active < 3 { active += 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if !waiters.isEmpty { waiters.removeFirst().resume() } else { active -= 1 }
    }

    private func download(seed: String, file: URL) async -> Data? {
        await acquire()
        defer { release() }
        var comps = URLComponents(string: "https://api.dicebear.com/9.x/lorelei/png")!
        comps.queryItems = [
            URLQueryItem(name: "seed", value: seed),
            URLQueryItem(name: "size", value: "192"),
            URLQueryItem(name: "backgroundColor", value: "b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf"),
            URLQueryItem(name: "backgroundType", value: "solid")
        ]
        guard let url = comps.url else { return nil }
        for attempt in 0..<3 {
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            if let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse {
                if http.statusCode == 200, UIImage(data: data) != nil {
                    try? data.write(to: file)
                    return data
                }
                if http.statusCode == 429 { try? await Task.sleep(nanoseconds: UInt64(1_200_000_000 * (attempt + 1))); continue }
                return nil
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
        return nil
    }
}

struct Avatar: View {
    let emoji: String
    let key: String
    var size: CGFloat = 40
    var ring: Bool = false
    var photo: Bool = true
    @State private var img: UIImage?

    init(emoji: String, key: String, size: CGFloat = 40, ring: Bool = false, photo: Bool = true) {
        self.emoji = emoji; self.key = key; self.size = size; self.ring = ring; self.photo = photo
        _img = State(initialValue: photo ? AvatarMem.cache.object(forKey: key as NSString) : nil)
    }

    var body: some View {
        ZStack {
            Circle().fill(Color(hue: hueFor(key), saturation: 0.45, brightness: 0.48))
            if let img = img {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Text(emoji).font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring ? T.blue : Color.clear, lineWidth: 2.5))
        .task(id: key) {
            guard photo, img == nil else { return }
            if let c = AvatarMem.cache.object(forKey: key as NSString) { img = c; return }
            if let loaded = await AvatarLoader.shared.image(seed: key) {
                AvatarMem.cache.setObject(loaded, forKey: key as NSString)
                img = loaded
            }
        }
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

func stableNum(_ s: String, _ lo: Int, _ hi: Int) -> Int {
    var h: UInt32 = 5381
    for u in s.unicodeScalars { h = h &* 33 &+ u.value }
    return lo + Int(h % UInt32(max(1, hi - lo + 1)))
}

/// Text where @mentions are blue.
func mentionText(_ s: String) -> Text {
    let words = s.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    var out = Text("")
    for (i, w) in words.enumerated() {
        let piece = w.hasPrefix("@") ? Text(w).foregroundColor(T.blue) : Text(w)
        out = out + piece + Text(i < words.count - 1 ? " " : "")
    }
    return out
}
