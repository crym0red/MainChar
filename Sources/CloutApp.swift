import SwiftUI

@main
struct CloutApp: App {
    init() {
        Task.detached(priority: .utility) { Corpus.load() }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
