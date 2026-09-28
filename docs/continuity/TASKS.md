# Tasks

## Done
- [x] Audit state/concurrency/UI; SpeechAnalyzer rewrite (committed b046db1)
- [x] widgetURL widget, Control Center control, App Shortcuts (b046db1)
- [x] App opens straight into a listening voice sheet on launch / foreground
- [x] Countdown ring (default 5 s) during listen
- [x] Gear + history icons grouped top-right on main screen; panels slide over from the right
- [x] Listen Time picker + "Keep Last Result" toggle in Settings panel
- [x] Persistent history with day headers (Today / Yesterday / full date), swipe-left delete
- [x] Tapping a text field clears both fields and closes the voice sheet
- [x] Retro Apple II-style TTS voice
- [x] Fix: duplicate listen at launch killed the live one (per-run IDs in SpeechService)

## Open
- [ ] Commit the uncommitted work on `feat/speechanalyzer-voice-first` (user asked "all together" for the first commit; ask again)
- [ ] Verify on hemoila: retro voice audible (Fred installed?), history swipe-delete vs panel swipe-right-close
- [ ] Verify on hemoila: widget tap, Control Center control (OpenURLIntent from controls is reported flaky), Siri phrase
- [ ] Simulator voice test: first run timed out (~13 s Siri-server connect > listen timeout); re-run `Scripts/sim-voice-test.sh`
- [ ] Decide: should deleting the newest history entry also clear the saved last result? (currently no)
- [ ] Optional: keep or drop the os.Logger `[speech]` lines in SpeechService
