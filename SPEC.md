# SPEC

## §G GOAL

`nix-orca` — Orca (`stablyai/orca`, desktop app running fleet of coding agents) as nix flake on fleet nixpkgs pin (`nixpkgs-lock`), ∀ 4 fleet systems, attachable to NixOS, nix-darwin & home-manager closures w/ 1 input. Linux built from source on pin's Electron; darwin = upstream's signed `Orca.app` untouched. built daily; Linux cached on `pr0d1r2.cachix.org`; GitHub release only when upstream releases.

LINEAGE: `SPEC-PROMPT.md` (HISTORICAL after this run). where it & this spec differ, this spec wins. prompt decisions cited `D<n>`. paradigm `e5605a3` + its `docs/NIX.md` & `docs/SHELL.md`; fleet rules cited `paradigm/V<n>`.

## §D DESCRIPTION

nix flake + bash scripts + 1 python stub server (tests). packaging only: fetch, build, wrap, test, cache, release. ⊥ fork of Orca: patches only paths, libraries, sandbox, updater & telemetry switches (D6, D26, D27). consumer surface: `orca-ide`, `orca-ide-agents`, overlay, NixOS / nix-darwin / home-manager modules. fleet member, full paradigm conformance (D9).

## §F FEDERATION

dir|owns|⊥owns|tokens
nix|flake outputs, `nix/sources.json`; packages & modules in children|scripts (`scripts`), VM tests (`tests`), dev shell (`dev`)|-
scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats|flake outputs (`nix`), workflows (`.actlith`)|-
tests|VM & integration tests, stub model server|package builds (`nix`), unit bats (`scripts`, `gate`)|-
dev|dev shell flake, hook install on entry|hk steps (`.pklith`), gate scripts (`gate`)|-
gate|gate scripts: name guard, lock-graph guard; their bats|hk steps (`.pklith`, `hk.pkl`), dev shell (`dev`)|-
docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER|spec rules, package behaviour (`nix`)|-
release|CI & release pipeline: workflows from `.actlith`, bump PR flow, release job, tokens, permissions|package builds (`nix`), bash steps (`scripts`)|-

## §N NAV

rel|path|lens
up|-|-
self|.|-

## §C CONSTRAINTS

- lang = nix + bash; 1 python stub (stdlib only) in `tests`. paradigm `docs/NIX.md`: nixfmt, statix, deadnix, nixpkgs follows nixpkgs-lock, 1 nixpkgs in lock graph, Linux-only work from macOS → remote Linux builder. `docs/SHELL.md`: one script one job, ⊥ shell functions except `info` `warn` `fatal`, extract ⊥ embed, mirrored bats both ways, TDD order on push, env-var seams named in script header.
- 1 nixpkgs = pin = `nixpkgs-lock`'s nixpkgs (`8ce73368`) ∀ package, dev flake, tool (D17). ⊥ nixpkgs-unstable, ⊥ 2nd nixpkgs for newer Electron | agent. follows `nixpkgs-lock` bumps via `nixpkgs-lock-subscribe`.
- root inputs: `nixpkgs-lock` + 6 agent inputs (D8 amended by D43). gate tools in `dev/flake.nix` ⊥ root (D8).
- systems: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`, all built & checked by CI (D1). ⊥ Windows (D2).
- Linux `orca-ide` = source build at upstream tag, run by pin `electron_43` (D21, D38). darwin `orca-ide` = upstream signed `-mac.zip`, `Orca.app` ⊥ modified (D38; nixpkgs Electron on darwin rejected: signature, TCC, keychain). darwin may lag Linux by ≥ 1 release (D38): until `nix/darwin` lands, releases cover Linux only & notes say so; after, ∀ 4 systems green ! before release (round 7).
- stable upstream releases only, ⊥ `-rc.N` (D7).
- program `orca-ide` only, ⊥ `orca` (screen reader clash, D5).
- ⊥ self-update: update arrives as new flake release only (D6); updater & telemetry off switches opt-in, default = upstream behaviour (D26, D27).
- cadence: build daily from `main`; release ⇔ new upstream stable version; `nixpkgs-lock` bump → built, checked, cached, ⊥ released (D19). build once: bump PR from own branch pushes cachix, release job builds nothing (D20). Orca & `nixpkgs-lock` bump PRs merge themselves when ∀ required check green (D10); agent-input PRs wait for the owner (round 9).
- CI & release mechanics (workflows, tokens, permissions, bump flow, release job) in `release` node.
- release = text only, ⊥ binary assets (D22). tag `v<upstream version>-nix.<n>`: `n = 1` for the first release of each upstream version, whatever unblocked it (round 7 decision 4); packaging fix that changes a Linux output for the current upstream version → `-nix.<n+1>`, only by owner-run `workflow_dispatch` of the release job, ⊥ automatic (round 7; D19 stays the only automatic trigger).
- cache `pr0d1r2.cachix.org`: cachix free tier, 5 GB shared w/ fleet (D40). push = Linux `orca-ide` closure only: ⊥ darwin (D41), ⊥ agents, ⊥ unfree (D43), ⊥ `orca-ide-bin` (D38). pins keep 2 Linux revisions / system (D40). ⊥ change cache retention, ⊥ delete path.
- outward acts ! explicit human approval: GitHub repo creation, first push, cachix token, bump GitHub App & its secrets (round 8), first release. after first release, releases go out behind required checks w/o per-release approval: `.pklith` `exempt` row for `paradigm/V32` citing `pr0d1r2/paradigm#24` (D37). ⊥ publish to irreversible registry.
- Linux work from workstation → `nix-builder.local` (x86_64-linux, `kvm`, `nixos-test`, `big-parallel`); `aarch64-linux` CI only (D34). builder configured outside this repo; ⊥ push | release from builder.
- first hands-on test: Linux, unprivileged account (⊥ sudo, ∉ `trusted-users`) (D38).
- ⊥ private repo named in committed text; ∀ repo named checked by `gh repo view` before first push (`paradigm/V37`).
- licence MIT, same as upstream Orca (owner 2026-10-20).
- non-goals: Windows, Orca Mobile, building `cloud/` | `native/`, Orca relay, release candidates, patching behaviour beyond paths/libraries/sandbox/updater/telemetry, Homebrew tap.

## §I INTERFACES

- pkg: `packages.<system>.orca-ide` & `default` — `bin/orca-ide`, ∀ 4 systems (`nix`).
- pkg: `packages.<system>.orca-ide-agents` — `orca-ide` w/ ∀ available agent CLI on `PATH` (`nix/agents`).
- pkg: `packages.<linux>.orca-ide-bin` — `.deb` repackage fallback, built & checked, ⊥ cached, ⊥ released (`nix/bin`).
- override: `orca-ide.override { updater = false; telemetry = false; agents = [ ... ]; }`.
- overlay: `overlays.default` adds `orca-ide` & `orca-ide-agents` only.
- app: `apps.<system>.orca-ide` & `default`.
- legacy: `legacyPackages.<system>.agents.<name>`.
- module: `nixosModules.orca-ide`, `darwinModules.orca-ide`, `homeManagerModules.orca-ide`, each also `default` (`nix/modules`).
- input override: `inputs.nix-orca.inputs.<name>.{url,follows}` for `claude-code-nix`, `codex-cli-nix`, `gemini-cli-nix`, `pi-nix`, `grok-build-nix`, `nix-mistral-vibe`.
- file: `nix/sources.json` — only file an upstream bump changes.
- cache: `https://pr0d1r2.cachix.org`, key `pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=`, in `nixConfig` of root & dev flakes. pins `orca-ide-<system>` (Linux).
- release: tag `v<upstream>-nix.<n>`; notes per system: store path, NAR hash & size, closure size, nixpkgs rev, commit, closure diff, vulnix findings, `--rebuild` result; files: `SHA256SUMS` of upstream inputs, CycloneDX & SPDX SBOM, attestations over NAR hashes.

## §R RESEARCH

id|topic|finding|src
R1|upstream 2026-10-20|latest `v1.4.230` 2026-10-19; 51 stable releases 2026-08-10…2026-10-19 (~1 / 1.4 d); `-rc.N` = prerelease; Electron 43.7.8, Node 24; `packageManager` pnpm 12.8.1 at tag (12.14.0 = latest pnpm, misread earlier); MIT|`gh release list -R stablyai/orca -L 200 --json tagName,publishedAt,isPrerelease`
R2|upstream assets `v1.4.230`|`.deb` amd64 210 MB, arm64 205 MB; `-mac.zip` arm64 305 MB, x64 315 MB; `latest*.yml` w/ `sha512` & `size`; AppImage names unversioned|`gh release view -R stablyai/orca --json assets`
R3|pin `8ce73368` 2026-10-20|`electron` 43.7.11, `pnpm` 11.27.0, `nodejs_24` 24.21.0, `agent-browser` 0.27.0, `sherpa-onnx` 1.12.38, `onnxruntime` 1.24.4, `sbomnix` 1.7.6, `vulnix` 1.12.4, `nvd` 0.2.4, `cachix` 1.11.1, `ollama` 0.40.3; `orca` = GNOME screen reader|`nix eval --raw github:NixOS/nixpkgs/<pin>#<attr>.version`
R4|prior art 2026-10-20|numtide `llm-agents.nix`, `elsirion/orca-nix` (pnpm 11 reads upstream lockfile), `kevinpita`, `Samuka007`, `stslex`, NUR: ∀ repackage binaries; ⊥ `x86_64-darwin`, ⊥ follows `nixpkgs-lock`, ⊥ published outputs|`gh search code stablyai/orca --extension nix`
R9|cachix 2026-10-20|free 5 GB for open source; `cachix pin <cache> <name> <path> --keep-revisions N`; cache prefers ZSTD|cachix.org/pricing, `cachix pin --help`, `app.cachix.org/api/v1/cache/pr0d1r2`
R10|paradigm release rule `paradigm/V32`|per-publish approval ∵ registry artifact immutable; split proposed by reversibility, open|`pr0d1r2/paradigm#24`
R11|space estimate 2026-10-20|pinned ~0.35 GB (2 Linux outputs × 2 systems, ~295 + 205 MB NAR, ~35% zstd assumed); pushed ~3 GB / month; source build expected smaller, measured at first push|D40, D41

## §V INVARIANTS

V1: lock graph: exactly 1 nixpkgs node, ∀ input w/ `nixpkgs` follows it; gate fails else (D17).
V2: ⊥ `bin/orca` in ∀ output (D5).
V3: ∀ GitHub release ⊥ binary asset; notes carry ∀ field of §I release (D13, D22, D29).
V4: automatic release ⇔ new upstream stable version; `nixpkgs-lock` bump alone → ⊥ release (D19); only other release = owner-dispatched `-nix.<n+1>` (round 7).
V5: ∀ cachix push ⊆ Linux `orca-ide` closure; ⊥ darwin, ⊥ `orca-ide-agents`, ⊥ agent, ⊥ unfree, ⊥ `orca-ide-bin` path (D38, D41, D43).
V6: pin rotates only when path ≠ newest pinned revision; ⊥ change cache retention, ⊥ delete cache path (D40).
V7: package ⊥ updates itself; store copy read-only (D6).
V8: tests ⊥ network except fixed-output fetches; ⊥ paid inference, ⊥ API key (D44).
V9: ∀ outward act ∈ approval list (§C) has human approval on record; ⊥ irreversible registry publish (D37).
V10: ⊥ private repo named in committed text (`paradigm/V37`).

## §T TASKS

id|status|task|cites
T1|x|vendor `FORMAT.md` & `FORMAT-EXTENSIONS.md` from paradigm `e5605a3`|-
T2|x|spec run: root sections & ∀ node, 1 per commit, trailer `spec-run`|-
T3|x|freeze `SPEC-PROMPT.md`: line 1 → `HISTORICAL INPUT`, own commit|-
T4|x|dev shell (`dev`); ask human to reload|V1
T5|x|`.gitignore`: `.claude/`, `.direnv/`, `result*`|-
T6|.|guardrails via `.pklith`, 1 check per commit, planted violation each; release-approval waiver row per §C (D37); ask human to reload|V1,V2,V10
T7|x|`.context-limits` from `sherd budget` + 12–20%|-
T8|.|waves via `sherd wave`, build order: `nix/linux` x86_64-linux on `nix-builder.local` + unprivileged-user test → `nix/bin` → aarch64-linux (CI) → `nix/darwin` → `scripts` bump → CI → release → `docs` → `nix/modules` stacked → `nix/agents` → `tests` integration layers|V1,V2,V7
T9|.|CI & release pipeline, see `release` node|V4,V5,V6
T10|.|GitHub repo `pr0d1r2/nix-orca`, first push, first release `-nix.1`, ∀ w/ approval; `gh repo view` ∀ named repo first|V9,V10
T11|.|drop release-approval waiver row (§C) when `pr0d1r2/paradigm#24` decided|V9
T12|.|follow paradigm: when paradigm moves past `e5605a3`, own PR re-vendors `FORMAT.md` & `FORMAT-EXTENSIONS.md`, updates LINEAGE pin, passes spec checks; owner merges (round 11)|-
T13|.|owner reviews gap rounds 7–11 (agent-answered, `git log --format='%(trailers:key=Paradigm-Stage,valueonly)'` lists them); each amendment = new dated decision, ⊥ silent rewrite (`paradigm/V5`) (round 11)|-

## §B BUGS

id|date|cause|fix
