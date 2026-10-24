#!/usr/bin/env bats
# scripts/build/linux-build.sh (nix/linux T2): the build phase of the Linux
# source build, sourced by stdenv under its `set -eu -o pipefail`. Every
# tool is a stub that logs "<dir>: <tool> <args>"; node-gyp and cc leave
# the files they would build.

bats_require_minimum_version 1.5.0

setup() {
  script="$BATS_TEST_DIRNAME/../../../../scripts/build/linux-build.sh"
  root=$BATS_TEST_TMPDIR/src
  log=$BATS_TEST_TMPDIR/log
  mkdir -p "$root" "$BATS_TEST_TMPDIR/stubs" "$BATS_TEST_TMPDIR/home" "$BATS_TEST_TMPDIR/electron"
  cd "$root" || exit 1
  mkdir -p mobile node_modules/node-pty node_modules/@parcel/watcher \
    node_modules/@parcel/watcher-linux-x64-glibc node_modules/@parcel/watcher-linux-arm64-glibc \
    node_modules/.bin native/wayland-clipboard
  echo '{}' >package.json
  echo prebuilt >node_modules/@parcel/watcher-linux-x64-glibc/watcher.node
  echo binary >"$BATS_TEST_TMPDIR/electron/electron"

  for tool in node pnpm cc; do
    cat >"$BATS_TEST_TMPDIR/stubs/$tool" <<STUB
#!/usr/bin/env bash
echo "\${PWD#$root}: $tool \$*" >>"$log"
if [ "$tool" = cc ]; then
  while [ "\$#" -gt 1 ]; do [ "\$1" = -o ] && touch "\$2"; shift; done
fi
STUB
  done
  cat >"$BATS_TEST_TMPDIR/stubs/node-gyp" <<STUB
#!/usr/bin/env bash
echo "\${PWD#$root}: node-gyp \$*" >>"$log"
mkdir -p build/Release/obj.target
touch build/Makefile build/config.gypi build/Release/obj.target/x.o
case "\$PWD" in
*/node-pty) echo addon >build/Release/pty.node ;;
*/watcher) echo addon >build/Release/watcher.node ;;
esac
STUB
  cat >node_modules/.bin/electron-builder <<STUB
#!/usr/bin/env bash
echo "\${PWD#$root}: electron-builder \$*" >>"$log"
STUB
  cat >"$BATS_TEST_TMPDIR/stubs/guard" <<STUB
#!/usr/bin/env bash
echo "\${PWD#$root}: guard \$*" >>"$log"
exit "\${STUB_GUARD:-0}"
STUB
  chmod +x "$BATS_TEST_TMPDIR"/stubs/* node_modules/.bin/electron-builder

  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export HOME=$BATS_TEST_TMPDIR/home
  export ORCA_ARCH=x64
  export ELECTRON_DIST=$BATS_TEST_TMPDIR/electron
  export ELECTRON_HEADERS=/store/electron-headers
  export ELECTRON_VERSION=43.7.11
  export ELECTRON_MAJOR_CHECK=$BATS_TEST_TMPDIR/stubs/guard
  export ORCA_MOBILE=1 mobilePnpmDeps=/store/mobile-deps
  export ORCA_HELPER_RPATH=/store/wayland/lib:/store/gtk3/lib
}

runHook() {
  echo "${PWD#"$root"}: runHook $*" >>"$log"
}

pnpmConfigHook() {
  # shellcheck disable=SC2154 # pnpmRoot, pnpmDeps: the script's to set.
  echo "${PWD#"$root"}: pnpmConfigHook root=$pnpmRoot deps=$pnpmDeps" >>"$log"
}

# Its own shell: bats runs a function inside `||`, where errexit is off.
build_phase() {
  export -f runHook pnpmConfigHook
  export root log
  bash -eu -o pipefail -c '. "$1"' _ "$script"
}

@test "the Electron major guard runs first, on upstream's package.json" {
  run build_phase
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p "$log")" = ": guard package.json 43.7.11" ]
}

@test "a failing guard stops the phase before any build step" {
  export STUB_GUARD=1
  run build_phase
  [ "$status" -ne 0 ]
  run ! grep -q "node\|pnpm\|electron-builder" "$log"
}

@test "mobile/ gets its own deps, then its generated sources" {
  run build_phase
  [ "$status" -eq 0 ]
  grep -qxF ": pnpmConfigHook root=mobile deps=/store/mobile-deps" "$log"
  grep -qxF "/mobile: node scripts/build-terminal-webview-engine.mjs" "$log"
  grep -qxF "/mobile: node scripts/build-mermaid-page-engine.mjs" "$log"
  grep -qxF "/mobile: node scripts/build-terminal-document-script.mjs" "$log"
}

@test "without ORCA_MOBILE, no mobile/ deps, sources or web bundle, and no mobile deps needed" {
  unset ORCA_MOBILE mobilePnpmDeps
  run build_phase
  [ "$status" -eq 0 ]
  run ! grep -q "mobile" "$log"
  grep -q "electron-builder --dir" "$log"
}

@test "node-pty and @parcel/watcher build against the pin's Electron headers" {
  run build_phase
  [ "$status" -eq 0 ]
  grep -qxF "/node_modules/node-pty: node-gyp rebuild --nodedir=/store/electron-headers" "$log"
  grep -qxF "/node_modules/@parcel/watcher: node-gyp rebuild --nodedir=/store/electron-headers" "$log"
}

@test "only the addons ship: ours replaces the prebuilt watcher, no build leftovers" {
  run build_phase
  [ "$status" -eq 0 ]
  [ "$(cat node_modules/@parcel/watcher-linux-x64-glibc/watcher.node)" = addon ]
  [ ! -e node_modules/@parcel/watcher/build ]
  [ "$(cd node_modules/node-pty/build && find . -type f)" = "./Release/pty.node" ]
}

@test "arm64 picks the arm64 watcher package and helper directory" {
  export ORCA_ARCH=arm64
  run build_phase
  [ "$status" -eq 0 ]
  [ "$(cat node_modules/@parcel/watcher-linux-arm64-glibc/watcher.node)" = addon ]
  [ -e native/wayland-clipboard/.build/arm64/orca-wayland-clipboard ]
  grep -q "electron-builder --dir --linux --arm64" "$log"
}

@test "the JS bundles build in upstream's release order, the mobile web bundle last" {
  run build_phase
  [ "$status" -eq 0 ]
  want=": pnpm run build:packages
: node node_modules/typescript/bin/tsc -p config/tsconfig.build.cli.json --outDir out --composite false --incremental false
: node config/scripts/verify-cli-bin.mjs --fix-executable --fix-package-json
: node config/scripts/build-wsl-guest.mjs
: node config/scripts/run-electron-vite-build.mjs
: node config/scripts/verify-skills-cli-runtime.cjs out
: node config/scripts/project-renderer-web-client.mjs
: node config/scripts/verify-web-build.mjs
: node config/scripts/build-mobile-web-app-bundle.mjs
: node config/scripts/verify-mobile-web-app-bundle.mjs"
  [ "$(grep -E '^: (node|pnpm) ' "$log")" = "$want" ]
}

@test "the Wayland clipboard helper is compiled where packaging looks" {
  run build_phase
  [ "$status" -eq 0 ]
  [ -e native/wayland-clipboard/.build/x64/orca-wayland-clipboard ]
  grep -q "cc .*-o native/wayland-clipboard/.build/x64/orca-wayland-clipboard" "$log"
}

@test "the helper finds the libraries it dlopens through its RUNPATH" {
  run build_phase
  [ "$status" -eq 0 ]
  grep -q "cc .*-Wl,-rpath,/store/wayland/lib:/store/gtk3/lib .*-o native/wayland-clipboard" "$log"
}

@test "without the helper's RUNPATH the phase fails" {
  unset ORCA_HELPER_RPATH
  run build_phase
  [ "$status" -ne 0 ]
}

@test "electron-builder packages a writable copy of the pin's Electron, outside the checkout" {
  run build_phase
  [ "$status" -eq 0 ]
  grep -qxF ": electron-builder --dir --linux --x64 --config config/electron-builder.config.cjs -c.electronDist=$HOME/electron-dist -c.electronVersion=43.7.11 -c.npmRebuild=false" "$log"
  [ -w "$HOME/electron-dist/electron" ]
  [ ! -e electron-dist ]
}

@test "pre and post build hooks run around it" {
  run build_phase
  [ "$status" -eq 0 ]
  [ "$(head -1 "$log")" = ": runHook preBuild" ]
  [ "$(tail -1 "$log")" = ": runHook postBuild" ]
}
