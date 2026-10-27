# Shared paths and helpers for CAP shell builds (source from release.sh / dev.sh).
set -euo pipefail

CAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAP_PROJECT="$CAP_ROOT/CAP.xcodeproj"
CAP_SCHEME="CAP"
CAP_DERIVED_DATA="$CAP_ROOT/build/DerivedData"

cap_xcodebuild() {
  local config="$1"
  xcodebuild \
    -project "$CAP_PROJECT" \
    -scheme "$CAP_SCHEME" \
    -configuration "$config" \
    -derivedDataPath "$CAP_DERIVED_DATA" \
    build
}

cap_app_path() {
  local config="$1"
  echo "$CAP_DERIVED_DATA/Build/Products/$config/CAP.app"
}

# Quit release and debug instances (menu bar app may need killall fallback).
cap_quit_all() {
  osascript -e 'tell application "CAP Debug" to quit' 2>/dev/null || true
  osascript -e 'tell application "CAP" to quit' 2>/dev/null || true

  local waited=0
  while pgrep -xq CAP && [[ "$waited" -lt 40 ]]; do
    sleep 0.25
    waited=$((waited + 1))
  done

  if pgrep -xq CAP; then
    killall CAP 2>/dev/null || true
    sleep 0.5
  fi
}
