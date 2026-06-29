#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 dist/LocalAIbundle-<version>.pkg" >&2
    exit 1
fi

PKG_PATH="$1"

if [[ ! -f "$PKG_PATH" ]]; then
    echo "package not found: $PKG_PATH" >&2
    exit 1
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$PKG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
else
    : "${APPLE_ID:?Set APPLE_ID or NOTARY_PROFILE}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARY_PROFILE}"
    : "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD or NOTARY_PROFILE}"

    xcrun notarytool submit "$PKG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
fi

xcrun stapler staple "$PKG_PATH"
spctl --assess --type install "$PKG_PATH"
pkgutil --check-signature "$PKG_PATH"
