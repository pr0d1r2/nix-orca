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
four systems the fleet uses, built daily, cached on cachix and released on
GitHub when upstream releases. Linux is built from source.

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
- `nix/sources.json`: version, the source and dependency hashes, and the
  darwin zip hashes, the only file a bump changes
- `nixConfig`: the `pr0d1r2.cachix.org` substituter and key
- `dev/flake.nix`: the dev shell and gate tools, kept out of consumers'
  lock files; hk from `nix-hk`; entering the shell installs the hooks
  (decision 11)
- `.envrc`: `use flake ./dev`

# Release sketch

Sketch, not final:
- `upstream.yml`, daily cron: read upstream's latest stable release; if it
  is newer than `nix/sources.json`, run the bump script, which fetches the
  tag's source, its JS dependencies and the two darwin zips and writes
  their hashes; open a PR.
- `build.yml`, on the PR: build and check all four systems with nix
  (`x86_64-darwin` through Rosetta, decision 39), push the Linux outputs
  to cachix (decision 41), and verify from a separate job that every
  pushed path is in the cache.
- on merge to `main`: tag `v<upstream version>-nix.<n>` and publish a
  GitHub release whose notes give the upstream version, the nixpkgs rev,
  and the store path per system, with no binary assets (decision 22).
- a day with no new upstream release makes no release, even when
  `nixpkgs-lock` moved (decision 19).

# Decisions (2026-10-20)

1. Systems: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`,
   `aarch64-linux`, all tier 1: built by CI, cached, released. Deviation
   from `nix-hk` and `nix-mistral-vibe`, which keep `x86_64-darwin` tier 2:
   there it means compiling, here it means unpacking a zip, so a missing
   Intel runner is not a reason to drop it (open question 3). Local.
2. Windows is not a target. Nix does not run there, so a Windows asset
   would be upstream's installer passed through, which nix adds nothing to.
   Windows users take upstream's `orca-windows-setup.exe`; WSL users take
   the Linux package. Local.
3. Daily releases (owner's request, 2026-10-20): the schedule is daily, the
   release happens only when its inputs change (decision 4). Every release
   is built by nix in CI from the tagged commit; nothing is uploaded from a
   workstation. Local.
4. A release is keyed by the pair (upstream version, nixpkgs rev). Either
   one moving makes a new `-nix.<n>`; neither moving makes none. Local.
5. Package attribute `orca-ide`, programs `orca-ide` on every system; no
   `orca` command, because on Linux it collides with the screen reader in
   any closure that has both (`elsirion/orca-nix` made the same call).
   Local.
6. The package never updates itself: Orca's updater is switched off or made
   inert in the package, and a test proves it. An update arrives as a new
   flake release, nowhere else. Local.
7. Only stable releases are packaged; `-rc.N` prereleases are skipped.
   Local.
8. The root flake has one input, `nixpkgs-lock`; the gate's tools live in
   `dev/flake.nix`, as in `nix-mistral-vibe`, so a consumer's lock file
   gains one node. Local.
9. The repository conforms to the paradigm process in full and is a fleet
   member, gated like `nix-mistral-vibe`: hk from `.pklith`, CI from
   `.actlith`, a federated spec, the paradigm lifecycle and its
   waivers. Every deviation is a numbered decision here, or a `.pklith`
   `exempt` row citing `paradigm/V<n>` with a reason. Local.
10. Every bump PR merges itself when every required check is green, so the
    daily loop needs no human; a red check stops it and leaves the PR open.
    Candidate (the fleet's `nix-*` repositories all bump by hand or by PR).
11. Dev shell (owner's request, 2026-10-20): `dev/flake.nix` provides the
    dev shell, entered by direnv (`.envrc`: `use flake ./dev`) or `nix
    develop ./dev`. hk comes from `nix-hk`, following `nixpkgs-lock`, and
    the shell hook installs the git hooks on every entry, idempotently, so
    a fresh clone is gated from its first shell, with no manual `hk
    install`. A shell without hk refuses to install hooks rather than
    falling back to another hook runner (paradigm/V23). Local.

# Decisions, round 2 (2026-10-20): what nix adds

No prior-art package does any of these; together they are why a consumer
picks this flake over the others.

12. Hashes come from upstream's own manifests. Each release carries
    electron-updater manifests (`latest-mac.yml`, `latest-linux.yml`,
    `latest-linux-arm64.yml`) with a `sha512` and `size` per asset,
    checked present for `v1.4.230`. The bump script takes each fetch hash
    as SRI `sha512-...` from the manifest and refuses an asset whose
    manifest entry is missing or whose size differs, so nix itself checks
    upstream's stated hash on every fetch. Limit, stated so nobody
    oversells it: the manifest ships in the same GitHub release as the
    asset, so this catches a corrupt or swapped upload, not a compromised
    release. Recount: `gh release download <tag> -R stablyai/orca -p
    'latest*.yml'`. Local.
13. Attested releases. Each GitHub release states, per system, the store
    path, the NAR hash, the nixpkgs rev and the commit, and carries a
    GitHub artifact attestation (SLSA build provenance) for every asset,
    so `gh attestation verify` ties an asset to the workflow run and
    commit that built it. Local.
14. Release notes say what changed: a closure diff against the previous
    release per system (`nvd`, 0.2.4 in the pin, or `nix store
    diff-closures`) and the closure size per system. A closure budget per
    system, measured from the first release, fails CI when a bump grows
    past it; raising it is its own reviewed commit. Local.
15. Vulnerability scan of every release closure with `vulnix` (1.12.4 in
    the pin, wrapped by the fleet's `nix-lefthook-vulnix-scan`), findings
    in the release notes. A separate check reports when the Electron
    bundled in Orca lags the pin's `electron_43`: on 2026-10-20 upstream's
    `package.json` declares 43.7.8 and the pin has 43.7.11. Both report;
    neither blocks a release until a gap round says which findings should.
    Local.
16. Launch tests beyond `--version`. Linux: a `runNixOSTest` VM starts
    `orca-ide` under Xvfb and runs `orca-ide serve` headless, asserting it
    answers. Darwin: `codesign --verify --deep --strict` on the store
    `Orca.app`, proving the signature survived the copy into the store (a
    NAR keeps no extended attributes, so this is a real question). Local.
17. One nixpkgs, from `nixpkgs-lock` (owner's request, 2026-10-20), for
    everything: the package, the dev flake, and every tool this round
    names (`nvd`, `vulnix`, `electron_43`, the agent CLIs). "The pin" in
    this file always means `nixpkgs-lock`'s nixpkgs. No input may bring a
    second nixpkgs, not even nixpkgs-unstable for a newer Electron or
    agent CLI; a lock-graph check (exactly one nixpkgs node, every input
    `follows` it, `docs/NIX.md`) fails the gate otherwise. The repository
    follows `nixpkgs-lock` bumps through `nixpkgs-lock-subscribe`, and a
    bump is a release input (decision 4). Narrows decision 8. Local.
18. Binary cache: `pr0d1r2.cachix.org`, the fleet's existing cache (owner's
    request, 2026-10-20), public key
    `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`,
    the same one `nix-hk` and `nix-mistral-vibe` use. Both flakes'
    `nixConfig` list it. CI pushes every system's package and the dev
    shell from `main` and the release job only, with the token in the
    `CACHIX_AUTH_TOKEN` repository secret; PR jobs build without it, so a
    fork PR never sees it. A separate job verifies every pushed path is in
    the cache (`nix path-info --store https://pr0d1r2.cachix.org`), as in
    `nix-hk`. The README states the untrusted-substituter trap. The space
    in open question 4 is this shared cache's, so retention must not evict
    the rest of the fleet. Local.

# Decisions, round 3 (2026-10-20): cadence and cost

19. Build daily, release on upstream (owner's answer, 2026-10-20). The
    daily run builds and checks all four systems from `main`; with no
    input changed every path is a cachix hit, so it costs an evaluation
    and a substitution, not a build or new cache space. A new upstream
    stable version is the only thing that makes a release. A
    `nixpkgs-lock` bump is built, checked and cached the day it lands, but
    waits for the next upstream version to be released. Amends decisions 3,
    4 and 17. Local.
20. Build once (owner's answer, 2026-10-20). The bump PR comes from a
    branch of this repository, so its build job pushes to cachix; the
    release job on `main` asserts every path is already cached and builds
    nothing. PRs from forks build without the token, as decision 18 says.
    Amends decision 18. Local.
21. Linux runs on the pin's Electron, not the bundled one (owner's
    request, 2026-10-20; closes open question 6). Measured on the
    `v1.4.230` amd64 `.deb`: 680 MB unpacked, of which 318 MB is the
    Electron runtime (`orca-ide` 216 MB, `locales/` 46 MB, Chromium libs
    and paks) and 363 MB is Orca's own `resources/`. The package keeps
    only `resources/` and launches `app.asar` with `electron_43` from
    `nixpkgs-lock`, so each release adds about half the bytes to the
    store and the cache, and the runtime is one shared path per Electron
    version that also gets nixpkgs' security bumps. Bundled Electron is
    43.7.8 (Chrome 150, read from the binary), the pin's is 43.7.11; the
    native modules (`node-pty` built for ABI 148, `@parcel/watcher`,
    `sherpa-onnx`) target the Electron 43 ABI, which a patch release does
    not change. Guards: a check fails when upstream's bundled Electron
    major differs from the pin's, and the decision 16 VM test runs on this
    package. `orca-ide-bundled-electron` stays as a fallback attribute,
    built and tested but not cached or released, for the days a major
    lands upstream before it lands in the pin. Darwin keeps upstream's
    Electron (rejected design below). Recount: `strings opt/Orca/orca-ide
    | grep -m1 Electron/`, `du -sk opt/Orca opt/Orca/resources`. Local.
22. Releases carry no binaries (closes open question 2). A GitHub release
    holds text only: per system the store path, the NAR hash and size,
    the closure size, the nixpkgs rev and the commit; a `SHA256SUMS` over
    the upstream assets it was built from; and the decision 13
    attestations, made over the NAR hashes. The bytes come from
    `pr0d1r2.cachix.org` only, so `nix build github:pr0d1r2/nix-orca/<tag>`
    or `nix-store -r <path>` with the substituter is how a release is
    fetched. Saves about 1 GB of GitHub storage per release, and a
    consumer never gets an artifact nix did not check. Candidate
    `(a)` (a `nix copy --to file://` tarball) is rejected for that size;
    `nix bundle` was Linux only. Local.
23. Linux uses the pin's `ripgrep` for local search and drops
    `resources/ripgrep` (28 MB, `rg` for 6 platforms), keeping its
    `licenses/`. Checked in upstream's source on 2026-10-20: remote hosts
    get the `rg` inside their own `orcad-template/targets/<target>/`
    ("Only the target's own ripgrep ships (design D2)",
    `src/shared/orcad-artifacts.ts`; copied by `build-orcad.mjs`), and
    the only remaining callers of `resources/ripgrep` are the local spawn
    (`bundledRipgrepCommand`) and WSL routing, which only a Windows host
    does. The SSH comment in `config/bundled-ripgrep-resources.cjs` is
    stale: `bundledRipgrepContentKey` has no callers outside tests. The
    package puts a symlink to the pin's `rg` at
    `resources/ripgrep/<host platform>/rg`, where
    `resolveBundledRipgrepPath` looks first. `orcad-template` stays
    byte-for-byte upstream's (decision 16 checks it). Guards, so the cut
    reverts the day upstream changes: a check fails when any
    `orcad-template` target lacks its own `rg`, and when upstream's
    compiled main process reads `resources/ripgrep` for anything but the
    local spawn. Darwin is unchanged: `resources/` is inside the signed
    `Orca.app`. A first draft of this prompt rejected the cut on the stale
    comment; the source said otherwise. Local.
24. Linux uses the pin's `agent-browser` (owner's answer, 2026-10-20).
    `resources/agent-browser-linux-<arch>` (11 MB) is upstream's
    `agent-browser` 0.27.0, the same version the pin ships. It runs
    locally only: upstream bundles just the host's build
    (`config/electron-builder.config.cjs`) and no `orcad-template` target
    carries it. The package replaces it with a symlink to the pin's
    binary at the same path. Guard: a check fails when upstream's bundled
    version and the pin's differ, and the package then keeps the bundled
    binary until they match again. Darwin unchanged (inside the signed
    `Orca.app`). Recount: `strings agent-browser-linux-x64 | grep -m1
    'agent-browser [0-9]'`, `nix eval --raw <pin>#agent-browser.version`.
    Local.
25. Linux uses the pin's sherpa-onnx and onnxruntime libraries, with a
    load test (owner's answer, 2026-10-20). Upstream's
    `node_modules/sherpa-onnx-linux-x64` (local speech-to-text,
    `src/main/speech/`) carries `libonnxruntime.so` 1.23.2 (23 MB),
    `libsherpa-onnx-c-api.so` (4.8 MB) and `libsherpa-onnx-cxx-api.so`
    from sherpa-onnx 1.12.37; the pin ships `sherpa-onnx` 1.12.38, whose
    `lib/` has both API libraries, linked to the pin's `onnxruntime`
    1.24.4. The package deletes the three libraries, keeps upstream's
    `sherpa-onnx.node` addon (0.9 MB) and points its RUNPATH at the pin's
    `sherpa-onnx`. Load test, a check on every build: Electron in node
    mode loads the addon, `ldd` shows every library resolving to the pin's
    store paths and none to the package, and the addon reports its
    version; a recognition round trip runs on a small model fetched as a
    fixed-output derivation, if one of a few MB exists (the spec run
    picks it). The decision 16 VM test loads the speech worker as well.
    Guard: the contract is sherpa-onnx's C API, not its version number.
    The addon is N-API (`napi_register_module_v1`), so Electron's ABI does
    not matter, but it passes config structs by pointer to
    `libsherpa-onnx-c-api.so`: a field added in a newer library still
    loads and silently reads the wrong memory. So the bump script diffs
    `sherpa-onnx/c-api/c-api.h` between upstream's bundled version and the
    pin's (`gh api repos/k2-fsa/sherpa-onnx/compare/v<a>...v<b>`), and on
    any change the package keeps the bundled libraries and a check
    reports it. For 1.12.37 to 1.12.38: 3 commits, 97 files, none under
    `c-api/` (checked 2026-10-20). The recognizer-creation step of the
    load test is what would catch a layout change the diff missed.
    Saves 28 MB per release. Darwin unchanged. Recount: `grep version
    node_modules/sherpa-onnx-linux-x64/package.json`, `readelf -d` on the
    addon and libraries. Local.

# Decisions, round 4 (2026-10-20): wrapper, proofs, integration

26. Updater off switch, opt-in (owner's answer, 2026-10-20). Upstream
    reads `resources/package-type` (`src/main/linux-update-package-type.ts`)
    and its own comment names Nix among the repackagers that inherit the
    `.deb`'s marker; a value other than `AppImage`, `deb` or `rpm` makes
    the updater fail closed. `orca-ide.override { updater = false; }`
    writes such a value, with a check that the updater reports itself
    unusable. Default: upstream's marker, untouched; on NixOS upstream
    already treats the install as externally managed because no trusted
    `dpkg` exists. On another distribution with `dpkg`, upstream may offer
    to install its `.deb` system-wide beside the nix one; the README says
    so and recommends the override there. Darwin has no switch: downloads
    are user-triggered (`autoDownload = false`) and installing into the
    read-only store fails; the README says so. Amends decision 6, which
    now holds by default only where upstream detects the external
    manager. Local.
27. Telemetry off switch, opt-in (owner's answer, 2026-10-20). Upstream
    honours `DO_NOT_TRACK=1` and `ORCA_TELEMETRY_DISABLED=1`
    (`docs/site/content/docs/telemetry.mdx`). `orca-ide.override {
    telemetry = false; }` sets `ORCA_TELEMETRY_DISABLED=1` in the wrapper.
    Default: upstream's behaviour (patching behaviour is a non-goal). On
    darwin the wrapper covers `bin/orca-ide` launches only, not the Dock
    or Finder; the README says so and points at Settings, Privacy. Local.
28. Runtime tools from the pin (owner's answer, 2026-10-20). `orca serve`
    and the computer-use surface shell out to `git`, `xclip`, `xdotool`,
    `xdg-utils`, `xvfb` and `xvfb-run` (the `.deb`'s `Depends`, as numtide
    found). The Linux wrapper puts the pin's builds on `PATH` with
    `--suffix`, so a consumer's own tools still win; darwin gets `git`
    only. A check lists every external command upstream's main process
    spawns and fails on one the wrapper does not provide or the README
    does not name. Local.
29. SBOM per release (owner's answer, 2026-10-20). `sbomnix` (1.7.6 in the
    pin) writes a CycloneDX and an SPDX SBOM per system from the release
    closure; both are text, attached to the release (decision 22) and
    covered by the decision 13 attestations. Local.
30. Reproducibility proof (owner's answer, 2026-10-20). CI runs `nix build
    --rebuild` for every system's package and fails when the rebuild is
    not bit-identical; the release notes say it was. Cheap here, since
    nothing compiles. Local.
31. Closure hygiene, as checks (owner's answer, 2026-10-20):
    - no reference to a build-only path (`disallowedReferences` on the
      fetch and unpack inputs)
    - no RUNPATH or string naming a foreign build host, such as the
      `/home/runner/work/sherpa-onnx/...` RUNPATH upstream's sherpa addon
      carries
    - the closure's store paths match an allow list per system (Electron,
      `ripgrep`, `agent-browser`, `sherpa-onnx`, `onnxruntime`, the
      decision 28 tools, glibc and the libraries `autoPatchelf` adds); a
      new path fails until the list is changed in a reviewed commit
    - no setuid or setgid file, no world-writable file, no dangling
      symlink in the output
    - every ELF file's interpreter and RUNPATH resolve inside the store
    Local.
32. Desktop integration and README notes (owner's answer, 2026-10-20).
    Linux: a `.desktop` entry (`StartupWMClass=orca`, as numtide found
    Electron reports it), the icons from the `.deb`, the `orca://` URL
    handler, and Wayland flags behind `NIXOS_OZONE_WL`. README notes:
    Ubuntu 24.04 and later restrict unprivileged user namespaces through
    AppArmor, and a store path cannot hold a setuid `chrome-sandbox`, so
    Electron from nix will not start there without an AppArmor profile.
    Upstream ships one in the `.deb` (`resources/apparmor-profile`, for
    `/opt/Orca`); the package installs it under `share/` with its paths
    rewritten to the store path, and the README says how to load it,
    rather than suggesting `--no-sandbox`. On
    nix-darwin `Orca.app` lands in `Nix Apps`, which Spotlight may not
    index. Plus decisions 26 and 27's notes. Local.
33. Content-addressed split on Linux (owner's answer, 2026-10-20).
    Measured `v1.4.229` against `v1.4.230` (amd64): 514 of 663 MB of
    files are byte-identical. Beyond what decisions 21 and 23 to 25
    already drop, the stable parts are `orcad-template/targets` (58.5 MB,
    91.5% unchanged), `node_modules` without sherpa (about 20 MB, 99.8%),
    `onboarding` (10.9 MB, 100%) and `app.asar.unpacked/resources` (4.1
    MB, 100%). Today each release makes new store paths for all of them,
    because the derivation hangs off the new `.deb`. Each stable subtree
    becomes its own fixed-output derivation, extracted from the `.deb`,
    whose recursive NAR hash the bump script computes (`nix hash path`)
    and writes to `nix/sources.json`; an unchanged subtree keeps its
    store path, so cachix stores it once. The package symlinks the pieces
    into `resources/`. Expected: about 205 MB of new store paths per
    release instead of about 295. Risk: upstream resolves some paths with
    `realpath` and checks they stay inside `process.resourcesPath` (seen
    in the updater), which a symlinked subtree can fail; so the decision 16
    VM test runs on this layout, plus an SSH upload from `orcad-template`
    to a second VM checked by Orca's own sha256. If any piece fails, that
    piece is copied in instead of linked. Darwin impossible: the signed
    `.app` stays one tree. Recount: hash every file of two consecutive
    `.deb`s and group by top-level `resources/` entry. Local.
34. Local Linux work runs on `nix-builder.local` (owner's note,
    2026-10-20), a node built from the public `pr0d1r2/nixos-nix-builder`:
    `x86_64-linux`, `supportedFeatures` `nixos-test`, `kvm`,
    `big-parallel`, reached over SSH as a `nix.buildMachines` entry and
    serving `nix-serve` on port 5000. From the aarch64-darwin workstation,
    every `x86_64-linux` build and every `runNixOSTest` VM (decisions 16,
    25 and 33) goes there, as `docs/NIX.md` asks ("Linux-only work from
    macOS goes to a remote Linux builder"); the dev shell names the
    builder and fails with a clear message when it is unreachable, rather
    than trying a Linux build on darwin. The builder is configured in the
    owner's machine configuration, not in this repository. It has no
    `aarch64-linux`: that system is built and tested in CI only
    (`ubuntu-24.04-arm`) unless the builder gains binfmt emulation. Its
    `nix-serve` is a local convenience; nothing built there is pushed to
    cachix or released, which stays CI's job (decision 3). Amends build
    order step 1. Local.
35. Hardening is tested, on `nix-builder.local` (owner's note,
    2026-10-20). The module from open question 5 runs `orca-ide serve` as
    a hardened systemd service (`DynamicUser`, `ProtectSystem=strict`,
    `ProtectHome`, `PrivateTmp`, `PrivateDevices`, `NoNewPrivileges`,
    `CapabilityBoundingSet=`, `RestrictAddressFamilies`,
    `SystemCallFilter=@system-service`, `MemoryDenyWriteExecute` where V8
    allows it), and every setting is proven by a `runNixOSTest` run on the
    builder:
    - `systemd-analyze security orca-ide-serve` exposure score is a
      ratchet floor kept in `.exposure` (not `.coverage`, which
      paradigm/V25 reserves); a change that raises it fails
    - `orca-ide serve` answers, and a client session runs an agent
      command, under the full hardening
    - the same service runs inside a NixOS container (systemd-nspawn,
      `containers.<name>`) within the VM, for hosts that run agents
      containerised
    - each relaxation carries a comment naming what breaks without it.
      Known tension: `serve` starts Electron under Xvfb, and Chromium's
      sandbox needs user namespaces, so `RestrictNamespaces` and
      `PrivateUsers` are settled by the test, not by guessing
    The VM tests need `kvm` and `nixos-test`, which the builder has and
    `ubuntu-24.04` runners give only partly; CI runs them where KVM is
    available and the builder is the reference. Applies once the module
    node exists; open question 5 still decides whether that is version 1.
    Local.
36. Darwin service hardening with Seatbelt itself, on by default, with an
    opt-out (owner's answer, 2026-10-20; closes open question 8). The
    nix-darwin module (`darwinModules.default`) runs `orca-ide serve` as
    a `launchd.daemons` job under a dedicated user from nix-darwin
    `users.users` (launchd `UserName`, `GroupName`), with launchd limits
    (`Umask`, `WorkingDirectory`, resource limits, `ProcessType`), through
    the built-in `/usr/bin/sandbox-exec` and a Seatbelt profile kept in
    this repository (`orca-ide.sb`): deny by default; read `/nix/store`
    and the system paths Electron needs; read and write only the state
    directory; inbound TCP only on the serve port; exec only from
    `/nix/store`. The module renders the store path, state directory and
    port as `sandbox-exec -D` parameters. Nothing beyond macOS is
    installed; nix's own darwin build sandbox uses the same mechanism,
    and nix's `sandbox-defaults.sb` and Chromium's `.sb` profiles are the
    prior art the profile is written from, since Apple does not document
    the profile language. Opt-out: `services.orca-ide.sandbox.enable =
    false` drops `sandbox-exec` and keeps the dedicated user and launchd
    limits; the option's description says it is for when the profile
    breaks something, and the README asks for an issue whenever it is
    used. Probes, run by CI on a macOS runner (no nested virtualisation)
    and in a Tart macOS VM on the owner's Mac as the reference: the job
    starts; `serve` answers; a write outside the state directory fails;
    the owner's home is not readable; and the unified log (`log show
    --predicate 'sender == "Sandbox"'`) shows only the denials the test
    expects, so an unexpected denial fails the test. Known unknown,
    settled by the probes: Chromium applies its own Seatbelt profile to
    its helpers, which may not work under an outer profile; if it fails,
    the profile is relaxed where the log points, not dropped. Network
    rules are by address and port, not domain. Applies once the module
    node exists (open question 5). Local.

# Decisions, round 5 (2026-10-20): the blocking questions

37. Releases go out without a human, under a waiver of paradigm/V32
    (owner's answer, 2026-10-20). V32 asks explicit human approval for
    every publish because a registry artifact is immutable. This
    repository publishes only to channels that can be undone: a cachix
    push (a store path is named by its inputs or content, so dropping one
    uses up no name, and pushing it again gives the same bytes) and a
    text-only GitHub release and tag, both deletable. So the owner
    approves the pipeline and its first release (Process); after that,
    releases go out behind the required checks with no approval per
    release. Recorded as a `.pklith` `exempt` row for `paradigm/V32`
    citing `pr0d1r2/paradigm#24`, which proposes splitting V32: per-publish
    approval for irreversible registries (crates.io; probably npm, PyPI
    and the Go module proxy), approval once for reversible channels. The
    row goes when paradigm decides. Nothing here publishes to an
    irreversible registry. Candidate (`pr0d1r2/paradigm#24`).
38. Linux is built from source; darwin repackages upstream's signed app
    (owner's answer, 2026-10-20; closes open question 1). The Linux size
    work rests on source: decisions 21 and 23 to 25 stop being surgery on
    a `.deb` and become build inputs, and what upstream packs by mistake
    (`stablyai/orca#30993`, `#30999`) never enters the output. Sketch:
    the upstream tag by `fetchFromGitHub`; the JS dependencies as one
    fixed-output derivation from `pnpm-lock.yaml` with the pin's pnpm
    11.27.0 (`elsirion` shows it reads upstream's pnpm 12 lockfile), so
    that path changes only when the lockfile does; upstream's own build
    scripts with Electron's download switched off; `app.asar` run by the
    pin's `electron_43`; `node-pty` and `@parcel/watcher` rebuilt against
    the pin's Electron headers; sherpa-onnx as decision 25 says. What
    source cannot make, `orcad-template/targets` (daemons for other
    platforms, which Orca checks by sha256 on the remote host), comes
    from upstream's `.deb` as a fixed-output piece (decision 33), and the
    decision 33 SSH upload test proves Orca accepts it. The `.deb`
    repackage of decisions 21 and 33 stays as `orca-ide-bin`, built and
    tested but not cached or released, in place of
    `orca-ide-bundled-electron`: it is the fallback both for an Electron
    major ahead of the pin and for a source build upstream breaks (a
    lockfile pnpm 11 cannot read, a new build-time download). Linux
    hashes are the tag's source hash and the dependencies' hash; decision
    12's manifest cross-check stays for darwin and `orca-ide-bin`.
    Darwin stays on upstream's signed `-mac.zip`: an unsigned source
    build costs the signature, TCC grants and keychain items, as the
    rejected nixpkgs Electron on darwin does. Darwin may lag: the first
    release can be Linux only, with darwin in a later one, if source
    work takes the time. First hands-on test: Linux, as an unprivileged
    account (no sudo, not in `trusted-users`). For that user the flake's
    `nixConfig` substituter is ignored (the cachix trust trap), so the
    machine's admin adds `pr0d1r2.cachix.org` to `substituters` and
    `trusted-public-keys`, or the user builds locally; and Chromium's
    sandbox runs on unprivileged user namespaces, since the store holds
    no setuid `chrome-sandbox` (decision 32 covers distributions that
    restrict them). The test passes when that user runs the package with
    `nix run`, the window opens (or `serve` answers when headless), and
    nothing asks for sudo. Amends decisions 12, 21 and 33 and the build
    order. Local.
39. `x86_64-darwin` is built on the arm64 macOS runner through Rosetta
    (owner's answer, 2026-10-20; closes open question 3), with
    `extra-platforms = x86_64-darwin`. The derivation unpacks and copies,
    so nothing compiles under emulation; the job installs Rosetta when
    the image lacks it (`softwareupdate --install-rosetta
    --agree-to-license`). A check asserts that `lipo -archs` of
    `Orca.app/Contents/MacOS/Orca` prints `x86_64`, so the arm64 zip
    cannot land under the x64 attribute, and decision 16's `codesign
    --verify` and launch run under Rosetta. Nothing depends on GitHub's
    Intel macOS runners. Local.
40. Retention (owner's answer, 2026-10-20; closes open question 4): the
    last darwin output (dropped by decision 41) and the last 2 Linux
    outputs per system stay cached, held by cachix pins: the current one
    and one known-good fallback, since rolling Linux back otherwise means
    a source build.
    Why so few: `pr0d1r2.cachix.org` is on cachix's free tier, 5 GB for
    open source (cachix.org/pricing, 2026-10-20), shared with every fleet
    repository that pushes there. After a push, CI runs `cachix pin
    pr0d1r2 orca-ide-<system> <path>` with `--keep-revisions 1` on darwin
    and `--keep-revisions 2` on Linux (`cachix` 1.11.1 in the pin), only
    when the path differs from the pin's newest revision, so the daily
    no-change build (decision 19) does not rotate the pins. An output is
    a distinct store path, so a `nixpkgs-lock` bump counts as one even
    without a release. Unpinned paths are left to the cache's own
    retention, which is cache-wide and shared with the fleet; this
    repository never changes that setting and never deletes a path.
    Release notes say the bytes stay cached while pinned; past that,
    `nix build` of an old tag rebuilds from source (Linux) or fetches
    upstream's zip again (darwin). Space, estimated 2026-10-20 (store
    sizes are NAR bytes; the cache stores them zstd-compressed):
    - darwin: one `Orca.app` per system, about 0.6 GB for both, taken
      from the zip sizes (305 and 315 MB), as signed Mach-O compresses
      about as well under zstd as under the zip's deflate.
    - Linux: about 295 MB for a first output and about 205 MB for each
      new one (decision 33's `.deb` figures), so 2 outputs are about 0.5
      GB per system and 1 GB for both; about 0.35 GB compressed, at an
      assumed 35%. The source build should be smaller and is measured at
      its first push.
    - The pin's Electron and other nixpkgs paths are not counted, on the
      expectation that cachix skips paths cache.nixos.org already holds;
      the first push checks it.
    - Pinned total: about 1 GB, and it stays flat, against open question
      4's 25 GB a month with no retention.
    - Pushed each month, before the cache collects it: about 21 releases,
      so about 13 GB of darwin and 3 GB of Linux. Darwin is most of that
      churn and gains least from the cache, as its output is a download
      and an unzip.
    Recount: the pin listing on app.cachix.org, `nix path-info -S --json`
    per output, the zip sizes in `gh release view -R stablyai/orca --json
    assets`. Local.
41. Darwin is not pushed to cachix (owner's answer, 2026-10-20). The
    5 GB free tier (decision 40) is shared with the fleet, and darwin
    would push about 13 GB a month of the 16 GB total. A cache that
    full may evict other members' paths every week or two. A darwin
    output is only upstream's zip unpacked, so the cache saves a
    consumer an unzip and little else. CI still builds and checks both
    darwin systems; the release notes still give their store paths and
    NAR hashes, with attestations over them. A consumer's `nix build`
    fetches the zip from GitHub as a fixed-output derivation and unpacks
    it locally, about 300 MB per update and no compiler. That rebuild
    gives the attested NAR hash because of decision 30's proof. No
    darwin pin. Cachix then holds only Linux: about 0.35 GB pinned and
    about 3 GB pushed a month. The cache's garbage collection keeps that
    under 5 GB. Amends decisions 18, 20 and 22 (the release job asserts
    only Linux paths are cached) and 40. Local.

# Decisions, round 6 (2026-10-20): modules, agents, integration

42. Modules in version 1, stacked (owner's answer, 2026-10-20; closes
    open question 5). Each module is its own node, built on the one
    before it, in atomic commits: the overlay; then
    `nixosModules.orca-ide` (the package and declarative settings);
    then its `services.orca-ide` running `serve` with decision 35's
    hardening; then `darwinModules.orca-ide` with decision 36's
    Seatbelt profile; then `homeManagerModules.orca-ide`. A node is done
    when its tests pass (decision 16's VM for NixOS, the macOS runner and
    Tart for nix-darwin, an activation check for home-manager), and only
    then does the next start. Amends the build order. Local.
43. Agent CLIs as native nix packages (owner's answer, 2026-10-20;
    closes open question 7). Orca `v1.4.230` knows 45 agents, each found
    by a `detectCmd` on `PATH` (`src/shared/tui-agent-config.ts`). Every
    one with a usable nix package ships with this flake, 18 of them:
    - from per-agent flakes that track upstream releases, ahead of the
      pin: `sadjow/claude-code-nix` (`claude` 2.1.304),
      `sadjow/codex-cli-nix` (`codex` 0.163.0), `sadjow/gemini-cli-nix`
      (`gemini` 0.64.0), `sadjow/pi-nix` (`pi` 1.3.0),
      `AodhanHayter/grok-build-nix` (xAI's Grok Build, `grok` 1.0.62)
      and the fleet's `nix-mistral-vibe` (`vibe` 2.26.1);
    - from the pin: `opencode` 1.15.10, `aider-chat` 0.86.1 (`aider`),
      `goose-cli` 1.28.0, `amp-cli` (`amp`), `crush` 0.70.0, `codebuff`
      1.0.674, `cursor-cli` (`cursor-agent`), `github-copilot-cli` 1.0.61
      (`copilot`), `kiro-cli` 2.3.0, `qwen-code` 0.16.0 (`qwen`), `acli`
      1.3.36 (Rovo Dev) and `openclaw` 2026.5.7.
    Not matched: the pin's `grok-cli` 0.0.33 is a different, community
    CLI under the same command; its `antigravity` is the IDE, whose
    program is not Orca's `agy` (checked when packaged); `kilocode-cli`
    lists no platforms and installs `kilocode`, not `kilo`; the pin's
    `ante` and `muse` are unrelated programs (a language, a MIDI
    sequencer). The other 26, Orca itself (`claude-agent-teams`)
    aside, have no nix package; each is a later node, sent to nixpkgs
    where its licence allows. Inputs: the five per-agent flakes are
    `flake = false` inputs whose `package.nix` is called with the pin's
    packages, so the closure keeps one nixpkgs and the lock gains five
    leaf nodes; `nix-mistral-vibe` is a flake input with
    `inputs.nixpkgs-lock.follows`. A consumer overrides any agent from
    their own flake (`inputs.nix-orca.inputs.claude-code-nix.url = ...`
    or `.follows`), and per package with `orca-ide.override { agents =
    [ ... ]; }`. Outputs: `orca-ide` stays lean with no agents;
    `orca-ide-agents` puts all 18 on Orca's `PATH`, and each agent is
    also `legacyPackages.<system>.agents.<name>`; an agent missing on a
    system is left out there rather than failing the build. Seven are
    unfree (`claude-code`, `amp-cli`, `crush`, `cursor-cli`,
    `github-copilot-cli`, `kiro-cli`, `acli`): the flake's own outputs
    evaluate with `allowUnfree`, the overlay honours the consumer's
    setting. Neither `orca-ide-agents` nor any agent is pushed to
    cachix: unfree licences forbid redistributing most of them, the
    free ones are on cache.nixos.org or their flakes' caches, and the 5
    GB tier (decision 40) has no room. A daily job updates the agent
    inputs in its own PR, which builds and checks but makes no release
    (decision 19). Later, not version 1: each agent in its own
    `systemd-nspawn` container or hardened unit, as decision 35 tests
    for `serve`. Amends decision 8 (the root gains six inputs; decision
    17's lock-graph check still asserts one nixpkgs). Recount: `detectCmd`
    entries in `tui-agent-config.ts` at the tag; `nix eval` of each
    attribute's `version`, `meta.mainProgram` and `meta.license` on the
    pin; `version` in each flake's `package.nix` or `sources.json`.
    Local.

# Non-goals

- Windows, decision 2
- Orca Mobile (the Android and iOS releases in the same repository)
- building `cloud/` or `native/`, or running an Orca relay
- release candidates, decision 7
- patching Orca's behaviour beyond what nix needs: paths, libraries,
  sandbox, and the updater (decision 6)
- a Homebrew tap: upstream has one

# Prior art and rejected designs

- Use `numtide/llm-agents.nix` as an input: it follows its own nixpkgs,
  has no `x86_64-darwin`, and ships `orca`, which shadows the screen
  reader. Its packaging notes are the best map of what Orca needs and are
  read first.
- Upstream's AppImage on Linux (`elsirion`, NUR): its asset names carry no
  version, so a pin cannot say what it pins without the hash. The `.deb` is
  versioned and is what numtide patches.
- The `.dmg` on darwin: mounting it needs `hdiutil`, which the nix sandbox
  does not have; the `-mac.zip` holds the same signed `Orca.app`.
- Building darwin from source: an unsigned app, with the costs of
  nixpkgs Electron on darwin below. Decision 38 builds Linux only.
- nono (`always-further/nono`, Rust, Seatbelt and Landlock, `nono`
  0.61.1 in the pin) and Anthropic's `sandbox-runtime` (`srt`, npm,
  0.0.52 in the pin) for darwin service hardening: both drive the same
  Seatbelt underneath and add domain-level network filtering, but each
  is a dependency beyond macOS for a profile this repository can hold
  itself (decision 36). Revisit if domain filtering becomes a need.
- `Jarred-Sumner/poof` for sandboxing: Linux only (overlayfs and
  namespaces), isolates one command run rather than a service, no
  licence, and marked experimental.
- nixpkgs Electron on darwin (owner agreed, 2026-10-20): the pin's
  `electron_43` 43.7.11 does build on both darwin systems, but there it is
  Electron's own prebuilt zip, so the only gain is a patch version.
  Putting `app.asar` into it breaks Stably's signature and notarization;
  an ad-hoc signature changes on every release (about every 1.4 days),
  which resets the TCC grants Orca's computer-use surface needs
  (Accessibility, Screen Recording), cuts off keychain items stored by
  `safeStorage` under upstream's signature, and turns decision 16's
  `codesign --verify` into a weaker test. It also means rebuilding
  upstream's helper apps, `Info.plist` and signed native modules. Darwin
  ships upstream's `Orca.app` untouched; decision 21 is Linux only.
- Windows through nix: decision 2.

# Open questions

Ask before guessing. A question marked blocking stops the node it names.

1. Source or binaries. Closed by decision 38.
2. Release asset format. Closed by decision 22.
3. `x86_64-darwin` in CI. Closed by decision 39.
4. Cache and release retention. Closed by decision 40; its 25 GB a month
   estimate (4 systems, about 300 MB each, a release about every 1.4
   days) is the baseline decision 40 compares against.
5. Modules. Closed by decision 42.
6. Electron from nixpkgs on Linux. Closed by decision 21.
7. Pinned agent CLIs. Closed by decision 43.
8. Service hardening on darwin. Closed by decision 36.

# Process

The paradigm lifecycle for a nix and shell member: dev shell, then ask me
to reload; guardrails first, one check per commit, then ask me to reload;
TDD, with RED commits red on purpose and tests on push; mirror bats tests
for every script; federated SPEC-DAG built in sherd waves.

Build order:
1. `x86_64-linux` from source and its checks, built on
   `nix-builder.local` (decision 34) and tried by an unprivileged user
   (decision 38); `orca-ide-bin` beside it.
2. `aarch64-linux`, then `aarch64-darwin` and `x86_64-darwin`; darwin may
   come after the first release (decision 38).
3. The bump script and `upstream.yml`.
4. `build.yml`: build and check all four systems; cache and verify Linux
   (decision 41).
5. The release job and the first `-nix.1` release.
6. The README: platform table, pin graph, cachix trust trap, how to attach
   the overlay to a NixOS, nix-darwin and home-manager closure.
7. The modules, one node each, stacked as decision 42 orders them.

Outward-facing steps need my explicit approval: creating the GitHub
repository, the first push, the cachix token, and the first release; after
that the daily loop runs on its own (decision 10). Before the first push,
check every repository named in a committed file with `gh repo view`, and
name no private repository.
