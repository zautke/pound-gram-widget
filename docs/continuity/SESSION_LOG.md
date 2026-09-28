# Session Log (newest first)

## 2026-09-28 — voice-first UX on device (hemoila)
- Set team 52AA89AC9T + automatic signing; built/ran on hemoila through Xcode MCP.
- App now opens listening; countdown ring; settings + history slide-over panels (top-right group); Keep Last Result toggle; persistent history with day headers + swipe delete.
- Text-field focus clears fields and closes voice sheet.
- Retro TTS: Fred voice + decimator + small-speaker EQ.
- Bug: ring never showed. Root cause from logs: SwiftUI restarted `.task(id:)` at launch → two listens; the cancelled one's cleanup reset `isListening`/`listenDeadline` and stopped the shared engine. Fix: per-run IDs (`runID`, `micOwner`) + `Task.checkCancellation()` before mic start.
- Researched Xcode 27 agent permission files; auto-mode blocked writing an allow-all script; manual steps given to user.

## 2026-09-26 — audit + SpeechAnalyzer rewrite
- Audit (state/concurrency/UI) → SpeechAnalyzer/DictationTranscriber rewrite, widgetURL widget, Control Center control, App Shortcuts, @Observable, iOS 26 UI polish. Committed `b046db1` (includes another session's AudioSession lease work).
- Simulator: mic grant via simctl works; speech permission via simulator TCC.db insert; SpeechAnalyzer unsupported in Simulator → SFSpeechRecognizer fallback + `Scripts/sim-voice-test.sh` file injection.
