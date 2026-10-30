#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Drive `runqemu nographic` over a pty: wait for login, run checks, power off.

Runs inside the kas build environment (runqemu on PATH). Standard library only.
Exit 0 only if the login prompt appeared and demod is active (running).
"""
import argparse
import os
import pty
import re
import select
import subprocess
import sys
import time

CHECKS = [
    "systemctl status demod --no-pager",
    "systemctl is-active demod",
    "zcat /proc/config.gz | grep SOFT_WATCHDOG",
    "uname -a",
]
PROMPT = re.compile(rb"root@qemuarm64:[^\n]*# ")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    master, slave = pty.openpty()
    proc = subprocess.Popen(
        ["runqemu", "qemuarm64", "nographic", "slirp"],
        stdin=slave, stdout=slave, stderr=slave, close_fds=True,
        start_new_session=True,
    )
    os.close(slave)

    buf = b""
    deadline = time.time() + args.timeout
    log = open(args.out, "wb")

    def read_until(pattern, start):
        nonlocal buf
        while time.time() < deadline:
            m = pattern.search(buf, start)
            if m:
                return m.end()
            r, _, _ = select.select([master], [], [], 1.0)
            if r:
                try:
                    data = os.read(master, 4096)
                except OSError:
                    return None
                if not data:
                    return None
                buf += data
                log.write(data)
                log.flush()
            elif proc.poll() is not None:
                return None
        return None

    def send(line):
        os.write(master, line.encode() + b"\n")

    ok_login = ok_daemon = False
    pos = read_until(re.compile(rb"qemuarm64 login: "), 0)
    if pos is not None:
        ok_login = True
        send("root")
        pos = read_until(PROMPT, pos)
        for cmd in CHECKS:
            if pos is None:
                break
            send(cmd)
            pos = read_until(PROMPT, pos)
        if pos is not None:
            # systemctl colours its output; strip ANSI escapes before matching
            plain = re.sub(rb"\x1b\[[0-9;?]*[A-Za-z]", b"", buf)
            ok_daemon = b"Active: active (running)" in plain
            send("poweroff")
            read_until(re.compile(rb"reboot: Power down|System halted"), pos)

    try:
        proc.wait(timeout=60)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, 9)
    log.close()

    print("BOOT_LOGIN_PROMPT=%s" % ("yes" if ok_login else "no"))
    print("BOOT_DEMOD_RUNNING=%s" % ("yes" if ok_daemon else "no"))
    return 0 if ok_login and ok_daemon else 1


if __name__ == "__main__":
    sys.exit(main())
