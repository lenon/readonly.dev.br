#!/usr/bin/env bash
set -euxo pipefail

sudo snap install hugo

# useful for debugging
hugo env
hugo config

builddir="$RUNNER_TEMP/hugo-build"
mkdir -p "$builddir"

# assuming we are on main branch
# let's build the static site using Hugo
hugo --verbose --destination "$builddir"

# create a new orphan branch for gh-pages if it does not exist yet
# otherwise just track the remote branch
if ! git show-ref --verify --quiet refs/remotes/origin/gh-pages ; then
  git switch --recurse-submodules --orphan gh-pages
else
  git switch --recurse-submodules --create gh-pages --track origin/gh-pages
fi

# sync new changes and remove stale files
# keep .git intact because we need to commit files later
# keep CNAME intact because it is used by GitHub pages
rsync --verbose \
      --archive \
      --delete \
      --exclude .git \
      --exclude CNAME \
      "$builddir/" .

# add changes, commit and push
# GitHub will then publish those pages
git config user.name github-actions
git config user.email github-actions@github.com
git add -- .
git commit --allow-empty --message "publish changes from commit $GITHUB_SHA"
git push origin gh-pages
