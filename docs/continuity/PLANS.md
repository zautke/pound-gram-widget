# Plans

## Goal
PoundsGrams: voice-first pounds ⇄ grams converter for iOS 26+ (app + widget + Control Center + Siri).
Open the app (any entry point) → it is already listening → speak "five pounds" → result shown, spoken, saved.

## Current facts (2026-09-28)
- Branch `feat/speechanalyzer-voice-first`; last commit `b046db1`; newer work uncommitted (see TASKS.md).
- Deployment target iOS 26.0, Swift 6 strict concurrency, XcodeGen (`project.yml` → regenerate after adding/removing files).
- Signing: team `52AA89AC9T`, automatic (`project.yml`).
- Test device: iPhone 18 Pro Max "hemoila" (UDID 00008160-000C39E00200000A), driven through the Xcode MCP (workspace `PoundsGrams.xcodeproj`).
- Speech: device = SpeechAnalyzer + DictationTranscriber; Simulator = SFSpeechRecognizer fallback (no Neural Engine in Simulator).
- TTS: "Fred" (1984 MacinTalk novelty voice) → AVAudioUnitDistortion `.multiDecimated2` + band-pass EQ (300 Hz–3.5 kHz).
- History: JSON array in app-group UserDefaults, newest first, capped at 1,000 (`SharedStore.historyLimit`).
- Settings (standard UserDefaults via @AppStorage): `listenSeconds` (3/5/8/10/15, default 5), `keepLastResult` (default on).

## Phases
1. Audit + SpeechAnalyzer rewrite, widget/Control/Siri — done, committed `b046db1`.
2. Voice-first UX: auto-listen, countdown ring, slide-over settings/history, retro TTS — done on device, uncommitted.
3. Next: on-device verification of widget / Control Center / Siri paths; commit phase 2.

## Non-goals
- Saving typed (text-field) conversions to history (changes per keystroke).
- A page in the iOS Settings app (removed in favor of the in-app slide-over panel).
