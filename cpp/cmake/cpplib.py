import argparse
from collections import namedtuple
import configparser
import contextlib
from fnmatch import fnmatch
import functools
import logging
import os
import os.path as osp
import shlex
import subprocess
import sys
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


def make_cpp_file_filter(excludes_re, files_re):
    """
    Returns:
        a Python function used to filter the C++ files that needs to
        be formatted.
    """

    def _func(cpp_file):
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
        cmd = ["git", "diff", '--unified=0', "--no-color"]
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


def filter_files_outside_time_range(source_dir, applies_on, generator):
    """
    Generator that reads files from input generator, and exclude those
    that were not modified during the time interval specified in option
    `applies-on` CLI option.

    Args:
        source_dir: the source directory
        applies_on: where to apply the change
        generator: generator returning a list of files

    Returns:
        String generator
    """
    if applies_on == 'all':
        for file in generator:
            yield file
    else:
        with pushd(source_dir):
            delta = GitDiffDelta.from_applies_on(applies_on)
            modified_files = set(delta.diff_name_status())
        for file in generator:
            if osp.realpath(file) in modified_files:
                yield file


def collect_files(source_dir, filter_file):
    """
    Args:
        cli_args: parsed CLI options
        filter_file: a function returning `True` if the given file should be
        excluded, `False` otherwise.
    Returns:
        Generator of C++ files
    """

    cmd = ["git", "ls-tree", "-r", "-z", "--name-only", "--full-name", "HEAD", source_dir]
    log_command(cmd)
    files = subprocess.check_output(cmd).decode('utf-8').split('\0')

    files = [osp.join(source_dir, x) for x in files]
    files = [x for x in files if not filter_file(x)]
    return files


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


def merge_clang_tidy_checks(orig_checks, new_checks):
    """Merge 2 'Checks' ClangTidy configuration key values"""
    if orig_checks is None:
        return new_checks
    orig_checks = [check.strip() for check in orig_checks.split(",")]
    new_checks = [check.strip() for check in new_checks.split(",")]

    for new_check in new_checks:
        if new_check.startswith("-"):
            name = new_check[1:]
            # remove check when check=google-runtime-references to_=-google-*
            orig_checks = list(
                check for check in orig_checks if not fnmatch(check, name)
            )
            # remove check when check=-google-runtime-references to_=-google-* (simplification)
            orig_checks = list(
                check for check in orig_checks if not fnmatch(check, new_check)
            )
        else:
            # remove check when check=-google-runtime-references to_=google-*
            orig_checks = list(
                check for check in orig_checks if not fnmatch(check, "-" + new_check)
            )
            # remove check when check=google-runtime-references to_=google-* (simplification)
            orig_checks = list(
                check for check in orig_checks if not fnmatch(check, new_check)
            )
        orig_checks.append(new_check)
    return ",".join(orig_checks)


def do_merge_yaml(*files, **kwargs):
    """Merge YAML files. The last argument is the destination file
    """
    import yaml

    succeeded = True
    transformers = kwargs.get("transformers", {})
    out = files[-1]
    ins = files[:-1]

    outdated = not osp.exists(out) or osp.getmtime(out) < max(
        (osp.getmtime(f) for f in ins)
    )
    if outdated:
        data = {}
        for file in ins:
            with open(file) as istr:
                content = yaml.safe_load(istr)
                if not isinstance(content, dict):
                    logging.error("while reading YAML file %s: expected dictionary but got %s",
                                  file, type(content).__name__)
                    succeeded = False
                    continue

                for key, value in content.items():
                    transform_func = transformers.get(key)
                    if transform_func:
                        data[key] = transform_func(data.get(key), value)
                    else:
                        data[key] = value
        logging.info("writing file %s", out)
        if succeeded:
            with open(out, 'w') as ostr:
                yaml.dump(data, ostr, default_flow_style=False)
    else:
        logging.info("file %s is up to date, nothing to do.", out)
    return succeeded


def main(args=None):
    parser = argparse.ArgumentParser(description="Utility program")
    subparsers = parser.add_subparsers(help='sub-command help')
    merge_yaml = subparsers.add_parser('merge-yaml', help='Merge yaml files')
    merge_yaml.add_argument("files", nargs='+', help="input files then output file")
    merge_yaml.set_defaults(func=do_merge_yaml)

    merge_yaml = subparsers.add_parser(
        'merge-clang-tidy-config', help='Merge ClangTidy configuration files'
    )
    merge_yaml.add_argument("files", nargs='+', help="input files then output file")
    merge_yaml.set_defaults(
        func=functools.partial(
            do_merge_yaml, transformers=dict(Checks=merge_clang_tidy_checks)
        )
    )

    result = parser.parse_args(args=args)
    return result.func(*result.files)


if __name__ == '__main__':
    level = logging.INFO if 'VERBOSE' in os.environ else logging.WARN
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")
    sys.exit(0 if main() else 1)
