#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 dist/LocalAIbundle-<version>.pkg|dist/LocalAIbundle-<version>.dmg" >&2
    exit 1
fi

ARTIFACT_PATH="$1"

if [[ ! -f "$ARTIFACT_PATH" ]]; then
    echo "artifact not found: $ARTIFACT_PATH" >&2
    exit 1
fi

case "$ARTIFACT_PATH" in
    *.pkg) SPCTL_TYPE="install" ;;
    *.dmg) SPCTL_TYPE="open" ;;
    *)
        echo "unsupported artifact type: $ARTIFACT_PATH" >&2
        exit 1
        ;;
esac

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ARTIFACT_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
else
    : "${APPLE_ID:?Set APPLE_ID or NOTARY_PROFILE}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARY_PROFILE}"
    : "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD or NOTARY_PROFILE}"

    xcrun notarytool submit "$ARTIFACT_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
fi

xcrun stapler staple "$ARTIFACT_PATH"
spctl --assess --type "$SPCTL_TYPE" "$ARTIFACT_PATH"

if [[ "$ARTIFACT_PATH" == *.pkg ]]; then
    pkgutil --check-signature "$ARTIFACT_PATH"
elif [[ "$ARTIFACT_PATH" == *.dmg ]]; then
    hdiutil verify "$ARTIFACT_PATH"
fi
