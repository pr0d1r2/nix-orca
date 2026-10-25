# SPEC

## §G GOAL

`nix-orca` — Orca (`stablyai/orca`, desktop app running fleet of coding agents) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`), ∀ 4 fleet systems, attachable to NixOS, nix-darwin & home-manager closures w/ 1 input. Linux built from source on pin's Electron; darwin = upstream's signed `Orca.app` untouched. built on each bump; Linux cached on `pr0d1r2.cachix.org`; ⊥ GitHub release (T19).

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `e5605a3` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.

## §D DESCRIPTION

nix flake + bash scripts + 1 python stub server (tests). packaging only: fetch, build, wrap, test, cache. ⊥ fork of Orca: patches only paths, libraries, sandbox, updater & telemetry switches (D6, D26, D27). consumer surface: `orca-ide`, `orca-ide-agents`, overlay, NixOS / nix-darwin / home-manager modules. fleet member, full paradigm conformance (D9).

## §F FEDERATION

dir|owns|⊥owns|tokens
nix|flake outputs, `nix/sources.json`; packages & modules in children|scripts (`scripts`), VM tests (`tests`), dev shell (`dev`)|-
scripts|bash for bump, cachix pins, budgets, reports; mirrored bats|flake outputs (`nix`), workflows (`.actlith`)|-
tests|VM & integration tests, stub model server|package builds (`nix`), unit bats (`scripts`, `gate`)|-
dev|dev shell flake, hook install on entry|hk steps (`.pklith`), gate scripts (`gate`)|-
gate|gate scripts: name guard, lock-graph guard; their bats|hk steps (`.pklith`, `hk.pkl`), dev shell (`dev`)|-
docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER|spec rules, package behaviour (`nix`)|-
release|CI pipeline: workflows from `.actlith`, bump PR flow, cache checks, tokens, permissions|package builds (`nix`), bash steps (`scripts`)|-

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS

- lang = nix + bash; 1 python stub (stdlib only) in `tests`. paradigm `docs/NIX.md`: nixfmt, statix, deadnix, nixpkgs follows nixpkgs-lock, 1 nixpkgs in lock graph, Linux-only work from macOS → remote Linux builder. `docs/SHELL.md`: one script one job, ⊥ shell functions except `info` `warn` `fatal`, extract ⊥ embed, mirrored bats both ways, TDD order on push, env-var seams named in script header.
- 1 nixpkgs = pin = `nixpkgs-lock`'s nixpkgs (`f3a73bcf` since 2026-10-20; was `8ce73368`) ∀ package, dev flake, tool (D17). ⊥ nixpkgs-unstable, ⊥ 2nd nixpkgs for newer Electron | agent. follows `nixpkgs-lock` bumps via `nixpkgs-lock-subscribe`.
- root inputs: `nixpkgs-lock` + 6 agent inputs (D8 amended by D43). gate tools in `dev/flake.nix` ⊥ root (D8).
- systems: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`, all built & checked by CI (D1); exception: x86_64-darwin agent outputs (`orca-ide-agents`, checks `agents-*`) evaluated only, under Rosetta they compile nodejs from source past the job timeout (owner 2026-10-24). ⊥ Windows (D2).
- Linux `orca-ide` = source build at upstream tag, run by pin `electron_43` (D21, D38). darwin `orca-ide` = upstream signed `-mac.zip`, `Orca.app` ⊥ modified (D38; nixpkgs Electron on darwin rejected: signature, TCC, keychain). darwin may lag Linux by ≥ 1 upstream version (D38).
- stable upstream releases only, ⊥ `-rc.N` (D7).
- program `orca-ide` only, ⊥ `orca` (screen reader clash, D5).
- ⊥ self-update: update arrives as new flake revision only (D6); updater & telemetry off switches opt-in, default = upstream behaviour (D26, D27).
- cadence: owner's tending loop opens bump & agent-input PRs, ⊥ GitHub App (owner 2026-10-24); upstream stable version | `nixpkgs-lock` bump → built, checked, cached (D19). build once: bump PR from own branch pushes cachix, its merge builds nothing new (D20). Orca & `nixpkgs-lock` bump PRs merge themselves when ∀ required check green (D10); agent-input PRs wait for the owner (round 9).
- CI mechanics (workflows, tokens, permissions, bump flow, cache checks) in `release` node.
- cachix only (owner 2026-10-24, amends D22): ⊥ GitHub release, ⊥ tag, ⊥ attestation, ⊥ SBOM; Linux bytes from cachix, darwin from upstream's zip. round 7's `-nix.<n>` tags & owner-dispatched packaging fix dropped: a fix lands on `main` & is pushed like any build.
- cache `pr0d1r2.cachix.org`: cachix free tier, 5 GB shared w/ fleet (D40). push = Linux `orca-ide` closure only: ⊥ darwin (D41), ⊥ agents, ⊥ unfree (D43), ⊥ `orca-ide-bin` (D38). pins keep 2 Linux revisions / system (D40). ⊥ change cache retention, ⊥ delete path.
- outward acts ! explicit human approval: GitHub repo creation, first push (it brings the first cachix push), cachix token. after first push, cachix pushes go out behind required checks w/o per-push approval: `.pklith` `exempt` row for `paradigm/V32` citing `pr0d1r2/paradigm#24` (D37). ⊥ publish to irreversible registry.
- Linux work from workstation → `nix-builder.local` (x86_64-linux, `kvm`, `nixos-test`, `big-parallel`); `aarch64-linux` CI only (D34). builder configured outside this repo; ⊥ push from builder.
- first hands-on test: Linux, unprivileged account (⊥ sudo, ∉ `trusted-users`) (D38).
- ⊥ private repo named in committed text; ∀ repo named checked by `gh repo view` before first push (`paradigm/V37`).
- licence MIT, same as upstream Orca (owner 2026-10-20).
- non-goals: Windows, Orca Mobile, building `cloud/` | `native/`, Orca relay, release candidates, patching behaviour beyond paths/libraries/sandbox/updater/telemetry, Homebrew tap.

## §I INTERFACES

- pkg: `packages.<system>.orca-ide` & `default` — `bin/orca-ide`, ∀ 4 systems (`nix`).
- pkg: `packages.<system>.orca-ide-agents` — `orca-ide` w/ ∀ available agent CLI on `PATH` (`nix/agents`).
- pkg: `packages.<linux>.orca-ide-bin` — `.deb` repackage fallback, built & checked, ⊥ cached (`nix/bin`).
- override: `orca-ide.override { updater = false; telemetry = false; agents = [ ... ]; }`.
- overlay: `overlays.default` adds `orca-ide` & `orca-ide-agents` only.
- app: `apps.<system>.orca-ide` & `default`.
- legacy: `legacyPackages.<system>.agents.<name>`.
- module: `nixosModules.orca-ide`, `darwinModules.orca-ide`, `homeManagerModules.orca-ide`, each also `default` (`nix/modules`).
- input override: `inputs.nix-orca.inputs.<name>.{url,follows}` for `claude-code-nix`, `codex-cli-nix`, `gemini-cli-nix`, `pi-nix`, `grok-build-nix`, `nix-mistral-vibe`.
- file: `nix/sources.json` — only file an upstream bump changes.
- cache: `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`, in `nixConfig` of root & dev flakes. pins `orca-ide-<system>` (Linux).

## §R RESEARCH

id|topic|finding|src
R1|upstream 2026-10-20|latest `v1.4.230` 2026-10-19; 51 stable releases 2026-08-10…2026-10-19 (~1 / 1.4 d); `-rc.N` = prerelease; Electron 43.7.8, Node 24; `packageManager` pnpm 12.8.1 at tag (12.14.0 = latest pnpm, misread earlier); MIT|`gh release list -R stablyai/orca -L 200 --json tagName,publishedAt,isPrerelease`
R2|upstream assets `v1.4.230`|`.deb` amd64 210 MB, arm64 205 MB; `-mac.zip` arm64 305 MB, x64 315 MB; `latest*.yml` w/ `sha512` & `size`; AppImage names unversioned|`gh release view -R stablyai/orca --json assets`
R3|pin `8ce73368` 2026-10-20, same at `f3a73bcf`|`electron` 43.7.11, `pnpm` 11.27.0, `nodejs_24` 24.21.0, `agent-browser` 0.27.0, `sherpa-onnx` 1.12.38, `onnxruntime` 1.24.4, `sbomnix` 1.7.6, `vulnix` 1.12.4, `nvd` 0.2.4, `cachix` 1.11.1, `ollama` 0.40.3; `orca` = GNOME screen reader|`nix eval --raw github:NixOS/nixpkgs/<pin>#<attr>.version`
R4|prior art 2026-10-20|numtide `llm-agents.nix`, `elsirion/orca-nix` (pnpm 11 reads upstream lockfile), `kevinpita`, `Samuka007`, `stslex`, NUR: ∀ repackage binaries; ⊥ `x86_64-darwin`, ⊥ follows `nixpkgs-lock`, ⊥ published outputs|`gh search code stablyai/orca --extension nix`
R9|cachix 2026-10-20|free 5 GB for open source; `cachix pin <cache> <name> <path> --keep-revisions N`; cache prefers ZSTD|cachix.org/pricing, `cachix pin --help`, `app.cachix.org/api/v1/cache/pr0d1r2`
R10|paradigm release rule `paradigm/V32`|per-publish approval ∵ registry artifact immutable; split proposed by reversibility, open|`pr0d1r2/paradigm#24`
R11|space estimate 2026-10-20|pinned ~0.35 GB (2 Linux outputs × 2 systems, ~295 + 205 MB NAR, ~35% zstd assumed); pushed ~3 GB / month; source build expected smaller, measured at first push|D40, D41

## §V INVARIANTS

V1: lock graph: exactly 1 nixpkgs node, ∀ input w/ `nixpkgs` follows it; gate fails else (D17).
V2: ⊥ `bin/orca` in ∀ output (D5).
V3: ∀ GitHub release ⊥ binary asset; notes carry ∀ field of §I release (D13, D22, D29). [superseded by V11]
V4: automatic release ⇔ new upstream stable version; `nixpkgs-lock` bump alone → ⊥ release (D19); only other release = owner-dispatched `-nix.<n+1>` (round 7). [superseded by V11]
V5: ∀ cachix push ⊆ Linux `orca-ide` closure; ⊥ darwin, ⊥ `orca-ide-agents`, ⊥ agent, ⊥ unfree, ⊥ `orca-ide-bin` path (D38, D41, D43).
V6: pin rotates only when path ≠ newest pinned revision; ⊥ change cache retention, ⊥ delete cache path (D40).
V7: package ⊥ updates itself; store copy read-only (D6).
V8: tests ⊥ network except fixed-output fetches; ⊥ paid inference, ⊥ API key (D44).
V9: ∀ outward act ∈ approval list (§C) has human approval on record; ⊥ irreversible registry publish (D37).
V10: ⊥ private repo named in committed text (`paradigm/V37`).
V11: ⊥ GitHub release, ⊥ tag made by this repo's CI; consumer bytes = cachix (Linux) | upstream (darwin) (T19).

## §T TASKS

id|status|task|cites
T8|.|waves via `sherd wave`, build order: `nix/linux` x86_64-linux on `nix-builder.local` + unprivileged-user test → `nix/bin` → aarch64-linux (CI) → `nix/darwin` → `scripts` bump → CI → `docs` → `nix/modules` stacked → `nix/agents` → `tests` integration layers|V1,V2,V7
T9|.|CI pipeline, see `release` node|V5,V6,V11
T10|.|GitHub repo `pr0d1r2/nix-orca` created public & empty 2026-10-24 (owner); first push ! owner approval; `CACHIX_AUTH_TOKEN` set by owner 2026-10-24 (`gh secret set`); `gh repo view` ∀ named repo first|V9,V10
T11|.|drop push-approval waiver row (§C) when `pr0d1r2/paradigm#24` decided|V9
T12|.|follow paradigm: when paradigm moves past `e5605a3`, own PR re-vendors `FORMAT.md` & `FORMAT-EXTENSIONS.md`, updates LINEAGE pin, passes spec checks; owner merges (round 11)|-
T14|.|gate follow-ups from T6: V2 check once `nix/linux` builds; pklith pin past v0.1.0 brings hk 2.7.0 schema, `bats-unit`, `tdd-order` rule, `## exempt` table (push waiver moves there); name guard allowlist half in CI (`paradigm/V37`)|V2,V9,V10
T16|.|register `nix-builder.local` as this Mac's nix builder (daemon `builders` empty); `root@` ssh works since 2026-10-21, agent builds there over ssh meanwhile|-

## §B BUGS

id|date|cause|fix
