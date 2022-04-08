#! /usr/bin/env python

import contextlib
import filecmp
import functools
import logging
import os
import re
import subprocess
import sys
import tempfile

from cpplib import collect_files, make_file_filter, log_command, parse_cli


def _build_excluded_dirs():
    eax = set(["CMakeTemp", "CMakeFiles", ".git", "HOME", "INSTALL"])
    actions = ["Start", "Configure", "Build", "Test", "Coverage", "MemCheck", "Submit"]
    prefixes = ["Continuous", "Nightly", "Experimental"]
    for prefix in prefixes:
        eax.add(prefix + ".dir")
        for action in actions:
            eax.add(prefix + action + ".dir")
    return eax


EXCLUDED_DIRS = _build_excluded_dirs()
del _build_excluded_dirs


EXCLUDED_FILES = set(
    [
        "cmake_install.cmake",
        "CMakeDirectoryInformation.cmake",
        "DependInfo.cmake",
        "cmake_clean.cmake",
        "CTestTestfile.cmake",
    ]
)

LOGGER = logging.Logger("bbp-cmake-format")


def do_format(cmake_file, cmake_format, options):
    cmd = [cmake_format] + options
    if "-i" not in options and "--in-place" not in options:
        cmd.append("-i")
    cmd.append(cmake_file)
    log_command(cmd)
    return subprocess.call(cmd) == 0


def do_check(cmake_file, cmake_format, options, tempfile=None):
    options = [opt for opt in options if opt not in ["-i", "--in-place"]]
    cmd = [cmake_format] + options
    cmd.append(cmake_file)
    log_command(cmd)
    with open(tempfile, "w") as ostr:
        subprocess.call(cmd, stdout=ostr)
    if not filecmp.cmp(cmake_file, tempfile):
        LOGGER.error(
            "\033[1;31merror:\033[0;0m "
            "improper CMake file formatting: "
            "\033[;1m%s\033[0;0m",
            cmake_file,
        )
        return False
    return True


@contextlib.contextmanager
def build_action_func(args):
    action = getattr(sys.modules[__name__], "do_" + args.action)
    try:
        if args.action == "check":
            fd, path = tempfile.mkstemp()
            os.close(fd)
            action = functools.partial(action, tempfile=path)
        yield action
    finally:
        if args.action == "check":
            os.remove(path)


def main(**kwargs):
    args = parse_cli(**kwargs)

    if not args.executable:
        args.executable = "cmake-format"

    excludes_re = [re.compile(r) for r in args.excludes_re]
    files_re = [re.compile(r) for r in args.files_re]
    with build_action_func(args) as action:
        succeeded = True
        for cmake_file in collect_files(args.source_dir, make_file_filter(excludes_re, files_re)):
            succeeded &= action(cmake_file, args.executable, args.options)
    return succeeded


if __name__ == "__main__":
    level = logging.INFO if 'VERBOSE' in os.environ else logging.WARN
    logging.basicConfig(level=level, format="%(message)s")
    sys.exit(0 if main() else 1)
