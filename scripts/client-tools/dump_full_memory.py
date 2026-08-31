#!/usr/bin/env python3
"""Full writable-memory dump of the game client via memd.

Run this WHILE THE HP BAR IS SHOWING (keep hitting mobs so it stays up — the
bar re-arms on every hit, so mobs dying quickly is fine as long as you keep
attacking). Dumps every writable region (optionally restricted to a VA band)
to <out>/region_<start>-<end>.bin and writes <out>/index.txt. Later, search
the dump offline with search_dump.py — no need to keep the game running.

The bar lives in the Wine heap zone; a quick capture is ~1 GiB and takes
~30-60s:
  python3 dump_full_memory.py --lo 0x10000000 --hi 0x60000000 /tmp/opencode/bar_dump
Full capture (all ~3.8 GiB) is slower and needs sustained fighting.

Usage: python3 dump_full_memory.py [--lo HEX] [--hi HEX] [outdir]
"""
import argparse
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.abspath(__file__))
MEMC = os.path.join(REPO, "memc.py")
SOCK = os.environ.get("MEMD_SOCK", "/tmp/opencode/memd.sock")
ENV = dict(os.environ, MEMD_SOCK=SOCK)


def memc(*args, timeout=900):
    return subprocess.run(
        [sys.executable, MEMC, *args], capture_output=True, text=True,
        timeout=timeout, env=ENV,
    ).stdout


def regions():
    out = memc("REGIONS")
    rows = []
    for line in out.splitlines():
        line = line.strip()
        if not line or line == "END":
            continue
        a, b = line.split("-")
        rows.append((int(a, 16), int(b, 16)))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lo", default="0x0", help="only dump regions at/above this VA")
    ap.add_argument("--hi", default="0xffffffffff", help="only dump regions at/below this VA")
    ap.add_argument("outdir", nargs="?", default="/tmp/opencode/bar_dump")
    args = ap.parse_args()
    lo, hi = int(args.lo, 16), int(args.hi, 16)
    outdir = args.outdir

    os.makedirs(outdir, exist_ok=True)
    rows = [r for r in regions() if r[1] > lo and r[0] < hi]
    rows.sort(key=lambda r: r[1] - r[0], reverse=True)
    total = sum(min(b, hi) - max(a, lo) for a, b in rows)
    print(f"{len(rows)} writable regions in 0x{lo:x}-0x{hi:x}, "
          f"{total / 1024 / 1024:.0f} MiB total", flush=True)
    print("KEEP HITTING mobs so the HP bar stays up during the dump...", flush=True)

    idx = []
    done = 0
    for n, (a, b) in enumerate(rows, 1):
        path = os.path.join(outdir, f"region_{a:x}-{b:x}.bin")
        memc("DUMPREGION", f"{a:x}", f"{b:x}", path)
        size = os.path.getsize(path)
        idx.append(f"0x{a:x} 0x{b:x} {size} {os.path.basename(path)}")
        done += b - a
        print(f"[{n}/{len(rows)}] 0x{a:x}-0x{b:x} ({size / 1024 / 1024:.1f} MiB)  "
              f"{done * 100 // total}%", flush=True)

    with open(os.path.join(outdir, "index.txt"), "w") as f:
        f.write("\n".join(idx) + "\n")
    print(f"done -> {outdir} (index.txt)")
    print("now search offline: python3 search_dump.py " + outdir + " [--model NAME]")


if __name__ == "__main__":
    sys.exit(main())