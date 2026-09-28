# Remember (append-only)

## 2026-09-28
- SpeechAnalyzer/SpeechTranscriber/DictationTranscriber do NOT run in the iOS Simulator (need the Neural Engine) — Apple forum thread 806765. Simulator builds use SFSpeechRecognizer.
- SpeechAnalyzer transcribers do not need SFSpeechRecognizer authorization; only the microphone.
- `simctl privacy grant` has no speech-recognition service ("Failed to create TCC authorization record"); insert `kTCCServiceSpeechRecognition` into the simulator's `data/Library/TCC/TCC.db` instead.
- `simctl openurl` shows an "Open in …?" confirmation; AXe/xcui cannot tap under Xcode 27 (SimulatorKit path missing).
- iOS 26: `openAppWhenRun` errors for intents run in an extension; use `supportedModes = .foreground(.immediate)` and compile the intent into app + extension.
- SwiftUI may run a `.task(id:)` body twice at launch; anything with shared resources must tolerate a cancelled older run finishing late.
- `SFSpeechError.Code.insufficientResources` must be spelled with `.Code` to compile.
- Xcode 27 agent permissions: `~/Library/Group Containers/group.com.apple.dt.Xcode.SecureSettingsContainer/CodingAssistant/{AgentToolPermissionSettings/permissions.json, HeadlessPermissions/mcp-server.json}`; defaults key `IDEChatAgenticChatSkipPermissions`.
- Another agent (running inside Xcode) edits this repo concurrently; re-read files before editing.
- Device screenshots: `xcrun devicectl device capture screenshot --device <UDID> --destination <png>` (takes seconds; too slow to catch a 5 s listen).
