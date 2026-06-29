#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(grep -E '^VERSION=' "$ROOT_DIR/install.sh" | head -1 | cut -d'"' -f2)
DIST_DIR="$ROOT_DIR/dist"
PKG_NAME="LocalAIbundle-${VERSION}"
PKG_PATH="$DIST_DIR/${PKG_NAME}.tar.gz"
MANIFEST_PATH="$DIST_DIR/${PKG_NAME}-manifest.json"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$DIST_DIR"
rm -f "$PKG_PATH" "$PKG_PATH.sha256" "$MANIFEST_PATH"
mkdir -p "$TMP_DIR/$PKG_NAME"

(
    cd "$ROOT_DIR"
    tar \
        --exclude='./.git' \
        --exclude='./dist' \
        --exclude='./docs/roadmap-local.md' \
        --exclude='./packaging/homebrew' \
        --exclude='./__pycache__' \
        --exclude='./*/__pycache__' \
        --exclude='./*.pyc' \
        --exclude='./*/*.pyc' \
        --exclude='./*.tgz' \
        --exclude='./*.tar.gz' \
        --exclude='./*.pkg' \
        --exclude='./*.dmg' \
        --exclude='./*.sha256' \
        -cf - .
) | (
    cd "$TMP_DIR/$PKG_NAME"
    tar -xf -
)

find "$TMP_DIR/$PKG_NAME" -exec touch -t 202001010000 {} +
if tar --version 2>/dev/null | grep -q 'GNU tar'; then
    tar \
        --format ustar \
        --sort=name \
        --mtime='2020-01-01 00:00Z' \
        --owner=0 \
        --group=0 \
        --numeric-owner \
        -C "$TMP_DIR" \
        -cf "$TMP_DIR/${PKG_NAME}.tar" \
        "$PKG_NAME"
else
    tar \
        --format ustar \
        --uid 0 \
        --gid 0 \
        --uname root \
        --gname wheel \
        -C "$TMP_DIR" \
        -cf "$TMP_DIR/${PKG_NAME}.tar" \
        "$PKG_NAME"
fi
gzip -n -c "$TMP_DIR/${PKG_NAME}.tar" > "$PKG_PATH"

if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$PKG_PATH" > "$PKG_PATH.sha256"
else
    sha256sum "$PKG_PATH" > "$PKG_PATH.sha256"
fi

SHA256=$(awk '{print $1}' "$PKG_PATH.sha256")
COMMIT=$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$MANIFEST_PATH" << JSON
{
  "name": "LocalAIbundle",
  "version": "$VERSION",
  "commit": "$COMMIT",
  "created": "$CREATED",
  "artifacts": [
    {
      "path": "dist/${PKG_NAME}.tar.gz",
      "sha256": "$SHA256"
    }
  ],
  "supported_platforms": [
    "macOS Apple Silicon"
  ]
}
JSON

printf 'Created %s\n' "$PKG_PATH"
printf 'Created %s\n' "$PKG_PATH.sha256"
printf 'Created %s\n' "$MANIFEST_PATH"
