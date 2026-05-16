import AVFoundation
import Foundation

@MainActor
final class TTSService: ObservableObject {
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, locale: String = "en-US") {
        configurePlaybackSession()
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: locale)
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    private func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
