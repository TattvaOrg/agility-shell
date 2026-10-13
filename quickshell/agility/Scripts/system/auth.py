#!/usr/bin/env python3
import os
import shutil
import sys

def _exec_agl(subcmd, args):
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.abspath(os.path.join(here, "../../../../target/release/agl")),
        os.path.abspath(os.path.join(here, "../../../../target/debug/agl")),
        os.path.abspath(os.path.join(here, "../../../../../target/release/agl")),
        os.path.abspath(os.path.join(here, "../../../../../target/debug/agl")),
        "/usr/bin/agl",
        os.path.expanduser("~/.local/bin/agl"),
    ]
    which = shutil.which("agl")
    if which:
        candidates.append(which)

    for c in candidates:
        if os.path.isfile(c) and os.access(c, os.X_OK):
            try:
                with open(c, "rb") as f:
                    if f.read(4) == b"\x7fELF":
                        os.execv(c, [c, subcmd] + args)
            except Exception:
                pass
    sys.exit(1)

if __name__ == "__main__":
    _exec_agl("auth", sys.argv[1:])
