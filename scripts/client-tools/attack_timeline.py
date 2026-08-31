#!/usr/bin/env python3
"""Timed attack + fast memory timeline capture for the field monster HP bar.

The top-center bar (UIUpperHpBar) shows for the player's last target, so
hitting ANY monster arms it. This script times attack windows and records a
FAST region-scoped memory timeline so we can catch the bar instantiating on
the reference server (works) vs never on ms2ex (broken). Use a normal,
respawning mob as the subject.

The bar signal is the "UIUpperHPBar/" composite symbol, probed with BARPROBE2
on the region anchored via BARANCHOR (the swf-path region). Each probe is
region-scoped and fast (~sub-second), unlike a full-process sweep.

Rounds: idle baseline -> attack window -> fade. On the first probe where the
bar appears it dumps a ~4MB window around each hit (armed state) and, unless
--no-chain, probes the +0x3b8 link chain while the bar is live. The same
windows are dumped again when the bar fades so armed-vs-faded can be diffed.
If the bar never arms (ms2ex), only the timeline is produced.

The client MUST be running under memd:
  reference (bar works): scripts/client-tools/restart_ref_client.sh
  ms2ex      (no bar):   scripts/client-tools/restart_ms2ex_client.sh
Pick the daemon with MEMD_SOCK (ref = /tmp/opencode/memd.sock,
ms2ex = /tmp/opencode/memd_ms2ex.sock).

Attack input: prints timed cues by default (you attack with X, the basic
attack key, during the attack window). If xdotool is installed it can drive
the window itself: make sure the game is focused, then it holds X for the
attack window. Pass --no-auto to force manual cues.

If you SEE the bar in-game but the script reports never-armed, the anchored
region does not cover the bar's heap; capture the instance region with
probe_bar_chain.py / FIND2 and re-run with --extra-region LO-HI.

Usage:
  python3 attack_timeline.py [--rounds 3] [--baseline 3] [--attack 6]
      [--fade 8] [--pause 2] [--model NAME] [--extra-region LO-HI]
      [--no-chain] [--no-auto] [--out DIR]
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.abspath(__file__))
MEMC = os.path.join(REPO, "memc.py")
CHAIN = os.path.join(REPO, "probe_bar_chain.py")
SOCK = os.environ.get("MEMD_SOCK", "/tmp/opencode/memd.sock")
ENV = dict(os.environ, MEMD_SOCK=SOCK)

INTERVAL = 0.2
DUMP_HALF = 0x200000


def memc(*args, timeout=300):
    r = subprocess.run(
        [sys.executable, MEMC, *args],
        capture_output=True, text=True, timeout=timeout, env=ENV,
    )
    return r.stdout


def parse_probe(out):
    counts, addrs = {}, {}
    cur = None
    for line in out.splitlines():
        if line.startswith("  "):
            if cur is not None:
                try:
                    addrs.setdefault(cur, []).append(int(line.split()[0], 16))
                except (ValueError, IndexError):
                    pass
            continue
        if "=" in line:
            k, _, v = line.partition("=")
            counts[k.strip()] = int(v.strip())
            cur = k.strip()
    return counts, addrs


def probe(regions, model):
    """Probe every region; merge counts/addresses."""
    counts, addrs = {}, {}
    for lo, hi in regions:
        args = ["BARPROBE2", f"{lo:x}", f"{hi:x}"]
        if model:
            args.append(model)
        c, a = parse_probe(memc(*args))
        for k, v in c.items():
            counts[k] = counts.get(k, 0) + v
        for k, v in a.items():
            addrs.setdefault(k, []).extend(v)
    return counts, addrs


def dump_windows(addrs, label, stem, outdir):
    seen = []
    for a in addrs:
        if a in seen:
            continue
        seen.append(a)
        lo, hi = max(a - DUMP_HALF, 0), a + DUMP_HALF
        path = os.path.join(outdir, f"{stem}_{label}_{len(seen)}.bin")
        print(f"  dumping {label} window @0x{a:x} -> {path}", flush=True)
        memc("DUMPREGION", f"{lo:x}", f"{hi:x}", path)


def log(outdir, line):
    stamp = time.strftime("%H:%M:%S")
    with open(os.path.join(outdir, "timeline.log"), "a") as f:
        f.write(f"[{stamp}] {line}\n")
    print(f"[{stamp}] {line}", flush=True)


def cue(text, secs=3):
    for i in range(secs, 0, -1):
        print(f"    {text} in {i}...", flush=True)
        time.sleep(1)


def sample_loop(outdir, regions, model, deadline, phase, hit=None):
    """Sample until deadline; return (armed, windows). Call hit(state) on arm."""
    armed, windows = False, []
    while time.monotonic() < deadline:
        counts, addrs = probe(regions, model)
        log(outdir, f"phase={phase} upper_composite={counts.get('upper_composite', 0)} "
            f"upper_any={counts.get('upper_any', 0)} name_wide={counts.get('name_wide', 0)}")
        if counts.get("upper_composite", 0) > 0:
            if not armed and hit is not None:
                hit(addrs.get("upper_composite", []) + addrs.get("name_wide", []))
            armed = True
        time.sleep(INTERVAL)
    return armed


def main():
    ap = argparse.ArgumentParser(description="Timed attack + memory capture for the HP bar.")
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--baseline", type=float, default=3.0)
    ap.add_argument("--attack", type=float, default=6.0)
    ap.add_argument("--fade", type=float, default=8.0)
    ap.add_argument("--pause", type=float, default=2.0)
    ap.add_argument("--model", default="", help="mob model name (adds wide-string needle)")
    ap.add_argument("--extra-region", action="append", default=[],
                    help="additional LO-HI probe region (repeatable)")
    ap.add_argument("--no-chain", action="store_true", help="skip the +0x3b8 chain probe on arm")
    ap.add_argument("--no-auto", action="store_true", help="force manual cues even if xdotool exists")
    ap.add_argument("--out", default="/tmp/opencode/bar_timeline")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)

    try:
        pid = memc("PID", timeout=15).strip()
    except Exception as exc:
        print(f"memd not reachable on {SOCK}: {exc!r}")
        print("launch the client under memd first: "
              "scripts/client-tools/restart_ref_client.sh (reference) or "
              "restart_ms2ex_client.sh (ms2ex)")
        return 1
    print(f"memd OK, client pid {pid}", flush=True)

    xd = shutil.which("xdotool")
    auto = bool(xd) and not args.no_auto
    print(f"attack input: "
          f"{'xdotool (keep the game focused; it holds the X attack key)' if auto else 'manual cues (you attack with X during the window)'}",
          flush=True)

    log(args.out, f"== anchor: stand still, scanning for the UI region (~30s) ==")
    anchor = memc("BARANCHOR", timeout=180)
    if not anchor.startswith("0x") or "region=" not in anchor:
        print("BARANCHOR failed:", anchor)
        return 1
    addr = anchor.split()[0]
    region = next(t for t in anchor.split() if t.startswith("region=")).split("=")[1]
    lo, hi = (int(x, 16) for x in region.split("-"))
    print(f"anchored swf path at {addr}, region {region}", flush=True)

    regions = [(lo, hi)]
    for extra in args.extra_region:
        el, eh = (int(x, 16) for x in extra.split("-"))
        regions.append((el, eh))
        print(f"extra probe region {el:x}-{eh:x}", flush=True)

    log(args.out, f"== start rounds={args.rounds} baseline={args.baseline}s "
        f"attack={args.attack}s fade={args.fade}s model={args.model or '(none)'} "
        f"auto={auto} regions={len(regions)} ==")

    armed_total = 0
    for rnd in range(1, args.rounds + 1):
        log(args.out, f"-- ROUND {rnd} baseline (idle) --")
        sample_loop(args.out, regions, args.model,
                    time.monotonic() + args.baseline, "baseline")

        log(args.out, f"-- ROUND {rnd} attack window ({args.attack}s) --")
        if auto:
            assert xd is not None
            cue("POINT AT THE MOB", 3)
            subprocess.run([xd, "keydown", "x"], env=ENV)
        else:
            cue("ATTACK NOW: use X (basic attack) on the mob", 3)

        armed = False
        windows = []

        def on_arm(addrs):
            nonlocal armed, windows
            armed, windows = True, addrs
            log(args.out, f"ROUND {rnd}: BAR ARMED at hits "
                f"{[hex(a) for a in addrs[:6]]}")
            dump_windows(addrs, "arm", f"round{rnd:02d}", args.out)
            if not args.no_chain:
                print("    KEEP ATTACKING while we probe the chain...", flush=True)
                log(args.out, f"ROUND {rnd}: probing +0x3b8 chain (bar is live)...")
                cp = os.path.join(args.out, f"round{rnd:02d}_chain.txt")
                try:
                    co = subprocess.run(
                        [sys.executable, CHAIN], capture_output=True, text=True,
                        timeout=120, env=ENV,
                    ).stdout
                    with open(cp, "w") as f:
                        f.write(co)
                    print(f"  chain output -> {cp}", flush=True)
                except subprocess.TimeoutExpired:
                    print("  chain probe timed out (bar may have faded)", flush=True)

        sample_loop(args.out, regions, args.model,
                    time.monotonic() + args.attack, "attack", hit=on_arm)
        if auto:
            assert xd is not None
            subprocess.run([xd, "keyup", "x"], env=ENV)

        log(args.out, f"-- ROUND {rnd} fade ({args.fade}s, stop attacking) --")
        if not auto:
            print("    STOP ATTACKING", flush=True)
        saw = sample_loop(args.out, regions, args.model,
                          time.monotonic() + args.fade, "fade")
        if armed:
            dump_windows(windows, "fade", f"round{rnd:02d}", args.out)
        armed_total += int(armed)
        log(args.out, f"ROUND {rnd} result: {'ARMED' if armed else 'never armed'} "
            f"({armed_total}/{args.rounds} so far)")
        if rnd < args.rounds:
            time.sleep(args.pause)

    log(args.out, f"== done: bar armed in {armed_total}/{args.rounds} rounds ==\n")
    print(f"done -> {args.out}")
    print("diff the armed vs faded windows: roundNN_arm_*.bin vs roundNN_fade_*.bin")
    return 0


if __name__ == "__main__":
    sys.exit(main())