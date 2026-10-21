#!/usr/bin/env bats
# scripts/build/deb-piece.sh (nix/bin T2): the install phase of a
# fixed-output piece cut from upstream's .deb, sourced by stdenv under its
# `set -eu -o pipefail`. dpkg-deb and runHook are stubs.

bats_require_minimum_version 1.5.0

setup() {
  script="$BATS_TEST_DIRNAME/../../../../scripts/build/deb-piece.sh"
  log=$BATS_TEST_TMPDIR/log
  mkdir -p "$BATS_TEST_TMPDIR/stubs" "$BATS_TEST_TMPDIR/build"
  cd "$BATS_TEST_TMPDIR/build" || exit 1
  cat >"$BATS_TEST_TMPDIR/stubs/dpkg-deb" <<'STUB'
#!/usr/bin/env bash
echo "dpkg-deb $*" >>"$BATS_TEST_TMPDIR/log"
[ "$1" = -x ] || exit 2
mkdir -p "$3/opt/Orca/resources/orcad-template/targets" "$3/opt/Orca/resources/node_modules"
printf 'x\n' >"$3/opt/Orca/resources/orcad-template/orcad.js"
printf '#!/usr/bin/env node\n' >"$3/opt/Orca/resources/orcad-template/targets/run"
chmod +x "$3/opt/Orca/resources/orcad-template/targets/run"
STUB
  chmod +x "$BATS_TEST_TMPDIR/stubs/dpkg-deb"
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export src=/store/orca-ide_1.4.232_amd64.deb
  export out=$BATS_TEST_TMPDIR/out
  export ORCA_PIECE=opt/Orca/resources/orcad-template
}

runHook() {
  echo "runHook $*" >>"$log"
}

# Its own shell: bats runs a function inside `||`, where errexit is off.
install_phase() {
  export -f runHook
  export log
  bash -eu -o pipefail -c '. "$1"' _ "$script"
}

@test "the piece is the .deb's subtree, as it is" {
  run install_phase
  [ "$status" -eq 0 ]
  grep -qxF "dpkg-deb -x /store/orca-ide_1.4.232_amd64.deb deb" "$log"
  [ "$(cat "$out/orcad.js")" = x ]
  [ -x "$out/targets/run" ]
  [ "$(head -1 "$out/targets/run")" = "#!/usr/bin/env node" ]
}

@test "only that subtree: nothing else of the .deb" {
  run install_phase
  [ "$status" -eq 0 ]
  [ ! -e "$out/node_modules" ]
  [ ! -e "$out/opt" ]
}

@test "a path the .deb does not have fails the phase" {
  export ORCA_PIECE=opt/Orca/resources/onboarding
  run install_phase
  [ "$status" -ne 0 ]
  [ ! -e "$out" ]
}

@test "pre and post install hooks run around it" {
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$log")" = "runHook preInstall" ]
  [ "$(tail -1 "$log")" = "runHook postInstall" ]
}

@test "without ORCA_PIECE the phase fails" {
  unset ORCA_PIECE
  run install_phase
  [ "$status" -ne 0 ]
}
