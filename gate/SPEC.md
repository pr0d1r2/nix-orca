# SPEC

## §G GOAL

repo gate scripts hk runs: name guard, lock-graph guard, commit-message gate; bats in `tests/unit/gate/`.

## §N NAV

rel|path|lens
up|.|-
self|gate|gate scripts: name guard, lock-graph guard; their bats
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats
sib|tests|VM & integration tests, stub model server
sib|dev|dev shell flake, hook install on entry
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|release|CI & release pipeline: workflows from `.actlith`, bump PR flow, release job, tokens, permissions

## §C CONSTRAINTS

- hk steps from `.pklith` via pklith (`paradigm/V23`); 1 check per commit, planted violation each.
- name guard: denylist local `.private/denylist`, allowlist in CI (`paradigm/V37`).
- lock-graph guard runs on root & `dev` locks.

## §I INTERFACES

- cmd: `gate/lock-graph.sh <flake.lock>` → exit 1 on 2nd nixpkgs | unfollowed input.
- cmd: `gate/name-guard.sh` → exit 1 on denylisted name.

## §V INVARIANTS

V1: lock-graph guard fails on fixture w/ 2 nixpkgs nodes & passes on single (`.:V1`).
V2: name guard fails on planted private name fixture (`.:V10`).

## §T TASKS

id|status|task|cites
T1|x|`lock-graph.sh` + fixtures|V1
T2|x|`name-guard.sh` + fixtures|V2

## §B BUGS

id|date|cause|fix
