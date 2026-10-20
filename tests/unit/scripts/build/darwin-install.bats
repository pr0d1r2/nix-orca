#!/usr/bin/env bats
# scripts/build/darwin-install.sh (nix/darwin T1): the install phase of the
# darwin package, sourced by stdenv. makeWrapper and runHook are stubs on
# PATH that log their arguments.

setup() {
  script="$BATS_TEST_DIRNAME/../../../../scripts/build/darwin-install.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p src/Orca.app/Contents/Resources/bin stubs
  printf '#!/usr/bin/env bash\n' >src/Orca.app/Contents/Resources/bin/orca
  cat >stubs/makeWrapper <<'STUB'
#!/usr/bin/env bash
echo "makeWrapper $*" >>"$BATS_TEST_TMPDIR/log"
STUB
  cat >stubs/runHook <<'STUB'
#!/usr/bin/env bash
echo "runHook $*" >>"$BATS_TEST_TMPDIR/log"
STUB
  chmod +x stubs/* src/Orca.app/Contents/Resources/bin/orca
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export out="$BATS_TEST_TMPDIR/out"
  export ORCA_PATH=/store/git/bin
  export ORCA_TELEMETRY=true
}

install() {
  # shellcheck source=/dev/null
  (cd src && . "$script")
}

@test "Orca.app moves under Applications, untouched" {
  run install
  [ "$status" -eq 0 ]
  [ -x "$out/Applications/Orca.app/Contents/Resources/bin/orca" ]
  [ ! -e src/Orca.app ]
}

@test "bin/orca-ide wraps upstream's CLI launcher with the runtime PATH" {
  run install
  [ "$status" -eq 0 ]
  grep -qxF "makeWrapper $out/Applications/Orca.app/Contents/Resources/bin/orca $out/bin/orca-ide --prefix PATH : /store/git/bin" log
}

@test "telemetry off sets ORCA_TELEMETRY_DISABLED for bin/orca-ide only" {
  export ORCA_TELEMETRY=false
  run install
  [ "$status" -eq 0 ]
  grep -qxF "makeWrapper $out/Applications/Orca.app/Contents/Resources/bin/orca $out/bin/orca-ide --prefix PATH : /store/git/bin --set ORCA_TELEMETRY_DISABLED 1" log
}

@test "pre and post install hooks run around it" {
  run install
  [ "$status" -eq 0 ]
  [ "$(head -1 log)" = "runHook preInstall" ]
  [ "$(tail -1 log)" = "runHook postInstall" ]
}
