#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(grep -E '^VERSION=' "$ROOT_DIR/install.sh" | head -1 | cut -d'"' -f2)
DIST_DIR="$ROOT_DIR/dist"
PKG_ID="com.devenducommun.localaibundle"
PKG_NAME="LocalAIbundle-${VERSION}.pkg"
PKG_PATH="$DIST_DIR/$PKG_NAME"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

PAYLOAD="$TMP_DIR/payload"
INSTALL_ROOT="$PAYLOAD/usr/local/libexec/localaibundle"
BIN_DIR="$PAYLOAD/usr/local/bin"

mkdir -p "$INSTALL_ROOT" "$BIN_DIR" "$DIST_DIR"

(
    cd "$ROOT_DIR"
    tar \
        --exclude='./.git' \
        --exclude='./dist' \
        --exclude='./docs/roadmap-local.md' \
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
    cd "$INSTALL_ROOT"
    tar -xf -
)

ln -sf ../libexec/localaibundle/bin/localaibundle "$BIN_DIR/localaibundle"
chmod +x "$INSTALL_ROOT/install.sh" "$INSTALL_ROOT/bin/localaibundle"
find "$PAYLOAD" -name '._*' -delete
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$PAYLOAD" 2>/dev/null || true
fi

rm -f "$PKG_PATH" "$PKG_PATH.sha256"

PKGBUILD_ARGS=(
    --root "$PAYLOAD"
    --identifier "$PKG_ID"
    --version "$VERSION"
    --install-location /
    --filter '(^|/)\._'
    --filter '(^|/)\.DS_Store$'
    --filter '(^|/)__pycache__($|/)'
    --filter '\.pyc$'
)

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    PKGBUILD_ARGS+=(--sign "$SIGN_IDENTITY")
fi

pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_PATH"

if command -v shasum >/dev/null 2>&1; then
    (cd "$DIST_DIR" && shasum -a 256 "$(basename "$PKG_PATH")") > "$PKG_PATH.sha256"
else
    (cd "$DIST_DIR" && sha256sum "$(basename "$PKG_PATH")") > "$PKG_PATH.sha256"
fi

printf 'Created %s\n' "$PKG_PATH"
printf 'Created %s\n' "$PKG_PATH.sha256"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    printf 'Package is unsigned. Set SIGN_IDENTITY to a Developer ID Installer identity for signed builds.\n'
fi
