import ConversionKit
import SwiftUI

@main
struct PoundsGramsApp: App {
    @State private var deepLink: DeepLink?

    var body: some Scene {
        WindowGroup {
            ContentView(deepLink: $deepLink)
                .onOpenURL { url in
                    deepLink = DeepLink(url: url)
                }
        }
    }
}

enum DeepLink: Equatable {
    case voice

    init?(url: URL) {
        guard url.scheme == "poundsgrams" else { return nil }
        if url.host == "voice" || url.path.contains("voice") {
            self = .voice
            return
        }
        return nil
    }
}
