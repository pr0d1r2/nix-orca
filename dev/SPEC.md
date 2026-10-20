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

## §C CONSTRAINTS

- `dev/flake.nix`, own lock; ⊥ in consumers' locks (D8). inputs follow `nixpkgs-lock`.
- `.envrc`: `use flake ./dev`; also `nix develop ./dev`.
- hk from `nix-hk`; shell hook runs `hk install` every entry, idempotent; ⊥ hk → refuse, ⊥ fallback runner (`paradigm/V23`).
- tools: hk, pklith, actlith, microlith, sherd, itok, characterminator, xenolith, rekall, bats, shellcheck, shfmt, nixfmt, statix, deadnix, gitleaks, jq, `cachix`, `nvd`, `vulnix`, `sbomnix`.
- shell names `nix-builder.local`; Linux build w/ builder unreachable → clear message, ⊥ local Linux attempt (D34).

## §I INTERFACES

- shell: `devShells.<system>.default` in `dev/flake.nix`.
- file: `.envrc`.

## §V INVARIANTS

V1: fresh clone + first shell entry → hooks installed, ⊥ manual step.
V2: dev lock graph: 1 nixpkgs (`.:V1`).

## §T TASKS

id|status|task|cites
T1|.|`dev/flake.nix` + `.envrc` + hook install|V1,V2
T2|.|builder reachability message|-

## §B BUGS

id|date|cause|fix
