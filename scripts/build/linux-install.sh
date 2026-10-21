#!/usr/bin/env bash
# Install phase of the Linux orca-ide (nix/linux T2), sourced by stdenv from
# the built tree. electron-builder's unpacked app keeps upstream's layout:
# Electron's executable beside `resources/`, which Electron derives
# `process.resourcesPath` from and Orca reads 58 times. wrapProgram,
# patchShebangs and runHook are stdenv's, gappsWrapperArgsHook
# wrapGAppsHook3's. Sourced, so it sets no shell options.
# Env: ORCA_ARCH (x64 | arm64), ORCA_TEMPLATE (the orcad template piece),
# ORCA_PATH (runtime PATH prefix),
# gappsWrapperArgs (wrapGAppsHook3's array, filled by gappsWrapperArgsHook).

# shellcheck disable=SC2154 # set by stdenv and the derivation.
: "${out:?}" "${ORCA_ARCH:?}" "${ORCA_TEMPLATE:?}" "${ORCA_PATH?}"

runHook preInstall

unpacked=dist/linux-unpacked
if [ "$ORCA_ARCH" = arm64 ]; then
  unpacked=dist/linux-arm64-unpacked
fi
app=$out/libexec/orca-ide
mkdir -p "$out/libexec" "$out/bin"
cp -r "$unpacked" "$app"
# No Electron default app (nix/linux §C). chrome-sandbox stays, without its
# setuid bit (the store drops it): named by CHROME_DEVEL_SANDBOX below,
# Chromium finds it unusable and takes its user-namespace sandbox. Unnamed,
# Electron traps at start.
rm "$app/resources/default_app.asar"
# pnpmConfigHook pointed node_modules' scripts at the build's Node; they ship
# with upstream's interpreter line, as in upstream's .deb.
grep -rlE '^#!/nix/store/[^ ]+/bin/node' "$app/resources/node_modules" |
  xargs -r sed -i '1s|^#!/nix/store/[^ ]*/bin/node|#!/usr/bin/env node|'
# Upstream's template, byte for byte (nix/bin V1).
ln -s "$ORCA_TEMPLATE" "$app/resources/orcad-template"

# The environment the pin's own electron wrapper sets.
gappsWrapperArgsHook
wrapProgram "$app/orca-ide" "${gappsWrapperArgs[@]}" \
  --set CHROME_DEVEL_SANDBOX "$app/chrome-sandbox" \
  --prefix PATH : "$ORCA_PATH"
# bin/orca-ide is upstream's launcher: CLI verbs, and `open` starts the app.
patchShebangs "$app/resources/bin/orca-ide"
ln -s "$app/resources/bin/orca-ide" "$out/bin/orca-ide"

runHook postInstall
