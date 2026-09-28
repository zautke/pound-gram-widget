import AVFoundation
import Foundation
import Observation
import os
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
    /// True from the moment ``recognize(timeout:silenceTimeout:)`` is called until it returns,
    /// including model download and mic start-up.
    private(set) var isBusy = false
    /// Incremented per ``recognize(timeout:silenceTimeout:)`` call. A listen cancelled because a newer one
    /// started must not reset state the newer one now owns.
    private var runID = 0

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

    private let log = Logger(subsystem: "com.braisenly.pounds-grams", category: "speech")
    private let audioEngine = AVAudioEngine()
    private var finalizedText = ""
    private var lastHeard = ContinuousClock.now
    /// Id of the listen that currently owns the engine's input tap. A listen cancelled because a newer
    /// one started must not stop the engine out from under it.
    private var micOwner = 0

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
    /// A `nil` timeout listens indefinitely: only a pause after speech (or cancellation) ends it.
    func recognize(
        timeout: Duration? = .seconds(8),
        silenceTimeout: Duration = .milliseconds(1500)
    ) async throws -> String {
        guard AVAudioApplication.shared.recordPermission == .granted || Self.testAudioURL != nil
        else { throw Error.notAuthorized }
        runID += 1
        let id = runID
        isBusy = true
        defer { if id == runID { isBusy = false } }
        #if targetEnvironment(simulator)
            return try await recognizeWithSFSpeech(timeout: timeout, silenceTimeout: silenceTimeout)
        #else
            return try await recognizeWithAnalyzer(timeout: timeout, silenceTimeout: silenceTimeout)
        #endif
    }

    // MARK: Device backend — SpeechAnalyzer

    private func recognizeWithAnalyzer(timeout: Duration?, silenceTimeout: Duration) async throws -> String {
        let id = runID
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US"))
        else { throw Error.unavailable }
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)

        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            isPreparing = true
            defer { if id == runID { isPreparing = false } }
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
        // SwiftUI can restart the calling `.task` right after launch; don't open the mic for a dead listen.
        try Task.checkCancellation()

        let (inputs, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let mic = try await startMic { micFormat in
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

        stopMic(mic)
        continuation.finish()
        await analyzer.cancelAndFinishNow()
        return try outcome.get()
    }

    // MARK: Simulator backend — SFSpeechRecognizer

    #if targetEnvironment(simulator)
        /// SpeechAnalyzer's models need the Neural Engine, which the Simulator doesn't emulate, so
        /// `DictationTranscriber` never loads there. Apple's forum guidance: fall back to SFSpeechRecognizer
        /// in Simulator builds (https://developer.apple.com/forums/thread/806765).
        private func recognizeWithSFSpeech(timeout: Duration?, silenceTimeout: Duration) async throws -> String {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw Error.notAuthorized }
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")), recognizer.isAvailable
            else { throw Error.unavailable }

            let request: SFSpeechRecognitionRequest
            var mic: Int?
            if let url = Self.testAudioURL {
                request = SFSpeechURLRecognitionRequest(url: url)
            } else {
                let buffered = SFSpeechAudioBufferRecognitionRequest()
                mic = try await startMic { _ in Self.makeAppendingTap(buffered) }
                request = buffered
            }
            request.shouldReportPartialResults = true
            request.contextualStrings = Self.vocabulary

            let (updates, continuation) = AsyncThrowingStream.makeStream(of: Update.self)
            let task = recognizer.recognitionTask(with: request, resultHandler: Self.makeResultHandler(continuation))
            let outcome = await run(updates, timeout: timeout, silenceTimeout: silenceTimeout)

            task.cancel()
            if let mic { stopMic(mic) }
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
        timeout: Duration?,
        silenceTimeout: Duration
    ) async -> Result<String, Swift.Error> {
        transcript = ""
        finalizedText = ""
        lastHeard = .now
        let id = runID
        isListening = true
        log.info("listen started, timeout \(String(describing: timeout)), silence \(silenceTimeout)")
        defer {
            if id == runID {
                isListening = false
            }
        }
        do {
            return try await .success(withThrowingTaskGroup(of: String.self) { group in
                group.addTask { try await self.consume(updates, run: id) }
                group.addTask { try await self.waitForEndOfSpeech(timeout: timeout, silenceTimeout: silenceTimeout) }
                defer { group.cancelAll() }
                guard let first = try await group.next(), !first.isEmpty else { throw Error.noSpeech }
                return first
            })
        } catch {
            log.error("listen ended with error: \(String(describing: error), privacy: .public)")
            return .failure(error)
        }
    }

    /// Feeds updates into the shared transcript while `run` is still the current listen; a cancelled
    /// older listen's late results are dropped.
    private func consume(
        _ updates: some AsyncSequence<Update, any Swift.Error> & Sendable,
        run id: Int
    ) async throws -> String {
        for try await update in updates where id == runID {
            // Transcripts are whatever the open mic heard: keep them out of persisted logs.
            log.debug("update final=\(update.isFinal) \(update.text, privacy: .private)")
            ingest(text: update.text, isFinal: update.isFinal)
        }
        log.info("result stream ended, transcript '\(self.transcript, privacy: .private)'")
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

    private func waitForEndOfSpeech(timeout: Duration?, silenceTimeout: Duration) async throws -> String {
        let deadline = timeout.map { ContinuousClock.now + $0 }
        while true {
            try await Task.sleep(for: .milliseconds(200))
            if !transcript.isEmpty, ContinuousClock.now - lastHeard > silenceTimeout {
                return transcript
            }
            if let deadline, ContinuousClock.now >= deadline {
                guard !transcript.isEmpty else { throw Error.noSpeech }
                return transcript
            }
        }
    }

    /// Takes an ``AudioSession`` lease and taps the mic; `makeTap` receives the mic's native format.
    /// Returns the owner id to hand back to ``stopMic(_:)``.
    private func startMic(_ makeTap: (AVAudioFormat) throws -> AVAudioNodeTapBlock) async throws -> Int {
        do {
            try await AudioSession.acquire()
        } catch {
            throw Error.audioSession(error.localizedDescription)
        }
        micOwner += 1
        let owner = micOwner
        do {
            let input = audioEngine.inputNode
            let micFormat = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: micFormat, block: try makeTap(micFormat))
            audioEngine.prepare()
            try audioEngine.start()
            return owner
        } catch let error as Error {
            stopMic(owner)
            throw error
        } catch {
            stopMic(owner)
            throw Error.audioSession(error.localizedDescription)
        }
    }

    /// Releases this listen's session lease; stops the engine only if no newer listen has taken it over.
    private func stopMic(_ owner: Int) {
        // Stop I/O before dropping the lease: the last lease deactivates the session.
        if owner == micOwner {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        AudioSession.release()
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
