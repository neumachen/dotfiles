"""Make test subprocesses resolve `python3` to the interpreter running the tests.

The tool and tests/fake_defaults both start with `#!/usr/bin/env python3`, so
whichever `python3` comes first on PATH runs them. A caller whose PATH starts
with mise shims gets a shim, and a shim needs the caller's real HOME (to find
its config and installed versions). The tests replace HOME with a fixture
directory, so the shim fails or picks another Python. Pinning avoids both: a
directory holding a `python3` wrapper that `exec`s `sys.executable` goes in
front of PATH, so `env python3` always lands on the interpreter under test,
whatever the caller's PATH or HOME.
"""

import os
import shlex
import stat
import sys


def pinned_bin(parent):
    """Directory under `parent` whose python3/python run exactly sys.executable."""
    directory = os.path.join(parent, 'pinned-python')
    os.makedirs(directory, exist_ok=True)
    script = '#!/bin/sh\nexec %s "$@"\n' % shlex.quote(sys.executable)
    for name in ('python3', 'python'):
        path = os.path.join(directory, name)
        if not os.path.exists(path):
            with open(path, 'w') as handle:
                handle.write(script)
            os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return directory


def path_with_pinned(parent, base=None):
    """PATH with the pinned interpreter first, then `base` (default: the caller's PATH).

    Idempotent: if `base` already contains the pinned directory it is moved to the front.
    """
    base = os.environ.get('PATH', '/usr/bin:/bin') if base is None else base
    pinned = pinned_bin(parent)
    return os.pathsep.join([pinned] + [p for p in base.split(os.pathsep) if p != pinned])
