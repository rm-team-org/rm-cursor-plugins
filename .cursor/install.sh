#!/usr/bin/env bash
# Idempotent development environment setup for the rm-cursor-plugins repository.
# Installs the toolchain pinned by the imported AWS agent toolkit (mise.toml).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Install mise (tool version manager) if it is not already present.
if [ ! -x "$HOME/.local/bin/mise" ] && ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# 2. Activate mise for future interactive shells so its tools are on PATH.
if ! grep -qs 'mise activate' "$HOME/.bashrc"; then
  echo 'eval "$(~/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
fi

# 3. Install the toolchain (Node, Python, uv, gitleaks, markdownlint-cli2)
#    pinned by the imported toolkit's mise.toml.
cd "$REPO_ROOT/agent-toolkit-for-aws"
mise trust
mise install

echo "Development environment ready. Run 'mise run build' in agent-toolkit-for-aws/ to lint, validate, and scan."
