import SwiftUI
import CoreText

@main
struct CloutApp: App {
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
