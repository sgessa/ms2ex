#!/usr/bin/env python3
"""Live probe of the HP-bar dispatch pre-conditions via memd.

Run against BOTH clients (reference first, where the bar works; then ms2ex)
with a mob present, and diff the output. The bar's wrapper is only created
if `container->find_entity(0x6200028)` returns a mob, which is gated behind
these dispatch pre-conditions (all traced at the assembly level):

  1. field = [container + 0x1b00]; bit 3 of [field + 0x800] must be SET
  2. [0x14210be98] (config registry) != NULL, and config key 0x4e3d resolves
  3. [container + 0x14c] == 0

This scans the writable heap for the dispatch container (objects whose first
qword is a vtable in the code range, whose [X+0x1b00] points to a field with
a small [field+0x800] bitmask, and whose [X+0x14c] == 0) and prints the
distinct field bitmasks found. Compare which bit 3 state exists on each
server.

Usage: MEMD_SOCK=... python3 probe_dispatch.py
"""
import os
import struct
import subprocess
import sys

REPO = os.path.dirname(os.path.abspath(__file__))
MEMC = os.path.join(REPO, "memc.py")
SOCK = os.environ.get("MEMD_SOCK", "/tmp/opencode/memd.sock")
ENV = dict(os.environ, MEMD_SOCK=SOCK)

CODE_LO, CODE_HI = 0x140000000, 0x142660000


def memc(*args, timeout=300):
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


def probe(field_addr, stride=8):
    # read one qword; field_addr absolute
    out = memc("READMEM", f"{field_addr:x}", "8")
    for line in out.splitlines():
        if "q=0x" in line:
            return int(line.split("q=0x")[1].split()[0], 16)
    return None


def main():
    try:
        pid = memc("PID", timeout=15).strip()
    except Exception as exc:
        print(f"memd not reachable on {SOCK}: {exc!r}")
        return 1
    print(f"client pid {pid}, socket {SOCK}", flush=True)

    for name, addr in [
        ("config_registry [0x14210be98]", 0x14210be98),
        ("entity_registry [0x14210bf78]", 0x14210bf78),
        ("tick_flag   [0x14210e224]", 0x14210e224),
        ("bar_flag    [0x14210d224]", 0x14210d224),
    ]:
        v = probe(addr)
        print(f"  {name} = 0x{v:x}" if v else f"  {name} = NULL")

    print("scanning heap for dispatch containers (may take a while)...", flush=True)
    found = set()
    count = 0
    for lo, hi in regions():
        if hi - lo < 0x2000:
            continue
        size = hi - lo
        out = memc("DUMPREGION", f"{lo:x}", f"{hi:x}", f"/tmp/opencode/probe_{lo:x}.bin")
        try:
            data = open(f"/tmp/opencode/probe_{lo:x}.bin", "rb").read()
        except OSError:
            continue
        n = len(data)
        for off in range(0, n - 0x1b10, 8):
            vt = struct.unpack_from("<Q", data, off)[0]
            if not (CODE_LO <= vt < CODE_HI):
                continue
            v14c = struct.unpack_from("<I", data, off + 0x14c)[0]
            if v14c != 0:
                continue
            field = struct.unpack_from("<Q", data, off + 0x1b00)[0]
            if not field:
                continue
            # check the field bitmask live (field may be outside this region)
            m = probe(field + 0x800)
            if m is None or m == 0 or m >= 0x1000:
                continue
            key = (vt, m)
            if key in found:
                continue
            found.add(key)
            count += 1
            print(f"  container 0x{lo + off:x} vtable=0x{vt:x} "
                  f"field=0x{field:x} [field+0x800]=0x{m:x} bit3={(m >> 3) & 1}",
                  flush=True)
            if count >= 30:
                break
        os.unlink(f"/tmp/opencode/probe_{lo:x}.bin")
        if count >= 30:
            break

    print(f"\n{count} container/field-mask combos ({len(found)} unique)")
    print("-> look for a field mask with bit3=1 (bar dispatch proceeds) vs bit3=0")
    return 0


if __name__ == "__main__":
    sys.exit(main())