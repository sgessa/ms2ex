#!/usr/bin/env python3
"""Probe the boss-bar chain on a live client via memd.

Usage: python3 probe_bar_chain.py
Reads the UIUpperHpBar instance (vtable 0x141a62ba0), its +0x3b8 link,
the wrapper's target id, and the key globals. Run while a field boss is
present (bar active on the reference; on ms2ex the bar stays hidden but the
instance should still exist while the boss is in the field).

Compare the reference (bar works) vs ms2ex (no bar) to find which
dispatch pre-condition differs.
"""
import os
import subprocess
import sys

SOCK = os.environ.get("MEMD_SOCK", "/tmp/opencode/memd.sock")
REPO = "/home/enki/Projects/maplestory2/ms2ex/scripts/client-tools"
BAR_VTABLE = 0x141A62BA0  # decimal 5389705120

def run(args):
    return subprocess.run(
        [sys.executable, f"{REPO}/memc.py", *args],
        capture_output=True, text=True, timeout=900, env=dict(os.environ, MEMD_SOCK=SOCK),
    ).stdout

def q(addr):
    out = run(["READMEM", f"{addr:x}", "64"])
    val = {}
    for line in out.splitlines():
        if "q=0x" not in line:
            continue
        off, v = line.split(":", 1)
        off = off.strip()
        if not off.startswith("+"):
            continue
        try:
            key = int(off[1:], 16)
        except ValueError:
            continue
        val[key] = int(v.split("q=0x")[1].split()[0], 16)
    return val

print("=== globals ===")
for name, addr in [("config_registry", 0x14210be98), ("entity_registry", 0x14210bf78),
                   ("tick_flag", 0x14210e224), ("ui_state", 0x14210ed40)]:
    v = q(addr).get(0)
    print(f"  {name} [0x{addr:x}] = 0x{v:x}" if v else f"  {name} [0x{addr:x}] = NULL/0")

print("=== UIUpperHpBar instances ===")
out = run(["FIND2", str(BAR_VTABLE)])
lines = [l for l in out.splitlines() if l.startswith("0x")]
if not lines:
    print("  none (bar instance not present - is a boss in the field?)")
for l in lines[:10]:
    bar = int(l.split("=")[0], 16)
    f = q(bar)
    movie = f.get(0x38, 0)
    flag = f.get(0x14c, 0)
    link = f.get(0x3b8, 0)
    print(f"  bar 0x{bar:x}: movie=0x{movie:x} +14c=0x{flag:x} +3b8=0x{link:x}")
    if link:
        w = q(link)
        wid = w.get(0)
        w18 = w.get(0x18)
        w88 = w.get(0x88)
        w98 = w.get(0x98)
        print(f"    wrapper 0x{link:x}: id={wid} (0x{wid:x}) +18=0x{w18:x} +88=0x{w88:x} +98=0x{w98:x}")
        if w18:
            sub = q(w18)
            print(f"      [wrapper+18] 0x{w18:x}: +0=0x{sub.get(0,0):x} +8=0x{sub.get(8,0):x}")
print("DONE")