#!/bin/bash

set -eux

task_dir=$PWD

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
# upload-blobs
#

bosh upload-blobs


#
# done
#

git commit -m "${git_message:-Update blobs}"
