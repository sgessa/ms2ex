#!/usr/bin/env python3
"""Memory daemon: launches a child process and serves memory-tool requests.

The daemon is the parent of the launched process, so yama ptrace_scope=1
allows it to read /proc/<pid>/mem without root.

Usage: memd.py <game-cmdline...>
Unix socket: /tmp/opencode/memd.sock   Log: /tmp/opencode/memd.log

Protocol (newline-terminated, one op per line):
  PID                          -> pid
  REGIONS                      -> one 'start-end perms' per line, END
  SCAN_INIT <file> <min> <max> -> kept count
  FIND <file> <value>          -> fresh scan for exact i64, kept count
  FILTER_DEC <file> <d|--any>  -> kept count + first hits
  FILTER_INC <file> <d|--any>
  FILTER_EQ <file> <value>     -> kept against fresh reads
  SHOW <file> [n]
  DUMP <hexaddr> <len>         -> hexdump lines
  RAW <hexaddr> <len>          -> hexlified bytes
Each reply block ends with END / ERR <msg>.
"""
import os
import re
import socket
import struct
import subprocess
import sys

sys.path.insert(0, "/tmp/opencode")
OPS_PATH = "/tmp/opencode/memd_ops.py"
_ops_mod = None
_ops_mtime = 0.0
_handlers = {}


def get_handlers():
    global _ops_mod, _ops_mtime, _handlers
    mt = os.path.getmtime(OPS_PATH)
    if _ops_mod is None or mt != _ops_mtime:
        import importlib

        if _ops_mod is None:
            _ops_mod = importlib.import_module("memd_ops")
        else:
            _ops_mod = importlib.reload(_ops_mod)
        _handlers = {}
        _ops_mod.register(_handlers)
        _ops_mtime = mt
    return _handlers


class Ctx:
    def __init__(self, mem, game_pid, end):
        self.mem = mem
        self.game_pid = game_pid
        self.end = end

SOCK = os.environ.get("MEMD_SOCK", "/tmp/opencode/memd.sock")
CHUNK = 1 << 26
PAIR = "<Qq"


def log(msg):
    with open("/tmp/opencode/memd.log", "a") as f:
        f.write(msg + "\n")


def spawn(cmd):
    env = dict(os.environ)
    env["WINEPREFIX"] = "/home/enki/Games/mushroom-launcher"
    env["WINEDEBUG"] = "-all"
    proc = subprocess.Popen(cmd, env=env)
    log(f"spawned {cmd} pid={proc.pid}")
    return proc


class Mem:
    def __init__(self, pid):
        self.pid = pid

    def regions(self):
        out = []
        with open(f"/proc/{self.pid}/maps") as f:
            for line in f:
                m = re.match(r"([0-9a-f]+)-([0-9a-f]+) (....) ", line)
                if not m:
                    continue
                start, end, perms = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
                if "r" not in perms or "w" not in perms:
                    continue
                parts = line.rstrip("\n").split(None, 5)
                name = parts[5] if len(parts) == 6 else ""
                if name and not name.startswith("["):
                    continue
                out.append((start, end))
        return out

    def read(self, addr, size):
        # prefer process_vm_readv: fast-fails on unmapped/guard pages
        import ctypes
        import errno

        buf = ctypes.create_string_buffer(size)
        class iovec(ctypes.Structure):
            _fields_ = [("iov_base", ctypes.c_void_p), ("iov_len", ctypes.c_size_t)]

        local = iovec(ctypes.cast(buf, ctypes.c_void_p), size)
        remote = iovec(ctypes.c_void_p(addr), size)
        libc = ctypes.CDLL("libc.so.6", use_errno=True)
        n = libc.process_vm_readv(
            ctypes.c_int(self.pid),
            ctypes.byref(local), 1,
            ctypes.byref(remote), 1,
            ctypes.c_ulong(0),
        )
        if n == size:
            return buf.raw
        if n >= 0:
            return buf.raw[:n]
        err = ctypes.get_errno()
        if err in (errno.EIO, errno.EFAULT, errno.ENOMEM):
            raise OSError(err, "unmapped")
        # fallback: /proc/pid/mem for anything else (e.g. EPERM scenarios)
        with open(f"/proc/{self.pid}/mem", "rb", 0) as f:
            f.seek(addr)
            data = f.read(size)
        if len(data) != size:
            raise OSError(errno.EIO, "short read")
        return data

    def qwords(self, start, end):
        pos = start
        tail = b""
        while pos < end:
            n = min(CHUNK, end - pos)
            try:
                buf = tail + self.read(pos, n)
            except OSError:
                return
            usable = len(buf) - len(buf) % 8
            base = pos - len(tail)
            for i in range(0, usable, 8):
                yield base + i, struct.unpack_from("<Q", buf, i)[0]
            tail = buf[usable:]
            pos += n


def load_pairs(path):
    if not os.path.exists(path):
        return []
    blob = open(path, "rb").read()
    return list(struct.iter_unpack(PAIR, blob[: len(blob) // 8 * 8]))


def save_pairs(path, pairs):
    with open(path, "wb") as f:
        for a, v in pairs:
            f.write(struct.pack(PAIR, a, v))


def signed(raw):
    return struct.unpack("<q", struct.pack("<Q", raw))[0]


def handle(mem, game_pid, line, write):
    parts = line.split()
    op = parts[0]

    def end(*lines):
        for l in lines:
            write(l)
        write("END")

    if op == "PID":
        end(str(game_pid))
    elif op == "REGIONS":
        regs = [f"{s:x}-{e:x}" for s, e in mem.regions()]
        end(*regs)
    elif op == "SCAN_INIT":
        path, lo, hi = parts[1], int(parts[2]), int(parts[3])
        kept = []
        for s, e in mem.regions():
            for addr, raw in mem.qwords(s, e):
                v = signed(raw)
                if lo <= v <= hi:
                    kept.append((addr, v))
        save_pairs(path, kept)
        end(str(len(kept)))
    elif op == "FIND":
        path, want = parts[1], int(parts[2])
        kept = []
        for s, e in mem.regions():
            for addr, raw in mem.qwords(s, e):
                if signed(raw) == want:
                    kept.append((addr, want))
        save_pairs(path, kept)
        end(str(len(kept)))
    elif op in ("FILTER_DEC", "FILTER_INC"):
        path = parts[1]
        delta = None if parts[2] == "--any" else int(parts[2])
        kept = []
        for addr, old in load_pairs(path):
            try:
                v = signed(struct.unpack("<Q", mem.read(addr, 8))[0])
            except (OSError, OverflowError):
                continue
            d = old - v
            if op == "FILTER_DEC" and (delta is None and d > 0 or d == delta):
                kept.append((addr, v))
            elif op == "FILTER_INC" and (delta is None and d < 0 or d == -delta):
                kept.append((addr, v))
        save_pairs(path, kept)
        lines = [str(len(kept))] + [f"0x{a:x} = {v}" for a, v in kept[:40]]
        end(*lines)
    elif op == "FILTER_EQ":
        path, want = parts[1], int(parts[2])
        kept = []
        for addr, _old in load_pairs(path):
            try:
                v = signed(struct.unpack("<Q", mem.read(addr, 8))[0])
            except (OSError, OverflowError):
                continue
            if v == want:
                kept.append((addr, v))
        save_pairs(path, kept)
        lines = [str(len(kept))] + [f"0x{a:x} = {v}" for a, v in kept[:40]]
        end(*lines)
    elif op == "SHOW":
        path = parts[1]
        pairs = load_pairs(path)
        n = int(parts[2]) if len(parts) > 2 else 60
        lines = [str(len(pairs))] + [f"0x{a:x} = {v}" for a, v in pairs[:n]]
        end(*lines)
    elif op == "DUMP":
        addr, length = int(parts[1], 16), int(parts[2])
        data = mem.read(addr, length)
        for off in range(0, len(data), 16):
            chunk = data[off : off + 16]
            hx = " ".join(f"{b:02x}" for b in chunk)
            asc = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
            write(f"0x{addr + off:x}  {hx:<47}  |{asc}|")
        end()
    elif op == "RAW":
        addr, length = int(parts[1], 16), int(parts[2])
        end(mem.read(addr, length).hex())
    else:
        handlers = get_handlers()
        if op in handlers:
            ctx = Ctx(mem, game_pid, end)
            handlers[op](ctx, parts, write)
        else:
            write(f"ERR unknown op {op}")


def main():
    cmd = sys.argv[1:]
    game = spawn(cmd)
    mem = None

    if os.path.exists(SOCK):
        os.unlink(SOCK)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK)
    srv.listen(4)
    log("listening")

    while True:
        conn, _ = srv.accept()
        with conn:
            f = conn.makefile("rw")
            try:
                line = f.readline().strip()
                log(f"req: {line}")
                if not line:
                    continue
                if mem is None:
                    mem = Mem(game.pid)
                handle(mem, game.pid, line, lambda s: (f.write(s + "\n"), f.flush()))
            except BrokenPipeError:
                pass
            except Exception as exc:
                try:
                    f.write(f"ERR {exc}\n")
                    f.write("END\n")
                    f.flush()
                except Exception:
                    pass
                log(f"error handling request: {exc!r}")


if __name__ == "__main__":
    main()
