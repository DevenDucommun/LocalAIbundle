#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(grep -E '^VERSION=' "$ROOT_DIR/install.sh" | head -1 | cut -d'"' -f2)
DIST_DIR="$ROOT_DIR/dist"
PKG_NAME="LocalAIbundle-${VERSION}"
PKG_PATH="$DIST_DIR/${PKG_NAME}.tar.gz"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$DIST_DIR"
rm -f "$PKG_PATH" "$PKG_PATH.sha256"
mkdir -p "$TMP_DIR/$PKG_NAME"

(
    cd "$ROOT_DIR"
    tar \
        --exclude='./.git' \
        --exclude='./dist' \
        --exclude='./*.tar.gz' \
        -cf - .
) | (
    cd "$TMP_DIR/$PKG_NAME"
    tar -xf -
)

tar -C "$TMP_DIR" -czf "$PKG_PATH" "$PKG_NAME"

if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$PKG_PATH" > "$PKG_PATH.sha256"
else
    sha256sum "$PKG_PATH" > "$PKG_PATH.sha256"
fi

printf 'Created %s\n' "$PKG_PATH"
printf 'Created %s\n' "$PKG_PATH.sha256"
