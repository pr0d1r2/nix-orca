#!/usr/bin/env bash
# An upstream tag's commit and source hash (scripts T1, round 9): the
# commit the tag points at, an annotated tag dereferenced, so a moved tag
# is caught later; and the hash nix computes for the tag's tree.
# Usage: source.sh TAG
# Env: GH, NIX name the tools (default gh, nix); ORCA_REPO the repository
# (default stablyai/orca).
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: source.sh TAG" >&2
  exit 2
fi
tag=$1
gh=${GH:-gh}
nix=${NIX:-nix}
repo=${ORCA_REPO:-stablyai/orca}

if ! ref=$("$gh" api "repos/$repo/git/ref/tags/$tag" 2>/dev/null); then
  echo "source: $repo has no tag $tag" >&2
  exit 1
fi
commit=$(jq -r .object.sha <<<"$ref")
if [ "$(jq -r .object.type <<<"$ref")" = tag ]; then
  commit=$("$gh" api "repos/$repo/git/tags/$commit" | jq -r .object.sha)
fi

hash=$("$nix" flake prefetch --json "github:$repo/$tag" | jq -r .hash)
jq -n --arg commit "$commit" --arg hash "$hash" '{commit: $commit, hash: $hash}'
