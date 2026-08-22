#!/usr/bin/env bash
# Rebuild the `website` branch from website/ on main (site files at repo root).
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

if [[ ! -d website ]]; then
  echo "error: website/ directory not found" >&2
  exit 1
fi

if ! git rev-parse --verify main >/dev/null 2>&1; then
  echo "error: main branch not found" >&2
  exit 1
fi

current=$(git branch --show-current)
restore() {
  if [[ -n "${current}" ]]; then
    git checkout "$current" >/dev/null 2>&1 || true
  fi
}
trap restore EXIT

if git show-ref --verify --quiet refs/heads/website; then
  git branch -D website
fi

git subtree split --prefix=website -b website

echo "Branch 'website' updated from website/."
echo "Push with: git push -f origin website"
