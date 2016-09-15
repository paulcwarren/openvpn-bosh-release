#!/bin/sh

set -eu

task_dir=$PWD

git config --global user.email "${git_user_email:-ci@localhost}"
git config --global user.name "${git_user_name:-CI Bot}"
export GIT_COMMITTER_NAME="Concourse"
export GIT_COMMITTER_EMAIL="concourse.ci@localhost"

git clone file://$task_dir/repo updated-repo
cp -r repo/blobs updated-repo/blobs
cp repo/config/blobs.yml updated-repo/config/blobs.yml

cd updated-repo

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
# upload
#

bosh upload-blobs

#
# commit updated blobs
#

git add -A config/blobs.yml
git commit -m "Bump $blob to $( cat blobs/$blob/VERSION )"
