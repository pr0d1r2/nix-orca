#!/usr/bin/env bash
# Let bwrap make a user namespace inside the nix sandbox on the Linux CI
# runner (nix/agents V3). Ubuntu 24.04's AppArmor keeps unprivileged
# processes out of new user namespaces, so an agent wrapped in bwrap
# (`rovo`, `acli`) fails its --version check with "setting up uid map:
# Permission denied". A kernel without the knob needs nothing.
# Usage: userns.sh
# Env: USERNS_KNOB the knob (default
# /proc/sys/kernel/apparmor_restrict_unprivileged_userns).
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo "usage: userns.sh" >&2
  exit 2
fi
knob=${USERNS_KNOB:-/proc/sys/kernel/apparmor_restrict_unprivileged_userns}

[ -e "$knob" ] || exit 0
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 >/dev/null
if [ "$(cat "$knob")" != 0 ]; then
  echo "userns: $knob is still $(cat "$knob"); bwrap in the nix sandbox cannot make a user namespace" >&2
  exit 1
fi
