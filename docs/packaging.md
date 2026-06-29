# Packaging

LocalAIbundle currently supports GitHub release tarballs and includes scaffolding for Homebrew and native macOS packages.

## Release Tarball

```bash
bash scripts/package-release.sh
```

Outputs:

- `dist/LocalAIbundle-<version>.tar.gz`
- `dist/LocalAIbundle-<version>.tar.gz.sha256`

The tarball is the canonical source artifact for GitHub releases and Homebrew tap packaging.

## Homebrew Tap

A formula template lives at:

```text
packaging/homebrew/localaibundle.rb
```

The formula should be copied into a personal tap such as `DevenDucommun/homebrew-localai` after the release tarball URL and SHA-256 are verified.

The formula must only install the `localaibundle` command. It should not run the full workstation setup during `brew install`.

## Native `.pkg`

Build an unsigned package locally on macOS:

```bash
bash scripts/package-pkg.sh
```

Build a signed package:

```bash
SIGN_IDENTITY="Developer ID Installer: Your Name (TEAMID)" bash scripts/package-pkg.sh
```

The package installs:

- `/usr/local/libexec/localaibundle`
- `/usr/local/bin/localaibundle`

It does not download models or run setup during package installation. Users still run:

```bash
localaibundle install
```

## Notarization

Store notarization credentials in Keychain:

```bash
xcrun notarytool store-credentials localaibundle-notary \
  --apple-id "you@example.com" \
  --team-id "TEAMID"
```

After signing, notarize and staple:

```bash
NOTARY_PROFILE=localaibundle-notary \
bash scripts/notarize-artifact.sh dist/LocalAIbundle-<version>.pkg
```

Verify:

```bash
spctl --assess --type install dist/LocalAIbundle-<version>.pkg
pkgutil --check-signature dist/LocalAIbundle-<version>.pkg
```

## DMG

Build a DMG containing the package installer:

```bash
bash scripts/package-dmg.sh
```

Outputs:

- `dist/LocalAIbundle-<version>.dmg`
- `dist/LocalAIbundle-<version>.dmg.sha256`

The DMG is a distribution container. The `.pkg` inside remains the actual installer. For public release, build the final signed and notarized `.pkg`, then build the DMG from that final package.

Verify the DMG:

```bash
hdiutil verify dist/LocalAIbundle-<version>.dmg
```

For the final public DMG, notarize and staple the DMG too:

```bash
NOTARY_PROFILE=localaibundle-notary \
bash scripts/notarize-artifact.sh dist/LocalAIbundle-<version>.dmg
```

## Docker Checks

Docker can validate Linux-portable checks:

```bash
docker build -f Dockerfile.test -t localaibundle-test .
docker run --rm localaibundle-test
```

Docker does not validate macOS LaunchAgents, VS Code app layout, Apple Silicon detection, signing, or notarization.
