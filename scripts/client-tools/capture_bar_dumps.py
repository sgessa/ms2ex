#!/usr/bin/env python3
"""Coordinated manual memory dumps of the boss HP bar UI region.

You drive it — the script waits for Enter at each step:

  1) stand next to the spawned boss (idle)     -> Enter  (baseline)
  2) attack the boss until the HP bar appears  -> Enter  (bar visible)
  3) stop attacking, wait for the bar to fade  -> Enter  (bar gone)
  ... repeat as needed ... type 'q' then Enter to finish.

Each step saves a BARPROBE2 summary and a full dump of the anchored UI
region, then diffs the two most recent dumps (byte-level, changed ranges)
and prints the probe-summary delta. Run against the reference server first
(where the bar works) so the diff shows exactly what the bar-arming does.

Usage: python3 capture_bar_dumps.py [output_dir]
"""
import os
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.abspath(__file__))
MEMC = os.path.join(REPO, "memc.py")
OUTDIR = sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/bar_dumps"
ENV = dict(os.environ, MEMD_SOCK="/tmp/opencode/memd.sock")


def memc(*args, timeout=300):
    r = subprocess.run(
        [sys.executable, MEMC, *args], capture_output=True, text=True,
        timeout=timeout, env=ENV,
    )
    return r.stdout.strip()


def probe_summary(lo, hi, model):
    out = memc("BARPROBE2", lo, hi, model)
    return out


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    print("anchoring UI region (stand still, ~30s)...", flush=True)
    anchor = memc("BARANCHOR", timeout=300)
    if not anchor.startswith("0x") or "region=" not in anchor:
        print("BARANCHOR failed:", anchor)
        return 1
    addr = anchor.split()[0]
    region = next(t for t in anchor.split() if t.startswith("region=")).split("=")[1]
    lo, hi = region.split("-")
    model = input("boss model name (e.g. 02020107_M_Lslime02): ").strip()
    print(f"anchored swf path at {addr}, region {lo}-{hi}, model={model!r}", flush=True)

    snaps = []
    seq = 0
    while True:
        key = input(f"\nstep {seq} ready -> Enter to snapshot (q=quit): ").strip().lower()
        if key == "q":
            break
        stamp = time.strftime("%H%M%S")
        dump_path = os.path.join(OUTDIR, f"step{seq:02d}_{stamp}.bin")
        probe = probe_summary(lo, hi, model)
        dump = memc("DUMPREGION", lo, hi, dump_path)
        rec = {"seq": seq, "stamp": stamp, "probe": probe, "dump": dump_path}
        snaps.append(rec)
        print(f"  [{stamp}] probe:", flush=True)
        for line in probe.splitlines():
            print("    ", line, flush=True)
        print("  ", dump, flush=True)

        if len(snaps) >= 2:
            prev, cur = snaps[-2], snaps[-1]
            print("\n  --- delta vs previous ---", flush=True)
            pkeys = [k for k in cur["probe"].splitlines() if "=" in k]
            for pline in pkeys:
                key = pline.split("=")[0]
                old = next((l for l in prev["probe"].splitlines() if l.startswith(key + "=")), "?")
                mark = "  <-- CHANGED" if old.split("=", 1)[-1] != pline.split("=", 1)[-1] else ""
                print(f"    {key}: {old.split('=',1)[-1]} -> {pline.split('=',1)[-1]}{mark}", flush=True)
            print("  diff regions (old vs new):", flush=True)
            for a, b in diff_regions(prev["dump"], cur["dump"]):
                print(f"    0x{lo} + 0x{a:x} .. +0x{b:x}  (len {b-a})", flush=True)
        seq += 1

    print(f"\ndone -> {OUTDIR}")
    return 0


def diff_regions(path_a, path_b):
    """Yield (start_off, end_off) of differing byte ranges between two dumps."""
    with open(path_a, "rb") as fa, open(path_b, "rb") as fb:
        a = fa.read()
        b = fb.read()
    n = min(len(a), len(b))
    out = []
    i = 0
    while i < n:
        if a[i] != b[i]:
            start = i
            while i < n and a[i] != b[i]:
                i += 1
            out.append((start, i))
        else:
            i += 1
    return out[:60]


if __name__ == "__main__":
    sys.exit(main())