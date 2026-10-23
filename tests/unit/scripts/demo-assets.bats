#!/usr/bin/env bats
# scripts/demo-assets.sh (scripts T6, tests T4): re-record the demo with
# the agents-stub check and commit its files into docs/demo/, alone. nix
# is a stub whose build prints a fake check output; git is real, in a
# scratch repository.

bats_require_minimum_version 1.5.0

setup() {
  assets="$BATS_TEST_DIRNAME/../../../scripts/demo-assets.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir stubs out repo
  for f in demo.mp4 preview.webp shot.png run.mp4; do
    echo "$f 1" >"out/$f"
  done
  cat >stubs/nix <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$BATS_TEST_TMPDIR/nix.log"
[ "$1" = build ] && echo "$BATS_TEST_TMPDIR/out"
true
STUB
  chmod +x stubs/nix
  export NIX="$BATS_TEST_TMPDIR/stubs/nix"
  cd repo || exit 1
  git init -q
  git config user.email test@localhost
  git config user.name test
  mkdir nix
  echo '{"version":"1.4.232"}' >nix/sources.json
  git add -A
  git commit -qm init
}

@test "the check's demo files land in docs/demo/ in one commit of their own" {
  run --separate-stderr "$assets"
  [ "$status" -eq 0 ]
  grep -qx "build --no-link --print-out-paths .#checks.x86_64-linux.agents-stub" ../nix.log
  [ "$(git log -1 --format=%s)" = "docs(demo): re-record orca-ide 1.4.232" ]
  [ "$(git show --name-only --format= HEAD | sort | tr '\n' ' ')" = "docs/demo/demo.mp4 docs/demo/preview.webp docs/demo/shot.png " ]
  [ "$(cat docs/demo/shot.png)" = "shot.png 1" ]
}

@test "a store builds remotely, the output is copied back" {
  run --separate-stderr "$assets" ssh-ng://root@builder
  [ "$status" -eq 0 ]
  grep -qx "build --no-link --print-out-paths --store ssh-ng://root@builder --eval-store auto .#checks.x86_64-linux.agents-stub" ../nix.log
  grep -qx "copy --no-check-sigs --from ssh-ng://root@builder $BATS_TEST_TMPDIR/out" ../nix.log
}

@test "the same recording again commits nothing, exit 3" {
  "$assets"
  head=$(git rev-parse HEAD)
  run --separate-stderr "$assets"
  [ "$status" -eq 3 ]
  [ "$stderr" = "demo-assets: docs/demo/ unchanged" ]
  [ "$(git rev-parse HEAD)" = "$head" ]
}

@test "a new recording replaces the files" {
  "$assets"
  echo "shot.png 2" >../out/shot.png
  run --separate-stderr "$assets"
  [ "$status" -eq 0 ]
  [ "$(git show --name-only --format= HEAD)" = "docs/demo/shot.png" ]
}

@test "staged changes are refused, so the commit holds the assets alone" {
  echo x >other
  git add other
  run --separate-stderr "$assets"
  [ "$status" -eq 1 ]
  [ "$stderr" = "demo-assets: changes are staged; the commit holds the demo files alone" ]
  [ ! -e ../nix.log ]
}

@test "an output without a demo file fails, nothing committed" {
  rm ../out/preview.webp
  head=$(git rev-parse HEAD)
  run --separate-stderr "$assets"
  [ "$status" -eq 1 ]
  [ "$stderr" = "demo-assets: $BATS_TEST_TMPDIR/out has no preview.webp" ]
  [ "$(git rev-parse HEAD)" = "$head" ]
}

@test "more than one argument is a usage error, exit 2" {
  run --separate-stderr "$assets" a b
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: demo-assets.sh [STORE]" ]
}
