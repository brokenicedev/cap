#!/usr/bin/env bash
# Imposta la versione di CAP e incrementa il numero di build (richiesto da Sparkle).
#
# Uso:
#   ./Scripts/bump-version.sh 0.2.0     # versione 0.2.0, build +1
#   ./Scripts/bump-version.sh           # stessa versione, solo build +1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT/CAP.xcodeproj/project.pbxproj"

current_version="$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' "$PBXPROJ" | head -1)"
current_build="$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/p' "$PBXPROJ" | head -1)"

new_version="${1:-$current_version}"
if [[ ! "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versione non valida: $new_version (formato atteso: X.Y.Z)" >&2
  exit 1
fi
new_build=$((current_build + 1))

sed -i '' \
  -e "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $new_version;/" \
  -e "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $new_build;/" \
  "$PBXPROJ"

echo "CAP $current_version ($current_build) → $new_version ($new_build)"
