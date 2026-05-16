import AppIntents
import WidgetKit

struct LaunchVoiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Voice Convert"
    static let description = IntentDescription("Open PoundsGrams and start a voice conversion.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "poundsgrams://voice")!))
    }
}
