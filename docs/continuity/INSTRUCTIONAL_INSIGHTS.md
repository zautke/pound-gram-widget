# Instructional Insights (append-only)

## 2026-09-28
- Diagnose UI "not showing" bugs with a few `os.Logger` lines + Xcode MCP `GetConsoleOutput` before guessing at layout; here the logs showed two listens 0.1 ms apart.
- Don't run `xcodegen generate` and an Xcode MCP build/run in the same parallel tool batch: Xcode's reload cancels the run, or builds stale files.
- After an edit, confirm the build actually recompiled the file (`GetBuildLog` pattern for "Compile <File>.swift") — incremental builds of a few seconds can miss files edited mid-build.
- User wording "slide over" meant a right-edge overlay panel, not a sheet or the Settings app; "top right" and "main screen only" matter — confirm placement words literally.
- Render short TTS to buffers (`AVSpeechSynthesizer.write`) and play through an `AVAudioEngine` effect chain for voice styling; guard the continuation against multiple end markers.
