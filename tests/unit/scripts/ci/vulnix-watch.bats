#!/usr/bin/env bats
# scripts/ci/vulnix-watch.sh (scripts §C round 9, D15): a vulnix finding
# with CVSS >= 9.0 in a path this package owns opens one issue per CVE;
# pin paths are nixpkgs' to track. Never fails the release. vulnix and gh
# are stubs.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

setup() {
  watch="$BATS_TEST_DIRNAME/../../../../scripts/ci/vulnix-watch.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/vulnix <<'STUB'
#!/usr/bin/env bash
cat <<'JSON'
[
  {"name": "orca-ide-1.4.232", "pname": "orca-ide", "affected_by": ["CVE-2026-1", "CVE-2026-2"],
    "cvssv3_basescore": {"CVE-2026-1": 9.8, "CVE-2026-2": 5.0}},
  {"name": "openssl-3.6.0", "pname": "openssl", "affected_by": ["CVE-2026-3"],
    "cvssv3_basescore": {"CVE-2026-3": 9.9}}
]
JSON
exit 2
STUB
  cat >stubs/gh <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$BATS_TEST_TMPDIR/calls"
case "$*" in "issue list"*) case "$*" in *"${STUB_OPEN:-none}"*) echo 1 ;; *) echo 0 ;; esac ;; esac
STUB
  chmod +x stubs/*
  export VULNIX="$PWD/stubs/vulnix" GH="$PWD/stubs/gh"
}

@test "a critical CVE in an owned path opens one issue" {
  run --separate-stderr "$watch" /nix/store/x-orca-ide-1.4.232
  [ "$status" -eq 0 ]
  grep -q "^gh issue create --title CVE-2026-1 in orca-ide-1.4.232 (CVSS 9.8)" calls
}

@test "below 9.0, or in a pin path, no issue" {
  run --separate-stderr "$watch" /nix/store/x-orca-ide-1.4.232
  run ! grep -qE "CVE-2026-2|CVE-2026-3" calls
}

@test "a CVE with an open issue is not reported twice" {
  export STUB_OPEN=CVE-2026-1
  run --separate-stderr "$watch" /nix/store/x-orca-ide-1.4.232
  [ "$status" -eq 0 ]
  run ! grep -q "issue create" calls
}

@test "every path given is scanned, one issue per CVE across them" {
  run --separate-stderr "$watch" /nix/store/x-orca-ide-1.4.232 /nix/store/y-orca-ide-1.4.232
  [ "$status" -eq 0 ]
  [ "$(grep -c "^gh issue create" calls)" -eq 1 ]
}

@test "no path is a usage error, exit 2" {
  run --separate-stderr "$watch"
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: vulnix-watch.sh STORE-PATH..." ]
}
