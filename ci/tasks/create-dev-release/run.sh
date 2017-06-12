#!/bin/bash

set -eu

release_name=$( bosh interpolate --path /final_name repo/config/final.yml )
s3_bucket=$( bosh interpolate --path /blobstore/options/bucket_name repo/config/final.yml )

cd repo


#
# create the dev release tarball
#

version=$( bosh create-release --force --tty | grep '^Version ' | awk '{ print $2 }' ; rm -fr dev_releases )
versiondate=$( date -u +%Y-%m-%dT%H:%M:%SZ )

if [[ "${version_suffix:-}" != "" ]]; then
  version="$version$version_suffix"
fi

tarball="../dev-release/$release_name-$version.tgz"

bosh create-release --version="$version" --tarball="$tarball" --force

metalink_path="../dev-release/$release_name-$version.meta4"

meta4 create --metalink="$metalink_path"
meta4 set-published --metalink="$metalink_path" "$versiondate"
meta4 import-file --metalink="$metalink_path" --version="$version" "$tarball"
meta4 file-set-url --metalink="$metalink_path" "https://$s3_bucket.s3.amazonaws.com/dev_releases/$release_name-$version.tgz"

cat "$metalink_path"
