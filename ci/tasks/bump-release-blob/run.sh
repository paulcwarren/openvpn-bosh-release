#!/bin/sh

set -eu

task_dir=$PWD

git clone file://$task_dir/repo updated-repo

cd updated-repo

bosh sync-blobs

changed=false

for existing_blob in $( cd blobs/$blob && find . | cut -c3- | grep -Ev '^$' ); do
  if [ ! -e $task_dir/blob/$existing_blob ] || ! cmp -s $task_dir/blob/$existing_blob $existing_blob; then
    bosh remove-blob "$blob/$existing_blob"
    changed=true
  fi
done

for new_blob in $( cd $task_dir/blob && find . | cut -c3- | grep -Ev '^$' ); do
  if [ ! -e blobs/$blob/$new_blob ]; then
    bosh add-blob "$task_dir/blob/$new_blob" "$blob/$new_blob"
    changed=true
  fi
done

if [ "$changed" = "false" ]; then
  echo "error: no blobs changed" >&2
  exit 1
fi
