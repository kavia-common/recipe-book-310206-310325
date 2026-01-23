#!/usr/bin/env bash
set -euo pipefail
# Deterministic dependency installer for FrontendApplication (deps-003)
WORKSPACE="/home/kavia/workspace/code-generation/recipe-book-310206-310325/FrontendApplication"
LOG="$WORKSPACE/.setup_logs/deps-003.log"
mkdir -p "$WORKSPACE/.setup_logs"; touch "$LOG"
# load existing project env if present
PKG_ENV=""; TYPE="js"
if [ -f "$WORKSPACE/.project_env" ]; then source "$WORKSPACE/.project_env" || true; fi
cd "$WORKSPACE"
# choose package manager: prefer lockfiles, else prefer installed binary
PKG_MANAGER="npm"
if [ -f yarn.lock ]; then PKG_MANAGER="yarn"
elif [ -f package-lock.json ]; then PKG_MANAGER="npm"
elif command -v yarn >/dev/null 2>&1; then PKG_MANAGER="yarn"
fi
# persist choice
echo "PKG_MANAGER=$PKG_MANAGER" > "$WORKSPACE/.pkg_manager"
echo "$(date -Is) chosen_pkg=$PKG_MANAGER" >>"$LOG"
# install project deps deterministically
if [ "$PKG_MANAGER" = "yarn" ]; then
  # yarn install (silent) - respects yarn.lock
  yarn install --silent >>"$LOG" 2>&1 || { echo "yarn install failed (see $LOG)" >&2; exit 8; }
else
  # npm path: prefer CI when lockfile present
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund --silent >>"$LOG" 2>&1 || { echo "npm ci failed (see $LOG)" >&2; exit 9; }
  else
    npm install --no-audit --no-fund --silent >>"$LOG" 2>&1 || { echo "npm install failed (see $LOG)" >&2; exit 10; }
  fi
fi
# determine which dev deps are missing (eslint, prettier, jest, serve)
MISSING=()
# Use node to inspect package.json merging dependencies/devDependencies
if [ -f package.json ]; then
  mapfile -t MISSING < <(node -e "try{const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));const deps=Object.assign({},p.dependencies||{},p.devDependencies||{});['eslint','prettier','jest','serve'].forEach(d=>{if(!deps[d])console.log(d)});}catch(e){process.exit(0)}") || true
fi
# Install missing dev deps locally if any
if [ ${#MISSING[@]} -gt 0 ]; then
  if [ "$PKG_MANAGER" = "yarn" ]; then
    yarn add -D --silent "${MISSING[@]}" >>"$LOG" 2>&1 || { echo "yarn add devDeps failed (see $LOG)" >&2; exit 11; }
  else
    npm i -D --no-audit --no-fund --silent "${MISSING[@]}" >>"$LOG" 2>&1 || { echo "npm install devDeps failed (see $LOG)" >&2; exit 12; }
  fi
else
  echo "$(date -Is) devDeps already satisfied" >>"$LOG"
fi
# Log tool versions (best-effort)
node -v >>"$LOG" 2>&1 || true
npm -v >>"$LOG" 2>&1 || true
command -v yarn >/dev/null 2>&1 && yarn -v >>"$LOG" 2>&1 || true
# Final marker
echo "$(date -Is) deps install complete" >>"$LOG"
exit 0
