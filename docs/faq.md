# FAQ

## Does my code leave my machine?

LocalAIbundle configures Continue.dev to use Ollama on `localhost:11434`. Model inference runs locally. The installer does use the network during first setup to download tools, extensions, and model files unless you use an offline bundle.

## Can I use it offline?

Yes, after the stack and models are installed. You can also create an offline bundle on a connected Mac:

```bash
./install.sh bundle --profile professional --output LocalAIbundle-offline-professional.tar.gz
```

Then import that bundle on another Mac:

```bash
./install.sh install --offline LocalAIbundle-offline-professional.tar.gz
```

## How much disk space do models use?

The default automatic profile depends on RAM. Expect roughly 6GB for 16GB machines, 11GB for 24-32GB machines, and 25GB for 48GB+ machines. Run `./install.sh --dry-run` to see the selected profile and estimate before installing.

## Can I keep my existing Continue config?

The installer backs up `~/.continue/config.yaml` before writing a new config. Backups are timestamped as `config.yaml.bak.<timestamp>`.

During uninstall, preserve Continue config with:

```bash
./install.sh uninstall --preserve-config
```

## Does uninstall remove VS Code?

No. `./install.sh uninstall` removes LocalAIbundle-managed pieces: Ollama app, models unless preserved, LaunchAgent, Continue extension, and Continue config. It does not remove VS Code itself.

## Can I preserve models during uninstall?

Yes:

```bash
./install.sh uninstall --preserve-models
```

You can combine preserve flags:

```bash
./install.sh uninstall --preserve-models --preserve-config
```

## Is there a Homebrew package?

Not yet. The repo includes a formula template under `packaging/homebrew/`, but public README Homebrew instructions should wait until a personal tap exists and is tested.
