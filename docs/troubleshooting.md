# Troubleshooting

## Preview Changes First

```bash
./install.sh --dry-run
```

This shows the selected profile, model downloads, paths, and planned writes without changing the system.

## Run Diagnostics

```bash
./install.sh doctor
./install.sh doctor --json
```

Use JSON output when attaching diagnostics to an issue or automating checks.

Create a redacted troubleshooting archive:

```bash
./install.sh issue-report --issue-output localai-report.tgz
```

Review the archive before sharing. Home directory paths are redacted to `~`.

## Repair Common Problems

```bash
./install.sh repair --no-model-pull
```

This can rewrite a stale LaunchAgent, reinstall missing config, and repair common local setup issues without re-downloading models.

## Ollama Is Not Running

Start Ollama manually:

```bash
ollama serve
```

Then run:

```bash
./install.sh doctor
```

If the LaunchAgent is stale, run:

```bash
./install.sh repair --no-model-pull
```

## Models Are Missing

Pull models for the selected profile:

```bash
./install.sh install --models-only --profile professional
```

Or choose a smaller profile:

```bash
./install.sh install --models-only --profile fast
```

## Continue Config Looks Wrong

Validate the generated config:

```bash
./install.sh validate-config
```

Rewrite only the Continue config and VS Code settings:

```bash
./install.sh install --config-only
```

Existing configs are backed up before replacement.

## VS Code CLI Is Missing

Open VS Code, run the command palette, and choose `Shell Command: Install 'code' command in PATH`. Then rerun:

```bash
./install.sh doctor
```

## Package Or Release Checks

Run non-mutating project checks:

```bash
./install.sh self-test --no-network
```
