# Privacy And Security Model

LocalAIbundle is designed for local inference on macOS Apple Silicon.

## Local Boundary

- Ollama serves models on `localhost:11434`.
- Continue.dev is configured to use the local Ollama provider.
- No cloud API keys are required.
- Continue telemetry is disabled in VS Code settings by the installer.

## Network Use

The first install can use the network to download:

- Ollama
- VS Code, when VS Code is not already installed
- Continue.dev VS Code extension
- Ollama model files

Use `./install.sh --dry-run` to preview planned downloads. Use offline bundles when installing on disconnected machines.

## Offline Bundles

Offline bundles can include installer files and the local Ollama model cache from `~/.ollama/models`. They do not prove that the original online machine never used the network; they only avoid model downloads on the target machine.

## Local Files Changed

Common paths:

| Path | Purpose |
|------|---------|
| `~/Applications/Ollama.app` | User-local Ollama app install |
| `~/.ollama` | Ollama model cache and logs |
| `~/Library/LaunchAgents/com.localai.ollama.plist` | Ollama auto-start LaunchAgent |
| `~/.continue/config.yaml` | Continue.dev local model config |
| `~/Library/Application Support/Code/User/settings.json` | VS Code settings updated to disable Continue telemetry |
| `~/.localaibundle/` | Install reports |

## Reporting Issues

Install reports are written under `~/.localaibundle/`. Review them before sharing because they can include local paths and hardware details.
