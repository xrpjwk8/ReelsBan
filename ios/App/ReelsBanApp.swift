import SwiftUI

@MainActor final class JobRouter: ObservableObject {
    @Published var showJob = false
    func consumeRequest() {
        if SharedState.consumeJobRequest() { showJob = true }
    }
}

@main struct ReelsBanApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
