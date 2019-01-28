#! usr/bin/env python
import argparse
import contextlib
import filecmp
import functools
import json
import logging
import os
import os.path as osp
import re
import shlex
import subprocess
import sys
import tempfile


def _parse_cli(args=None):
    parser = argparse.ArgumentParser(description="Ensure C++ code formatting")
    parser.add_argument(
        "-S", dest="source_dir", metavar="PATH", help="Path to CMake source directory"
    )
    parser.add_argument(
        "-B", dest="binary_dir", metavar="PATH", help="Path to CMake binary directory"
    )
    parser.add_argument("--clang-format", help="Path to clang-format executable")
    parser.add_argument("--options", nargs="*", help="Options given to clang-format")
    parser.add_argument(
        "--excludes-re",
        nargs="*",
        help="list of regular expressions of C++ files to exclude",
    )
    parser.add_argument(
        "--files-re",
        nargs="*",
        help="List of regular expressions of C++ files to include",
    )
    parser.add_argument("compile_commands_file", type=str)
    parser.add_argument("action", choices=["check", "format"])
    return parser.parse_args(args=args)


def make_cpp_file_filter(source_dir, binary_dir, excludes_re, files_re):
    def _func(cpp_file):
        if not cpp_file.startswith(source_dir):
            return True
        if cpp_file.startswith(binary_dir):
            return True
        for exclude_re in excludes_re:
            if exclude_re.match(cpp_file):
                return True
        for file_re in files_re:
            if file_re.match(cpp_file):
                return False
        return True

    return _func


def collect_included_headers(entry, filter_cpp_file):
    cmd = shlex.split(entry["command"])
    try:
        # remove "-o object_file.o" from command
        opos = cmd.index("-o")
        cmd.pop(opos)
        cmd.pop(opos)
    except ValueError:
        pass
    cmd.insert(1, "-M")
    output = subprocess.check_output(cmd).decode("utf-8")
    headers = output.splitlines()[1:]
    for header in headers:
        if header[-1] == "\\":
            header = header[:-1]
        header = header.strip()
        if not filter_cpp_file(header):
            yield header


def collect_files(compile_commands, filter_cpp_file):
    files = set()
    with open(compile_commands) as istr:
        for entry in json.load(istr):
            cpp_file = osp.realpath(osp.join(entry["directory"], entry["file"]))
            if not filter_cpp_file(cpp_file):
                if cpp_file not in files:
                    yield cpp_file
                    files.add(cpp_file)
                    for header in collect_included_headers(entry, filter_cpp_file):
                        if header not in files:
                            yield header
                            files.add(header)


def log_command(cmd):
    logging.info(" ".join([shlex.quote(e) for e in cmd]))


def do_format(cpp_file, clang_format, options):
    cmd = [clang_format] + options
    if "-i" not in options:
        cmd.append("-i")
    cmd.append(cpp_file)
    log_command(cmd)
    return subprocess.call(cmd) == 0


def do_check(cpp_file, clang_format, options, tempfile=None):
    options = [opt for opt in options if opt != "-i"]
    cmd = [clang_format] + options
    cmd.append(cpp_file)
    with open(tempfile, "w") as ostr:
        log_command(cmd)
        subprocess.call(cmd, stdout=ostr)
    if not filecmp.cmp(cpp_file, tempfile):
        logging.error(
            "\033[1;31merror:\033[0;0m"
            "improper C/C++ file formatting: "
            "\033[;1m%s\033[0;0m",
            cpp_file,
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
    args = _parse_cli(**kwargs)
    excludes_re = [re.compile(r) for r in args.excludes_re]
    files_re = [re.compile(r) for r in args.files_re]
    filter_cpp_file = make_cpp_file_filter(
        args.source_dir, args.binary_dir, excludes_re, files_re
    )
    with build_action_func(args) as action:
        succeeded = True
        for cpp_file in collect_files(args.compile_commands_file, filter_cpp_file):
            succeeded &= action(cpp_file, args.clang_format, args.options)
    return succeeded


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARN, format="%(message)s")
    sys.exit(0 if main() else 1)
