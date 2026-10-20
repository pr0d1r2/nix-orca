# SPEC

## §G GOAL

`orca-ide` on `x86_64-linux` & `aarch64-linux`: built from upstream tag source, run by pin `electron_43`, size cuts as build inputs.

## §N NAV

rel|path|lens
up|.|-
up|nix|flake outputs, `nix/sources.json`; packages & modules in children
self|nix/linux|Linux `orca-ide` from source on pin Electron
sib|nix/darwin|darwin `orca-ide` from upstream signed zip
sib|nix/bin|`orca-ide-bin` & fixed-output pieces from `.deb`
sib|nix/agents|agent CLI set, `orca-ide-agents`, agent inputs
sib|nix/modules|NixOS, nix-darwin, home-manager modules; `orca-ide.sb`; `.exposure`

## §C CONSTRAINTS

- source: upstream tag via `fetchFromGitHub`, hash in `nix/sources.json` (D38).
- JS deps: 1 fixed-output derivation via pin `fetchPnpmDeps` (`fetcherVersion = 4`, pnpm 11.27.0) from `pnpm-lock.yaml`; path changes only when lockfile does. ⊥ workspace filter: saves 0 (R2). store ∀ platforms (`--force`) 1.84 GB, build-time only, ⊥ in runtime closure, ⊥ cached (`.:V5`). pnpm ! stay 11.27.0, ⊥ self-switch to `packageManager` 12.8.1.
- pnpm major follows the pin: fetcher uses pin `pnpm`; once pin offers pnpm major = upstream `packageManager` major (12 today), switch in own PR w/ new deps hash; check reports while they differ (round 11).
- build: upstream scripts, `ELECTRON_SKIP_BINARY_DOWNLOAD=1`; `app.asar` launched by pin `electron_43` (D21). native modules `node-pty`, `@parcel/watcher` rebuilt vs pin Electron headers.
- Electron major guard: upstream `package.json` Electron major ≠ pin `electron_43` major → build fails, message names `orca-ide-bin` (D21).
- ripgrep: symlink pin `rg` at `resources/ripgrep/<host platform>/rg`; ⊥ other `rg` copies; keep `licenses/` (D23).
- `agent-browser`: symlink pin 0.27.0 at `resources/agent-browser-linux-<arch>`; version ≠ upstream bundled → keep bundled, check reports (D24).
- sherpa-onnx: keep upstream `sherpa-onnx.node` addon; RUNPATH → pin `sherpa-onnx` 1.12.38 & `onnxruntime` 1.24.4; ⊥ bundled `.so` (D25). `c-api.h` changed between bundled & pin version → keep bundled libs, check reports.
- `orcad-template/targets`: from `nix/bin` fixed-output piece, ⊥ rebuilt, ⊥ patched, ⊥ stripped (D33, D38).
- wrapper: `PATH --suffix` pin `git xclip xdotool xdg-utils xvfb xvfb-run` (D28); `libglvnd` on `LD_LIBRARY_PATH`; Wayland flags behind `NIXOS_OZONE_WL`; ⊥ setuid `chrome-sandbox`.
- override `updater = false` → `resources/package-type` value ∉ {`AppImage`, `deb`, `rpm`} (D26); `telemetry = false` → `ORCA_TELEMETRY_DISABLED=1` (D27). defaults = upstream behaviour.
- desktop: `.desktop` w/ `StartupWMClass=orca`, icons, `orca://` handler; upstream `resources/apparmor-profile` installed under `share/` w/ paths rewritten to store (D32).

## §I INTERFACES

- pkg: `orca-ide` (Linux) — `bin/orca-ide` (GUI & CLI: wraps Electron for the app, upstream launcher `resources/bin/orca-ide` for CLI verbs, as upstream's shim does), `share/applications/orca-ide.desktop`, `share/icons/`, `share/apparmor/orca-ide`.
- override: `{ updater ? true, telemetry ? true, agents ? [ ] }`.
- check: `checks.<linux>.{orca-ide-version,electron-major,sherpa-load,runtime-commands,closure-hygiene,closure-budget,rebuild}`.

## §R RESEARCH

id|topic|finding|src
R1|upstream packaging bugs filed 2026-10-20|`stablyai/orca#30993`: `app.asar` ships `cloud/` + 7 root configs, 652 files 6.5 MB, byte-identical to tag; `stablyai/orca#30999`: ssh2 `pagent.exe`, `pagent.c`, `build_pagent.bat` in Linux package|`gh issue view -R stablyai/orca`
R2|JS deps measured 2026-10-20|root `pnpm-lock.yaml` (v9.0, 548 KB) covers app, `src/packages/*`, `native/windows-{registry,security}`; `mobile/` & `cloud/` own lockfiles ∴ ⊥ fetched. `--filter 'orca...'` → same 1311 host packages ∴ filter saves 0. pin `fetchPnpmDeps` (`fetcherVersion = 4`, pnpm 11.27.0, `--force` ∀ platforms): 1524 packages, `pnpm-store.tar.zst` 1.84 GB NAR, 21 s install, 62 s total on aarch64-darwin. outside nix, pnpm 11 self-switches to `packageManager` 12.8.1; inside fetcher stays 11.27.0. largest: `mermaid` 84 MB, `monaco-editor` 73, `agent-browser` 72, `sherpa-onnx-<platform>` 72, `@oven/bun-<platform>` 67, `node-pty` 62|`nix build` of `fetchPnpmDeps` on pin, `nix path-info -S`, `nix log`

## §V INVARIANTS

V1: output ⊥ `cloud/`, ⊥ upstream root dev configs, ⊥ `pagent.exe` `pagent.c` `build_pagent.bat` (R1).
V2: exactly 1 `rg` reachable from `resources/ripgrep` = pin's; ∀ `orcad-template` target carries own `rg`; upstream main process reads `resources/ripgrep` only for local spawn → else check fails (D23).
V3: sherpa load test: Electron in node mode loads addon; `ldd` ∀ lib → pin store paths, ⊥ package path; addon reports version (D25).
V4: `bin/orca-ide --version` prints upstream version from `nix/sources.json`.
V5: closure hygiene (D31): ⊥ build-only path reference; ⊥ foreign build-host RUNPATH | string; closure paths ⊆ allow list per system; ⊥ setuid/setgid, ⊥ world-writable, ⊥ dangling symlink; ∀ ELF interpreter & RUNPATH inside store.
V6: closure size ≤ budget per system; raise = own reviewed commit (D14).
V7: `nix build --rebuild` bit-identical (D30).
V8: ∀ external command upstream main process spawns ∈ wrapper `PATH` | named in README (D28).
V9: `updater = false` → updater reports itself unusable (D26).

## §T TASKS

id|status|task|cites
T1|.|JS deps FOD via `fetchPnpmDeps`; measured (R2)|-
T2|.|source build x86_64-linux on `nix-builder.local`; Electron major guard|V4
T3|.|ripgrep, agent-browser, sherpa swaps + guards|V2,V3
T4|.|wrapper, desktop, AppArmor profile, overrides|V8,V9
T5|.|closure hygiene, budget & rebuild checks|V1,V5,V6,V7
T6|.|hands-on: unprivileged account runs `nix run`, window opens, ⊥ sudo prompt (D38)|V4
T7|.|`aarch64-linux` in CI|V4
T8|.|? narrow JS deps FOD to Linux via `supportedArchitectures` (own fetcher, `fetchPnpmDeps` passes `--force`); measure first, keep only if saving ≥ 25%|-

## §B BUGS

id|date|cause|fix
