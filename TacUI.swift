import SwiftUI
import UIKit
import ImageIO

/// Shared look for the lobby, HUD and menus.
enum TUI {
    static let accent = Color(red: 0.78, green: 0.96, blue: 0.28)
    static let blue = Color(red: 0.30, green: 0.62, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.18)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.25)
    static let red = Color(red: 1.0, green: 0.31, blue: 0.31)
    static let green = Color(red: 0.42, green: 0.95, blue: 0.5)
    static let ink = Color(red: 0.05, green: 0.06, blue: 0.09)
}

/// SF Symbol with a safe fallback so a symbol missing on an older iOS never renders blank.
func SF(_ name: String, _ fallback: String = "circle.fill") -> Image {
    UIImage(systemName: name) != nil ? Image(systemName: name) : Image(systemName: fallback)
}

extension View {
    /// dark translucent card with a hairline edge
    func tuiGlass(_ radius: CGFloat = 12, fill: Double = 0.5) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.black.opacity(fill)))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

struct TuiPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Animated, transparent GIF that plays once (used for kill effects).
struct TacGif: UIViewRepresentable {
    let name: String

    private static var cache: [String: ([UIImage], Double)] = [:]

    static func frames(_ name: String) -> ([UIImage], Double)? {
        if let c = cache[name] { return c }
        let url = Bundle.main.url(forResource: name, withExtension: "gif")
            ?? Bundle.main.url(forResource: name, withExtension: "gif", subdirectory: "fx")
        guard let u = url, let src = CGImageSourceCreateWithURL(u as CFURL, nil) else { return nil }
        var imgs: [UIImage] = []
        var dur = 0.0
        for i in 0..<CGImageSourceGetCount(src) {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            imgs.append(UIImage(cgImage: cg))
            if let pr = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any],
               let gp = pr[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                dur += (gp[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gp[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.04
            } else { dur += 0.04 }
        }
        if imgs.isEmpty { return nil }
        cache[name] = (imgs, max(0.2, dur))
        return cache[name]
    }

    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.backgroundColor = .clear
        v.isOpaque = false
        v.isUserInteractionEnabled = false
        if let (f, d) = TacGif.frames(name) {
            v.animationImages = f
            v.animationDuration = d
            v.animationRepeatCount = 1
            v.image = f.last
            v.startAnimating()
        }
        return v
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
