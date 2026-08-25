#!/usr/bin/env bash
#
# Resolve every source's tracked branch to a commit SHA and decide which ones
# need building. Writes `matrix` and `any` to $GITHUB_OUTPUT.
#
# Why ls-remote instead of cloning: an OpenWrt tree is hundreds of megabytes,
# and all we need to know here is whether the branch tip moved. One network
# round trip per source answers that.
#
# Env:
#   FORCE=true   build every source regardless of whether upstream moved
#   ONLY=a,b     restrict to these source ids
set -euo pipefail

LOCK="upstream.lock"
FORCE="${FORCE:-false}"
ONLY="${ONLY:-}"

[ -s "$LOCK" ] || echo '{}' > "$LOCK"

new_lock="$(cat "$LOCK")"
include='[]'

for id in $(jq -r '.[].id' sources.json); do
  if [ -n "$ONLY" ] && ! printf '%s' ",${ONLY// /}," | grep -q ",${id},"; then
    echo "$id: skipped (not listed in 'only')"
    continue
  fi

  src="$(jq -c --arg i "$id" '.[] | select(.id == $i)' sources.json)"
  repo="$(printf '%s' "$src" | jq -r .repo)"
  branch="$(printf '%s' "$src" | jq -r .branch)"

  sha="$(git ls-remote "$repo" "refs/heads/$branch" | cut -f1)"
  if [ -z "$sha" ]; then
    echo "::error::cannot resolve $repo branch $branch"
    exit 1
  fi

  old="$(jq -r --arg i "$id" '.[$i] // ""' "$LOCK")"
  if [ "$sha" = "$old" ] && [ "$FORCE" != "true" ]; then
    echo "$id: unchanged (${sha:0:12})"
    continue
  fi

  echo "$id: ${old:0:12}${old:+ -> }${sha:0:12}"
  new_lock="$(printf '%s' "$new_lock" | jq --arg i "$id" --arg s "$sha" '.[$i] = $s')"
  include="$(printf '%s' "$include" | jq -c --argjson s "$src" --arg sha "$sha" '. + [$s + {sha: $sha}]')"
done

# The lock is only *previewed* here. It is committed by the record job, and
# only for sources that actually built — otherwise one broken build would
# advance the pointer and the next scheduled run would skip retrying it.
printf '%s\n' "$new_lock" | jq -S . > upstream.lock.next

count="$(printf '%s' "$include" | jq 'length')"
{
  echo "matrix=$(printf '%s' "$include" | jq -c '{include: .}')"
  echo "any=$([ "$count" -gt 0 ] && echo true || echo false)"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

echo "$count source(s) to build"
