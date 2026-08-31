#!/usr/bin/env python3
"""Capture the reference client's heap + UI regions during a boss hit.

Usage: python3 capture_refheap.py <label>
Run while the player is attacking a field boss (bar visible).

UIUpperHpBar instances (vtable 0x141a62ba0) are created LAZILY when a boss is
in the field. On ms2ex the instance landed at 0x36dcf280 (region
0x341f0000-0x38130000), which the original capture missed entirely. This
version adds the high heap regions and scans every dumped region for the
vtable at the end so we know exactly where the bar landed.
"""
import os
import subprocess
import sys
import time

SOCK = "/tmp/opencode/memd.sock"
REPO = "/home/enki/Projects/maplestory2/ms2ex/scripts/client-tools"
OUT = "/tmp/opencode/refheap"
BAR_VTABLE = 0x141A62BA0  # UIUpperHpBar vtable (decimal 5389705120)
os.makedirs(OUT, exist_ok=True)

def run(args):
    return subprocess.run(
        [sys.executable, f"{REPO}/memc.py", *args],
        capture_output=True, text=True, timeout=900, env=dict(os.environ, MEMD_SOCK=SOCK),
    )

label = sys.argv[1] if len(sys.argv) > 1 else "snap"
start = time.time()

REGIONS = [
    ("252f0000", "28670000"),   # LOW heap: bar parent/fill objects
    ("28672000", "28770000"),
    ("2abf0000", "2bbc0000"),   # anchored UI region (bar fill data)
    ("28790000", "2a730000"),   # big heap
    ("2a732000", "2a830000"),
    ("2a832000", "2a930000"),
    ("2a932000", "2aa30000"),
    ("2aa32000", "2ab30000"),
    ("2bbc2000", "2bcc0000"),
    ("2bcc2000", "2bdd0000"),
    ("2bfc2000", "2c0c0000"),
    ("2c0c2000", "2c1c0000"),
    ("2c200000", "2d1d0000"),
    ("2d6f0000", "2e6c0000"),
    ("2f070000", "30040000"),
    ("30040000", "33020000"),
    ("33220000", "341f0000"),
    ("341f0000", "38130000"),   # HIGH heap: UIUpperHpBar instance lives here
    ("38130000", "3c740000"),
]

dumped = []
for i, (lo, hi) in enumerate(REGIONS):
    t0 = time.time()
    path = f"{OUT}/{label}_{i}_{lo}_{hi}.bin"
    r = run(["DUMPREGION", lo, hi, path])
    dt = time.time() - t0
    msg = r.stdout.strip() or r.stderr.strip()
    print(f"[{dt:6.1f}s] {msg}", flush=True)
    dumped.append((lo, hi, path))

# scan every dumped region for the UIUpperHpBar vtable (bar must be visible)
for lo, hi, path in dumped:
    t0 = time.time()
    r = run(["REGIONSCAN", lo, hi, str(BAR_VTABLE)])
    out = r.stdout.strip() or r.stderr.strip()
    print(f"[{time.time()-t0:6.1f}s] {lo}-{hi}: {out}", flush=True)

print(f"TOTAL {time.time()-start:.1f}s", flush=True)