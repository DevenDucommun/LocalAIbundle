# macOS Manual QA Checklist

Use this checklist before cutting a release. CI validates shell behavior, but these checks cover the macOS pieces that need a real Apple Silicon host.

## Clean Install

- Start on macOS Apple Silicon with 16GB+ RAM.
- Run `./install.sh --dry-run --profile professional`.
- Confirm the selected models, disk estimate, and planned writes are accurate.
- Run `./install.sh install --profile professional`.
- Confirm `~/.continue/config.yaml` exists and contains `schema: v1`.
- Confirm `~/Library/LaunchAgents/com.localai.ollama.plist` points to the resolved `ollama` binary.
- Run `./install.sh doctor --profile professional` and confirm no warnings.
- Run `./install.sh test` and confirm completion, chat, and embedding checks pass.

## Existing Install Repair

- Install Ollama outside `~/Applications` or symlink `ollama` into `PATH`.
- Create a stale `~/Library/LaunchAgents/com.localai.ollama.plist` pointing to a missing binary.
- Run `./install.sh repair --no-model-pull`.
- Confirm the LaunchAgent was backed up and rewritten with the active binary path.

## Config Safety

- Create an existing `~/.continue/config.yaml`.
- Run `./install.sh install --config-only --profile balanced`.
- Confirm a timestamped `config.yaml.bak.*` file exists.
- Confirm the new config validates with `./install.sh validate-config --profile balanced`.

## Offline Bundle

- On an online Mac with models downloaded, run:

  ```bash
  ./install.sh bundle --profile professional --output LocalAIbundle-offline-professional.tar.gz
  ```

- Move the bundle to another Mac.
- Run:

  ```bash
  ./install.sh install --offline LocalAIbundle-offline-professional.tar.gz --profile professional
  ```

- Confirm no model pull is attempted and `./install.sh doctor --profile professional` passes.

## Uninstall

- Run `./install.sh uninstall --preserve-models`.
- Confirm `~/.ollama` remains.
- Reinstall with `./install.sh install --no-model-pull`.
- Run `./install.sh uninstall`.
- Confirm `~/.ollama` is removed.
