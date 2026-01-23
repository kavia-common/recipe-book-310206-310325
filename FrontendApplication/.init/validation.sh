#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-book-310206-310325/FrontendApplication"
LOG="$WORKSPACE/.setup_logs/validation-005.log"
mkdir -p "$WORKSPACE/.setup_logs"; touch "$LOG"
cd "$WORKSPACE"
PORT=${PORT:-3000}
SERVE_BIN="$WORKSPACE/node_modules/.bin/serve"
if [ ! -x "$SERVE_BIN" ]; then echo "$(date -Is) local serve not found, please ensure deps step installed it" >>"$LOG"; exit 18; fi
# start serve in background, capture PID
"$SERVE_BIN" -s build -l "$PORT" >>"$LOG" 2>&1 &
SERVER_PID=$!
# small pause to let process start and record PGID
sleep 0.5
PGID=$(ps -o pgid= "$SERVER_PID" 2>/dev/null | tr -d ' ' || echo "")
# wait for server readiness (up to 60s)
TRIES=0; MAX=60
until curl -sSf "http://127.0.0.1:$PORT" >/dev/null 2>&1 || [ $TRIES -ge $MAX ]; do sleep 1; TRIES=$((TRIES+1)); done
if [ $TRIES -ge $MAX ]; then echo "$(date -Is) server did not start (see $LOG)" >>"$LOG"; # cleanup
  if [ -n "$PGID" ]; then kill -- -"${PGID}" >/dev/null 2>&1 || true; fi
  kill -TERM "$SERVER_PID" >/dev/null 2>&1 || true
  exit 19
fi
# smoke test: accept 200/301/302
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT" ) || true
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "301" ] && [ "$HTTP_CODE" != "302" ]; then echo "$(date -Is) smoke test failed code=$HTTP_CODE" >>"$LOG"; curl -s "http://127.0.0.1:$PORT" >>"$LOG" 2>&1 || true; # cleanup
  if [ -n "$PGID" ]; then kill -- -"${PGID}" >/dev/null 2>&1 || true; fi
  kill -TERM "$SERVER_PID" >/dev/null 2>&1 || true
  exit 20
fi
# cleanup: prefer process-group kill, fallback to PID
if [ -n "$PGID" ]; then kill -- -"${PGID}" >/dev/null 2>&1 || true; fi
sleep 1
if ps -p "$SERVER_PID" >/dev/null 2>&1; then kill -TERM "$SERVER_PID" >/dev/null 2>&1 || true; sleep 1; if ps -p "$SERVER_PID" >/dev/null 2>&1; then kill -9 "$SERVER_PID" >/dev/null 2>&1 || true; fi; fi
echo "$(date -Is) validation completed" >>"$LOG"
exit 0
