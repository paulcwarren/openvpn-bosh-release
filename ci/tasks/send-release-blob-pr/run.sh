#!/bin/sh

set -eu

echo "pushing branch"

jq -n \
  '
    {
      "source": {
        "uri": ("git@github.com:" + env.owner + "/" + env.repository + ".git"),
        "branch": env.branch,
        "private_key": env.private_key
      },
      "params": {
        "repository": "repo"
      }
    }
  ' \
  | /opt/resource/out "$PWD" \
  > /tmp/git

jq -r '.version.ref' < /tmp/git

echo

echo "creating pull request"

jq -n \
  --arg blob "$blob" \
  --arg version "$( cat repo/blobs/$blob/VERSION )" \
  '
    {
      "title": ("Bump " + $blob + " to " + $version),
      "body": ([
        "Looks like it already passes tests. When merging, remember to...",
        "",
        " - [ ] review the changelog for unexpected feature changes",
        " - [ ] bump the major or minor version for the pipeline, if necessary",
        " - [ ] merge",
        " - [ ] delete the branch"
      ]|join("\n")),
      "head": env.branch,
      "base": env.base_branch
    }
  ' \
  | curl \
    -f \
    -H "Authorization: token $access_token" \
    -X POST \
    -d @- \
    "https://api.github.com/repos/$owner/$repository/pulls" \
    > /tmp/pr

jq -r '.html_url' < /tmp/pr
