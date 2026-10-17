import SwiftUI
import CoreText

enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .portrait

    static func set(landscape: Bool) {
        mask = landscape ? .landscape : .portrait
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscapeRight : .portrait)) { _ in }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

@main
struct CloutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // make sure the bundled typeface is registered even if the plist entry is skipped
        for sub in [nil, "Fonts"] as [String?] {
            for u in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: sub) ?? [] {
                CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
            }
        }
        Task.detached(priority: .utility) { Corpus.load() }
    }

    var body: some Scene {
        WindowGroup { RootView().dynamicTypeSize(.large) }
    }
}
