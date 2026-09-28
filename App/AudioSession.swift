import AVFoundation

/// Single owner of the app's `AVAudioSession`, shared by microphone capture and text-to-speech.
///
/// Leases are counted so the session stays active across a listen → speak hand-off instead of
/// being deactivated and re-activated between the two. Activation and deactivation never run
/// synchronously on the main thread (the synchronous `setActive` is reported as an
/// "AVAudioSession Hang Risk" runtime issue): iOS 27 uses the asynchronous session API and
/// iOS 26 hops to a background task.
@MainActor
enum AudioSession {
    private static var leases = 0
    /// Teardown still in flight from the last ``release()``; a new lease waits for it.
    private static var deactivation: Task<Void, Never>?
    /// Activation started by the first holder; every holder awaits it, so none returns before the
    /// session is actually active (or keeps a lease on a session that failed to activate).
    private static var activation: Task<Void, any Error>?

    /// Takes a lease on the session, activating it for the first holder. Balance with ``release()``.
    static func acquire() async throws {
        leases += 1
        if leases == 1 { activation = Task { try await activateNow() } }
        do {
            try await activation?.value
        } catch {
            leases -= 1
            if leases == 0 { activation = nil }
            throw error
        }
    }

    private static func activateNow() async throws {
        await deactivation?.value
        deactivation = nil
        let session = AVAudioSession.sharedInstance()
        // Configure only while inactive: changing the category on an active session is itself
        // a main-thread hang risk.
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        if #available(iOS 27, *) {
            try await session.activate()
        } else {
            try await Task.detached { try AVAudioSession.sharedInstance().setActive(true) }.value
        }
    }

    /// Drops a lease; the last holder deactivates the session so ducked audio resumes.
    static func release() {
        guard leases > 0 else { return }
        leases -= 1
        guard leases == 0 else { return }
        activation = nil
        deactivation = Task { await deactivateNow() }
    }

    private static func deactivateNow() async {
        if #available(iOS 27, *) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) { _, _ in
                    continuation.resume()
                }
            }
        } else {
            await Task.detached {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }.value
        }
    }
}
