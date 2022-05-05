#!/usr/bin/env bash

set -euo pipefail

VENV=build/venv-python-format
BLACK_VERSION=22.3.0

if [[ ! -d $VENV ]]; then
    python3 -mvenv "$VENV"
    "$VENV/bin/pip" install black=="$BLACK_VERSION"
fi

set +u  # ignore errors in virtualenv's activate
source "$VENV/bin/activate"
set -u

black $@ cpp/cmake dev/bump

