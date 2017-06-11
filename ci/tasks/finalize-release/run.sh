#!/bin/sh

set -eux

task_dir=$PWD

release_name=$( bosh interpolate --path /final_name repo/config/final.yml )
s3_bucket=$( bosh interpolate --path /blobstore/options/bucket_name repo/config/final.yml )
version=$( cat version/number )

git config --global user.email "${git_user_email:-ci@localhost}"
git config --global user.name "${git_user_name:-CI Bot}"
export GIT_COMMITTER_NAME="Concourse"
export GIT_COMMITTER_EMAIL="concourse.ci@localhost"

git clone --quiet file://$task_dir/repo updated-repo

cd updated-repo/


#
# we'll be updating the blobstore
#

cat > config/private.yml <<EOF
---
blobstore:
  provider: s3
  options:
    access_key_id: "$blobstore_s3_access_key_id"
    secret_access_key: "$blobstore_s3_secret_access_key"
EOF


#
# finalize the release
#

bosh finalize-release \
  --version="$version" \
  "$task_dir/dev-release/$release_name"-*.tgz


#
# create the release tarball
#

echo "v$version" > $task_dir/release/name
git rev-parse HEAD > $task_dir/release/commit

if [ -e releases/*/*-$version.md ] ; then
  cp releases/*/*-$version.md $task_dir/release/notes.md
else
  touch $task_dir/release/notes.md
fi

tarball="../release/$release_name-$version.tgz"

bosh create-release --tarball="$tarball" "releases/$release_name/$release_name-$version.yml"

metalink_path="releases/$release_name/$release_name-$version.meta4"

meta4 create --metalink="$metalink_path"
meta4 set-published --metalink="$metalink_path" "$( date -u +%Y-%m-%dT%H:%M:%SZ )"
meta4 import-file --metalink="$metalink_path" --version="$version" "$tarball"
meta4 file-set-url --metalink="$metalink_path" "https://$s3_bucket.s3.amazonaws.com/releases/$release_name/$release_name-$version.tgz"


#
# commit final release
#

git add -A .final_builds releases

git commit -m "Finalize release v$version"
