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
- JS deps: 1 fixed-output derivation (+ `mobile/`'s, R3) via pin `fetchPnpmDeps` (`fetcherVersion = 4`, pnpm 11.27.0) from `pnpm-lock.yaml`; path changes only when lockfile does. ⊥ workspace filter: saves 0 (R2). store ∀ platforms (`--force`) 1.84 GB, build-time only, ⊥ in runtime closure, ⊥ cached (`.:V5`). pnpm ! stay 11.27.0, ⊥ self-switch to `packageManager` 12.8.1.
- pnpm major follows the pin: fetcher uses pin `pnpm`; once pin offers pnpm major = upstream `packageManager` major (12 today), switch in own PR w/ new deps hash; check reports while they differ (round 11).
- build: upstream `build:release` steps, ⊥ download (R4); `electron-builder --dir` on pin `electron_43` dist (D21): Electron derives `process.resourcesPath` from its executable's dir & Orca reads it 58× ∴ app = pin dist copied beside `resources/`, executable byte-identical to pin's; ⊥ fixup on it (RUNPATH shrink drops dlopen'd libglvnd, vulkan, pipewire). native modules `node-pty`, `@parcel/watcher` built by `node-gyp` vs pin Electron headers.
- Electron major guard: upstream `package.json` Electron major ≠ pin `electron_43` major → build fails, message names `orca-ide-bin` (D21).
- ripgrep: `resources/ripgrep` = upstream's bytes, ∀ platform: each `rg` is the SSH relay upload for its platform, checked vs `orcad-template.json` sha256 (R5; amends D23 2026-10-21, owner review root T17).
- `agent-browser`: symlink pin 0.27.0 at `resources/agent-browser-linux-<arch>`; version ≠ upstream bundled → keep bundled, check reports (D24).
- sherpa-onnx: keep upstream `sherpa-onnx.node` addon; RUNPATH → pin `sherpa-onnx` 1.12.38 (→ `onnxruntime` 1.24.4) & cc runtime libs; ⊥ bundled `.so` (D25; +83 MiB closure). `c-api.h` changed between bundled & pin version → keep bundled libs, check reports.
- `orcad-template`: `nix/bin` fixed-output piece, linked; ⊥ rebuilt, ⊥ patched, ⊥ stripped (D33, D38).
- runtime: `PATH --suffix` pin `gitMinimal procps xclip xdotool xdg-utils xvfb wl-clipboard` (D28 + R6); hard-coded `/bin/bash` (hooks, PID-1 reaper) & `/bin/ps` (tmux probe) → store's; rest named in README (V8).
- wrapper: GApps env of pin `electron` wrapper ⊥ gtk4 (Electron runs GTK 3; gtk4 = 1 GB closure); `CHROME_DEVEL_SANDBOX` → own non-setuid `chrome-sandbox` (unset → SIGILL at start; set → user-namespace sandbox); Wayland flags behind `NIXOS_OZONE_WL`, ⊥ in node mode; ⊥ setuid `chrome-sandbox`.
- override `updater = false` → `resources/package-type` value ∉ {`AppImage`, `deb`, `rpm`} (D26); `telemetry = false` → `ORCA_TELEMETRY_DISABLED=1` (D27). defaults = upstream behaviour.
- desktop: `.desktop` w/ `StartupWMClass=orca`, icons, `orca://` handler; upstream `resources/apparmor-profile` installed under `share/` w/ paths rewritten to store (D32).

## §I INTERFACES

- pkg: `orca-ide` (Linux) — `bin/orca-ide` → upstream launcher `resources/bin/orca-ide` (CLI verbs; `open` starts app), `libexec/orca-ide/` (app, wrapped Electron), `share/applications/orca-ide.desktop`, `share/icons/`, `share/apparmor/orca-ide`.
- override: `{ updater ? true, telemetry ? true, agents ? [ ] }`.
- check: `checks.<linux>.{orca-ide-version,electron-major,sherpa-load,ripgrep,agent-browser,runtime-commands,updater-off,closure-hygiene,closure-budget}`; rebuild = `build.yml` `--rebuild` step (⊥ flake check).

## §R RESEARCH

id|topic|finding|src
R1|upstream packaging bugs filed 2026-10-20|`stablyai/orca#30993`: `app.asar` ships `cloud/` + 7 root configs, 652 files 6.5 MB, byte-identical to tag; `stablyai/orca#30999`: ssh2 `pagent.exe`, `pagent.c`, `build_pagent.bat` in Linux package|`gh issue view -R stablyai/orca`
R2|JS deps measured 2026-10-20|root `pnpm-lock.yaml` (v9.0, 548 KB) covers app, `src/packages/*`, `native/windows-{registry,security}`; `mobile/` & `cloud/` own lockfiles ∴ ⊥ fetched. `--filter 'orca...'` → same 1311 host packages ∴ filter saves 0. pin `fetchPnpmDeps` (`fetcherVersion = 4`, pnpm 11.27.0, `--force` ∀ platforms): 1524 packages, `pnpm-store.tar.zst` 1.84 GB NAR, 21 s install, 62 s total on aarch64-darwin. outside nix, pnpm 11 self-switches to `packageManager` 12.8.1; inside fetcher stays 11.27.0. largest: `mermaid` 84 MB, `monaco-editor` 73, `agent-browser` 72, `sherpa-onnx-<platform>` 72, `@oven/bun-<platform>` 67, `node-pty` 62|`nix build` of `fetchPnpmDeps` on pin, `nix path-info -S`, `nix log`
R3|`mobile/` deps measured 2026-10-21|desktop ships `out/mobile-web` (8.5 MB, esbuild of `mobile/`), so build needs `mobile/` deps: own `pnpm-lock.yaml` ∴ 2nd `fetchPnpmDeps` (`preInstall = "cd mobile"`), 736 MiB, 25 s; its postinstall generators skipped by `--ignore-scripts` → run in build|`nix build` on nix-builder.local
R4|source build 2026-10-21, `v1.4.232`, nix-builder.local (Ryzen 7 3800X)|sandbox, offline: upstream rebuild script downloads Electron, AppImage step downloads Node, clipboard helper builds in Docker, `git rev-parse` needs `.git`; each replaced (`scripts/build/linux-*.sh`). pnpm 11 collector packed deps into `app.asar` (39 MB vs .deb 7 MB) → excluded. file set = amd64 `.deb`'s minus 4 renamed renderer chunks. closure 1.4 GiB; onboarding renders under Xvfb as unprivileged user|`nix build`, `diff` of file lists, Xvfb screenshot
R5|ripgrep in `v1.4.232` 2026-10-21|`resources/ripgrep` holds `rg` for 6 platforms; template targets for Linux & Windows carry empty `ripgrep/` dirs (upstream `compact-packaged-orcad-ripgrep.cjs`), darwin ones own signed copies; `orcad-template.json` lists `ripgrep/<platform>/rg` sha256; `src/main/ripgrep/bundled-ripgrep-path.ts` hashes them to gate SSH upload ∴ swap or removal breaks remote deploy|`find`, `grep` of manifest & source
R6|runtime commands & telemetry 2026-10-21|survey of `src/main`, `src/shared`, `src/cli` (⊥ tests): core `git`, `ps`; `/bin/bash` hard-coded for orca.yaml hooks, `/bin/ps` for tmux probe; optional `xdg-open` (via Electron), `xclip`/`wl-copy`, `xdotool`, `Xvfb`, `ssh`, `tmux`, `systemd-run`, `secret-tool`, `gdbus`, `gh`, `glab`, `python3`+gi; `xvfb-run` only in test fixtures. `electron.vite.config.ts`: PostHog key & build identity injected by upstream CI only → source build never sends telemetry|Explore agent survey, `grep`
R7|`orca serve` 2026-10-21 (launch VM test)|local orcad slot needs upstream's official Node, sha256-pinned (`NODE_RUNTIME_ASSETS`), from AppImage or a run-time download ∴ ⊥ store Node; serve falls back to Electron serve & works (port answers). serve binds `0.0.0.0` unless told; installs `~/.local/bin/orca-ide` → store path itself|`scripts/check/vm-orca.sh serve`, `src/main/orcad/orcad-local-serve-selection.ts`

## §V INVARIANTS

V1: output ⊥ `cloud/`, ⊥ upstream root dev configs, ⊥ `pagent.exe` `pagent.c` `build_pagent.bat` (R1).
V2: ∀ `ripgrep/<platform>/rg` in `orcad-template.json`: `resources/ripgrep/<platform>/rg` exists, sha256 = manifest's (R5).
V3: sherpa load test: Electron in node mode loads addon; `ldd` ∀ lib → pin store paths, ⊥ package path; addon reports version (D25).
V4: `bin/orca-ide --version` prints upstream version from `nix/sources.json`.
V5: closure hygiene (D31): ⊥ build-only path reference; ⊥ foreign build-host RUNPATH | string; closure paths ⊆ allow list per system; ⊥ setuid/setgid, ⊥ world-writable, ⊥ dangling symlink; ∀ ELF interpreter & RUNPATH inside store.
V6: closure size ≤ budget per system; raise = own reviewed commit (D14).
V7: `nix build --rebuild` bit-identical (D30).
V8: ∀ external command upstream main process spawns ∈ wrapper `PATH` | named in README (D28).
V9: `updater = false` → updater reports itself unusable (D26).

## §T TASKS

id|status|task|cites
T1|x|JS deps FOD via `fetchPnpmDeps`; measured (R2)|-
T2|x|source build x86_64-linux on `nix-builder.local`; Electron major guard|V4
T3|x|agent-browser, sherpa swaps + guards; ripgrep kept (R5) w/ V2 check|V2,V3
T4|x|wrapper, desktop, AppArmor profile, overrides|V8,V9
T5|x|closure hygiene, budget & rebuild checks|V1,V5,V6,V7
T6|.|hands-on: unprivileged account runs `nix run`, window opens, ⊥ sudo prompt (D38)|V4
T7|.|`aarch64-linux` in CI: first build measures `.closure-budget` line & checks names vs `closure-allow.txt` (from x86_64)|V4,V5,V6
T8|.|? narrow JS deps FOD to Linux via `supportedArchitectures` (own fetcher, `fetchPnpmDeps` passes `--force`); measure first, keep only if saving ≥ 25%|-

## §B BUGS

id|date|cause|fix
