#!/usr/bin/env bash
set -euo pipefail

# LocalAIbundle — Fully local AI coding assistant for macOS
# Installs Ollama, code models, Continue.dev, and configures everything
# Zero cloud dependencies. All inference stays on your machine.

VERSION="1.0.0"
DRY_RUN=false
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1" >&2; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
dry()  { echo -e "${DIM}[dry-run]${NC} would: $1"; }

header() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  LocalAIbundle v${VERSION} — Private AI Coding Assistant${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${DIM}Fully local. No telemetry. Your code never leaves this machine.${NC}"
    echo ""
}

# ─── Hardware Detection ───────────────────────────────────────────────────────

detect_hardware() {
    info "Detecting hardware..."

    if [[ "$(uname -s)" != "Darwin" ]]; then
        err "This tool is macOS-only (Apple Silicon required)"
        exit 1
    fi

    ARCH=$(uname -m)
    if [[ "$ARCH" != "arm64" ]]; then
        err "Apple Silicon (arm64) required. Detected: $ARCH"
        exit 1
    fi

    RAM_BYTES=$(sysctl -n hw.memsize)
    RAM_GB=$((RAM_BYTES / 1073741824))
    CPU_BRAND=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
    GPU_CORES=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Total Number of Cores" | awk -F': ' '{print $2}' | head -1)

    log "Hardware: ${CPU_BRAND}"
    log "RAM: ${RAM_GB}GB"
    log "GPU Cores: ${GPU_CORES:-unknown}"
    echo ""

    # Select model tier based on RAM
    if [[ $RAM_GB -ge 48 ]]; then
        MODEL_TIER="power"
        COMPLETION_MODEL="qwen2.5-coder:7b"
        CHAT_MODEL="qwen2.5-coder:32b"
        EMBED_MODEL="nomic-embed-text"
        info "Tier: POWER — 7B completion + 32B chat (near GPT-4o quality)"
    elif [[ $RAM_GB -ge 24 ]]; then
        MODEL_TIER="professional"
        COMPLETION_MODEL="qwen2.5-coder:3b"
        CHAT_MODEL="qwen2.5-coder:14b"
        EMBED_MODEL="nomic-embed-text"
        info "Tier: PROFESSIONAL — 3B completion + 14B chat"
    elif [[ $RAM_GB -ge 16 ]]; then
        MODEL_TIER="standard"
        COMPLETION_MODEL="qwen2.5-coder:1.5b"
        CHAT_MODEL="qwen2.5-coder:7b"
        EMBED_MODEL="nomic-embed-text"
        info "Tier: STANDARD — 1.5B completion + 7B chat"
    else
        err "Minimum 16GB RAM required. Detected: ${RAM_GB}GB"
        exit 1
    fi
}

# ─── Dependency Installation ──────────────────────────────────────────────────

install_homebrew() {
    if command -v brew &>/dev/null; then
        log "Homebrew already installed"
        return
    fi
    if $DRY_RUN; then dry "install Homebrew"; return; fi
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log "Homebrew installed"
}

install_ollama() {
    if command -v ollama &>/dev/null; then
        log "Ollama already installed ($(ollama --version 2>&1 | grep -o '[0-9].*' || echo 'unknown'))"
        return
    fi
    if $DRY_RUN; then dry "install Ollama app bundle (~150MB)"; return; fi
    info "Installing Ollama..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -fsSL "https://ollama.com/download/Ollama-darwin.zip" -o "$tmp_dir/Ollama-darwin.zip"
    unzip -q "$tmp_dir/Ollama-darwin.zip" -d "$tmp_dir"
    mkdir -p "$HOME/Applications"
    # Remove old install if present
    rm -rf "$HOME/Applications/Ollama.app"
    mv "$tmp_dir/Ollama.app" "$HOME/Applications/Ollama.app"
    rm -rf "$tmp_dir"
    # Symlink the CLI binary into PATH
    ln -sf "$HOME/Applications/Ollama.app/Contents/Resources/ollama" /opt/homebrew/bin/ollama
    log "Ollama installed ($(ollama --version 2>&1 | grep -o '[0-9].*'))"
}

start_ollama() {
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        log "Ollama server already running"
        return
    fi
    if $DRY_RUN; then dry "start ollama serve (background daemon)"; return; fi
    info "Starting Ollama server..."
    ollama serve &>/dev/null &
    OLLAMA_PID=$!
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags &>/dev/null; then
            log "Ollama server started (PID: $OLLAMA_PID)"
            return
        fi
        sleep 1
    done
    err "Ollama server failed to start within 30s"
    exit 1
}

install_launchagent() {
    local plist="$HOME/Library/LaunchAgents/com.localai.ollama.plist"
    if [[ -f "$plist" ]]; then
        log "Ollama LaunchAgent already configured"
        return
    fi
    if $DRY_RUN; then dry "install LaunchAgent for Ollama auto-start on login"; return; fi
    info "Installing Ollama LaunchAgent (auto-start on login)..."
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.localai.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/Applications/Ollama.app/Contents/Resources/ollama</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.ollama/logs/server.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.ollama/logs/server.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_FLASH_ATTENTION</key>
        <string>1</string>
        <key>OLLAMA_KV_CACHE_TYPE</key>
        <string>q8_0</string>
    </dict>
</dict>
</plist>
EOF
    mkdir -p "$HOME/.ollama/logs"
    launchctl load "$plist"
    log "Ollama will auto-start on login"
}

# ─── Test Command ─────────────────────────────────────────────────────────────

cmd_test() {
    header
    info "Running inference smoke tests..."
    echo ""

    local failures=0

    # Check Ollama is running
    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        err "Ollama is not running. Start with: ollama serve"
        exit 1
    fi

    # Get installed models
    local models
    models=$(curl -s http://localhost:11434/api/tags | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(m['name'])
" 2>/dev/null)

    # Test completion model
    local completion_model
    completion_model=$(echo "$models" | grep "qwen2.5-coder" | grep -E "1\.5b|3b" | head -1)
    if [[ -n "$completion_model" ]]; then
        info "Testing completion model: $completion_model"
        local result
        result=$(curl -s http://localhost:11434/api/generate \
            -d "{\"model\":\"$completion_model\",\"prompt\":\"def quicksort(arr):\\n    \",\"stream\":false}" 2>/dev/null)
        local tokens duration speed
        tokens=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('eval_count',0))" 2>/dev/null)
        duration=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(f\"{r.get('eval_duration',0)/1e9:.2f}\")" 2>/dev/null)
        speed=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); c=r.get('eval_count',0); d=r.get('eval_duration',1)/1e9; print(f\"{c/d:.1f}\")" 2>/dev/null)
        if [[ "$tokens" -gt 0 ]] 2>/dev/null; then
            log "Completion: ${tokens} tokens in ${duration}s (${speed} tok/s)"
            if (( $(echo "$speed < 20" | bc -l) )); then
                warn "  Speed below 20 tok/s — autocomplete may feel sluggish"
            fi
        else
            err "Completion model failed to generate"
            failures=$((failures + 1))
        fi
    else
        warn "No completion model found"
        failures=$((failures + 1))
    fi

    echo ""

    # Test chat model
    local chat_model
    chat_model=$(echo "$models" | grep "qwen2.5-coder" | grep -E "7b|14b|32b" | head -1)
    if [[ -n "$chat_model" ]]; then
        info "Testing chat model: $chat_model"
        local result
        result=$(curl -s http://localhost:11434/api/generate \
            -d "{\"model\":\"$chat_model\",\"prompt\":\"In one sentence, what does malloc() do in C?\",\"stream\":false}" 2>/dev/null)
        local tokens duration speed response
        tokens=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('eval_count',0))" 2>/dev/null)
        duration=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(f\"{r.get('eval_duration',0)/1e9:.2f}\")" 2>/dev/null)
        speed=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); c=r.get('eval_count',0); d=r.get('eval_duration',1)/1e9; print(f\"{c/d:.1f}\")" 2>/dev/null)
        response=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('response','')[:100])" 2>/dev/null)
        if [[ "$tokens" -gt 0 ]] 2>/dev/null; then
            log "Chat: ${tokens} tokens in ${duration}s (${speed} tok/s)"
            echo -e "    ${DIM}\"${response}...\"${NC}"
        else
            err "Chat model failed to generate"
            failures=$((failures + 1))
        fi
    else
        warn "No chat model found"
        failures=$((failures + 1))
    fi

    echo ""

    # Test embedding model
    local embed_model
    embed_model=$(echo "$models" | grep "nomic-embed\|mxbai-embed\|all-minilm" | head -1)
    if [[ -n "$embed_model" ]]; then
        info "Testing embedding model: $embed_model"
        local result
        result=$(curl -s http://localhost:11434/api/embed \
            -d "{\"model\":\"$embed_model\",\"input\":\"test embedding generation\"}" 2>/dev/null)
        local dims
        dims=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin); print(len(r.get('embeddings',[[]])[0]))" 2>/dev/null)
        if [[ "$dims" -gt 0 ]] 2>/dev/null; then
            log "Embeddings: ${dims} dimensions — codebase indexing will work"
        else
            err "Embedding model failed"
            failures=$((failures + 1))
        fi
    else
        warn "No embedding model found"
        failures=$((failures + 1))
    fi

    echo ""

    # Summary
    if [[ $failures -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}  ✓ All tests passed. Your local AI is ready.${NC}"
    else
        echo -e "${RED}${BOLD}  ✗ ${failures} test(s) failed.${NC}"
        exit 1
    fi
}

pull_models() {
    echo ""
    if $DRY_RUN; then
        dry "ollama pull ${COMPLETION_MODEL} (~1.9GB download)"
        dry "ollama pull ${CHAT_MODEL} (~9GB download)"
        dry "ollama pull ${EMBED_MODEL} (~274MB download)"
        echo ""
        info "Total model downloads: ~11.2GB"
        return
    fi
    info "Pulling models (this may take a while on first run)..."
    echo ""

    info "Pulling completion model: ${COMPLETION_MODEL}"
    ollama pull "$COMPLETION_MODEL"
    log "Completion model ready: ${COMPLETION_MODEL}"
    echo ""

    info "Pulling chat model: ${CHAT_MODEL}"
    ollama pull "$CHAT_MODEL"
    log "Chat model ready: ${CHAT_MODEL}"
    echo ""

    info "Pulling embedding model: ${EMBED_MODEL}"
    ollama pull "$EMBED_MODEL"
    log "Embedding model ready: ${EMBED_MODEL}"
}

# ─── VS Code + Continue.dev ───────────────────────────────────────────────────

install_vscode() {
    if command -v code &>/dev/null; then
        log "VS Code already installed"
        return
    fi
    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        log "VS Code app exists (adding 'code' to PATH)"
        export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
        return
    fi
    if $DRY_RUN; then dry "brew install --cask visual-studio-code (~400MB)"; return; fi
    info "Installing VS Code..."
    # Use user-local ~/Applications to avoid sudo requirement
    brew install --cask visual-studio-code --appdir="$HOME/Applications" 2>/dev/null \
        || brew install --cask visual-studio-code 2>/dev/null \
        || {
            warn "VS Code cask install needs sudo. Installing manually..."
            # Download and extract to ~/Applications as fallback
            mkdir -p "$HOME/Applications"
            local tmp_zip="/tmp/vscode-darwin.zip"
            curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64" -o "$tmp_zip"
            unzip -q "$tmp_zip" -d "$HOME/Applications/"
            rm -f "$tmp_zip"
        }
    # Ensure 'code' is in PATH
    if [[ -d "$HOME/Applications/Visual Studio Code.app" ]]; then
        export PATH="$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
    elif [[ -d "/Applications/Visual Studio Code.app" ]]; then
        export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
    fi
    if command -v code &>/dev/null; then
        log "VS Code installed"
    else
        warn "VS Code installed but 'code' CLI not in PATH — open VS Code and run 'Install code command in PATH'"
    fi
}

install_continue_extension() {
    if code --list-extensions 2>/dev/null | grep -qi "continue"; then
        log "Continue.dev extension already installed"
        return
    fi
    if $DRY_RUN; then dry "code --install-extension Continue.continue"; return; fi
    info "Installing Continue.dev VS Code extension..."
    code --install-extension Continue.continue
    log "Continue.dev extension installed"
}

configure_continue() {
    CONTINUE_DIR="$HOME/.continue"

    if $DRY_RUN; then
        dry "write Continue.dev config to $CONTINUE_DIR/config.yaml"
        dry "  chat model: ${CHAT_MODEL}"
        dry "  completion model: ${COMPLETION_MODEL}"
        dry "  embedding model: ${EMBED_MODEL}"
        dry "  telemetry: disabled (VS Code setting)"
        dry "  codebase indexing: enabled"
        return
    fi

    mkdir -p "$CONTINUE_DIR"
    info "Configuring Continue.dev for local-only operation..."

    cat > "$CONTINUE_DIR/config.yaml" << YAML
# LocalAIbundle — Continue.dev Configuration (v1.2.x YAML format)
# All models run locally via Ollama. No cloud connections.

name: LocalAIbundle
version: "1.0"

models:
  - name: Chat (${CHAT_MODEL})
    provider: ollama
    model: ${CHAT_MODEL}
    apiBase: http://localhost:11434
    roles:
      - chat
      - edit
    defaultCompletionOptions:
      contextLength: 32768
      maxTokens: 4096

  - name: Autocomplete (${COMPLETION_MODEL})
    provider: ollama
    model: ${COMPLETION_MODEL}
    apiBase: http://localhost:11434
    roles:
      - autocomplete
    defaultCompletionOptions:
      contextLength: 4096
      maxTokens: 256

  - name: Embeddings (${EMBED_MODEL})
    provider: ollama
    model: ${EMBED_MODEL}
    apiBase: http://localhost:11434
    roles:
      - embed

context:
  - provider: codebase
    params:
      nRetrieve: 20
      nFinal: 5
      useReranking: true

  - provider: code
    params:
      nLines: 50

  - provider: diff

  - provider: terminal

  - provider: open

docs: []
YAML

    # Disable telemetry via VS Code settings
    local vscode_settings="$HOME/Library/Application Support/Code/User/settings.json"
    if [[ -f "$vscode_settings" ]]; then
        # Add continue telemetry setting if not present
        if ! grep -q "continue.telemetryEnabled" "$vscode_settings"; then
            # Insert before the last closing brace
            sed -i '' '$ s/}$/,\n  "continue.telemetryEnabled": false\n}/' "$vscode_settings"
        fi
    else
        mkdir -p "$(dirname "$vscode_settings")"
        echo '{ "continue.telemetryEnabled": false }' > "$vscode_settings"
    fi

    log "Continue.dev configured at $CONTINUE_DIR/config.yaml"
}

# ─── Verification ─────────────────────────────────────────────────────────────

verify_installation() {
    echo ""
    echo -e "${BOLD}━━━ Verification ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local all_good=true

    # Check Ollama
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        log "Ollama server: running"
    else
        warn "Ollama server: not running (start with: ollama serve)"
        all_good=false
    fi

    # Check models
    local models
    models=$(ollama list 2>/dev/null || echo "")

    if echo "$models" | grep -q "$COMPLETION_MODEL"; then
        log "Completion model: ${COMPLETION_MODEL} ✓"
    else
        warn "Completion model not found: ${COMPLETION_MODEL}"
        all_good=false
    fi

    if echo "$models" | grep -q "$CHAT_MODEL"; then
        log "Chat model: ${CHAT_MODEL} ✓"
    else
        warn "Chat model not found: ${CHAT_MODEL}"
        all_good=false
    fi

    if echo "$models" | grep -q "$EMBED_MODEL"; then
        log "Embedding model: ${EMBED_MODEL} ✓"
    else
        warn "Embedding model not found: ${EMBED_MODEL}"
        all_good=false
    fi

    # Check VS Code + Continue
    if command -v code &>/dev/null; then
        log "VS Code: installed"
    else
        warn "VS Code: not found in PATH"
        all_good=false
    fi

    if code --list-extensions 2>/dev/null | grep -qi "continue"; then
        log "Continue.dev: installed"
    else
        warn "Continue.dev extension: not found"
        all_good=false
    fi

    # Test inference
    echo ""
    info "Testing inference (quick completion test)..."
    local test_response
    test_response=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\": \"${COMPLETION_MODEL}\", \"prompt\": \"def fibonacci(n):\", \"stream\": false}" \
        2>/dev/null | grep -o '"response":"[^"]*"' | head -1)

    if [[ -n "$test_response" ]]; then
        log "Inference test: PASSED"
    else
        warn "Inference test: no response (model may still be loading)"
        all_good=false
    fi

    echo ""
    if $all_good; then
        echo -e "${GREEN}${BOLD}  ✓ All systems operational. Your AI coding assistant is ready.${NC}"
    else
        echo -e "${YELLOW}${BOLD}  ! Some components need attention (see warnings above).${NC}"
    fi
}

# ─── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "${BOLD}━━━ Setup Complete ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Your local AI stack:${NC}"
    echo -e "  ├─ Engine:     Ollama (localhost:11434)"
    echo -e "  ├─ Completion: ${COMPLETION_MODEL} (tab autocomplete)"
    echo -e "  ├─ Chat:       ${CHAT_MODEL} (explanations, refactoring)"
    echo -e "  ├─ Embeddings: ${EMBED_MODEL} (codebase indexing)"
    echo -e "  └─ IDE:        VS Code + Continue.dev"
    echo ""
    echo -e "  ${BOLD}Usage:${NC}"
    echo -e "  • Open VS Code in your project directory"
    echo -e "  • Tab completion works automatically as you type"
    echo -e "  • Press ${BOLD}Cmd+L${NC} to open chat (ask questions about code)"
    echo -e "  • Press ${BOLD}Cmd+I${NC} to edit code inline with AI"
    echo -e "  • Type ${BOLD}@codebase${NC} in chat to search your entire project"
    echo ""
    echo -e "  ${BOLD}Maintenance:${NC}"
    echo -e "  • Update models:  ollama pull ${CHAT_MODEL}"
    echo -e "  • Check status:   $0 status"
    echo -e "  • Ollama logs:    ollama logs"
    echo ""
    echo -e "  ${DIM}All processing is local. No data leaves this machine.${NC}"
    echo ""
}

# ─── Status Command ───────────────────────────────────────────────────────────

cmd_status() {
    header
    info "Checking LocalAIbundle status..."
    echo ""

    # Ollama
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        log "Ollama: running"
        echo ""
        info "Installed models:"
        ollama list 2>/dev/null | while IFS= read -r line; do
            echo "    $line"
        done
    else
        warn "Ollama: not running"
        echo "    Start with: ollama serve"
    fi

    echo ""

    # VS Code
    if command -v code &>/dev/null; then
        log "VS Code: installed"
        if code --list-extensions 2>/dev/null | grep -qi "continue"; then
            log "Continue.dev: installed"
        else
            warn "Continue.dev: not installed"
        fi
    else
        warn "VS Code: not found"
    fi

    # Config
    echo ""
    if [[ -f "$HOME/.continue/config.yaml" ]]; then
        log "Continue config: $HOME/.continue/config.yaml"
    else
        warn "Continue config: not found"
    fi
}

# ─── Uninstall Command ────────────────────────────────────────────────────────

cmd_uninstall() {
    header
    warn "This will remove:"
    echo "    - Ollama app and all downloaded models (~11GB)"
    echo "    - Ollama LaunchAgent (auto-start)"
    echo "    - Continue.dev VS Code extension"
    echo "    - Continue.dev configuration"
    echo ""
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled."
        exit 0
    fi

    info "Removing Continue.dev extension..."
    code --uninstall-extension Continue.continue 2>/dev/null || true

    info "Removing Continue.dev config..."
    rm -rf "$HOME/.continue"

    info "Stopping Ollama..."
    pkill -f "ollama" 2>/dev/null || true

    info "Removing Ollama LaunchAgent..."
    local plist="$HOME/Library/LaunchAgents/com.localai.ollama.plist"
    if [[ -f "$plist" ]]; then
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
    fi

    info "Removing Ollama app..."
    rm -rf "$HOME/Applications/Ollama.app"
    rm -f /opt/homebrew/bin/ollama

    info "Removing Ollama models and data..."
    rm -rf "$HOME/.ollama"

    log "Uninstall complete. All LocalAIbundle components removed."
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    header
    detect_hardware

    echo ""
    echo -e "${BOLD}━━━ Installing Components ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    install_homebrew
    install_ollama
    install_launchagent
    start_ollama
    pull_models

    echo ""
    install_vscode
    install_continue_extension
    configure_continue

    if $DRY_RUN; then
        echo ""
        echo -e "${BOLD}━━━ Dry Run Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Disk space required:${NC} ~12GB (models) + ~550MB (tools)"
        echo -e "  ${BOLD}Disk space available:${NC} $(df -h / | tail -1 | awk '{print $4}')"
        echo -e "  ${BOLD}Estimated time:${NC} 10-15 min (mostly model downloads)"
        echo ""
        echo -e "  ${BOLD}Will install:${NC}"
        echo -e "  ├─ Ollama app bundle (inference engine)"
        echo -e "  ├─ VS Code (editor)"
        echo -e "  ├─ Continue.dev (VS Code extension)"
        echo -e "  ├─ qwen2.5-coder:3b (~1.9GB)"
        echo -e "  ├─ qwen2.5-coder:14b (~9GB)"
        echo -e "  └─ nomic-embed-text (~274MB)"
        echo ""
        echo -e "  ${BOLD}Will configure:${NC}"
        echo -e "  └─ ~/.continue/config.yaml (local-only, no telemetry)"
        echo ""
        echo -e "  ${DIM}Run without --dry-run to execute.${NC}"
        echo ""
        return
    fi

    verify_installation
    print_summary
}

# ─── CLI Entry Point ──────────────────────────────────────────────────────────

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
    esac
done

# Strip flags to get command
CMD="${1:-install}"
[[ "$CMD" == "--dry-run" ]] && CMD="install"

case "$CMD" in
    install)  main ;;
    status)   cmd_status ;;
    test)     cmd_test ;;
    uninstall) cmd_uninstall ;;
    --version|-v) echo "LocalAIbundle v${VERSION}" ;;
    --help|-h)
        echo "LocalAIbundle v${VERSION} — Private AI Coding Assistant"
        echo ""
        echo "Usage: $0 [command] [flags]"
        echo ""
        echo "Commands:"
        echo "  install     Install and configure everything (default)"
        echo "  status      Check current installation status"
        echo "  test        Run inference smoke tests (speed + correctness)"
        echo "  uninstall   Remove all components"
        echo "  --version   Show version"
        echo "  --help      Show this help"
        echo ""
        echo "Flags:"
        echo "  --dry-run   Show what would be installed without doing it"
        ;;
    *)
        err "Unknown command: $CMD"
        echo "Run '$0 --help' for usage."
        exit 1
        ;;
esac
