#!/usr/bin/env bash
# ============================================================
# claw-bootstrap.sh — one-command setup of ok-claw (pi fork) + claw extensions
# on a new machine. Idempotent-ish; safe to re-run.
#
# Run from a cloned ok-claw:
#   bash scripts/claw-bootstrap.sh
#
# Env overrides:
#   CLAW_NODE_VERSION  Node version to install/use (default 22.22.3; needs >=22.19.0)
#   LOCAL_TOOLS_DIR    where local-tools lives (default ~/Desktop/my/local-tools)
#   LOCAL_TOOLS_REPO   local-tools git remote (default git@github.com:waybi/local-tools.git)
#   CLAW_EXT_BRANCH    branch carrying the claw extensions (default claw/pi-extensions)
#
# Principle (ADR-005): code syncs via git; state + credentials stay local.
# This script never enters credentials — login is a manual one-time step at the end.
# ============================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
NODE_VERSION="${CLAW_NODE_VERSION:-22.22.3}"
LOCAL_TOOLS_DIR="${LOCAL_TOOLS_DIR:-$HOME/Desktop/my/local-tools}"
LOCAL_TOOLS_REPO="${LOCAL_TOOLS_REPO:-git@github.com:waybi/local-tools.git}"
EXT_BRANCH="${CLAW_EXT_BRANCH:-claw/pi-extensions}"

say() { printf '\n== %s ==\n' "$*"; }

say "ok-claw bootstrap  (root: $HERE)"

# 1) Node via nvm
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install "$NODE_VERSION" >/dev/null
  nvm use "$NODE_VERSION"
  echo "node: $(node -v)"
else
  echo "WARN: nvm not found at $NVM_DIR. Ensure Node >= 22.19.0 is active (current: $(node -v 2>/dev/null || echo none))."
fi

# 2) Build pi
say "npm install + build (pi)"
( cd "$HERE" && npm install && npm run build )

# 3) Claw skills + extensions (distributed via local-tools/agent-skills)
if [ ! -d "$LOCAL_TOOLS_DIR/.git" ]; then
  say "clone local-tools -> $LOCAL_TOOLS_DIR"
  git clone "$LOCAL_TOOLS_REPO" "$LOCAL_TOOLS_DIR"
  git -C "$LOCAL_TOOLS_DIR" checkout "$EXT_BRANCH"   # fresh clone: extensions live on this branch
else
  cur="$(git -C "$LOCAL_TOOLS_DIR" branch --show-current 2>/dev/null || echo '?')"
  if [ "$cur" != "$EXT_BRANCH" ]; then
    echo "NOTE: existing local-tools is on '$cur'; claw extensions live on '$EXT_BRANCH'."
    echo "      To install them, checkout/merge it:  git -C \"$LOCAL_TOOLS_DIR\" checkout $EXT_BRANCH"
  fi
fi
if [ -x "$LOCAL_TOOLS_DIR/tools/agent-skills/scripts/install.sh" ]; then
  say "install claw skills + extensions -> ~/.pi/skills, ~/.pi/agent/extensions"
  ( cd "$LOCAL_TOOLS_DIR/tools/agent-skills" && ./scripts/install.sh pi )
else
  echo "WARN: agent-skills install.sh not found under $LOCAL_TOOLS_DIR (wrong branch?). Skipping extension install."
fi

# 4) Login — manual, never automated (credentials are per-machine, never in git)
say "NEXT — one-time login (manual)"
cat <<EOF
  node "$HERE/packages/coding-agent/dist/cli.js"      # then in the TUI:  /login  ->  ChatGPT Plus/Pro (Codex)
  (token stored in ~/.pi/agent/auth.json, auto-refreshes; never committed)

  Optional — match this machine's default reasoning level to your preference:
    after first run, set "defaultThinkingLevel" in ~/.pi/agent/settings.json
EOF

# 5) Verify (after login)
say "verify (after login)"
echo "  node \"$HERE/packages/coding-agent/dist/cli.js\" --no-tools --no-session -p 'Reply with exactly: OK'"
echo
echo "bootstrap done."
