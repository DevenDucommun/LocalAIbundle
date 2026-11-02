# Changelog

## 1.3.0 - Unreleased

### Changed

- Model refresh for 48GB+ machines: the `auto` POWER tier (48-95GB) now uses `qwen3.6:35b-a3b-coding`, a mixture-of-experts coding model, in place of the dense `qwen2.5-coder:32b`.
- `max` profile now uses `qwen3-coder-next` (80B MoE) and is selected automatically on 96GB+ machines.
- Download size estimates and disk preflight updated for the new tiers (~29GB power, ~57GB max).

### Added

- Explicit `power` profile (`--profile power`).
- Continue Agent mode: tool-capable chat models (`qwen3-coder`, `qwen3.6`, `devstral`, `gpt-oss`) get `capabilities: [tool_use]` in the generated config.

## 1.2.0 - 2026-06-29

### Added

- Disk-space preflight before model downloads.
- Network preflight warnings for first-install downloads.
- Model cache size reporting in status and doctor output.
- `issue-report` command for redacted troubleshooting bundles.
- `--preserve-config` uninstall flag.
- Model profile guide, manual setup comparison, and sample install report docs.

### Fixed

- Dry-run previews no longer fail on disk preflight or perform live network checks.
- Hardware detection falls back to the standard profile when RAM probing is restricted.
- Issue reports now collect best-effort diagnostics even when hardware detection is incomplete.

## 1.1.1

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
