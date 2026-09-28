import ConversionKit
import SwiftUI
import WidgetKit

struct VoiceConvertView: View {
    @State private var speech = SpeechService()
    @State private var tts = TTSService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// Set when the app goes to the background, so returning to it starts a fresh listen.
    @State private var returnedFromBackground = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var lastResult: LastConversion? = SharedStore.load()
    @State private var errorMessage: String?
    /// Bumped to start a listen; `.task(id:)` cancels an in-flight listen on dismiss.
    @State private var listenRequest = 0

    private var statusMessage: String {
        if speech.isPreparing { return "Downloading speech model\u{2026}" }
        if speech.isListening { return "Listening\u{2026}" }
        return "Tap to listen"
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Voice Convert")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text(statusMessage)
                .font(.headline)
                .foregroundStyle(.secondary)

            if !speech.transcript.isEmpty {
                Text("\u{201C}\(speech.transcript)\u{201D}")
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let lc = lastResult {
                Text(lc.displayString)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityLabel("Last conversion: \(lc.accessibilityString)")
            }

            if let err = errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                listenRequest += 1
            } label: {
                Label(
                    speech.isListening ? "Listening\u{2026}" : "Tap to Convert",
                    systemImage: speech.isListening ? "waveform" : "mic.fill"
                )
                .symbolEffect(.variableColor.iterative, isActive: speech.isListening)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .disabled(speech.isListening || speech.isPreparing)

            Button("Done") { dismiss() }
                .buttonStyle(.glass)
        }
        .padding()
        .sensoryFeedback(.success, trigger: lastResult)
        .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
        // Opening the sheet starts listening immediately; no tap needed.
        .task {
            if await speech.requestAuthorization() { listenRequest += 1 }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                returnedFromBackground = true
            case .active where returnedFromBackground:
                returnedFromBackground = false
                if !speech.isListening, !speech.isPreparing { listenRequest += 1 }
            default:
                break
            }
        }
        .task(id: listenRequest) {
            guard listenRequest > 0 else { return }
            await listen()
        }
        // VoiceOver announcements are posted from these synchronous observers rather than from
        // inside `listen()`: posting from a Swift task trips an accessibility runtime issue
        // ("unsafeForcedSync called from Swift Concurrent context").
        .onChange(of: speech.isListening) { _, listening in
            if listening { AccessibilityNotification.Announcement("Listening").post() }
        }
        .onChange(of: errorMessage) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
        .onChange(of: lastResult) { _, result in
            // Spoken results normally come from TTS; with VoiceOver running, let it speak instead
            // so two voices don't overlap.
            if voiceOverEnabled, let result {
                AccessibilityNotification.Announcement(result.accessibilityString).post()
            }
        }
    }

    private func listen() async {
        errorMessage = nil

        do {
            // Hold the audio session for the whole listen → speak round trip so it isn't torn down
            // and rebuilt between the microphone and the synthesizer.
            try await AudioSession.acquire()
            defer { AudioSession.release() }

            let transcript = try await speech.recognize()
            switch LastConversion.fromVoice(transcript) {
            case let .success(lc):
                SharedStore.save(lc)
                withAnimation { lastResult = lc }
                WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
                if !voiceOverEnabled {
                    await tts.speak(lc.accessibilityString)
                }
            case let .failure(err):
                errorMessage = humanize(err)
            }
        } catch is CancellationError {
            // Sheet dismissed mid-listen; nothing to report.
        } catch SpeechService.Error.notAuthorized {
            errorMessage = "Microphone or speech permission denied. Enable in Settings."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func humanize(_ err: VoiceParser.ParseError) -> String {
        switch err {
        case .noNumber: "Didn't catch a number. Try again."
        case .noUnit: "Didn't catch a unit. Say pounds or grams."
        case .ambiguousUnits: "Heard both units. Say one only."
        case .nonFinite: "Couldn't parse the number."
        }
    }
}

#Preview {
    VoiceConvertView()
}
