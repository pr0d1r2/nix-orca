#!/usr/bin/env bats
# scripts/service/serve-bind.sh (nix/modules §C, T7): `listenInterface`.
# The service's command runs with ORCA_SERVE_BIND_HOST set to the
# interface's IPv4 address, waiting for one to appear. `ip` is a stub.

bats_require_minimum_version 1.5.0

setup() {
  bind="$BATS_TEST_DIRNAME/../../../../scripts/service/serve-bind.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/ip <<'STUB'
#!/usr/bin/env bash
# ip -4 -o addr show dev IFACE: an address only once STUB_UP exists.
echo "ip $*" >>"$BATS_TEST_TMPDIR/ip.log"
[ -e "$BATS_TEST_TMPDIR/up" ] || exit 0
echo "2: $5    inet 192.168.1.20/24 brd 192.168.1.255 scope global dynamic $5"
echo "2: $5    inet 10.0.0.7/8 scope global secondary $5"
STUB
  cat >stubs/show <<'STUB'
#!/usr/bin/env bash
echo "$ORCA_SERVE_BIND_HOST $*"
STUB
  chmod +x stubs/ip stubs/show
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH" SERVE_BIND_TIMEOUT=3
}

@test "the command runs with the interface's first IPv4 address" {
  touch up
  run --separate-stderr "$bind" enp3s0 -- show serve --port 6768
  [ "$status" -eq 0 ]
  [ "$output" = "192.168.1.20 serve --port 6768" ]
  grep -qx "ip -4 -o addr show dev enp3s0" ip.log
}

@test "it waits for the address to come up" {
  (sleep 1 && touch up) &
  run --separate-stderr "$bind" enp3s0 -- show
  [ "$status" -eq 0 ]
  [ "$output" = "192.168.1.20 " ]
}

@test "no address within the timeout fails, the command never runs" {
  run --separate-stderr "$bind" enp3s0 -- touch ran
  [ "$status" -eq 1 ]
  [ "$stderr" = "serve-bind: enp3s0 has no IPv4 address after 3 s" ]
  [ ! -e ran ]
}

@test "without the separator or a command it is a usage error, exit 2" {
  run --separate-stderr "$bind" enp3s0 serve
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: serve-bind.sh INTERFACE -- COMMAND..." ]
}
