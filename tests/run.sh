#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() {
    printf 'ok - %s\n' "$1"
}

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    if [[ "$expected" != "$actual" ]]; then
        printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
        fail "$label"
    fi
    pass "$label"
}

run_sourced() {
    LOCALAIBUNDLE_SOURCE_ONLY=true \
    LOCALAIBUNDLE_TEST_UNAME_S=Darwin \
    LOCALAIBUNDLE_TEST_UNAME_M=arm64 \
    LOCALAIBUNDLE_TEST_GPU_CORES=10 \
    bash -c "source '$ROOT_DIR/install.sh'; $*"
}

test_auto_profiles() {
    local output
    output=$(LOCALAIBUNDLE_TEST_RAM_GB=16 run_sourced 'detect_hardware >/dev/null; printf "%s|%s|%s|%s" "$MODEL_TIER" "$COMPLETION_MODEL" "$CHAT_MODEL" "$TOTAL_MODEL_SIZE"')
    assert_eq "standard|qwen2.5-coder:1.5b|qwen2.5-coder:7b|~6GB" "$output" "auto profile selects standard on 16GB"

    output=$(LOCALAIBUNDLE_TEST_RAM_GB=32 run_sourced 'detect_hardware >/dev/null; printf "%s|%s|%s|%s" "$MODEL_TIER" "$COMPLETION_MODEL" "$CHAT_MODEL" "$TOTAL_MODEL_SIZE"')
    assert_eq "professional|qwen2.5-coder:3b|qwen2.5-coder:14b|~11.2GB" "$output" "auto profile selects professional on 32GB"

    output=$(LOCALAIBUNDLE_TEST_RAM_GB=64 run_sourced 'detect_hardware >/dev/null; printf "%s|%s|%s|%s" "$MODEL_TIER" "$COMPLETION_MODEL" "$CHAT_MODEL" "$TOTAL_MODEL_SIZE"')
    assert_eq "power|qwen2.5-coder:7b|qwen2.5-coder:32b|~25GB" "$output" "auto profile selects power on 64GB"
}

test_parser_modes() {
    local output
    output=$(run_sourced 'parse_args install --dry-run --profile agentic --models-only --chat-model custom:latest; printf "%s|%s|%s|%s|%s|%s" "$CMD" "$DRY_RUN" "$PROFILE" "$INSTALL_VSCODE" "$WRITE_CONFIG" "$CHAT_MODEL_OVERRIDE"')
    assert_eq "install|true|agentic|false|false|custom:latest" "$output" "parser handles profile, dry-run, models-only, model override"

    output=$(run_sourced 'parse_args repair --config-only --report-dir /tmp/lab-reports; printf "%s|%s|%s|%s|%s|%s" "$CMD" "$INSTALL_OLLAMA" "$PULL_MODEL_FILES" "$WRITE_CONFIG" "$INSTALL_CONTINUE" "$REPORT_DIR"')
    assert_eq "repair|false|false|true|false|/tmp/lab-reports" "$output" "parser handles config-only and report-dir"

    output=$(run_sourced 'parse_args uninstall --preserve-models; printf "%s|%s" "$CMD" "$PRESERVE_MODELS"')
    assert_eq "uninstall|true" "$output" "parser handles preserve-models"
}

test_continue_config_generation() {
    local tmp_home output
    tmp_home=$(mktemp -d)

    output=$(HOME="$tmp_home" LOCALAIBUNDLE_TEST_RAM_GB=32 run_sourced '
        detect_hardware >/dev/null
        mkdir -p "$HOME/.continue" "$HOME/Library/Application Support/Code/User"
        printf "old config\n" > "$HOME/.continue/config.yaml"
        printf "{\n  // user comment\n  \"editor.fontSize\": 14,\n}\n" > "$HOME/Library/Application Support/Code/User/settings.json"
        configure_continue >/dev/null
        validate_continue_config "$HOME/.continue/config.yaml"
        printf "%s|%s|%s|%s|%s|%s" \
            "$(grep -c "^schema: v1$" "$HOME/.continue/config.yaml")" \
            "$(grep -c "      - apply" "$HOME/.continue/config.yaml")" \
            "$(grep -c "model: qwen2.5-coder:14b" "$HOME/.continue/config.yaml")" \
            "$(grep -c "\"continue.telemetryEnabled\": false" "$HOME/Library/Application Support/Code/User/settings.json")" \
            "$(find "$HOME/.continue" -name "config.yaml.bak.*" | wc -l | tr -d " ")" \
            "$?"
    ')

    rm -rf "$tmp_home"
    assert_eq "1|1|1|1|1|0" "$output" "configure_continue writes valid v1 config, disables telemetry, and backs up existing config"
}

test_auto_profiles
test_parser_modes
test_continue_config_generation
