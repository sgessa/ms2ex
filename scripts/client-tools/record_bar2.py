#!/usr/bin/env python3
"""Timeline recorder for boss HP bar state.

Usage: python3 record_bar2.py <seconds> [model_name]
Run it, then attack. Ctrl-C to stop early.
Writes timeline to /tmp/opencode/bar_capture.log
"""
import os
import subprocess
import sys
import time

DURATION = int(sys.argv[1]) if len(sys.argv) > 1 else 45
MODEL = sys.argv[2] if len(sys.argv) > 2 else "02020107_M_Lslime02"
OUT = "/tmp/opencode/bar_capture.log"
ENV = dict(os.environ, MEMD_SOCK="/tmp/opencode/memd.sock")
REPO = os.path.dirname(os.path.abspath(__file__))


def memc(*args, timeout=30):
    return subprocess.run(
        [sys.executable, os.path.join(REPO, "memc.py"), *args],
        capture_output=True, text=True, timeout=timeout, env=ENV,
    ).stdout.strip()


# phase 1: anchor the UI region while idle (slow scan, once)
print("anchoring UI region (may take ~30s, stand still)...", flush=True)
anchor = memc("BARANCHOR", timeout=180)
if "NOT_FOUND" in anchor or not anchor.startswith("0x"):
    print("FAILED:", anchor)
    sys.exit(1)
addr_s = anchor.split()[0]
lo_hi = next(t for t in anchor.split() if t.startswith("region=")).split("=")[1]
lo, hi = lo_hi.split("-")
print(f"anchored at {addr_s}, probing region {lo}-{hi}", flush=True)

# phase 2: fast timeline
deadline = time.time() + DURATION
prev = None
with open(OUT, "a") as log:
    log.write(f"\n=== recording {DURATION}s model={MODEL} region={lo}-{hi} ===\n")
    while time.time() < deadline:
        stamp = time.strftime("%H:%M:%S")
        out = ""
        try:
            out = memc("BARPROBE2", lo, hi, MODEL, timeout=15)
            summary = " ".join(
                l for l in out.splitlines() if "=" in l and "[" not in l
            )
        except subprocess.TimeoutExpired:
            summary = "SAMPLE_TIMEOUT"
        print(f"{stamp}  {summary}", flush=True)
        if summary != prev:
            log.write(f"\n--- CHANGE at {stamp} ---\n{out}\n")
            prev = summary
        else:
            log.write(f"{stamp}  {summary}\n")
        time.sleep(0.3)

print(f"done -> {OUT}")
