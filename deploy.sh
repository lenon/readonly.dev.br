#!/usr/bin/env bash
set -euxo pipefail

outputdir="$HOME/hugo-build"
mkdir -p "$outputdir"

# let's build the site using hugo and current branch
hugo --verbose --destination "$outputdir"

# remove submodule and checkout to the branch used for github pages
git submodule deinit .
git checkout gh-pages

# sync new changes and remove stale files
# keep .git intact because we need to commit files later
# keep CNAME intact because it is used by GitHub pages
rsync --verbose \
      --archive \
      --delete \
      --exclude .git \
      --exclude CNAME \
      "$outputdir/" .

# add changes, commit and push
git add -- .
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
git commit --allow-empty --message "publish changes from commit $GITHUB_SHA"
git push origin gh-pages
