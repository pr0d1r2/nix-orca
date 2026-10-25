#!/usr/bin/env bash
# Open /dev/kvm on the x86_64-linux CI runner (tests §C, release T1), so
# the NixOS VM checks run under KVM. A runner without it fails the job
# loudly: the VM checks never skip or fall back to TCG. The udev rule is
# the one GitHub documents for its hosted runners.
# Usage: kvm.sh
# Env: KVM_DEV the device (default /dev/kvm); KVM_RULES the rule file
# (default /etc/udev/rules.d/99-kvm4all.rules).
set -euo pipefail

if [ "$#" -ne 0 ]; then
  echo "usage: kvm.sh" >&2
  exit 2
fi
dev=${KVM_DEV:-/dev/kvm}
rules=${KVM_RULES:-/etc/udev/rules.d/99-kvm4all.rules}
fail() {
  echo "kvm: $*" >&2
  exit 1
}

[ -e "$dev" ] || fail "$dev missing: this runner has no KVM, and the VM checks never skip or fall back to TCG (tests §C)"
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' |
  sudo tee "$rules" >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
# trigger only queues the event; wait until udev has applied the rule.
sudo udevadm settle --timeout=30
[ -r "$dev" ] && [ -w "$dev" ] || fail "$dev not readable and writable after the udev rule"
