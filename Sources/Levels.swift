import SwiftUI

struct LevelBadge: Codable, Hashable, Identifiable {
    var id: String
    var level: Int
    var name: String
    var symbol: String
}

struct LvReward {
    var gems: Int
    var points: Int
    var itemName: String? = nil
    var itemSymbol: String? = nil
    var item: Int? = nil          // 0 gifts, 1 viral, 2 shield, 3 squad
    var badge: LevelBadge? = nil
    var crate: Bool = false
}

enum Levels {
    static let ladder: [(String, String)] = [
        ("Script Kiddie", "chevron.left.forwardslash.chevron.right"), ("Tweak Dev", "wrench.and.screwdriver.fill"),
        ("Cert Wrangler", "checkmark.seal.fill"), ("Dylib Smith", "hammer.fill"), ("Kernel Poet", "cpu"),
        ("Root Access", "terminal.fill"), ("Zero Day", "ladybug.fill"), ("Jailbreak Legend", "lock.open.fill"),
        ("Scene Icon", "crown.fill"), ("Mythic", "sparkles")
    ]
    static let items: [(String, String)] = [("Gift pack x2", "gift.fill"), ("Viral charge", "bolt.fill"), ("Shield", "shield.lefthalf.filled"), ("Hype squad", "person.3.fill")]
    static let keystones = [10, 25, 50, 75, 100]
    static let keystoneGems = [5, 10, 25, 50, 100]

    /// XP needed to go from `level` to `level + 1`. Gets steep.
    static func need(_ l: Int) -> Int { 40 + 5 * l + (l * l) / 40 }

    static func skillCost(_ v: Int) -> Int { 1 + v / 10 }

    static func reward(_ l: Int) -> LvReward {
        var r = LvReward(gems: 2 + l / 20, points: l % 5 == 0 ? 5 : 2)
        if l % 5 == 0 {
            let it = items[(l / 5) % items.count]
            r.item = (l / 5) % items.count; r.itemName = it.0; r.itemSymbol = it.1
        }
        if l % 10 == 0 {
            let idx = (l / 10 - 1) % ladder.count
            let cycle = (l / 10 - 1) / ladder.count
            let name = ladder[idx].0 + (cycle > 0 ? " Tier \(cycle + 1)" : "")
            r.badge = LevelBadge(id: "lv\(l)", level: l, name: name, symbol: ladder[idx].1)
            r.gems += 10
        }
        if l % 50 == 0 { r.crate = true; r.gems += 50 }
        return r
    }

    static func summary(_ r: LvReward) -> String {
        var p = ["+\(r.gems) gems", "+\(r.points) skill points"]
        if let i = r.itemName { p.append(i) }
        if let b = r.badge { p.append("\(b.name) badge") }
        if r.crate { p.append("Legend crate") }
        return p.joined(separator: ", ")
    }
}

extension Game {
    func applyLevelReward(_ st: inout GameState, level: Int) {
        let r = Levels.reward(level)
        st.points += r.points
        st.ex.gems += r.gems
        switch r.item {
        case 0: st.ex.gifts += 2
        case 1: st.ex.viralArmed = true
        case 2: st.ex.shield = true
        case 3: st.ex.squad = true
        default: break
        }
        if let b = r.badge {
            var list = st.ex.lvBadges ?? []
            if !list.contains(where: { $0.id == b.id }) { list.append(b) }
            st.ex.lvBadges = list
        }
        notify(&st, "level", "Level \(level) reached", sub: Levels.summary(r), emoji: r.badge != nil ? "🏆" : "⭐")
    }

    func checkKeystones(_ st: inout GameState) {
        var keys = st.ex.keys ?? []
        var changed = false
        for sk in st.skills {
            for (i, t) in Levels.keystones.enumerated() where sk.value >= t {
                let k = "\(sk.name)#\(t)"
                if keys.contains(k) { continue }
                keys.append(k); changed = true
                st.ex.gems += Levels.keystoneGems[i]
                var list = st.ex.lvBadges ?? []
                list.append(LevelBadge(id: "key-" + k, level: st.level, name: "\(sk.name) \(t)", symbol: "star.circle.fill"))
                st.ex.lvBadges = list
                notify(&st, "milestone", "Keystone: \(sk.name) \(t)", sub: "+\(Levels.keystoneGems[i]) gems, +1% XP forever", emoji: "🌟")
            }
        }
        if changed { st.ex.keys = keys }
    }
}
