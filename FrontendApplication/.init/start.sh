#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-book-310206-310325/FrontendApplication"
LOG_DIR="$WORKSPACE/.setup_logs"
LOG="$LOG_DIR/start-007.log"
mkdir -p "$LOG_DIR"
cd "$WORKSPACE"
# Default package manager; prefer persisted choice if present
PKG_MANAGER="npm"
if [ -f "$WORKSPACE/.pkg_manager" ]; then
  # .pkg_manager expected to contain a simple assignment like: PKG_MANAGER="yarn"
  # shellcheck disable=SC1090
  source "$WORKSPACE/.pkg_manager" || true
fi
export NODE_ENV=development
export PORT=${PORT:-3000}
# Ensure node is available
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node not found on PATH" >&2
  exit 2
fi
# Launch dev server in foreground and tee logs
if [ "${PKG_MANAGER}" = "yarn" ]; then
  exec yarn start 2>&1 | tee -a "$LOG"
else
  exec npm start 2>&1 | tee -a "$LOG"
fi
