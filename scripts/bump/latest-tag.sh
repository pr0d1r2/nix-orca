#!/usr/bin/env bash
# Newest stable upstream release tag (scripts T1, V2, D7): the highest
# version among releases that are neither drafts, nor prereleases, nor
# `-rc.N` tags, compared as versions rather than text.
# Usage: latest-tag.sh
# Env: GH names gh (default gh); ORCA_REPO the repository
# (default stablyai/orca).
set -euo pipefail

gh=${GH:-gh}
repo=${ORCA_REPO:-stablyai/orca}

tag=$("$gh" api "repos/$repo/releases?per_page=100" |
  jq -r '.[] | select((.draft | not) and (.prerelease | not)) | .tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' |
  sort -V | tail -n 1)
if [ -z "$tag" ]; then
  echo "latest-tag: $repo has no stable release (scripts V2)" >&2
  exit 1
fi
echo "$tag"
