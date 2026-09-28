import ConversionKit
import SwiftUI

@main
struct PoundsGramsApp: App {
    /// A simulator test-audio launch opens straight into a listening voice sheet.
    @State private var deepLink: DeepLink? = SpeechService.testAudioURL == nil ? nil : .voice

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
