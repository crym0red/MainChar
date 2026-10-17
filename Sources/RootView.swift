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

struct FlowSeed: Identifiable {
    let id = UUID()
    var world: WorldDef?
}

struct HubView: View {
    @EnvironmentObject var game: Game
    @State private var query = ""
    @State private var searching = false
    @State private var flow: FlowSeed? = nil
    @State private var showSettings = false

    private func match(_ w: WorldDef) -> Bool {
        query.trimmed.isEmpty || w.title.localizedCaseInsensitiveContains(query) || w.tagline.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                header
                if searching {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundColor(T.sub)
                        TextField("Search worlds", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .padding(12).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
                Divider().background(Color.white.opacity(0.12))
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if !game.store.saves.isEmpty { saves }
                        carousel("Featured Worlds", Array(WorldDef.presets.prefix(2)).filter(match))
                        carousel("Popular", Array(WorldDef.presets.dropFirst(2)).filter(match))
                        myPresets
                    }
                    .padding(.vertical, 16).padding(.bottom, 100)
                }
            }
            Button { flow = FlowSeed(world: nil) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                    Text("Create my own").font(.system(size: 20, weight: .medium))
                }
                .foregroundColor(.white).padding(.horizontal, 28).padding(.vertical, 18)
                .background(T.blue).clipShape(Capsule())
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
            }
            .padding(20)
        }
        .background(T.bg.ignoresSafeArea())
        .fullScreenCover(item: $flow) { seed in
            CreateFlow(initialWorld: seed.world) { flow = nil }
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("MainChar")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.80, green: 0.62, blue: 1.0), Color(red: 0.55, green: 0.45, blue: 1.0)],
                                                startPoint: .leading, endPoint: .trailing))
            Spacer()
            Button { withAnimation { searching.toggle(); if !searching { query = "" } } } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 20)).foregroundColor(T.sub)
                    .frame(width: 52, height: 52).background(T.card).clipShape(Circle())
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 20)).foregroundColor(T.sub)
                    .frame(width: 52, height: 52).background(T.card).clipShape(Circle())
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
    }

    private var saves: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Continue playing").padding(.horizontal, 16)
            ForEach(game.store.saves) { sv in
                Button { game.resume(sv.id) } label: {
                    HStack(spacing: 12) {
                        Avatar(emoji: sv.persona.emoji, key: sv.persona.handle, size: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sv.persona.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            Text("\(sv.world.title) · Day \(sv.day) · Lvl \(sv.level)")
                                .font(.system(size: 13)).foregroundColor(T.sub)
                        }
                        Spacer()
                        Text(short(sv.followers)).font(.system(size: 15, weight: .bold)).foregroundColor(T.blue)
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.sub)
                    }
                    .card()
                }
                .padding(.horizontal, 16)
                .contextMenu {
                    Button(role: .destructive) { game.deleteSave(sv.id) } label: { Label("Delete save", systemImage: "trash") }
                }
            }
        }
    }

    private func carousel(_ title: String, _ worlds: [WorldDef]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !worlds.isEmpty {
                Text(title).font(.system(size: 24, weight: .regular)).padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(worlds) { w in
                            Button { flow = FlowSeed(world: w) } label: { WorldCardView(world: w) }
                        }
                    }.padding(.horizontal, 16)
                }
            }
        }
    }

    private var myPresets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My presets").font(.system(size: 24, weight: .regular)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(game.store.presets.filter(match)) { w in
                        Button { flow = FlowSeed(world: w) } label: { WorldCardView(world: w) }
                            .contextMenu {
                                Button(role: .destructive) { game.deletePreset(w.id) } label: { Label("Delete preset", systemImage: "trash") }
                            }
                    }
                    Button { flow = FlowSeed(world: nil) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                            Image(systemName: "plus").font(.system(size: 30)).foregroundColor(T.sub)
                                .frame(width: 70, height: 70).background(T.card).clipShape(Circle())
                        }
                        .frame(width: game.store.presets.isEmpty ? 330 : 160, height: 200)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }
}

struct WorldCardView: View {
    let world: WorldDef

    var body: some View {
        let h2 = (world.hue + 0.08).truncatingRemainder(dividingBy: 1)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Color(hue: world.hue, saturation: 0.65, brightness: 0.6),
                                        Color(hue: h2, saturation: 0.7, brightness: 0.25)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(world.emoji).font(.system(size: 120)).opacity(0.32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 8) {
                    Text(world.emoji)
                    Text(world.title).lineLimit(1)
                }
                .font(.system(size: 17, weight: .medium)).foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.black.opacity(0.45)).clipShape(Capsule())
                .padding(14)
            }
            .frame(height: 170)
            VStack(alignment: .leading, spacing: 8) {
                Text(world.title).font(.system(size: 24, weight: .medium)).foregroundColor(.white).lineLimit(1)
                Text(world.tagline).font(.system(size: 16)).foregroundColor(T.sub).lineLimit(2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    HStack(spacing: -10) {
                        ForEach(world.cast.prefix(4)) { n in
                            Avatar(emoji: n.emoji, key: n.handle, size: 34)
                                .overlay(Circle().stroke(T.card, lineWidth: 2))
                        }
                        Text("+\(max(0, world.cast.count - 4))").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 34, height: 34).background(T.card2).clipShape(Circle())
                            .overlay(Circle().stroke(T.card, lineWidth: 2))
                    }
                    Spacer()
                    Image(systemName: "person.fill").foregroundColor(T.sub)
                    Text("\(world.cast.count)").font(.system(size: 15)).foregroundColor(T.sub)
                }
            }
            .padding(16)
        }
        .frame(width: 310)
        .background(T.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Custom character

struct CreateCharacterSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onDone: (Persona) -> Void
    @State private var name = ""
    @State private var handle = ""
    @State private var vibe: Vibe = .clown

    private var cleanHandle: String {
        let h = (handle.isEmpty ? name : handle).lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return h.isEmpty ? "player" : h
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Spacer(); Avatar(emoji: "😎", key: cleanHandle, size: 96); Spacer() }
                    Text("Your profile picture is generated from your handle.").font(.system(size: 12)).foregroundColor(T.sub)
                        .frame(maxWidth: .infinity)
                    TextField("Display name", text: $name).padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    TextField("handle", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14))
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
                    BigButton(title: "Continue", enabled: !name.trimmed.isEmpty) {
                        let p = Persona(name: name.trimmed, handle: cleanHandle, bio: "", emoji: "😎", vibe: vibe)
                        dismiss()
                        onDone(p)
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
                Section(header: Text("AI"), footer: Text("Tries free public AI services (LLM7, Pollinations) with no key. If none respond, on-topic built-in content is used. Free tiers are rate limited, so AI content can take a few seconds.")) {
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
