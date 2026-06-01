#!/usr/bin/env bash
# ============================================================
# claw-doctor.sh — health check for an ok-claw install. Read-only.
# Pairs with claw-bootstrap.sh: bootstrap sets up, doctor verifies.
#   bash scripts/claw-doctor.sh
# Exit 0 = healthy; 1 = one or more problems.
# ============================================================
set -uo pipefail   # not -e: run every check even if one fails

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
note(){ printf '  - %s\n' "$*"; }

echo "== ok-claw doctor (root: $HERE) =="

# 1) Node >= 22.19.0
if command -v node >/dev/null 2>&1; then
  v="$(node -v | sed 's/^v//')"
  major="${v%%.*}"; minor="$(printf '%s' "$v" | cut -d. -f2)"
  if [ "$major" -gt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -ge 19 ]; }; then
    ok "node $v (>= 22.19.0)"
  else
    bad "node $v is < 22.19.0 — run: nvm use 22.22.3"
  fi
else
  bad "node not found on PATH"
fi

# 2) pi built
if [ -f "$HERE/packages/coding-agent/dist/cli.js" ]; then
  ok "pi built (packages/coding-agent/dist/cli.js)"
else
  bad "pi not built — run: npm run build"
fi

# 3) Logged in
if [ -f "$HOME/.pi/agent/auth.json" ]; then
  ok "provider login present (~/.pi/agent/auth.json)"
else
  bad "not logged in — run pi, then /login (ChatGPT Plus/Pro Codex)"
fi

# 4) Extensions installed, no dangling symlinks
EXTDIR="$HOME/.pi/agent/extensions"
if [ -d "$EXTDIR" ]; then
  n=0; dangling=0
  for f in "$EXTDIR"/*.ts; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    n=$((n + 1))
    if [ -L "$f" ] && [ ! -e "$f" ]; then dangling=$((dangling + 1)); fi
  done
  if [ "$n" -eq 0 ]; then
    bad "no extensions in $EXTDIR — run: (cd local-tools/tools/agent-skills && ./scripts/install.sh pi)"
  elif [ "$dangling" -gt 0 ]; then
    bad "$dangling dangling extension symlink(s) in $EXTDIR — re-run install.sh pi"
  else
    ok "$n extension(s) installed, no dangling symlinks"
  fi
else
  bad "no $EXTDIR — run agent-skills install.sh pi"
fi

# 5) Skills dir (optional)
if [ -d "$HOME/.pi/skills" ]; then
  ok "skills dir present (~/.pi/skills)"
else
  note "no ~/.pi/skills yet (optional; only if pi-targeted skills are installed)"
fi

# 6) Default reasoning level (informational)
if [ -f "$HOME/.pi/agent/settings.json" ]; then
  lvl="$(grep -o '"defaultThinkingLevel"[^,}]*' "$HOME/.pi/agent/settings.json" 2>/dev/null | sed 's/.*: *"//; s/"//')"
  [ -n "${lvl:-}" ] && note "default reasoning level: $lvl" || note "default reasoning level: (unset → medium)"
fi

echo
echo "== $PASS ok, $FAIL problem(s) =="
if [ "$FAIL" -eq 0 ]; then echo "healthy."; exit 0; else echo "see ✗ above."; exit 1; fi
