# Changelog

## 1.1.1 - Unreleased

### Fixed

- Made release tarball packaging work on both macOS BSD tar and Linux GNU tar.
- Removed credential environment variable fallback from notarization helper to avoid secret-scanner false positives.

## 1.1.0

### Added

- Stable `bin/localaibundle` command wrapper for package managers.
- `doctor --json` and `status --json` machine-readable output.
- `self-test --no-network` release/package validation command.
- Homebrew formula template.
- Docker-based portable test scaffold.
- Native macOS `.pkg` packaging and notarization scripts.
- Public FAQ, privacy, troubleshooting, and packaging docs.
- Tag-triggered GitHub release workflow.

## 1.0.0

### Added

- macOS Apple Silicon installer for Ollama, coding models, VS Code, and Continue.dev.
- Hardware-aware model profiles.
- Diagnostics, repair mode, config validation, offline bundles, and install reports.
- Sandbox install test and CI validation.
