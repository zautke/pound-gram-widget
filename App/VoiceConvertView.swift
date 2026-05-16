import ConversionKit
import SwiftUI
import UIKit
import WidgetKit

struct VoiceConvertView: View {
    @StateObject private var speech = SpeechService()
    @StateObject private var tts = TTSService()
    @Environment(\.dismiss) private var dismiss
    @State private var lastResult: LastConversion? = SharedStore.load()
    @State private var statusMessage: String = "Tap to listen"
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Voice Convert")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text(statusMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)

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
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityLabel("Last conversion: \(lc.accessibilityString)")
            }

            if let err = errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    Task { await listen() }
                } label: {
                    Label(
                        speech.isListening ? "Listening…" : "Tap to Convert",
                        systemImage: speech.isListening ? "waveform" : "mic.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(speech.isListening)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
        .task { _ = await speech.requestAuthorization() }
    }

    @MainActor
    private func listen() async {
        errorMessage = nil
        statusMessage = "Listening…"
        UIAccessibility.post(notification: .announcement, argument: "Listening")

        do {
            let transcript = try await speech.recognize(timeout: 8, silenceTimeout: 1.5)
            statusMessage = "Processing…"
            switch VoiceParser.parse(transcript) {
            case let .success(parsed):
                let outUnit: MassUnit = parsed.unit == .pounds ? .grams : .pounds
                let outValue = MassConverter.convert(parsed.value, from: parsed.unit, to: outUnit)
                let lc = LastConversion(
                    inputValue: parsed.value,
                    inputUnit: parsed.unit,
                    outputValue: outValue,
                    outputUnit: outUnit
                )
                SharedStore.save(lc)
                lastResult = lc
                statusMessage = "Done"
                WidgetCenter.shared.reloadTimelines(ofKind: "PoundsGramsWidget")
                let spoken = spokenForm(of: lc)
                tts.speak(spoken)
                UIAccessibility.post(notification: .announcement, argument: spoken)
            case let .failure(err):
                errorMessage = humanize(err)
                statusMessage = "Tap to listen"
            }
        } catch SpeechService.Error.notAuthorized {
            errorMessage = "Microphone or speech permission denied. Enable in Settings."
            statusMessage = "Tap to listen"
        } catch {
            errorMessage = "Couldn't capture audio: \(error.localizedDescription)"
            statusMessage = "Tap to listen"
        }
    }

    private func spokenForm(of lc: LastConversion) -> String {
        let inUnit = lc.inputUnit == .pounds ? "pounds" : "grams"
        let outUnit = lc.outputUnit == .pounds ? "pounds" : "grams"
        let inV = MassConverter.displayString(lc.inputValue)
        let outV = MassConverter.displayString(lc.outputValue)
        return "\(inV) \(inUnit) is \(outV) \(outUnit)"
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
