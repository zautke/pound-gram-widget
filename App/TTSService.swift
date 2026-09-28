import AVFoundation
import Foundation

/// Speaks conversion results in the most natural US English female voice on the device.
///
/// Speech is rendered to buffers and played through the app's own engine so it shares the
/// ``AudioSession`` lease with the microphone. Holds a lease only while playing.
@MainActor
final class TTSService {
    private let synth = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var connectedFormat: AVAudioFormat?

    /// Best-quality US English female voice installed: Premium (neural) beats Enhanced beats Default.
    /// Premium voices such as Ava or Zoe are downloaded in Settings > Accessibility > Read & Speak > Voices;
    /// without one, the built-in compact female voice is used. Re-read on every use so a voice
    /// downloaded while the app is running is picked up.
    static var voice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" && $0.gender == .female && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Name and quality tier of ``voice`` for display, e.g. "Ava (Premium)".
    static var voiceDescription: String {
        guard let voice else { return "System default" }
        let tier = switch voice.quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
        return "\(voice.name) (\(tier))"
    }

    init() {
        engine.attach(player)
    }

    /// Speaks `text` and returns once it has finished. Cancelling the awaiting task stops speech.
    func speak(_ text: String) async {
        guard !Task.isCancelled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        let buffers = await render(utterance).list
        guard let format = buffers.first?.format, !Task.isCancelled else { return }

        do {
            try await AudioSession.acquire()
        } catch {
            return
        }
        defer { AudioSession.release() }

        do {
            try start(with: format)
        } catch {
            return
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                for buffer in buffers.dropLast() { player.scheduleBuffer(buffer) }
                // `stop()` also fires this handler, so cancellation resumes the waiter too.
                player.scheduleBuffer(buffers[buffers.count - 1], completionCallbackType: .dataPlayedBack) { _ in
                    done.resume()
                }
                player.play()
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
        player.stop()
        engine.stop()
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        player.stop()
    }

    private func start(with format: AVAudioFormat) throws {
        if connectedFormat != format {
            engine.connect(player, to: engine.mainMixerNode, format: format)
            connectedFormat = format
        }
        if !engine.isRunning { try engine.start() }
    }

    /// Synthesizes the whole utterance to PCM up front; results are a phrase long, so this is fast.
    private func render(_ utterance: AVSpeechUtterance) async -> RenderedSpeech {
        await withCheckedContinuation { (rendered: CheckedContinuation<RenderedSpeech, Never>) in
            let collected = RenderedSpeech()
            synth.write(utterance) { buffer in
                guard !collected.finished else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                    collected.finished = true
                    rendered.resume(returning: collected) // an empty buffer marks the end
                    return
                }
                collected.list.append(pcm)
            }
        }
    }
}

/// Buffers produced by `AVSpeechSynthesizer.write`, filled serially on the synthesizer's callback
/// queue and read only after the end marker resumes the waiter.
private final class RenderedSpeech: @unchecked Sendable {
    var list: [AVAudioPCMBuffer] = []
    var finished = false
}
