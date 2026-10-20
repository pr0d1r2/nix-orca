# The agent table of tui-agent-config.ts, one line per agent: id, detectCmd,
# aliases (scripts/agents/tui-ids.sh). An entry opens at two-space indent
# with `id: {` or `'id': {`; its first detectCmd and detectCmdAliases count.
/^const TUI_AGENT_CONFIG_SOURCE/ { table = 1; next }
table && /^}/ { flush(); table = 0 }
!table { next }
/^  ('[a-z0-9-]+'|[a-z0-9]+): \{/ {
  flush()
  id = $1
  gsub(/[:']/, "", id)
}
id != "" && cmd == "" && match($0, /detectCmd: '[^']+'/) {
  cmd = substr($0, RSTART + 12, RLENGTH - 13)
}
id != "" && aliases == "" && match($0, /detectCmdAliases: \[[^]]*\]/) {
  aliases = substr($0, RSTART + 19, RLENGTH - 20)
  gsub(/[',]/, "", aliases)
}
function flush() {
  if (id != "" && cmd != "") print id, cmd (aliases == "" ? "" : " " aliases)
  id = ""; cmd = ""; aliases = ""
}
