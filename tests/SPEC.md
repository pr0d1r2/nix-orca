# SPEC

## §G GOAL

VM & integration tests: Linux launch, hardening, agent integration w/o paid inference (D16, D35, D44); stub model server.

## §N NAV

rel|path|lens
up|.|-
self|tests|VM & integration tests, stub model server
sib|nix|flake outputs, `nix/sources.json`; packages & modules in children
sib|scripts|bash for bump, release notes, cachix pins, budgets, reports; mirrored bats
sib|dev|dev shell flake, hook install on entry
sib|gate|gate scripts: name guard, lock-graph guard; their bats
sib|docs|human pages: README, SECURITY, CONTRIBUTING, LLM-DISCLAIMER
sib|release|CI & release pipeline: workflows from `.actlith`, bump PR flow, release job, tokens, permissions

## §C CONSTRAINTS

- `runNixOSTest`; reference runner `nix-builder.local` (kvm, nixos-test) (D34, D35). CI: required VM checks (launch, layers 1 & 2) on `ubuntu-24.04` x64 w/ `/dev/kvm` opened by udev rule; job asserts `/dev/kvm` first & fails loudly, ⊥ silent skip | TCG fallback. aarch64-linux VM checks ⊥ required until KVM proven on `ubuntu-24.04-arm` (round 8).
- launch: `orca-ide` under Xvfb; `orca-ide serve` headless answers; speech worker loads (D16, D25).
- integration layers (D44), each a VM w/ `orca-ide-agents` & `serve`:
- 1 detection: Orca detects ∀ agent on `PATH`, each `--version` → required.
- 2 stub: `tests/stub` python stdlib server, OpenAI chat completions & responses + Anthropic messages, streaming; replays script: 1 tool call writing a file, then final message. ∀ agent w/ settable endpoint started by Orca via `serve` in worktree → required.
- 3 local model: pin `ollama` 0.40.3, small open-weight model as fixed-output derivation; nightly, `nix-builder.local` only, ⊥ required.
- agents w/o settable endpoint (`cursor-agent`, `copilot`, `amp`, `kiro-cli`, `acli`, …) stop at layer 1.
- ⊥ hosted free tier: ∀ known need account & key (D44).
- unit bats of scripts live under `tests/unit/` mirroring `scripts/` & `gate/`, owned by those nodes.

## §I INTERFACES

- check: `checks.x86_64-linux.{launch,agents-detect,agents-stub}`; `ollama` layer as `legacyPackages.x86_64-linux.nightly.agents-ollama`.
- cmd: `tests/stub/server.py --script <file> --port <n>`.

## §V INVARIANTS

V1: stub run deterministic: same script → same agent-visible bytes.
V2: ⊥ test needs network beyond fixed-output fetches, ⊥ key (`.:V8`).
V3: layer 2: file written by agent's tool call exists & Orca reports agent done.
V4: launch test passes on `orca-ide` & `orca-ide-bin`.

## §T TASKS

id|status|task|cites
T1|.|launch VM test|V4
T2|.|detection layer|V2
T3|.|stub server + recorded scripts per protocol|V1
T4|.|stub layer, endpoint matrix as finding|V3
T5|.|ollama nightly layer, model pick|V2

## §B BUGS

id|date|cause|fix
