#!/usr/bin/env bash
# Launch the game client under memd connected to the REFERENCE server
# (127.0.0.1:20001) so we can dump memory while the HP bar WORKS.
#
# The reference client owns the default memd socket (/tmp/opencode/memd.sock);
# the ms2ex client uses MEMD_SOCK=/tmp/opencode/memd_ms2ex.sock so both
# can coexist (see restart_ms2ex_client.sh).
#
# Usage: ./restart_ref_client.sh
# After launch, probe with:
#   python3 memc.py PID
#   python3 probe_bar_chain.py
#   python3 attack_timeline.py --model <mob-model-name>
set -e

SOCK=/tmp/opencode/memd.sock
MEMD=/tmp/opencode/memd.py
MCC=/home/enki/Projects/maplestory2/ms2ex/scripts/client-tools/memc.py
EXE="/home/enki/Games/mushroom-launcher/drive_c/users/steamuser/Desktop/MS2/x64/MapleStory2.exe"
PORT=20001

# /tmp/opencode may have been cleared; memd loads ops from there, so make
# sure the runtime files are present before launching.
mkdir -p /tmp/opencode
cp -f "$(dirname "$0")/memd.py" "$MEMD"
cp -f "$(dirname "$0")/memd_ops.py" /tmp/opencode/memd_ops.py
cp -f "$(dirname "$0")/memc.py" /tmp/opencode/memc.py

# only kill the reference memd + its client (NOT the ms2ex one on 8526)
pkill -f "memd.py wine.*port=$PORT" 2>/dev/null || true
sleep 1
pkill -f "MapleStory2.exe.*ip=127.0.0.1 --port=$PORT" 2>/dev/null || true
sleep 3

nohup env MEMD_SOCK="$SOCK" python3 "$MEMD" wine "$EXE" --nxapp=nxl --ip=127.0.0.1 --port=$PORT >/dev/null 2>&1 &
disown
sleep 6

echo "reference client PID:"
python3 "$MCC" PID