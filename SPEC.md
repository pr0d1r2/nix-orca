# SPEC

## §G GOAL

`nix-orca` — Orca (`stablyai/orca`, desktop app running fleet of coding agents) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`), ∀ 4 fleet systems, attachable to NixOS, nix-darwin & home-manager closures w/ 1 input. Linux built from source on pin's Electron; darwin = upstream's signed `Orca.app` untouched. built daily; Linux cached on `pr0d1r2.cachix.org`; GitHub release only when upstream releases.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `e5605a3` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.

## §D DESCRIPTION

nix flake + bash scripts + 1 python stub server (tests). packaging only: fetch, build, wrap, test, cache, release. ⊥ fork of Orca: patches only paths, libraries, sandbox, updater & telemetry switches (D6, D26, D27). consumer surface: `orca-ide`, `orca-ide-agents`, overlay, NixOS / nix-darwin / home-manager modules. fleet member, full paradigm conformance (D9).

## §F FEDERATION

dir|owns|⊥owns|tokens

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS

- lang = nix + bash; 1 python stub (stdlib only) in `tests`. paradigm `docs/NIX.md`: nixfmt, statix, deadnix, nixpkgs follows nixpkgs-lock, 1 nixpkgs in lock graph, Linux-only work from macOS → remote Linux builder. `docs/SHELL.md`: one script one job, ⊥ shell functions except `info` `warn` `fatal`, extract ⊥ embed, mirrored bats both ways, TDD order on push, env-var seams named in script header.
- 1 nixpkgs = pin = `nixpkgs-lock`'s nixpkgs (`8ce73368`) ∀ package, dev flake, tool (D17). ⊥ nixpkgs-unstable, ⊥ 2nd nixpkgs for newer Electron | agent. follows `nixpkgs-lock` bumps via `nixpkgs-lock-subscribe`.
- root inputs: `nixpkgs-lock` + 6 agent inputs (D8 amended by D43). gate tools in `dev/flake.nix` ⊥ root (D8).
- systems: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`, all built & checked by CI (D1). ⊥ Windows (D2).
- Linux `orca-ide` = source build at upstream tag, run by pin `electron_43` (D21, D38). darwin `orca-ide` = upstream signed `-mac.zip`, `Orca.app` ⊥ modified (D38; nixpkgs Electron on darwin rejected: signature, TCC, keychain). darwin may lag Linux by ≥ 1 release (D38).
- stable upstream releases only, ⊥ `-rc.N` (D7).
- program `orca-ide` only, ⊥ `orca` (screen reader clash, D5).
- ⊥ self-update: update arrives as new flake release only (D6); updater & telemetry off switches opt-in, default = upstream behaviour (D26, D27).
- cadence: build daily from `main`; release ⇔ new upstream stable version; `nixpkgs-lock` bump → built, checked, cached, ⊥ released (D19). build once: bump PR from own branch pushes cachix, release job builds nothing (D20). bump PR merges itself when ∀ required check green (D10).
- release = text only, ⊥ binary assets (D22). tag `v<upstream version>-nix.<n>`.
- cache `pr0d1r2.cachix.org`: cachix free tier, 5 GB shared w/ fleet (D40). push = Linux `orca-ide` closure only: ⊥ darwin (D41), ⊥ agents, ⊥ unfree (D43), ⊥ `orca-ide-bin` (D38). pins keep 2 Linux revisions / system (D40). ⊥ change cache retention, ⊥ delete path.
- token `CACHIX_AUTH_TOKEN` repo secret; PR jobs from forks build w/o it (D18, D20).
- outward acts ! explicit human approval: GitHub repo creation, first push, cachix token, first release. after first release, releases go out behind required checks w/o per-release approval: `.pklith` `exempt` row for `paradigm/V32` citing `pr0d1r2/paradigm#24` (D37). ⊥ publish to irreversible registry.
- Linux work from workstation → `nix-builder.local` (x86_64-linux, `kvm`, `nixos-test`, `big-parallel`); `aarch64-linux` CI only (D34). builder configured outside this repo; ⊥ push | release from builder.
- first hands-on test: Linux, unprivileged account (⊥ sudo, ∉ `trusted-users`) (D38).
- CI = GitHub Actions rendered by actlith from `.actlith`, same `hk.pkl` (`paradigm/V23`, `paradigm/V28`). hk from `nix-hk`.
- ⊥ private repo named in committed text; ∀ repo named checked by `gh repo view` before first push (`paradigm/V37`).
- licence MIT ? (upstream Orca MIT; owner to confirm before first push).
- non-goals: Windows, Orca Mobile, building `cloud/` | `native/`, Orca relay, release candidates, patching behaviour beyond paths/libraries/sandbox/updater/telemetry, Homebrew tap.
