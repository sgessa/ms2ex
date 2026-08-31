#!/usr/bin/env python3
"""Scan a process's readable memory for strings (ASCII + UTF-16LE).

Usage: sudo python3 scan_client.py <pid> <str> [str2 ...]
"""
import re
import sys

MAX_PRINT = 60


def regions(pid):
    out = []
    with open(f"/proc/{pid}/maps") as f:
        for line in f:
            m = re.match(r"([0-9a-f]+)-([0-9a-f]+) (....) ", line)
            if not m:
                continue
            start, end, perms = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
            if "r" not in perms:
                continue
            parts = line.rstrip("\n").split(None, 5)
            name = parts[5] if len(parts) == 6 else ""
            out.append((start, end, perms, name))
    return out


def main():
    pid = sys.argv[1]
    strings = sys.argv[2:]
    needles = {}
    for s in strings:
        needles[f"utf16:{s}"] = s.encode("utf-16-le")
        needles[f"ascii:{s}"] = s.encode()

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
                    lo = max(0, idx - 48)
                    ctx = data[lo : idx + len(needle) + 64]
                    where = name or "anon"
                    print(f"{label} @ 0x{addr:x} [{where} {perms}]")
                    print(f"   ctx: {ctx!r}")
                    printed += 1
                idx = data.find(needle, idx + 1)
    for k, v in sorted(counts.items()):
        print(f"{k}: {v} hit(s)")


if __name__ == "__main__":
    main()
