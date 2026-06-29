#!/usr/bin/env bash
# Auto-checkpoint: commit + push on Stop. Registered in .claude/settings.json.
# ALWAYS exits 0 so it never blocks the agent from stopping.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || { echo "[checkpoint] no origin remote; skip"; exit 0; }

# Nothing changed (ignored files don't show here) -> no-op.
[ -z "$(git status --porcelain)" ] && exit 0

git add -A

# Secret guard (public repo): abort if staged content looks like a private key / token.
hits="$(git diff --cached -U0 \
  | grep -E -- '-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36,}|AKIA[0-9A-Z]{16}|PRIVATE_KEY[[:space:]]*=[[:space:]]*0x?[0-9a-fA-F]{64}' \
  || true)"
if [ -n "$hits" ]; then
  git reset -q
  echo "[checkpoint] ABORTED: possible secret in staged changes; nothing committed/pushed." >&2
  exit 0
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
git commit -q \
  -m "checkpoint: ${ts}" \
  -m "Auto-commit via Stop hook." \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" || exit 0

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git push -q origin "HEAD:${branch}" || echo "[checkpoint] push failed (retry next checkpoint)" >&2
else
  git push -q -u origin "${branch}" || echo "[checkpoint] initial push failed" >&2
fi
exit 0
