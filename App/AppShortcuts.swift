import AppIntents

/// Siri / Spotlight phrases for starting a voice conversion.
struct PoundsGramsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenVoiceConvertIntent(),
            phrases: [
                "Convert with \(.applicationName)",
                "\(.applicationName) voice convert",
                "Convert pounds with \(.applicationName)",
                "Convert grams with \(.applicationName)"
            ],
            shortTitle: "Voice Convert",
            systemImageName: "mic.fill"
        )
    }
}
