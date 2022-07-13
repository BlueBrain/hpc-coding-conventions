from pathlib import Path
import re
import stat
import sys
import tempfile

sys.path.append(str(Path(__file__).resolve().parent.parent))

import cpp.lib  # noqa: E402


def test_where():
    """Test cpp.lib.where function"""
    with tempfile.TemporaryDirectory() as bin_dir:
        expected_paths = set()
        for name in [
            "clang-format",
            "clang-format-13",
            "clang-format-14",
            "clang-format-mp-13",
            "clang-format-mp-14",
            "clang-format-diff.py",
            "clang-format-mp-diff.py",
            "clang-format-14-diff.py",
        ]:
            Path(bin_dir, name).touch()
        for name in ["clang-format", "clang-format-13", "clang-format-mp-13"]:
            executable = Path(bin_dir, name)
            executable.chmod(executable.stat().st_mode | stat.S_IEXEC)
            expected_paths.add(str(executable))
        for name in [
            "clang-format-diff.py",
            "clang-format-mp-diff.py",
            "clang-format-14-diff.py",
        ]:
            executable = Path(bin_dir, name)
            executable.chmod(executable.stat().st_mode | stat.S_IEXEC)
        names_regex = cpp.lib.BBPProject.TOOLS_DESCRIPTION["ClangFormat"]["names_regex"]
        paths = set(
            cpp.lib.where(
                "clang-format", regex=re.compile(names_regex), paths=[bin_dir]
            )
        )
        assert paths == expected_paths
