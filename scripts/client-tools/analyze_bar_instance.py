#!/usr/bin/env python3
"""Decode the UIUpperHpBar instance from a memory dump.

Given a dump from dump_full_memory.py, finds the live UIUpperHpBar instance
(vtable 0x141a62ba0) and decodes its arming state:
  - instance: vtable, movie ptr, +0x14c, +0x15c, +0x3b8 link
  - if the link is non-NULL: the bar-entity wrapper's target entity id,
    byte[+0x14], and embedded wide strings

Run this on the REFERENCE dump (bar works -> link populated) and on an ms2ex
dump (bar broken -> expect link NULL) and diff the output.

Usage: python3 analyze_bar_instance.py [dumpdir]   (default /tmp/opencode/bar_dump)
"""
import mmap
import os
import struct
import sys

VTABLE = 0x141A62BA0
VTABLE_B = struct.pack("<Q", VTABLE)


def find_instance(dumpdir):
    files = sorted(
        f for f in os.listdir(dumpdir)
        if f.startswith("region_") and f.endswith(".bin")
    )
    for fname in files:
        start_s, end_s = fname[len("region_"):].split("-")
        start = int(start_s, 16)
        path = os.path.join(dumpdir, fname)
        with open(path, "rb") as fh:
            data = mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ)
        idx = 0
        while True:
            idx = data.find(VTABLE_B, idx)
            if idx < 0:
                break
            if idx % 8 == 0:
                return start, idx, fname
            idx += 1
        data.close()
    return None


def main():
    dumpdir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/bar_dump"
    hit = find_instance(dumpdir)
    if hit is None:
        print(f"no UIUpperHpBar instance (vtable 0x{VTABLE:x}) found in {dumpdir}")
        return 1
    start, idx, fname = hit
    inst = start + idx
    print(f"instance VA 0x{inst:x}  (region {fname}, file off 0x{idx:x})")

    path = os.path.join(dumpdir, fname)
    with open(path, "rb") as fh:
        data = mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ)

    def q(a):
        off = a - start
        if 0 <= off + 8 <= len(data):
            return struct.unpack_from("<Q", data, off)[0]
        return None

    def u32(a):
        off = a - start
        if 0 <= off + 4 <= len(data):
            return struct.unpack_from("<I", data, off)[0]
        return None

    def wstr(a, n=32):
        off = a - start
        if off < 0 or off + n > len(data):
            return ""
        out = []
        for i in range(off, off + n - 1, 2):
            c = struct.unpack_from("<H", data, i)[0]
            if c == 0:
                break
            out.append(chr(c))
        return "".join(out)

    print(f"  +0x00 vtable      = 0x{q(inst):x}")
    print(f"  +0x38 movie       = 0x{q(inst + 0x38):x}")
    print(f"  +0x14c guard      = 0x{u32(inst + 0x14c):x}")
    print(f"  +0x15c            = 0x{u32(inst + 0x15c):x}")
    link = q(inst + 0x3b8)
    if not link:
        print("  +0x3b8 link       = NULL  (bar never armed - chain never set it)")
        return 0
    print(f"  +0x3b8 link       = 0x{link:x}")
    tid = u32(link)
    print(f"    wrapper +0     = 0x{tid:x} ({tid})  <- target entity id")
    b14 = u32(link + 0x14)
    print(f"    wrapper +0x14  = {b14 if b14 is None else hex(b14)} "
          f"(byte {hex(b14 & 0xff) if b14 is not None else '?'})")
    for a in range(link, link + 0xa0, 2):
        s = wstr(a, 24)
        if len(s) >= 2 and s.isprintable():
            print(f"    wide +0x{a - link:x} -> {s!r}")
    data.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())