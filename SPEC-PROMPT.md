DRAFT INPUT. This file is the prompt for the first ck:spec run. When that
run lands SPEC.md, mark this file HISTORICAL INPUT in its own commit; from
then on SPEC.md and the node specs it federates are the law, and where they
differ from this file, they win.

Paradigm: paradigm (`github.com/pr0d1r2/paradigm`), commit e5605a3 (no
tag yet), with the language pages `docs/NIX.md` and `docs/SHELL.md`. This
repository conforms to the paradigm process in full (decision 9). Process,
guardrail roster and shared conventions come from there; this file states
only the product and its deviations.

nix-orca

Orca, the desktop app for running a fleet of coding agents side by side
(`stablyai/orca`), as a Nix flake on the fleet's pinned nixpkgs, for all
four systems the fleet uses, cached on cachix and released on GitHub every
day.

# Problem and goals

Orca is not in nixpkgs. The `orca` attribute in nixpkgs is the GNOME screen
reader, a different program. Five public flakes and three NUR repositories
package Orca (survey below), but none of them fits the fleet:

- none follows `nixpkgs-lock`, so each one brings its own nixpkgs and a
  machine that attaches Orca to its system closure resolves a second
  nixpkgs, with no shared cache entry. This is the path multiplication
  `nixpkgs-lock` exists to stop.
- none builds `x86_64-darwin`, and only two build `aarch64-darwin`.
- none publishes its built outputs anywhere a consumer can check: there
  are no GitHub releases of nix outputs and no public cache for them.
- upstream releases often (51 stable releases in 70 days), so a hand-bumped
  package falls behind within days.

Goals:
- one flake that exposes Orca as `packages.<system>.orca-ide` and through
  `overlays.default`, so a NixOS, nix-darwin or home-manager configuration
  adds it to its closure with one input that follows `nixpkgs-lock`
- all four fleet systems, `aarch64-darwin`, `x86_64-darwin`,
  `x86_64-linux` and `aarch64-linux`, built by CI with nix, every one
  pushed to cachix
- a daily scheduled run that notices a new upstream release, bumps the pin,
  builds all four systems with nix and publishes a GitHub release of the
  nix outputs, with no human in the loop when every gate is green
- the same gate a fleet repository has: hk from `.pklith` via pklith, CI
  rendered by actlith, a federated spec checked by microlith and sherd,
  token ceilings by itok, characters by characterminator, one language
  per file by xenolith

# Naming

- Repository and flake name: `nix-orca`. The fleet names repositories
  whose product is a nix package of someone else's program
  `nix-<upstream>`: `nix-hk`, `nix-fakecloud`, `nix-mistral-vibe`,
  `nix-semble`, `nix-cavekit`. A deviation from the `-lith` rule, as for
  those; local.
- Package attribute and program: `orca-ide`, the name upstream gives its
  Linux packages (`orca-ide_<v>_amd64.deb`) and its CLI shim. Not `orca`:
  in an overlay that name would shadow the screen reader for every
  consumer of the overlay.
- Availability checked 2026-10-20:
  - no GitHub repository `pr0d1r2/nix-orca`
  - GitHub repository search `nix-orca in:name`: 13 results, most of them
    OrcaSlicer flakes; `Samuka007/nix-orca` packages this Orca,
    `Verantor/nix-orca` is an unrelated "nix helper" last pushed
    2024-09-06
  - nixpkgs (fleet pin `8ce7336`): `orca` is "Screen reader"; no
    `orca-ide`
  - Recount: `gh api repos/pr0d1r2/nix-orca`, `gh api -X GET
    search/repositories -f q='nix-orca in:name' -q .total_count`, `nix
    eval --raw github:NixOS/nixpkgs/<pin>#orca.meta.description`.
- Rejected alternatives (same date, same checks):
  - `orca-nix`: 13 GitHub repositories match, 4 of them package this Orca.
  - `nix-orca-ide`: free (0 results), but longer than it needs to be; the
    repository name is about the upstream project, the attribute about the
    program.
  - a `-lith` name: the fleet keeps `-lith` for its own tools.

# Survey (2026-10-20)

Upstream, `stablyai/orca`:
- MIT, TypeScript, created 2026-03-17, about 98,000 stars.
- Electron 43.7.8, Node 24, pnpm 12.14.0 (`packageManager` in
  `package.json`), a pnpm workspace that also holds `mobile/`, `cloud/`
  and `native/`.
- Latest release `v1.4.230`, 2026-10-19. 51 `v*` stable releases between
  2026-08-10 and 2026-10-19, about one every 1.4 days. Release candidates
  (`-rc.N`) are marked prerelease: 95 of the last 200 releases.
- Release assets per version, the desktop ones and their sizes for
  `v1.4.230`:
  - `orca-ide_<v>_amd64.deb` 210 MB, `orca-ide_<v>_arm64.deb` 205 MB
  - `orca-ide-<v>.x86_64.rpm`, `orca-ide-<v>.aarch64.rpm`
  - `orca-linux.AppImage`, `orca-linux-arm64.AppImage` (unversioned names)
  - `Orca-<v>-arm64-mac.zip` 305 MB, `Orca-<v>-mac.zip` 315 MB (x64)
  - `orca-macos-arm64.dmg`, `orca-macos-x64.dmg`
  - `orca-windows-setup.exe`
  - `latest*.yml` electron-updater manifests, `.blockmap` files, a
    sourcemaps zip
- The app has an electron-updater updater (`src/main/updater/`) with
  `autoDownload = false`; a store copy is read-only, so an update it
  downloads cannot be applied in place.
- Upstream also ships a Homebrew cask (`Casks/orca.rb`, `orca@rc.rb`) and a
  `homebrew-bump.yml` workflow.
- Recount: `gh release list -R stablyai/orca -L 200 --json
  tagName,publishedAt,isPrerelease`, `gh release view -R stablyai/orca
  --json assets`, `gh api repos/stablyai/orca/contents/package.json`.

Fleet nixpkgs pin (`nixpkgs-lock`, nixpkgs `8ce73368`): `electron` 43.7.11,
`pnpm` 11.27.0, `nodejs_24` 24.21.0. Recount: `nix eval --raw
github:NixOS/nixpkgs/<pin>#<attr>.version`.

Prior art, all public, all repackaging upstream's release binaries:
- `numtide/llm-agents.nix` `packages/orca`: `aarch64-darwin`,
  `x86_64-linux`, `aarch64-linux`. Linux from the `.deb`, `autoPatchelf`
  over everything except `resources/orcad-template` (per-platform daemons
  Orca uploads to remote hosts and verifies by sha256, so they must stay
  unpatched and unstripped), `chrome-sandbox` removed (a store path cannot
  be setuid), `libglvnd` on the wrapper's `LD_LIBRARY_PATH` so WebGL does
  not fall back to SwiftShader, the Wayland ozone flags behind
  `NIXOS_OZONE_WL`, `git xclip xdotool xdg-utils xvfb xvfb-run` on `PATH`
  because `orca serve` shells out to them. Darwin from the `-mac.zip`,
  `Orca.app` copied untouched with `dontFixup`. Programs `orca-ide` and
  `orca`. One `hashes.json` per version and an updater.
- `elsirion/orca-nix`: Linux only, from the AppImage, a `smoke` test under
  `ELECTRON_RUN_AS_NODE=1`, deliberately no `orca` command (screen reader
  clash). Carries a source overlay built with `pnpm_11`, because pnpm 12
  ships only as a native binary and pnpm 11 reads its lockfile.
- `kevinpita/orca-nix`: Linux only, NixOS and home-manager modules.
- `Samuka007/nix-orca`: the numtide set of three systems.
- `stslex/orca-nix`: Linux only, a daily update workflow.
- NUR (`lonerOrz`, `AstroOrbis`, `ahmet-cetinkaya` `orca-bin`): Linux
  AppImage wrappers.
- None builds `x86_64-darwin`, follows `nixpkgs-lock`, or publishes built
  outputs.
- Recount: `gh search code stablyai/orca --extension nix`, then read each
  `flake.nix`.

Fleet shape to copy: `nix-mistral-vibe` (root flake with only
`nixpkgs-lock` as input, the gate in a separate `dev/` flake, `.pklith`
seeded by `pklith seed --init`, `build.yml` and `upstream.yml`) and `nix-hk`
(platform table, pin graph, cachix trust trap in the README, a version
check, an upstream watch). Fleet tools on 2026-10-20: `pklith` v0.1.0,
`actlith` v0.1.0, `microlith` v0.7.4, `sherd` v0.5.4, `itok` v0.3.1,
`characterminator` v0.1.1, `xenolith` v0.1.0, `rekall` v0.4.0, hk from
`nix-hk`. Recount: `gh api repos/pr0d1r2/<tool>/tags -q '.[0].name'`.

# Flake sketch

Sketch, not final:
- inputs: `nixpkgs-lock` and `nixpkgs.follows = "nixpkgs-lock/nixpkgs"`,
  nothing else at the root
- `packages.<system>.orca-ide` and `default`, for the four systems
- `overlays.default`: adds `orca-ide`, touches nothing else
- `apps.<system>.orca-ide` and `apps.<system>.default`
- `checks.<system>`: the package, a version check (the binary or the
  bundle's `Info.plist` reports the pinned version), a smoke run of the
  CLI entry point, and an assertion that `orcad-template` is byte-for-byte
  upstream's
- `nix/sources.json`: version and one sha256 per system, the only file a
  bump changes
- `nixConfig`: the `pr0d1r2.cachix.org` substituter and key
- `dev/flake.nix`: the dev shell and gate tools, kept out of consumers'
  lock files; hk from `nix-hk`; entering the shell installs the hooks
  (decision 11)
- `.envrc`: `use flake ./dev`

# Release sketch

Sketch, not final:
- `upstream.yml`, daily cron: read upstream's latest stable release; if it
  is newer than `nix/sources.json`, run the bump script, which fetches the
  four assets and writes their hashes; open a PR.
- `build.yml`, on the PR: build and check all four systems with nix, each
  on a native runner, push to cachix, and verify from a separate job that
  every pushed path is in the cache.
- on merge to `main`: tag `v<upstream version>-nix.<n>` and publish a
  GitHub release whose notes give the upstream version, the nixpkgs rev,
  and the store path per system, with per-system nix outputs as assets
  (format: open question 2) and a `SHA256SUMS` file.
- a day with no new upstream release and no new `nixpkgs-lock` rev makes no
  release.
