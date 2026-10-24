# SPEC

## §G GOAL

CI pipeline: workflows rendered from `.actlith`, bump PR flow, cache checks on `main`, tokens & workflow permissions. ⊥ GitHub release (root T19).

## §N NAV

rel|path|lens
up|.|-
self|release|CI pipeline: workflows from `.actlith`, bump PR flow, cache checks, tokens, permissions
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, cachix pins, budgets, reports; mirrored bats
sib|tests|VM & integration tests, stub model server
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: name guard, lock-graph guard; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- red source build on a bump (Electron major ahead of pin, lockfile pin pnpm cannot read, new build-time download): bump PR stays open (D10), issue opened, new version ⊥ cached; `orca-ide-bin` still built & checked, so upstream breakage & ours read apart; resumes when fixed | pin catches up. consumers keep previous cached build (round 7).
- token `CACHIX_AUTH_TOKEN` repo secret; PR jobs from forks build w/o it (D18, D20).
- bump & agent-input PRs opened by owner's tending loop (`scripts/ci/upstream.sh`, `agents-pr.sh`) w/ its own token, ⊥ CI, ⊥ GitHub App (owner 2026-10-24; round 8 App dropped): PRs made w/ `GITHUB_TOKEN` trigger no workflow.
- `watch` job in `build.yml`, on `main` after ∀ 4 systems green: `verify-cache.sh` ∀ Linux path (a cachix push failure ⊥ fails its job), then `vulnix-watch.sh`, report-only; builds nothing (D20; root T19).
- workflow permissions least privilege: default `contents: read`; jobs that open issues (red build, moved upstream tag, critical finding, new upstream agent, cache watch: rounds 7, 9, 11) add `issues: write` only; ∀ action pinned by full commit SHA; ⊥ `pull_request_target`; secrets only in jobs on own branches & `main` (round 8).
- CI = GitHub Actions rendered by actlith from `.actlith`, same `hk.pkl` (`paradigm/V23`, `paradigm/V28`). hk from `nix-hk`.

## §I INTERFACES

- CI: `.github/workflows/build.yml` (jobs `eval`, `build`, `watch`), `agents.yml` (new-agent watch), `gate.yml`, listed in `.actlith`.
- env: `CACHIX_AUTH_TOKEN` (CI secret).

## §V INVARIANTS

V1: ⊥ workflow run w/ write token on a fork PR; ⊥ `pull_request_target`.
V2: release job twice on same commit → 1 release. [superseded by `.:V11`]

## §T TASKS

id|status|task|cites
T1|.|CI via actlith: `build.yml` (build & check ∀ 4, cache Linux, `watch` on `main`), required checks; `CACHIX_AUTH_TOKEN` set by owner 2026-10-24|V1

## §B BUGS

id|date|cause|fix
