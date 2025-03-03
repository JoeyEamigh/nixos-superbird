#!/usr/bin/env bash
set -eo pipefail

if [ -d .venv ]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
else
  python3 -m venv .venv
  # shellcheck source=/dev/null
  source .venv/bin/activate

  python3 -m pip install --upgrade pip git+https://github.com/superna9999/pyamlboot
fi

chmod 600 ./ssh/*
chmod +x ./scripts/*.sh

echo "this script calls sudo. please enter your password if asked."

sudo ./.venv/bin/python3 ./manual/manual.py "$@"
