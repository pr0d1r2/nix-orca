#!/usr/bin/env bats
# scripts/agents-update.sh (scripts T5, nix/agents T4): update every agent
# input and nothing else. nix is a stub over flake metadata.

bats_require_minimum_version 1.5.0

setup() {
  update="$BATS_TEST_DIRNAME/../../../scripts/agents-update.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
if [ "$1 $2" = "flake metadata" ]; then
  echo '{"locks":{"nodes":{"root":{"inputs":{"nixpkgs":["nixpkgs-lock","nixpkgs"],"nixpkgs-lock":"nixpkgs-lock","claude-code-nix":"claude-code-nix","nix-mistral-vibe":"nix-mistral-vibe"}}}}}'
fi
STUB
  chmod +x stubs/nix
  export NIX="$BATS_TEST_TMPDIR/stubs/nix"
}

@test "every root input but the pin is updated, in one call" {
  run --separate-stderr "$update"
  [ "$status" -eq 0 ]
  [ "$(tail -1 nix.log)" = "flake update claude-code-nix nix-mistral-vibe" ]
}

@test "the pin is never updated here (nixpkgs-lock bumps are their own PR)" {
  run --separate-stderr "$update"
  run grep -E "update .*nixpkgs" nix.log
  [ "$status" -eq 1 ]
}
