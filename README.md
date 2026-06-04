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

```bash
./install.sh
```

The installer auto-detects your RAM and selects the best models:

| RAM | Completion | Chat | Quality |
|-----|-----------|------|---------|
| 16GB | qwen2.5-coder:1.5b | qwen2.5-coder:7b | Good |
| 24-32GB | qwen2.5-coder:3b | qwen2.5-coder:14b | Great |
| 48GB+ | qwen2.5-coder:7b | qwen2.5-coder:32b | Near GPT-4o |

## Usage

Once installed, open VS Code in any project:

- **Tab completion** — works automatically as you type
- **Cmd+L** — open chat (ask questions about your code)
- **Cmd+I** — edit code inline with AI assistance
- **@codebase** — search your entire project for context

## Commands

```bash
./install.sh install    # Install everything (default)
./install.sh status     # Check what's running
./install.sh uninstall  # Remove everything
```

## Requirements

- macOS on Apple Silicon (M1/M2/M3/M4)
- 16GB RAM minimum (32GB recommended)
- ~20GB disk space for models

## Privacy

- Ollama: no telemetry, no network calls, air-gappable
- Continue.dev: telemetry disabled in config
- All inference runs on your GPU via Metal
- Safe for proprietary/confidential codebases
