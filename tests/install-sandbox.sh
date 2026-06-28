#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX_DIR=$(mktemp -d)
trap 'rm -rf "$SANDBOX_DIR"' EXIT

FAKE_HOME="$SANDBOX_DIR/home"
FAKE_BIN="$SANDBOX_DIR/bin"
STATE_DIR="$SANDBOX_DIR/state"
mkdir -p "$FAKE_HOME" "$FAKE_BIN" "$STATE_DIR"

cat > "$FAKE_BIN/ollama" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${LOCALAIBUNDLE_SANDBOX_STATE:?}"
case "${1:-}" in
  --version)
    echo "ollama version 0.0.0-sandbox"
    ;;
  pull)
    mkdir -p "$state"
    grep -Fxq "$2" "$state/models" 2>/dev/null || echo "$2" >> "$state/models"
    echo "pulled $2"
    ;;
  list)
    echo "NAME ID SIZE MODIFIED"
    cat "$state/models" 2>/dev/null || true
    ;;
  serve)
    sleep 1
    ;;
  *)
    echo "fake ollama: unsupported args: $*" >&2
    exit 1
    ;;
esac
SH

cat > "$FAKE_BIN/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${LOCALAIBUNDLE_SANDBOX_STATE:?}"
args="$*"

if [[ "$args" == *"/api/tags"* ]]; then
  python3 - "$state/models" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
models = []
if path.exists():
    models = [{"name": line.strip()} for line in path.read_text().splitlines() if line.strip()]
print(json.dumps({"models": models}))
PY
elif [[ "$args" == *"/api/embed"* ]]; then
  printf '{"embeddings":[[0.1,0.2,0.3]]}\n'
elif [[ "$args" == *"/api/generate"* ]]; then
  printf '{"response":"sandbox response","eval_count":24,"eval_duration":1200000000}\n'
else
  echo "fake curl: unsupported args: $*" >&2
  exit 1
fi
SH

cat > "$FAKE_BIN/code" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${LOCALAIBUNDLE_SANDBOX_STATE:?}"
case "${1:-}" in
  --list-extensions)
    cat "$state/extensions" 2>/dev/null || true
    ;;
  --install-extension)
    mkdir -p "$state"
    grep -Fxq "$2" "$state/extensions" 2>/dev/null || echo "$2" >> "$state/extensions"
    echo "installed $2"
    ;;
  --uninstall-extension)
    touch "$state/extensions"
    grep -Fxv "$2" "$state/extensions" > "$state/extensions.tmp" || true
    mv "$state/extensions.tmp" "$state/extensions"
    ;;
  *)
    echo "fake code: unsupported args: $*" >&2
    exit 1
    ;;
esac
SH

cat > "$FAKE_BIN/launchctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "launchctl $*" >> "${LOCALAIBUNDLE_SANDBOX_STATE:?}/launchctl.log"
SH

cat > "$FAKE_BIN/brew" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "brew $*" >> "${LOCALAIBUNDLE_SANDBOX_STATE:?}/brew.log"
SH

cat > "$FAKE_BIN/pkill" <<'SH'
#!/usr/bin/env bash
exit 0
SH

chmod +x "$FAKE_BIN/"*

export HOME="$FAKE_HOME"
export PATH="$FAKE_BIN:$PATH"
export LOCALAIBUNDLE_SANDBOX_STATE="$STATE_DIR"
export LOCALAIBUNDLE_TEST_UNAME_S=Darwin
export LOCALAIBUNDLE_TEST_UNAME_M=arm64
export LOCALAIBUNDLE_TEST_RAM_GB=32
export LOCALAIBUNDLE_TEST_CPU_BRAND="Sandbox Apple Silicon"
export LOCALAIBUNDLE_TEST_GPU_CORES=16
export LOCALAIBUNDLE_REPORT_DIR="$FAKE_HOME/.localaibundle"

"$ROOT_DIR/install.sh" install --profile professional
"$ROOT_DIR/install.sh" doctor --profile professional
"$ROOT_DIR/install.sh" test

[[ -f "$FAKE_HOME/.continue/config.yaml" ]]
grep -q '^schema: v1$' "$FAKE_HOME/.continue/config.yaml"
grep -q 'model: qwen2.5-coder:14b' "$FAKE_HOME/.continue/config.yaml"
grep -q '"continue.telemetryEnabled": false' "$FAKE_HOME/Library/Application Support/Code/User/settings.json"
grep -q '/bin/ollama</string>' "$FAKE_HOME/Library/LaunchAgents/com.localai.ollama.plist"
find "$FAKE_HOME/.localaibundle" -name 'install-report-*.json' | grep -q .

printf 'sandbox install test passed: %s\n' "$SANDBOX_DIR"
