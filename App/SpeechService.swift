import AVFoundation
import Foundation
import os
import Speech

@MainActor
final class SpeechService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false

    enum Error: Swift.Error, LocalizedError {
        case notAuthorized
        case unavailable
        case audioSession(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: "Speech recognition not authorized."
            case .unavailable: "Speech recognition unavailable on this device."
            case let .audioSession(s): "Audio session error: \(s)"
            }
        }
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<
            SFSpeechRecognizerAuthorizationStatus,
            Never
        >) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        return micGranted
    }

    func recognize(timeout: TimeInterval = 8, silenceTimeout: TimeInterval = 1.5) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw Error.unavailable
        }
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else { throw Error.notAuthorized }
        guard AVAudioApplication.shared.recordPermission == .granted else { throw Error.notAuthorized }

        try configureSession()
        transcript = ""
        isListening = true
        defer {
            isListening = false
            stop()
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        let state = RecognitionState()

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Swift.Error>) in
            let finish: (Swift.Result<String, Swift.Error>) -> Void = { result in
                guard state.markFinished() else { return }
                state.cancelTimers()
                cont.resume(with: result)
            }

            state.silenceTask = Task { [weak self] in
                while !state.isFinished {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if Task.isCancelled { break }
                    guard let self else { break }
                    let snapshot = self.transcript
                    let last = state.lastUpdate
                    if Date().timeIntervalSince(last) > silenceTimeout, !snapshot.isEmpty {
                        finish(.success(snapshot))
                        break
                    }
                }
            }

            state.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if Task.isCancelled { return }
                guard let self else { return }
                let snapshot = self.transcript
                if snapshot.isEmpty {
                    finish(.failure(Error.audioSession("timeout, no speech")))
                } else {
                    finish(.success(snapshot))
                }
            }

            self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    state.touch()
                    Task { @MainActor [weak self] in
                        self?.transcript = text
                    }
                    if result.isFinal {
                        finish(.success(text))
                    }
                }
                if let error {
                    finish(.failure(error))
                }
            }
        }
    }

    private final class RecognitionState: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock<Bool>(initialState: false)
        private let updateLock = OSAllocatedUnfairLock<Date>(initialState: Date())
        var silenceTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?

        func markFinished() -> Bool {
            lock.withLock { state in
                guard !state else { return false }
                state = true
                return true
            }
        }

        var isFinished: Bool { lock.withLock { $0 } }

        func touch() { updateLock.withLock { $0 = Date() } }
        var lastUpdate: Date { updateLock.withLock { $0 } }

        func cancelTimers() {
            silenceTask?.cancel()
            timeoutTask?.cancel()
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw Error.audioSession(error.localizedDescription)
        }
    }
}
