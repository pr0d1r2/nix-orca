# Demo

Orca runs the agent; the gate decides what lands.

![Orca: pklith lays a gate, OpenCode commits, the gate refuses, OpenCode fixes it](demo/preview.webp)

[Full video (mp4)](demo/demo.mp4) · [last frame](demo/shot.png)

## What happens

In a NixOS VM, with no network and no API key:

1. Alice's Orca (`orca-ide` with OpenCode, updater off) opens a small
   repository: `hello.sh`, a README, and an `opencode.json` that points
   OpenCode at a local model server.
2. In an Orca terminal, [pklith](https://github.com/pr0d1r2/pklith) lays
   the repository's gate: `pklith seed --init` finds shell and markdown,
   `pklith gen` writes the [hk](https://github.com/jdx/hk) configuration
   and git hooks, `pklith confirm` checks the gate can run, and the gate
   commits itself through its own 16 checks.
3. `orca-ide agent launch` starts OpenCode on the task "make greet.sh
   greet by name, commit it". It writes `greet.sh` with an unquoted
   variable and commits.
4. The pre-commit hook refuses: shellcheck SC2086. OpenCode quotes the
   variable and commits again, and the gate lets it through.

The model is the stub from `tests/stub`: it replays a recorded answer
(write the file, commit, fix, commit) so every run is the same. The gate
and its refusal are real.

Orca's first-run screens (onboarding, tips, tours, star prompt,
telemetry notice) are skipped by seeding its state. Each still stretch
is cut to at most 1.5 s.

## Re-record

The video is the output of the dev flake's
`checks.x86_64-linux.agents-gate`, which needs an x86_64-linux host with
KVM. In the dev shell:

```sh
scripts/demo-assets.sh                                # this host builds it
scripts/demo-assets.sh ssh-ng://root@builder.example  # a remote host does
```

It replaces the files in `docs/demo/` and commits them alone. The check
runs again only when its inputs change (a bump, the stub server, the
scripts), so the same inputs commit nothing.
