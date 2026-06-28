#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export LOCALAIBUNDLE_TEST_UNAME_S=Darwin
export LOCALAIBUNDLE_TEST_UNAME_M=arm64
export LOCALAIBUNDLE_TEST_RAM_GB=32
export LOCALAIBUNDLE_TEST_CPU_BRAND="Demo Apple Silicon"
export LOCALAIBUNDLE_TEST_GPU_CORES=16

cd "$ROOT_DIR"

printf '\n$ ./install.sh --dry-run --profile professional --no-vscode\n'
./install.sh --dry-run --profile professional --no-vscode

printf '\n$ bash tests/install-sandbox.sh\n'
bash tests/install-sandbox.sh
