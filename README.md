# LocalAIbundle

Fully local AI coding assistant for macOS (Apple Silicon). Installs and configures a complete private AI stack for code completion, chat, and codebase-aware answers — with zero cloud dependencies.

**Your code never leaves your machine.**

## What it installs

| Component | Purpose |
|-----------|---------|
| [Ollama](https://ollama.com) | Local inference engine (Metal-accelerated) |
| Qwen2.5-Coder (small) | Fast tab completion (<200ms) |
| Qwen2.5-Coder (large) | Chat, explanations, refactoring |
| nomic-embed-text | Codebase indexing for context-aware answers |
| [VS Code](https://code.visualstudio.com) | Editor |
| [Continue.dev](https://continue.dev) | IDE integration (connects everything) |

## Quick start

### Prerequisites

- macOS on Apple Silicon (M1/M2/M3/M4)
- 16GB RAM minimum (32GB recommended)
- ~20GB free disk space
- Internet connection (for initial model downloads only)

### Install

```bash
git clone https://github.com/DevenDucommun/LocalAIbundle.git
cd LocalAIbundle
chmod +x install.sh

# Preview what will be installed (no changes made)
./install.sh --dry-run

# Run the full installation (~10-15 min, mostly model downloads)
./install.sh
```

### Verify

```bash
# Check all components are running
./install.sh status

# Run inference speed tests
./install.sh test
```

### Start coding

1. Open VS Code: `code /path/to/your/project`
2. Wait ~10 seconds for Continue.dev to initialize and index your project
3. Start typing — tab completion suggestions appear automatically
4. Press **Cmd+L** to open the AI chat panel
5. Type `@codebase` in chat to give the AI full project context

## Model tiers

The installer auto-detects your RAM and selects the best models:

| RAM | Completion | Chat | Quality |
|-----|-----------|------|---------|
| 16GB | qwen2.5-coder:1.5b | qwen2.5-coder:7b | Good |
| 24-32GB | qwen2.5-coder:3b | qwen2.5-coder:14b | Great |
| 48GB+ | qwen2.5-coder:7b | qwen2.5-coder:32b | Near GPT-4o |

## Usage

| Action | Shortcut | Description |
|--------|----------|-------------|
| Tab complete | Just type | Suggestions appear inline as you code |
| Chat | **Cmd+L** | Ask questions, get explanations |
| Inline edit | **Cmd+I** | AI rewrites selected code |
| Codebase context | `@codebase` | Search entire project for relevant code |
| Open file context | `@open` | Reference currently open files |
| Terminal context | `@terminal` | Reference recent terminal output |
| Diff context | `@diff` | Reference uncommitted changes |

## Commands

```bash
./install.sh install    # Install and configure everything (default)
./install.sh status     # Check what's running and installed
./install.sh test       # Smoke test inference speed and model loading
./install.sh uninstall  # Remove all components cleanly
./install.sh --dry-run  # Preview install without making changes
./install.sh --help     # Show all commands
```

## How it works

```
┌─────────────────────────────────────────────────────┐
│  VS Code + Continue.dev Extension                    │
│  (tab completion, chat panel, inline edit)           │
└────────────────────┬────────────────────────────────┘
                     │ OpenAI-compatible API
                     ▼
┌─────────────────────────────────────────────────────┐
│  Ollama (localhost:11434)                            │
│  ├─ qwen2.5-coder:3b   → autocomplete (fast)       │
│  ├─ qwen2.5-coder:14b  → chat/edit (quality)       │
│  └─ nomic-embed-text   → codebase indexing          │
│                                                     │
│  Metal GPU acceleration · Auto-start on login       │
└─────────────────────────────────────────────────────┘
```

All requests stay on `localhost`. No API keys needed. No cloud accounts.

## After installation

Ollama starts automatically on login via a LaunchAgent. If you need to manage it manually:

```bash
# Stop Ollama
pkill ollama

# Start Ollama
ollama serve

# Update models to latest
ollama pull qwen2.5-coder:14b
ollama pull qwen2.5-coder:3b

# List installed models
ollama list
```

## Troubleshooting

**Tab completion not working?**
- Check Ollama is running: `curl http://localhost:11434`
- Restart VS Code (Continue.dev connects on startup)
- Check Continue logs: Cmd+Shift+P → "Continue: View Logs"

**Slow responses?**
- Run `./install.sh test` to check token speed
- Close memory-heavy apps (models need RAM)
- Smaller models = faster: edit `~/.continue/config.yaml` to use 1.5b for completion

**Models not loading?**
- Check disk space: `df -h /`
- Re-pull: `ollama pull qwen2.5-coder:14b`

## Privacy

- Ollama: no telemetry, no network calls, fully air-gappable
- Continue.dev: telemetry disabled in VS Code settings
- All inference runs on-device via Apple Metal GPU
- Models stored locally in `~/.ollama/`
- Safe for proprietary/confidential codebases
- Can operate completely offline after initial install

## Uninstall

```bash
./install.sh uninstall
```

Removes: Ollama app, all models (~11GB), LaunchAgent, Continue.dev extension and config. Does not remove VS Code itself.
