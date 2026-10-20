#!/usr/bin/env bats
# scripts/agents/versions.sh (nix/agents V3): every agent's command answers
# `--version` with exit 0, offline, with no key and an empty HOME.

bats_require_minimum_version 1.5.0

setup() {
  versions="$BATS_TEST_DIRNAME/../../../../scripts/agents/versions.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir bin
  cat >bin/good <<'STUB'
#!/usr/bin/env bash
[ "$1" = --version ] && [ -d "$HOME" ] && [ "$HOME" != "$REAL_HOME" ] && echo "good 1.0"
STUB
  cat >bin/bad <<'STUB'
#!/usr/bin/env bash
echo "no key" >&2
exit 3
STUB
  chmod +x bin/*
  export REAL_HOME="$HOME"
  export out="$BATS_TEST_TMPDIR/out"
}

@test "commands that answer --version pass, each in its own empty HOME" {
  run --separate-stderr "$versions" good="$PWD/bin/good"
  [ "$status" -eq 0 ]
  [ -f "$out" ]
}

@test "a command that fails is refused with its exit code and output" {
  run --separate-stderr "$versions" good="$PWD/bin/good" bad="$PWD/bin/bad"
  [ "$status" -eq 1 ]
  [ "$stderr" = "versions: bad: \`$PWD/bin/bad --version\` exited 3: no key (nix/agents V3)" ]
  [ ! -e "$out" ]
}

@test "no agents is a usage error, exit 2" {
  run --separate-stderr "$versions"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: versions.sh ID=COMMAND..." ]
}
