#!/usr/bin/env bats
# scripts/sbom.sh (scripts T3, D29): CycloneDX and SPDX SBOMs of a system's
# runtime closure, named for the release. sbomnix is a stub.

bats_require_minimum_version 1.5.0

setup() {
  sbom="$BATS_TEST_DIRNAME/../../../scripts/sbom.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs out
  cat >stubs/sbomnix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/sbomnix.log"
while [ "$#" -gt 0 ]; do
  case "$1" in
  --cdx | --spdx | --csv) echo '{}' >"$2"; shift ;;
  esac
  shift
done
STUB
  chmod +x stubs/sbomnix
  export SBOMNIX="$BATS_TEST_TMPDIR/stubs/sbomnix"
}

@test "both SBOMs of the runtime closure land in the output directory" {
  run --separate-stderr "$sbom" x86_64-linux /nix/store/abc-orca-ide out
  [ "$status" -eq 0 ]
  [ -f out/orca-ide-x86_64-linux.cdx.json ]
  [ -f out/orca-ide-x86_64-linux.spdx.json ]
  run grep -c -- "--buildtime" sbomnix.log
  [ "$output" = 0 ]
  grep -q "^/nix/store/abc-orca-ide " sbomnix.log
}

@test "no CSV is left behind" {
  run --separate-stderr "$sbom" x86_64-linux /nix/store/abc-orca-ide out
  [ "$(find . -name '*.csv' | wc -l)" -eq 0 ]
}

@test "anything but a system, a path and a directory is a usage error, exit 2" {
  run --separate-stderr "$sbom" x86_64-linux
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: sbom.sh SYSTEM STORE-PATH OUT-DIR" ]
}
