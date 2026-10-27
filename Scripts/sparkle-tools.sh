# Helper condivisi per i tool da riga di comando di Sparkle (source da altri script).

SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-cap}"

# Trova un tool di Sparkle (generate_keys, sign_update, …) scaricato da Swift Package Manager.
sparkle_tool() {
  local name="$1"
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  local candidate
  for candidate in \
    "$root/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/$name" \
    $(find "$HOME/Library/Developer/Xcode/DerivedData"/CAP-*/SourcePackages/artifacts/sparkle/Sparkle/bin/"$name" -type f 2>/dev/null | head -1); do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  if [[ ! -d "$root/build/DerivedData/SourcePackages" ]]; then
    echo "→ Risolvo i pacchetti Swift (Sparkle)…" >&2
    xcodebuild -resolvePackageDependencies \
      -project "$root/CAP.xcodeproj" \
      -scheme CAP \
      -derivedDataPath "$root/build/DerivedData" >/dev/null
    if [[ -x "$root/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/$name" ]]; then
      echo "$root/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/$name"
      return 0
    fi
  fi

  echo "Tool Sparkle '$name' non trovato. Compila CAP una volta (./dev.sh) e riprova." >&2
  return 1
}
