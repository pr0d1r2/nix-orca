#!/usr/bin/env bats
# scripts/check/vm-orca.sh (nix/modules T1, tests T1): the checks a NixOS
# VM test runs inside the VM, as root. su, Xvfb, orca-ide, systemd-run,
# systemctl and ffmpeg are stubs; su runs the command as the caller and
# logs the user.
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
repo) echo "$*" >>"$BATS_TEST_TMPDIR/orca.log" ;;
agent)
  echo "$*" >>"$BATS_TEST_TMPDIR/orca.log"
  [ -n "${STUB_NO_AGENT:-}" ] || echo hi >"$BATS_TEST_TMPDIR/demo/hello.txt"
  echo '{"result":{"outcome":{"handle":"term_1"}}}'
  ;;
terminal)
  echo "$*" >>"$BATS_TEST_TMPDIR/orca.log"
  [ -z "${STUB_NOT_IDLE:-}" ]
  ;;
serve)
  # Like Orca: a set DISPLAY that is not live stops it.
  [ -n "${STUB_NO_SERVE:-}${DISPLAY:-}" ] && exit 1
  echo "Orca server ready"
  echo "Bound endpoint: ws://0.0.0.0:$3"
  ;;
esac
STUB
  cat >stubs/ss <<'STUB'
#!/usr/bin/env bash
printf 'LISTEN 0 511 %s:6768 0.0.0.0:*\n' ${STUB_LISTEN:-127.0.0.1}
for f in "$BATS_TEST_TMPDIR"/listen-*; do
  [ -e "$f" ] && printf 'LISTEN 0 5 127.0.0.1:%s 0.0.0.0:*\n' "${f##*-}"
done
true
STUB
  cat >stubs/systemd-run <<'STUB'
#!/usr/bin/env bash
# systemd-run -u UNIT ... COMMAND...; the unit's process is not run.
echo "systemd-run $*" >>"$BATS_TEST_TMPDIR/systemd-run.log"
unit=$2
touch "$BATS_TEST_TMPDIR/active-$unit"
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[i]}" = --port ] && [ -z "${STUB_NO_LISTEN:-}" ]; then
    touch "$BATS_TEST_TMPDIR/listen-${args[i + 1]}"
  fi
done
STUB
  cat >stubs/systemctl <<'STUB'
#!/usr/bin/env bash
echo "systemctl $*" >>"$BATS_TEST_TMPDIR/systemctl.log"
case "$1" in
is-active) [ -e "$BATS_TEST_TMPDIR/active-${*: -1}" ] ;;
kill) [ -n "${STUB_NO_STOP:-}" ] || rm -f "$BATS_TEST_TMPDIR/active-${*: -1}" ;;
esac
STUB
  cat >stubs/ffmpeg <<'STUB'
#!/usr/bin/env bash
echo "ffmpeg $*" >>"$BATS_TEST_TMPDIR/ffmpeg.log"
[ -n "${STUB_NO_FFMPEG:-}" ] || echo frames >"${*: -1}"
STUB
  cat >stubs/systemd-analyze <<'STUB'
#!/usr/bin/env bash
echo "→ Overall exposure level for $2: ${STUB_EXPOSURE:-2.2} OK :-)"
STUB
  printf '# unit score\norca-ide.service 2.2\n' >exposure
  mkdir -p demo home src/tests/stub
  chmod +x stubs/*
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export ORCA_VM_PROFILE=$BATS_TEST_TMPDIR/profile ORCA_VM_TIMEOUT=3 ORCA_VM_LOGS=$BATS_TEST_TMPDIR
  export ORCA_VM_SRC=$BATS_TEST_TMPDIR/src HOME=$BATS_TEST_TMPDIR/home
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

@test "serve: headless, whatever DISPLAY root's environment carries" {
  export DISPLAY=:0.0
  run --separate-stderr "$vm" serve bob 6769
  [ "$status" -eq 0 ]
}

@test "serve: a server that never gets ready fails with its log" {
  export STUB_NO_SERVE=1
  run --separate-stderr "$vm" serve bob 6769
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"vm-orca: bob's orca-ide serve not ready on 6769 after 3 s"* ]]
}

@test "listening: the port is bound on the address alone" {
  run --separate-stderr "$vm" listening 6768 127.0.0.1
  [ "$status" -eq 0 ]
}

@test "listening: another bound address fails" {
  export STUB_LISTEN="127.0.0.1 0.0.0.0"
  run --separate-stderr "$vm" listening 6768 127.0.0.1
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: port 6768 is bound on 0.0.0.0, want 127.0.0.1 only" ]
}

@test "exposure: systemd's score within the ratchet passes" {
  run --separate-stderr "$vm" exposure orca-ide.service exposure
  [ "$status" -eq 0 ]
}

@test "exposure: a higher score fails and names V1" {
  export STUB_EXPOSURE=2.3
  run --separate-stderr "$vm" exposure orca-ide.service exposure
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: orca-ide.service exposure 2.3, ratchet 2.2 in exposure; raise it in its own reviewed commit (nix/modules V1)" ]
}

@test "seed: the user's Orca starts with onboarding closed, tips seen, no tours, telemetry off" {
  run --separate-stderr "$vm" seed alice
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  jq -e '.onboarding.closedAt != null and .onboarding.outcome == "completed" and .ui.contextualToursAutoEligible == false and (.ui.featureTipsSeenIds | length) > 0 and .settings.telemetry.optedIn == false and .settings.telemetry.existedBeforeTelemetryRelease == false' home/.config/orca/orca-data.json
}

@test "seed: state already there fails, untouched" {
  mkdir -p home/.config/orca
  echo '{}' >home/.config/orca/orca-data.json
  run --separate-stderr "$vm" seed alice
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: alice already has Orca state in ~/.config/orca/orca-data.json" ]
  [ "$(cat home/.config/orca/orca-data.json)" = "{}" ]
}

@test "stub: the stub model server runs as the user from ORCA_VM_SRC and listens" {
  run --separate-stderr "$vm" stub alice 8787 opencode.json "$BATS_TEST_TMPDIR/demo"
  [ "$status" -eq 0 ]
  grep -q -- "-u orca-stub --uid=alice -p WorkingDirectory=$BATS_TEST_TMPDIR/src " systemd-run.log
  grep -q -- "-m tests.stub.server --script $BATS_TEST_TMPDIR/src/tests/stub/scripts/opencode.json --port 8787 --workdir $BATS_TEST_TMPDIR/demo\$" systemd-run.log
}

@test "stub: a server that never listens fails within the timeout" {
  export STUB_NO_LISTEN=1
  run --separate-stderr "$vm" stub alice 8787 opencode.json "$BATS_TEST_TMPDIR/demo"
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: stub model server not listening on 8787 after 3 s" ]
}

@test "record: ffmpeg grabs the user's display :99 into the file" {
  run --separate-stderr "$vm" record alice /tmp/run.mp4
  [ "$status" -eq 0 ]
  grep -q -- "-u orca-record --uid=alice --setenv=DISPLAY=:99 .* -f x11grab .* -i :99 .*/tmp/run.mp4\$" systemd-run.log
}

@test "record-stop: ffmpeg gets SIGINT and the unit ends" {
  touch active-orca-record
  run --separate-stderr "$vm" record-stop
  [ "$status" -eq 0 ]
  grep -qx "systemctl kill -s INT orca-record" systemctl.log
}

@test "record-stop: a recorder still running after the timeout fails" {
  touch active-orca-record
  export STUB_NO_STOP=1
  run --separate-stderr "$vm" record-stop
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: recorder still running after 3 s" ]
}

@test "agent: the repo is added, the agent launched focused, writes the file and goes idle" {
  run --separate-stderr "$vm" agent alice opencode "$BATS_TEST_TMPDIR/demo" "write hello.txt" hello.txt
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  grep -qx "repo add --path $BATS_TEST_TMPDIR/demo --json" orca.log
  grep -qx "agent launch --agent opencode --worktree path:$BATS_TEST_TMPDIR/demo --prompt write hello.txt --focus --json" orca.log
  grep -q "^terminal wait --terminal term_1 --for tui-idle " orca.log
}

@test "agent: no file written fails within the timeout" {
  export STUB_NO_AGENT=1
  run --separate-stderr "$vm" agent alice opencode "$BATS_TEST_TMPDIR/demo" "write hello.txt" hello.txt
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: opencode wrote no $BATS_TEST_TMPDIR/demo/hello.txt after 3 s" ]
}

@test "agent: an agent that never goes idle fails" {
  export STUB_NOT_IDLE=1
  run --separate-stderr "$vm" agent alice opencode "$BATS_TEST_TMPDIR/demo" "write hello.txt" hello.txt
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: opencode's terminal term_1 not idle after 3 s" ]
}

@test "compact: frames that do not change are dropped, the last one held" {
  run --separate-stderr "$vm" compact run.mp4 demo.mp4
  [ "$status" -eq 0 ]
  grep -q "mpdecimate=.*max=20,setpts=N/10/TB,tpad=stop_mode=clone:stop_duration=3" ffmpeg.log
  [ -s demo.mp4 ]
}

@test "compact: no output fails" {
  export STUB_NO_FFMPEG=1
  run --separate-stderr "$vm" compact run.mp4 demo.mp4
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: ffmpeg wrote no demo.mp4" ]
}

@test "anything else is a usage error, exit 2" {
  run --separate-stderr "$vm" launch alice
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT | listening PORT ADDRESS | exposure UNIT FILE | seed USER | stub USER PORT SCRIPT WORKDIR | record USER FILE | record-stop | agent USER AGENT DIR PROMPT FILE | compact IN OUT" ]
}
