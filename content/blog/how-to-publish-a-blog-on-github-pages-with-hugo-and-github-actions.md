---
title: "How to publish a blog on GitHub Pages with Hugo and GitHub Actions"
date: 2020-10-25T21:00:00Z
tags: [hugo,blogging,github]
---

I decided to start a new blog and, after looking at many of the available
options for blogging, I chose a static site generator. I had used Jekyll in the
past, but this time I wanted to try something new, so I gave [Hugo][hugo] a try.
I also wanted to publish this blog to GitHub Pages whenever I push new content
to the GitHub repo. So in this blog post I describe how I'm using it along with
GitHub actions to automatically deploy this blog to GitHub Pages.

The first step is to declare a new workflow file for GitHub Actions. For this, I
added a new file in `.github/workflows/main.yml` with the following content:

```yaml
name: Publish
on: push
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          submodules: true
          fetch-depth: 0

      - name: Build and publish
        run: ./publish.sh
```

This workflow is configured to run on every push to the repo (`on: push`). It
uses `actions/checkout` configured to also fetch submodules (`submodules: true`)
because Hugo themes are usually added as git submodules. The `fetch-depth`
option is configured with `0` to make it get all history for all branches and to
make possible to commit on the `gh-pages` branch.

Now the next step is to create the shell script referenced on the workflow file.
This script will build the static site, commit any changes and push them to the
repo. Here's how I started the `publish.sh` file:

```bash
#!/usr/bin/env bash
set -euxo pipefail
```

The first line makes the shell search for `bash` in user's `PATH`. It is more
flexible than using a hardcoded path. The second line makes bash a bit safer:

* `set -e` stops the script if a command fails (when the exit status is greater
  than 0).
* `set -u` tells Bash to treat unset variables as an error and exit immediately.
* `set -o pipefail` if any command in a pipeline fails, the entire pipe will
  fail.
* `set -x` is good for debugging and is optional. It makes Bash print all
  executed commands to the terminal.

I use these 2 lines in almost all shell scripts that I write. Now let's see the
actual script.

As the virtual environment for GitHub Actions runner includes Snap, I used it to
install Hugo from the [official package][hugo-package]:

```bash
sudo snap install hugo
```

Next, I added some commands for debugging:

```bash
hugo env
hugo config
```

The first one prints Hugo version and environment info. Second one prints the
site configuration. They are useful for troubleshooting.

Then I used the following commands to build the site into a temporary folder:

```bash
builddir="$RUNNER_TEMP/hugo-build"
mkdir -p "$builddir"
hugo --verbose --destination "$builddir"
```

To keep things simple, I decided to place static files in an orphan git branch.
With this type of branch, I can simply publish files in the root folder and
GitHub Pages will work right away. The only requirement is for the branch to be
named `gh-pages`.

Here's the command to create a new orphan branch or to switch to it when it
already exists:

```bash
if ! git show-ref --verify --quiet refs/remotes/origin/gh-pages ; then
  git switch --recurse-submodules --orphan gh-pages
else
  git switch --recurse-submodules --create gh-pages --track origin/gh-pages
fi
```

As I mentioned, the conditional will check if `gh-pages` already exists and, if
not, will create it as an orphan branch. Later on, the script will push this
branch to the repo. Otherwise, when it is not the first run (`gh-pages` was
already pushed), it will simply switch to it locally.

Now it is necessary to move static files to the repo. I used rsync for this
task:

```bash
rsync --verbose \
      --archive \
      --delete \
      --exclude .git \
      --exclude CNAME \
      "$builddir/" .
```

This command will add new files and remove stale ones. It is important to not
touch `.git` because it contains the actual git repo. `CNAME` should also not be
touched because GitHub Pages uses it to store custom domains.

Now, the last step:

```bash
git config user.name github-actions
git config user.email github-actions@github.com
git add -- .
git commit --allow-empty --message "publish changes from commit $GITHUB_SHA"
git push origin gh-pages
```

I included the `--allow-empty` flag because sometimes a change in source files
does not cause an actual change in the output of static files.

Let's see how the final script looks like:

```bash
#!/usr/bin/env bash
set -euxo pipefail

sudo snap install hugo

hugo env
hugo config

builddir="$RUNNER_TEMP/hugo-build"
mkdir -p "$builddir"
hugo --verbose --destination "$builddir"

if ! git show-ref --verify --quiet refs/remotes/origin/gh-pages ; then
  git switch --recurse-submodules --orphan gh-pages
else
  git switch --recurse-submodules --create gh-pages --track origin/gh-pages
fi

rsync --verbose \
      --archive \
      --delete \
      --exclude .git \
      --exclude CNAME \
      "$builddir/" .

git config user.name github-actions
git config user.email github-actions@github.com
git add -- .
git commit --allow-empty --message "publish changes from commit $GITHUB_SHA"
git push origin gh-pages
```

You can see the up-to-date version of this script [here on
GitHub][publish-sh-repo].

[hugo]:https://gohugo.io/
[hugo-package]:https://snapcraft.io/hugo
[publish-sh-repo]:https://github.com/lenon/readonly.dev.br/blob/main/publish.sh
