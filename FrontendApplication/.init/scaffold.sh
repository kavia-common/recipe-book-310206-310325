#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/recipe-book-310206-310325/FrontendApplication"
LOG="$WORKSPACE/.setup_logs/scaffold-002.log"
mkdir -p "$WORKSPACE" && mkdir -p "$(dirname "$LOG")"
# load persisted project env (defaults)
PKG_MANAGER="npm"; TYPE="js"
if [ -f "$WORKSPACE/.project_env" ]; then source "$WORKSPACE/.project_env" || true; fi
cd "$WORKSPACE"
# skip if React markers present
if [ -f package.json ]; then
  if node -e "try{const p=require('./package.json');const deps=Object.assign({},p.dependencies||{},p.devDependencies||{});if(deps.react||deps['react-scripts']||deps.vite) process.exit(0);}catch(e){} process.exit(1)" 2>/dev/null; then
    printf "%s already has a React project, skipping scaffold\n" "$WORKSPACE" >"$LOG"
    exit 0
  fi
fi
TMPDIR=$(mktemp -d -t cra-scaffold-XXXX)
trap 'rm -rf "$TMPDIR"' EXIT
TEMPLATE=""; [ "${TYPE}" = "ts" ] && TEMPLATE="--template typescript"
# prefer installed create-react-app; fallback to npx
if command -v create-react-app >/dev/null 2>&1; then
  (cd "$TMPDIR" && create-react-app . $TEMPLATE) >>"$LOG" 2>&1 || { printf "CRA failed (see %s)\n" "$LOG" >&2; exit 5; }
else
  (cd "$TMPDIR" && npx --yes create-react-app@latest . $TEMPLATE) >>"$LOG" 2>&1 || { printf "npx CRA failed (see %s)\n" "$LOG" >&2; exit 6; }
fi
# if preferred manager is yarn but scaffold produced package-lock.json, import to yarn.lock
if [ "$PKG_MANAGER" = "yarn" ] && [ -f "$TMPDIR/package-lock.json" ] && command -v yarn >/dev/null 2>&1; then
  (cd "$TMPDIR" && yarn import >>"$LOG" 2>&1) || true
fi
# safe copy: only add missing files; do not silently overwrite existing files
shopt -s dotglob
for f in "$TMPDIR"/* "$TMPDIR"/.*; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "." ] || [ "$base" = ".." ] || true
  if [ ! -e "$WORKSPACE/$base" ]; then
    cp -a "$f" "$WORKSPACE/"
  fi
done
# merge package.json: preserve existing fields, add scripts/deps from scaffold when missing
if [ -f "$TMPDIR/package.json" ]; then
  if [ -f "$WORKSPACE/package.json" ]; then
    node -e "const fs=require('fs');const wp='$WORKSPACE'.replace(/'/g,\\"'\\");const tp='$TMPDIR'.replace(/'/g,\\"'\\");const a=JSON.parse(fs.readFileSync(\"$WORKSPACE/package.json\"));const b=JSON.parse(fs.readFileSync(\"$TMPDIR/package.json\"));a.scripts=Object.assign({},b.scripts||{},a.scripts||{});a.dependencies=Object.assign({},b.dependencies||{},a.dependencies||{});a.devDependencies=Object.assign({},b.devDependencies||{},a.devDependencies||{});fs.writeFileSync(\"$WORKSPACE/package.json\",JSON.stringify(a,null,2))"
  else
    cp -a "$TMPDIR/package.json" "$WORKSPACE/"
  fi
fi
# validate essential artifacts exist after copy
if [ ! -f "$WORKSPACE/package.json" ] || [ ! -f "$WORKSPACE/public/index.html" ] || ( [ ! -f "$WORKSPACE/src/index.js" ] && [ ! -f "$WORKSPACE/src/index.tsx" ] ); then
  printf "%s missing scaffold artifacts after copy (see %s)\n" "$WORKSPACE" "$LOG" >>"$LOG"
  exit 7
fi
# ensure package.json has start/build/test scripts (do not overwrite existing)
node -e "const fs=require('fs');const pth=\"$WORKSPACE/package.json\";let p=JSON.parse(fs.readFileSync(pth));p.scripts=p.scripts||{};p.scripts.start=p.scripts.start||'react-scripts start';p.scripts.build=p.scripts.build||'react-scripts build';p.scripts.test=p.scripts.test||'react-scripts test';fs.writeFileSync(pth,JSON.stringify(p,null,2));"
# minimal lint configs only if absent
[ -f "$WORKSPACE/.eslintrc.json" ] || cat > "$WORKSPACE/.eslintrc.json" <<'ESL'
{ "extends": ["react-app", "eslint:recommended"], "env": {"browser": true, "es2021": true} }
ESL
[ -f "$WORKSPACE/.prettierrc" ] || cat > "$WORKSPACE/.prettierrc" <<'PRE'
{ "singleQuote": true, "trailingComma": "es5" }
PRE
# persist chosen PKG_MANAGER and TYPE to project env
printf "PKG_MANAGER=%s\nTYPE=%s\n" "$PKG_MANAGER" "$TYPE" > "$WORKSPACE/.project_env"
printf "%s scaffold complete, pkg=%s type=%s\n" "$(date -Is)" "$PKG_MANAGER" "$TYPE" >>"$LOG"
exit 0
