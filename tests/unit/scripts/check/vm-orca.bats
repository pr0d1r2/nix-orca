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
  case "$2" in
  create)
    # Like the gate command: hooks on, then the gate commit.
    dir=${4#path:}
    [ -n "${STUB_NO_GATE:-}" ] ||
      { git -C "$dir" config core.hooksPath .githooks && git -C "$dir" commit -q --allow-empty -m "chore: the gate, from .pklith"; }
    ;;
  wait) [ -z "${STUB_NOT_IDLE:-}" ] ;;
  esac
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
show) echo "${STUB_PID-42}" ;;
esac
STUB
  cat >stubs/nsenter <<'STUB'
#!/usr/bin/env bash
# nsenter -t PID -m COMMAND...: the unit's mount namespace, by STUB_SEES
# and STUB_WRITABLE.
echo "nsenter $*" >>"$BATS_TEST_TMPDIR/nsenter.log"
case "$4" in
test) [ -n "${STUB_SEES:-}" ] ;;
touch) [ -n "${STUB_WRITABLE:-}" ] ;;
esac
STUB
  cat >stubs/xdotool <<'STUB'
#!/usr/bin/env bash
echo "xdotool $* DISPLAY=$DISPLAY" >>"$BATS_TEST_TMPDIR/xdotool.log"
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

@test "isolated: the unit's mount namespace hides PATH and keeps / read-only" {
  mkdir -p home/alice && touch home/alice/secret
  run --separate-stderr "$vm" isolated orca-ide.service home/alice/secret
  [ "$status" -eq 0 ]
  grep -qx "nsenter -t 42 -m test -e home/alice/secret" nsenter.log
}

@test "isolated: a PATH the unit sees fails and names V8" {
  mkdir -p home/alice && touch home/alice/secret
  export STUB_SEES=1
  run --separate-stderr "$vm" isolated orca-ide.service home/alice/secret
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: orca-ide.service sees home/alice/secret (nix/modules V8)" ]
}

@test "isolated: a writable / fails and names V8" {
  mkdir -p home/alice && touch home/alice/secret
  export STUB_WRITABLE=1
  run --separate-stderr "$vm" isolated orca-ide.service home/alice/secret
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: orca-ide.service can write / (nix/modules V8)" ]
}

@test "isolated: a PATH missing on the host fails, so the check is not vacuous" {
  run --separate-stderr "$vm" isolated orca-ide.service home/alice/secret
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: home/alice/secret is missing on the host" ]
}

@test "isolated: a unit with no main process fails" {
  mkdir -p home/alice && touch home/alice/secret
  export STUB_PID=0
  run --separate-stderr "$vm" isolated orca-ide.service home/alice/secret
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: orca-ide.service has no main process" ]
}

@test "seed: the user's Orca starts with onboarding closed, tips seen, no tours, no star prompt, telemetry off" {
  run --separate-stderr "$vm" seed alice
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  jq -e '.onboarding.closedAt != null and .onboarding.outcome == "completed" and .ui.contextualToursAutoEligible == false and (.ui.featureTipsSeenIds | length) > 0 and .ui.starNagCompleted == true and .settings.telemetry.optedIn == false and .settings.telemetry.existedBeforeTelemetryRelease == false' home/.config/orca/orca-data.json
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

@test "agent: the agent launched focused on the added repo, writes the file and goes idle" {
  run --separate-stderr "$vm" agent alice opencode "$BATS_TEST_TMPDIR/demo" "write hello.txt" hello.txt
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  run ! grep -q "^repo add" orca.log
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

@test "compact: a still stretch lasts at most 1.5 s, a blinking cursor is still, the last frame held" {
  run --separate-stderr "$vm" compact run.mp4 demo.mp4
  [ "$status" -eq 0 ]
  grep -qF 'mpdecimate=hi=64*100000:lo=64*5:frac=0.005,setpts='"'"'if(eq(N\,0)\,0\,PREV_OUTPTS+min(PTS-PREV_INPTS\,1.5/TB))'"'"',tpad=stop_mode=clone:stop_duration=3 -fps_mode vfr' ffmpeg.log
  [ -s demo.mp4 ]
}

@test "compact: no output fails" {
  export STUB_NO_FFMPEG=1
  run --separate-stderr "$vm" compact run.mp4 demo.mp4
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: ffmpeg wrote no demo.mp4" ]
}

@test "preview: an animated WebP of the video, its frames timed as they are, looping, under the size limit" {
  run --separate-stderr "$vm" preview demo.mp4 preview.webp
  [ "$status" -eq 0 ]
  grep -qF -- "-i demo.mp4 -vf scale=960:-1 -fps_mode vfr -c:v libwebp_anim -quality 60 -loop 0 -an preview.webp" ffmpeg.log
}

@test "preview: over the size limit fails" {
  export ORCA_VM_PREVIEW_MAX=3
  run --separate-stderr "$vm" preview demo.mp4 preview.webp
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: preview.webp is 7 bytes, over 3" ]
}

@test "repo: a git repository in DIR holding the files, one commit" {
  printf '{}\n' >opencode.json
  run --separate-stderr "$vm" repo alice "$HOME/demo" opencode.json
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  [ "$(git -C home/demo ls-files | tr '\n' ' ')" = "README opencode.json " ]
  [ "$(git -C home/demo rev-list --count HEAD)" -eq 1 ]
  [ -z "$(git -C home/demo status --porcelain)" ]
}

@test "repo: an existing DIR fails" {
  mkdir -p home/demo
  run --separate-stderr "$vm" repo alice "$HOME/demo"
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: $HOME/demo already exists" ]
}

@test "stub: a script given by absolute path is used as it is" {
  run --separate-stderr "$vm" stub alice 8787 /etc/demo/opencode.json "$BATS_TEST_TMPDIR/demo"
  [ "$status" -eq 0 ]
  grep -q -- "--script /etc/demo/opencode.json --port 8787 " systemd-run.log
}

@test "add: the user's Orca adds DIR as a repository" {
  run --separate-stderr "$vm" add alice "$BATS_TEST_TMPDIR/demo"
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  grep -qx "repo add --path $BATS_TEST_TMPDIR/demo --json" orca.log
}

@test "gate: the vendored schema in place, pklith materializes the gate in an Orca terminal, committed" {
  git -C demo init -q
  git -C demo -c user.email=t@l -c user.name=t commit -q --allow-empty -m init
  git -C demo config user.email t@l
  git -C demo config user.name t
  echo schema >Config.pkl
  run --separate-stderr "$vm" gate alice "$BATS_TEST_TMPDIR/demo" "$BATS_TEST_TMPDIR/Config.pkl"
  [ "$status" -eq 0 ]
  [ "$(cat demo/pkl/Config.pkl)" = schema ]
  grep -qx "terminal create --worktree path:$BATS_TEST_TMPDIR/demo --title gate --focus --json --command pklith seed --init && pklith gen && pklith confirm && git config core.hooksPath .githooks && git add -A && git commit -qm 'chore: the gate, from .pklith'" orca.log
}

@test "gate: no gate commit fails within the timeout" {
  git -C demo init -q
  git -C demo -c user.email=t@l -c user.name=t commit -q --allow-empty -m init
  echo schema >Config.pkl
  export STUB_NO_GATE=1
  run --separate-stderr "$vm" gate alice "$BATS_TEST_TMPDIR/demo" "$BATS_TEST_TMPDIR/Config.pkl"
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: no gate commit in $BATS_TEST_TMPDIR/demo after 3 s" ]
}

@test "commits: DIR reaches N commits" {
  git -C demo init -q
  git -C demo -c user.email=t@l -c user.name=t commit -q --allow-empty -m one
  git -C demo -c user.email=t@l -c user.name=t commit -q --allow-empty -m two
  run --separate-stderr "$vm" commits alice "$BATS_TEST_TMPDIR/demo" 2
  [ "$status" -eq 0 ]
}

@test "commits: fewer than N after the timeout fails" {
  git -C demo init -q
  git -C demo -c user.email=t@l -c user.name=t commit -q --allow-empty -m one
  run --separate-stderr "$vm" commits alice "$BATS_TEST_TMPDIR/demo" 3
  [ "$status" -eq 1 ]
  [ "$stderr" = "vm-orca: $BATS_TEST_TMPDIR/demo has 1 commits after 3 s, want 3" ]
}

@test "seed onboarding: no tips, tours, star prompt or telemetry banner, but onboarding left to run" {
  run --separate-stderr "$vm" seed alice onboarding
  [ "$status" -eq 0 ]
  jq -e '.onboarding.closedAt == null and .onboarding.lastCompletedStep == -1 and .onboarding.flowVersion == 4 and .ui.contextualToursAutoEligible == false and .ui.starNagCompleted == true and .settings.telemetry.optedIn == false' home/.config/orca/orca-data.json
}

@test "keys: each key on the user's display :99, a pause between" {
  export ORCA_VM_KEY_PAUSE=0
  run --separate-stderr "$vm" keys alice ctrl+Return Escape
  [ "$status" -eq 0 ]
  grep -qx "su alice" su.log
  [ "$(cat xdotool.log)" = "xdotool key ctrl+Return DISPLAY=:99
xdotool key Escape DISPLAY=:99" ]
}

@test "anything else is a usage error, exit 2" {
  run --separate-stderr "$vm" launch alice
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT | listening PORT ADDRESS | exposure UNIT FILE | isolated UNIT PATH | seed USER [onboarding] | stub USER PORT SCRIPT WORKDIR | record USER FILE | record-stop | agent USER AGENT DIR PROMPT FILE | compact IN OUT | preview IN OUT | repo USER DIR [FILE...] | add USER DIR | gate USER DIR SCHEMA | commits USER DIR N | keys USER KEY..." ]
}
