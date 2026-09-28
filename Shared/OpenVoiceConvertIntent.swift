import AppIntents
import ConversionKit

/// Opens PoundsGrams straight into a listening voice conversion.
/// Compiled into both the app and the widget extension so it runs in the app process (iOS 26 rule).
struct OpenVoiceConvertIntent: AppIntent {
    static let title: LocalizedStringResource = "Voice Convert"
    static let description = IntentDescription("Open PoundsGrams and start a voice conversion.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(SharedStore.voiceURL))
    }
}
