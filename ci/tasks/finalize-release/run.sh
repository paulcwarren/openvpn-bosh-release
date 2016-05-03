#!/bin/sh

set -eu

task_dir=$PWD
version=$( cat version/number )

git config --global user.email "${git_user_email:-ci@localhost}"
git config --global user.name "${git_user_name:-CI Bot}"

git clone file://$task_dir/candidate-repo updated-candidate-repo
git clone file://$task_dir/master-repo updated-master-repo
git clone file://$task_dir/develop-repo updated-develop-repo

cd updated-candidate-repo/


#
# we'll be updating the blobstore
#

cat > config/private.yml <<EOF
---
blobstore:
  s3:
    access_key_id: "$blobstore_s3_access_key_id"
    secret_access_key: "$blobstore_s3_secret_access_key"
EOF


#
# finalize the release
#

bosh -n finalize release \
  $task_dir/candidate-release/*.tgz \
  --version="$version"


#
# commit final release
#

git add -A .final_builds releases

(
  echo "Release v$version"
  [ ! -e releases/*/*-$version.md ] || ( echo "" ; cat releases/*/*-$version.md )
) \
  | git commit -F-


#
# release artifact
#

echo "v$version" > $task_dir/master-release-artifacts/name
git rev-parse HEAD > $task_dir/master-release-artifacts/commit

if [ -e releases/*/*-$version.md ] ; then
  cp releases/*/*-$version.md $task_dir/master-release-artifacts/notes.md
else
  touch $task_dir/master-release-artifacts/notes.md
fi

bosh -n create release \
  --version="$version" \
  --with-tarball

cp releases/*/*.tgz $task_dir/master-release-artifacts/


#
# merge release to master
#

cd $task_dir/updated-master-repo

git remote add --fetch updated-candidate-repo file://$task_dir/updated-candidate-repo

master_branch=$( git rev-parse --abbrev-ref HEAD )
release_branch=$( basename $( git ls-remote --heads updated-candidate-repo | awk '{ print $2 }' ) )

git merge --no-ff -m "$( echo "Merge branch 'release-$version' into $master_branch" ; echo ; echo '[ci skip]' )" updated-candidate-repo/$release_branch


#
# merge release to develop
#

cd $task_dir/updated-develop-repo

git remote add --fetch updated-candidate-repo file://$task_dir/updated-candidate-repo

develop_branch=$( git rev-parse --abbrev-ref HEAD )
release_branch=$( basename $( git ls-remote --heads updated-candidate-repo | awk '{ print $2 }' ) )

git merge --no-ff -m "$( echo "Merge branch 'release-$version' into $develop_branch" ; echo ; echo '[ci skip]' )" updated-candidate-repo/$release_branch
