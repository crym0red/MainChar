import SwiftUI

struct SamplePost: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let text: String
    let meta: String
    var verified = true
    var look = AvatarLook()

    static let all: [SamplePost] = [
        SamplePost(name: "Cert Daily", handle: "certdaily", text: "You just signed 40 apps in one night. Apple noticed. Is your certificate about to get revoked?", meta: "4:05 PM · 10/14/26 · 150k views"),
        SamplePost(name: "Scene Wire", handle: "scenewire", text: "NEW NAME IN THE SCENE! Your tweak hit 100k installs in 3 days. The repo servers crashed twice!", meta: "2:45 PM · 10/12/26 · 325k views"),
        SamplePost(name: "kernel_wizard", handle: "kernel_wizard", text: "The most evil dylib maker has beef with some kid at the signing service. Popcorn ready.", meta: "9:12 AM · 10/09/26 · 88k views", verified: false),
        SamplePost(name: "Drop Alert", handle: "dropalert", text: "BREAKING: $NULL is up 4,173% in an hour. Chat says invest now. Chat also says it's a rug.", meta: "11:30 PM · 10/16/26 · 412k views"),
        SamplePost(name: "ghost_ledger", handle: "ghost_ledger", text: "why does every new jailbreak look like the last one with a different logo", meta: "4:05 PM · 10/15/26 · 61k views", verified: false),
        SamplePost(name: "Feud Watch", handle: "feudwatch", text: "You called them out on stream. They remember. Everyone remembers. How long can you hold the line?", meta: "6:20 PM · 10/13/26 · 204k views"),
        SamplePost(name: "patch_gremlin", handle: "patch_gremlin", text: "pushed to main on a friday. it compiles. we ship. whatever happens next is a future me problem", meta: "1:02 AM · 10/11/26 · 47k views", verified: false),
        SamplePost(name: "Rank Report", handle: "rankreport", text: "Season ends in two days. You are #7 and someone is closing in fast. Time to post something loud.", meta: "8:45 AM · 10/16/26 · 96k views")
    ]
}

extension SamplePost {
    static func styled(_ f: (inout AvatarLook) -> Void) -> AvatarLook {
        var l = AvatarLook()
        f(&l)
        return l
    }

    /// Showcase avatars for the welcome wall, static so the marquee stays cheap.
    static let looks: [String: AvatarLook] = [
        "certdaily": styled { $0.hat = 18; $0.hatColor = 3; $0.specs = 3; $0.bg = 1; $0.pattern = 1; $0.skin = 3; $0.hairStyle = 0 },
        "scenewire": styled { $0.hat = 2; $0.hatColor = 5; $0.beard = 1; $0.necklace = 2; $0.bg = 3; $0.frame = 1; $0.skin = 5; $0.paint = 16 },
        "kernel_wizard": styled { $0.hat = 11; $0.hatColor = 2; $0.beard = 4; $0.beardColor = 8; $0.specs = 1; $0.bg = 6; $0.pattern = 4; $0.skin = 1 },
        "dropalert": styled { $0.hat = 3; $0.necklace = 3; $0.specs = 2; $0.bg = 4; $0.frame = 1; $0.skin = 4; $0.outfit = 4 },
        "ghost_ledger": styled { $0.mask = 7; $0.hat = 1; $0.hatColor = 8; $0.bg = 9; $0.pattern = 2; $0.skin = 2 },
        "feudwatch": styled { $0.paint = 8; $0.hat = 12; $0.bg = 2; $0.frame = 5; $0.accent = 0; $0.hairStyle = 2; $0.skin = 0 },
        "patch_gremlin": styled { $0.hairStyle = 15; $0.hair = 11; $0.paint = 6; $0.paintColor = 7; $0.ear = 2; $0.bg = 7; $0.frame = 6; $0.skin = 6; $0.outfit = 1 },
        "rankreport": styled { $0.outfit = 6; $0.neck = 2; $0.hairStyle = 14; $0.brow = 1; $0.bg = 5; $0.frame = 1; $0.necklace = 5; $0.skin = 7; $0.specs = 1 }
    ]
}

struct MCLogo: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text("mainchar")
                .font(.jk(size, .black)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.5)
                .overlay(alignment: .topLeading) {
                    Image(systemName: "crown.fill").font(.system(size: size * 0.2)).foregroundColor(.white)
                        .rotationEffect(.degrees(-8)).offset(x: size * 0.42, y: -size * 0.12)
                }
            ZStack {
                Image(systemName: "bubble.left.fill").font(.system(size: size * 0.34)).foregroundColor(.white)
                HStack(spacing: size * 0.05) {
                    Circle().fill(Color.black).frame(width: size * 0.06, height: size * 0.06)
                    Circle().fill(Color.black).frame(width: size * 0.06, height: size * 0.06)
                }.offset(y: -size * 0.02)
                Circle().fill(T.blue).frame(width: size * 0.1, height: size * 0.1).offset(x: size * 0.1, y: -size * 0.1)
            }
            .offset(x: size * 0.16, y: -size * 0.2)
        }
        .padding(.top, size * 0.2)
    }
}

struct SampleCard: View {
    let p: SamplePost
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PortraitAvatar(key: p.handle, size: 46, look: SamplePost.looks[p.handle] ?? AvatarLook())
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(p.name).font(.jk(16, .bold)).lineLimit(1)
                        if p.verified { VerifiedSeal(size: 15) }
                    }
                    Text("@\(p.handle)").font(.jk(13)).foregroundColor(T.sub).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "ellipsis").foregroundColor(T.sub)
            }
            Text(p.text).font(.jk(15)).foregroundColor(.white.opacity(0.92)).lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(p.meta).font(.jk(11)).foregroundColor(T.sub).lineLimit(1)
        }
        .padding(14)
        .frame(width: 300, height: 170, alignment: .topLeading)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct MarqueeRow: View {
    let items: [SamplePost]
    var speed: Double = 22
    var reverse = false
    var body: some View {
        let n = items.count
        let unit: CGFloat = 314
        let w = unit * CGFloat(n)
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let off = CGFloat((t * speed).truncatingRemainder(dividingBy: Double(w)))
            HStack(spacing: 14) {
                ForEach(0..<(n * 2), id: \.self) { i in SampleCard(p: items[i % n]) }
            }
            .fixedSize()
            .offset(x: reverse ? -w + off : -off)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 170)
        .clipped()
    }
}

struct SplashView: View {
    @State private var show = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MCLogo(size: 58).padding(.horizontal, 30)
                .opacity(show ? 1 : 0).scaleEffect(show ? 1 : 0.92)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { show = true } }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var game: Game
    var onBrowse: () -> Void
    @State private var flow: FlowSeed? = nil
    @State private var accounts = false

    var body: some View {
        let posts = SamplePost.all
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
            GeometryReader { geo in
                let rows = Int(ceil((geo.size.height + 80) / 184)) + 1
                VStack(spacing: 14) {
                    ForEach(0..<rows, id: \.self) { i in
                        let k = (i * 3) % posts.count
                        let items = Array(posts[k...] + posts[..<k])
                        MarqueeRow(items: items, speed: 16 + Double((i * 7) % 4) * 4, reverse: i % 2 == 1)
                    }
                }
                .frame(width: geo.size.width, alignment: .top)
                .offset(y: -40)
            }
            .ignoresSafeArea()
            .opacity(0.92)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.42),
                                         .init(color: .clear, location: 0.7)],
                                 startPoint: .top, endPoint: .bottom))
            VStack(spacing: 0) {
                Spacer()
                MCLogo(size: 56).padding(.horizontal, 30)
                Text("be the main character").font(.jk(22, .medium)).foregroundColor(T.sub).padding(.top, 14)
                Button { flow = FlowSeed(world: nil) } label: {
                    Text("Get started").font(.jk(24, .medium)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 66).background(T.blue).clipShape(Capsule())
                }
                .padding(.horizontal, 22).padding(.top, 34)
                Button { accounts = true } label: {
                    Text("I have an existing world").font(.jk(22, .medium)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                }
                .padding(.top, 6)
                Button(action: onBrowse) {
                    Text("Browse worlds").font(.jk(16)).foregroundColor(T.sub)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Color.white.opacity(0.08)).clipShape(Capsule())
                }
                .padding(.bottom, 40).padding(.top, 6)
            }
        }
        .fullScreenCover(item: $flow) { seed in
            CreateFlow(initialWorld: seed.world) { flow = nil }.zoomed()
        }
        .sheet(isPresented: $accounts) { AccountsSheet(onCreate: { accounts = false; flow = FlowSeed(world: nil) }).zoomed() }
    }
}

struct AccountsSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Back into your world").font(.jk(24, .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(T.card2).clipShape(Circle())
                }
            }
            if game.store.saves.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 48)).foregroundColor(T.sub)
                    Text("No worlds saved on this device yet.").font(.jk(16)).foregroundColor(T.sub)
                    BigButton(title: "Create a world", action: onCreate)
                }
                .frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(game.store.saves) { sv in
                            Button { dismiss(); game.resume(sv.id) } label: {
                                HStack(spacing: 12) {
                                    Avatar(emoji: sv.persona.emoji, key: sv.persona.handle, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sv.persona.name).font(.jk(17, .bold)).foregroundColor(.white)
                                        Text("\(sv.world.title) · Day \(sv.day) · Lvl \(sv.level)").font(.jk(13)).foregroundColor(T.sub)
                                    }
                                    Spacer()
                                    Text(short(sv.followers)).font(.jk(15, .bold)).foregroundColor(T.blue)
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.sub)
                                }
                                .card()
                            }
                            .contextMenu {
                                Button(role: .destructive) { game.deleteSave(sv.id) } label: { Label("Delete save", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(T.bg)
        .presentationDetents([.medium, .large])
    }
}
