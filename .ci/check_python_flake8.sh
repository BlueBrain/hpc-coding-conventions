#!/usr/bin/env bash

set -euo pipefail

VENV=build/venv-python-flake8
FLAKE8_VERSION=4.0.1

if [[ ! -d $VENV ]]; then
    python3 -mvenv "$VENV"
    "$VENV/bin/pip" install flake8=="$FLAKE8_VERSION"
fi

set +u  # ignore errors in virtualenv's activate
source "$VENV/bin/activate"
set -u

flake8 cpp/cmake dev/bump cpp/formatting
