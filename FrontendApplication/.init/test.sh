#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-book-310206-310325/FrontendApplication"
LOG="$WORKSPACE/.setup_logs/test-004.log"
mkdir -p "$WORKSPACE/.setup_logs"
: >"$LOG"
# defaults
PKG_MANAGER="npm"
TYPE="js"
# load persisted values if present
if [ -f "$WORKSPACE/.pkg_manager" ]; then source "$WORKSPACE/.pkg_manager" || true; fi
if [ -f "$WORKSPACE/.project_env" ]; then source "$WORKSPACE/.project_env" || true; fi
cd "$WORKSPACE"
# Determine test runner from package.json dependencies/devDependencies (jest, vitest, ts-jest)
TEST_RUNNER="jest"
node -e "try{const p=require('./package.json');const deps=Object.assign({},p.dependencies||{},p.devDependencies||{});if(deps['vitest']){console.log('vitest');}else if(deps['ts-jest']){console.log('ts-jest');}else if(deps['jest']){console.log('jest');}else{console.log('jest');}}catch(e){console.log('jest');}" >"$LOG.runner" 2>&1 || true
TR=$(tr -d '\n' <"$LOG.runner" || echo "jest")
TEST_RUNNER="${TR:-jest}"
# choose extension: ts if project TYPE is ts or ts-jest present
if [ "$TEST_RUNNER" = "ts-jest" ] || [ "${TYPE:-}" = "ts" ]; then EXT="ts"; else EXT="js"; fi
mkdir -p src/__tests__
TEST_FILE="src/__tests__/sanity.test.${EXT}"
if [ ! -f "$TEST_FILE" ]; then
  if [ "$EXT" = "ts" ]; then
    cat > "$TEST_FILE" <<'TS'
test('sanity', () => { expect(1 + 1).toBe(2); });
TS
  else
    cat > "$TEST_FILE" <<'JS'
test('sanity', () => { expect(1 + 1).toBe(2); });
JS
  fi
fi
# Ensure CI set so runners exit non-interactively
export CI=1
# Log header
echo "$(date -Is) test_runner=${TEST_RUNNER} pkg_manager=${PKG_MANAGER} ext=${EXT}" >>"$LOG"
# Run tests once via package script (respect package manager). Capture full output.
if [ "$PKG_MANAGER" = "yarn" ]; then
  # yarn test: make sure we don't enter interactive watch
  echo "running: yarn test --silent --watchAll=false" >>"$LOG"
  (cd "$WORKSPACE" && yarn test --silent --watchAll=false) >>"$LOG" 2>&1 || { echo "$(date -Is) tests failed (see $LOG)" >>"$LOG"; echo "tests failed (see $LOG)" >&2; exit 13; }
else
  # npm test: pass flags after -- to ensure non-watch
  echo "running: npm test --silent -- --watchAll=false" >>"$LOG"
  (cd "$WORKSPACE" && npm test --silent -- --watchAll=false) >>"$LOG" 2>&1 || { echo "$(date -Is) tests failed (see $LOG)" >>"$LOG"; echo "tests failed (see $LOG)" >&2; exit 14; }
fi
echo "$(date -Is) tests passed" >>"$LOG"
