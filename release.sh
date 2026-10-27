#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/build-env.sh
source "$ROOT/Scripts/build-env.sh"

INSTALL_APP="/Applications/CAP.app"

echo "→ Building CAP (Release)…"
cap_xcodebuild Release

BUILT_APP="$(cap_app_path Release)"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: build output not found at $BUILT_APP" >&2
  exit 1
fi

echo "→ Stopping running CAP instances…"
cap_quit_all

echo "→ Installing to ${INSTALL_APP}…"
rm -rf "$INSTALL_APP"
ditto "$BUILT_APP" "$INSTALL_APP"

echo "→ Launching CAP…"
open "$INSTALL_APP"

echo "Done. Installed: $INSTALL_APP"
