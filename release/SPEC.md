# SPEC

## §G GOAL

CI & release pipeline: workflows rendered from `.actlith`, daily build, bump PR flow, release job, tokens & workflow permissions.

## §N NAV

rel|path|lens
up|.|-
self|release|CI & release pipeline: workflows from `.actlith`, bump PR flow, release job, tokens, permissions
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats
sib|tests|VM & integration tests, stub model server
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: name guard, lock-graph guard; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER

## §C CONSTRAINTS

- red source build on a bump (Electron major ahead of pin, lockfile pin pnpm cannot read, new build-time download): bump PR stays open (D10), issue opened, ⊥ release; `orca-ide-bin` still built & checked, so upstream breakage & ours read apart; release resumes when fixed | pin catches up. consumers keep previous release (round 7).
- token `CACHIX_AUTH_TOKEN` repo secret; PR jobs from forks build w/o it (D18, D20).
- bump PRs opened by a GitHub App installation token (`actions/create-github-app-token`), ⊥ `GITHUB_TOKEN`: PRs & pushes made w/ `GITHUB_TOKEN` trigger no workflow, so `build.yml` would never run on them. App owned by owner, permissions `contents: write`, `pull-requests: write` on this repo only; secrets `BUMP_APP_ID`, `BUMP_APP_PRIVATE_KEY` (round 8).
- release job idempotent: runs on merge to `main` | owner dispatch; tag absent → verify ∀ Linux path in cache → attest → tag & publish; tag present → exit 0, ⊥ second release. re-run safe; a merge that keeps the upstream version finds its tag & exits, so only a bump | owner dispatch (round 7) releases (round 8).
- workflow permissions least privilege: default `contents: read`; release job adds `contents: write`, `id-token: write`, `attestations: write`; jobs that open issues (red build, moved tag, critical finding: rounds 7, 9) add `issues: write` only; ∀ action pinned by full commit SHA; ⊥ `pull_request_target`; secrets only in jobs on own branches & `main` (round 8).
- CI = GitHub Actions rendered by actlith from `.actlith`, same `hk.pkl` (`paradigm/V23`, `paradigm/V28`). hk from `nix-hk`.

## §I INTERFACES

- CI: `.github/workflows/build.yml`, `upstream.yml` from `.actlith`.
- env: `CACHIX_AUTH_TOKEN`, `BUMP_APP_ID`, `BUMP_APP_PRIVATE_KEY` (CI secrets).

## §V INVARIANTS

V1: ⊥ workflow run w/ write token on a fork PR; ⊥ `pull_request_target`.
V2: release job twice on same commit → 1 release.

## §T TASKS

id|status|task|cites
T1|.|CI via actlith: `build.yml` (build & check ∀ 4, cache & verify Linux), `upstream.yml` (daily), release job w/ owner `workflow_dispatch` for `-nix.<n+1>` (round 7), required checks; `CACHIX_AUTH_TOKEN` w/ approval|V1,V2

## §B BUGS

id|date|cause|fix
