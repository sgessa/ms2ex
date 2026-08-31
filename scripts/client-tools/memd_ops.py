#!/usr/bin/env python3
import os
"""Ops module for memd.py - hot-reloaded on mtime change.

Each handler: fn(ctx, parts, write) -> None; use ctx.mem, ctx.game_pid.
Emit lines via write(), finish with ctx.end(*lines).
"""
import re
import struct


def find_regions(mem):
    out = []
    with open(f"/proc/{mem.pid}/maps") as f:
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


def iter_regions_data(mem):
    for s, e, perms, name in find_regions(mem):
        pos = s
        while pos < e:
            n = min(1 << 26, e - pos)
            try:
                buf = mem.read(pos, n)
            except OSError:
                break
            if buf:
                yield pos, buf, (perms, name)
            pos += len(buf)


def scan_strings(mem, needle, wide=False):
    pat = needle.encode("utf-16-le") if wide else needle.encode()
    hits = []
    for pos, buf, meta in iter_regions_data(mem):
        idx = buf.find(pat)
        while idx != -1 and len(hits) < 40:
            hits.append((pos + idx, meta))
            idx = buf.find(pat, idx + 1)
    return hits


def scan_pointers(mem, targets):
    needles = {t: struct.pack("<Q", t) for t in targets}
    hits = []
    for pos, buf, meta in iter_regions_data(mem):
        for t, pat in needles.items():
            idx = buf.find(pat)
            while idx != -1 and len(hits) < 60:
                # keep only qword-aligned hits
                if (pos + idx) % 8 == 0:
                    hits.append((pos + idx, t, meta))
                idx = buf.find(pat, idx + 1)
    return hits


_libc = None
_IOVEC = None


def _vm_read(pid, addr, size):
    """Cached-libc process_vm_readv; returns bytes or None."""
    global _libc, _IOVEC
    if _libc is None:
        import ctypes

        _libc = ctypes.CDLL("libc.so.6", use_errno=True)

        class iovec(ctypes.Structure):
            _fields_ = [
                ("iov_base", ctypes.c_void_p),
                ("iov_len", ctypes.c_size_t),
            ]

        _IOVEC = iovec
    import ctypes

    buf = ctypes.create_string_buffer(size)
    local = _IOVEC(ctypes.cast(buf, ctypes.c_void_p), size)
    remote = _IOVEC(ctypes.c_void_p(addr), size)
    n = _libc.process_vm_readv(
        ctypes.c_int(pid),
        ctypes.byref(local), 1,
        ctypes.byref(remote), 1,
        ctypes.c_ulong(0),
    )
    if n == size:
        return buf.raw
    return None


def fast_iter_qwords(pid, start, end):
    CHUNK = 1 << 23
    pos = start
    while pos < end:
        n = min(CHUNK, end - pos)
        buf = _vm_read(pid, pos, n)
        if buf is None or len(buf) == 0:
            lo, hi = pos + 0x1000, end
            while lo < hi:
                mid = (lo + hi) // 2 & ~0xFFF
                if _vm_read(pid, mid, 0x1000) is None:
                    lo = mid + 0x1000
                else:
                    hi = mid
            pos = lo
            continue
        aligned = (len(buf) // 8) * 8
        for i in range(0, aligned, 8):
            yield pos + i, struct.unpack_from("<Q", buf, i)[0]
        pos += len(buf)


def find_u32_fast(pid, want, start, end):
    pat = struct.pack("<I", want)
    hits = []
    pos = start
    while pos < end:
        n = min(1 << 23, end - pos)
        buf = _vm_read(pid, pos, n)
        if buf is None or len(buf) == 0:
            lo, hi = pos + 0x1000, end
            while lo < hi:
                mid = (lo + hi) // 2 & ~0xFFF
                if _vm_read(pid, mid, 0x1000) is None:
                    lo = mid + 0x1000
                else:
                    hi = mid
            pos = lo
            continue
        idx = buf.find(pat)
        while idx != -1 and len(hits) < 200:
            hits.append(pos + idx)
            idx = buf.find(pat, idx + 1)
        pos += len(buf)
    return hits


def _read(mem, addr, size):
    try:
        return mem.read(addr, size)
    except OSError:
        return None


def iter_qwords(mem, start, end):
    """Short-read-safe qword iteration with bisection over unreadable holes."""
    CHUNK = 1 << 23  # 8 MiB
    pos = start
    tail = b""
    while pos < end:
        n = min(CHUNK, end - pos)
        buf = _read(mem, pos, n)
        if buf is None or len(buf) == 0:
            # bisect forward for the next readable page
            lo, hi = pos + 0x1000, end
            while lo < hi:
                mid = (lo + hi) // 2 & ~0xFFF
                if _read(mem, mid, 0x1000) is None:
                    lo = mid + 0x1000
                else:
                    hi = mid
            pos = lo
            tail = b""
            continue
        if len(buf) < n:
            # partial read: emit what we can and move past it
            base = pos
            pos += len(buf)
            tail = b""
            aligned = (len(buf) // 8) * 8
            for i in range(0, aligned, 8):
                yield base + i, struct.unpack_from("<Q", buf, i)[0]
            continue
        buf = tail + buf
        usable = len(buf) - len(buf) % 8
        base = pos - len(tail)
        for i in range(0, usable, 8):
            yield base + i, struct.unpack_from("<Q", buf, i)[0]
        tail = buf[usable:]
        pos += max(len(buf) - len(tail), 1)


def _scan_i64(mem, want=None, lo=None, hi=None):
    hits = []
    for s, e, perms, name in find_regions(mem):
        if "w" not in perms:
            continue
        for addr, raw in iter_qwords(mem, s, e):
            v = struct.unpack("<q", struct.pack("<Q", raw))[0]
            if want is not None and v == want:
                hits.append((addr, v))
            elif want is None and lo <= v <= hi:
                hits.append((addr, v))
    return hits


def register(handlers):
    def op_find2(ctx, parts, write):
        want = int(parts[1])
        hits = []
        for s, e, perms, name in find_regions(ctx.mem):
            if "w" not in perms:
                continue
            for addr, raw in fast_iter_qwords(ctx.game_pid, s, e):
                v = struct.unpack("<q", struct.pack("<Q", raw))[0]
                if v == want:
                    hits.append((addr, v))
            if len(hits) >= 200:
                break
        lines = [str(len(hits))] + [f"0x{a:x} = {v}" for a, v in hits[:60]]
        ctx.end(*lines)

    def op_dec2(ctx, parts, write):
        path, delta = parts[1], (None if parts[2] == "--any" else int(parts[2]))
        kept = []
        pairs = []
        blob_path = path
        old_pairs = []
        if os.path.exists(blob_path):
            import struct as st

            blob = open(blob_path, "rb").read()
            old_pairs = list(st.iter_unpack("<Qq", blob[: len(blob) // 16 * 16]))
        for addr, old in old_pairs:
            try:
                raw = ctx.mem.read(addr, 8)
                v = st.unpack("<q", raw)[0]
            except OSError:
                continue
            d = old - v
            if (delta is None and d > 0) or d == delta:
                kept.append((addr, v))
        with open(blob_path, "wb") as f:
            import struct as st

            for a, v in kept:
                f.write(st.pack("<Qq", a, v))
        lines = [str(len(kept))] + [f"0x{a:x} = {v}" for a, v in kept[:60]]
        ctx.end(*lines)

    def op_regionscan(ctx, parts, write):
        start, end, want = int(parts[1], 16), int(parts[2], 16), int(parts[3])
        total = 0
        found = []
        last = None
        seen_hex = []
        for addr, raw in iter_qwords(ctx.mem, start, end):
            total += 1
            last = addr
            if addr >= end - 16:
                seen_hex.append(f"0x{addr:x}:{raw:x}")
            v = struct.unpack("<q", struct.pack("<Q", raw))[0]
            if v == want:
                found.append(addr)
        ctx.end(
            f"scanned={total} first=0x{start:x} last=0x{last:x} "
            f"found={len(found)} {[hex(a) for a in found]} tail={seen_hex}",
        )

    def op_findu32(ctx, parts, write):
        want = int(parts[1])
        pat = struct.pack("<I", want)
        hits = []
        for s, e, perms, name in find_regions(ctx.mem):
            if "w" not in perms:
                continue
            pos = s
            while pos < e:
                n = min(1 << 24, e - pos)
                try:
                    buf = ctx.mem.read(pos, n)
                except OSError:
                    pos = (pos + 0x1000) & ~0xFFF
                    continue
                if not buf:
                    break
                idx = buf.find(pat)
                base = pos
                while idx != -1 and len(hits) < 80:
                    hits.append((base + idx, (perms, name)))
                    idx = buf.find(pat, idx + 1)
                pos += len(buf)
        lines = [str(len(hits))] + [
            f"0x{a:x} [{n or 'anon'}]" for a, (p, n) in hits[:60]
        ]
        ctx.end(*lines)

    def op_findu32range(ctx, parts, write):
        want = int(parts[1])
        start, end = int(parts[2], 16), int(parts[3], 16)
        hits = find_u32_fast(ctx.game_pid, want, start, end)
        ctx.end(*([str(len(hits))] + [f"0x{a:x}" for a in hits[:120]]))

    def op_pokeu32(ctx, parts, write):
        import ctypes
        import errno

        addr, val = int(parts[1], 16), int(parts[2])
        class iovec(ctypes.Structure):
            _fields_ = [("iov_base", ctypes.c_void_p), ("iov_len", ctypes.c_size_t)]

        data = struct.pack("<I", val)
        buf = ctypes.create_string_buffer(data, len(data))
        local = iovec(ctypes.cast(buf, ctypes.c_void_p), len(data))
        remote = iovec(ctypes.c_void_p(addr), len(data))
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        n = libc.process_vm_writev(
            ctypes.c_int(ctx.game_pid),
            ctypes.byref(local), 1,
            ctypes.byref(remote), 1,
            ctypes.c_ulong(0),
        )
        if n == len(data):
            ctx.end(f"wrote {val} -> 0x{addr:x}")
        else:
            err = ctypes.get_errno()
            ctx.end(f"ERR writev failed errno={err} n={n}")

    def op_barprobe(ctx, parts, write):
        """One memory sweep, many needles: catches transient UI state."""
        model = parts[1] if len(parts) > 1 else ""
        needles = {
            "upper_composite": b"UIUpperHPBar/",
            "upper_any": b"UIUpperHPBar",
            "duel_composite": b"UINpcDuelHPBarDialog/__setProp",
            "swf_path": b"/GFxAssets/UIUpperHPBar.swf",
        }
        if model:
            needles["name_wide"] = model.encode("utf-16-le")
            needles["name_ascii"] = model.encode()
        counts = {k: [] for k in needles}
        for s, e, perms, name in find_regions(ctx.mem):
            if "w" not in perms:
                continue
            pos = s
            while pos < e:
                n = min(1 << 23, e - pos)
                try:
                    buf = ctx.mem.read(pos, n)
                except OSError:
                    lo, hi = pos + 0x1000, e
                    while lo < hi:
                        mid = (lo + hi) // 2 & ~0xFFF
                        try:
                            ctx.mem.read(mid, 0x1000)
                            hi = mid
                        except OSError:
                            lo = mid + 0x1000
                    pos = lo
                    continue
                if not buf:
                    break
                for label, pat in needles.items():
                    idx = buf.find(pat)
                    while idx != -1 and len(counts[label]) < 20:
                        counts[label].append(pos + idx)
                        idx = buf.find(pat, idx + 1)
                pos += len(buf)
        lines = []
        for label, addrs in counts.items():
            lines.append(f"{label}={len(addrs)}")
            lines += [f"  0x{a:x}" for a in addrs[:6]]
        ctx.end(*lines)

    handlers["FIND2"] = op_find2
    handlers["DEC2"] = op_dec2
    handlers["REGIONSCAN"] = op_regionscan
    handlers["FINDU32"] = op_findu32
    handlers["FINDU32RANGE"] = op_findu32range
    handlers["POKEU32"] = op_pokeu32

    def op_pokebytes(ctx, parts, write):
        import ctypes
        addr = int(parts[1], 16)
        vals = bytes([int(x, 0) for x in parts[2:]])
        class iovec(ctypes.Structure):
            _fields_ = [("iov_base", ctypes.c_void_p), ("iov_len", ctypes.c_size_t)]
        buf = ctypes.create_string_buffer(vals, len(vals))
        local = iovec(ctypes.cast(buf, ctypes.c_void_p), len(vals))
        remote = iovec(ctypes.c_void_p(addr), len(vals))
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        n = libc.process_vm_writev(ctypes.c_int(ctx.game_pid), ctypes.byref(local), 1, ctypes.byref(remote), 1, ctypes.c_ulong(0))
        ctx.end(f"wrote {n}B -> 0x{addr:x}: {' '.join(f'{b:02x}' for b in vals)}")

    handlers["POKEBYTES"] = op_pokebytes

    def op_baranchor(ctx, parts, write):
        """Locate the UUIpperHPBar.swf path string once; report its region."""
        pat = b"/GFxAssets/UIUpperHPBar.swf"
        hit = None
        for s, e, perms, name in find_regions(ctx.mem):
            if "w" not in perms:
                continue
            pos = s
            while pos < e and hit is None:
                n = min(1 << 23, e - pos)
                try:
                    buf = ctx.mem.read(pos, n)
                except OSError:
                    pos = (pos + 0x1000) & ~0xFFF
                    continue
                if not buf:
                    break
                idx = buf.find(pat)
                if idx != -1:
                    hit = (pos + idx, s, e)
                pos += len(buf)
        if hit:
            addr, lo, hi = hit
            ctx.end(f"0x{addr:x} region=0x{lo:x}-0x{hi:x} size={hi-lo}")
        else:
            ctx.end("NOT_FOUND")

    def op_barprobe2(ctx, parts, write):
        """Fast probe limited to one region: BARPROBE2 <start hex> <end hex> [model]"""
        start, end = int(parts[1], 16), int(parts[2], 16)
        model = parts[3] if len(parts) > 3 else ""
        needles = {
            "upper_composite": b"UIUpperHPBar/",
            "upper_any": b"UIUpperHPBar",
            "swf_path": b"/GFxAssets/UIUpperHPBar.swf",
        }
        if model:
            needles["name_wide"] = model.encode("utf-16-le")
        counts = {k: [] for k in needles}
        pos = start
        while pos < end:
            n = min(1 << 22, end - pos)
            try:
                buf = ctx.mem.read(pos, n)
            except OSError:
                pos = (pos + 0x1000) & ~0xFFF
                continue
            if not buf:
                break
            for label, pat in needles.items():
                idx = buf.find(pat)
                while idx != -1 and len(counts[label]) < 20:
                    counts[label].append(pos + idx)
                    idx = buf.find(pat, idx + 1)
            pos += len(buf)
        lines = []
        for label, addrs in counts.items():
            lines.append(f"{label}={len(addrs)}")
            lines += [f"  0x{a:x}" for a in addrs[:6]]
        ctx.end(*lines)

    handlers["BARANCHOR"] = op_baranchor
    handlers["BARPROBE2"] = op_barprobe2
    def op_findstr(ctx, parts, write):
        _, needle, mode = parts[1], " ".join(parts[1:-1]), parts[-1]
        # allow: FINDSTR <text> [--wide]
        if needle == "--wide":
            write("ERR bad args")
            return
        wide = False
        text = " ".join(parts[1:])
        if text.endswith("--wide"):
            wide, text = True, text[: -6].strip()
        for addr, (perms, name) in scan_strings(ctx.mem, text, wide):
            write(f"0x{addr:x} [{name or 'anon'} {perms}]")
        ctx.end()

    def op_ptrscan(ctx, parts, write):
        targets = [int(a, 16) for a in parts[1:]]
        for addr, t, (perms, name) in scan_pointers(ctx.mem, targets):
            write(f"0x{addr:x} -> 0x{t:x} [{name or 'anon'} {perms}]")
        ctx.end()

    handlers["FINDSTR"] = op_findstr
    handlers["PTRSCAN"] = op_ptrscan

    def op_readmem(ctx, parts, write):
        addr = int(parts[1], 16)
        size = int(parts[2], 0) if len(parts) > 2 else 8
        data = _read(ctx.mem, addr, size)
        if data is None:
            write("ERR unreadable")
        else:
            hexstr = " ".join(f"{b:02x}" for b in data)
            write(f"0x{addr:x} ({len(data)}B): {hexstr}")
            if size >= 8:
                vals = {}
                for off in range(0, len(data) - 7, 8):
                    q = struct.unpack_from("<Q", data, off)[0]
                    vals[off] = f"0x{q:x}"
                for off, v in vals.items():
                    write(f"  +{off:02x}: q={v}")
            if size >= 4:
                for off in range(0, len(data) - 3, 4):
                    u = struct.unpack_from("<I", data, off)[0]
                    write(f"  +{off:02x}: u32=0x{u:x} ({u})")
        ctx.end()

    handlers["READMEM"] = op_readmem

    def op_dumpregion(ctx, parts, write):
        """DUMPREGION <start hex> <end hex> <path>: write raw bytes to a file."""
        start, end = int(parts[1], 16), int(parts[2], 16)
        path = parts[3]
        written = 0
        pos = start
        with open(path, "wb") as f:
            while pos < end:
                n = min(1 << 22, end - pos)
                try:
                    buf = ctx.mem.read(pos, n)
                except OSError:
                    pos = (pos + 0x1000) & ~0xFFF
                    continue
                if not buf:
                    break
                f.write(buf)
                written += len(buf)
                pos += len(buf)
        write(f"dumped {written}B ({start:x}-{end:x}) -> {path}")
        ctx.end()

    handlers["DUMPREGION"] = op_dumpregion
