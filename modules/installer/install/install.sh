#!/usr/bin/env bash

if [ -d .venv ]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
else
  python -m venv .venv
  # shellcheck source=/dev/null
  source .venv/bin/activate

  python -m pip install --upgrade pip git+https://github.com/superna9999/pyamlboot pyroute2
fi

echo "this script calls sudo. please enter your password if asked."

sudo ./.venv/bin/python ./install.py "$@"
