#!/usr/bin/env bash
# `services.orca-ide.listenInterface` (nix/modules §C, T7): run the
# service's command with ORCA_SERVE_BIND_HOST set to INTERFACE's first IPv4
# address, so serve binds that interface on a LAN whose address DHCP hands
# out. Waits for the address to come up; without one in time the command
# never runs. A later address change needs a restart of the service.
# Usage: serve-bind.sh INTERFACE -- COMMAND...
# Env: SERVE_BIND_TIMEOUT (seconds, default 60).
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$2" != -- ]; then
  echo "usage: serve-bind.sh INTERFACE -- COMMAND..." >&2
  exit 2
fi
interface=$1
shift 2
timeout=${SERVE_BIND_TIMEOUT:-60}

address() {
  ip -4 -o addr show dev "$interface" | awk '{ sub("/.*", "", $4); print $4; exit }'
}

for ((i = 0; i < timeout; i++)); do
  host=$(address)
  if [ -n "$host" ]; then
    ORCA_SERVE_BIND_HOST=$host exec "$@"
  fi
  sleep 1
done
echo "serve-bind: $interface has no IPv4 address after $timeout s" >&2
exit 1
