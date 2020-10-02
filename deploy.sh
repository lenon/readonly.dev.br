#!/usr/bin/env bash
set -euxo pipefail

# can't use /tmp with github actions for some reason
outputdir="$RUNNER_TEMP/build"
mkdir -p "$outputdir"

# let's build the site using hugo and current branch
hugo --verbose --destination "$outputdir"

# remove submodule and checkout to the branch used for github pages
git submodule deinit .
git checkout gh-pages

# sync new changes and remove stale files
# keep .git intact because we need to commit files later
rsync --verbose \
      --archive \
      --delete \
      --exclude .git \
      "$outputdir/" .

# add changes, commit and push
git add -- .
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
git commit --allow-empty --message "deploy commit $GITHUB_SHA"
git push origin gh-pages
