"""
This script reads input from a unified diff and filter its content
according to regular expressions passed in CLI.

For instance:

  git diff -U0 --no-color HEAD^ | bbp-diff-filter --files-re ".*\\.h"
"""
import logging
import os
import os.path as osp
import re
import sys

from cpplib import parse_cli, make_file_filter


DIFF_HEADER_PATTERNS = [
    re.compile(pattern)
    for pattern in ["^diff --git a/.* b/(.*)$", "^diff --git a/(.*)$"]
]


def main(**kwargs):
    description = sys.modules[__name__].__doc__
    args = parse_cli(description=description, **kwargs)
    excludes_re = [re.compile(r) for r in args.excludes_re or []]
    files_re = [re.compile(r) for r in args.files_re or []]
    filter_cpp_file = make_file_filter(excludes_re, files_re)
    try:
        line = input()
        while True:
            filename = None
            for pattern in DIFF_HEADER_PATTERNS:
                match = pattern.match(line)
                if match:
                    filename = match.group(1)
                    break
            if filename:
                file = osp.realpath(osp.join(args.source_dir, filename))
                if not filter_cpp_file(file):
                    print(line)
                    logging.info(line)
                    line = input()
                    while not line.startswith("diff --git"):
                        print(line)
                        line = input()
                    continue
            line = input()
    except EOFError:
        pass
    return True


if __name__ == '__main__':
    level = logging.INFO if 'VERBOSE' in os.environ else logging.WARN
    logging.basicConfig(level=level, format="%(message)s")
    sys.exit(0 if main() else 1)
