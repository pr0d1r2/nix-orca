#!/usr/bin/env bash
# Checks a NixOS VM test runs inside the VM, as root (nix/modules T1,
# tests T1). The test driver only takes Python, so the tests call this
# and keep their Python to the driver's own calls.
# Usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT |
#        listening PORT ADDRESS | exposure UNIT FILE
#   module: USER's orca-ide --version prints VERSION; the desktop entry and
#           a hicolor icon are in the system profile
#   app:    as USER, Xvfb on :99 and `orca-ide open`; the runtime connects
#           and the window is available
#   serve:  as USER, headless (no DISPLAY: Orca starts its own Xvfb),
#           `orca-ide serve --port PORT --no-pairing` says it is ready on PORT
#   listening: every listener on PORT is on ADDRESS
#   exposure: `systemd-analyze security UNIT` scores at most UNIT's line in
#           FILE (`unit score`, `#` comments), the .exposure ratchet
# Env: ORCA_VM_PROFILE (default /run/current-system/sw), ORCA_VM_TIMEOUT
# (seconds per wait, default 120), ORCA_VM_LOGS (default /tmp).
set -euo pipefail

usage() {
  echo "usage: vm-orca.sh module USER VERSION | app USER | serve USER PORT | listening PORT ADDRESS | exposure UNIT FILE" >&2
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
*)
  usage
  ;;
esac
