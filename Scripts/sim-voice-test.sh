#!/usr/bin/env bash
# Drive PoundsGrams' voice conversion in the iOS Simulator from a spoken phrase or an audio file.
#
#   Scripts/sim-voice-test.sh "five pounds"          # synthesize the phrase with `say`
#   Scripts/sim-voice-test.sh path/to/clip.wav       # use an existing recording (wav/aiff/m4a/caf)
#
# The app must already be installed on the booted simulator (or set UDID=<device>).
# The simulator build transcribes with SFSpeechRecognizer (needs network), not SpeechAnalyzer:
# the analyzer's models need the Neural Engine, which the Simulator doesn't emulate.
set -euo pipefail

INPUT="${1:-five pounds}"
UDID="${UDID:-booted}"
BUNDLE="com.braisenly.pounds-grams"

if [[ "$UDID" == "booted" ]]; then
  UDID=$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; print(next(d["udid"] for r in json.load(sys.stdin)["devices"].values() for d in r if d["state"]=="Booted"))')
fi

container=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
clip="$container/tmp/voice-test.wav"
mkdir -p "$container/tmp"
if [[ -f "$INPUT" ]]; then
  afconvert -f WAVE -d LEI16@16000 -c 1 "$INPUT" "$clip"
else
  say -o "$clip" --file-format=WAVE --data-format=LEI16@16000 "$INPUT"
fi

# Microphone: simctl can grant it. Speech recognition: simctl has no service for it
# ("Failed to create TCC authorization record"), so write the simulator's own TCC.db
# the same way simctl writes the microphone row, then restart the simulator's tccd.
xcrun simctl privacy "$UDID" grant microphone "$BUNDLE"
tcc=~/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/TCC/TCC.db
sqlite3 "$tcc" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version)
                VALUES ('kTCCServiceSpeechRecognition', '$BUNDLE', 0, 2, 4, 1);"
xcrun simctl spawn "$UDID" launchctl kickstart -k system/com.apple.tccd >/dev/null 2>&1 || true

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
SIMCTL_CHILD_POUNDSGRAMS_SPEECH_FILE="$clip" xcrun simctl launch "$UDID" "$BUNDLE"
echo "Launched with $clip — the voice sheet opens and transcribes it."
