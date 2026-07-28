"""Keep this project's Python process on pinned deps, not external PYTHONPATH.

Safe for GSoC/other global dev setups: only the current process is adjusted.
Nothing outside this repo is modified.
"""

import os
import sys


def isolate_from_external_pythonpath():
    raw = os.environ.get('PYTHONPATH')
    if not raw:
        return

    external_paths = {
        os.path.normcase(os.path.abspath(path))
        for path in raw.split(os.pathsep)
        if path.strip()
    }
    if not external_paths:
        return

    sys.path[:] = [
        path for path in sys.path
        if os.path.normcase(os.path.abspath(path)) not in external_paths
    ]
    os.environ.pop('PYTHONPATH', None)
