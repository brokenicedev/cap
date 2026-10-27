#!/usr/bin/env bash
# Build Release di CAP → firma Developer ID → notarizzazione → DMG → firma Sparkle → appcast.xml.
#
# Prerequisiti (una tantum):
#   brew install create-dmg
#   Certificato "Developer ID Application" del team (Xcode → Settings → Accounts → Manage Certificates)
#   Chiave Sparkle: ./Scripts/generate-sparkle-keys.sh
#   Credenziali notarizzazione salvate nel Portachiavi:
#     xcrun notarytool store-credentials cap-notary --apple-id <email> --team-id 9V7GQ329MP --password <app-specific>
#   gh auth login   (solo per --publish)
#
# Uso:
#   ./Scripts/bump-version.sh 0.2.0                         # prima: nuova versione + build
#   ./Scripts/release-dmg.sh --notes "Novità di questa versione"
#   ./Scripts/release-dmg.sh --notes-file notes.md --publish
#
#   # Oppure archive + notarizzazione da Xcode (Organizer → Distribute App → Direct Distribution → Export):
#   ./Scripts/release-dmg.sh --app ~/Desktop/CAP/CAP.app --notes "…" --publish
#
# Opzioni:
#   --notes "testo"      note di rilascio (appcast + GitHub Release)
#   --notes-file FILE    note di rilascio da file (Markdown/testo)
#   --publish            crea la GitHub Release vX.Y.Z con il DMG, poi commit + push di appcast.xml
#   --skip-notarize      solo per test locali: niente notarizzazione né appcast
#   --skip-build         riusa dist/CAP.app già presente
#   --app PATH           usa un CAP.app già notarizzato da Xcode (niente build né notarytool)
#
# Output:
#   dist/CAP.app
#   dist/CAP-<versione>.dmg
#   appcast.xml (nuovo <item> in cima)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=Scripts/sparkle-tools.sh
source "$ROOT/Scripts/sparkle-tools.sh"

PROJECT="$ROOT/CAP.xcodeproj"
SCHEME="CAP"
BUILD_DIR="$ROOT/build/release"
ARCHIVE_PATH="$BUILD_DIR/CAP.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DIST_DIR="$ROOT/dist"
APP_NAME="CAP.app"
APPCAST_PATH="$ROOT/appcast.xml"
GITHUB_REPO="brokenicedev/cap"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-cap-notary}"
SPARKLE_KEY_FILE="${SPARKLE_KEY_FILE:-$ROOT/secrets/sparkle/ed25519-priv.key}"

SKIP_BUILD=0
SKIP_NOTARIZE=0
XCODE_APP=""
PUBLISH=0
NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-notarize) SKIP_NOTARIZE=1 ;;
    --app) XCODE_APP="${2:?--app richiede il percorso di CAP.app}"; shift ;;
    --publish) PUBLISH=1 ;;
    --notes) NOTES="${2:?--notes richiede un testo}"; shift ;;
    --notes-file) NOTES="$(cat "${2:?--notes-file richiede un percorso}")"; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; exit 1 ;;
  esac
  shift
done

command -v create-dmg >/dev/null || { echo "create-dmg mancante: brew install create-dmg" >&2; exit 1; }
if [[ "$PUBLISH" -eq 1 ]]; then
  command -v gh >/dev/null || { echo "gh mancante: brew install gh && gh auth login" >&2; exit 1; }
  [[ "$SKIP_NOTARIZE" -eq 0 ]] || { echo "--publish richiede la notarizzazione." >&2; exit 1; }
fi

build_setting() {
  xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" -configuration Release 2>/dev/null \
    | awk -F' = ' -v key="$1" '$1 ~ "^ +"key"$" { print $2; exit }'
}

if [[ -n "$XCODE_APP" ]]; then
  XCODE_APP="${XCODE_APP%/}"
  [[ -d "$XCODE_APP" ]] || { echo "App non trovata: $XCODE_APP" >&2; exit 1; }
  if ! xcrun stapler validate "$XCODE_APP" >/dev/null 2>&1; then
    echo "$XCODE_APP non è notarizzata (manca il ticket)." >&2
    echo "In Xcode: Organizer → Distribute App → Direct Distribution, attendi la notarizzazione, poi Export." >&2
    exit 1
  fi
  mkdir -p "$DIST_DIR"
  if [[ "$(cd "$(dirname "$XCODE_APP")" && pwd)/$(basename "$XCODE_APP")" != "$DIST_DIR/$APP_NAME" ]]; then
    rm -rf "$DIST_DIR/$APP_NAME"
    ditto "$XCODE_APP" "$DIST_DIR/$APP_NAME"
  fi
  SKIP_BUILD=1
  VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$DIST_DIR/$APP_NAME/Contents/Info.plist")"
  BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$DIST_DIR/$APP_NAME/Contents/Info.plist")"
else
  VERSION="$(build_setting MARKETING_VERSION)"
  BUILD="$(build_setting CURRENT_PROJECT_VERSION)"
fi
TEAM_ID="$(build_setting DEVELOPMENT_TEAM)"
MIN_OS="$(build_setting MACOSX_DEPLOYMENT_TARGET)"
DMG_NAME="CAP-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
TAG="v${VERSION}"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${DMG_NAME}"
NOTES="${NOTES:-CAP ${VERSION}}"

if grep -q "<sparkle:version>${BUILD}</sparkle:version>" "$APPCAST_PATH"; then
  echo "La build $BUILD è già in appcast.xml. Esegui prima ./Scripts/bump-version.sh" >&2
  exit 1
fi

notarize() {
  local file="$1"
  echo "→ Notarizzazione di $(basename "$file") (può richiedere qualche minuto)"
  if [[ -n "${NOTARY_APPLE_ID:-}" ]]; then
    : "${NOTARY_PASSWORD:?Imposta NOTARY_PASSWORD (password specifica per app)}"
    xcrun notarytool submit "$file" --apple-id "$NOTARY_APPLE_ID" --team-id "$TEAM_ID" \
      --password "$NOTARY_PASSWORD" --wait
  else
    xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait
  fi
}

build_app() {
  echo "→ Archive Release"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR" "$DIST_DIR"
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates

  cat >"$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
EOF

  echo "→ Export firmato Developer ID (team $TEAM_ID)"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

  local app="$EXPORT_PATH/$APP_NAME"
  [[ -d "$app" ]] || { echo "App non trovata in $app" >&2; exit 1; }

  if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
    local zip="$BUILD_DIR/CAP-${VERSION}.zip"
    ditto -c -k --keepParent "$app" "$zip"
    notarize "$zip"
    xcrun stapler staple "$app"
  fi

  rm -rf "$DIST_DIR/$APP_NAME"
  ditto "$app" "$DIST_DIR/$APP_NAME"
}

make_dmg() {
  echo "→ Creazione $DMG_NAME"
  rm -f "$DMG_PATH" "$DIST_DIR"/rw.*.dmg
  # create-dmg scrive un'immagine temporanea accanto all'output: impacchetta una cartella separata.
  local stage="$BUILD_DIR/dmg-stage"
  rm -rf "$stage" && mkdir -p "$stage"
  ditto "$DIST_DIR/$APP_NAME" "$stage/$APP_NAME"

  local volicon=()
  if [[ -f "$DIST_DIR/$APP_NAME/Contents/Resources/AppIcon.icns" ]]; then
    volicon=(--volicon "$DIST_DIR/$APP_NAME/Contents/Resources/AppIcon.icns")
  fi

  create-dmg \
    --volname "CAP" \
    ${volicon[@]+"${volicon[@]}"} \
    --window-pos 200 120 \
    --window-size 600 380 \
    --icon-size 110 \
    --icon "$APP_NAME" 160 180 \
    --hide-extension "$APP_NAME" \
    --app-drop-link 440 180 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$stage/"
  rm -rf "$stage"

  if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
    local identity
    identity="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ && /'"$TEAM_ID"'/ { print $2; exit }')"
    if [[ -n "$identity" ]]; then
      echo "→ Firma DMG con \"$identity\""
      codesign --sign "$identity" --timestamp "$DMG_PATH"
    fi
    # Con --app l'app dentro il DMG è già notarizzata da Xcode: basta il DMG firmato.
    if [[ -z "$XCODE_APP" ]]; then
      notarize "$DMG_PATH"
      xcrun stapler staple "$DMG_PATH"
    fi
  fi
}

sparkle_sign() {
  local sign_update output
  sign_update="$(sparkle_tool sign_update)"
  if ! output="$("$sign_update" --account "$SPARKLE_ACCOUNT" "$DMG_PATH" 2>&1)"; then
    [[ -f "$SPARKLE_KEY_FILE" ]] || { echo "$output" >&2; exit 1; }
    output="$("$sign_update" --ed-key-file "$SPARKLE_KEY_FILE" "$DMG_PATH")"
  fi
  SPARKLE_LENGTH="$(sed -n 's/.*length="\([0-9]*\)".*/\1/p' <<<"$output" | head -1)"
  SPARKLE_SIGNATURE="$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' <<<"$output" | head -1)"
  [[ -n "$SPARKLE_LENGTH" && -n "$SPARKLE_SIGNATURE" ]] || { echo "Output di sign_update non riconosciuto: $output" >&2; exit 1; }
}

add_appcast_item() {
  echo "→ Aggiorno appcast.xml ($VERSION, build $BUILD)"
  python3 - "$APPCAST_PATH" "$VERSION" "$BUILD" "$MIN_OS" "$DOWNLOAD_URL" "$SPARKLE_LENGTH" "$SPARKLE_SIGNATURE" "$NOTES" "$GITHUB_REPO" "$TAG" <<'PY'
import html, sys
from email.utils import formatdate
path, version, build, min_os, url, length, signature, notes, repo, tag = sys.argv[1:11]
paragraphs = "".join(f"<p>{html.escape(p.strip())}</p>" for p in notes.split("\n\n") if p.strip())
item = f"""<!-- ITEMS -->
    <item>
      <title>{version}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{min_os}</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/{repo}/releases/tag/{tag}</sparkle:fullReleaseNotesLink>
      <description><![CDATA[{paragraphs}]]></description>
      <enclosure
        url="{url}"
        length="{length}"
        type="application/octet-stream"
        sparkle:edSignature="{signature}" />
    </item>"""
text = open(path, encoding="utf-8").read()
if "<!-- ITEMS -->" not in text:
    raise SystemExit("Marcatore <!-- ITEMS --> mancante in appcast.xml")
open(path, "w", encoding="utf-8").write(text.replace("<!-- ITEMS -->", item, 1))
PY
}

publish() {
  echo "→ GitHub Release $TAG"
  gh release create "$TAG" "$DMG_PATH" --repo "$GITHUB_REPO" --title "CAP $VERSION" --notes "$NOTES"

  echo "→ Pubblico appcast.xml"
  git -C "$ROOT" add appcast.xml CAP.xcodeproj/project.pbxproj
  git -C "$ROOT" commit -m "Release CAP $VERSION"
  git -C "$ROOT" push
}

echo "CAP $VERSION (build $BUILD)"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  build_app
else
  [[ -d "$DIST_DIR/$APP_NAME" ]] || { echo "Manca $DIST_DIR/$APP_NAME" >&2; exit 1; }
fi

make_dmg

if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  echo
  echo "Build di test (non notarizzata): appcast.xml non modificato."
  echo "  DMG: $DMG_PATH"
  exit 0
fi

sparkle_sign
add_appcast_item

if [[ "$PUBLISH" -eq 1 ]]; then
  publish
fi

echo
echo "Fatto."
echo "  DMG:     $DMG_PATH"
echo "  Appcast: $APPCAST_PATH"
if [[ "$PUBLISH" -eq 0 ]]; then
  echo
  echo "Per pubblicare (in quest'ordine):"
  echo "  1. gh release create $TAG \"$DMG_PATH\" --title \"CAP $VERSION\" --notes \"…\""
  echo "  2. git commit appcast.xml + push su main (gli utenti ricevono l'aggiornamento)"
fi
