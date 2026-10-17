import SwiftUI

struct RootView: View {
    @StateObject private var game = Game()
    @StateObject private var nav = Nav()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            if game.playing { GameShell() } else { HubView() }
        }
        .environmentObject(game)
        .environmentObject(nav)
        .preferredColorScheme(.dark)
        .tint(T.blue)
        .onChange(of: phase) { p in
            if p == .active { game.tickEnergy() } else { game.flush() }
        }
    }
}

// MARK: - Hub

struct HubView: View {
    @EnvironmentObject var game: Game
    @State private var query = ""
    @State private var showCreate = false
    @State private var showSettings = false

    private func match(_ w: WorldDef) -> Bool {
        query.trimmed.isEmpty || w.title.localizedCaseInsensitiveContains(query) || w.tagline.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !game.store.saves.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle("Continue playing")
                            ForEach(game.store.saves) { sv in
                                Button { game.resume(sv.id) } label: {
                                    HStack(spacing: 12) {
                                        Avatar(emoji: sv.persona.emoji, key: sv.persona.handle, size: 46)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sv.persona.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                            Text("\(sv.world.title) · Day \(sv.day) · Lvl \(sv.level)")
                                                .font(.system(size: 12)).foregroundColor(T.sub)
                                        }
                                        Spacer()
                                        Text(short(sv.followers)).font(.system(size: 14, weight: .bold)).foregroundColor(T.blue)
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

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Featured Worlds")
                        ForEach(WorldDef.presets.filter(match)) { w in
                            NavigationLink(value: w) { WorldCard(world: w) }
                        }
                    }

                    if !game.store.presets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle("My presets")
                            ForEach(game.store.presets.filter(match)) { w in
                                NavigationLink(value: w) { WorldCard(world: w) }
                                    .contextMenu {
                                        Button(role: .destructive) { game.deletePreset(w.id) } label: { Label("Delete preset", systemImage: "trash") }
                                    }
                            }
                        }
                    }

                    Button { showCreate = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create my own").font(.system(size: 16, weight: .bold))
                                Text("Describe a goal and a setting. AI builds the world.")
                                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(T.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(T.bg)
            .navigationTitle("Worlds")
            .searchable(text: $query, prompt: "Search worlds")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                }
            }
            .navigationDestination(for: WorldDef.self) { WorldOverview(world: $0) }
            .navigationDestination(isPresented: $showCreate) { CreateWorldView() }
            .sheet(isPresented: $showSettings) { SettingsSheet() }
        }
    }
}

struct WorldCard: View {
    let world: WorldDef
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hue: world.hue, saturation: 0.5, brightness: 0.5))
                Text(world.emoji).font(.system(size: 30))
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(world.title).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Text(world.tagline).font(.system(size: 13)).foregroundColor(T.sub).lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.sub)
        }
        .card()
    }
}

// MARK: - World overview

struct WorldOverview: View {
    let world: WorldDef
    @State private var pick = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hue: world.hue, saturation: 0.55, brightness: 0.6),
                                                      Color(hue: world.hue, saturation: 0.5, brightness: 0.3)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(spacing: 6) {
                        Text(world.emoji).font(.system(size: 54))
                        Text(world.title).font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                        Text(world.tagline).font(.system(size: 14)).foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal").font(.system(size: 13, weight: .bold)).foregroundColor(T.orange)
                    Text(world.goal).font(.system(size: 16)).foregroundColor(.white)
                }.card()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Setting").font(.system(size: 13, weight: .bold)).foregroundColor(T.blue)
                    Text(world.setting).font(.system(size: 15)).foregroundColor(.white.opacity(0.9))
                }.card()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cast").font(.system(size: 13, weight: .bold)).foregroundColor(T.sub)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(world.cast) { n in
                                VStack(spacing: 4) {
                                    Avatar(emoji: n.emoji, key: n.handle, size: 52)
                                    Text(n.name.components(separatedBy: " ").first ?? n.name)
                                        .font(.system(size: 11)).foregroundColor(T.sub)
                                }
                            }
                        }
                    }
                }.card()
                BigButton(title: "Play this world") { pick = true }
            }
            .padding(16)
        }
        .background(T.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $pick) { CharacterPickView(world: world) }
    }
}

// MARK: - Create

struct CreateWorldView: View {
    @EnvironmentObject var game: Game
    @State private var goal = ""
    @State private var setting = ""
    @State private var busy = false
    @State private var made: WorldDef? = nil
    @State private var go = false
    @State private var usedAI = true
    @State private var inspo = false

    private var ok: Bool { !goal.trimmed.isEmpty && !setting.trimmed.isEmpty && !busy }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("What is your goal?").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("\(150 - goal.count) left").font(.system(size: 12)).foregroundColor(T.sub)
                        }
                        TextField("e.g. Become the biggest streamer in the world", text: $goal, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: goal) { v in if v.count > 150 { goal = String(v.prefix(150)) } }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Describe the setting").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("\(2000 - setting.count) left").font(.system(size: 12)).foregroundColor(T.sub)
                        }
                        TextEditor(text: $setting)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .padding(8).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                            .onChange(of: setting) { v in if v.count > 2000 { setting = String(v.prefix(2000)) } }
                    }
                    DisclosureGroup("Need inspiration?", isExpanded: $inspo) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Inspiration.prompts, id: \.self) { p in
                                Button { setting = String(p.prefix(2000)); inspo = false } label: {
                                    Text(p).font(.system(size: 13)).foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(T.card2).clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }.padding(.top, 8)
                    }
                    .foregroundColor(T.blue)
                    .card()
                    if !usedAI {
                        Text("AI was unreachable, so a starter cast was used. You can still play.")
                            .font(.system(size: 12)).foregroundColor(T.orange)
                    }
                    BigButton(title: "Create world", enabled: ok) { generate() }
                }
                .padding(16)
            }
            .disabled(busy)
            if busy {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.4)
                    Text("Building your world…").font(.system(size: 16, weight: .bold))
                    Text("Writing the cast, skills and milestones").font(.system(size: 12)).foregroundColor(T.sub)
                }
                .padding(28).background(T.card).clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .background(T.bg)
        .navigationTitle("Create world")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $go) {
            if let w = made { WorldOverview(world: w) }
        }
    }

    private func generate() {
        busy = true
        let g = goal.trimmed, s = setting.trimmed
        Task {
            let (w, ai) = await game.buildWorld(goal: g, setting: s)
            game.savePreset(w)
            usedAI = ai
            made = w
            busy = false
            go = true
        }
    }
}

// MARK: - Character pick

struct CharacterPickView: View {
    @EnvironmentObject var game: Game
    let world: WorldDef
    @State private var custom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Be anyone in your world").font(.system(size: 24, weight: .heavy))
                Text("Pick a character to play, or make your own.").font(.system(size: 14)).foregroundColor(T.sub)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(world.cast) { n in
                        Button {
                            game.start(world: world,
                                       persona: Persona(name: n.name, handle: n.handle, bio: n.bio, emoji: n.emoji, vibe: n.trait.vibe),
                                       asNPC: n.handle)
                        } label: {
                            VStack(spacing: 6) {
                                Avatar(emoji: n.emoji, key: n.handle, size: 64)
                                Text(n.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                                Text(n.bio).font(.system(size: 11)).foregroundColor(T.sub).lineLimit(2).multilineTextAlignment(.center)
                                Chip(text: n.trait.vibe.label + " " + n.trait.vibe.emoji)
                            }
                            .padding(12).frame(maxWidth: .infinity)
                            .background(T.card).clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                BigButton(title: "Create your own") { custom = true }
            }
            .padding(16)
        }
        .background(T.bg)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $custom) { CreateCharacterSheet(world: world) }
    }
}

struct CreateCharacterSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    let world: WorldDef
    @State private var name = ""
    @State private var handle = ""
    @State private var emoji = "😎"
    @State private var vibe: Vibe = .clown
    private let emojis = ["😎", "🤩", "😈", "🥹", "🕶️", "🤡", "👑", "🦄", "🐸", "🔥", "🌸", "👽"]

    private var cleanHandle: String {
        let h = (handle.isEmpty ? name : handle).lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return h.isEmpty ? "player" : h
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Spacer(); Avatar(emoji: emoji, key: cleanHandle, size: 80); Spacer() }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(emojis, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.system(size: 28)).padding(8)
                                    .background(emoji == e ? T.blue.opacity(0.4) : T.card).clipShape(Circle())
                            }
                        } }
                    }
                    TextField("Display name", text: $name).padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                    TextField("handle", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Vibe").font(.system(size: 14, weight: .bold))
                    ForEach(Vibe.allCases) { v in
                        Button { vibe = v } label: {
                            HStack {
                                Text(v.emoji).font(.system(size: 24))
                                VStack(alignment: .leading) {
                                    Text(v.label).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                    Text(v.blurb).font(.system(size: 12)).foregroundColor(T.sub)
                                }
                                Spacer()
                                if vibe == v { Image(systemName: "checkmark.circle.fill").foregroundColor(T.blue) }
                            }
                            .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    BigButton(title: "Start", enabled: !name.trimmed.isEmpty) {
                        game.start(world: world,
                                   persona: Persona(name: name.trimmed, handle: cleanHandle, bio: "", emoji: emoji, vibe: vibe))
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(T.bg)
            .navigationTitle("Your character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Customize world (active game)

struct CustomizeWorldSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var goal = ""
    @State private var setting = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("World name", text: $title) }
                Section("Goal (\(150 - goal.count) left)") {
                    TextField("Goal", text: $goal, axis: .vertical).lineLimit(2...4)
                        .onChange(of: goal) { v in if v.count > 150 { goal = String(v.prefix(150)) } }
                }
                Section("Setting (\(2000 - setting.count) left)") {
                    TextEditor(text: $setting).frame(minHeight: 150)
                        .onChange(of: setting) { v in if v.count > 2000 { setting = String(v.prefix(2000)) } }
                }
                Section { Text("Changes apply to new AI events, posts and messages.").font(.footnote).foregroundColor(.secondary) }
            }
            .navigationTitle("Customize World")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { game.updateWorld(title: title, goal: goal, setting: setting); dismiss() }
                        .disabled(goal.trimmed.isEmpty)
                }
            }
            .onAppear {
                let w = game.s.world
                title = w.title; goal = w.goal; setting = w.setting
            }
        }
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ai.enabled") private var enabled = true
    @AppStorage("ai.key") private var key = ""
    @AppStorage("ai.url") private var url = ""
    @AppStorage("ai.model") private var model = ""
    @State private var testing = false
    @State private var result = ""
    @State private var confirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AI"), footer: Text("Uses the free Pollinations text API by default. If it is offline, built-in content is used. Anonymous use is rate limited, so AI content can take a few seconds.")) {
                    Toggle("AI-written content", isOn: $enabled)
                    Button {
                        testing = true; result = ""
                        Task { result = await game.testAI(); testing = false }
                    } label: {
                        HStack { Text("Test connection"); if testing { Spacer(); ProgressView() } }
                    }.disabled(testing)
                    if !result.isEmpty { Text(result).font(.footnote).foregroundColor(.secondary) }
                }
                Section(header: Text("Advanced"), footer: Text("Optional. Leave blank for defaults. Any OpenAI-compatible chat endpoint works.")) {
                    SecureField("API key (optional)", text: $key)
                    TextField("Endpoint URL", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Model", text: $model).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Button("Erase all data", role: .destructive) { confirm = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Erase everything?", isPresented: $confirm) {
                Button("Erase", role: .destructive) { game.resetAll(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("All saves and custom worlds will be deleted.") }
        }
    }
}
