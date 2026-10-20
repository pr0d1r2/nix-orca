# SPEC

## §G GOAL

bash scripts CI & humans run: upstream bump, release notes, cachix pins, closure diff & budget, vulnix & Electron-lag reports, SBOM, agent-input update. each w/ mirrored bats.

## §N NAV

rel|path|lens
up|.|-
self|scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|tests|VM & integration tests, stub model server
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: name guard, lock-graph guard; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|release|CI & release pipeline: workflows from `.actlith`, bump PR flow, release job, tokens, permissions

## §C CONSTRAINTS

- `docs/SHELL.md` rules (`.` §C); env seams in header; external tools stubbed in bats.
- bump: latest stable upstream tag (skip `-rc.N`); new → write `nix/sources.json` only: tag source hash, JS deps hash, `.deb` & piece hashes (`nix hash path`), darwin SRI `sha512` from manifests; refuse on missing manifest entry | size ≠ (D12). diff `sherpa-onnx/c-api/c-api.h` bundled vs pin (`gh api repos/k2-fsa/sherpa-onnx/compare/v<a>...v<b>`) (D25).
- 1 bump PR at a time, branch `bump/orca-ide`, updated in place by the next run; ≥ 2 upstream releases since last bump → jump to latest, intermediates ⊥ released; `upstream.yml` concurrency group `upstream`, ⊥ cancel in progress (round 8).
- upstream immutability: `nix/sources.json` records tag → commit sha; bump re-reads it ∀ run. pinned version whose tag moved | asset hash changed → stop, open issue, ⊥ rewrite hashes for a version already pinned. new version only via new tag (round 9).
- bump PR body lists npm packages added, removed & version-changed between old & new `pnpm-lock.yaml`, plus new `allowBuilds` entries (install scripts) in `pnpm-workspace.yaml`; report-only, ⊥ blocks auto-merge (round 9).
- pin: `cachix pin pr0d1r2 orca-ide-<system> <path> --keep-revisions 2` only when path ≠ newest pinned revision (D40).
- cache watch: release notes carry compressed bytes this release pushed (`cachix push` output); monthly job sums last 30 days & this repo's pinned paths; > 4 GB pushed (D40 expects ~3) | > 0.5 GB pinned (D40 expects ~0.35) → issue, ~10% over a 5 GB tier shared w/ the fleet (D40, D41; round 11).
- release notes: ∀ field of `.` §I release; closure diff via `nvd` vs previous release (D14); vulnix findings & Electron-lag report, both report-only (D15); SBOM via `sbomnix` CycloneDX & SPDX (D29).
- vulnix & Electron-lag stay report-only (D15); a new finding w/ CVSS ≥ 9.0 in a path the package owns (⊥ pin paths, which nixpkgs tracks) opens an issue once per CVE; ⊥ blocks release (round 9).
- ⊥ network in bats; ⊥ real cachix | GitHub call in tests.

## §I INTERFACES

- cmd: `scripts/bump.sh` → edits `nix/sources.json`, exit 0 = bumped, 3 = up to date.
- cmd: `scripts/release-notes.sh <system>...` → markdown stdout.
- cmd: `scripts/cachix-pin.sh <system> <path>`.
- cmd: `scripts/closure-budget.sh <system> <path>` → exit 1 over budget.
- cmd: `scripts/agents-update.sh` → `nix flake update` of agent inputs.
- env: `CACHIX_AUTH_TOKEN`, `GH_TOKEN` (CI).

## §V INVARIANTS

V1: bump writes only `nix/sources.json` (`nix:V3`).
V2: bump ⊥ picks `-rc.N` (D7).
V3: pin script ⊥ pins same path twice in a row; ⊥ calls cachix delete | retention API (`.:V6`).
V4: release notes ⊥ reference binary asset upload (`.:V3`).
V5: ∀ script has mirrored bats & passes w/ stubs only.

## §T TASKS

id|status|task|cites
T1|.|`bump.sh` + manifest refusal + sherpa header diff|V1,V2
T2|.|`cachix-pin.sh`|V3
T3|.|`release-notes.sh` w/ nvd, vulnix, Electron lag, SBOM|V4
T4|.|`closure-budget.sh`|V5
T5|.|`agents-update.sh`|V5

## §B BUGS

id|date|cause|fix
