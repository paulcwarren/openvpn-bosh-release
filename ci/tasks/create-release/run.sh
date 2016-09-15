#!/bin/sh

set -eu

task_dir=$PWD
version=$( cat version/number )

cd repo


#
# create dev release
#

bosh create-release \
  --version="$version" \
  --force \
  --tarball

cp releases/*/*.tgz $task_dir/release/
