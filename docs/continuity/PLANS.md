# Plans

## Goal
PoundsGrams: voice-first pounds ⇄ grams converter for iOS 26+ (app + widget + Control Center + Siri).
Open the app (any entry point) → it is already listening → speak "five pounds" → result shown, spoken, saved.

## Current facts (2026-09-28)
- Work lands through PRs on https://github.com/zautke/pound-gram-widget (PR #1: voice-first flow).
- Deployment target iOS 26.0, Swift 6 strict concurrency, XcodeGen (`project.yml` → regenerate after adding/removing files).
- Signing: team `52AA89AC9T`, automatic (`project.yml`).
- Test device: a physical iPhone selected as the Xcode run destination, driven through the Xcode MCP (workspace `PoundsGrams.xcodeproj`).
- Speech: device = SpeechAnalyzer + DictationTranscriber; Simulator = SFSpeechRecognizer fallback (no Neural Engine in Simulator).
- TTS: best installed US English female voice (Premium > Enhanced > default, novelty voices excluded), rendered with `AVSpeechSynthesizer.write` and played through the app's `AVAudioEngine` so it shares the `AudioSession` lease.
- History: JSON array in app-group UserDefaults, newest first, capped at 1,000 (`SharedStore.historyLimit`).
- Settings (standard UserDefaults via @AppStorage): `listenSeconds` (presets 3/5/8/10/15, 0 = Indefinite, custom 1–600; default 5), `keepLastResult` (default on).

## Phases
1. Audit + SpeechAnalyzer rewrite, widget/Control/Siri — done, committed `b046db1`.
2. Voice-first UX: auto-listen, countdown ring with retry-on-unrecognized, slide-over settings/history, natural TTS — PR #1.
3. Next: on-device verification of widget / Control Center / Siri paths; merge PR #1.

## Non-goals
- Saving typed (text-field) conversions to history (changes per keystroke).
- A page in the iOS Settings app (removed in favor of the in-app slide-over panel).
