#!/bin/sh

set -ex

cp -r repo/ci/images/release-blob/* buildroot/
cp -r repo/src/blobs/$blob buildroot/blob
