#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/build-env.sh
source "$ROOT/Scripts/build-env.sh"

echo "→ Stopping running CAP instances…"
cap_quit_all

echo "→ Building CAP (Debug)…"
cap_xcodebuild Debug

BUILT_APP="$(cap_app_path Debug)"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: build output not found at $BUILT_APP" >&2
  exit 1
fi

echo "→ Launching CAP Debug…"
open "$BUILT_APP"

echo "Done. Running: $BUILT_APP"
