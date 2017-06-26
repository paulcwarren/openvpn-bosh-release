#!/bin/bash

set -eu

fail () { echo "FAILURE: $1" >&2 ; exit 1 ; }

cd repo

start-bosh -o $PWD/ci/tasks/integration-test/bosh-ops.yml

source /tmp/local-bosh/director/env

bosh upload-stemcell \
  --sha1=1396d7877204e630b9e77ae680f492d26607461d \
  https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3421.9-warden-boshlite-ubuntu-trusty-go_agent.tgz

export BOSH_DEPLOYMENT=integration-test

bosh -n deploy \
  --vars-store=/tmp/deployment-vars.yml \
  -v repo_dir="$PWD" \
  ci/tasks/integration-test/deployment.yml

bosh ssh role1/0 '
  set -e
  sudo ping -c 5 192.168.206.1 | sudo tee -a /var/vcap/sys/log/openvpn-client/stdout.log
  sleep 5
  sudo /var/vcap/bosh/bin/monit stop openvpn-client
'

mkdir -p role1-logs

bosh scp role1/0:/var/vcap/sys/log/openvpn-client/stdout.log role1-logs/client-stdout.log
bosh scp role1/0:/var/vcap/sys/log/openvpn/stdout.log role1-logs/stdout.log

if ! grep -q "Initialization Sequence Completed" role1-logs/client-stdout.log* ; then
  fail "Client failed to connect to server"
elif ! grep -q "/sbin/ifconfig tun1 192.168.206.2 netmask 255.255.255.0" role1-logs/client-stdout.log* ; then
  fail "Client failed to establish tunnel correctly"
elif ! grep -q "Initialization Sequence Completed" role1-logs/client-stdout.log* ; then
  fail "Client did not complete initialization sequence"
elif ! grep -q "64 bytes from 192.168.206.1" role1-logs/client-stdout.log* ; then
  fail "Client was unable to ping the remote gateway"
elif ! grep -q "process exiting" role1-logs/client-stdout.log* ; then
  fail "Client did not exit cleanly"
fi

bosh ssh role2/0 '
  set -e
  sudo ping -c 5 192.168.202.1 | sudo tee -a /var/vcap/sys/log/openvpn-client/stdout.log
  sleep 5
  sudo /var/vcap/bosh/bin/monit stop openvpn-client
'

mkdir -p role2-logs

bosh scp role2/0:/var/vcap/sys/log/openvpn-client/stdout.log role2-logs/client-stdout.log
bosh scp role2/0:/var/vcap/sys/log/openvpn/stdout.log role2-logs/stdout.log

if ! grep -q "Initialization Sequence Completed" role2-logs/client-stdout.log* ; then
  fail "Client failed to connect to server"
elif ! grep -q "/sbin/ifconfig tun1 192.168.202.2 netmask 255.255.255.0" role2-logs/client-stdout.log* ; then
  fail "Client failed to establish tunnel correctly"
elif ! grep -q "Initialization Sequence Completed" role2-logs/client-stdout.log* ; then
  fail "Client did not complete initialization sequence"
elif ! grep -q "64 bytes from 192.168.202.1" role2-logs/client-stdout.log* ; then
  fail "Client was unable to ping the remote gateway"
elif ! grep -q "process exiting" role2-logs/client-stdout.log* ; then
  fail "Client did not exit cleanly"
fi

bosh -n delete-deployment

#
# stop-bosh
#

bosh -n clean-up --all

bosh delete-env "/tmp/local-bosh/director/bosh-director.yml" \
  --vars-store="/tmp/local-bosh/director/creds.yml" \
  --state="/tmp/local-bosh/director/state.json"
