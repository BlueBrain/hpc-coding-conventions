from pathlib import Path
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
        ]:
            Path(bin_dir, name).touch()
        for name in ["clang-format", "clang-format-13", "clang-format-mp-13"]:
            executable = Path(bin_dir, name)
            executable.chmod(executable.stat().st_mode | stat.S_IEXEC)
            expected_paths.add(str(executable))
        paths = set(
            cpp.lib.where(
                "clang-format", glob_patterns=["clang-format-*"], paths=[bin_dir]
            )
        )
        assert paths == expected_paths
