#!/usr/bin/env bash
# Genera (o rilegge) le chiavi EdDSA di Sparkle per CAP — una tantum.
#   Private key → Portachiavi macOS (account: cap) + backup in secrets/sparkle/ (gitignored)
#   Public key  → CAP/Info.plist (SUPublicEDKey), aggiornata automaticamente
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=Scripts/sparkle-tools.sh
source "$ROOT/Scripts/sparkle-tools.sh"

KEYS_DIR="$ROOT/secrets/sparkle"
mkdir -p "$KEYS_DIR"

GENERATE_KEYS="$(sparkle_tool generate_keys)"
echo "→ Uso $GENERATE_KEYS (account Portachiavi: $SPARKLE_ACCOUNT)"

# Crea la chiave se non esiste, altrimenti stampa quella esistente.
"$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT"

if [[ ! -f "$KEYS_DIR/ed25519-priv.key" ]]; then
  echo "→ Backup private key in $KEYS_DIR/ed25519-priv.key"
  "$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" -x "$KEYS_DIR/ed25519-priv.key"
  chmod 600 "$KEYS_DIR/ed25519-priv.key"
fi

PUB="$("$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" -p)"
printf '%s\n' "$PUB" >"$KEYS_DIR/ed25519-pub.txt"

/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $PUB" "$ROOT/CAP/Info.plist"
echo "→ SUPublicEDKey in CAP/Info.plist: $PUB"
echo
echo "Conserva una copia di secrets/sparkle/ed25519-priv.key in un posto sicuro:"
echo "senza questa chiave non potrai più pubblicare aggiornamenti per le installazioni esistenti."
