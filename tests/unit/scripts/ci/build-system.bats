#!/usr/bin/env bats
# scripts/ci/build-system.sh (`release` T1): build every package and check
# the flake has for one system, by name, so a runner can build a system
# that is not its own (x86_64-darwin under Rosetta). On x86_64-darwin the
# agent outputs are evaluated, not built: under Rosetta they compile
# nodejs from source past the job's timeout (owner 2026-10-24). nix is a
# stub.

bats_require_minimum_version 1.5.0

setup() {
  build="$BATS_TEST_DIRNAME/../../../../scripts/ci/build-system.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
case "$*" in
"eval --json .#packages.x86_64-darwin --apply builtins.attrNames") echo '["default","orca-ide","orca-ide-agents"]' ;;
"eval --json .#checks.x86_64-darwin --apply builtins.attrNames") echo '["agents-version","arch","codesign"]' ;;
"eval --json .#packages.aarch64-darwin --apply builtins.attrNames") echo '["orca-ide","orca-ide-agents"]' ;;
"eval --json .#checks.aarch64-darwin --apply builtins.attrNames") echo '["agents-version"]' ;;
eval\ --raw\ *.drvPath) echo /nix/store/x.drv ;;
"eval --json .#packages.x86_64-linux --apply builtins.attrNames") echo '[]' ;;
"eval --json .#checks.x86_64-linux --apply builtins.attrNames") echo '["sources"]' ;;
build*) [ -z "${STUB_FAIL:-}" ] ;;
esac
STUB
  chmod +x stubs/nix
  export NIX="$BATS_TEST_TMPDIR/stubs/nix"
}

@test "every package and check of the system, in one build" {
  run --separate-stderr "$build" aarch64-darwin
  [ "$status" -eq 0 ]
  [ "$(tail -1 nix.log)" = "build --no-link --print-build-logs .#packages.aarch64-darwin.orca-ide .#packages.aarch64-darwin.orca-ide-agents .#checks.aarch64-darwin.agents-version" ]
}

@test "x86_64-darwin evaluates the agent outputs and builds the rest" {
  run --separate-stderr "$build" x86_64-darwin
  [ "$status" -eq 0 ]
  grep -qx "eval --raw .#packages.x86_64-darwin.orca-ide-agents.drvPath" nix.log
  grep -qx "eval --raw .#checks.x86_64-darwin.agents-version.drvPath" nix.log
  [ "$(tail -1 nix.log)" = "build --no-link --print-build-logs .#packages.x86_64-darwin.default .#packages.x86_64-darwin.orca-ide .#checks.x86_64-darwin.arch .#checks.x86_64-darwin.codesign" ]
}

@test "a system with checks and no package yet still builds its checks" {
  run --separate-stderr "$build" x86_64-linux
  [ "$status" -eq 0 ]
  [ "$(tail -1 nix.log)" = "build --no-link --print-build-logs .#checks.x86_64-linux.sources" ]
}

@test "a failed build fails the job" {
  export STUB_FAIL=1
  run --separate-stderr "$build" x86_64-darwin
  [ "$status" -ne 0 ]
}

@test "anything but one system is a usage error, exit 2" {
  run --separate-stderr "$build"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: build-system.sh SYSTEM" ]
}
