#!/usr/bin/env bash
# Every agent Orca knows (nix/agents V1, V5), read from upstream's
# src/shared/tui-agent-config.ts: one line each, the id, its detectCmd,
# then its detectCmdAliases. The parser is awk, in tui-ids.awk beside
# this script. A file with no agent in its table fails.
# Usage: tui-ids.sh TUI-AGENT-CONFIG-TS
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: tui-ids.sh TUI-AGENT-CONFIG-TS" >&2
  exit 2
fi
here=$(dirname "${BASH_SOURCE[0]}")

agents=$(awk -f "$here/tui-ids.awk" "$1")
if [ -z "$agents" ]; then
  echo "tui-ids: $1: no agents in TUI_AGENT_CONFIG_SOURCE" >&2
  exit 1
fi
printf '%s\n' "$agents"
