#!/usr/bin/env bats
# scripts/closure-budget.sh (scripts T4, D14, nix/linux V6): a package
# closure stays within its system's budget in .closure-budget. nix is a
# stub reporting a closure size.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  budget="$BATS_TEST_DIRNAME/../../../scripts/closure-budget.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
printf '%s\t%s\n' "${@: -1}" "${STUB_SIZE:-863000000}"
STUB
  chmod +x stubs/nix
  printf '# system bytes\naarch64-darwin 900000000\nx86_64-linux 700000000\n' >budget
  export NIX="$BATS_TEST_TMPDIR/stubs/nix" CLOSURE_BUDGET="$BATS_TEST_TMPDIR/budget"
  # The dev shell exports mkShell's `out`; only a check derivation sets it.
  unset out
}

@test "a closure within budget passes and says how much room is left" {
  run --separate-stderr "$budget" aarch64-darwin /nix/store/x-orca-ide
  [ "$status" -eq 0 ]
  [ "$output" = "closure-budget: aarch64-darwin 863000000 of 900000000 bytes (95%)" ]
  grep -q "path-info -S /nix/store/x-orca-ide" nix.log
}

@test "a closure over budget fails" {
  export STUB_SIZE=700000001
  run --separate-stderr "$budget" x86_64-linux /nix/store/y-orca-ide
  [ "$status" -eq 1 ]
  [ "$stderr" = "closure-budget: x86_64-linux 700000001 bytes, budget 700000000; raise it in its own reviewed commit (D14)" ]
}

@test "a system with no budget fails" {
  run --separate-stderr "$budget" aarch64-linux /nix/store/z-orca-ide
  [ "$status" -eq 1 ]
  [ "$stderr" = "closure-budget: no budget for aarch64-linux in $CLOSURE_BUDGET" ]
}

@test "anything but a system and a path is a usage error, exit 2" {
  run --separate-stderr "$budget" aarch64-darwin
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: closure-budget.sh SYSTEM STORE-PATH" ]
}

@test "in a check derivation the size comes from closureInfo's total-nar-size" {
  echo 650000000 >total-nar-size
  export CLOSURE_SIZE_FILE=$BATS_TEST_TMPDIR/total-nar-size
  run --separate-stderr "$budget" x86_64-linux /nix/store/y-orca-ide
  [ "$status" -eq 0 ]
  [ "$output" = "closure-budget: x86_64-linux 650000000 of 700000000 bytes (92%)" ]
  [ ! -e nix.log ]
}

@test "a pass writes \$out when it is set, a failure does not" {
  export out=$BATS_TEST_TMPDIR/out
  run --separate-stderr "$budget" aarch64-darwin /nix/store/x-orca-ide
  [ "$status" -eq 0 ]
  [ -e "$out" ]
  rm "$out"
  export STUB_SIZE=900000001
  run --separate-stderr "$budget" aarch64-darwin /nix/store/x-orca-ide
  [ "$status" -eq 1 ]
  [ ! -e "$out" ]
}
