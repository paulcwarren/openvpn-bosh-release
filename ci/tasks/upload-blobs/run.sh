#!/bin/bash

set -eux

task_dir=$PWD

git config --global user.email "${git_user_email:-ci@localhost}"
git config --global user.name "${git_user_name:-CI Bot}"
export GIT_COMMITTER_NAME="Concourse"
export GIT_COMMITTER_EMAIL="concourse.ci@localhost"

git clone --quiet file://$task_dir/repo updated-repo

cd repo/


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
# upload-blobs
#

bosh upload-blobs


#
# commit
#


cd $task_dir/updated-repo/

cp $task_dir/repo/config/blobs.yml config/blobs.yml

git add config/blobs.yml

git commit -m "${git_message:-Update blobs}"
