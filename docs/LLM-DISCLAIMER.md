# Built by an LLM, in the open

This repository (code, spec, tests and prose) was written by
[Claude Code](https://claude.com/claude-code) running Anthropic's Claude
Opus 5.5, working from an owner's decisions. Every commit carries a
`Co-Authored-By: Claude Opus 5.5` trailer; compare
`git log --format=%B | grep -c Co-Authored-By` with
`git rev-list --count HEAD`. A human owns every decision and is
accountable for what ships.

## Why say it at all

An LLM writes plausible code, and plausible is not correct. A reader who
does not know how a repository was produced cannot calibrate how hard to
look at it.

## What keeps it checkable

- **A written spec.** `SPEC.md` and its nodes record every decision, with
  its date and who made it. Decisions the agent made on its own are marked
  as such and go to the owner for review; the review of 2026-10-24
  approved most and amended the rest (root T18).
- **A gate laid before the product code**, one check per commit, each
  shown refusing a planted violation in its commit body.
- **Tests before scripts.** Every script's bats test landed first and
  failing; the commit history shows each red and green pair.
- **Measurements, not memory.** Sizes, hashes and versions in the spec and
  commit messages were measured on the date given, with the command named.
- **Reproducible output.** Each package is rebuilt and compared bit for
  bit, and releases attest the NAR hashes, so a reader can check a release
  without trusting this text.

## What to watch for

The agent can be confidently wrong. Facts it could not check are marked
unverified where they are used, for example the shape of the cache's pin
API before the first pin existed. If something here does not match what
you see, believe what you see and open an issue.
