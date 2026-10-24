#!/usr/bin/env bash
# Build phase of the Linux orca-ide (nix/linux T2), sourced by stdenv after
# pnpmConfigHook installed the root deps. Upstream's release build, step by
# step, without its downloads: native modules against the pin's Electron
# headers, the JS bundles, the Wayland clipboard helper, then
# electron-builder --dir on the pin's Electron. Sourced, so it sets no
# shell options; a failing step fails the phase.
# Env: ORCA_ARCH (x64 | arm64), ELECTRON_DIST, ELECTRON_HEADERS,
# ELECTRON_VERSION, ELECTRON_MAJOR_CHECK (scripts/check/electron-major.sh),
# ORCA_HELPER_RPATH (where the clipboard helper finds what it dlopens);
# ORCA_MOBILE=1 builds Orca Mobile's web bundle, from mobilePnpmDeps (the
# mobile/ deps fetch). Without it the app has no bundle, which upstream's
# app treats as an install without Orca Mobile.

# shellcheck disable=SC2154 # set by the derivation.
: "${ORCA_ARCH:?}" "${ELECTRON_DIST:?}" "${ELECTRON_HEADERS:?}" "${ELECTRON_VERSION:?}" \
  "${ELECTRON_MAJOR_CHECK:?}" "${ORCA_HELPER_RPATH:?}"
mobile=${ORCA_MOBILE:-}

runHook preBuild

bash "$ELECTRON_MAJOR_CHECK" package.json "$ELECTRON_VERSION"

# mobile/ has its own lockfile; its postinstall generates sources the web
# bundle imports.
if [ "$mobile" = 1 ]; then
  pnpmRoot=mobile pnpmDeps=${mobilePnpmDeps:?} pnpmConfigHook
  (cd mobile && node scripts/build-terminal-webview-engine.mjs &&
    node scripts/build-mermaid-page-engine.mjs &&
    node scripts/build-terminal-document-script.mjs)
fi

# Native modules against the pin's Electron. Upstream's rebuild script
# downloads Electron first; node-gyp with the pin's headers needs nothing.
for module in node_modules/node-pty node_modules/@parcel/watcher; do
  (cd "$module" && node-gyp rebuild --nodedir="$ELECTRON_HEADERS")
done
# @parcel/watcher loads its addon from the platform package, a prebuilt
# binary from npm; ours replaces it.
cp node_modules/@parcel/watcher/build/Release/watcher.node \
  "node_modules/@parcel/watcher-linux-$ORCA_ARCH-glibc/watcher.node"
rm -r node_modules/@parcel/watcher/build
# Only the addon ships: node-gyp's Makefiles and objects name the build's
# Node, node-gyp and Python.
mv node_modules/node-pty/build/Release/pty.node "$HOME/pty.node"
rm -r node_modules/node-pty/build
mkdir -p node_modules/node-pty/build/Release
mv "$HOME/pty.node" node_modules/node-pty/build/Release/pty.node

pnpm run build:packages
node node_modules/typescript/bin/tsc -p config/tsconfig.build.cli.json \
  --outDir out --composite false --incremental false
node config/scripts/verify-cli-bin.mjs --fix-executable --fix-package-json
node config/scripts/build-wsl-guest.mjs
node config/scripts/run-electron-vite-build.mjs
node config/scripts/verify-skills-cli-runtime.cjs out
node config/scripts/project-renderer-web-client.mjs
node config/scripts/verify-web-build.mjs
if [ "$mobile" = 1 ]; then
  node config/scripts/build-mobile-web-app-bundle.mjs
  node config/scripts/verify-mobile-web-app-bundle.mjs
fi

# Upstream's flags. The helper dlopens libwayland-client and GTK by name,
# which on NixOS only its RUNPATH can find.
helper=native/wayland-clipboard/.build/$ORCA_ARCH
mkdir -p "$helper"
cc -O2 -Wall -Wextra -Werror -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
  -fPIE -pie -Wl,-z,relro,-z,now -Wl,-rpath,"$ORCA_HELPER_RPATH" \
  native/wayland-clipboard/wayland-clipboard.c \
  native/wayland-clipboard/x11-clipboard-publisher.c \
  -ldl -o "$helper/orca-wayland-clipboard"

# electron-builder renames and rewrites the Electron it packages. Outside
# the checkout: upstream's all-negation `files` list packs whatever else is
# in it into app.asar.
cp -r "$ELECTRON_DIST" "$HOME/electron-dist"
chmod -R u+w "$HOME/electron-dist"
node_modules/.bin/electron-builder --dir --linux "--$ORCA_ARCH" \
  --config config/electron-builder.config.cjs \
  -c.electronDist="$HOME/electron-dist" \
  -c.electronVersion="$ELECTRON_VERSION" \
  -c.npmRebuild=false

runHook postBuild
