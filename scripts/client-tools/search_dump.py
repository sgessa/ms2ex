#!/usr/bin/env python3
"""Search a full memory dump (from dump_full_memory.py) for the HP bar.

Scans every region_*.bin for:
  - qword vtable 0x141a62ba0   (a live UIUpperHpBar instance)
  - ASCII "UIUpperHPBar/"      (instantiated composite symbols)
  - ASCII "UIUpperHPBar"       (any, incl. the swf path)
  - UTF-16LE model name        (if --model NAME given)

Hits are reported with region + approximate VA (region start + file offset,
assuming contiguous readable pages within a region).

Usage: python3 search_dump.py [dumpdir] [--model NAME] [--detail]
"""
import argparse
import mmap
import os
import struct
import sys

VTABLE = 0x141A62BA0
VTABLE_B = struct.pack("<Q", VTABLE)
COMPS = b"UIUpperHPBar/"
ANY = b"UIUpperHPBar"


def count_hits(data, pat, limit=200):
    out = []
    idx = 0
    while True:
        idx = data.find(pat, idx)
        if idx < 0 or len(out) >= limit:
            break
        out.append(idx)
        idx += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dumpdir", nargs="?", default="/tmp/opencode/bar_dump")
    ap.add_argument("--model", default="", help="mob model name (UTF-16LE needle)")
    ap.add_argument("--detail", action="store_true", help="print hit offsets, not just counts")
    args = ap.parse_args()

    files = sorted(
        f for f in os.listdir(args.dumpdir)
        if f.startswith("region_") and f.endswith(".bin")
    )
    if not files:
        print(f"no region_*.bin in {args.dumpdir}")
        return 1

    model_wide = args.model.encode("utf-16-le") if args.model else None
    print(f"scanning {len(files)} regions in {args.dumpdir} "
          f"(model={args.model or 'none'})...", flush=True)

    instance_vtbl = []
    for fname in files:
        start_s, end_s = fname[len("region_"):].split("-")
        start, end = int(start_s, 16), int(end_s[: -len(".bin")], 16)
        path = os.path.join(args.dumpdir, fname)
        with open(path, "rb") as fh:
            data = mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ)

        n_vt = len(count_hits(data, VTABLE_B))
        n_comp = len(count_hits(data, COMPS))
        n_any = len(count_hits(data, ANY))
        n_model = len(count_hits(data, model_wide)) if model_wide else 0

        if args.detail:
            for off in count_hits(data, VTABLE_B, limit=20):
                if off % 8 == 0:
                    print(f"  vtbl 0x{start:x}+0x{off:x} = 0x{start + off:x}")
            for off in count_hits(data, COMPS, limit=10):
                print(f"  comp 0x{start:x}+0x{off:x} = 0x{start + off:x}")
            if model_wide:
                for off in count_hits(data, model_wide, limit=10):
                    print(f"  name 0x{start:x}+0x{off:x} = 0x{start + off:x}")

        if n_vt or n_comp or n_model:
            print(f"{fname}: vtbl={n_vt} composite={n_comp} any={n_any} "
                  f"name={n_model}")
            for off in count_hits(data, VTABLE_B, limit=20):
                if off % 8 == 0:
                    instance_vtbl.append((start + off, fname))
        data.close()

    print()
    if instance_vtbl:
        print(f"{len(instance_vtbl)} UIUpperHpBar instance candidate(s):")
        for va, fname in instance_vtbl:
            print(f"  0x{va:x}  ({fname})")
        print("confirm + read the +0x3b8 chain live via probe_bar_chain.py / READMEM")
    else:
        print("no UIUpperHpBar instance found (bar not up during the dump?)")
    return 0


if __name__ == "__main__":
    sys.exit(main())