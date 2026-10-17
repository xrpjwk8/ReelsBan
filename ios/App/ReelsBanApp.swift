import SwiftUI

@MainActor final class JobRouter: ObservableObject {
    enum Destination: String, Identifiable {
        case settings, limit
        var id: String { rawValue }
    }
    @Published var destination: Destination?
    func consumeRequest() {
        if SharedState.consumeJobRequest() { destination = .limit }
    }
}

@main struct ReelsBanApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
