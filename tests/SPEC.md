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

- `runNixOSTest`; driver Python = boot + calls; checks in `scripts/check/vm-orca.sh` (bats-tested); reference runner `nix-builder.local` (kvm, nixos-test) (D34, D35). CI: required VM checks (launch, layers 1 & 2) on `ubuntu-24.04` x64 w/ `/dev/kvm` opened by udev rule; job asserts `/dev/kvm` first & fails loudly, ⊥ silent skip | TCG fallback. aarch64-linux VM checks ⊥ required until KVM proven on `ubuntu-24.04-arm` (round 8).
- launch: `orca-ide` under Xvfb; `orca-ide serve` headless answers; speech worker loads (D16, D25).
- non-NixOS launch: `nix run` of `orca-ide` on plain `ubuntu-24.04` runner under `xvfb-run`, window up w/ software GL, as unprivileged runner user (round 10; D38 hands-on test, automated). runner restricts unprivileged userns via AppArmor ∴ job first loads the package's `share/apparmor/orca-ide` (D32) w/ `apparmor_parser`, then launches w/o sudo & ⊥ `--no-sandbox`: proves the shipped profile. required check.
- integration layers (D44), each a VM w/ `orca-ide-agents` & `serve`:
- 1 detection: Orca detects ∀ agent on `PATH`, each `--version` → required.
- 2 stub: `tests/stub` python stdlib server, OpenAI chat completions & responses + Anthropic messages, streaming; replays script: 1 tool call writing a file, then final message. ∀ agent w/ settable endpoint started by Orca via `serve` in worktree → required.
- agents w/o settable endpoint (R2) stop at layer 1.
- ⊥ hosted free tier in tests (D44); ollama layer dropped (owner).
- dogfood demo (owner 2026-10-23; ⊥ test ∴ `.:V8` holds; D44 amended for demos): after root T10 (repo goes to 3rd party). VM w/ network: Orca + OpenCode on Big Pickle does 1 sherd task here via hooks, recorded; commits → branch for owner; clone ⊥ `.private/`.
- unit bats of scripts live under `tests/unit/` mirroring `scripts/` & `gate/`, owned by those nodes.

## §I INTERFACES

- check: `checks.x86_64-linux.{launch,agents-detect,agents-stub}`; `checks.<system>.agents-stub-cli` (agents vs stub, ⊥ Orca).
- cmd: `python3 -m tests.stub.server --script <file> --port <n> [--workdir <dir>]`; `python3 -m tests.stub.run <id>... | --all`.

## §R RESEARCH

id|topic|finding|src
R1|stub layer probe, aarch64-darwin 2026-10-20|`claude` 2.1.304: `ANTHROPIC_BASE_URL` + any `ANTHROPIC_API_KEY`, `-p ... --permission-mode acceptEdits --allowedTools Write` → `Write` tool, file written (`tests/stub/scripts/claude.json`). `codex` 0.163.0 ignores `OPENAI_BASE_URL` (hit `api.openai.com`, 401 w/ fake key); works via `-c model_provider=stub` + `model_providers.stub={base_url,env_key,wire_api="responses"}`, `exec -s workspace-write` → `exec_command` tool (`tests/stub/scripts/codex.json`)|run agent vs `tests/stub/server.py`, empty `HOME`
R2|stub layer matrix, aarch64-darwin 2026-10-20|11 agents pass `tests/stub/run.py`, recipes & protocols in `tests/stub/runs.json`. `opencode` reads `PWD`; python agents break on a foreign `PYTHONPATH`; `codex` fails in darwin nix build (MDM prefs). `amp`, `cursor`, `copilot`, `kiro`, `rovo`, `acli`: layer 1 only|`python3 -m tests.stub.run --all`, `checks.aarch64-darwin.agents-stub-cli`
R3|layer 2 in Orca, x86_64-linux VM 2026-10-23|`opencode` via `agent launch --focus` writes the file in 77 s, ~65 s blank TUI after its 1st-run DB migration; its disable flags ⊥ help. seeding `~/.config/orca/orca-data.json` skips 1st-run surfaces; seeded file = pre-telemetry install ∴ opt-out set|`checks.x86_64-linux.agents-stub`

## §V INVARIANTS

V1: stub run deterministic: same script → same agent-visible bytes.
V2: ⊥ test needs network beyond fixed-output fetches, ⊥ key (`.:V8`).
V3: layer 2: file written by agent's tool call exists & Orca reports agent done.
V4: launch test passes on `orca-ide` & `orca-ide-bin`.

## §T TASKS

id|status|task|cites
T1|x|launch VM test; speech worker load = `checks.<linux>.sherpa-load`|V4
T2|.|detection layer|V2
T3|x|stub server + recorded scripts per protocol|V1
T4|.|stub layer, endpoint matrix; `opencode` done (`agents-stub`; demo: dev `agents-gate`)|V3
T5|.|dogfood demo; 1st task: `demo-assets.sh` unstages on gate refusal|-

## §B BUGS

id|date|cause|fix
