#!/usr/bin/env python3
"""Scan process memory for 8-byte LE pointers to given addresses.

Usage: sudo python3 pointer_scan.py <pid> <addr> [<addr>...]
"""
import re
import struct
import sys

MAX_PRINT = 80


def regions(pid):
    out = []
    with open(f"/proc/{pid}/maps") as f:
        for line in f:
            m = re.match(r"([0-9a-f]+)-([0-9a-f]+) (....) ", line)
            if not m:
                continue
            start, end, perms = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
            if "r" not in perms or "w" not in perms:
                continue
            parts = line.rstrip("\n").split(None, 5)
            name = parts[5] if len(parts) == 6 else ""
            out.append((start, end, perms, name))
    return out


def main():
    pid = sys.argv[1]
    targets = [int(a, 16) for a in sys.argv[2:]]
    needles = {}
    for t in targets:
        needles[f"->0x{t:x}"] = struct.pack("<Q", t)

    mem = open(f"/proc/{pid}/mem", "rb", 0)
    printed = 0
    counts = {k: 0 for k in needles}
    for start, end, perms, name in regions(pid):
        try:
            mem.seek(start)
            data = mem.read(end - start)
        except (OSError, OverflowError):
            continue
        for label, needle in needles.items():
            idx = data.find(needle)
            while idx != -1:
                counts[label] += 1
                if printed < MAX_PRINT:
                    addr = start + idx
                    lo = max(0, idx - 64)
                    ctx = data[lo : idx + 72]
                    print(f"{label} @ 0x{addr:x} [{name or 'anon'}]")
                    print(f"   ctx: {ctx!r}")
                    printed += 1
                idx = data.find(needle, idx + 1)
    for k, v in sorted(counts.items()):
        print(f"{k}: {v} ref(s)")


if __name__ == "__main__":
    main()
