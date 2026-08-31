#!/usr/bin/env bash
# restart the memory daemon + game client cleanly
pkill -f "memd.py" 2>/dev/null
sleep 1
pkill -x "MapleStory2.exe" 2>/dev/null
sleep 3
nohup python3 /tmp/opencode/memd.py wine \
  "/home/enki/Games/mushroom-launcher/drive_c/users/steamuser/Desktop/MS2/x64/MapleStory2.exe" \
  --nxapp=nxl --ip=127.0.0.1 --port=8531 >/dev/null 2>&1 &
disown
sleep 6
python3 /tmp/opencode/memc.py PID
