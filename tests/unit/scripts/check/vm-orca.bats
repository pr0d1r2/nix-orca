#!/usr/bin/env bats
# scripts/check/vm-orca.sh (nix/modules T1, tests T1): the checks a NixOS
# VM test runs inside the VM, as root. su, Xvfb and orca-ide are stubs;
# su runs the command as the caller and logs the user.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  vm="$BATS_TEST_DIRNAME/../../../../scripts/check/vm-orca.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p stubs profile/share/applications profile/share/icons/hicolor/256x256/apps
  touch profile/share/applications/orca-ide.desktop profile/share/icons/hicolor/256x256/apps/orca-ide.png
  cat >stubs/su <<'STUB'
#!/usr/bin/env bash
# su - USER -c COMMAND
echo "su $2" >>"$BATS_TEST_TMPDIR/su.log"
exec bash -c "$4"
STUB
  cat >stubs/Xvfb <<'STUB'
#!/usr/bin/env bash
echo "Xvfb $*" >>"$BATS_TEST_TMPDIR/xvfb.log"
STUB
  cat >stubs/orca-ide <<'STUB'
#!/usr/bin/env bash
case "$1" in
--version) echo "${STUB_VERSION:-1.4.232}" ;;
open) [ -n "${STUB_NO_RUNTIME:-}" ] || touch "$BATS_TEST_TMPDIR/opened" ;;
status)
  state=disconnected
  [ -e "$BATS_TEST_TMPDIR/opened" ] && state=connected
  printf '{"result":{"app":{"desktopWindowStatus":"available"},"runtime":{"connectionState":"%s"}}}\n' "$state"
  ;;
serve)
  [ -n "${STUB_NO_SERVE:-}" ] && exit 1
  echo "Orca server ready"
  echo "Bound endpoint: ws://0.0.0.0:$3"
  ;;
esac
STUB
  chmod +x stubs/*
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export ORCA_VM_PROFILE=$BATS_TEST_TMPDIR/profile ORCA_VM_TIMEOUT=3
}

@test "module: the user's orca-ide prints the version; entry and icon in the profile" {
  run --separate-stderr "$vm" module alice 1.4.232
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
}

@test "module: another version fails" {
  export STUB_VERSION=1.4.230
  run --separate-stderr "$vm" module alice 1.4.232
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: alice's orca-ide --version printed 1.4.230, want 1.4.232" ]
}

@test "module: a missing desktop entry fails" {
  rm profile/share/applications/orca-ide.desktop
  run --separate-stderr "$vm" module alice 1.4.232
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"share/applications/orca-ide.desktop is missing" ]]
}

@test "app: Xvfb, then the window, then the runtime connected" {
  run --separate-stderr "$vm" app alice
  [ "$status" -eq 0 ]
  grep -q "Xvfb :99" xvfb.log
  grep -qx "su alice" su.log
}

@test "app: a runtime that never connects fails within the timeout, with the app's log" {
  export STUB_NO_RUNTIME=1
  run --separate-stderr "$vm" app alice
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"vm-orca: alice's Orca runtime not connected after 3 s"* ]]
}

@test "serve: the server says it is ready on the port" {
  run --separate-stderr "$vm" serve bob 6769
  [ "$status" -eq 0 ]
  grep -qx "su bob" su.log
}

@test "serve: a server that never gets ready fails with its log" {
  export STUB_NO_SERVE=1
  run --separate-stderr "$vm" serve bob 6769
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"vm-orca: bob's orca-ide serve not ready on 6769 after 3 s"* ]]
}

@test "anything else is a usage error, exit 2" {
  run --separate-stderr "$vm" launch alice
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT" ]
}
