#!/usr/bin/env bash
set -euo pipefail

# LocalAIbundle — Fully local AI coding assistant for macOS
# Installs Ollama, code models, Continue.dev, and configures everything
# Zero cloud dependencies. All inference stays on your machine.

VERSION="1.0.0"
DRY_RUN=false
PROFILE="auto"
INSTALL_VSCODE=true
INSTALL_CONTINUE=true
INSTALL_OLLAMA=true
INSTALL_LAUNCHAGENT=true
START_OLLAMA=true
PULL_MODEL_FILES=true
WRITE_CONFIG=true
PRESERVE_MODELS=false
OFFLINE_BUNDLE=""
BUNDLE_OUTPUT=""
REPORT_DIR="${LOCALAIBUNDLE_REPORT_DIR:-$HOME/.localaibundle}"
REPORT_FILE=""
MODEL_TIER=""
COMPLETION_MODEL=""
CHAT_MODEL=""
EMBED_MODEL=""
COMPLETION_MODEL_OVERRIDE=""
CHAT_MODEL_OVERRIDE=""
EMBED_MODEL_OVERRIDE=""
COMPLETION_MODEL_SIZE=""
CHAT_MODEL_SIZE=""
EMBED_MODEL_SIZE="~274MB"
TOTAL_MODEL_SIZE=""
RAM_GB=0
CPU_BRAND=""
GPU_CORES=""
ARCH=""
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

timestamp() {
    date +"%Y%m%d%H%M%S"
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup
        backup="${file}.bak.$(timestamp)"
        cp "$file" "$backup"
        log "Backed up existing $(basename "$file") to $backup"
    fi
}

configure_homebrew_path() {
    if command -v brew &>/dev/null; then
        return
    fi
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

resolve_ollama_binary() {
    if command -v ollama &>/dev/null; then
        command -v ollama
        return 0
    fi

    local candidate
    for candidate in \
        "$HOME/Applications/Ollama.app/Contents/Resources/ollama" \
        "/Applications/Ollama.app/Contents/Resources/ollama" \
        "/opt/homebrew/bin/ollama"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

model_size() {
    case "$1" in
        qwen2.5-coder:1.5b) echo "~986MB" ;;
        qwen2.5-coder:3b)   echo "~1.9GB" ;;
        qwen2.5-coder:7b)   echo "~4.7GB" ;;
        qwen2.5-coder:14b)  echo "~9GB" ;;
        qwen2.5-coder:32b)  echo "~20GB" ;;
        qwen3-coder:30b)    echo "~19GB" ;;
        nomic-embed-text)   echo "~274MB" ;;
        *)                  echo "size varies" ;;
    esac
}

set_model_sizes() {
    COMPLETION_MODEL_SIZE=$(model_size "$COMPLETION_MODEL")
    CHAT_MODEL_SIZE=$(model_size "$CHAT_MODEL")
    EMBED_MODEL_SIZE=$(model_size "$EMBED_MODEL")

    case "$MODEL_TIER" in
        fast)         TOTAL_MODEL_SIZE="~2.2GB" ;;
        standard)     TOTAL_MODEL_SIZE="~6GB" ;;
        balanced)     TOTAL_MODEL_SIZE="~6GB" ;;
        professional) TOTAL_MODEL_SIZE="~11.2GB" ;;
        agentic)      TOTAL_MODEL_SIZE="~21GB" ;;
        power)        TOTAL_MODEL_SIZE="~25GB" ;;
        max)          TOTAL_MODEL_SIZE="~25GB" ;;
        *)            TOTAL_MODEL_SIZE="varies" ;;
    esac
}

apply_profile() {
    case "$PROFILE" in
        auto)
            if [[ $RAM_GB -ge 48 ]]; then
                MODEL_TIER="power"
                COMPLETION_MODEL="qwen2.5-coder:7b"
                CHAT_MODEL="qwen2.5-coder:32b"
                info "Tier: POWER — 7B completion + 32B chat (near GPT-4o quality)"
            elif [[ $RAM_GB -ge 24 ]]; then
                MODEL_TIER="professional"
                COMPLETION_MODEL="qwen2.5-coder:3b"
                CHAT_MODEL="qwen2.5-coder:14b"
                info "Tier: PROFESSIONAL — 3B completion + 14B chat"
            else
                MODEL_TIER="standard"
                COMPLETION_MODEL="qwen2.5-coder:1.5b"
                CHAT_MODEL="qwen2.5-coder:7b"
                info "Tier: STANDARD — 1.5B completion + 7B chat"
            fi
            ;;
        fast)
            MODEL_TIER="fast"
            COMPLETION_MODEL="qwen2.5-coder:1.5b"
            CHAT_MODEL="qwen2.5-coder:3b"
            info "Profile: FAST — smallest useful local coding stack"
            ;;
        balanced)
            MODEL_TIER="balanced"
            COMPLETION_MODEL="qwen2.5-coder:1.5b"
            CHAT_MODEL="qwen2.5-coder:7b"
            info "Profile: BALANCED — responsive default for 16GB+ machines"
            ;;
        professional)
            MODEL_TIER="professional"
            COMPLETION_MODEL="qwen2.5-coder:3b"
            CHAT_MODEL="qwen2.5-coder:14b"
            info "Profile: PROFESSIONAL — larger chat model for daily development"
            ;;
        agentic)
            MODEL_TIER="agentic"
            COMPLETION_MODEL="qwen2.5-coder:3b"
            CHAT_MODEL="qwen3-coder:30b"
            info "Profile: AGENTIC — long-context coding model for larger tasks"
            ;;
        max)
            MODEL_TIER="max"
            COMPLETION_MODEL="qwen2.5-coder:7b"
            CHAT_MODEL="qwen2.5-coder:32b"
            info "Profile: MAX — largest Qwen2.5-Coder tier"
            ;;
        *)
            err "Unknown profile: $PROFILE"
            exit 1
            ;;
    esac

    EMBED_MODEL="nomic-embed-text"

    [[ -n "$COMPLETION_MODEL_OVERRIDE" ]] && COMPLETION_MODEL="$COMPLETION_MODEL_OVERRIDE"
    [[ -n "$CHAT_MODEL_OVERRIDE" ]] && CHAT_MODEL="$CHAT_MODEL_OVERRIDE"
    [[ -n "$EMBED_MODEL_OVERRIDE" ]] && EMBED_MODEL="$EMBED_MODEL_OVERRIDE"
    set_model_sizes
}

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

    local os_name
    os_name="${LOCALAIBUNDLE_TEST_UNAME_S:-$(uname -s)}"
    if [[ "$os_name" != "Darwin" ]]; then
        err "This tool is macOS-only (Apple Silicon required)"
        exit 1
    fi

    ARCH="${LOCALAIBUNDLE_TEST_UNAME_M:-$(uname -m)}"
    if [[ "$ARCH" != "arm64" ]]; then
        err "Apple Silicon (arm64) required. Detected: $ARCH"
        exit 1
    fi

    if [[ -n "${LOCALAIBUNDLE_TEST_RAM_GB:-}" ]]; then
        RAM_GB="$LOCALAIBUNDLE_TEST_RAM_GB"
    else
        local ram_bytes
        ram_bytes=$(sysctl -n hw.memsize)
        RAM_GB=$((ram_bytes / 1073741824))
    fi
    CPU_BRAND="${LOCALAIBUNDLE_TEST_CPU_BRAND:-$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")}"
    GPU_CORES="${LOCALAIBUNDLE_TEST_GPU_CORES:-$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Total Number of Cores" | awk -F': ' '{print $2}' | head -1)}"

    log "Hardware: ${CPU_BRAND}"
    log "RAM: ${RAM_GB}GB"
    log "GPU Cores: ${GPU_CORES:-unknown}"
    echo ""

    if [[ $RAM_GB -lt 16 ]]; then
        err "Minimum 16GB RAM required. Detected: ${RAM_GB}GB"
        exit 1
    fi

    apply_profile
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
    configure_homebrew_path
    log "Homebrew installed"
}

install_ollama() {
    local ollama_bin
    if ollama_bin=$(resolve_ollama_binary); then
        log "Ollama already installed ($("$ollama_bin" --version 2>&1 | grep -o '[0-9].*' || echo 'unknown'))"
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
    configure_homebrew_path
    if [[ -d /opt/homebrew/bin ]]; then
        ln -sf "$HOME/Applications/Ollama.app/Contents/Resources/ollama" /opt/homebrew/bin/ollama
    fi
    ollama_bin=$(resolve_ollama_binary)
    log "Ollama installed ($("$ollama_bin" --version 2>&1 | grep -o '[0-9].*'))"
}

start_ollama() {
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        log "Ollama server already running"
        return
    fi
    if $DRY_RUN; then dry "start ollama serve (background daemon)"; return; fi
    local ollama_bin
    if ! ollama_bin=$(resolve_ollama_binary); then
        err "Ollama CLI not found"
        exit 1
    fi
    info "Starting Ollama server..."
    "$ollama_bin" serve &>/dev/null &
    OLLAMA_PID=$!
    for _ in {1..30}; do
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
    local ollama_bin

    if ! ollama_bin=$(resolve_ollama_binary); then
        if $DRY_RUN; then
            dry "install LaunchAgent after Ollama is installed"
            return
        fi
        err "Ollama CLI not found; cannot configure LaunchAgent"
        exit 1
    fi

    if [[ -f "$plist" ]] && grep -Fq "<string>$ollama_bin</string>" "$plist"; then
        log "Ollama LaunchAgent already configured"
        return
    fi

    if $DRY_RUN; then dry "install or update LaunchAgent for Ollama auto-start on login ($ollama_bin)"; return; fi
    if [[ -f "$plist" ]]; then
        warn "Updating existing Ollama LaunchAgent to use $ollama_bin"
        launchctl unload "$plist" 2>/dev/null || true
        backup_file "$plist"
    else
        info "Installing Ollama LaunchAgent (auto-start on login)..."
    fi
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
        <string>$ollama_bin</string>
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

configured_model_for_role() {
    local role="$1"
    local fallback="$2"
    local config="$HOME/.continue/config.yaml"

    if [[ ! -f "$config" ]]; then
        echo "$fallback"
        return
    fi

    python3 "$(helper_script config-model-for-role.py)" "$config" "$role" "$fallback" 2>/dev/null || echo "$fallback"
}

installed_models() {
    local ollama_bin
    if ollama_bin=$(resolve_ollama_binary); then
        "$ollama_bin" list 2>/dev/null || true
    fi
}

model_installed() {
    local model="$1"
    installed_models | grep -Fq "$model"
}

launchagent_plist() {
    echo "$HOME/Library/LaunchAgents/com.localai.ollama.plist"
}

launchagent_ok() {
    local plist ollama_bin
    plist=$(launchagent_plist)
    ollama_bin=$(resolve_ollama_binary 2>/dev/null || true)
    [[ -n "$ollama_bin" && -f "$plist" ]] && grep -Fq "<string>$ollama_bin</string>" "$plist"
}

continue_config_ok() {
    local config="$HOME/.continue/config.yaml"
    [[ -f "$config" ]] \
        && grep -q '^schema: v1$' "$config" \
        && grep -Fq "model: ${CHAT_MODEL}" "$config" \
        && grep -Fq "model: ${COMPLETION_MODEL}" "$config" \
        && grep -Fq "model: ${EMBED_MODEL}" "$config"
}

continue_telemetry_disabled() {
    local vscode_settings="$HOME/Library/Application Support/Code/User/settings.json"
    [[ -f "$vscode_settings" ]] && grep -q '"continue.telemetryEnabled"[[:space:]]*:[[:space:]]*false' "$vscode_settings"
}

validate_continue_config() {
    local config="${1:-$HOME/.continue/config.yaml}"

    if [[ ! -f "$config" ]]; then
        err "Continue config not found: $config"
        return 1
    fi

    python3 "$(helper_script validate-config.py)" "$config" "$CHAT_MODEL" "$COMPLETION_MODEL" "$EMBED_MODEL"
}

write_install_report() {
    mkdir -p "$REPORT_DIR"
    REPORT_FILE="$REPORT_DIR/install-report-$(timestamp).json"

    local ollama_bin ollama_version report_args
    ollama_bin=$(resolve_ollama_binary 2>/dev/null || true)
    if [[ -n "$ollama_bin" ]]; then
        ollama_version=$("$ollama_bin" --version 2>&1 | head -1)
    else
        ollama_version=""
    fi

    report_args=(
        --output "$REPORT_FILE"
        --version "$VERSION"
        --timestamp "$(timestamp)"
        --profile "$PROFILE"
        --model-tier "$MODEL_TIER"
        --arch "$ARCH"
        --cpu "$CPU_BRAND"
        --gpu-cores "${GPU_CORES:-unknown}"
        --ram-gb "$RAM_GB"
        --completion-model "$COMPLETION_MODEL"
        --chat-model "$CHAT_MODEL"
        --embed-model "$EMBED_MODEL"
        --total-model-size "$TOTAL_MODEL_SIZE"
        --ollama-binary "$ollama_bin"
        --ollama-version "$ollama_version"
    )
    curl -s http://localhost:11434/api/tags &>/dev/null && report_args+=(--ollama-server-running)
    launchagent_ok && report_args+=(--launchagent-ok)
    command -v code &>/dev/null && report_args+=(--vscode-installed)
    code --list-extensions 2>/dev/null | grep -qi "continue" && report_args+=(--continue-installed)
    continue_config_ok && report_args+=(--continue-config-ok)

    python3 "$(helper_script write-install-report.py)" "${report_args[@]}"
    log "Install report: $REPORT_FILE"
}

print_check() {
    local status="$1"
    local label="$2"
    local detail="${3:-}"

    case "$status" in
        ok)   log "$label${detail:+: $detail}" ;;
        warn) warn "$label${detail:+: $detail}" ;;
        fail) err "$label${detail:+: $detail}" ;;
    esac
}

run_doctor_checks() {
    local failures=0 warnings=0
    local ollama_bin

    if ollama_bin=$(resolve_ollama_binary); then
        print_check ok "Ollama CLI" "$ollama_bin"
    else
        print_check fail "Ollama CLI not found"
        failures=$((failures + 1))
    fi

    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        print_check ok "Ollama server" "running on localhost:11434"
    else
        print_check warn "Ollama server not running" "repair can start it"
        warnings=$((warnings + 1))
    fi

    if launchagent_ok; then
        print_check ok "Ollama LaunchAgent" "$(launchagent_plist)"
    else
        print_check warn "Ollama LaunchAgent missing or stale" "repair can rewrite it"
        warnings=$((warnings + 1))
    fi

    local model
    for model in "$COMPLETION_MODEL" "$CHAT_MODEL" "$EMBED_MODEL"; do
        if model_installed "$model"; then
            print_check ok "Model installed" "$model"
        else
            print_check warn "Model missing" "$model"
            warnings=$((warnings + 1))
        fi
    done

    if command -v code &>/dev/null; then
        print_check ok "VS Code CLI" "$(command -v code)"
    else
        print_check warn "VS Code CLI not found"
        warnings=$((warnings + 1))
    fi

    if code --list-extensions 2>/dev/null | grep -qi "continue"; then
        print_check ok "Continue.dev extension" "installed"
    else
        print_check warn "Continue.dev extension missing"
        warnings=$((warnings + 1))
    fi

    if continue_config_ok; then
        print_check ok "Continue config" "$HOME/.continue/config.yaml"
        if validate_continue_config "$HOME/.continue/config.yaml" 2>/dev/null; then
            print_check ok "Continue config validation" "passed"
        else
            print_check warn "Continue config validation failed"
            warnings=$((warnings + 1))
        fi
    else
        print_check warn "Continue config missing or not matching selected profile"
        warnings=$((warnings + 1))
    fi

    if continue_telemetry_disabled; then
        print_check ok "Continue telemetry setting" "disabled"
    else
        print_check warn "Continue telemetry setting not confirmed disabled"
        warnings=$((warnings + 1))
    fi

    echo ""
    if [[ $failures -eq 0 && $warnings -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}  ✓ Doctor found no issues.${NC}"
    elif [[ $failures -eq 0 ]]; then
        echo -e "${YELLOW}${BOLD}  ! Doctor found ${warnings} warning(s). Run '$0 repair' to fix common issues.${NC}"
    else
        echo -e "${RED}${BOLD}  ✗ Doctor found ${failures} failure(s) and ${warnings} warning(s).${NC}"
    fi

    return "$failures"
}

cmd_doctor() {
    header
    detect_hardware
    info "Running diagnostics..."
    echo ""
    run_doctor_checks
}

cmd_repair() {
    header
    detect_hardware
    info "Repairing LocalAIbundle installation..."
    echo ""

    if $INSTALL_OLLAMA; then
        install_ollama
    fi
    if $INSTALL_LAUNCHAGENT; then
        install_launchagent
    fi
    if $START_OLLAMA; then
        start_ollama
    fi
    if $PULL_MODEL_FILES; then
        pull_models
    fi
    if $INSTALL_VSCODE; then
        install_homebrew
    fi
    if $INSTALL_VSCODE; then
        install_vscode
    fi
    if $INSTALL_CONTINUE; then
        install_continue_extension
    fi
    if $WRITE_CONFIG; then
        configure_continue
    fi

    verify_installation
    write_install_report
}

script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

helper_script() {
    echo "$(script_dir)/scripts/$1"
}

import_offline_bundle() {
    local bundle="$1"

    if [[ ! -f "$bundle" ]]; then
        err "Offline bundle not found: $bundle"
        exit 1
    fi

    if $DRY_RUN; then
        dry "import offline bundle $bundle"
        return
    fi

    info "Importing offline bundle: $bundle"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    tar -xzf "$bundle" -C "$tmp_dir"

    if [[ -f "$tmp_dir/payload/ollama-models.tar.gz" ]]; then
        mkdir -p "$HOME/.ollama"
        tar -xzf "$tmp_dir/payload/ollama-models.tar.gz" -C "$HOME/.ollama"
        log "Imported Ollama model cache"
    else
        warn "Offline bundle does not include an Ollama model cache"
    fi

    rm -rf "$tmp_dir"
}

cmd_bundle() {
    header
    detect_hardware

    local output="${BUNDLE_OUTPUT:-LocalAIbundle-offline-${MODEL_TIER}.tar.gz}"
    local tmp_dir payload_dir source_dir
    tmp_dir=$(mktemp -d)
    payload_dir="$tmp_dir/payload"
    source_dir=$(script_dir)
    mkdir -p "$payload_dir"

    if $DRY_RUN; then
        dry "create offline bundle at $output"
        if [[ -d "$HOME/.ollama/models" ]]; then
            dry "include Ollama model cache from $HOME/.ollama/models"
        else
            dry "create scripts/config bundle without Ollama model cache"
        fi
        rm -rf "$tmp_dir"
        return
    fi

    info "Building offline bundle..."
    cp "$source_dir/install.sh" "$payload_dir/install.sh"
    [[ -d "$source_dir/scripts" ]] && cp -R "$source_dir/scripts" "$payload_dir/scripts"
    [[ -f "$source_dir/README.md" ]] && cp "$source_dir/README.md" "$payload_dir/README.md"
    [[ -f "$source_dir/LICENSE" ]] && cp "$source_dir/LICENSE" "$payload_dir/LICENSE"
    [[ -f "$source_dir/.gitignore" ]] && cp "$source_dir/.gitignore" "$payload_dir/.gitignore"

    cat > "$payload_dir/manifest.json" << JSON
{
  "name": "LocalAIbundle offline bundle",
  "version": "$VERSION",
  "created": "$(timestamp)",
  "profile": "$PROFILE",
  "model_tier": "$MODEL_TIER",
  "models": {
    "completion": "$COMPLETION_MODEL",
    "chat": "$CHAT_MODEL",
    "embedding": "$EMBED_MODEL"
  }
}
JSON

    if [[ -d "$HOME/.ollama/models" ]]; then
        info "Adding local Ollama model cache from $HOME/.ollama/models"
        tar -C "$HOME/.ollama" -czf "$payload_dir/ollama-models.tar.gz" models
    else
        warn "No local Ollama model cache found; bundle will include scripts/config only"
    fi

    tar -C "$tmp_dir" -czf "$output" payload
    rm -rf "$tmp_dir"
    log "Offline bundle created: $output"
}

cmd_validate_config() {
    header
    detect_hardware
    local config="$HOME/.continue/config.yaml"
    info "Validating Continue config: $config"
    validate_continue_config "$config"
    log "Continue config validation passed"
}

cmd_test() {
    header
    detect_hardware
    info "Running inference smoke tests..."
    echo ""

    local failures=0
    local completion_model chat_model embed_model
    completion_model=$(configured_model_for_role "autocomplete" "$COMPLETION_MODEL")
    chat_model=$(configured_model_for_role "chat" "$CHAT_MODEL")
    embed_model=$(configured_model_for_role "embed" "$EMBED_MODEL")

    # Check Ollama is running
    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        err "Ollama is not running. Start with: ollama serve"
        exit 1
    fi

    # Get installed models
    local models
    models=$(curl -s http://localhost:11434/api/tags | python3 "$(helper_script ollama-json.py)" models 2>/dev/null)

    # Test completion model
    if echo "$models" | grep -Fxq "$completion_model"; then
        info "Testing completion model: $completion_model"
        local result
        result=$(curl -s http://localhost:11434/api/generate \
            -d "{\"model\":\"$completion_model\",\"prompt\":\"def quicksort(arr):\\n    \",\"stream\":false}" 2>/dev/null)
        local tokens duration speed
        tokens=$(echo "$result" | python3 "$(helper_script ollama-json.py)" generate-stat tokens 2>/dev/null)
        duration=$(echo "$result" | python3 "$(helper_script ollama-json.py)" generate-stat duration 2>/dev/null)
        speed=$(echo "$result" | python3 "$(helper_script ollama-json.py)" generate-stat speed 2>/dev/null)
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
        warn "Completion model not found: $completion_model"
        failures=$((failures + 1))
    fi

    echo ""

    # Test chat model
    if echo "$models" | grep -Fxq "$chat_model"; then
        info "Testing chat model: $chat_model"
        local result
        result=$(curl -s http://localhost:11434/api/generate \
            -d "{\"model\":\"$chat_model\",\"prompt\":\"In one sentence, what does malloc() do in C?\",\"stream\":false}" 2>/dev/null)
        local tokens duration speed response
        tokens=$(echo "$result" | python3 "$(helper_script ollama-json.py)" generate-stat tokens 2>/dev/null)
        duration=$(echo "$result" | python3 "$(helper_script ollama-json.py)" generate-stat duration 2>/dev/null)
        speed=$(echo "$result" | python3 "$(helper_script ollama-json.py)" generate-stat speed 2>/dev/null)
        response=$(echo "$result" | python3 "$(helper_script ollama-json.py)" response 100 2>/dev/null)
        if [[ "$tokens" -gt 0 ]] 2>/dev/null; then
            log "Chat: ${tokens} tokens in ${duration}s (${speed} tok/s)"
            echo -e "    ${DIM}\"${response}...\"${NC}"
        else
            err "Chat model failed to generate"
            failures=$((failures + 1))
        fi
    else
        warn "Chat model not found: $chat_model"
        failures=$((failures + 1))
    fi

    echo ""

    # Test embedding model
    if echo "$models" | grep -Fxq "$embed_model"; then
        info "Testing embedding model: $embed_model"
        local result
        result=$(curl -s http://localhost:11434/api/embed \
            -d "{\"model\":\"$embed_model\",\"input\":\"test embedding generation\"}" 2>/dev/null)
        local dims
        dims=$(echo "$result" | python3 "$(helper_script ollama-json.py)" embedding-dims 2>/dev/null)
        if [[ "$dims" -gt 0 ]] 2>/dev/null; then
            log "Embeddings: ${dims} dimensions — codebase indexing will work"
        else
            err "Embedding model failed"
            failures=$((failures + 1))
        fi
    else
        warn "Embedding model not found: $embed_model"
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
        dry "ollama pull ${COMPLETION_MODEL} (${COMPLETION_MODEL_SIZE} download)"
        dry "ollama pull ${CHAT_MODEL} (${CHAT_MODEL_SIZE} download)"
        dry "ollama pull ${EMBED_MODEL} (${EMBED_MODEL_SIZE} download)"
        echo ""
        info "Total model downloads: ${TOTAL_MODEL_SIZE}"
        return
    fi
    info "Pulling models (this may take a while on first run)..."
    echo ""

    local ollama_bin
    if ! ollama_bin=$(resolve_ollama_binary); then
        err "Ollama CLI not found"
        exit 1
    fi

    info "Pulling completion model: ${COMPLETION_MODEL}"
    "$ollama_bin" pull "$COMPLETION_MODEL"
    log "Completion model ready: ${COMPLETION_MODEL}"
    echo ""

    info "Pulling chat model: ${CHAT_MODEL}"
    "$ollama_bin" pull "$CHAT_MODEL"
    log "Chat model ready: ${CHAT_MODEL}"
    echo ""

    info "Pulling embedding model: ${EMBED_MODEL}"
    "$ollama_bin" pull "$EMBED_MODEL"
    log "Embedding model ready: ${EMBED_MODEL}"
}

# ─── VS Code + Continue.dev ───────────────────────────────────────────────────

install_vscode() {
    configure_homebrew_path
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

disable_continue_telemetry() {
    local vscode_settings="$HOME/Library/Application Support/Code/User/settings.json"

    mkdir -p "$(dirname "$vscode_settings")"
    if [[ -f "$vscode_settings" ]]; then
        backup_file "$vscode_settings"
    else
        echo '{}' > "$vscode_settings"
    fi

    if python3 "$(helper_script update-vscode-settings.py)" "$vscode_settings"; then
        log "Continue.dev telemetry disabled in VS Code settings"
    else
        warn "Could not update VS Code settings automatically; disable 'Allow Anonymous Telemetry' in Continue settings"
    fi
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
    backup_file "$CONTINUE_DIR/config.yaml"

    cat > "$CONTINUE_DIR/config.yaml" << YAML
# LocalAIbundle — Continue.dev Configuration (v1 YAML format)
# All models run locally via Ollama. No cloud connections.

name: LocalAIbundle
version: 1.0.0
schema: v1

models:
  - name: Chat (${CHAT_MODEL})
    provider: ollama
    model: ${CHAT_MODEL}
    apiBase: http://localhost:11434
    roles:
      - chat
      - edit
      - apply
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

    validate_continue_config "$CONTINUE_DIR/config.yaml"
    log "Continue.dev config validated"
    disable_continue_telemetry

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
    local models ollama_bin
    if ollama_bin=$(resolve_ollama_binary); then
        models=$("$ollama_bin" list 2>/dev/null || echo "")
    else
        models=""
    fi

    if echo "$models" | grep -Fq "$COMPLETION_MODEL"; then
        log "Completion model: ${COMPLETION_MODEL} ✓"
    else
        warn "Completion model not found: ${COMPLETION_MODEL}"
        all_good=false
    fi

    if echo "$models" | grep -Fq "$CHAT_MODEL"; then
        log "Chat model: ${CHAT_MODEL} ✓"
    else
        warn "Chat model not found: ${CHAT_MODEL}"
        all_good=false
    fi

    if echo "$models" | grep -Fq "$EMBED_MODEL"; then
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
        local ollama_bin
        if ollama_bin=$(resolve_ollama_binary); then
            "$ollama_bin" list 2>/dev/null | while IFS= read -r line; do
                echo "    $line"
            done
        else
            warn "Ollama CLI not found"
        fi
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
    echo "    - Ollama app"
    if $PRESERVE_MODELS; then
        echo "    - Ollama models: preserved because --preserve-models was set"
    else
        echo "    - Ollama models and data"
    fi
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
    if [[ -L /opt/homebrew/bin/ollama ]]; then
        local ollama_link_target
        ollama_link_target=$(readlink /opt/homebrew/bin/ollama)
        if [[ "$ollama_link_target" == "$HOME/Applications/Ollama.app/Contents/Resources/ollama" ]]; then
            rm -f /opt/homebrew/bin/ollama
        fi
    fi

    if $PRESERVE_MODELS; then
        info "Preserving Ollama models and data at $HOME/.ollama"
    else
        info "Removing Ollama models and data..."
        rm -rf "$HOME/.ollama"
    fi

    log "Uninstall complete. All LocalAIbundle components removed."
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    header
    detect_hardware

    echo ""
    echo -e "${BOLD}━━━ Installing Components ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if $INSTALL_VSCODE; then
        install_homebrew
    fi
    if $INSTALL_OLLAMA; then
        install_ollama
    fi
    if [[ -n "$OFFLINE_BUNDLE" ]]; then
        import_offline_bundle "$OFFLINE_BUNDLE"
    fi
    if $INSTALL_LAUNCHAGENT; then
        install_launchagent
    fi
    if $START_OLLAMA; then
        start_ollama
    fi
    if $PULL_MODEL_FILES; then
        pull_models
    else
        info "Skipping model downloads"
    fi

    echo ""
    if $INSTALL_VSCODE; then
        install_vscode
    else
        info "Skipping VS Code install"
    fi
    if $INSTALL_CONTINUE; then
        install_continue_extension
    else
        info "Skipping Continue.dev extension install"
    fi
    if $WRITE_CONFIG; then
        configure_continue
    else
        info "Skipping Continue.dev config write"
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${BOLD}━━━ Dry Run Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Model tier:${NC} ${MODEL_TIER}"
        echo -e "  ${BOLD}Disk space required:${NC} ${TOTAL_MODEL_SIZE} (models) + ~550MB (tools)"
        echo -e "  ${BOLD}Disk space available:${NC} $(df -h / | tail -1 | awk '{print $4}')"
        echo -e "  ${BOLD}Estimated time:${NC} 10-15 min (mostly model downloads)"
        echo ""
        echo -e "  ${BOLD}Will install:${NC}"
        $INSTALL_OLLAMA && echo -e "  ├─ Ollama app bundle (inference engine)"
        $INSTALL_LAUNCHAGENT && echo -e "  ├─ Ollama LaunchAgent"
        if $PULL_MODEL_FILES; then
            echo -e "  ├─ ${COMPLETION_MODEL} (${COMPLETION_MODEL_SIZE})"
            echo -e "  ├─ ${CHAT_MODEL} (${CHAT_MODEL_SIZE})"
            echo -e "  ├─ ${EMBED_MODEL} (${EMBED_MODEL_SIZE})"
        fi
        $INSTALL_VSCODE && echo -e "  ├─ VS Code (editor)"
        $INSTALL_CONTINUE && echo -e "  ├─ Continue.dev (VS Code extension)"
        [[ -n "$OFFLINE_BUNDLE" ]] && echo -e "  ├─ offline model cache from ${OFFLINE_BUNDLE}"
        echo -e "  └─ install report in ${REPORT_DIR}"
        echo ""
        echo -e "  ${BOLD}Will configure:${NC}"
        if $WRITE_CONFIG; then
            echo -e "  └─ ~/.continue/config.yaml (local-only, no telemetry)"
        else
            echo -e "  └─ no Continue config changes"
        fi
        echo ""
        echo -e "  ${DIM}Run without --dry-run to execute.${NC}"
        echo ""
        return
    fi

    verify_installation
    write_install_report
    print_summary
}

# ─── CLI Entry Point ──────────────────────────────────────────────────────────

usage() {
    echo "LocalAIbundle v${VERSION} — Private AI Coding Assistant"
    echo ""
    echo "Usage: $0 [command] [flags]"
    echo ""
    echo "Commands:"
    echo "  install       Install and configure everything (default)"
    echo "  doctor        Run diagnostics without changing the system"
    echo "  repair        Repair common installation/configuration issues"
    echo "  status        Check current installation status"
    echo "  test          Run inference smoke tests (speed + correctness)"
    echo "  validate-config Validate the generated Continue config"
    echo "  bundle        Create an offline bundle from this repo and local model cache"
    echo "  uninstall     Remove all components"
    echo "  --version     Show version"
    echo "  --help        Show this help"
    echo ""
    echo "Profiles:"
    echo "  auto          Select by RAM (default)"
    echo "  fast          Smallest useful stack"
    echo "  balanced      Responsive 16GB+ stack"
    echo "  professional  Larger daily-development stack"
    echo "  agentic       Long-context coding model for larger tasks"
    echo "  max           Largest Qwen2.5-Coder tier"
    echo ""
    echo "Flags:"
    echo "  --dry-run                    Show planned actions without making changes"
    echo "  --profile <name>             Choose a model profile"
    echo "  --completion-model <model>   Override autocomplete model"
    echo "  --chat-model <model>         Override chat/edit model"
    echo "  --embed-model <model>        Override embedding model"
    echo "  --models-only                Install/start Ollama and pull models only"
    echo "  --config-only                Write Continue config/settings only"
    echo "  --no-vscode                  Skip VS Code and Continue extension installs"
    echo "  --no-continue                Skip Continue extension and config"
    echo "  --no-launchagent             Skip Ollama auto-start LaunchAgent"
    echo "  --no-model-pull              Skip model downloads"
    echo "  --offline <bundle.tgz>       Import model cache from an offline bundle"
    echo "  --output <bundle.tgz>        Output path for the bundle command"
    echo "  --report-dir <dir>           Directory for install reports"
    echo "  --preserve-models            Keep ~/.ollama during uninstall"
}

require_arg() {
    local flag="$1"
    local value="${2:-}"
    if [[ -z "$value" || "$value" == --* ]]; then
        err "$flag requires a value"
        exit 1
    fi
}

parse_args() {
    CMD="install"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|doctor|repair|status|test|validate-config|bundle|uninstall)
                CMD="$1"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --profile)
                require_arg "$1" "${2:-}"
                PROFILE="$2"
                shift 2
                ;;
            --profile=*)
                PROFILE="${1#*=}"
                shift
                ;;
            --completion-model)
                require_arg "$1" "${2:-}"
                COMPLETION_MODEL_OVERRIDE="$2"
                shift 2
                ;;
            --completion-model=*)
                COMPLETION_MODEL_OVERRIDE="${1#*=}"
                shift
                ;;
            --chat-model)
                require_arg "$1" "${2:-}"
                CHAT_MODEL_OVERRIDE="$2"
                shift 2
                ;;
            --chat-model=*)
                CHAT_MODEL_OVERRIDE="${1#*=}"
                shift
                ;;
            --embed-model)
                require_arg "$1" "${2:-}"
                EMBED_MODEL_OVERRIDE="$2"
                shift 2
                ;;
            --embed-model=*)
                EMBED_MODEL_OVERRIDE="${1#*=}"
                shift
                ;;
            --models-only)
                INSTALL_VSCODE=false
                INSTALL_CONTINUE=false
                WRITE_CONFIG=false
                shift
                ;;
            --config-only)
                INSTALL_OLLAMA=false
                INSTALL_LAUNCHAGENT=false
                START_OLLAMA=false
                PULL_MODEL_FILES=false
                INSTALL_VSCODE=false
                INSTALL_CONTINUE=false
                WRITE_CONFIG=true
                shift
                ;;
            --no-vscode)
                INSTALL_VSCODE=false
                INSTALL_CONTINUE=false
                shift
                ;;
            --no-continue)
                INSTALL_CONTINUE=false
                WRITE_CONFIG=false
                shift
                ;;
            --no-launchagent)
                INSTALL_LAUNCHAGENT=false
                shift
                ;;
            --no-model-pull)
                PULL_MODEL_FILES=false
                shift
                ;;
            --offline)
                require_arg "$1" "${2:-}"
                OFFLINE_BUNDLE="$2"
                PULL_MODEL_FILES=false
                shift 2
                ;;
            --offline=*)
                OFFLINE_BUNDLE="${1#*=}"
                PULL_MODEL_FILES=false
                shift
                ;;
            --output)
                require_arg "$1" "${2:-}"
                BUNDLE_OUTPUT="$2"
                shift 2
                ;;
            --output=*)
                BUNDLE_OUTPUT="${1#*=}"
                shift
                ;;
            --report-dir)
                require_arg "$1" "${2:-}"
                REPORT_DIR="$2"
                shift 2
                ;;
            --report-dir=*)
                REPORT_DIR="${1#*=}"
                shift
                ;;
            --preserve-models)
                PRESERVE_MODELS=true
                shift
                ;;
            --help|-h)
                CMD="help"
                shift
                ;;
            --version|-v)
                CMD="version"
                shift
                ;;
            *)
                err "Unknown argument: $1"
                echo "Run '$0 --help' for usage."
                exit 1
                ;;
        esac
    done
}

dispatch() {
    case "$CMD" in
        install)   main ;;
        doctor)    cmd_doctor ;;
        repair)    cmd_repair ;;
        status)    cmd_status ;;
        test)      cmd_test ;;
        validate-config) cmd_validate_config ;;
        bundle)    cmd_bundle ;;
        uninstall) cmd_uninstall ;;
        version)   echo "LocalAIbundle v${VERSION}" ;;
        help)      usage ;;
        *)
            err "Unknown command: $CMD"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
}

if [[ "${LOCALAIBUNDLE_SOURCE_ONLY:-false}" != "true" ]]; then
    parse_args "$@"
    dispatch
fi
