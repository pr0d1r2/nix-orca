# Contributing to nix-orca

Thanks for looking.

## Getting set up

Enter the dev shell with `direnv allow` (the `.envrc` runs
`use flake ./dev`) or `nix develop ./dev`. Every tool the gate runs comes
from it, pinned by `dev/flake.lock`, and the shell points git at the
tracked hooks in `.githooks/`. Linux builds from a Mac go to a remote
Linux builder; the shell says so when nix has none. The reference one,
`nix-builder.local`, is a
[nixos-nix-builder](https://github.com/pr0d1r2/nixos-nix-builder)
appliance: x86_64-linux with KVM, so it also runs the NixOS VM checks.
`docs/BUILDER.md` says how to build there, run the VM checks and share
the machine.

## The gate

Every commit runs hk's pre-commit hook; every push also runs the bats
suite. Run everything by hand with `hk check --all`. The hooks refuse
when hk is missing. Never use `--no-verify`: when the gate refuses, it is
working, and its message says what to do. The checks are listed in
`.pklith`, from which `pklith gen` writes `hk.pklith.pkl`.

## Commits

- One change per commit.
- Subject `type(scope): claim`, at most 72 characters; the body says why
  and what was checked.
- Shell lives in `scripts/` and `gate/`, not inside `.nix` files or
  workflows (`xnl check` gates it; `xenolith.toml` names the one-line
  forms that stay inline), and every script has its bats test in
  `tests/unit/`, mirrored by path. The test lands first, failing, then
  the script.
- A new gate step comes with proof, in its commit body, that it rejects a
  planted violation.

## Design

The design is a federated spec: `SPEC.md` at the root and one `SPEC.md`
per node (`nix/`, `nix/linux/`, `nix/darwin/`, `nix/agents/`, `nix/bin/`,
`nix/modules/`, `scripts/`, `tests/`, `gate/`, `docs/`, `release/`,
`dev/`). Change the spec with the
code it describes. `SPEC-PROMPT.md` is the frozen input of the first spec
run and is never edited.

## Reporting problems

Bugs and ideas go in GitHub issues. Security problems go through
`docs/SECURITY.md`, not a public issue.
