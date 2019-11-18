#! usr/bin/env python
import contextlib
import filecmp
import functools
import itertools
import logging
import os
import os.path as osp
import re
import shutil
import subprocess
import sys
import tempfile

from cpplib import (
    collect_files,
    filter_files_outside_time_range,
    GitDiffDelta,
    log_command,
    make_cpp_file_filter,
    parse_cli,
    pipe_processes,
    pushd,
    str2bool,
)


def file_filters_cli_options(args):
    """
    Rebuild file filtering command line arguments from the parsed values

    Args:
      args: parsed CLI arguments

    Returns:
      list of raw CLI options
    """
    result = ["-S", args.source_dir, "-B", args.binary_dir]
    if args.git_modules:
        result.append('--git-modules')
    for re_opt, patterns in [
        ("--files-re", args.files_re),
        ("--excludes-re", args.excludes_re),
    ]:
        result += list(itertools.chain(*list(itertools.product([re_opt], patterns))))
    return result


def diff_filters_command(args):
    """
    Args:
      args: parsed CLI arguments

    Returns:
      Command to execute the bbp-diff-filters.py according to the file filters given to
      this current program
    """
    return [
        sys.executable,
        osp.join(osp.dirname(__file__), 'bbp-diff-filter.py'),
    ] + file_filters_cli_options(args)


def clang_format_diff_command(args, apply_changes=True):
    """
    Args:
        args: parsed CLI arguments
        apply_changes: whether clang-format-diff should apply the changes
        on the codebase or simply output the formatted diff

    Returns:
        Command to execute clang-format-diff
    """
    command = [
        args.clang_format_diff_executable,
        "-sort-includes",
        "-binary",
        args.executable,
        "-p1",
    ]
    if logging.root.level >= logging.INFO:
        command.append("--verbose")
    if apply_changes:
        command.append("-i")
    return command


def compare_diffs(delta, patch, formatted_patch):
    """
    Compare the 2 given diff files, and print the differences to standard output
    with `interdiff` utility (from package patchtutil).

    Args:
        delta(GitDiffDelta): a set of git changes
        patch: path to diff file of unformatted changes
        formatted_patch: path to diff file of changes formatted
        with clang-format-diff utility

    Returns:
        True if files are identical, False otherwise
    """
    same = filecmp.cmp(patch, formatted_patch)
    if not same:
        logging.error(
            "\033[1;31merror:\033[0;0m" "improper C/C++ files formatting of %s.", delta
        )
    interdiff = shutil.which("interdiff")
    if interdiff:
        subprocess.check_call([interdiff, '-U0', patch, formatted_patch])
    else:
        logging.warn("Can not find 'interdiff' executable")
        logging.warn("Please install 'patchutil' package to display differences.")
    return same


def do_partial_format(delta, args, apply_changes=True):
    """
    Format the modified chunks of the C/C++ files touched by the specified set of changes

    Args:
         delta(GitDiffDelta): a set of git changes
         args: parsed CLI arguments
         apply_changes: whether clang-format-diff should apply the changes
        on the codebase or simply output the formatted diff
    """
    with pushd(args.source_dir):
        commands = [
            delta.diff_command,
            diff_filters_command(args),
            clang_format_diff_command(args, apply_changes=apply_changes),
        ]
        process = pipe_processes(*commands)
        return_code = process.wait()

    if return_code != 0:
        raise Exception("Error occurred while formatting changes")
    return return_code == 0


def do_partial_check(delta, args, tempfile=None):
    """
    Ensure that the modified chunks of the C/C++ files touched by the specified
    set of changes are properly formatted.

    Args:
         delta(GitDiffDelta): a set of git changes
         args: parsed CLI arguments
         tempfile: path to a temporary file previously created
    """
    with pushd(args.source_dir):
        # generate diff of specified git changes
        with open(tempfile, 'w') as ostr:
            proc = pipe_processes(
                delta.diff_command, diff_filters_command(args), stdout=ostr
            )
            exit_status = proc.wait()
            if exit_status != 0:
                raise Exception(
                    'Error occurred while executing command: %s', exit_status
                )
        formatted_file = tempfile + '.format'
        with open(tempfile) as istr, open(formatted_file, 'w') as ostr:
            # format the diff
            command = clang_format_diff_command(args, apply_changes=False)
            log_command(command)
            subprocess.check_call(command, stdin=istr, stdout=ostr)
    same = compare_diffs(delta, tempfile, formatted_file)
    os.remove(formatted_file)
    return same


def do_full_format(cpp_file, clang_format, options):
    """
    Format all the C/C++ files of the project
    """
    cmd = [clang_format] + options
    if "-i" not in options:
        cmd.append("-i")
    cmd.append(cpp_file)
    log_command(cmd)
    return subprocess.call(cmd) == 0


def do_full_check(cpp_file, clang_format, options, tempfile=None):
    """
    Ensure that all the C/C++ files of the project are properly formatted
    """
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
    if args.changes_only and args.applies_on != 'all':
        action = getattr(sys.modules[__name__], "do_partial_" + args.action)
    else:
        action = getattr(sys.modules[__name__], "do_full_" + args.action)
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
    parser_args = [
        ("--clang-format-diff-executable", dict(help="Path to clang-format-diff")),
        (
            "--changes-only",
            dict(
                type=str2bool,
                help="Only format modified chunks, not the entire files",
                const=True,
                default=False,
                nargs="?",
            ),
        ),
    ]
    args = parse_cli(parser_args=parser_args, **kwargs)
    excludes_re = [re.compile(r) for r in args.excludes_re]
    files_re = [re.compile(r) for r in args.files_re]
    filter_cpp_file = make_cpp_file_filter(
        args.source_dir, args.binary_dir, excludes_re, files_re
    )
    with build_action_func(args) as action:
        succeeded = True
        if args.changes_only and args.applies_on != 'all':
            succeeded = action(GitDiffDelta.from_applies_on(args.applies_on), args)
        else:
            for cpp_file in filter_files_outside_time_range(
                args, collect_files(args.compile_commands_file, filter_cpp_file)
            ):
                succeeded &= action(cpp_file, args.executable, args.options)
    return succeeded


if __name__ == "__main__":
    level = logging.INFO if 'VERBOSE' in os.environ else logging.WARN
    logging.basicConfig(level=level, format="%(message)s")
    sys.exit(0 if main() else 1)
