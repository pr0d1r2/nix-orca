# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately, through GitHub's private
vulnerability reporting on this repository, not in a public issue. Include
what you ran, what happened, and what you expected.

You will get an acknowledgement within a week. A fix, or a reason there
will not be one, follows as soon as the issue is understood.

A vulnerability in Orca itself belongs to [stablyai/orca](https://github.com/stablyai/orca);
one in an agent CLI belongs to that agent's project. Report it there, and
here only if this packaging makes it worse.

## Supported versions

There are no releases or tags. The newest commit on `main` is supported,
with the Linux builds it pushed to the cache.

## What this flake trusts, and what it promises

- **Upstream Orca.** Linux builds from the tagged source; darwin uses
  upstream's signed `Orca.app` unchanged. Every input is pinned by hash in
  `nix/sources.json`. The bump refuses an upstream release whose manifest and
  GitHub disagree, and stops with an issue when upstream moves a tag or
  replaces an asset it already released. The darwin check pins the app's
  signing team.
- **Agent CLIs.** Six come from third-party flakes whose `package.nix` is
  evaluated in this build; their updates arrive as pull requests the owner
  reads before merging, never automatically. The rest come from nixpkgs.
- **The binary cache.** Only Linux `orca-ide` closures are pushed, from
  this repository's own CI. Darwin, the agents and anything unfree are
  never pushed.
- **CI.** Workflows run with read-only permissions unless a job needs
  more, pin every action to a commit SHA, never use `pull_request_target`,
  and give secrets only to jobs on this repository's own branches. Bump
  and agent-input pull requests come from the owner's update loop, not
  from CI, and go through the same checks.
- **Builds** are rebuilt in CI and checked to be bit for bit identical.
  There is no GitHub release and no attestation: the cache's signature,
  under the key in the flake's `nixConfig`, says a path came from here.

In scope: anything that would let an upstream change, a third-party input
or a pull request reach the cache or a user's machine
unreviewed, and any deviation from the promises above.
