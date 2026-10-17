import SwiftUI
import PhotosUI

// MARK: - Profile image storage

enum ProfileImages {
    private static let cache = NSCache<NSString, UIImage>()

    static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static func url(_ name: String) -> URL {
        let safe = name.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }.joined()
        return dir.appendingPathComponent(safe + ".jpg")
    }

    static func save(_ img: UIImage, name: String, maxSide: CGFloat) {
        let longest = max(img.size.width, img.size.height)
        let scale = longest > 0 ? min(1, maxSide / longest) : 1
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        if let d = out.jpegData(compressionQuality: 0.8) { try? d.write(to: url(name)) }
        cache.setObject(out, forKey: name as NSString)
    }

    static func load(_ name: String) -> UIImage? {
        if let c = cache.object(forKey: name as NSString) { return c }
        guard let i = UIImage(contentsOfFile: url(name).path) else { return nil }
        cache.setObject(i, forKey: name as NSString)
        return i
    }
}

private func loadPicked(_ item: PhotosPickerItem?) async -> UIImage? {
    guard let item = item, let d = try? await item.loadTransferable(type: Data.self) else { return nil }
    return UIImage(data: d)
}

struct ProfileBanner: View {
    var body: some View {
        if let img = ProfileImages.load("banner") {
            GeometryReader { g in
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height).clipped()
            }
        } else {
            T.blue
        }
    }
}

// MARK: - Edit profile

struct EditProfileSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var p = Persona(name: "", handle: "", bio: "", emoji: "🙂", vibe: .clown)
    @State private var banner: UIImage? = nil
    @State private var avatar: UIImage? = nil
    @State private var bannerPick: PhotosPickerItem? = nil
    @State private var avatarPick: PhotosPickerItem? = nil
    @State private var bannerChanged = false
    @State private var avatarChanged = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Edit Profile").font(.jk(24, .semibold))
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .bottom) {
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let b = banner {
                                    GeometryReader { g in
                                        Image(uiImage: b).resizable().scaledToFill()
                                            .frame(width: g.size.width, height: g.size.height).clipped()
                                    }
                                } else {
                                    LinearGradient(colors: [T.blue, Color(red: 0.15, green: 0.30, blue: 0.62)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            PhotosPicker(selection: $bannerPick, matching: .images) {
                                Image(systemName: "pencil").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 48, height: 48).background(Color.black.opacity(0.6)).clipShape(Circle())
                            }
                            .padding(12)
                        }
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let a = avatar {
                                    Image(uiImage: a).resizable().scaledToFill()
                                        .frame(width: 104, height: 104).clipShape(Circle())
                                } else {
                                    Avatar(emoji: p.emoji, key: p.handle, size: 104)
                                }
                            }
                            .overlay(Circle().stroke(T.bg, lineWidth: 5))
                            PhotosPicker(selection: $avatarPick, matching: .images) {
                                Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 38, height: 38).background(T.blue).clipShape(Circle())
                            }
                        }
                        .offset(y: 50)
                    }
                    .padding(.bottom, 56)

                    label("Character name")
                    TextField("Name", text: $p.name)
                        .font(.jk(22)).padding(.horizontal, 20).padding(.vertical, 18)
                        .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    label("Handle").foregroundColor(T.sub.opacity(0.7)).padding(.top, 10)
                    HStack(spacing: 10) {
                        Text("@").foregroundColor(T.sub)
                        Text(p.handle).foregroundColor(T.sub)
                        Spacer()
                    }
                    .font(.jk(22)).padding(.horizontal, 20).padding(.vertical, 18)
                    .background(T.card).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text("Editing your handle is temporarily disabled.").font(.jk(16)).foregroundColor(T.sub.opacity(0.7))

                    label("Profile bio").padding(.top, 10)
                    TextEditor(text: $p.bio)
                        .scrollContentBackground(.hidden)
                        .font(.jk(22)).frame(height: 150).padding(12)
                        .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onChange(of: p.bio) { v in if v.count > 1000 { p.bio = String(v.prefix(1000)) } }
                    Text("\(p.bio.count)/1000").font(.jk(17)).foregroundColor(T.sub)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    label("Vibe").padding(.top, 10)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Vibe.allCases) { v in
                                Button { p.vibe = v } label: {
                                    Text("\(v.emoji) \(v.label)").font(.jk(17, .semibold)).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(p.vibe == v ? T.blue : T.card2).clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }

            BigButton(title: "Save", enabled: !p.name.trimmed.isEmpty, action: save)
                .clipShape(Capsule()).padding(.horizontal, 16).padding(.bottom, 10)
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear {
            p = game.s.persona
            banner = ProfileImages.load("banner")
        }
        .onChange(of: bannerPick) { item in
            Task { if let i = await loadPicked(item) { banner = i; bannerChanged = true } }
        }
        .onChange(of: avatarPick) { item in
            Task { if let i = await loadPicked(item) { avatar = i; avatarChanged = true } }
        }
    }

    private func label(_ t: String) -> Text {
        Text(t).font(.jk(22, .medium)).foregroundColor(Color.white.opacity(0.8))
    }

    private func save() {
        game.updatePersona(p)
        if avatarChanged, let a = avatar {
            ProfileImages.save(a, name: "avatar_" + p.handle, maxSide: 400)
            AvatarMem.cache.setObject(a, forKey: p.handle as NSString)
        }
        if bannerChanged, let b = banner {
            ProfileImages.save(b, name: "banner", maxSide: 1200)
        }
        game.profileRev += 1
        dismiss()
    }
}

// MARK: - All stories

struct AllStoriesSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var open: StoryOpen? = nil

    var body: some View {
        let stories = game.s.ex.stories
        VStack(spacing: 0) {
            ZStack {
                Text("Your Stories").font(.jk(24, .semibold))
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 8)
            ScrollView {
                if stories.isEmpty {
                    EmptyState(emoji: "📸", title: "No stories yet", detail: "Tap Add story on the feed.").padding(.top, 60)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(stories) { s in
                        Button { open = StoryOpen(story: s.id) } label: {
                            ZStack(alignment: .bottomLeading) {
                                StoryThumb(story: s, width: 110, height: 170)
                                    .frame(maxWidth: .infinity)
                                Text(s.text).font(.jk(14)).foregroundColor(.white).lineLimit(1).padding(8)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .fullScreenCover(item: $open) { o in StoriesFlow(openStory: o.story).zoomed() }
    }
}

// MARK: - Characters

struct CharactersSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var pick: NPC? = nil

    var body: some View {
        let cast = game.s.npcs.filter { $0.id != "newsdesk" }
        VStack(spacing: 0) {
            ZStack {
                Text("My characters").font(.jk(24, .semibold))
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(cast) { n in
                        Button { pick = n } label: {
                            HStack(spacing: 14) {
                                Avatar(emoji: n.emoji, key: n.handle, size: 56)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.name).font(.jk(20, .semibold)).foregroundColor(.white)
                                    Text("@\(n.handle) · \(n.trait.rawValue.capitalized)").font(.jk(15)).foregroundColor(T.sub)
                                }
                                Spacer()
                                Text("\(n.affinity)%").font(.jk(17, .semibold)).foregroundColor(T.lime)
                                Image(systemName: "chevron.right").foregroundColor(T.sub)
                            }
                            .padding(14).background(T.card)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(item: $pick) { NPCSheet(npc: $0).zoomed() }
    }
}

// MARK: - In-game settings

struct GameSettingsView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var aiSheet = false
    @State private var chars = false
    @State private var confirmDelete = false
    @State private var confirmLeave = false

    private func username(_ st: GameState) -> String {
        let raw = st.id.uuidString.replacingOccurrences(of: "-", with: "")
        return String(raw.prefix(10))
    }

    var body: some View {
        let st = game.s
        VStack(spacing: 0) {
            ZStack {
                Text("Settings").font(.jk(24, .semibold))
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header("Account details")
                    group {
                        row("person.crop.circle.badge.checkmark", "Username", trailing: username(st), icon2: "doc.on.doc.fill") {
                            UIPasteboard.general.string = username(st)
                            game.showToast("Username copied")
                        }
                        divider
                        row("sparkles", "AI & data", chevron: true) { aiSheet = true }
                    }
                    group {
                        row("person.3.fill", "My characters", chevron: true) { chars = true }
                    }
                    header("Gameplay").padding(.top, 8)
                    group {
                        row("bolt.fill", "Get free energy", trailing: game.canRefill ? "Ready" : "Used", chevron: true) {
                            if game.canRefill { game.refill(); game.showToast("Energy refilled") }
                            else { game.showToast("Free refill is on cooldown") }
                        }
                        divider
                        row("arrow.2.squarepath", "Auto-use Gems for Energy", trailing: (st.ex.autoGems ?? false) ? "On" : "Off") {
                            var s2 = game.s
                            s2.ex.autoGems = !(s2.ex.autoGems ?? false)
                            game.s = s2
                        }
                        divider
                        row("character.bubble.fill", "Language", trailing: "English") {}
                    }
                    group {
                        row("rectangle.portrait.and.arrow.right", "Leave World") { confirmLeave = true }
                        divider
                        row("figure.walk.departure", "Log out") { leave() }
                        divider
                        row("trash.fill", "Delete Account", tint: T.red) { confirmDelete = true }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 40)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .toastOverlay()
        .sheet(isPresented: $aiSheet) { SettingsSheet().zoomed() }
        .fullScreenCover(isPresented: $chars) { CharactersSheet().zoomed() }
        .alert("Leave this world?", isPresented: $confirmLeave) {
            Button("Leave") { leave() }
            Button("Stay", role: .cancel) {}
        } message: { Text("Your progress is saved.") }
        .alert("Delete account?", isPresented: $confirmDelete) {
            Button("Delete everything", role: .destructive) { game.resetAll(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This erases every world and save on this device.") }
    }

    private func leave() {
        dismiss()
        game.exitToHub()
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.leading, 56)
    }

    private func header(_ t: String) -> some View {
        Text(t).font(.jk(20)).foregroundColor(T.sub).padding(.top, 4)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 18)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1.5))
    }

    private func row(_ icon: String, _ title: String, trailing: String? = nil, icon2: String? = nil,
                     chevron: Bool = false, tint: Color = .white, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(tint == .white ? T.sub : tint)
                    .frame(width: 34)
                Text(title).font(.jk(22)).foregroundColor(tint)
                Spacer(minLength: 6)
                if let t = trailing { Text(t).font(.jk(21)).foregroundColor(T.sub) }
                if let i2 = icon2 { Image(systemName: i2).font(.system(size: 24)).foregroundColor(T.sub) }
                if chevron { Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold)).foregroundColor(T.sub) }
            }
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
    }
}
