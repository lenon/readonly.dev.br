#!/usr/bin/env bash
set -euxo pipefail

# useful for debugging
hugo env
hugo config

sitedir="$HOME/site-build"
mkdir -p "$sitedir"

# assuming we are on main branch
# let's build the static site using Hugo
hugo --verbose --destination "$sitedir"

# gh-pages contains only static files and does not include Hugo source files
git checkout --recurse-submodules gh-pages

# sync new changes and remove stale files
# keep .git intact because we need to commit files later
# keep CNAME intact because it is used by GitHub pages
rsync --verbose \
      --archive \
      --delete \
      --exclude .git \
      --exclude CNAME \
      "$sitedir/" .

# add changes, commit and push
# GitHub will then publish those pages
git add -- .
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
git commit --allow-empty --message "publish changes from commit $GITHUB_SHA"
git push origin gh-pages
