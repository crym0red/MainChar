import SwiftUI

/// Optional account sync with the MainChar backend. The game is fully offline without it.
/// Saves are exchanged as a portable v1 profile that the web game reads and writes too.
@MainActor
final class SyncClient: ObservableObject {
    static let shared = SyncClient()
    static let defaultAPI = "https://mainchar.city/mc/api"

    @Published var user: String? = UserDefaults.standard.string(forKey: "mc.sync.user")
    @Published var msg = ""
    @Published var busy = false
    private var token: String? { UserDefaults.standard.string(forKey: "mc.sync.token") }
    private var pushTask: Task<Void, Never>?

    var api: String {
        get { UserDefaults.standard.string(forKey: "mc.sync.url") ?? Self.defaultAPI }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "mc.sync.url") }
    }
    var signedIn: Bool { token != nil }

    // MARK: Portable format

    static func key(_ s: GameState) -> String {
        (s.world.id + "_" + s.persona.handle).filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    /// Player-driven numbers only, so idle world simulation never counts as a local edit.
    static func fingerprint(_ s: GameState) -> String {
        "\(s.level)-\(s.xp)-\(s.points)-\(s.ex.gems)-\((s.ex.following ?? []).count)-\(s.totalPosts)-\(s.ex.theme ?? 0)-\(s.ex.title ?? "")"
    }

    static func portable(_ s: GameState) -> [String: Any] {
        [
            "v": 1, "worldId": s.world.id,
            "persona": ["name": s.persona.name, "handle": s.persona.handle, "bio": s.persona.bio],
            "followers": s.followers, "following": s.ex.following ?? [], "aura": s.aura, "level": s.level, "xp": s.xp,
            "points": s.points, "gems": s.ex.gems, "day": s.day, "stats": s.stats, "skills": s.skills.map { $0.value },
            "theme": s.ex.theme ?? 0, "title": s.ex.title.map { $0 as Any } ?? NSNull(), "badges": (s.ex.lvBadges ?? []).map { $0.name },
            "totalPosts": s.totalPosts,
            "npcs": s.npcs.map { ["handle": $0.handle, "followers": $0.followers, "affinity": $0.affinity, "followsYou": $0.followsYou] as [String: Any] }
        ]
    }

    static func apply(_ p: [String: Any], to s: inout GameState) {
        func i(_ k: String) -> Int? { (p[k] as? NSNumber)?.intValue }
        s.followers = i("followers") ?? s.followers
        s.aura = i("aura") ?? s.aura
        s.level = max(1, i("level") ?? s.level)
        s.xp = i("xp") ?? s.xp
        s.points = i("points") ?? s.points
        s.day = max(s.day, i("day") ?? s.day)
        s.totalPosts = i("totalPosts") ?? s.totalPosts
        if let g = i("gems") { s.ex.gems = g }
        if let f = p["following"] as? [String] { s.ex.following = f; s.following = f.count }
        if let st = p["stats"] as? [String: Int] { for (k, v) in st { s.stats[k] = v } }
        if let sk = p["skills"] as? [Int] { for (n, v) in sk.enumerated() where s.skills.indices.contains(n) { s.skills[n].value = v } }
        s.ex.theme = i("theme")
        s.ex.title = p["title"] as? String
        if let ns = p["npcs"] as? [[String: Any]] {
            for x in ns {
                guard let h = x["handle"] as? String, let j = s.npcs.firstIndex(where: { $0.handle == h }) else { continue }
                if let f = (x["followers"] as? NSNumber)?.intValue { s.npcs[j].followers = f }
                if let a = (x["affinity"] as? NSNumber)?.intValue { s.npcs[j].affinity = a }
                if let b = x["followsYou"] as? Bool { s.npcs[j].followsYou = b }
            }
        }
    }

    // MARK: Network

    private struct Fail: Error { var code: Int; var text: String }

    private func call(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: api.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else { throw Fail(code: 0, text: "Bad server URL") }
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        if let b = body { r.httpBody = try JSONSerialization.data(withJSONObject: b) }
        let (d, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
        if code >= 400 { throw Fail(code: code, text: j["error"] as? String ?? "Error") }
        return j
    }

    func auth(_ username: String, _ password: String, create: Bool, game: Game) async {
        msg = "..."
        do {
            let j = try await call("POST", create ? "/register" : "/login", ["username": username, "password": password])
            UserDefaults.standard.set(j["token"] as? String, forKey: "mc.sync.token")
            UserDefaults.standard.set(j["username"] as? String, forKey: "mc.sync.user")
            user = j["username"] as? String
            msg = "Signed in"
            await syncAll(game)
        } catch let f as Fail { msg = f.text } catch { msg = "Server unreachable" }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "mc.sync.token")
        UserDefaults.standard.removeObject(forKey: "mc.sync.user")
        user = nil; msg = ""
    }

    private func meta() -> [String: [String: Any]] { (UserDefaults.standard.dictionary(forKey: "mc.sync.meta") as? [String: [String: Any]]) ?? [:] }

    func poke(_ game: Game) {
        guard signedIn else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled { await self?.syncAll(game) }
        }
    }

    func syncAll(_ game: Game) async {
        guard signedIn, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let remote = (try await call("GET", "/saves"))["saves"] as? [String: [String: Any]] ?? [:]
            var m = meta()
            for idx in game.store.saves.indices {
                let s = game.store.saves[idx]
                guard WorldDef.presets.contains(where: { $0.id == s.world.id }) else { continue }
                let k = Self.key(s), fp = Self.fingerprint(s)
                let info = m[k] ?? [:]
                let lastFp = info["fp"] as? String, lastAt = (info["at"] as? NSNumber)?.doubleValue ?? 0
                let rAt = (remote[k]?["updatedAt"] as? NSNumber)?.doubleValue
                let changed = lastFp != fp
                if let rAt = rAt, !changed, rAt > lastAt {
                    let full = try await call("GET", "/saves/" + k)
                    if let st = full["state"] as? [String: Any] {
                        var ns = game.store.saves[idx]
                        Self.apply(st, to: &ns)
                        game.store.saves[idx] = ns
                        m[k] = ["fp": Self.fingerprint(ns), "at": rAt]
                    }
                } else if rAt == nil || changed {
                    let now = Date().timeIntervalSince1970 * 1000
                    _ = try await call("PUT", "/saves/" + k, [
                        "updatedAt": now, "device": "ios", "force": true,
                        "summary": ["name": s.persona.name, "level": s.level, "followers": s.followers],
                        "state": Self.portable(s)
                    ])
                    m[k] = ["fp": fp, "at": now]
                }
            }
            // saves that exist only on the server (made on the web)
            for (k, info) in remote where !game.store.saves.contains(where: { Self.key($0) == k }) {
                let full = try await call("GET", "/saves/" + k)
                guard let st = full["state"] as? [String: Any], let wid = st["worldId"] as? String,
                      let w = WorldDef.presets.first(where: { $0.id == wid }),
                      let pr = st["persona"] as? [String: Any], let name = pr["name"] as? String, let handle = pr["handle"] as? String else { continue }
                let prev = game.store.activeID
                game.start(world: w, persona: Persona(name: name, handle: handle, bio: pr["bio"] as? String ?? w.goal, emoji: "🙂", vibe: .clown))
                if let i = game.store.saves.firstIndex(where: { $0.persona.handle == handle && $0.world.id == wid }) {
                    var ns = game.store.saves[i]
                    Self.apply(st, to: &ns)
                    game.store.saves[i] = ns
                    m[k] = ["fp": Self.fingerprint(ns), "at": (info["updatedAt"] as? NSNumber)?.doubleValue ?? 0]
                }
                game.store.activeID = prev
            }
            UserDefaults.standard.set(m, forKey: "mc.sync.meta")
            msg = "Synced " + Date().formatted(date: .omitted, time: .shortened)
        } catch let f as Fail {
            if f.code == 401 { signOut(); msg = "Session expired. Sign in again." } else { msg = f.text }
        } catch {
            msg = "Offline or server unreachable. Progress is safe on this device."
        }
    }
}

struct SyncSheet: View {
    @EnvironmentObject var game: Game
    @ObservedObject var sync = SyncClient.shared
    @Environment(\.dismiss) private var dismiss
    @State private var u = ""
    @State private var p = ""
    @State private var url = SyncClient.shared.api

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Optional. The game works fully offline. Sign in to continue the same character on the app and the web.")
                        .font(.jk(14)).foregroundColor(T.sub)
                    if let user = sync.user {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(user)").font(.jk(20, .bold))
                            Text(sync.msg.isEmpty ? "Signed in" : sync.msg).font(.jk(13)).foregroundColor(T.sub)
                        }.card()
                        Button { Task { await sync.syncAll(game) } } label: {
                            Text(sync.busy ? "Syncing..." : "Sync now").font(.jk(17, .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16).background(T.blue).clipShape(Capsule())
                        }
                        Button { sync.signOut() } label: {
                            Text("Sign out").font(.jk(16, .semibold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14).background(T.card2).clipShape(Capsule())
                        }
                    } else {
                        TextField("Username", text: $u).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(14).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 12))
                        SecureField("Password", text: $p)
                            .padding(14).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 12))
                        HStack(spacing: 10) {
                            Button { sync.api = url; Task { await sync.auth(u, p, create: false, game: game) } } label: {
                                Text("Sign in").font(.jk(16, .bold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(T.blue).clipShape(Capsule())
                            }
                            Button { sync.api = url; Task { await sync.auth(u, p, create: true, game: game) } } label: {
                                Text("Create account").font(.jk(16, .bold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(T.card2).clipShape(Capsule())
                            }
                        }
                        if !sync.msg.isEmpty { Text(sync.msg).font(.jk(13)).foregroundColor(T.sub) }
                    }
                    Text("Server").font(.jk(12, .bold)).foregroundColor(T.sub).padding(.top, 8)
                    TextField("Server", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.jk(13)).padding(10).background(T.card2).clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: url) { sync.api = $0 }
                    Text("Custom worlds stay on this device. Preset worlds sync.").font(.jk(12)).foregroundColor(T.sub)
                }.padding(16)
            }
            .background(T.bg)
            .navigationTitle("Account Sync").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
