import argparse
from fnmatch import fnmatch
import functools
import logging
import os
import shlex
import subprocess
import sys


def make_file_filter(excludes_re, files_re):
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
    files = [x for x in files if not filter_file(x)]
    files = [os.path.join(source_dir, x) for x in files]
    return files


def parse_cli(
    choices=None, description=None, parser_args=None, args=None
):
    choices = choices or ["check", "format"]
    parser = argparse.ArgumentParser(
        description=description or "Wrapper for checker utility"
    )
    parser.add_argument(
        "-S", dest="source_dir", metavar="PATH", help="Path to CMake source directory"
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

    for name, kwargs in parser_args or []:
        parser.add_argument(name, **kwargs)
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

    outdated = not os.path.exists(out) or os.path.getmtime(out) < max(
        (os.path.getmtime(f) for f in ins)
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
