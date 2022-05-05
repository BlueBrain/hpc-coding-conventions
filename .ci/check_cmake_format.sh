#!/usr/bin/env bash

set -euo pipefail

VENV=build/venv-cmake-format
CMAKE_FORMAT_VERSION=0.6.13

if [[ ! -d $VENV ]]; then
    python3 -mvenv "$VENV"
    "$VENV/bin/pip" install cmake-format[YAML]=="$CMAKE_FORMAT_VERSION"
fi

set +u  # ignore errors in virtualenv's activate
source "$VENV/bin/activate"
set -u

action=${@:-format}

cpp/cmake/bbp-cmake-format.py -S . --files-re ".*\\.cmake$" ".*CMakeLists.txt$" -- $action
