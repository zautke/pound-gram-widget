import AVFoundation
import Foundation
import Observation
import Speech

/// Captures one short spoken phrase from the microphone and returns its transcript.
///
/// Device: `SpeechAnalyzer` + `DictationTranscriber` (iOS 26). Simulator: `SFSpeechRecognizer`
/// (mic or an injected test file), because the analyzer models can't run there. Cancellation is structural:
/// cancelling the task that awaits ``recognize(timeout:silenceTimeout:)`` stops the mic and
/// tears down the analyzer.
@MainActor
@Observable
final class SpeechService {
    /// Live transcript: finalized text plus the current volatile guess.
    private(set) var transcript: String = ""
    /// True while the microphone is capturing.
    private(set) var isListening: Bool = false
    /// True while the on-device speech model is downloading.
    private(set) var isPreparing: Bool = false

    enum Error: Swift.Error, LocalizedError {
        case notAuthorized
        case unavailable
        case noSpeech
        case audioSession(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: "Speech recognition not authorized."
            case .unavailable: "Speech recognition unavailable on this device."
            case .noSpeech: "Didn't hear anything."
            case let .audioSession(s): "Audio session error: \(s)"
            }
        }
    }

    /// One transcription update from either backend.
    private struct Update: Sendable {
        let text: String
        let isFinal: Bool
    }

    private let audioEngine = AVAudioEngine()
    private var finalizedText = ""
    private var lastHeard = ContinuousClock.now
    /// True while this service holds an ``AudioSession`` lease for the microphone.
    private var holdsSessionLease = false

    /// Simulator-only test hook: transcribe this audio file instead of the microphone.
    /// Set with `SIMCTL_CHILD_POUNDSGRAMS_SPEECH_FILE=<path> xcrun simctl launch …` (see `Scripts/sim-voice-test.sh`).
    nonisolated static var testAudioURL: URL? {
        #if targetEnvironment(simulator)
            ProcessInfo.processInfo.environment["POUNDSGRAMS_SPEECH_FILE"].map { URL(fileURLWithPath: $0) }
        #else
            nil
        #endif
    }

    func requestAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
            // The simulator backend is SFSpeechRecognizer, which needs its own permission.
            guard await Self.requestSpeechAuthorizationStatus() == .authorized else { return false }
            if Self.testAudioURL != nil { return true }
        #endif
        // SpeechAnalyzer runs fully on device and needs only the microphone.
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Listens until the speaker pauses for `silenceTimeout` or `timeout` elapses.
    func recognize(
        timeout: Duration = .seconds(8),
        silenceTimeout: Duration = .milliseconds(1500)
    ) async throws -> String {
        guard AVAudioApplication.shared.recordPermission == .granted || Self.testAudioURL != nil
        else { throw Error.notAuthorized }
        #if targetEnvironment(simulator)
            return try await recognizeWithSFSpeech(timeout: timeout, silenceTimeout: silenceTimeout)
        #else
            return try await recognizeWithAnalyzer(timeout: timeout, silenceTimeout: silenceTimeout)
        #endif
    }

    // MARK: Device backend — SpeechAnalyzer

    private func recognizeWithAnalyzer(timeout: Duration, silenceTimeout: Duration) async throws -> String {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US"))
        else { throw Error.unavailable }
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)

        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            isPreparing = true
            defer { isPreparing = false }
            try await install.downloadAndInstall()
        }

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        else { throw Error.unavailable }

        let context = AnalysisContext()
        context.contextualStrings[.general] = Self.vocabulary
        // `.lingering` keeps the model warm between back-to-back conversions; preparing before the
        // mic opens means the first spoken words aren't queued behind model load.
        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .userInitiated, modelRetention: .lingering)
        )
        try await analyzer.setContext(context)
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (inputs, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        try await startMic { micFormat in
            guard let converter = AVAudioConverter(from: micFormat, to: analyzerFormat) else {
                throw Error.audioSession("unsupported microphone format")
            }
            return Self.makeConvertingTap(converter: converter, format: analyzerFormat, continuation: continuation)
        }

        let updates = transcriber.results.map { @Sendable result in
            Update(text: String(result.text.characters), isFinal: result.isFinal)
        }
        let outcome: Result<String, Swift.Error>
        do {
            try await analyzer.start(inputSequence: inputs)
            outcome = await run(updates, timeout: timeout, silenceTimeout: silenceTimeout)
        } catch {
            outcome = .failure(error)
        }

        stopMic()
        continuation.finish()
        await analyzer.cancelAndFinishNow()
        return try outcome.get()
    }

    // MARK: Simulator backend — SFSpeechRecognizer

    #if targetEnvironment(simulator)
        /// SpeechAnalyzer's models need the Neural Engine, which the Simulator doesn't emulate, so
        /// `DictationTranscriber` never loads there. Apple's forum guidance: fall back to SFSpeechRecognizer
        /// in Simulator builds (https://developer.apple.com/forums/thread/806765).
        private func recognizeWithSFSpeech(timeout: Duration, silenceTimeout: Duration) async throws -> String {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw Error.notAuthorized }
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")), recognizer.isAvailable
            else { throw Error.unavailable }

            let request: SFSpeechRecognitionRequest
            if let url = Self.testAudioURL {
                request = SFSpeechURLRecognitionRequest(url: url)
            } else {
                let buffered = SFSpeechAudioBufferRecognitionRequest()
                try await startMic { _ in Self.makeAppendingTap(buffered) }
                request = buffered
            }
            request.shouldReportPartialResults = true
            request.contextualStrings = Self.vocabulary

            let (updates, continuation) = AsyncThrowingStream.makeStream(of: Update.self)
            let task = recognizer.recognitionTask(with: request, resultHandler: Self.makeResultHandler(continuation))
            let outcome = await run(updates, timeout: timeout, silenceTimeout: silenceTimeout)

            task.cancel()
            stopMic()
            continuation.finish()
            return try outcome.get()
        }

        private nonisolated static func makeAppendingTap(_ request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
            { buffer, _ in request.append(buffer) }
        }

        private nonisolated static func makeResultHandler(
            _ continuation: AsyncThrowingStream<Update, Swift.Error>.Continuation
        ) -> @Sendable (SFSpeechRecognitionResult?, (any Swift.Error)?) -> Void {
            { result, error in
                if let result {
                    continuation.yield(Update(text: result.bestTranscription.formattedString, isFinal: result.isFinal))
                    if result.isFinal { continuation.finish() }
                } else if let error {
                    continuation.finish(throwing: error)
                }
            }
        }
    #endif

    // MARK: Shared

    private static let vocabulary = ["pounds", "pound", "grams", "gram", "lbs"]

    /// Resets live state, then races the update stream against the silence/timeout clock.
    private func run(
        _ updates: some AsyncSequence<Update, any Swift.Error> & Sendable,
        timeout: Duration,
        silenceTimeout: Duration
    ) async -> Result<String, Swift.Error> {
        transcript = ""
        finalizedText = ""
        lastHeard = .now
        isListening = true
        defer { isListening = false }
        do {
            return try await .success(withThrowingTaskGroup(of: String.self) { group in
                group.addTask { try await self.consume(updates) }
                group.addTask { try await self.waitForEndOfSpeech(timeout: timeout, silenceTimeout: silenceTimeout) }
                defer { group.cancelAll() }
                guard let first = try await group.next(), !first.isEmpty else { throw Error.noSpeech }
                return first
            })
        } catch {
            return .failure(error)
        }
    }

    private func consume(_ updates: some AsyncSequence<Update, any Swift.Error> & Sendable) async throws -> String {
        for try await update in updates {
            ingest(text: update.text, isFinal: update.isFinal)
        }
        return transcript
    }

    private func ingest(text: String, isFinal: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFinal {
            finalizedText = [finalizedText, trimmed].filter { !$0.isEmpty }.joined(separator: " ")
            transcript = finalizedText
        } else {
            transcript = [finalizedText, trimmed].filter { !$0.isEmpty }.joined(separator: " ")
        }
        lastHeard = .now
    }

    private func waitForEndOfSpeech(timeout: Duration, silenceTimeout: Duration) async throws -> String {
        let deadline = ContinuousClock.now + timeout
        while true {
            try await Task.sleep(for: .milliseconds(200))
            if !transcript.isEmpty, ContinuousClock.now - lastHeard > silenceTimeout {
                return transcript
            }
            if ContinuousClock.now >= deadline {
                guard !transcript.isEmpty else { throw Error.noSpeech }
                return transcript
            }
        }
    }

    /// Activates the audio session and taps the mic; `makeTap` receives the mic's native format.
    private func startMic(_ makeTap: (AVAudioFormat) throws -> AVAudioNodeTapBlock) async throws {
        do {
            try await AudioSession.acquire()
            holdsSessionLease = true
            let input = audioEngine.inputNode
            let micFormat = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: micFormat, block: try makeTap(micFormat))
            audioEngine.prepare()
            try audioEngine.start()
        } catch let error as Error {
            stopMic()
            throw error
        } catch {
            stopMic()
            throw Error.audioSession(error.localizedDescription)
        }
    }

    private func stopMic() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        if holdsSessionLease {
            holdsSessionLease = false
            AudioSession.release()
        }
    }

    /// Built `nonisolated` so the closure is not MainActor-isolated: it runs on the realtime audio thread.
    private nonisolated static func makeConvertingTap(
        converter: AVAudioConverter,
        format: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            let ratio = format.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
            guard capacity > 0,
                  let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
            let feed = OneShotBuffer(buffer)
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                feed.next(status)
            }
            if error == nil, output.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: output))
            }
        }
    }

    private nonisolated static func requestSpeechAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
    }
}

/// Hands one tap buffer to `AVAudioConverter`, then reports no more data.
/// Only touched synchronously inside `convert(to:error:withInputFrom:)` on the audio thread.
private final class OneShotBuffer: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard let buffer else {
            status.pointee = .noDataNow
            return nil
        }
        self.buffer = nil
        status.pointee = .haveData
        return buffer
    }
}
