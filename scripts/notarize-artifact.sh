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

: "${NOTARY_PROFILE:?Set NOTARY_PROFILE. Create one with: xcrun notarytool store-credentials localaibundle-notary}"

xcrun notarytool submit "$ARTIFACT_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$ARTIFACT_PATH"
spctl --assess --type "$SPCTL_TYPE" "$ARTIFACT_PATH"

if [[ "$ARTIFACT_PATH" == *.pkg ]]; then
    pkgutil --check-signature "$ARTIFACT_PATH"
elif [[ "$ARTIFACT_PATH" == *.dmg ]]; then
    hdiutil verify "$ARTIFACT_PATH"
fi
