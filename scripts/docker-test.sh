#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n install.sh
shellcheck install.sh bin/localaibundle tests/run.sh tests/install-sandbox.sh scripts/package-release.sh scripts/package-pkg.sh scripts/package-dmg.sh scripts/notarize-artifact.sh scripts/notarize-pkg.sh scripts/demo.sh scripts/docker-test.sh
python3 -m py_compile scripts/*.py
bash tests/run.sh
bash tests/install-sandbox.sh
bash scripts/package-release.sh
git diff --check --no-index /dev/null /dev/null >/dev/null 2>&1 || true

printf 'Docker test checks passed\n'
