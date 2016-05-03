#!/bin/sh

set -eu

TASK_DIR=$PWD
VERSION=$( cat version/number )

cd repo


#
# create dev release
#

bosh -n create release \
  --version="$VERSION" \
  --with-tarball

cp dev_releases/*/*.tgz $TASK_DIR/create-release/
