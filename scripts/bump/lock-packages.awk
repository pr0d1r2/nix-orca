# Every package in a pnpm-lock.yaml (lock-diff.sh): "name version" per key
# under each document's top-level `packages:` section. A key is `name@ver`
# or `'@scope/name@ver'`; the version is what follows the last `@`.
/^[^ #]/ { section = $0 }
section == "packages:" && /^  [^ ]/ {
  key = $0
  sub(/^  /, "", key)
  sub(/:$/, "", key)
  gsub(/'/, "", key)
  at = match(substr(key, 2), /@[^@]*$/)
  if (at) print substr(key, 1, at), substr(key, at + 2)
}
