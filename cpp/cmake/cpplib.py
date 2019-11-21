import argparse
from collections import namedtuple
import configparser
import contextlib
import json
import logging
import os
import os.path as osp
import shlex
import subprocess
import tempfile


def pipe_processes(*commands, **kwargs):
    """
    Execute given shell commands such that
    standard output of command N is given to standard input of command N + 1

    Args:
       commands: list of commands pipe and execute
        kwargs: additional options given to the `subprocess.Popen` constructor
                of the last process downstream.

    Returns:
        subprocess.Popen instance of the process downstream
    """
    log_command(*commands)
    prev_process = subprocess.Popen(commands[0], stdout=subprocess.PIPE)
    for cmd in commands[1:-1]:
        process = subprocess.Popen(
            cmd, stdin=prev_process.stdout, stdout=subprocess.PIPE
        )
        prev_process.stdout.close()
        prev_process = process
    return subprocess.Popen(commands[-1], stdin=prev_process.stdout, **kwargs)


@contextlib.contextmanager
def mkstemp(*args, **kwargs):
    """
    Create a temporary file within a Python context.
    File is removed when leaving the context

    Args:
        kwargs: additional argument given to `tempfile.mkstemp`
    Returns:
        path to create file
    """
    fd, path = tempfile.mkstemp(*args, **kwargs)
    os.close(fd)
    try:
        yield path
    finally:
        os.remove(path)


@contextlib.contextmanager
def pushd(dir):
    """Change working directory within a Python context"""
    cwd = os.getcwd()
    try:
        os.chdir(dir)
        yield dir
    finally:
        os.chdir(cwd)


def str2bool(v):
    """
    Convert a string meaning "yes" or "no" into a bool
    """
    if v.lower() in ("yes", "true", "t", "y", "1", "on"):
        return True
    elif v.lower() in ("no", "false", "f", "n", "0", "off"):
        return False
    else:
        raise argparse.ArgumentTypeError("Boolean value expected.")


def make_cpp_file_filter(source_dir, binary_dir, excludes_re, files_re):
    """
    Returns:
        a Python function used to filter the C++ files that needs to
        be formatted.
    """

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


def collect_submodules(source_dir):
    """Obtain a list of paths from `.gitmodules`

    Args:
        source_dir: The directory potentially containing `.gitmodules`
    Returns:
        A generator yielding the submodule paths
    """
    fn = osp.join(source_dir, ".gitmodules")
    cfg = configparser.ConfigParser()
    cfg.read(fn)
    for section in cfg.sections():
        value = cfg.get(section, "path", fallback=None)
        if value:
            yield osp.join(source_dir, value)


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
    lines = output.splitlines()[1:]
    for line in lines:
        if line[-1] == "\\":
            line = line[:-1]
        for header in line.split():
            if not filter_cpp_file(header):
                yield header


class GitDiffDelta(namedtuple("GitDiffDelta", ["from_", "to", "staged"])):
    """
    A set of changes, either:
    - the working area
    - the staging area
    - a range of revisions
    """

    def __str__(self):
        if self.from_ is None and self.to is None:
            if self.staged:
                return "git staging area"
            return "git working area"
        else:
            return "{}:{}".format(self.from_ or "", self.to or "")

    @property
    def diff_command(self):
        cmd = ["git", "diff", '-U0', "--no-color"]
        if self.staged:
            cmd.append("--cached")
        if self.from_:
            cmd.append(self.from_)
        if self.to:
            cmd.append(self.to)
        return cmd

    @classmethod
    def fork_point(cls, ref):
        fork_point_cmd = ['git', 'merge-base', '--fork-point', ref, 'HEAD']
        log_command(fork_point_cmd)
        return subprocess.check_output(fork_point_cmd).decode('utf-8').strip()

    @classmethod
    def from_applies_on(cls, applies_on):
        if applies_on == 'working':
            return GitDiffDelta(from_=None, to=None, staged=False)
        if applies_on == 'staging':
            return GitDiffDelta(from_=None, to=None, staged=True)
        elif applies_on.startswith('since-rev'):
            git_rev = applies_on[len('since-rev:') :]
            return GitDiffDelta(from_=git_rev, to='HEAD', staged=False)
        elif applies_on.startswith('since-ref:'):
            git_ref = applies_on[len('since-ref:') :]
            git_rev = cls.fork_point(git_ref)
            return GitDiffDelta(from_=git_rev, to='HEAD', staged=False)
        elif applies_on == 'base-branch':
            git_ref = os.environ.get('CHANGE_BRANCH')
            if git_ref is None:
                msg = 'Expecting environment variable CHANGE_BRANCH. '
                msg += 'This command may be executed within Jenkins'
                logging.error(msg)
                raise Exception(msg)
            git_rev = cls.fork_point(git_ref)
            return GitDiffDelta(from_=git_rev, to='HEAD', staged=False)
        elif applies_on == 'all':
            raise Exception('GitDiffDelta does not apply to option applies-on=all')
        else:
            msg = 'Unknown applies-on argument: ' + applies_on
            logging.error(msg)
            raise Exception(msg)

    def diff_name_status(self):
        """A generator providing the list of added and modified files

        Args:
            git_dir: root repository directory (containing .git/)
            delta(GitDiffDelta): interval of changes to look into
            git: path to git executable (look into PATH if `None`)
        """
        git_diff_cmd = ['git', 'diff', '--name-status']
        if self.staged:
            git_diff_cmd.append('--cached')
        if self.from_:
            git_diff_cmd.append(self.from_)
        if self.to:
            git_diff_cmd.append(self.to)
        log_command(git_diff_cmd)
        for line in subprocess.check_output(git_diff_cmd).decode('utf-8').splitlines():
            status, file = line.split('\t', 1)
            if status[0] in ['A', 'M']:
                yield osp.abspath(file.lstrip('\t'))


def filter_files_outside_time_range(cli_args, generator):
    """
    Generator that reads files from input generator, and exclude those
    that were not modified during the time interval specified in option
    `applies-on` CLI option.

    Args:
        cli_args: parsed CLI options
        generator: generator returning a list of files

    Returns:
        String generator
    """
    if cli_args.applies_on == 'all':
        for file in generator:
            yield file
    else:
        with pushd(cli_args.source_dir):
            delta = GitDiffDelta.from_applies_on(cli_args.applies_on)
            modified_files = set(delta.diff_name_status())
        for file in generator:
            if osp.realpath(file) in modified_files:
                yield file


def collect_files(compile_commands, filter_cpp_file):
    """
    Args:
        compile_commands: path to compile_commands.json JSON compilation database
        filter_cpp_file: a function returning `True` if the given file should be
        excluded, `False` otherwise.
    Returns:
        Generator of C++ files
    """
    files = set()
    if not osp.exists(compile_commands):
        msg = (
            'Could not find file %s. Please make sure '
            + 'CMAKE_EXPORT_COMPILE_COMMANDS CMake variable is on.'
        )
        msg = msg % compile_commands
        logging.error(msg)
        raise Exception(msg)

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


def parse_cli(
    compile_commands=True, choices=None, description=None, parser_args=None, args=None
):
    choices = choices or ["check", "format"]
    parser = argparse.ArgumentParser(
        description=description or "Wrapper for checker utility"
    )
    parser.add_argument(
        "-S", dest="source_dir", metavar="PATH", help="Path to CMake source directory"
    )
    parser.add_argument(
        "-B", dest="binary_dir", metavar="PATH", help="Path to CMake binary directory"
    )
    parser.add_argument("--executable", help="Path to executable to run")
    parser.add_argument(
        "--excludes-re",
        nargs="*",
        default=[],
        help="list of regular expressions of files to exclude",
    )
    parser.add_argument(
        "--files-re", nargs="*", help="List of regular expressions of files to include"
    )
    parser.add_argument(
        "--git-modules",
        action="store_true",
        help="Parse .gitmodules of the project to exclude external projects",
    )
    parser.add_argument(
        "--make-unescape-re",
        action="store_true",
        help="Unescape make-escaped regular-expression arguments",
    )
    parser.add_argument(
        "--git-executable", default='git', help="Path to git executable"
    )
    parser.add_argument(
        '--applies-on', help="Specify changeset where formatting applies"
    )

    for name, kwargs in parser_args or []:
        parser.add_argument(name, **kwargs)
    if compile_commands:
        parser.add_argument("-p", dest="compile_commands_file", type=str)
    parser.add_argument("--action", choices=choices)
    parser.add_argument("options", nargs="*", help="Options given to executable")
    result = parser.parse_args(args=args)
    if result.git_modules:
        result.excludes_re.extend(collect_submodules(result.source_dir))
    if result.make_unescape_re:

        def make_unescape_re(pattern):
            if pattern.endswith('$$'):
                pattern = pattern[:-1]
            pattern = pattern.replace('\\\\', '\\')
            return pattern

        def make_unescape_res(patterns):
            return [make_unescape_re(pattern) for pattern in patterns]

        result.files_re = make_unescape_res(result.files_re)
        result.excludes_re = make_unescape_res(result.excludes_re)
    if result.applies_on:
        result.applies_on = result.applies_on.lower()
    result.options = [opt for opt in result.options if opt]
    return result


def log_command(*commands):
    if len(commands) == 1:
        logging.info(" ".join([shlex.quote(e) for e in commands[0]]))
    else:
        logging.info("    " + " |\n    ".join([" ".join(cmd) for cmd in commands]))
