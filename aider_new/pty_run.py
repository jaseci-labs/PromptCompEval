#!/usr/bin/env python3
"""
pty_run.py: Run a command inside a pseudo-terminal, send a task string when ready,
optionally wait for a completion marker, and then exit cleanly.

- Reads the task from --task-file and sends it followed by a newline.
- Waits for startup markers before sending the task (with a soft timeout/fallback).
- Optionally waits for a 'done' marker and then sends '/exit' to terminate.
- Streams all child output to stdout (so caller can redirect to a log file).

This avoids the "Input is not a terminal (fd=0)" warning and premature exits
by ensuring the child sees a TTY/PTY.
"""
from __future__ import annotations
import argparse
import os
import pty
import select
import sys
import time
import fcntl
import errno
import signal

START_MARKERS = [
    b"Genius Agent",
    b"Advanced AI-Powered Pair Programming",
    b"Using gpt-",
    b"Aider v",
]
DONE_MARKERS = [
    b"Genius Agent - Phase: Done",
]
CANCELLED_MARKERS = [
    b"Task input cancelled by user",
]


def set_nonblocking(fd: int) -> None:
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)


def now() -> float:
    return time.monotonic()


def contains_any(buf: bytes, needles: list[bytes]) -> bool:
    return any(n in buf for n in needles)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--task-file", required=True, help="Path to file containing task text")
    ap.add_argument("--startup-timeout", type=float, default=30.0, help="Seconds to wait for startup markers before sending the task anyway")
    ap.add_argument("--done-timeout", type=float, default=1800.0, help="Maximum seconds to wait for completion marker before sending exit")
    ap.add_argument("--grace-exit-wait", type=float, default=5.0, help="Seconds to wait after sending /exit")
    ap.add_argument("--send-exit-on-done", action="store_true", default=True, help="Send /exit once done marker is seen")
    ap.add_argument("--no-send-exit-on-done", dest="send_exit_on_done", action="store_false")
    ap.add_argument("--cwd", default=None, help="Working directory to exec the command in")
    # All remaining arguments after a standalone "--" are treated as the command to run
    ap.add_argument("cmd", nargs=argparse.REMAINDER, help="Command to run (place after --)")
    args = ap.parse_args()

    if not args.cmd:
        print("pty_run.py: No command provided after --", file=sys.stderr)
        return 2

    # Drop the leading '--' from cmd if present
    if args.cmd and args.cmd[0] == "--":
        cmd = args.cmd[1:]
    else:
        cmd = args.cmd

    if args.cwd:
        os.chdir(args.cwd)

    try:
        with open(args.task_file, "rb") as f:
            task = f.read().rstrip(b"\n")
    except Exception as e:
        print(f"pty_run.py: Failed to read task file: {e}", file=sys.stderr)
        return 1

    pid, master_fd = pty.fork()
    if pid == 0:
        # Child: exec the command with a real pty as stdio
        try:
            os.execvp(cmd[0], cmd)
        except Exception as e:
            print(f"pty_run.py (child): exec failed: {e}", file=sys.stderr)
            os._exit(127)

    # Parent
    set_nonblocking(master_fd)

    # Stream output and perform simple state machine
    sent_task = False
    seen_start = False
    seen_done = False
    sent_exit = False

    start_time = now()
    last_io = now()

    # Keep a sliding buffer for pattern matching (limit size to avoid memory bloat)
    match_buf = bytearray()
    MATCH_BUF_MAX = 64 * 1024

    # Helper to write to the child pty
    def write_child(data: bytes) -> None:
        nonlocal last_io
        total = 0
        while total < len(data):
            try:
                n = os.write(master_fd, data[total:])
                if n > 0:
                    total += n
                    last_io = now()
                else:
                    time.sleep(0.01)
            except OSError as e:
                if e.errno in (errno.EWOULDBLOCK, errno.EAGAIN):
                    time.sleep(0.01)
                    continue
                else:
                    break

    # Main loop
    try:
        while True:
            r, _, _ = select.select([master_fd], [], [], 0.2)
            if r:
                try:
                    data = os.read(master_fd, 8192)
                except OSError as e:
                    if e.errno in (errno.EIO,):  # EOF on pty
                        break
                    continue
                if not data:
                    break
                # Mirror to our stdout for logging by caller
                try:
                    sys.stdout.buffer.write(data)
                    sys.stdout.flush()
                except BrokenPipeError:
                    pass

                # Update buffers and match flags
                match_buf += data
                if len(match_buf) > MATCH_BUF_MAX:
                    del match_buf[: len(match_buf) - MATCH_BUF_MAX]

                if not seen_start and contains_any(match_buf, START_MARKERS):
                    seen_start = True
                if contains_any(match_buf, DONE_MARKERS):
                    seen_done = True
                if contains_any(match_buf, CANCELLED_MARKERS):
                    # If cancelled and we haven't tried sending the task yet, try once more
                    if not sent_task:
                        # fall through to resend below
                        pass

            now_t = now()

            # If not sent task: send after seeing start or after startup timeout
            if not sent_task and (seen_start or (now_t - start_time) > args.startup_timeout):
                write_child(task + b"\r")
                sent_task = True
                # Reset done detection after sending task
                match_buf.clear()

            # If done seen and configured to send exit, do it once
            if sent_task and seen_done and args.send_exit_on_done and not sent_exit:
                write_child(b"/exit\r")
                sent_exit = True

            # Bail out if we ran too long after sending task, try to exit gracefully
            if sent_task and (now_t - start_time) > args.done_timeout and not sent_exit:
                write_child(b"/exit\r")
                sent_exit = True

            # After sending exit, wait a small grace period then break
            if sent_exit and (now_t - last_io) > args.grace_exit_wait:
                break

            # Also check if child exited
            try:
                pid_ret, status = os.waitpid(pid, os.WNOHANG)
                if pid_ret == pid:
                    break
            except ChildProcessError:
                break
    finally:
        try:
            os.close(master_fd)
        except Exception:
            pass
        # Ensure child is reaped
        try:
            os.kill(pid, signal.SIGTERM)
        except Exception:
            pass
        try:
            os.waitpid(pid, os.WNOHANG)
        except Exception:
            pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
