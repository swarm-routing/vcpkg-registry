#!/usr/bin/env python3
# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
"""Run port_bump.py's --self-test, for coverage.py.

reusable-python-ci.yml runs each test script as `coverage run <script>`,
with no arguments; port_bump.py tests itself with `--self-test`. This runs
it in a child process, which coverage.py measures too (`patch =
subprocess`), so Codecov sees tools/ as the self-test exercises it
(swarm-routing/.github#635). registry.yml's `tools` job runs the same
self-test directly. Exits with the self-test's status.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    cmd = [sys.executable, os.path.join(HERE, "port_bump.py"), "--self-test"]
    return subprocess.run(cmd, cwd=os.path.dirname(HERE), check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
