#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(grep -E '^VERSION=' "$ROOT_DIR/install.sh" | head -1 | cut -d'"' -f2)
DIST_DIR="$ROOT_DIR/dist"
PKG_PATH="$DIST_DIR/LocalAIbundle-${VERSION}.pkg"
DMG_PATH="$DIST_DIR/LocalAIbundle-${VERSION}.dmg"
VOL_NAME="LocalAIbundle ${VERSION}"
TMP_DIR=$(mktemp -d)
STAGE_DIR="$TMP_DIR/dmg"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v hdiutil >/dev/null 2>&1; then
    echo "hdiutil is required to build a DMG; run this on macOS." >&2
    exit 1
fi

mkdir -p "$DIST_DIR" "$STAGE_DIR"

if [[ ! -f "$PKG_PATH" ]]; then
    bash "$ROOT_DIR/scripts/package-pkg.sh"
fi

cp "$PKG_PATH" "$STAGE_DIR/"
[[ -f "$PKG_PATH.sha256" ]] && cp "$PKG_PATH.sha256" "$STAGE_DIR/"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"
cp "$ROOT_DIR/docs/packaging.md" "$STAGE_DIR/PACKAGING.md"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/LICENSE"

cat > "$STAGE_DIR/Install LocalAIbundle.command" << SCRIPT
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")"
open "LocalAIbundle-${VERSION}.pkg"
SCRIPT
chmod +x "$STAGE_DIR/Install LocalAIbundle.command"

find "$STAGE_DIR" -name '._*' -delete
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$STAGE_DIR" 2>/dev/null || true
fi

rm -f "$DMG_PATH" "$DMG_PATH.sha256"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if command -v shasum >/dev/null 2>&1; then
    (cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG_PATH")") > "$DMG_PATH.sha256"
else
    (cd "$DIST_DIR" && sha256sum "$(basename "$DMG_PATH")") > "$DMG_PATH.sha256"
fi

printf 'Created %s\n' "$DMG_PATH"
printf 'Created %s\n' "$DMG_PATH.sha256"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    printf 'DMG is unsigned. Notarize the final distribution artifact before public release.\n'
fi
