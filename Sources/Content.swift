import SwiftUI

/// Player-controlled content & language filter. Applied at pick time, so the corpus is never changed
/// and every switch takes effect immediately.
enum ContentPrefs {
    static var level: Int { UserDefaults.standard.object(forKey: "cl.level") as? Int ?? 2 }
    static var blockSlurs: Bool { UserDefaults.standard.object(forKey: "cl.slurs") as? Bool ?? true }
    static var blockSelfHarm: Bool { UserDefaults.standard.object(forKey: "cl.selfharm") as? Bool ?? true }
    static var blockViolence: Bool { UserDefaults.standard.object(forKey: "cl.violence") as? Bool ?? true }

    private static let strong = try! NSRegularExpression(pattern: "\\b(fuck\\w*|motherfuck\\w*|shit\\w*|bullshit|bitch\\w*|dick\\w*|asshole\\w*|dumbass|jackass|\\w+-ass|pussy|cock\\w*|piss\\w*|wtf|stfu|gtfo)\\b", options: .caseInsensitive)
    private static let mild = try! NSRegularExpression(pattern: "\\b(damn\\w*|hell|crap\\w*|ass|arse|bastard\\w*|prick|douche\\w*|suck\\w*)\\b", options: .caseInsensitive)
    private static let slur = try! NSRegularExpression(pattern: "(nigg|fagg|retard|cunt|tranny|chink|\\bspic\\b|kike|\\bcoon\\b|nazi)", options: .caseInsensitive)
    private static let selfHarm = try! NSRegularExpression(pattern: "\\b(kys|kill yourself|go die|unalive|end yourself|off yourself|hang yourself|drink bleach|slit your)\\b", options: .caseInsensitive)
    private static let violence = try! NSRegularExpression(pattern: "(kill you|beat you|stab|shoot|find where you live|know where you live|end you\\b|murder|burn your house|break your legs|hurt you|jump you)", options: .caseInsensitive)

    private static func n(_ r: NSRegularExpression, _ s: String) -> Int {
        r.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s))
    }

    static func allows(_ s: String) -> Bool {
        let lv = level
        if lv < 2 {
            let st = n(strong, s), ml = n(mild, s)
            if lv == 0 { if st + ml > 0 { return false } }
            else if st + ml > 1 || st > 1 { return false }
        }
        if blockSlurs, n(slur, s) > 0 { return false }
        if blockSelfHarm, n(selfHarm, s) > 0 { return false }
        if blockViolence, n(violence, s) > 0 { return false }
        return true
    }
}

struct ContentSection: View {
    @AppStorage("cl.level") private var level = 2
    @AppStorage("cl.slurs") private var slurs = true
    @AppStorage("cl.selfharm") private var selfHarm = true
    @AppStorage("cl.violence") private var violence = true

    var body: some View {
        Section(header: Text("Content & Language"),
                footer: Text(level == 0 ? "Characters keep it clean: no swearing." :
                                level == 1 ? "Occasional mild swearing. Harsh roasts stay playful." :
                                "Cussing, harsh roasts and hostile banter. Changes apply instantly.")) {
            Picker("Language filter", selection: $level) {
                Text("Clean").tag(0)
                Text("Moderate").tag(1)
                Text("Uncensored").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Block slurs and hateful language", isOn: $slurs)
            Toggle("Block content encouraging self-harm", isOn: $selfHarm)
            Toggle("Block explicit real-world violence threats", isOn: $violence)
        }
    }
}

// MARK: - 75% zoom: every screen lays out as if the display were 4/3 larger, then shrinks to fit

let appZoom: CGFloat = 0.75

struct Zoomed: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { g in
            content
                .frame(width: g.size.width / appZoom, height: g.size.height / appZoom)
                .scaleEffect(appZoom, anchor: .topLeading)
                .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        .background(T.bg.ignoresSafeArea())
    }
}
extension View { func zoomed() -> some View { modifier(Zoomed()) } }
