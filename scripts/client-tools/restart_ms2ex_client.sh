#!/usr/bin/env bash
# Launch the ms2ex game client under its OWN memory daemon so we can probe
# its memory independently of the reference client.
#
# The reference client runs under memd on /tmp/opencode/memd.sock; this one
# uses MEMD_SOCK=/tmp/opencode/memd_ms2ex.sock so both coexist.
#
# Usage: ./restart_ms2ex_client.sh
# After launch, the client PID is printed; probe with:
#   MEMD_SOCK=/tmp/opencode/memd_ms2ex.sock python3 memc.py PID
#   MEMD_SOCK=/tmp/opencode/memd_ms2ex.sock python3 probe_bar_chain.py
set -e

SOCK=/tmp/opencode/memd_ms2ex.sock
MEMD=/tmp/opencode/memd.py
MCC=/home/enki/Projects/maplestory2/ms2ex/scripts/client-tools/memc.py
EXE="/home/enki/Games/mushroom-launcher/drive_c/users/steamuser/Desktop/MS2/x64/MapleStory2.exe"

# /tmp/opencode may have been cleared; memd loads ops from there, so make
# sure the runtime files are present before launching.
mkdir -p /tmp/opencode
cp -f "$(dirname "$0")/memd.py" "$MEMD"
cp -f "$(dirname "$0")/memd_ops.py" /tmp/opencode/memd_ops.py
cp -f "$(dirname "$0")/memc.py" /tmp/opencode/memc.py

# only kill the ms2ex memd (NOT the reference one)
pkill -f "memd.py wine.*port=8531" 2>/dev/null || true
sleep 1
pkill -f "MapleStory2.exe.*ip=127.0.0.1 --port=8531" 2>/dev/null || true
sleep 3

nohup env MEMD_SOCK="$SOCK" python3 "$MEMD" wine "$EXE" --nxapp=nxl --ip=127.0.0.1 --port=8531 >/dev/null 2>&1 &
disown
sleep 6

echo "ms2ex client PID:"
MEMD_SOCK="$SOCK" python3 "$MCC" PID