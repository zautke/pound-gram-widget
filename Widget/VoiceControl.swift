import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action button entry point.
struct VoiceControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "PoundsGramsVoiceControl") {
            ControlWidgetButton(action: OpenVoiceConvertIntent()) {
                Label("Voice Convert", systemImage: "mic.fill")
            }
        }
        .displayName("Voice Convert")
        .description("Convert pounds and grams by voice.")
    }
}
