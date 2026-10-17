import SwiftUI
import PhotosUI

// MARK: - Style + image storage

enum StoryStyle {
    static let colors: [[Color]] = [
        [Color(red: 0.16, green: 0.16, blue: 0.18), Color(red: 0.09, green: 0.09, blue: 0.11)],
        [Color(red: 0.27, green: 0.60, blue: 0.93), Color(red: 0.12, green: 0.28, blue: 0.68)],
        [Color(red: 0.62, green: 0.85, blue: 0.20), Color(red: 0.12, green: 0.50, blue: 0.28)],
        [Color(red: 0.96, green: 0.55, blue: 0.10), Color(red: 0.82, green: 0.20, blue: 0.28)],
        [Color(red: 0.64, green: 0.36, blue: 0.93), Color(red: 0.90, green: 0.30, blue: 0.62)],
        [Color(red: 0.10, green: 0.55, blue: 0.62), Color(red: 0.05, green: 0.14, blue: 0.36)]
    ]

    static func gradient(_ i: Int) -> LinearGradient {
        let c = colors[abs(i) % colors.count]
        return LinearGradient(colors: c, startPoint: .top, endPoint: .bottom)
    }
}

enum StoryImages {
    static var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("stories", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func url(_ id: UUID) -> URL { dir.appendingPathComponent(id.uuidString + ".jpg") }

    static func save(_ img: UIImage, id: UUID) {
        let maxSide: CGFloat = 900
        let longest = max(img.size.width, img.size.height)
        let scale = longest > 0 ? min(1, maxSide / longest) : 1
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let out = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        if let d = out.jpegData(compressionQuality: 0.7) { try? d.write(to: url(id)) }
    }

    static func load(_ id: UUID) -> UIImage? { UIImage(contentsOfFile: url(id).path) }
    static func remove(_ id: UUID) { try? FileManager.default.removeItem(at: url(id)) }
}

struct StoryBackground: View {
    let bg: Int
    let id: UUID
    let hasImage: Bool

    var body: some View {
        StoryStyle.gradient(bg)
            .overlay {
                if hasImage, let img = StoryImages.load(id) {
                    GeometryReader { g in
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: g.size.width, height: g.size.height).clipped()
                    }
                }
            }
            .clipped()
    }
}

struct StoryThumb: View {
    let story: Story
    var width: CGFloat = 54
    var height: CGFloat = 72
    var body: some View {
        StoryBackground(bg: story.bg, id: story.id, hasImage: story.hasImage)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StoryOpen: Identifiable {
    let id = UUID()
    var story: UUID? = nil
}

private func circleButton(_ icon: String, size: CGFloat = 46, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: icon).font(.system(size: size * 0.4, weight: .bold)).foregroundColor(.white)
            .frame(width: size, height: size).background(Color.white.opacity(0.14)).clipShape(Circle())
    }
}

// MARK: - Container

struct StoriesFlow: View {
    @Environment(\.dismiss) private var dismiss
    enum Step: Equatable { case intro, create, view(UUID) }
    @State private var step: Step

    init(openStory: UUID? = nil) {
        if let o = openStory {
            _step = State(initialValue: .view(o))
        } else if UserDefaults.standard.bool(forKey: "clout.storiesIntro") {
            _step = State(initialValue: .create)
        } else {
            _step = State(initialValue: .intro)
        }
    }

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            switch step {
            case .intro:
                StoriesIntroView(onClose: { dismiss() }) {
                    UserDefaults.standard.set(true, forKey: "clout.storiesIntro")
                    step = .create
                }
            case .create:
                CreateStoryView(onClose: { dismiss() }) { id in step = .view(id) }
            case .view(let id):
                StoryViewer(storyID: id, onClose: { dismiss() })
            }
        }
    }
}

// MARK: - Intro

struct StoriesIntroView: View {
    var onClose: () -> Void
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                circleButton("xmark", size: 48, onClose)
            }
            .padding(.horizontal, 20).padding(.top, 10)

            ZStack {
                HStack(spacing: -22) {
                    badge("M", ring: T.lime)
                    badge("C", ring: T.blue)
                }
                Image(systemName: "sparkle").font(.system(size: 22)).foregroundColor(T.lime).offset(x: -92, y: -64)
                Image(systemName: "sparkle").font(.system(size: 22)).foregroundColor(T.blue).offset(x: 84, y: 62)
            }
            .padding(.top, 36)

            Text("Introducing").font(.system(size: 22, weight: .semibold)).padding(.top, 40)
            HStack(spacing: 10) {
                Text("MainChar Stories").font(.system(size: 32, weight: .heavy))
                Text("BETA").font(.system(size: 18, weight: .medium)).foregroundColor(T.blue)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(red: 0.07, green: 0.15, blue: 0.25)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 4)

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "star.fill").font(.system(size: 26)).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(T.lime).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Post in My World").font(.system(size: 22, weight: .medium))
                    Text("Only AI characters react and reply to your stories within your world context.")
                        .font(.system(size: 17)).foregroundColor(T.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 36)

            Spacer()
            BigButton(title: "Create a story", action: onCreate)
                .clipShape(Capsule()).padding(.horizontal, 24).padding(.bottom, 20)
        }
    }

    private func badge(_ letter: String, ring: Color) -> some View {
        Text(letter).font(.system(size: 44, weight: .bold)).foregroundColor(.white)
            .frame(width: 90, height: 90).background(T.blue).clipShape(Circle())
            .padding(6).background(T.bg).clipShape(Circle())
            .overlay(Circle().stroke(ring, lineWidth: 6))
    }
}

// MARK: - Create

struct CreateStoryView: View {
    @EnvironmentObject var game: Game
    var onClose: () -> Void
    var onPosted: (UUID) -> Void
    @State private var text = ""
    @State private var bg = 0
    @State private var image: UIImage? = nil
    @State private var pick: PhotosPickerItem? = nil
    @State private var audience = false
    @FocusState private var focused: Bool

    var body: some View {
        let st = game.s
        let can = (!text.trimmed.isEmpty || image != nil) && game.canAfford(1)
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                circleButton("xmark", size: 46, onClose)
                Text("Create a story").font(.system(size: 26, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 8)

            ZStack(alignment: .topTrailing) {
                ZStack {
                    StoryStyle.gradient(bg)
                    if let img = image {
                        GeometryReader { g in
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: g.size.width, height: g.size.height).clipped()
                        }
                        Color.black.opacity(0.2)
                    }
                    ZStack {
                        if text.isEmpty {
                            Text("Add some text…").font(.system(size: 32, weight: .bold)).foregroundColor(Color.white.opacity(0.5))
                        }
                        TextField("", text: $text, axis: .vertical)
                            .font(.system(size: 32, weight: .bold)).multilineTextAlignment(.center)
                            .foregroundColor(.white).focused($focused).lineLimit(1...8)
                            .onChange(of: text) { v in if v.count > 140 { text = String(v.prefix(140)) } }
                    }
                    .padding(.horizontal, 30)
                }
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .onTapGesture { focused = true }

                VStack(spacing: 14) {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Image(systemName: "photo").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                            .frame(width: 56, height: 56).background(Color.black.opacity(0.45)).clipShape(Circle())
                    }
                    circleButton("paintpalette.fill", size: 56) { bg = (bg + 1) % StoryStyle.colors.count }
                        .shadow(color: .black.opacity(0.3), radius: 2)
                    if image != nil {
                        circleButton("trash", size: 56) { image = nil; pick = nil }
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 56)
                Button { audience = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill").font(.system(size: 18)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(T.lime).clipShape(Circle())
                        Text("My World").font(.system(size: 20, weight: .medium)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(T.card2).clipShape(Capsule())
                }
                Button(action: post) {
                    HStack(spacing: 8) {
                        Text("Post").font(.system(size: 20, weight: .medium))
                        Text("−1").font(.system(size: 20, weight: .bold)).foregroundColor(T.gold)
                        Image(systemName: "bolt.fill").foregroundColor(T.gold)
                    }
                    .foregroundColor(can ? .white : Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(can ? T.blue : Color.white.opacity(0.18)).clipShape(Capsule())
                }
                .disabled(!can)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .onChange(of: pick) { item in
            guard let item = item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: d) {
                    image = ui
                }
            }
        }
        .sheet(isPresented: $audience) { AudienceSheet() }
    }

    private func post() {
        let id = UUID()
        if let img = image { StoryImages.save(img, id: id) }
        focused = false
        if game.postStory(id: id, text: text, bg: bg, hasImage: image != nil) != nil {
            onPosted(id)
        } else if image != nil {
            StoryImages.remove(id)
        }
    }
}

// MARK: - Audience sheet

struct AudienceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.white.opacity(0.3)).frame(width: 48, height: 5).padding(.top, 8)
            Image(systemName: "star.fill").font(.system(size: 56)).foregroundColor(.white)
                .frame(width: 130, height: 130).background(T.lime).clipShape(Circle()).padding(.top, 10)
            Text("My World").font(.system(size: 32, weight: .bold))
            Text("Only your characters in your world context can interact with this story.")
                .font(.system(size: 19)).foregroundColor(T.sub).multilineTextAlignment(.center).padding(.horizontal, 20)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundColor(T.blue)
                VStack(alignment: .leading, spacing: 6) {
                    Text("My World Characters").font(.system(size: 22, weight: .semibold))
                    Text("These are characters that belong to your world.").font(.system(size: 18)).foregroundColor(T.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .background(T.card2)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            BigButton(title: "Got it") { dismiss() }.clipShape(Capsule())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.card.ignoresSafeArea())
        .presentationDetents([.height(580)])
    }
}

// MARK: - Viewer

struct StoryViewer: View {
    @EnvironmentObject var game: Game
    let storyID: UUID
    var onClose: () -> Void
    @State private var progress: CGFloat = 0
    @State private var showComments = false
    @State private var audience = false
    @State private var confirmDelete = false

    var body: some View {
        let st = game.s
        let story = st.ex.stories.first { $0.id == storyID }
        ZStack {
            if let story = story {
                StoryBackground(bg: story.bg, id: story.id, hasImage: story.hasImage).ignoresSafeArea()
                Color.black.opacity(0.2).ignoresSafeArea()
                if !story.text.isEmpty {
                    Text(story.text).font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                        .multilineTextAlignment(.center).padding(.horizontal, 28)
                        .shadow(color: .black.opacity(0.35), radius: 4)
                }
                VStack(spacing: 14) {
                    progressBar
                    header(st)
                    Spacer()
                    bottom(story, st)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
            } else {
                VStack(spacing: 16) {
                    Text("This story is gone.").font(.system(size: 18, weight: .semibold))
                    BigButton(title: "Close", action: onClose).padding(.horizontal, 60)
                }
            }
        }
        .sheet(isPresented: $showComments) { StoryCommentsSheet(storyID: storyID) }
        .sheet(isPresented: $audience) { AudienceSheet() }
        .alert("Delete this story?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { game.deleteStory(storyID); onClose() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { withAnimation(.linear(duration: 14)) { progress = 1 } }
    }

    private var progressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.28))
                Capsule().fill(Color.white.opacity(0.9)).frame(width: g.size.width * progress)
            }
        }
        .frame(height: 5)
    }

    private func header(_ st: GameState) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 62)
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(T.blue)
                    .background(Circle().fill(Color.black.opacity(0.6))).offset(x: 4, y: 4)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(st.persona.name).font(.system(size: 22, weight: .bold)).lineLimit(1)
                    if st.followers >= 10000 { VerifiedSeal(size: 18) }
                }
                Text("@\(st.persona.handle)").font(.system(size: 17)).foregroundColor(T.sub).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button { audience = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 12)
                .background(T.lime).clipShape(Capsule())
            }
            Menu {
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete story", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    .frame(width: 46, height: 46).background(Color.black.opacity(0.45)).clipShape(Circle())
            }
            circleButton("xmark", size: 46, onClose)
        }
    }

    private func bottom(_ story: Story, _ st: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let c = story.comments.first {
                HStack(alignment: .top, spacing: 12) {
                    Avatar(emoji: c.emoji, key: c.handle, size: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(c.name).font(.system(size: 18, weight: .bold)).lineLimit(1)
                            Text("@\(c.handle)").font(.system(size: 16)).foregroundColor(T.sub).lineLimit(1)
                        }
                        mentionText(c.text).font(.system(size: 20))
                    }
                }
                if story.comments.count > 1 {
                    HStack(spacing: 12) {
                        HStack(spacing: -14) {
                            ForEach(Array(story.comments.dropFirst().prefix(3))) { o in
                                Avatar(emoji: o.emoji, key: o.handle, size: 36)
                                    .overlay(Circle().stroke(Color.black.opacity(0.7), lineWidth: 2))
                            }
                        }
                        .frame(minWidth: 50, alignment: .leading)
                        Text("View other \(story.comments.count - 1) comments")
                            .font(.system(size: 17)).foregroundColor(T.sub)
                    }
                }
            }
            HStack(spacing: 12) {
                Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 46)
                Text("Add a comment…").font(.system(size: 20)).foregroundColor(T.sub)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 26)).foregroundColor(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showComments = true }
    }
}

// MARK: - Comments sheet

struct StoryCommentsSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let storyID: UUID
    @State private var text = ""
    @State private var replyTo: String? = nil
    @State private var liked: Set<UUID> = []
    @State private var starred: Set<UUID> = []
    @State private var hint = true
    @FocusState private var focus: Bool

    var body: some View {
        let st = game.s
        let story = st.ex.stories.first { $0.id == storyID }
        let comments = story?.comments ?? []
        VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.3)).frame(width: 48, height: 5).padding(.top, 8).padding(.bottom, 10)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            Avatar(emoji: st.persona.emoji, key: st.persona.handle, size: 56)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text(st.persona.name).font(.system(size: 22, weight: .bold))
                                    if st.followers >= 10000 { VerifiedSeal(size: 18) }
                                }
                                Text("@\(st.persona.handle)").font(.system(size: 16)).foregroundColor(T.sub)
                            }
                        }
                        if let t = story?.text, !t.isEmpty { Text(t).font(.system(size: 22, weight: .medium)) }
                        Divider().background(Color.white.opacity(0.15))
                        Text("Comments (\(comments.count))").font(.system(size: 22, weight: .semibold))
                        ForEach(comments) { c in row(c).id(c.id) }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 12)
                }
                .onChange(of: comments.count) { _ in
                    withAnimation { if let l = comments.last { proxy.scrollTo(l.id, anchor: .bottom) } }
                }
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.card.ignoresSafeArea())
        .presentationDetents([.fraction(0.78), .large])
    }

    private func row(_ c: Comment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(emoji: c.emoji, key: c.handle, size: 54)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(c.name).font(.system(size: 20, weight: .bold)).lineLimit(1)
                    if c.verified { VerifiedSeal(size: 15) }
                    Text("@\(c.handle)").font(.system(size: 17)).foregroundColor(T.sub).lineLimit(1)
                }
                mentionText(c.text).font(.system(size: 20))
                HStack(spacing: 14) {
                    Button {
                        if liked.contains(c.id) { liked.remove(c.id) } else { liked.insert(c.id) }
                    } label: {
                        Image(systemName: liked.contains(c.id) ? "heart.fill" : "heart")
                            .foregroundColor(liked.contains(c.id) ? T.red : T.sub)
                    }
                    Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
                    Button {
                        replyTo = c.handle
                        text = "@\(c.handle) "
                        focus = true
                    } label: { Text("Reply").foregroundColor(T.sub) }
                }
                .font(.system(size: 18))
            }
            Spacer(minLength: 0)
            Button {
                if starred.contains(c.id) { starred.remove(c.id) } else { starred.insert(c.id) }
            } label: {
                Image(systemName: starred.contains(c.id) ? "star.fill" : "star")
                    .font(.system(size: 20)).foregroundColor(starred.contains(c.id) ? T.gold : T.sub)
            }
            .padding(.top, 38)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if hint {
                HStack(spacing: 6) {
                    Text("Replying in Private Stories uses").foregroundColor(T.sub)
                    Text("1").foregroundColor(T.gold).fontWeight(.bold)
                    Image(systemName: "bolt.fill").foregroundColor(T.gold).font(.system(size: 14))
                    Spacer()
                    Button { hint = false } label: { Image(systemName: "xmark").foregroundColor(T.sub) }
                }
                .font(.system(size: 17))
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(T.card2).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            HStack(spacing: 12) {
                Button { text = "this is so good" } label: {
                    Image(systemName: "sparkles").font(.system(size: 22)).foregroundColor(.white)
                        .frame(width: 54, height: 54).background(T.card2).clipShape(Circle())
                }
                HStack {
                    TextField("Add a comment…", text: $text).focused($focus).font(.system(size: 20))
                    if !text.trimmed.isEmpty {
                        Button(action: send) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundColor(T.blue)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(T.card2).clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }

    private func send() {
        if game.commentOnStory(storyID, text: text, replyTo: replyTo) {
            text = ""
            replyTo = nil
            focus = false
        }
    }
}
