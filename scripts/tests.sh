#!/usr/bin/env bash
set -euo pipefail

run_npm() {
  if command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /C npm.cmd "$@"
  else
    npm "$@"
  fi
}

run_npm test
