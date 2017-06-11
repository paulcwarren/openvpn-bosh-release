#!/bin/bash

set -eu

task_dir=$PWD

git clone --quiet file://$task_dir/repo updated-repo

cd updated-repo/


#
# replace existing blobs
#

for file in $( bosh blobs --column=path | grep "^$blob/" | sed "s#$blob/##g" ); do
  if [[ ! -e "../blob/$file" ]]; then
    bosh remove-blob "$blob/$file"

    continue
  fi

  new_digest=$( shasum "../blob/$file" | awk '{ print $1 }' )
  existing_digest=$( bosh blobs --column=path --column=digest | grep "^$blob/$file\s" | awk '{ print $2 }' )

  if [[ "$new_digest" == "$existing_digest" ]]; then
    echo "$file unchanged"

    continue
  fi

  bosh remove-blob "$blob/$file"

  bosh add-blob "../blob/$file" "$blob/$file"
done


#
# add new blobs
#

for file in $( cd ../blob ; find . -type f | grep -v '^./.resource' | cut -c3- ); do
  if bosh blobs --column=path | grep -q "^$blob/$file\s" ; then
    continue
  fi

  bosh add-blob "../blob/$file" "$blob/$file"
done
