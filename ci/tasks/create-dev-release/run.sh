#!/bin/bash

set -eu

release_name=$( bosh interpolate --path /final_name repo/config/final.yml )
s3_bucket=$( bosh interpolate --path /blobstore/options/bucket_name repo/config/final.yml )

s3_prefix="${s3_prefix:-}"

if [ -f version/number ]; then
  version=$( sed -E 's/\-.+//' version/number )-dev.$( date -u +%Y%m%dT%H%M%SZ )
else
  version=$( cd repo ; bosh create-release --force --timestamp-version --tty | grep '^Version ' | awk '{ print $2 }' ; rm -fr dev_releases )
fi

versiondate=$( date -u +%Y-%m-%dT%H:%M:%SZ )

cd repo


#
# create the dev release tarball
#

if [[ "${version_suffix:-}" != "" ]]; then
  version="$version$version_suffix"
fi

tarball="../dev-release/$release_name-$version.tgz"

bosh create-release --version="$version" --tarball="$tarball" --force

metalink_path="../dev-release/v$version.meta4"

meta4 create --metalink="$metalink_path"
meta4 set-published --metalink="$metalink_path" "$versiondate"
meta4 import-file --metalink="$metalink_path" --version="$version" "$tarball"

if [ -n "${s3_host:-}" ]; then
  export AWS_ACCESS_KEY_ID="${s3_access_key:-}"
  export AWS_SECRET_ACCESS_KEY="${s3_secret_key:-}"

  sha1=$( meta4 file-hash --metalink="$metalink_path" sha-1 )
  meta4 file-upload --metalink="$metalink_path" "$tarball" "s3://$s3_host/$s3_bucket/${s3_prefix}$sha1"
fi

cat "$metalink_path"
