#!/usr/bin/env bash
set -euo pipefail

bun run build
bun run fmt:check
bun run test
bash scripts/check-loc.sh
