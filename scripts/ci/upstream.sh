#!/usr/bin/env bash
# The upstream run, called by the owner's tending loop (`release` §C,
# owner 2026-10-24). Runs the bump, then:
# - exit 3, up to date: nothing else
# - exit 0, bumped: commit nix/sources.json to `bump/orca-ide`, force-push,
#   open the one bump PR or update it in place (round 8), and turn on
#   auto-merge so it merges when every required check is green (D10)
# - exit 4, upstream moved a pinned tag or asset: one issue, never reopened
#   while open, and the run fails (round 9)
# - anything else: the run fails, nothing pushed
# GH_TOKEN is the loop's token, so the PR triggers the build; issues go
# through ISSUE_TOKEN when it is set, GH_TOKEN otherwise.
# Usage: upstream.sh
# Env: BUMP, PR_BODY, GIT, GH name the tools (defaults: scripts/bump.sh,
# scripts/bump/pr-body.sh, git, gh);
# SOURCES the pinned file (default nix/sources.json).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bump=${BUMP:-$here/../bump.sh}
pr_body=${PR_BODY:-$here/../bump/pr-body.sh}
git=${GIT:-git}
gh=${GH:-gh}
sources=${SOURCES:-$here/../../nix/sources.json}
branch=bump/orca-ide
issue_token=${ISSUE_TOKEN:-${GH_TOKEN:-}}
issue="upstream moved a released tag or asset"

from=$(jq -r .version "$sources")
rc=0
log=$(bash "$bump" 2>&1) || rc=$?
case "$rc" in
0) ;;
3) exit 0 ;;
4)
  printf '%s\n' "$log" >&2
  if [ "$(GH_TOKEN=$issue_token "$gh" issue list --state open --search "\"$issue\" in:title" --json number --jq length)" = 0 ]; then
    GH_TOKEN=$issue_token "$gh" issue create --title "$issue" --body "$log"
  fi
  exit 1
  ;;
*)
  printf '%s\n' "$log" >&2
  exit 1
  ;;
esac

to=$(jq -r .version "$sources")
title="chore(bump): orca-ide $from -> $to"
# The dependency report is report-only (round 9): its failure never stops
# the bump.
body=$(bash "$pr_body" "v$from" "v$to") || body="The dependency report failed; see the run's log."
"$git" checkout -B "$branch"
"$git" commit -m "$title" -- nix/sources.json
"$git" push --force origin "$branch"
if [ "$("$gh" pr view "$branch" --json state --jq '.state == "OPEN"' 2>/dev/null)" = true ]; then
  "$gh" pr edit "$branch" --title "$title" --body "$body"
else
  "$gh" pr create --head "$branch" --title "$title" --body "$body"
fi
"$gh" pr merge "$branch" --auto --merge
