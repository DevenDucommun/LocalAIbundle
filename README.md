# LocalAIbundle

[![CI](https://github.com/DevenDucommun/LocalAIbundle/actions/workflows/ci.yml/badge.svg)](https://github.com/DevenDucommun/LocalAIbundle/actions/workflows/ci.yml)

LocalAIbundle installs and maintains a fully local AI coding stack for macOS Apple Silicon. It sets up Ollama, coding models, VS Code, Continue.dev, diagnostics, repair tooling, and offline bundle support with no cloud accounts or API keys.

**Your code stays on your machine.**

## What It Provides

| Capability | Details |
|-----------|---------|
| Local inference | Ollama on `localhost:11434` with Apple Metal acceleration |
| IDE integration | VS Code + Continue.dev for chat, autocomplete, inline edits, and codebase context |
| Hardware-aware profiles | Automatically selects models by RAM, or accepts explicit profile/model overrides |
| Safe configuration | Backs up existing Continue config and VS Code settings before writing |
| Diagnostics | `doctor` checks Ollama, models, LaunchAgent, VS Code, Continue, config, and telemetry |
| Repair mode | `repair` fixes common stale or missing setup pieces |
| Offline workflow | `bundle` packages the repo and local Ollama model cache for air-gapped installs |
| Config validation | `validate-config` checks the generated Continue YAML shape and required roles |
| Install reports | Writes JSON reports under `~/.localaibundle/` for auditing and troubleshooting |
| CI coverage | Bash syntax, ShellCheck, whitespace checks, and unit tests run in GitHub Actions |

## Quick Start

### Prerequisites

- macOS on Apple Silicon (M1/M2/M3/M4)
- 16GB RAM minimum, 32GB+ recommended
- 20GB+ free disk space for the default profile
- Internet connection for the first model download

### Install

```bash
git clone https://github.com/DevenDucommun/LocalAIbundle.git
cd LocalAIbundle
chmod +x install.sh

# Preview without making changes
./install.sh --dry-run

# Install the default local coding stack
./install.sh install
```

### Verify

```bash
./install.sh doctor
./install.sh test
```

## Model Profiles

The default `auto` profile selects models by RAM. You can also choose a profile explicitly.

| Profile | Completion | Chat/Edit | Best For |
|---------|------------|-----------|----------|
| `auto` | RAM-based | RAM-based | Most users |
| `fast` | `qwen2.5-coder:1.5b` | `qwen2.5-coder:3b` | Lightweight laptops |
| `balanced` | `qwen2.5-coder:1.5b` | `qwen2.5-coder:7b` | 16GB machines |
| `professional` | `qwen2.5-coder:3b` | `qwen2.5-coder:14b` | Daily coding on 24GB+ |
| `agentic` | `qwen2.5-coder:3b` | `qwen3-coder:30b` | Larger coding tasks and long-context work |
| `max` | `qwen2.5-coder:7b` | `qwen2.5-coder:32b` | High-memory machines |

Automatic RAM tiers:

| RAM | Completion | Chat/Edit |
|-----|------------|-----------|
| 16-23GB | `qwen2.5-coder:1.5b` | `qwen2.5-coder:7b` |
| 24-47GB | `qwen2.5-coder:3b` | `qwen2.5-coder:14b` |
| 48GB+ | `qwen2.5-coder:7b` | `qwen2.5-coder:32b` |

Example overrides:

```bash
./install.sh install --profile agentic
./install.sh install --chat-model qwen3-coder:30b --completion-model qwen2.5-coder:3b
```

## Commands

```bash
./install.sh install        # Install and configure the full stack
./install.sh doctor         # Diagnose local setup without changing anything
./install.sh repair         # Fix common setup/configuration issues
./install.sh status         # Print component status
./install.sh test           # Run inference smoke tests
./install.sh validate-config # Validate Continue config for the selected profile
./install.sh bundle         # Create an offline bundle
./install.sh uninstall      # Remove LocalAIbundle components
./install.sh --help         # Show all commands and flags
```

Useful install modes:

```bash
./install.sh install --models-only
./install.sh install --config-only
./install.sh install --no-vscode
./install.sh install --no-continue
./install.sh install --no-launchagent
./install.sh install --no-model-pull
./install.sh uninstall --preserve-models
```

## Offline Installs

Create a bundle on a machine that already has the desired Ollama models:

```bash
./install.sh bundle --profile professional --output LocalAIbundle-offline-professional.tar.gz
```

Move the tarball to the offline Mac, then run:

```bash
./install.sh install --offline LocalAIbundle-offline-professional.tar.gz
```

The offline bundle includes the installer, docs, manifest, and local Ollama model cache when `~/.ollama/models` exists.

## How It Works

```text
VS Code + Continue.dev
  |  chat, edit, autocomplete, @codebase
  v
Ollama on localhost:11434
  |  local model files in ~/.ollama
  v
Apple Silicon / Metal GPU
```

Generated files:

| Path | Purpose |
|------|---------|
| `~/.continue/config.yaml` | Continue.dev local model configuration |
| `~/Library/LaunchAgents/com.localai.ollama.plist` | Ollama auto-start on login |
| `~/.localaibundle/install-report-*.json` | Install diagnostics and selected model report |
| `~/.continue/config.yaml.bak.*` | Timestamped backup of previous Continue config |

## Privacy

- Ollama inference runs locally.
- Continue is configured to use local Ollama models.
- Continue telemetry is disabled in VS Code settings.
- No API keys or cloud accounts are required.
- After the first install or an offline bundle import, the stack can run without internet.

## Development

Run the same checks as CI:

```bash
bash -n install.sh
shellcheck install.sh tests/run.sh tests/install-sandbox.sh scripts/package-release.sh scripts/demo.sh
python3 -m py_compile scripts/*.py
bash tests/run.sh
bash tests/install-sandbox.sh
bash scripts/package-release.sh
git diff --check
```

The unit test harness uses `LOCALAIBUNDLE_SOURCE_ONLY=true` plus `LOCALAIBUNDLE_TEST_*` hardware overrides so model selection and config generation can be tested on non-macOS CI runners without touching a real installation.

The sandbox install test creates a temporary `HOME` and fake `ollama`, `code`, `curl`, `brew`, and `launchctl` commands. It runs a non-dry-run install, doctor, and inference smoke test without modifying the developer machine.

Create release artifacts:

```bash
bash scripts/package-release.sh
```

This writes `dist/LocalAIbundle-<version>.tar.gz` and a matching `.sha256` checksum.

Record a terminal demo:

```bash
bash scripts/demo.sh
```

Manual macOS QA steps live in [docs/macos-qa.md](docs/macos-qa.md).

## Uninstall

```bash
./install.sh uninstall
```

Removes the user-local Ollama app, downloaded models, LocalAIbundle LaunchAgent, Continue.dev extension, and Continue config. It does not remove VS Code itself.
