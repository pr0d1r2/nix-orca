# SPEC

## §G GOAL

dev shell flake: gate tools pinned, hooks installed on every entry (D11).

## §N NAV

rel|path|lens
up|.|-
self|dev|dev shell flake, hook install on entry
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats
sib|tests|VM & integration tests, stub model server
sib|gate|gate scripts: name guard, lock-graph guard; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|release|CI & release pipeline: workflows from `.actlith`, bump PR flow, release job, tokens, permissions

## §C CONSTRAINTS

- `dev/flake.nix`, own lock; ⊥ in consumers' locks (D8). inputs follow `nixpkgs-lock`.
- `.envrc`: `use flake ./dev`; also `nix develop ./dev`.
- hk from `nix-hk`; shell hook points `core.hooksPath` at pklith's tracked `.githooks/` every entry once `hk.pkl` exists, idempotent; ⊥ hk → refuse, ⊥ fallback runner (`paradigm/V23`). ⊥ `hk install`: pklith seeds tracked hooks (2026-10-20).
- shell adds tools `pklith gen` names in `nix/pklith.nix`.
- tools: hk, pklith, actlith, microlith, sherd, characterminator, xenolith, bats, shellcheck, shfmt, nixfmt, statix, deadnix, gitleaks, jq, `cachix`, `vulnix` (`nvd`, `sbomnix` dropped w/ release notes, root T19).
- shell names `nix-builder.local`; Linux build w/ builder unreachable → clear message, ⊥ local Linux attempt (D34).

## §I INTERFACES

- shell: `devShells.<system>.default` in `dev/flake.nix`.
- file: `.envrc`.

## §V INVARIANTS

V1: fresh clone + first shell entry → hooks installed, ⊥ manual step.
V2: dev lock graph: 1 nixpkgs (`.:V1`).

## §T TASKS

id|status|task|cites
T1|x|`dev/flake.nix` + `.envrc` + hook install|V1,V2
T2|x|builder reachability message|-

## §B BUGS

id|date|cause|fix
