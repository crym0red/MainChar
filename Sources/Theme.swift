import SwiftUI

extension Font {
    /// Plus Jakarta Sans, the typeface used across the app.
    static func jk(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        let n: String
        switch w {
        case .medium: n = "PlusJakartaSans-Medium"
        case .semibold: n = "PlusJakartaSans-SemiBold"
        case .bold: n = "PlusJakartaSans-Bold"
        case .heavy, .black: n = "PlusJakartaSans-ExtraBold"
        default: n = "PlusJakartaSans-Regular"
        }
        return .custom(n, size: size)
    }
}

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

func letterColor(_ s: String) -> Color {
    let pal: [Color] = [Color(red: 0.27, green: 0.60, blue: 0.93), Color(red: 1.0, green: 0.37, blue: 0.64),
                        Color(red: 0.62, green: 0.82, blue: 0.0), Color(red: 0.96, green: 0.55, blue: 0.10),
                        Color(red: 0.55, green: 0.40, blue: 0.95), Color(red: 0.10, green: 0.70, blue: 0.62)]
    return pal[Int(hueFor(s) * 997) % pal.count]
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
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("avatars3", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func fileURL(_ seed: String) -> URL {
        let safe = seed.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return dir.appendingPathComponent(safe + ".img")
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

    static var femNames: Set<String> { fem }
    static var malNames: Set<String> { mal }
    private static let fem: Set<String> = ["luna","mina","priya","sofia","sophia","emma","olivia","ava","mia","zoe","chloe","nora","lena","maya","ella","ivy","aria","lily","grace","hannah","nina","anna","sara","sarah","julia","kate","amy","ruby","tara","rosa","eva","isla","leah","jade","iris","vera","cleo","nia","ana","lucia","elena","amara","kira","yuki","sana","lila","rin","jess","jenny","lisa","maria","alice","bella","faith","holly","jasmine","kayla","laura","megan","nadia","paige","riley","willow","stella","hazel","june","ruth","cora","dani","ivana","mara","ines","noor","zara"]
    private static let mal: Set<String> = ["jonah","theo","dev","sam","max","leo","noah","liam","ethan","jack","finn","owen","eli","kai","ben","dan","tom","tim","nick","alex_m","marco","ravi","omar","hugo","cole","miles","jay","rex","ty","zane","felix","arlo","oscar","isaac","adam","luca","niko","remy","sean","gus","ian","joel","drew","carl","raj","ali","jin","tariq","diego","mateo","andre","victor","walt","nate"]

    private static let cool: [String] = [
        "cool-neon-blue-profile-picture-u9y9ydo971k9mdcf",
        "cool-profile-picture-minion-13pu7815v42uvrsg",
        "cool-smiley-profile-picture-6lqzc2aegkuxbini",
        "cool-profile-pictures-red-anime-fw4wgkj905tjeujb",
        "cool-neon-hoodie-profile-picture-vt4w54fxrvenydvu",
        "cool-profile-pictures-ken-kaneki-9lgr6mb8ammbblap",
        "cool-profile-pictures-panda-car-pswltzd2oewsl4wt",
        "cool-among-us-profile-picture-fhnahgd3g0lzviqv",
        "cool-profile-pictures-faceless-white-man-lne9zmhqlchlcpc7",
        "pink-angel-cool-profile-picture-wcjxfrrq0kjq98yb",
        "profile-picture-spirit-knight-k2ar09ggd5uvxwi1",
        "cool-cat-profile-pictures-ej5ie7iisas6xr7z",
        "cool-minimalist-profile-pictures-oib9ltzxmonk5hxz",
        "pink-bunny-cool-profile-picture-dc05663sotzgycnm",
        "cool-profile-picture-l0hzjr9omwan07nt",
        "cool-profile-picture-o6xweez7rh4347gx",
        "cool-profile-picture-n4gqyfx775vg4lxx",
        "cool-profile-picture-n8lf8k6jzs6ex36l",
        "cool-profile-picture-awled9dwo4qq2yv2",
        "cool-profile-picture-7d08ca58vaanj07r",
        "cool-profile-picture-ld8f4n1qemczkrig",
        "cool-profile-picture-kpwjvjw5434qfzo3",
        "cool-profile-picture-87h46gcobjl5e4xu",
        "cool-profile-picture-45bhdh56z2fjf5qv",
        "cool-profile-picture-7aecpj5vptd1a0ib",
        "cool-profile-picture-gdhlf31a1n7pcctk",
        "cool-profile-picture-g6nh5sv88vm84c8t",
        "cool-profile-picture-38op6ugjj3nkzjf0",
        "cool-profile-picture-ejbvgihibdts0jgt",
        "cute-tiktok-profile-pictures-1le4o5rz9oep6eky",
        "cool-profile-picture-9nthoux7dyev7lrl",
        "cool-profile-picture-ug9oc08q7nn527wu",
        "cool-profile-picture-1ecoo30f26bkr14o",
        "cool-profile-picture-mmg5lynaskhshnuo",
        "cool-profile-picture-d7un7z8trf41eu98",
        "cool-profile-picture-7fk2du857svpto74",
        "cool-profile-picture-461j83j9veimjjwr",
        "cool-profile-picture-orfj1dxf6nqeor92",
        "cool-profile-picture-77juffbwoivsi1s3",
        "cool-profile-picture-o0siqf9tzr6qyz04",
        "cool-profile-picture-yxroqlz004j409pm",
        "cool-profile-picture-a7nr00sputssb6m7",
        "cool-profile-picture-m32rqwm6zzf1osox",
        "cool-profile-picture-ovkcl8395dos1gs5",
        "cool-profile-picture-ioaknxj004tuzxpn",
        "cool-profile-picture-pjbik82u4xgo4i88",
        "cool-profile-picture-qej7j2ekuor93ss7",
        "cool-profile-picture-swtwohfekfqtvt1s",
        "cool-profile-picture-lyk4mvqrjewpoi92",
        "cool-profile-picture-kw8v1xchaodw2iiz",
        "cool-profile-picture-q9i2gvcrskxefbe9",
        "cool-profile-picture-2we7xmn0737hqgtu",
        "cool-profile-picture-6g9cru2ih9v1bok7",
        "cool-profile-picture-g3nzxs9mvrwkt7ew",
        "cool-profile-picture-j1zd9pqrtyswza7y",
        "cool-earth-profile-picture-ujntg8ghkjri61u9",
        "cool-profile-pictures-hoodie-cat-6dkl56hixhnq590g",
        "cool-profile-pictures-pink-crown-5lzmya5phb2bc4az",
        "cool-skull-profile-picture-j6r78po6xuuton85",
        "cool-profile-pictures-red-spiral-jrg6t4b3443jwsmw"
    ]

    /// A stable "cool" profile picture for a seed, from wallpapers.com's cool-profile-pictures set.
    static func portraitURL(_ seed: String) -> URL? {
        var h: UInt32 = 2166136261
        for u in seed.unicodeScalars { h = (h ^ u.value) &* 16777619 }
        return URL(string: "https://wallpapers.com/images/thumbnail/\(cool[Int(h % UInt32(cool.count))]).jpg")
    }

    private func download(seed: String, file: URL) async -> Data? {
        await acquire()
        defer { release() }
        if let u = AvatarLoader.portraitURL(seed) {
            for _ in 0..<2 {
                var req = URLRequest(url: u)
                req.timeoutInterval = 12
                if let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse {
                    if http.statusCode == 200, UIImage(data: data) != nil {
                        try? data.write(to: file)
                        return data
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
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

enum HK {
    static func h(_ s: String) -> UInt32 {
        var x: UInt32 = 5381
        for u in s.unicodeScalars { x = x &* 33 &+ u.value }
        return x
    }
    static let glyphs = ["terminal.fill", "cpu", "lock.open.fill", "ladybug.fill", "bolt.horizontal.fill",
                         "chevron.left.forwardslash.chevron.right", "shield.lefthalf.filled", "network",
                         "externaldrive.fill", "key.fill", "antenna.radiowaves.left.and.right", "wrench.and.screwdriver.fill"]
    static func neon(_ key: String) -> Color { Color(hue: Double(h(key.lowercased()) % 360) / 360, saturation: 0.85, brightness: 1) }
    static func glyph(_ key: String) -> String { glyphs[Int((h(key.lowercased()) >> 5) % UInt32(glyphs.count))] }
}

struct HackerAvatar: View {
    let key: String
    var size: CGFloat = 40

    var body: some View {
        let h = HK.h(key.lowercased())
        let hue = Double(h % 360) / 360
        let neon = Color(hue: hue, saturation: 0.85, brightness: 1)
        let deep = Color(hue: hue, saturation: 0.75, brightness: 0.24)
        let eyes = Int((h >> 9) % 4)
        let gear = Int((h >> 13) % 3)
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [deep, Color.black], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, sz in
                let w = sz.width, ht = sz.height
                var grid = Path()
                let step = w / 8
                for i in 1..<8 {
                    let v = step * CGFloat(i)
                    grid.move(to: CGPoint(x: v, y: 0)); grid.addLine(to: CGPoint(x: v, y: ht))
                    grid.move(to: CGPoint(x: 0, y: v)); grid.addLine(to: CGPoint(x: w, y: v))
                }
                ctx.stroke(grid, with: .color(neon.opacity(0.13)), lineWidth: 0.6)
                let dark = Color(white: 0.05)
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.10, y: ht * 0.70, width: w * 0.80, height: ht * 0.70)), with: .color(dark))
                ctx.stroke(Path(ellipseIn: CGRect(x: w * 0.10, y: ht * 0.70, width: w * 0.80, height: ht * 0.70)), with: .color(neon.opacity(0.55)), lineWidth: max(0.8, w * 0.012))
                let hood = CGRect(x: w * 0.23, y: ht * 0.14, width: w * 0.54, height: ht * 0.60)
                ctx.fill(Path(ellipseIn: hood), with: .color(dark))
                ctx.stroke(Path(ellipseIn: hood), with: .color(neon.opacity(0.7)), lineWidth: max(0.9, w * 0.015))
                if gear == 1 {
                    ctx.fill(Path(roundedRect: CGRect(x: w * 0.17, y: ht * 0.34, width: w * 0.09, height: ht * 0.22), cornerRadius: w * 0.03), with: .color(neon))
                    ctx.fill(Path(roundedRect: CGRect(x: w * 0.74, y: ht * 0.34, width: w * 0.09, height: ht * 0.22), cornerRadius: w * 0.03), with: .color(neon))
                    var band = Path(); band.addArc(center: CGPoint(x: w * 0.5, y: ht * 0.45), radius: w * 0.29, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
                    ctx.stroke(band, with: .color(neon), lineWidth: max(1, w * 0.02))
                } else if gear == 2 {
                    var peak = Path()
                    peak.move(to: CGPoint(x: w * 0.5, y: ht * 0.04)); peak.addLine(to: CGPoint(x: w * 0.40, y: ht * 0.20)); peak.addLine(to: CGPoint(x: w * 0.60, y: ht * 0.20)); peak.closeSubpath()
                    ctx.fill(peak, with: .color(neon.opacity(0.85)))
                }
                let face = CGRect(x: w * 0.31, y: ht * 0.27, width: w * 0.38, height: ht * 0.36)
                ctx.fill(Path(ellipseIn: face), with: .color(.black))
                let ey = ht * 0.42
                func glow(_ r: CGRect, _ corner: CGFloat) {
                    ctx.fill(Path(roundedRect: r.insetBy(dx: -w * 0.025, dy: -w * 0.025), cornerRadius: corner + w * 0.02), with: .color(neon.opacity(0.28)))
                    ctx.fill(Path(roundedRect: r, cornerRadius: corner), with: .color(neon))
                }
                switch eyes {
                case 0:
                    glow(CGRect(x: w * 0.36, y: ey, width: w * 0.09, height: ht * 0.05), w * 0.01)
                    glow(CGRect(x: w * 0.55, y: ey, width: w * 0.09, height: ht * 0.05), w * 0.01)
                case 1:
                    glow(CGRect(x: w * 0.34, y: ey - ht * 0.01, width: w * 0.32, height: ht * 0.06), w * 0.02)
                case 2:
                    glow(CGRect(x: w * 0.37, y: ey, width: w * 0.06, height: w * 0.06), w * 0.03)
                    glow(CGRect(x: w * 0.47, y: ey, width: w * 0.06, height: w * 0.06), w * 0.03)
                    glow(CGRect(x: w * 0.57, y: ey, width: w * 0.06, height: w * 0.06), w * 0.03)
                default:
                    glow(CGRect(x: w * 0.455, y: ey - ht * 0.01, width: w * 0.09, height: w * 0.09), w * 0.045)
                }
                if w >= 36 {
                    var y: CGFloat = 0
                    var lines = Path()
                    while y < ht { lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: w, y: y)); y += 3 }
                    ctx.stroke(lines, with: .color(.black.opacity(0.18)), lineWidth: 0.8)
                }
            }
            if size >= 56 {
                Image(systemName: HK.glyph(key)).font(.system(size: size * 0.16, weight: .bold))
                    .foregroundColor(neon).padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(neon.opacity(0.55), lineWidth: max(1, size * 0.022)))
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
            if let img = img {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } else if !photo {
                ZStack {
                    Circle().fill(T.card2)
                    Image(systemName: "newspaper.fill").font(.system(size: size * 0.42, weight: .semibold)).foregroundColor(T.blue)
                }
                .frame(width: size, height: size)
            } else {
                PortraitAvatar(key: key, size: size)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(ring ? T.blue : Color.clear, lineWidth: 2.5).padding(-1))
        .task(id: key) {
            guard photo, img == nil else { return }
            if let c = AvatarMem.cache.object(forKey: key as NSString) { img = c; return }
            if let custom = ProfileImages.load("avatar_" + key) {
                AvatarMem.cache.setObject(custom, forKey: key as NSString)
                img = custom
            }
        }
    }
}

/// Tap a character anywhere to open their profile sheet.
struct ProfileTap: ViewModifier {
    @EnvironmentObject var game: Game
    let handle: String
    @State private var npc: NPC?
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                if let n = game.s.npcs.first(where: { $0.handle == handle }), n.id != "newsdesk" { npc = n }
                else if handle != game.s.persona.handle, Crowd.looksLikeCrowd(handle) {
                    var st = game.s
                    let n = Crowd.npc(for: handle)
                    st.npcs.append(n)
                    game.s = st
                    npc = n
                }
            }
            .sheet(item: $npc) { NPCSheet(npc: $0).zoomed() }
    }
}

extension View {
    func profileTap(_ handle: String) -> some View { modifier(ProfileTap(handle: handle)) }
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
                .font(.jk(16, .bold))
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
            .font(.jk(12, .semibold))
            .foregroundColor(fg)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }
}

struct SectionTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.jk(20, .heavy)).foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyState: View {
    let emoji: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 8) {
            SymbolTile(emoji: emoji, size: 60)
            Text(title).font(.jk(18, .bold)).foregroundColor(.white)
            Text(detail).font(.jk(14)).foregroundColor(T.sub).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}

final class Nav: ObservableObject {
    @Published var tab = 0
    @Published var chat: String? = nil
    @Published var coin: String? = nil
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
