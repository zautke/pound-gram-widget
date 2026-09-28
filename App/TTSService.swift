import AVFoundation
import Foundation

/// Speaks conversion results. Holds an ``AudioSession`` lease only while an utterance is playing.
@MainActor
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    /// Resumed when the current utterance finishes or is stopped.
    private var utteranceFinished: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Speaks `text` and returns once it has finished. Cancelling the awaiting task stops speech.
    func speak(_ text: String, locale: String = "en-US") async {
        guard !Task.isCancelled else { return }
        do {
            try await AudioSession.acquire()
        } catch {
            return
        }
        defer { AudioSession.release() }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                utteranceFinished = continuation
                synth.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }

    func stop() {
        // `stopSpeaking` reports `false` when nothing is queued, in which case no delegate
        // callback will arrive to resume the waiter.
        if !synth.stopSpeaking(at: .immediate) {
            finish()
        }
    }

    private func finish() {
        utteranceFinished?.resume()
        utteranceFinished = nil
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
