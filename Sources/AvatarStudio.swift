import SwiftUI

/// Dress-up studio for the player's avatar: skin, hair, outfits, hats, face paint, glasses, animated backdrops.
struct AvatarStudioView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var look = AvatarLook()
    @State private var tab = 0

    private let tabs = ["Skin", "Hair", "Face", "Outfit", "Hats", "Paint", "Glasses", "Extras", "Backdrop"]
    private let hairStyles = [0, 1, 2, 3, 4, 5, 6, 9]
    private let hairNames = ["Crop", "Long", "Buzz", "Afro", "Bun", "Swoop", "Waves", "Bald"]
    private let eyeNames = ["Round", "Wide", "Happy"]
    private let mouthNames = ["Smile", "Flat", "Smirk", "Grin"]
    private let outfitNames = ["Tee", "Hoodie", "Collar", "Turtle", "Jacket", "Jersey", "Suit", "Tank"]
    private let hatNames = ["None", "Beanie", "Cap", "Crown", "Party", "Cowboy", "Band", "Halo", "Bunny", "Cat", "Top hat", "Wizard", "Horns"]
    private let paintNames = ["None", "Stripes", "Stars", "Bolt", "Tiger", "Clown", "Cyber", "Hearts", "Skull", "Bandit"]
    private let specNames = ["None", "Round", "Shades", "Visor"]
    private let animNames = ["Still", "Aurora", "Stars", "Matrix", "Bubbles", "Pulse", "Glitch", "Embers", "Rainbow"]

    private var key: String { game.s.persona.handle }
    private let cols = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    private func col(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }

    private func variant(_ f: (inout AvatarLook) -> Void) -> AvatarLook {
        var l = look
        f(&l)
        if tab != 8 { l.anim = 0 }
        return l
    }

    private func tile(_ label: String, _ v: AvatarLook, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                PortraitAvatar(key: key, size: 64, look: v)
                    .overlay(Circle().stroke(on ? T.blue : Color.clear, lineWidth: 3).padding(-3))
                Text(label).font(.jk(12, .semibold)).foregroundColor(on ? Color.white : T.sub).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ c: Color, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Circle().fill(c).frame(width: 40, height: 40)
                .overlay(Circle().stroke(on ? Color.white : Color.white.opacity(0.15), lineWidth: on ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    private func gradSwatch(_ a: Color, _ b: Color, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Circle().fill(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 40, height: 40)
                .overlay(Circle().stroke(on ? Color.white : Color.white.opacity(0.15), lineWidth: on ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.jk(14, .bold)).foregroundColor(T.sub)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    }

    private func tri(_ title: String, _ b: Binding<Bool?>) -> some View {
        HStack {
            Text(title).font(.jk(16, .semibold))
            Spacer()
            Picker("", selection: b) {
                Text("Auto").tag(Bool?.none)
                Text("On").tag(Bool?.some(true))
                Text("Off").tag(Bool?.some(false))
            }
            .pickerStyle(.segmented).frame(width: 190)
        }
    }

    private func randomize() {
        var l = AvatarLook()
        l.skin = Int.random(in: 0..<8)
        l.hair = Int.random(in: 0..<13)
        l.hairStyle = hairStyles.randomElement()
        l.top = Int.random(in: 0..<12)
        l.outfit = Int.random(in: 0..<8)
        l.eyes = Int.random(in: 0..<3)
        l.mouth = Int.random(in: 0..<4)
        l.specs = [0, 0, 1, 2, 3].randomElement()
        l.hat = Bool.random() ? Int.random(in: 1...12) : 0
        l.hatColor = Int.random(in: 0..<12)
        l.paint = Int.random(in: 0...2) == 0 ? Int.random(in: 1...9) : 0
        l.paintColor = Int.random(in: 0..<8)
        l.chain = Int.random(in: 0..<4) == 0
        l.bg = Int.random(in: 0..<10)
        l.anim = Int.random(in: 0...8)
        look = l
    }

    private func save() {
        let h = game.s.persona.handle
        AvatarLooks.save(look, handle: h)
        ProfileImages.remove("avatar_" + h)
        AvatarMem.cache.removeObject(forKey: h as NSString)
        game.profileRev += 1
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                Text("Avatar Studio").font(.jk(24, .heavy))
                Spacer()
                Button(action: save) {
                    Text("Save").font(.jk(17, .bold)).foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(T.blue).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)

            PortraitAvatar(key: key, size: 168, look: look)
                .shadow(color: Color.black.opacity(0.4), radius: 14, y: 6)
                .padding(.vertical, 8)

            HStack(spacing: 10) {
                Button { randomize() } label: {
                    Label("Randomize", systemImage: "dice.fill").font(.jk(15, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9).background(T.card2).clipShape(Capsule())
                }
                Button { look = AvatarLook() } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise").font(.jk(15, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9).background(T.card2).clipShape(Capsule())
                }
            }
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<tabs.count, id: \.self) { i in
                        Button { tab = i } label: {
                            Text(tabs[i]).font(.jk(15, .semibold)).foregroundColor(tab == i ? Color.white : T.sub)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(tab == i ? T.blue : T.card2).clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(16).padding(.bottom, 30)
            }
            .background(T.card.opacity(0.5))
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear { look = AvatarLooks.look(for: key) ?? AvatarLook() }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case 0: skinTab
        case 1: hairTab
        case 2: faceTab
        case 3: outfitTab
        case 4: hatTab
        case 5: paintTab
        case 6: glassesTab
        case 7: extrasTab
        default: backdropTab
        }
    }

    private var skinTab: some View {
        LazyVGrid(columns: cols, spacing: 14) {
            ForEach(0..<PortraitAvatar.skins.count, id: \.self) { i in
                swatch(col(PortraitAvatar.skins[i]), on: look.skin == i) { look.skin = i }
            }
        }
    }

    private var hairTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Style")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<hairStyles.count, id: \.self) { i in
                    let st = hairStyles[i]
                    tile(hairNames[i], variant { $0.hairStyle = st }, on: look.hairStyle == st) { look.hairStyle = st }
                }
            }
            section("Colour")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<PortraitAvatar.hairs.count, id: \.self) { i in
                    swatch(col(PortraitAvatar.hairs[i]), on: look.hair == i) { look.hair = i }
                }
            }
        }
    }

    private var faceTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Eyes")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<eyeNames.count, id: \.self) { i in
                    tile(eyeNames[i], variant { $0.eyes = i }, on: look.eyes == i) { look.eyes = i }
                }
            }
            section("Mouth")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<mouthNames.count, id: \.self) { i in
                    tile(mouthNames[i], variant { $0.mouth = i }, on: look.mouth == i) { look.mouth = i }
                }
            }
        }
    }

    private var outfitTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Clothes")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<outfitNames.count, id: \.self) { i in
                    tile(outfitNames[i], variant { $0.outfit = i }, on: look.outfit == i) { look.outfit = i }
                }
            }
            section("Colour")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<PortraitAvatar.tops.count, id: \.self) { i in
                    swatch(col(PortraitAvatar.tops[i]), on: look.top == i) { look.top = i }
                }
            }
            Toggle("Gold chain", isOn: $look.chain).font(.jk(16, .semibold)).padding(.top, 6)
        }
    }

    private var hatTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Hats")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<hatNames.count, id: \.self) { i in
                    tile(hatNames[i], variant { $0.hat = i }, on: look.hat == i) { look.hat = i }
                }
            }
            section("Hat colour")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<PortraitAvatar.tops.count, id: \.self) { i in
                    swatch(col(PortraitAvatar.tops[i]), on: look.hatColor == i) { look.hatColor = i }
                }
            }
        }
    }

    private var paintTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Face paint")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<paintNames.count, id: \.self) { i in
                    tile(paintNames[i], variant { $0.paint = i }, on: look.paint == i) { look.paint = i }
                }
            }
            section("Paint colour")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<PortraitAvatar.paints.count, id: \.self) { i in
                    swatch(col(PortraitAvatar.paints[i]), on: look.paintColor == i) { look.paintColor = i }
                }
            }
        }
    }

    private var glassesTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Eyewear")
            LazyVGrid(columns: cols, spacing: 14) {
                tile("Auto", variant { $0.specs = nil }, on: look.specs == nil) { look.specs = nil }
                ForEach(0..<specNames.count, id: \.self) { i in
                    tile(specNames[i], variant { $0.specs = i }, on: look.specs == i) { look.specs = i }
                }
            }
        }
    }

    private var extrasTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Accessories")
            tri("Earring", $look.earring)
            tri("Headphones", $look.phones)
            Toggle("Gold chain", isOn: $look.chain).font(.jk(16, .semibold))
        }
    }

    private var backdropTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Animated backdrop")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<animNames.count, id: \.self) { i in
                    tile(animNames[i], variant { $0.anim = i }, on: look.anim == i) { look.anim = i }
                }
            }
            section("Base colour")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<PortraitAvatar.bgs.count, id: \.self) { i in
                    gradSwatch(col(PortraitAvatar.bgs[i].0), col(PortraitAvatar.bgs[i].1), on: look.bg == i) { look.bg = i }
                }
            }
        }
    }
}
