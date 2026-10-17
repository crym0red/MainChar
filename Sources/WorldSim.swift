import SwiftUI

// MARK: - Living world: the world keeps moving while you're away

extension Game {
    static let minAway: TimeInterval = 20 * 60
    static let dailyAuraBudget = 16
    static let dailyFolBudget = 0.14

    // MARK: Clock

    /// Call when the app leaves the foreground: the world is simulated up to this moment.
    func stampSim() {
        guard playing else { return }
        var st = s
        st.ex.lastSim = Date()
        s = st
        flush()
    }

    func dismissDigest() {
        var st = s
        st.ex.digest = nil
        s = st
    }

    // MARK: History

    func addHistory(_ st: inout GameState, _ emoji: String, _ title: String, _ detail: String,
                    post: UUID? = nil, handles: [String]? = nil) {
        var h = st.ex.history ?? []
        var item = HistoryItem(day: st.day, emoji: emoji, title: title, detail: detail)
        item.date = st.ex.simNow ?? Date()
        item.postID = post
        item.handles = handles
        h.insert(item, at: 0)
        if h.count > 150 { h.removeLast(h.count - 150) }
        st.ex.history = h
    }

    // MARK: Daily limits so popularity can't swing wildly

    private func rollBudget(_ st: inout GameState) {
        let k = Game.dayKey(Date())
        if st.ex.simDay != k {
            st.ex.simDay = k
            st.ex.simAuraUsed = 0
            st.ex.simFolUsed = 0
        }
    }

    private func spendBudget(_ st: inout GameState, aura: Int, fol: Double) {
        st.ex.simAuraUsed = (st.ex.simAuraUsed ?? 0) + abs(aura)
        st.ex.simFolUsed = (st.ex.simFolUsed ?? 0) + abs(fol)
    }

    // MARK: Catch-up when you come back

    func catchUp() {
        guard playing, s.intro?.done != false else { return }
        var st = s
        let now = Date()
        guard let last = st.ex.lastSim else {
            st.ex.lastSim = now
            s = st
            return
        }
        // clock moved backwards: just resync, never simulate negative time
        if last > now {
            st.ex.lastSim = now
            s = st
            return
        }
        let away = now.timeIntervalSince(last)
        // short absences accumulate instead of being thrown away
        guard away >= Game.minAway else { return }

        pruneLive(&st)
        rollBudget(&st)
        let hrs = min(away, 48 * 3600) / 3600
        let ticks = min(14, max(1, Int(hrs * 1.5) + 1))
        let auraCap = min(10, 2 + Int(hrs))
        let folCap = min(0.10, 0.01 + hrs * 0.006)
        let allowA = max(0, min(auraCap, Game.dailyAuraBudget - (st.ex.simAuraUsed ?? 0)))
        let allowF = max(0.0, min(folCap, Game.dailyFolBudget - (st.ex.simFolUsed ?? 0)))

        if away >= 3600 { checkIgnored(&st) }
        let f0 = st.followers
        let a0 = st.aura
        var items: [DigestItem] = []
        for i in 0..<ticks {
            st.ex.simNow = last.addingTimeInterval(away * Double(i + 1) / Double(ticks + 1))
            let fb = st.followers, ab = st.aura, nb = items.count
            simTick(&st, &items, quiet: false)
            if items.count > nb, let k = items[nb...].indices.max(by: { (items[$0].weight ?? 0) < (items[$1].weight ?? 0) }) {
                items[k].fol = st.followers - fb
                items[k].aura = st.aura - ab
            }
        }
        st.ex.simNow = nil
        marketAdvance(&st, &items, steps: min(400, Int(away / 10)), quiet: false)
        checkSeason(&st, &items, quiet: false)

        // slow drift in your popularity, scaled by how long you were gone
        let scale = min(1.0, hrs / 8)
        var pct = Double.random(in: -0.003...0.006) * scale
        if st.aura >= 60 { pct += 0.004 * scale } else if st.aura < 30 { pct -= 0.006 * scale }
        st.followers = max(10, Int(Double(st.followers) * (1 + pct)))
        if hrs >= 4 {
            if st.aura > 55 { st.aura -= 1 } else if st.aura < 45 { st.aura += 1 }
        }

        // hard limits on the net swing
        var rawF = st.followers - f0
        var rawA = st.aura - a0
        let capF = Int(Double(f0) * allowF)
        var scaleF = 1.0
        var scaleA = 1.0
        if abs(rawF) > capF {
            scaleF = capF == 0 ? 0 : Double(capF) / Double(abs(rawF))
            st.followers = f0 + (rawF > 0 ? capF : -capF)
            rawF = st.followers - f0
        }
        if abs(rawA) > allowA {
            scaleA = allowA == 0 ? 0 : Double(allowA) / Double(abs(rawA))
            st.aura = a0 + (rawA > 0 ? allowA : -allowA)
            rawA = st.aura - a0
        }
        if a0 >= 5 && a0 <= 95 { st.aura = min(95, max(5, st.aura)) }
        rawA = st.aura - a0
        for i in items.indices {
            if let f = items[i].fol { items[i].fol = Int(Double(f) * scaleF) }
            if let a = items[i].aura { items[i].aura = Int(Double(a) * scaleA) }
        }
        spendBudget(&st, aura: rawA, fol: f0 > 0 ? Double(abs(rawF)) / Double(f0) : 0)

        st.ex.lastSim = now
        if st.posts.count > 120 { st.posts.removeLast(st.posts.count - 120) }

        // the recap may only mention posts that really are in the feed
        let present = Set(st.posts.map { $0.id })
        items = items.filter { $0.postID == nil || present.contains($0.postID!) }

        if !items.isEmpty {
            let ranked = items.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }
            let shown = Array(ranked.prefix(8)).sorted { ($0.at ?? .distantPast) > ($1.at ?? .distantPast) }
            let more = items.count - shown.count
            var d = Digest(items: shown, followerDelta: rawF, auraDelta: rawA, minutes: Int(away / 60), more: more)
            if var old = st.ex.digest {
                // an earlier recap was never opened: keep it, and add what happened since
                let keep = old.items.filter { $0.postID == nil || present.contains($0.postID!) }
                old.items = Array((shown + keep).sorted { ($0.at ?? .distantPast) > ($1.at ?? .distantPast) }.prefix(10))
                old.followerDelta += rawF
                old.auraDelta += rawA
                old.minutes += Int(away / 60)
                old.more = (old.more ?? 0) + more
                d = old
            }
            st.ex.digest = d
            let hero = ranked.first
            notify(&st, "event", "While you were away", sub: hero?.title ?? "Your world kept moving", emoji: "🌍")
        }
        s = st
        flush()
        checkBadges()
    }

    /// Small live events while the app is open.
    func ambientTick() {
        guard playing, s.intro?.done != false else { return }
        marketAmbient()
        var st = s
        let now = Date()
        let last = st.ex.lastSim ?? now
        // the world is "live" while the app is open
        if now.timeIntervalSince(last) > 90 || last > now {
            st.ex.lastSim = now
            s = st
        }
        pruneLive(&st)
        rollBudget(&st)
        guard (st.ex.simAuraUsed ?? 0) < Game.dailyAuraBudget,
              (st.ex.simFolUsed ?? 0) < Game.dailyFolBudget else { return }
        guard Double.random(in: 0...1) < 0.5 else { return }
        var items: [DigestItem] = []
        let fb = st.followers, ab = st.aura
        simTick(&st, &items, quiet: true)
        st.aura = min(95, max(5, st.aura))
        spendBudget(&st, aura: st.aura - ab, fol: fb > 0 ? Double(abs(st.followers - fb)) / Double(fb) : 0)
        if st.posts.count > 120 { st.posts.removeLast(st.posts.count - 120) }
        s = st
    }

    // MARK: One simulation step

    private func simTick(_ st: inout GameState, _ items: inout [DigestItem], quiet: Bool) {
        let cast = st.npcs.filter { $0.id != "newsdesk" }
        guard cast.count >= 2 else { return }
        if let sp = st.ex.spotlight, sp > 0 {
            st.ex.spotlight = sp - 1
            if sp - 1 == 0 { fadeHype(&st, &items, quiet) }
            let q = Double.random(in: 0...1)
            if q < 0.30 { simScrutiny(&st, &items, cast, quiet); return }
            if q < 0.42 { simOffer(&st, &items, cast, quiet); return }
        }
        growWorld(&st, &items, quiet)
        if Double.random(in: 0...1) < 0.07 { simCoinLaunch(&st, &items, cast, quiet); return }
        let pre = Double.random(in: 0...1)
        if pre < 0.16 { simStory(&st, &items, cast, quiet); return }
        if pre < 0.27 { simGoLive(&st, &items, cast, quiet); return }
        if pre < 0.42, CastGen.isScene(st.world) { simScene(&st, &items, cast, quiet); return }
        let r = Double.random(in: 0...1)
        if r < 0.24 { simPost(&st, &items, cast, quiet) }
        else if r < 0.48 { simBeef(&st, &items, cast, quiet) }
        else if r < 0.58 { simResurface(&st, &items, cast, quiet) }
        else if r < 0.64 { simMajor(&st, &items, quiet) }
        else if r < 0.80 { if !simMemoryPost(&st, &items, cast, quiet) { simPost(&st, &items, cast, quiet) } }
        else if r < 0.92 { if !simMemoryDM(&st, &items, cast, quiet) { simBeef(&st, &items, cast, quiet) } }
        else { simPost(&st, &items, cast, quiet) }
    }
}
