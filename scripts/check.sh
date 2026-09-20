#!/usr/bin/env bash
# One command that tells you whether the library is sound: unit tests, a bundle, and two checks
# that the bundle actually RUNS (loadfile only parses, which is how a broken release artifact went
# unnoticed for a long time). Everything here is read-only apart from the files it writes under
# output/ and dist/.
#
#   ./scripts/check.sh            run everything
#   ./scripts/check.sh tests      unit tests only (fastest)
#   ./scripts/check.sh bundle     build + prove the bundle runs
#
# Why not `make check`: make on this machine needs an Xcode licence, and the Makefile calls `lua`,
# which here is 5.4 and cannot run this 5.1-era code. This script finds a working interpreter.
set -u
cd "$(dirname "$0")/.." || exit 1

BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
step() { printf '\n%s== %s ==%s\n' "$BOLD" "$1" "$OFF"; }
ok()   { printf '   %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
bad()  { printf '   %s✗ %s%s\n' "$RED" "$1" "$OFF"; FAILED=1; }
FAILED=0

# Lua 5.1 semantics required (setfenv, the 5.1 string library). luajit is the usual one here.
LUA=""
for c in luajit lua5.1 lua51 lua; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -e 'assert(setfenv)' >/dev/null 2>&1; then LUA="$c"; break; fi
done
[ -z "$LUA" ] && { echo "${RED}no Lua 5.1-compatible interpreter found (tried luajit, lua5.1, lua51, lua)${OFF}"; exit 1; }

BUNDLER="$(command -v lua-bundler || echo "$HOME/Documents/lua-bundler/lua-bundler")"

WHAT="${1:-all}"

if [ "$WHAT" = "all" ] || [ "$WHAT" = "tests" ]; then
  step "unit tests  ${DIM}($LUA)${OFF}"
  pass=0; fail=0; badfiles=""
  for f in tests/*_test.lua; do
    out="$("$LUA" "$f" 2>&1)"
    if [ $? -ne 0 ]; then
      badfiles="$badfiles $f"
      printf '   %s✗ %s%s\n' "$RED" "$f" "$OFF"
      echo "$out" | grep -E '^FAIL' -A 2 | head -6 | sed 's/^/      /'
    fi
    line="$(echo "$out" | grep TOTAL)"
    pass=$((pass + $(echo "$line" | awk '{print $2}')))
    fail=$((fail + $(echo "$line" | awk '{print $4}')))
  done
  if [ -n "$badfiles" ]; then bad "$pass passed, $fail failed"; else ok "$pass passed, 0 failed"; fi
fi

if [ "$WHAT" = "all" ] || [ "$WHAT" = "bundle" ]; then
  step "bundle"
  mkdir -p output dist
  if "$BUNDLER" -e ./main.lua -o ./output/bundle.lua >/dev/null 2>&1; then ok "built output/bundle.lua"; else bad "bundler failed"; fi

  # Parses AND runs. A bundle can parse perfectly and still die on its first window, which is
  # exactly what --release and --obfuscate 2/3 produce.
  if "$LUA" scripts/verify_bundle.lua >/dev/null 2>&1; then ok "verify_bundle (strict mock: controls, re-skin, graceful close)"
  else bad "verify_bundle failed:"; "$LUA" scripts/verify_bundle.lua 2>&1 | head -3 | sed 's/^/      /'; fi

  if "$BUNDLER" -e ./main.lua -o ./dist/ez-rbx-ui.lua >/dev/null 2>&1 &&
     "$LUA" scripts/smoke_bundle.lua ./dist/ez-rbx-ui.lua >/dev/null 2>&1; then ok "dist/ez-rbx-ui.lua builds a window"
  else bad "dist bundle does not run:"; "$LUA" scripts/smoke_bundle.lua ./dist/ez-rbx-ui.lua 2>&1 | head -3 | sed 's/^/      /'; fi

  if "$BUNDLER" -e ./example/showcase.lua -o ./dist/showcase.lua >/dev/null 2>&1; then ok "dist/showcase.lua built"
  else bad "showcase bundle failed"; fi
fi

if [ "$WHAT" = "all" ]; then
  step "docs in sync"
  if command -v node >/dev/null 2>&1; then
    if node scripts/check-skill.mjs >/dev/null 2>&1; then ok "skill reference matches the source"
    else bad "check-skill:"; node scripts/check-skill.mjs 2>&1 | head -5 | sed 's/^/      /'; fi
  else
    printf '   %s- node not found, skipped%s\n' "$DIM" "$OFF"
  fi
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then printf '%s%sALL GOOD%s\n' "$BOLD" "$GREEN" "$OFF"; exit 0; fi
printf '%s%sSOMETHING FAILED (see above)%s\n' "$BOLD" "$RED" "$OFF"; exit 1
