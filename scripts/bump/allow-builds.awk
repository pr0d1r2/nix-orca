# Packages a pnpm-workspace.yaml lets run install scripts (lock-diff.sh):
# each `allowBuilds:` entry set to true, one name per line.
/^[^ #]/ { section = $0 }
section == "allowBuilds:" && /^  [^ ].*: *true *$/ {
  name = $0
  sub(/^  /, "", name)
  sub(/: *true *$/, "", name)
  gsub(/'/, "", name)
  print name
}
