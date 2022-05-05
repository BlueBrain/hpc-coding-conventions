#! /usr/bin/env python3
import functools
import logging
import multiprocessing
import os
import re
import subprocess
import sys

from cpplib import collect_files, log_command, make_file_filter, parse_cli


def do_check(executable, compile_commands_file, options, cpp_file):
    cmd = [executable, "-p", compile_commands_file] + options + [cpp_file]
    log_command(cmd)
    if subprocess.call(cmd) == 0:
        return True
    logging.error(
        "\033[1;31merror:\033[0;0m"
        "clang-tidy detected error(s) in C++ file: "
        "\033[;1m%s\033[0;0m",
        cpp_file,
    )
    return False


def main(**kwargs):
    parser_args = [("-p", dict(dest="compile_commands_file", type=str))]
    args = parse_cli(parser_args=parser_args, choices=["check"], **kwargs)

    excludes_re = [re.compile(r) for r in args.excludes_re]
    files_re = [re.compile(r) for r in args.files_re]
    filter_cpp_file = make_file_filter(excludes_re, files_re)
    action = getattr(sys.modules[__name__], "do_" + args.action)
    workers = multiprocessing.Pool(processes=max(1, multiprocessing.cpu_count() - 2))
    if not os.path.exists(args.compile_commands_file):
        msg = (
            "Could not find file %s. Please make sure "
            + "CMAKE_EXPORT_COMPILE_COMMANDS CMake variable is on."
        )
        msg = msg % args.compile_commands_file
        logging.error(msg)
        raise Exception(msg)

    action = functools.partial(
        action, args.executable, args.compile_commands_file, args.options
    )
    succeeded = True
    for ok in workers.imap_unordered(
        action, collect_files(args.source_dir, filter_cpp_file)
    ):
        succeeded &= ok
    workers.close()
    workers.join()
    return succeeded


if __name__ == "__main__":
    level = logging.INFO if "VERBOSE" in os.environ else logging.WARN
    logging.basicConfig(level=level, format="%(message)s")
    sys.exit(0 if main() else 1)
