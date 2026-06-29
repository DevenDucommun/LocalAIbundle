# LocalAIbundle vs Manual Setup

| Area | LocalAIbundle | Manual Ollama + Continue |
|------|---------------|--------------------------|
| Model choice | RAM-aware profiles with explicit overrides | User researches and picks each model |
| Ollama setup | Installs, starts, and can configure LaunchAgent | Install and service setup handled separately |
| Continue config | Writes local-only v1 config and validates it | User edits YAML manually |
| Existing config safety | Timestamped backups | Depends on user workflow |
| Diagnostics | `doctor`, `status`, JSON output, install reports | Manual checks across tools |
| Repair | `repair` handles common stale setup pieces | User debugs each component |
| Offline installs | Bundle/import local model cache | Manual model/cache transfer |
| Uninstall | Removes managed pieces, with preserve flags | Manual cleanup |
| Release artifacts | Tarball, `.pkg`, `.dmg`, checksums | Not applicable |

Manual setup gives maximum control. LocalAIbundle is better when you want repeatable local AI coding setup, diagnostics, and uninstall behavior.
