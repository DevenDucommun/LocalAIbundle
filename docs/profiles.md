# Model Profiles

Use `auto` unless you already know which model sizes your Mac can handle. LocalAIbundle chooses a profile from system RAM and keeps autocomplete smaller than chat so coding stays responsive.

| Profile | RAM Target | Approx Models | Best Fit |
|---------|------------|---------------|----------|
| `fast` | 16GB | ~2.2GB | Lightweight machines, quick tests, battery-sensitive work |
| `balanced` | 16GB+ | ~6GB | General coding with responsive chat |
| `professional` | 24GB+ | ~11.2GB | Daily development, refactoring, explanations |
| `agentic` | 32GB+ | ~21GB | Larger tasks and long-context coding |
| `max` | 48GB+ | ~25GB | High-memory machines where quality matters more than download size |

Preview your selection:

```bash
./install.sh --dry-run
```

Override explicitly:

```bash
./install.sh install --profile professional
./install.sh install --chat-model qwen3-coder:30b --completion-model qwen2.5-coder:3b
```

If autocomplete feels slow, use a smaller completion model. If chat quality is the issue, increase only the chat model.
