# Current Task State (2026-09-28)

**Branch:** `feat/speechanalyzer-voice-first` @ `b046db1` + uncommitted changes
(ContentView, SpeechService, TTSService, VoiceConvertView, ConversionFieldsView, SharedStore(+Tests), new App/AppSettings.swift).

**Last action:** history swipe-left delete (`SharedStore.deleteFromHistory`, `.onDelete` in `HistoryPanel`), built + launched on hemoila. 30 package tests pass.

**Resume:**
1. Ask user to verify on device: retro voice, history delete, panel swipe-right close.
2. Commit when asked (branch already off main).
3. Build/run via Xcode MCP: `BuildProject` then `RunProject` (workspace `workspace-CV31PUYjiP` may change; re-open `PoundsGrams.xcodeproj`). Never run `xcodegen generate` in parallel with an Xcode build.
