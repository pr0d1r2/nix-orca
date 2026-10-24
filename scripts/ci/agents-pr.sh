#!/usr/bin/env bash
# The agent-input PR (nix/agents T4): update every agent input; when
# flake.lock moved, commit it to `agents/update`, force-push, and open the
# one PR or update it in place. Never auto-merged: an update changes
# third-party nix code evaluated in this build, and the owner merges after
# reading the diff (round 9). Called by the owner's tending loop with its
# token in GH_TOKEN, so the PR triggers the build (owner 2026-10-24).
# Usage: agents-pr.sh
# Env: AGENTS_UPDATE, GIT, GH name the tools (defaults:
# scripts/agents-update.sh, git, gh).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
update=${AGENTS_UPDATE:-$here/../agents-update.sh}
git=${GIT:-git}
gh=${GH:-gh}
branch=agents/update
title="chore(agents): update agent inputs"

bash "$update"
if "$git" diff --quiet -- flake.lock; then
  exit 0
fi
"$git" checkout -B "$branch"
"$git" commit -m "$title" -- flake.lock
"$git" push --force origin "$branch"
if [ "$("$gh" pr view "$branch" --json state --jq '.state == "OPEN"' 2>/dev/null)" != true ]; then
  "$gh" pr create --head "$branch" --title "$title" --body "Written by scripts/agents-update.sh. Read the package.nix diffs before merging (nix/agents §C)."
fi
