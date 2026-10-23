#!/usr/bin/env bats
# scripts/ci/kvm.sh (tests §C, release T1): the x86_64-linux runner opens
# /dev/kvm to the build user, or the job fails loudly; VM checks never
# skip or fall back to TCG. sudo runs its command; udevadm is a stub; the
# device is a file.

bats_require_minimum_version 1.5.0

setup() {
  kvm="$BATS_TEST_DIRNAME/../../../../scripts/ci/kvm.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/sudo <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB
  cat >stubs/udevadm <<'STUB'
#!/usr/bin/env bash
echo "udevadm $*" >>"$BATS_TEST_TMPDIR/udevadm.log"
STUB
  chmod +x stubs/*
  touch kvm
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export KVM_DEV=$BATS_TEST_TMPDIR/kvm KVM_RULES=$BATS_TEST_TMPDIR/99-kvm.rules
}

@test "the udev rule opens kvm to every user, then udev applies it" {
  run --separate-stderr "$kvm"
  [ "$status" -eq 0 ]
  [ "$(cat 99-kvm.rules)" = 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' ]
  [ "$(cat udevadm.log)" = "udevadm control --reload-rules
udevadm trigger --name-match=kvm" ]
}

@test "no /dev/kvm fails loudly, nothing written" {
  rm kvm
  run --separate-stderr "$kvm"
  [ "$status" -eq 1 ]
  [ "$stderr" = "kvm: $BATS_TEST_TMPDIR/kvm missing: this runner has no KVM, and the VM checks never skip or fall back to TCG (tests §C)" ]
  [ ! -e 99-kvm.rules ]
}

@test "a device still not usable after udev fails" {
  chmod 000 kvm
  run --separate-stderr "$kvm"
  [ "$status" -eq 1 ]
  [ "$stderr" = "kvm: $BATS_TEST_TMPDIR/kvm not readable and writable after the udev rule" ]
}

@test "any argument is a usage error, exit 2" {
  run --separate-stderr "$kvm" x86_64-linux
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: kvm.sh" ]
}
