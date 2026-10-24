#!/usr/bin/env bash
# Install phase of the Linux orca-ide (nix/linux T2), sourced by stdenv from
# the built tree. electron-builder's unpacked app keeps upstream's layout:
# Electron's executable beside `resources/`, which Electron derives
# `process.resourcesPath` from and Orca reads 58 times. wrapProgram,
# patchShebangs and runHook are stdenv's, gappsWrapperArgsHook
# wrapGAppsHook3's. Sourced, so it sets no shell options.
# Env: ORCA_ARCH (x64 | arm64), ORCA_TEMPLATE (the orcad template piece),
# ORCA_PATH (runtime PATH prefix: agents), ORCA_RUNTIME_PATH (suffix: the
# commands Orca runs, V8), ORCA_AGENT_BROWSER and
# ORCA_AGENT_BROWSER_VERSION (the pin's binary and its version),
# ORCA_SHERPA_RPATH (the sherpa-onnx addon's RUNPATH), ORCA_PACKAGE_TYPE
# (resources/package-type: deb, or anything else for an unusable updater,
# D26), ORCA_TELEMETRY (`false` sets ORCA_TELEMETRY_DISABLED=1, D27),
# ORCA_RG_X64 and ORCA_RG_ARM64 (the pin's static rg for the Linux remote
# targets, root T18), gappsWrapperArgs (wrapGAppsHook3's array, filled by
# gappsWrapperArgsHook).

# shellcheck disable=SC2154 # set by stdenv and the derivation.
: "${out:?}" "${ORCA_ARCH:?}" "${ORCA_TEMPLATE:?}" "${ORCA_PATH?}" "${ORCA_RUNTIME_PATH:?}" \
  "${ORCA_AGENT_BROWSER:?}" "${ORCA_AGENT_BROWSER_VERSION:?}" "${ORCA_SHERPA_RPATH:?}" \
  "${ORCA_PACKAGE_TYPE:?}" "${ORCA_TELEMETRY:?}" "${ORCA_RG_X64:?}" "${ORCA_RG_ARM64:?}"

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
# The template; its manifest names the rg below (nix/linux §C).
ln -s "$ORCA_TEMPLATE" "$app/resources/orcad-template"
# The Linux rg the relay uploads to remote hosts: the pin's static builds,
# copied, since the relay reads and sends the file itself (root T18).
install -m 755 "$ORCA_RG_X64" "$app/resources/ripgrep/linux-x64/rg"
install -m 755 "$ORCA_RG_ARM64" "$app/resources/ripgrep/linux-arm64/rg"

# Upstream's agent-browser asks for /lib64/ld-linux-x86-64.so.2; the pin's
# runs on NixOS. Only at upstream's version (D24).
bundled=$(jq -r .version node_modules/agent-browser/package.json)
if [ "$bundled" = "$ORCA_AGENT_BROWSER_VERSION" ]; then
  ln -sf "$ORCA_AGENT_BROWSER" "$app/resources/agent-browser-linux-$ORCA_ARCH"
else
  echo "agent-browser: upstream bundles $bundled, the pin has $ORCA_AGENT_BROWSER_VERSION; keeping upstream's" >&2
fi

# sherpa-onnx: upstream's addon on the pin's libraries; its own RUNPATH
# names the CI runner's home (D25).
sherpa=$app/resources/node_modules/sherpa-onnx-linux-$ORCA_ARCH
rm "$sherpa"/*.so
patchelf --set-rpath "$ORCA_SHERPA_RPATH" "$sherpa/sherpa-onnx.node"

# Orca's updater reads it: deb as in upstream's .deb, any other value makes
# it report itself unusable (D26). electron-builder --dir wrote AppImage.
printf '%s\n' "$ORCA_PACKAGE_TYPE" >"$app/resources/package-type"

# The environment the pin's own electron wrapper sets. Chromium's Wayland
# flags only for the app: the launcher runs CLI verbs in Electron's node
# mode, where Node refuses them.
gappsWrapperArgsHook
# shellcheck disable=SC2016 # expanded by the wrapper at run time.
wrap=(
  "${gappsWrapperArgs[@]}"
  --set CHROME_DEVEL_SANDBOX "$app/chrome-sandbox"
  --prefix PATH : "$ORCA_PATH"
  --suffix PATH : "$ORCA_RUNTIME_PATH"
  --run 'orca_wayland_flags=; if [ -z "${ELECTRON_RUN_AS_NODE-}" ] && [ -n "${NIXOS_OZONE_WL-}" ] && [ -n "${WAYLAND_DISPLAY-}" ]; then orca_wayland_flags="--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true"; fi'
  --add-flags '$orca_wayland_flags'
)
if [ "$ORCA_TELEMETRY" = false ]; then
  wrap+=(--set ORCA_TELEMETRY_DISABLED 1)
fi
wrapProgram "$app/orca-ide" "${wrap[@]}"
# bin/orca-ide is upstream's launcher: CLI verbs, and `open` starts the app.
patchShebangs "$app/resources/bin/orca-ide"
ln -s "$app/resources/bin/orca-ide" "$out/bin/orca-ide"

# Icons at every size upstream's .icns holds, as its .deb ships them.
icons=$(mktemp -d)
icns2png -x -o "$icons" resources/build/icon.icns
for png in "$icons"/icon_*x*x32.png; do
  size=${png##*/icon_}
  size=${size%%x*}
  install -Dm644 "$png" "$out/share/icons/hicolor/${size}x${size}/apps/orca-ide.png"
done

# Upstream's .deb entry, for the store's Electron (D32).
mkdir -p "$out/share/applications"
cat >"$out/share/applications/orca-ide.desktop" <<ENTRY
[Desktop Entry]
Name=Orca
Exec=$app/orca-ide %U
Terminal=false
Type=Application
Icon=orca-ide
StartupWMClass=orca
Comment=Next-gen IDE for parallel agentic development
MimeType=text/markdown;text/csv;text/tab-separated-values;x-scheme-handler/orca;
Categories=Utility;
ENTRY

# Upstream's .deb profile (D32), naming the executable Electron runs as.
mkdir -p "$out/share/apparmor"
cat >"$out/share/apparmor/orca-ide" <<PROFILE
abi <abi/4.0>,
include <tunables/global>

profile "orca-ide" "$app/.orca-ide-wrapped" flags=(unconfined) {
  userns,

  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/orca-ide>
}
PROFILE

runHook postInstall
