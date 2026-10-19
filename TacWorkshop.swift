import SwiftUI
import UIKit

// MARK: - Workshop data (sprite guns + tile maps)

struct WSGun: Codable, Identifiable {
    var id: String
    var name: String
    var base: String
    var px: String
}

struct WSMap: Codable, Identifiable {
    var id: String
    var name: String
    var cells: String
    var desc: String
}

enum TWorkshop {
    static let gw = 32, gh = 14
    static let mw = 36, mh = 20
    static let defPal = ["1c1c20", "4a4d55", "8d939e", "d8dce4", "7a4a26", "b98a52", "2f5a2a", "7fb04a", "a02a2a", "e0453a", "e8a21a", "f5e050", "1f4f9a", "4aa3e0", "ffffff"]
    private static let ud = UserDefaults.standard

    static var pal: [String] {
        get { let a = ud.stringArray(forKey: "ws.pal") ?? []; return a.count == 15 ? a : defPal }
        set { ud.set(newValue, forKey: "ws.pal") }
    }

    static func rgb(_ h: String) -> (Double, Double, Double) {
        let v = UInt32(h, radix: 16) ?? 0x888888
        return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    static func hexColor(_ h: String) -> Color {
        let c = rgb(h)
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    static func hexOf(_ c: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }

    // MARK: guns (named slots, one equipped per base gun)

    static func newId() -> String { UUID().uuidString }

    static var guns: [WSGun] {
        get {
            guard let d = ud.data(forKey: "ws.guns"), let a = try? JSONDecoder().decode([WSGun].self, from: d) else { return [] }
            return a
        }
        set { if let d = try? JSONEncoder().encode(newValue) { ud.set(d, forKey: "ws.guns") } }
    }

    static var maps: [WSMap] {
        get {
            if let d = ud.data(forKey: "ws.maps"), let a = try? JSONDecoder().decode([WSMap].self, from: d), !a.isEmpty { return a }
            return [WSMap(id: newId(), name: "Harbor Base", cells: cellsString(defaultMap()), desc: "A custom harbor map with multiple routes, cover and close quarters combat.")]
        }
        set { if let d = try? JSONEncoder().encode(newValue) { ud.set(d, forKey: "ws.maps") } }
    }

    static var mapSel: String {
        get { ud.string(forKey: "ws.mapSel") ?? "" }
        set { ud.set(newValue, forKey: "ws.mapSel") }
    }

    static var currentMap: WSMap {
        let m = maps
        return m.first(where: { $0.id == mapSel }) ?? m[0]
    }

    static func equippedId(_ base: String) -> String? { ud.string(forKey: "ws.eq." + base) }
    static func setEquipped(_ base: String, _ id: String?) {
        if let id = id { ud.set(id, forKey: "ws.eq." + base) } else { ud.removeObject(forKey: "ws.eq." + base) }
    }

    static func pxArray(_ s: String) -> [UInt8] {
        var a = [UInt8](repeating: 0, count: gw * gh)
        for (i, ch) in s.enumerated() where i < a.count { a[i] = UInt8(String(ch), radix: 16) ?? 0 }
        return a
    }

    static func pxString(_ a: [UInt8]) -> String { a.map { String($0, radix: 16) }.joined() }

    static func sprite(_ base: String) -> [UInt8] {
        guard let id = equippedId(base), let g = guns.first(where: { $0.id == id }) else { return [UInt8](repeating: 0, count: gw * gh) }
        return pxArray(g.px)
    }

    typealias Rect = (x: Int, y: Int, w: Int, h: Int, c: Int)

    /// greedy rectangle merge so a sprite becomes the fewest boxes
    static func rects(_ sp: [UInt8]) -> [Rect] {
        var used = [Bool](repeating: false, count: sp.count)
        var out: [Rect] = []
        for y in 0..<gh {
            for x in 0..<gw {
                let c = sp[y * gw + x]
                if c == 0 || used[y * gw + x] { continue }
                var w = 1
                while x + w < gw && sp[y * gw + x + w] == c && !used[y * gw + x + w] { w += 1 }
                var h = 1
                outer: while y + h < gh {
                    for k in 0..<w where sp[(y + h) * gw + x + k] != c || used[(y + h) * gw + x + k] { break outer }
                    h += 1
                }
                for yy in y..<(y + h) { for xx in x..<(x + w) { used[yy * gw + xx] = true } }
                out.append((x, y, w, h, Int(c)))
            }
        }
        return out
    }

    /// called by TwGunLib.load(): registers palette materials and swaps sprite guns into the rigs
    static func inject() {
        guard var rs = TwGunLib.rigs else { return }
        let p = pal
        for i in 1...15 {
            let c = rgb(p[i - 1])
            TwGunLib.defs["cg\(i)"] = ["c": [c.0, c.1, c.2], "sp": 0.3, "sh": 0.3, "rf": 0.0, "a": 1.0] as [String: Any]
        }
        let arm: Set<String> = ["glove", "sleeve", "sleeveDark", "knuckle", "strap", "skin", "nail"]
        for (gid, any) in rs {
            let sp = sprite(gid)
            if !sp.contains(where: { $0 != 0 }) { continue }
            guard var rig = any as? [String: Any] else { continue }
            let rs2 = rects(sp)
            // first-person: barrel along -z
            let parts = (rig["parts"] as? [[String: Any]]) ?? []
            var keep = parts.filter { arm.contains(($0["m"] as? String) ?? "") }
            let body = parts.filter { !arm.contains(($0["m"] as? String) ?? "") }
            var x0 = 1e9, x1 = -1e9, y1 = -1e9, z0 = 1e9, z1 = -1e9
            for q in body {
                guard let pos = q["p"] as? [Double], let s = q["s"] as? [Double], pos.count == 3, s.count == 3 else { continue }
                x0 = min(x0, pos[0] - s[0] / 2); x1 = max(x1, pos[0] + s[0] / 2)
                y1 = max(y1, pos[1] + s[1] / 2)
                z0 = min(z0, pos[2] - s[2] / 2); z1 = max(z1, pos[2] + s[2] / 2)
            }
            if let m = rig["muzzle"] as? [Double], m.count == 3 { z0 = min(z0, m[2]) }
            if x1 < x0 || z1 <= z0 { continue }
            let cl = (z1 - z0) / Double(gw)
            let th = min(5.0, max(2.0, cl * 1.4))
            let cx = (x0 + x1) / 2
            let top = y1 + 3 * cl
            for r in rs2 {
                let z = z1 - (Double(r.x) + Double(r.w) / 2) * cl
                let y = top - (Double(r.y) + Double(r.h) / 2) * cl
                keep.append(["t": "box", "m": "cg\(r.c)", "p": [cx, y, z], "q": [0.0, 0.0, 0.0, 1.0], "s": [th, Double(r.h) * cl, Double(r.w) * cl], "c": 0.0])
            }
            rig["parts"] = keep
            // world model: +x forward
            if var w = rig["w"] as? [String: Any], let wp = w["parts"] as? [[String: Any]] {
                var a0 = 1e9, a1 = -1e9, b1 = -1e9
                for q in wp {
                    guard let pos = q["p"] as? [Double], let s = q["s"] as? [Double], let qq = q["q"] as? [Double], pos.count == 3, s.count == 3, qq.count == 4 else { continue }
                    let ex = abs(qq[1]) > 0.5 ? s[2] : s[0]
                    a0 = min(a0, pos[0] - ex / 2); a1 = max(a1, pos[0] + ex / 2)
                    b1 = max(b1, pos[1] + s[1] / 2)
                }
                if a1 > a0 {
                    a1 = max(a1, (w["mx"] as? Double) ?? a1)
                    let wl = (a1 - a0) / Double(gw)
                    let wt = min(2.2, max(0.7, wl * 1.4))
                    let wtop = b1 + 3 * wl
                    var np: [[String: Any]] = []
                    for r in rs2 {
                        np.append(["t": "box", "m": "cg\(r.c)", "p": [a0 + (Double(r.x) + Double(r.w) / 2) * wl, wtop - (Double(r.y) + Double(r.h) / 2) * wl, 0.0],
                                   "q": [0.0, 0.0, 0.0, 1.0], "s": [Double(r.w) * wl, Double(r.h) * wl, wt], "c": 0.0])
                    }
                    w["parts"] = np
                    w["mx"] = a1
                    rig["w"] = w
                }
            }
            rs[gid] = rig
        }
        TwGunLib.rigs = rs
    }

    // MARK: map

    /// tile ids: 0 floor, 1 wall, 2 crate, 3 barrel, 4 sandbag, 5 car, 6 table, 7 shelf, 8 spawn, 9 loot
    static let tileNames = ["Floor", "Wall", "Crate", "Barrel", "Sandbag", "Car", "Table", "Shelf", "Spawn", "Loot"]
    static let tileIcons = ["square.stack.3d.up.fill", "rectangle.split.3x3.fill", "shippingbox.fill", "cylinder.fill", "rectangle.split.2x1.fill", "car.fill", "table.furniture.fill", "books.vertical.fill", "figure.walk", "diamond.fill"]
    static let tileCols: [Color] = [Color(white: 0.16), Color(white: 0.72), Color(red: 0.55, green: 0.38, blue: 0.2), Color(red: 0.9, green: 0.5, blue: 0.1),
                                    Color(red: 0.75, green: 0.68, blue: 0.45), Color(red: 0.2, green: 0.45, blue: 0.85), Color(red: 0.6, green: 0.45, blue: 0.3),
                                    Color(red: 0.6, green: 0.3, blue: 0.7), Color(red: 0.2, green: 0.9, blue: 0.3), Color(red: 1.0, green: 0.8, blue: 0.2)]
    static let presetNames = ["Harbor Base", "Warehouse", "Arena", "Blank"]

    static func cellsString(_ a: [UInt8]) -> String { a.map { String($0, radix: 16) }.joined() }

    static func cellsArray(_ s: String) -> [UInt8] {
        if s.count != mw * mh { return defaultMap() }
        return s.map { UInt8(String($0), radix: 16) ?? 0 }
    }

    static func preset(_ name: String) -> [UInt8] {
        var a = [UInt8](repeating: 0, count: mw * mh)
        func box(_ c0: Int, _ r0: Int, _ c1: Int, _ r1: Int, _ v: UInt8) { for r in r0...r1 { for c in c0...c1 { a[r * mw + c] = v } } }
        func put(_ c: Int, _ r: Int, _ v: UInt8) { if c >= 0 && c < mw && r >= 0 && r < mh { a[r * mw + c] = v } }
        switch name {
        case "Warehouse":
            box(4, 2, 16, 8, 1); box(5, 3, 15, 7, 0); box(9, 8, 11, 8, 0)
            box(19, 11, 31, 17, 1); box(20, 12, 30, 16, 0); box(24, 11, 26, 11, 0)
            for (c, r) in [(7, 4), (8, 4), (13, 5), (22, 14), (23, 14), (28, 13), (10, 12), (11, 12), (2, 15), (33, 4), (16, 15)] { put(c, r, 2) }
            for (c, r) in [(6, 7), (14, 4), (21, 15), (29, 15)] { put(c, r, 7) }
            for (c, r) in [(18, 9), (19, 9), (17, 5)] { put(c, r, 4) }
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
            put(10, 5, 9); put(25, 14, 9); put(18, 10, 9)
        case "Arena":
            box(16, 7, 19, 12, 1); box(17, 8, 18, 11, 0); put(17, 7, 0); put(18, 12, 0)
            for (c, r) in [(8, 4), (8, 15), (27, 4), (27, 15), (12, 9), (23, 10), (5, 9), (30, 10)] { put(c, r, 2); put(c + 1, r, 2) }
            for (c, r) in [(14, 3), (21, 16), (3, 5), (32, 14)] { put(c, r, 3) }
            for (c, r) in [(10, 6), (25, 13), (14, 14), (21, 5)] { put(c, r, 4); put(c + 1, r, 4) }
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
            put(17, 9, 9); put(18, 10, 9)
        case "Blank":
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
        default:
            return defaultMap()
        }
        return a
    }

    static func defaultMap() -> [UInt8] {
        var a = [UInt8](repeating: 0, count: mw * mh)
        func box(_ c0: Int, _ r0: Int, _ c1: Int, _ r1: Int, _ v: UInt8) { for r in r0...r1 { for c in c0...c1 { a[r * mw + c] = v } } }
        func put(_ c: Int, _ r: Int, _ v: UInt8) { if c >= 0 && c < mw && r >= 0 && r < mh { a[r * mw + c] = v } }
        box(5, 3, 13, 8, 1); box(6, 4, 12, 7, 0); box(8, 8, 10, 8, 0); put(9, 5, 9); put(7, 6, 6)
        box(23, 11, 31, 16, 1); box(24, 12, 30, 15, 0); box(26, 11, 28, 11, 0); put(27, 14, 9); put(25, 13, 7)
        for (c, r) in [(17, 4), (18, 4), (16, 9), (19, 10), (20, 5), (15, 14), (16, 14), (3, 12), (4, 12), (31, 5), (32, 5), (22, 18), (12, 17)] { put(c, r, 2) }
        for (c, r) in [(18, 8), (17, 12), (21, 8), (14, 11)] { put(c, r, 3) }
        for (c, r) in [(10, 11), (11, 11), (24, 6), (25, 6), (28, 19)] { put(c, r, 4) }
        put(20, 14, 5); put(8, 14, 5)
        for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
        put(18, 6, 9); put(18, 13, 9)
        return a
    }
}

// MARK: - Custom map (kind 5)

enum TCustom {
    private static var cache: MapData?

    static func invalidate() {
        cache = nil
        TMap.needsApply = true
    }

    static var shared: MapData {
        if let c = cache { return c }
        let m = build()
        cache = m
        return m
    }

    private static func build() -> MapData {
        let cells = TWorkshop.cellsArray(TWorkshop.currentMap.cells)
        let mw = TWorkshop.mw, mh = TWorkshop.mh
        let ox: CGFloat = 150, oy: CGFloat = 150, ts: CGFloat = 75
        let b = MapBuilder()
        let rc = b.rc
        let arena = rc(150, 150, 2700, 1500)
        b.setR(1, arena, true)
        b.tiles.insert(TRoom(name: "Arena", r: MapBuilder.R(1, arena), mat: 8, fl: 1), at: 0)
        b.rooms.append(TRoom(name: "West Side", r: MapBuilder.R(1, rc(150, 150, 1350, 1500)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "East Side", r: MapBuilder.R(1, rc(1500, 150, 1350, 1500)), mat: 8, fl: 1))

        var free: [CGPoint] = [], marked: [CGPoint] = [], lootM: [CGPoint] = []
        for r in 0..<mh {
            for c in 0..<mw {
                let v = Int(cells[r * mw + c])
                let x = ox + CGFloat(c) * ts, y = oy + CGFloat(r) * ts
                let mid = CGPoint(x: x + ts / 2, y: y + ts / 2)
                switch v {
                case 1: b.setR(1, rc(x, y, ts, ts), false)
                case 2: b.p(1, .crate, x + 2, y + 2, 70, 70)
                case 3: b.p(1, .barrel, x + 19, y + 19, 36, 36)
                case 4: b.p(1, .sandbag, x, y + 22, ts, 32)
                case 5: b.p(1, .car, x, y + 9, ts, 56)
                case 6: b.p(1, .table, x + 5, y + 15, 65, 45)
                case 7: b.p(1, .shelf, x, y + 23, ts, 28)
                case 8: marked.append(mid); free.append(mid)
                case 9: lootM.append(mid); free.append(mid)
                default: free.append(mid)
                }
            }
        }
        if free.isEmpty { free = [CGPoint(x: 300, y: 300), CGPoint(x: 2700, y: 1500)] }

        func spread(_ n: Int, _ seed: [CGPoint]) -> [CGPoint] {
            var out = seed
            var g = 0
            while out.count < n && g < 400 {
                var best = free[0]
                var bd: CGFloat = -1
                for p in free {
                    var d = CGFloat.infinity
                    for q in out { d = min(d, hypot(p.x - q.x, p.y - q.y)) }
                    if d > bd { bd = d; best = p }
                }
                out.append(best)
                g += 1
            }
            return out
        }
        let sp = Array(spread(20, Array(marked.prefix(20))).prefix(20))
        let spawns = sp.map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let byX = sp.sorted { $0.x < $1.x }
        let atk = byX.prefix(5).map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let def = byX.suffix(5).map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let packs = spread(24, sp).suffix(4).map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let lootPts = lootM.isEmpty ? Array(spread(28, sp).suffix(8)) : lootM
        let ids = ["g:rifle", "med", "ammo", "armor:2", "g:smg", "plate", "band", "kit", "g:m4", "armor:1"]
        var lootList: [(CGPoint, String)] = []
        for (i, p) in lootPts.enumerated() { lootList.append((CGPoint(x: p.x + TMap.off, y: p.y), ids[i % ids.count])) }

        let layout = b.layout([.brick, .concrete, .concrete])
        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: [], stairLo: [],
                         siteA: MapBuilder.R(1, rc(250, 300, 450, 300)), siteB: MapBuilder.R(1, rc(2300, 1200, 450, 300)),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(1300, 700, 400, 200)),
                         floorNames: ["", "CUSTOM", ""], loot: lootList, roofs: b.roofs, spawns: spawns)
        md.siteNames = ["A · WEST", "B · EAST"]
        return md
    }
}

// MARK: - Workshop screen

struct CSWorkshop: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void
    let playMap: () -> Void

    @State private var tab = 0
    @State private var guns: [WSGun] = TWorkshop.guns
    @State private var gunId = ""
    @State private var grid: [UInt8] = [UInt8](repeating: 0, count: TWorkshop.gw * TWorkshop.gh)
    @State private var ink: UInt8 = 3
    @State private var tool = 0
    @State private var undo: [UInt8] = []
    @State private var pal = TWorkshop.pal
    @State private var ver = 0
    @State private var stroke = false
    @State private var yaw: Double = 0
    @State private var maps: [WSMap] = TWorkshop.maps
    @State private var mapId = ""
    @State private var cells: [UInt8] = []
    @State private var tile: UInt8 = 1
    @State private var mUndo: [UInt8] = []
    @State private var presetPick = "Harbor Base"
    @State private var rename = false
    @State private var renameTarget = 0
    @State private var renameText = ""
    @State private var shareText = ""
    @State private var showShare = false
    @State private var note = ""

    private let gw = TWorkshop.gw, gh = TWorkshop.gh, mw = TWorkshop.mw, mh = TWorkshop.mh

    private var gunIdx: Int? { guns.firstIndex(where: { $0.id == gunId }) }
    private var mapIdx: Int? { maps.firstIndex(where: { $0.id == mapId }) }
    private var base: String { gunIdx.map { guns[$0].base } ?? nav.tacGun }

    // MARK: gun data ops

    private func syncGuns() { TWorkshop.guns = guns }

    private func loadGun(_ id: String) {
        gunId = id
        if let i = gunIdx {
            grid = TWorkshop.pxArray(guns[i].px)
            TWorkshop.setEquipped(guns[i].base, id)
        }
        undo = []
        TwGunLib.reloadRigs()
        ver += 1
    }

    private func commitGun() {
        guard let i = gunIdx else { return }
        guns[i].px = TWorkshop.pxString(grid)
        syncGuns()
        TWorkshop.setEquipped(guns[i].base, guns[i].id)
        TwGunLib.reloadRigs()
        ver += 1
    }

    private func newGun(base b: String? = nil, name: String? = nil, px: String? = nil) {
        let g = WSGun(id: TWorkshop.newId(), name: name ?? "Custom Gun \(guns.count + 1)", base: b ?? nav.tacGun, px: px ?? TWorkshop.pxString([UInt8](repeating: 0, count: gw * gh)))
        guns.append(g)
        syncGuns()
        loadGun(g.id)
    }

    private func deleteGun(_ id: String) {
        guard let i = guns.firstIndex(where: { $0.id == id }) else { return }
        let g = guns[i]
        if TWorkshop.equippedId(g.base) == id { TWorkshop.setEquipped(g.base, nil) }
        guns.remove(at: i)
        syncGuns()
        if guns.isEmpty { newGun() } else if gunId == id { loadGun(guns[0].id) } else { TwGunLib.reloadRigs(); ver += 1 }
    }

    private func setBase(_ id: String, _ b: String) {
        guard let i = guns.firstIndex(where: { $0.id == id }) else { return }
        if TWorkshop.equippedId(guns[i].base) == id { TWorkshop.setEquipped(guns[i].base, nil) }
        guns[i].base = b
        syncGuns()
        if gunId == id { TWorkshop.setEquipped(b, id) }
        TwGunLib.reloadRigs()
        ver += 1
    }

    // MARK: map data ops

    private func syncMaps() { TWorkshop.maps = maps }

    private func loadMap(_ id: String) {
        mapId = id
        TWorkshop.mapSel = id
        if let i = mapIdx { cells = TWorkshop.cellsArray(maps[i].cells) }
        mUndo = []
        TCustom.invalidate()
    }

    private func commitMap() {
        guard let i = mapIdx else { return }
        maps[i].cells = TWorkshop.cellsString(cells)
        syncMaps()
        TWorkshop.mapSel = mapId
        TCustom.invalidate()
    }

    private func newMap(name: String? = nil, cellsStr: String? = nil) {
        let m = WSMap(id: TWorkshop.newId(), name: name ?? "Custom Map \(maps.count + 1)", cells: cellsStr ?? TWorkshop.cellsString(TWorkshop.preset("Blank")), desc: "A custom map built in the Workshop.")
        maps.append(m)
        syncMaps()
        loadMap(m.id)
    }

    private func deleteMap(_ id: String) {
        guard maps.count > 1, let i = maps.firstIndex(where: { $0.id == id }) else { note = "Keep at least one map"; return }
        maps.remove(at: i)
        syncMaps()
        if mapId == id { loadMap(maps[0].id) }
    }

    private func importClipboard() {
        guard let s = UIPasteboard.general.string else { note = "Clipboard is empty"; return }
        let p = s.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if p.count >= 3, p[0] == "MAINSHOT-MAP", p[2].count == mw * mh { newMap(name: p[1], cellsStr: p[2]); tab = 1; note = "Map imported" }
        else if p.count >= 4, p[0] == "MAINSHOT-GUN", p[3].count == gw * gh { newGun(base: p[1], name: p[2], px: p[3]); tab = 0; note = "Gun imported" }
        else { note = "Nothing to import" }
    }

    // MARK: pieces

    private func thumb(_ px: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { ctx, sz in
            let a = TWorkshop.pxArray(px)
            let cs = min(sz.width / CGFloat(TWorkshop.gw), sz.height / CGFloat(TWorkshop.gh))
            for y in 0..<TWorkshop.gh {
                for x in 0..<TWorkshop.gw {
                    let v = Int(a[y * TWorkshop.gw + x])
                    if v > 0 { ctx.fill(Path(CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs + 0.3, height: cs + 0.3)), with: .color(TWorkshop.hexColor(pal[v - 1]))) }
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func mapThumb(_ s: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { ctx, sz in
            let a = TWorkshop.cellsArray(s)
            let cs = min(sz.width / CGFloat(TWorkshop.mw), sz.height / CGFloat(TWorkshop.mh))
            for y in 0..<TWorkshop.mh {
                for x in 0..<TWorkshop.mw {
                    let r = CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs + 0.3, height: cs + 0.3)
                    ctx.fill(Path(r), with: .color(TWorkshop.tileCols[Int(min(9, a[y * TWorkshop.mw + x]))]))
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func listRow(selected: Bool, name: String, sub: String, art: AnyView, menu: AnyView, tap: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Button(action: tap) {
                HStack(spacing: 6) {
                    art
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                        Text(sub).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(TuiPress())
            menu
        }
        .padding(.horizontal, 6).frame(height: 40)
        .background(selected ? LS.orange.opacity(0.12) : LS.card)
        .overlay(Rectangle().stroke(selected ? LS.orange : LS.line, lineWidth: selected ? 1.5 : 1))
    }

    private func toolBtn(_ icon: String, _ label: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 6) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold)).frame(width: 14)
                Text(label).font(.jk(10, .semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.85))
            .padding(.horizontal, 6).frame(height: 27)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func paintGun(_ p: CGPoint, _ cs: CGFloat) {
        let x = Int(p.x / cs), y = Int(p.y / cs)
        guard x >= 0, y >= 0, x < gw, y < gh, grid.count == gw * gh else { return }
        let first = !stroke
        if first { stroke = true; undo = grid }
        if tool == 2 { if first { flood(x, y) }; return }
        grid[y * gw + x] = tool == 1 ? 0 : ink
    }

    private func flood(_ sx: Int, _ sy: Int) {
        let target = grid[sy * gw + sx], to: UInt8 = ink
        if target == to { return }
        var st = [(sx, sy)]
        while let (x, y) = st.popLast() {
            if x < 0 || y < 0 || x >= gw || y >= gh || grid[y * gw + x] != target { continue }
            grid[y * gw + x] = to
            st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        }
    }

    private func mirror() {
        for y in 0..<gh { for x in 0..<(gw / 2) { grid.swapAt(y * gw + x, y * gw + (gw - 1 - x)) } }
    }

    // MARK: guns tab

    private func gunMenu(_ g: WSGun) -> AnyView {
        AnyView(Menu {
            Button("Rename") { renameTarget = 0; renameText = g.name; gunId = g.id; rename = true }
            Menu("Base Gun") {
                ForEach(TWeapons.all.map { $0.id }, id: \.self) { id in Button(TWeapons.w(id).name) { setBase(g.id, id) } }
            }
            Button("Duplicate") { newGun(base: g.base, name: g.name + " Copy", px: g.px) }
            Button("Share") { shareText = "MAINSHOT-GUN|\(g.base)|\(g.name)|\(g.px)"; showShare = true }
            Button("Delete", role: .destructive) { deleteGun(g.id) }
        } label: {
            SF("ellipsis").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.7)).rotationEffect(.degrees(90)).frame(width: 18, height: 28)
        })
    }

    private func gunsTab(_ W: CGFloat, _ ph: CGFloat) -> some View {
        let listW: CGFloat = 122, prevW: CGFloat = 112, gameW: CGFloat = 108
        let edW = W - 16 - listW - prevW - gameW - 15
        let toolsW: CGFloat = 64
        let cs = max(5, min((edW - 12 - toolsW - 6) / CGFloat(gw), (ph - 22 - 12 - 26) / CGFloat(gh)))
        let b = base
        return HStack(alignment: .top, spacing: 5) {
            LSPanel(title: "MY GUNS") {
                VStack(spacing: 4) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(guns) { g in
                                listRow(selected: g.id == gunId, name: g.name, sub: "Custom Gun · " + TWeapons.w(g.base).name,
                                        art: AnyView(thumb(g.px, 42, 18)), menu: gunMenu(g)) { loadGun(g.id) }
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        LSSmallButton(icon: "plus", label: "NEW") { newGun() }
                        LSSmallButton(icon: "square.and.arrow.down", label: "PASTE") { importClipboard() }
                    }
                }
                .padding(5)
            }
            .frame(width: listW, height: ph)
            LSPanel(title: "PIXEL EDITOR", trailing: "32 × 14") {
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 3) {
                        toolBtn("pencil", "Paint", tool == 0) { tool = 0 }
                        toolBtn("eraser.fill", "Erase", tool == 1) { tool = 1 }
                        toolBtn("drop.fill", "Fill", tool == 2) { tool = 2 }
                        toolBtn("arrow.left.arrow.right", "Mirror", false) { undo = grid; mirror(); commitGun() }
                        toolBtn("arrow.uturn.backward", "Undo", false) { if !undo.isEmpty { grid = undo; undo = []; commitGun() } }
                        toolBtn("trash.fill", "Clear", false) { undo = grid; grid = [UInt8](repeating: 0, count: gw * gh); commitGun() }
                    }
                    .frame(width: toolsW)
                    VStack(alignment: .leading, spacing: 5) {
                        Canvas { ctx, _ in
                            guard grid.count == gw * gh else { return }
                            for y in 0..<gh {
                                for x in 0..<gw {
                                    let r = CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs, height: cs)
                                    ctx.fill(Path(r), with: .color(Color.white.opacity((x + y) % 2 == 0 ? 0.05 : 0.1)))
                                    let v = Int(grid[y * gw + x])
                                    if v > 0 { ctx.fill(Path(r.insetBy(dx: 0.3, dy: 0.3)), with: .color(TWorkshop.hexColor(pal[v - 1]))) }
                                }
                            }
                        }
                        .frame(width: cs * CGFloat(gw), height: cs * CGFloat(gh))
                        .background(Color.black.opacity(0.35))
                        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { g in paintGun(g.location, cs) }
                            .onEnded { _ in stroke = false; commitGun() })
                        HStack(spacing: 3) {
                            ForEach(1...15, id: \.self) { i in
                                Button { ink = UInt8(i); if tool == 1 { tool = 0 } } label: {
                                    Rectangle().fill(TWorkshop.hexColor(pal[i - 1])).frame(width: 13, height: 13)
                                        .overlay(Rectangle().stroke(ink == UInt8(i) ? Color.white : Color.black.opacity(0.5), lineWidth: ink == UInt8(i) ? 2 : 1))
                                }
                                .buttonStyle(TuiPress())
                            }
                            ColorPicker("", selection: Binding(get: { TWorkshop.hexColor(pal[Int(max(1, ink)) - 1]) }, set: { c in
                                pal[Int(max(1, ink)) - 1] = TWorkshop.hexOf(c)
                                TWorkshop.pal = pal
                                commitGun()
                            })).labelsHidden().frame(width: 28)
                            Text("15 COLORS").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.6)).fixedSize()
                        }
                    }
                }
                .padding(6)
            }
            .frame(width: edW, height: ph)
            LSPanel(title: "3D PREVIEW") {
                ZStack(alignment: .bottomLeading) {
                    GunPreview3D(gid: b, sig: "ws\(ver)", yaw: yaw).allowsHitTesting(false)
                    LSSmallButton(icon: "arrow.triangle.2.circlepath", label: "ROTATE") { yaw += .pi / 2 }.padding(4)
                }
            }
            .frame(width: prevW, height: ph)
            LSPanel(title: "IN-GAME VIEW") {
                VStack(spacing: 5) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Color(red: 0.25, green: 0.45, blue: 0.7), Color(red: 0.5, green: 0.4, blue: 0.3)], startPoint: .top, endPoint: .bottom)
                        thumb(TWorkshop.pxString(grid), gameW - 14, (gameW - 14) * 0.44).rotationEffect(.degrees(-6)).offset(x: 6, y: -8)
                        Text("FIRST PERSON").font(.jk(7, .heavy)).foregroundColor(.white).padding(3)
                    }
                    .frame(height: 50).clipped()
                    ZStack(alignment: .bottomLeading) {
                        AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: 0, gun: b, yaw: 0.5, zoom: 1.5, sway: false).allowsHitTesting(false)
                        Text("ON SOLDIERS").font(.jk(7, .heavy)).foregroundColor(.white).padding(3)
                    }
                    .frame(height: 74).background(Color.black.opacity(0.3)).clipped()
                    Button { commitGun(); note = "Gun saved" } label: {
                        HStack(spacing: 5) {
                            SF("square.and.arrow.down.fill").font(.system(size: 11, weight: .bold))
                            Text("SAVE GUN").font(.jk(11, .heavy))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 30)
                        .background(LinearGradient(colors: [LS.orange, LS.orange2], startPoint: .top, endPoint: .bottom))
                    }
                    .buttonStyle(TuiPress())
                    Spacer(minLength: 0)
                }
                .padding(5)
            }
            .frame(width: gameW, height: ph)
        }
    }

    // MARK: maps tab

    private func mapMenu(_ m: WSMap) -> AnyView {
        AnyView(Menu {
            Button("Rename") { renameTarget = 1; renameText = m.name; mapId = m.id; rename = true }
            Button("Duplicate") { newMap(name: m.name + " Copy", cellsStr: m.cells) }
            Button("Share") { shareText = "MAINSHOT-MAP|\(m.name)|\(m.cells)"; showShare = true }
            Button("Delete", role: .destructive) { deleteMap(m.id) }
        } label: {
            SF("ellipsis").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.7)).rotationEffect(.degrees(90)).frame(width: 18, height: 28)
        })
    }

    private func mapsTab(_ W: CGFloat, _ ph: CGFloat) -> some View {
        let listW: CGFloat = 130, prevW: CGFloat = 190
        let edW = W - 16 - listW - prevW - 10
        let toolsW: CGFloat = 74
        let cs = max(5, min((edW - 12 - toolsW - 6) / CGFloat(mw), (ph - 22 - 12 - 34) / CGFloat(mh)))
        let cur = mapIdx.map { maps[$0] }
        return HStack(alignment: .top, spacing: 5) {
            LSPanel(title: "MY MAPS") {
                VStack(spacing: 4) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(maps) { m in
                                listRow(selected: m.id == mapId, name: m.name, sub: "Custom Map", art: AnyView(mapThumb(m.cells, 34, 20)), menu: mapMenu(m)) { loadMap(m.id) }
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        LSSmallButton(icon: "plus", label: "NEW") { newMap() }
                        LSSmallButton(icon: "square.and.arrow.down", label: "PASTE") { importClipboard() }
                    }
                }
                .padding(5)
            }
            .frame(width: listW, height: ph)
            LSPanel(title: "TILE EDITOR", trailing: "36 × 20") {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 6) {
                        VStack(spacing: 2) {
                            ForEach(0..<10, id: \.self) { i in
                                Button { tile = UInt8(i) } label: {
                                    HStack(spacing: 5) {
                                        Rectangle().fill(TWorkshop.tileCols[i]).frame(width: 10, height: 10)
                                        Text(TWorkshop.tileNames[i]).font(.jk(9, .semibold)).foregroundColor(tile == UInt8(i) ? LS.orange : .white.opacity(0.85))
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 5).frame(height: cs * CGFloat(mh) / 10 - 2)
                                    .background(tile == UInt8(i) ? LS.orange.opacity(0.16) : Color.black.opacity(0.35))
                                    .overlay(Rectangle().stroke(tile == UInt8(i) ? LS.orange : LS.line, lineWidth: 1))
                                }
                                .buttonStyle(TuiPress())
                            }
                        }
                        .frame(width: toolsW)
                        Canvas { ctx, _ in
                            guard cells.count == mw * mh else { return }
                            for y in 0..<mh {
                                for x in 0..<mw {
                                    let r = CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs, height: cs)
                                    ctx.fill(Path(r.insetBy(dx: 0.3, dy: 0.3)), with: .color(TWorkshop.tileCols[Int(min(9, cells[y * mw + x]))]))
                                }
                            }
                        }
                        .frame(width: cs * CGFloat(mw), height: cs * CGFloat(mh))
                        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let x = Int(g.location.x / cs), y = Int(g.location.y / cs)
                                guard x >= 0, y >= 0, x < mw, y < mh, cells.count == mw * mh else { return }
                                if !stroke { stroke = true; mUndo = cells }
                                cells[y * mw + x] = tile
                            }
                            .onEnded { _ in stroke = false; commitMap() })
                    }
                    HStack(spacing: 5) {
                        Text("PRESET LAYOUT").font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.7))
                        Menu {
                            ForEach(TWorkshop.presetNames, id: \.self) { n in Button(n) { presetPick = n } }
                        } label: {
                            HStack {
                                Text(presetPick).font(.jk(10, .semibold)).foregroundColor(.white)
                                Spacer(minLength: 4)
                                SF("chevron.down").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 8).frame(width: 110, height: 26).background(Color.black.opacity(0.45)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                        }
                        LSSmallButton(icon: "arrow.down.doc", label: "LOAD") { mUndo = cells; cells = TWorkshop.preset(presetPick); commitMap() }
                        LSSmallButton(icon: "trash", label: "CLEAR") { mUndo = cells; cells = [UInt8](repeating: 0, count: mw * mh); commitMap() }
                        LSSmallButton(icon: "arrow.uturn.backward", label: "UNDO") { if !mUndo.isEmpty { cells = mUndo; mUndo = []; commitMap() } }
                    }
                }
                .padding(6)
            }
            .frame(width: edW, height: ph)
            LSPanel(title: "MAP PREVIEW") {
                VStack(alignment: .leading, spacing: 5) {
                    ZStack(alignment: .bottomLeading) {
                        mapThumb(TWorkshop.cellsString(cells.count == mw * mh ? cells : TWorkshop.defaultMap()), prevW - 12, (prevW - 12) * 20 / 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(cur?.name ?? "").font(.jk(10, .heavy)).foregroundColor(.white)
                            Text("36 × 20 tiles").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.75))
                        }
                        .padding(4).background(Color.black.opacity(0.55))
                    }
                    Button { commitMap(); playMap() } label: {
                        HStack(spacing: 6) {
                            SF("play.fill").font(.system(size: 11, weight: .bold))
                            Text("PLAY MAP").font(.jk(12, .heavy))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 30).background(LS.green)
                    }
                    .buttonStyle(TuiPress())
                    Text("MAP INFO").font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        SF("mappin.circle.fill").font(.system(size: 16)).foregroundColor(.white.opacity(0.7))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(cur?.name ?? "").font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1)
                            Text("By \(TacProfile.name)").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Text(cur?.desc ?? "").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.65)).lineLimit(3)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        LSSmallButton(icon: "square.and.arrow.up", label: "SHARE") {
                            if let m = cur { shareText = "MAINSHOT-MAP|\(m.name)|\(m.cells)"; showShare = true }
                        }
                    }
                }
                .padding(6)
            }
            .frame(width: prevW, height: ph)
        }
    }

    var body: some View {
        let W = size.width, H = size.height
        let top: CGFloat = 86
        let ph = H - top - 6
        return ZStack(alignment: .topLeading) {
            LSTitle(title: "WORKSHOP", sub: "Create custom guns and maps. Play your creations.").position(x: 14 + 170, y: 26)
            HStack(spacing: 4) {
                LSTab(icon: "scope", label: "GUNS", on: tab == 0) { tab = 0 }
                LSTab(icon: "map.fill", label: "MAPS", on: tab == 1) { tab = 1 }
                if !note.isEmpty { Text(note).font(.jk(9, .heavy)).foregroundColor(TUI.gold).padding(.leading, 8) }
            }
            .position(x: 8 + 150, y: 62)
            Group {
                if tab == 0 { gunsTab(W, ph) } else { mapsTab(W, ph) }
            }
            .frame(width: W - 16, height: ph, alignment: .topLeading)
            .position(x: W / 2, y: top + ph / 2)
            if rename {
                RenameOverlay(text: $renameText) { ok in
                    if ok && !renameText.isEmpty {
                        if renameTarget == 0, let i = gunIdx { guns[i].name = renameText; syncGuns() }
                        if renameTarget == 1, let i = mapIdx { maps[i].name = renameText; syncMaps() }
                    }
                    rename = false
                }
                .frame(width: W, height: H)
            }
        }
        .frame(width: W, height: H)
        .sheet(isPresented: $showShare) { ShareSheet(text: shareText) }
        .onAppear {
            if guns.isEmpty { newGun() } else { loadGun(guns.first(where: { $0.id == gunId })?.id ?? guns[0].id) }
            maps = TWorkshop.maps
            loadMap(TWorkshop.currentMap.id)
        }
    }
}
