#!/usr/bin/env bash
# Checks a NixOS VM test runs inside the VM, as root (nix/modules T1,
# tests T1). The test driver only takes Python, so the tests call this
# and keep their Python to the driver's own calls.
# Usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT |
#        listening PORT ADDRESS | exposure UNIT FILE | seed USER |
#        stub USER PORT SCRIPT WORKDIR | record USER FILE | record-stop |
#        agent USER AGENT DIR PROMPT FILE | compact IN OUT | preview IN OUT |
#        repo USER DIR [FILE...] | add USER DIR | gate USER DIR SCHEMA |
#        commits USER DIR N
#   module: USER's orca-ide --version prints VERSION; the desktop entry and
#           a hicolor icon are in the system profile
#   app:    as USER, Xvfb on :99 and `orca-ide open`; the runtime connects
#           and the window is available
#   serve:  as USER, headless (no DISPLAY: Orca starts its own Xvfb),
#           `orca-ide serve --port PORT --no-pairing` says it is ready on PORT
#   listening: every listener on PORT is on ADDRESS
#   exposure: `systemd-analyze security UNIT` scores at most UNIT's line in
#           FILE (`unit score`, `#` comments), the .exposure ratchet
#   seed:   before `app`, USER's Orca state says onboarding is done, every
#           tip seen, no tour or star prompt may start and telemetry is off,
#           so the window shows the work (tests T4)
#   stub:   as USER, the stub model server (tests/stub under ORCA_VM_SRC)
#           replays tests/stub/scripts/SCRIPT, or SCRIPT itself when it is
#           an absolute path, on PORT in WORKDIR
#   record: as USER, ffmpeg records display :99 into FILE until record-stop
#   agent:  as USER, `agent launch` AGENT on the added DIR with PROMPT,
#           focused; the agent writes DIR/FILE and its terminal goes idle
#           (tests V3)
#   compact: IN with each still stretch cut to at most 1.5 s into OUT, the
#           last frame held
#   preview: IN as a looping animated WebP OUT, which GitHub plays inline,
#           at most ORCA_VM_PREVIEW_MAX bytes (default 1 MiB)
#   repo:   as USER, a new git repository in DIR holding the FILEs and a
#           README, in one commit: the repository an agent works in
#   add:    as USER, `orca-ide repo add` DIR
#   gate:   as USER, SCHEMA (the hk schema pklith's seed would write) to
#           DIR/pkl/Config.pkl, then pklith seeds, generates, confirms and
#           commits DIR's gate in a focused Orca terminal, in view
#   commits: as USER, DIR has at least N commits
# Env: ORCA_VM_PROFILE (default /run/current-system/sw), ORCA_VM_TIMEOUT
# (seconds per wait, default 120), ORCA_VM_LOGS (default /tmp), ORCA_VM_SRC
# (the directory holding tests/, for stub).
set -euo pipefail

usage() {
  echo "usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT | listening PORT ADDRESS | exposure UNIT FILE | seed USER | stub USER PORT SCRIPT WORKDIR | record USER FILE | record-stop | agent USER AGENT DIR PROMPT FILE | compact IN OUT | preview IN OUT | repo USER DIR [FILE...] | add USER DIR | gate USER DIR SCHEMA | commits USER DIR N" >&2
  exit 2
}
fail() {
  echo "vm-orca: $*" >&2
  exit 1
}
profile=${ORCA_VM_PROFILE:-/run/current-system/sw}
timeout=${ORCA_VM_TIMEOUT:-120}
logs=${ORCA_VM_LOGS:-/tmp}

# A login shell of USER, as a desktop session would have.
as() {
  local user=$1
  shift
  su - "$user" -c "$*"
}

# Runs its arguments once a second until they succeed or the time is up.
wait_for() {
  local i
  for ((i = 0; i < timeout; i++)); do
    if "$@"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

case "${1:-}" in
module)
  [ "$#" -eq 3 ] || usage
  user=$2 want=$3
  got=$(as "$user" "orca-ide --version")
  [ "$got" = "$want" ] || fail "$user's orca-ide --version printed $got, want $want"
  for file in share/applications/orca-ide.desktop share/icons/hicolor/256x256/apps/orca-ide.png; do
    [ -e "$profile/$file" ] || fail "$profile/$file is missing"
  done
  ;;
app)
  [ "$#" -eq 2 ] || usage
  user=$2 log=$logs/orca-open.log
  as "$user" "nohup Xvfb :99 -screen 0 1440x900x24 >$logs/xvfb.log 2>&1 &"
  as "$user" "DISPLAY=:99 nohup orca-ide open >$log 2>&1 &"
  connected() {
    as "$user" "orca-ide status --json" 2>/dev/null |
      jq -e '.result.runtime.connectionState == "connected" and .result.app.desktopWindowStatus == "available"' >/dev/null
  }
  if ! wait_for connected; then
    cat "$log" >&2 || true
    fail "$user's Orca runtime not connected after $timeout s"
  fi
  ;;
serve)
  [ "$#" -eq 3 ] || usage
  user=$2 port=$3 log=$logs/orca-serve.log
  as "$user" "unset DISPLAY; nohup orca-ide serve --port $port --no-pairing >$log 2>&1 &"
  ready() {
    grep -qx 'Orca server ready' "$log" 2>/dev/null &&
      grep -q "^Bound endpoint: .*:$port\$" "$log"
  }
  if ! wait_for ready; then
    cat "$log" >&2 || true
    fail "$user's orca-ide serve not ready on $port after $timeout s"
  fi
  ;;
listening)
  [ "$#" -eq 3 ] || usage
  port=$2 address=$3
  others=$(ss -ltnH "sport = :$port" | awk -v want="$address:$port" '$4 != want { sub(":[0-9]+$", "", $4); print $4 }' | sort -u | tr '\n' ' ')
  [ -z "$others" ] || fail "port $port is bound on ${others% }, want $address only"
  ;;
exposure)
  [ "$#" -eq 3 ] || usage
  unit=$2 file=$3
  score=$(systemd-analyze security "$unit" | sed -n 's/.*Overall exposure level for .*: \([0-9.]*\).*/\1/p')
  limit=$(awk -v u="$unit" '$1 == u { print $2 }' "$file")
  [ -n "$score" ] || fail "systemd-analyze gave no exposure score for $unit"
  [ -n "$limit" ] || fail "no ratchet for $unit in $file"
  if awk -v s="$score" -v l="$limit" 'BEGIN { exit !(s > l) }'; then
    fail "$unit exposure $score, ratchet $limit in $file; raise it in its own reviewed commit (nix/modules V1)"
  fi
  ;;
seed)
  [ "$#" -eq 2 ] || usage
  user=$2
  # The fields Orca's dev builds set to skip first-run education, and
  # telemetry off: a state file present at first start reads as an install
  # older than telemetry, which gets the consent banner. New tips in an
  # Orca bump show in the recording until listed here.
  state='{"onboarding":{"flowVersion":4,"closedAt":1,"outcome":"completed","lastCompletedStep":5},'
  state+='"ui":{"contextualToursAutoEligible":false,"starNagCompleted":true,"featureTipsSeenIds":["native-chat-upgrade","agent-session-search","orca-cli","cmd-j-palette","voice-dictation"]},'
  state+='"settings":{"telemetry":{"existedBeforeTelemetryRelease":false,"optedIn":false}}}'
  as "$user" "test ! -e ~/.config/orca/orca-data.json" ||
    fail "$user already has Orca state in ~/.config/orca/orca-data.json"
  as "$user" "mkdir -p ~/.config/orca && echo '$state' >~/.config/orca/orca-data.json"
  ;;
stub)
  [ "$#" -eq 5 ] || usage
  user=$2 port=$3 script=$4 workdir=$5 src=${ORCA_VM_SRC:?ORCA_VM_SRC is unset}
  case "$script" in
  /*) ;;
  *) script=$src/tests/stub/scripts/$script ;;
  esac
  systemd-run -u orca-stub --uid="$user" -p WorkingDirectory="$src" \
    "$(command -v python3)" -m tests.stub.server \
    --script "$script" --port "$port" --workdir "$workdir"
  listens() {
    ss -ltnH "sport = :$port" | awk -v p=":$port" '$4 ~ p "$"' | grep -q .
  }
  wait_for listens || fail "stub model server not listening on $port after $timeout s"
  ;;
record)
  [ "$#" -eq 3 ] || usage
  user=$2 file=$3
  systemd-run -u orca-record --uid="$user" --setenv=DISPLAY=:99 \
    "$(command -v ffmpeg)" -nostdin -y -f x11grab -video_size 1440x900 -framerate 10 \
    -i :99 -pix_fmt yuv420p "$file"
  ;;
record-stop)
  [ "$#" -eq 1 ] || usage
  systemctl kill -s INT orca-record
  stopped() { ! systemctl is-active -q orca-record; }
  wait_for stopped || fail "recorder still running after $timeout s"
  ;;
agent)
  [ "$#" -eq 6 ] || usage
  user=$2 agent=$3 dir=$4 prompt=$5 file=$6
  handle=$(as "$user" "orca-ide agent launch --agent $agent --worktree path:$(printf %q "$dir") --prompt $(printf %q "$prompt") --focus --json" |
    jq -r .result.outcome.handle)
  written() { [ -e "$dir/$file" ]; }
  wait_for written || fail "$agent wrote no $dir/$file after $timeout s"
  as "$user" "orca-ide terminal wait --terminal $handle --for tui-idle --timeout-ms $((timeout * 1000)) --json" >/dev/null ||
    fail "$agent's terminal $handle not idle after $timeout s"
  ;;
compact)
  [ "$#" -eq 3 ] || usage
  in=$2 out=$3
  # A frame counts as changed when over 0.5% of its 8x8 blocks differ, so
  # a blinking cursor is still; each still stretch is held at most 1.5 s,
  # timed from the previous kept frame; the result is held 3 s at the end.
  ffmpeg -v error -y -i "$in" \
    -vf "mpdecimate=hi=64*100000:lo=64*5:frac=0.005,setpts='if(eq(N\,0)\,0\,PREV_OUTPTS+min(PTS-PREV_INPTS\,1.5/TB))',tpad=stop_mode=clone:stop_duration=3" \
    -fps_mode vfr -an -pix_fmt yuv420p "$out"
  [ -s "$out" ] || fail "ffmpeg wrote no $out"
  ;;
preview)
  [ "$#" -eq 3 ] || usage
  in=$2 out=$3 max=${ORCA_VM_PREVIEW_MAX:-1048576}
  ffmpeg -v error -y -i "$in" -vf "fps=5,scale=960:-1" \
    -c:v libwebp -quality 60 -loop 0 -an "$out"
  size=$(($(wc -c <"$out")))
  [ "$size" -le "$max" ] || fail "$out is $size bytes, over $max"
  ;;
repo)
  [ "$#" -ge 3 ] || usage
  user=$2 dir=$3
  shift 3
  [ ! -e "$dir" ] || fail "$dir already exists"
  copy=""
  for f in "$@"; do
    f=$(cd "$(dirname "$f")" && pwd)/$(basename "$f")
    copy+=" && cp $(printf %q "$f") ."
  done
  as "$user" "mkdir -p $(printf %q "$dir") && cd $(printf %q "$dir") && git init -q &&
    git config user.email demo@localhost && git config user.name demo$copy &&
    echo demo >README && git add -A && git commit -qm init"
  ;;
add)
  [ "$#" -eq 3 ] || usage
  user=$2 dir=$3
  as "$user" "orca-ide repo add --path $(printf %q "$dir") --json" >/dev/null
  ;;
gate)
  [ "$#" -eq 4 ] || usage
  user=$2 dir=$3 schema=$4 subject="chore: the gate, from .pklith"
  as "$user" "mkdir -p $(printf %q "$dir")/pkl && cp $(printf %q "$schema") $(printf %q "$dir")/pkl/Config.pkl &&
    chmod u+w $(printf %q "$dir")/pkl/Config.pkl"
  command="pklith seed --init && pklith gen && pklith confirm && git config core.hooksPath .githooks && git add -A && git commit -qm '$subject'"
  as "$user" "orca-ide terminal create --worktree path:$(printf %q "$dir") --title gate --focus --json --command $(printf %q "$command")" >/dev/null
  gated() {
    as "$user" "git -C $(printf %q "$dir") log --format=%s" 2>/dev/null | grep -qxF "$subject"
  }
  wait_for gated || fail "no gate commit in $dir after $timeout s"
  ;;
commits)
  [ "$#" -eq 4 ] || usage
  user=$2 dir=$3 want=$4
  count() { as "$user" "git -C $(printf %q "$dir") rev-list --count HEAD" 2>/dev/null || echo 0; }
  enough() { [ "$(count)" -ge "$want" ]; }
  wait_for enough || fail "$dir has $(count) commits after $timeout s, want $want"
  ;;
*)
  usage
  ;;
esac
