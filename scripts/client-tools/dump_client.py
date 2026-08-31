#!/usr/bin/env python3
"""Hexdump memory ranges of a process.

Usage: sudo python3 dump_client.py <pid> <addr> [<addr>...] [--ctx N]
Dumps N bytes before and after each address (default 256).
"""
import sys


def read_mem(pid, start, end):
    with open(f"/proc/{pid}/mem", "rb", 0) as mem:
        mem.seek(start)
        return mem.read(end - start)


def hexdump(data, base):
    out = []
    for off in range(0, len(data), 16):
        chunk = data[off : off + 16]
        hx = " ".join(f"{b:02x}" for b in chunk)
        asc = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        out.append(f"0x{base + off:x}  {hx:<47}  |{asc}|")
    return "\n".join(out)


def main():
    args = sys.argv[1:]
    ctx = 256
    if "--ctx" in args:
        i = args.index("--ctx")
        ctx = int(args[i + 1])
        del args[i : i + 2]
    pid = args[0]
    for arg in args[1:]:
        addr = int(arg, 16)
        lo, hi = addr - ctx, addr + ctx
        try:
            data = read_mem(pid, lo, hi)
        except OSError as e:
            print(f"=== 0x{addr:x}: unreadable ({e})")
            continue
        print(f"=== 0x{addr:x} (0x{lo:x}-0x{hi:x})")
        print(hexdump(data, lo))
        print()


if __name__ == "__main__":
    main()
