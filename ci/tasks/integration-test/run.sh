#!/bin/sh

set -eu

fail () { echo "FAILURE: $1" >&2 ; exit 1 ; }

target=$( cat "$target_file" )

bosh --ca-cert=repo/ci/tasks/integration-test/bosh-lite-ca.crt env "https://$( echo "$target" | tr '.' '-' ).sslip.io:25555" bosh-lite
bosh log-in --user "$username" --password "$password"
bosh deployment integration-test

echo "$ssh_private_key" > id_rsa
chmod 0600 id_rsa

gateway="--gw-host $target --gw-user $ssh_user --gw-private-key $PWD/id_rsa"

bosh ssh $gateway role1/0 '
  sudo ping -c 5 192.168.206.1 | sudo tee -a /var/vcap/sys/log/openvpn/client1-stdout.log
  sleep 5
  sudo /var/vcap/bosh/bin/monit stop openvpn-client1
'

mkdir -p role1-logs

bosh scp $gateway role1/0:/var/vcap/sys/log/openvpn/client1-stdout.log role1-logs
bosh scp $gateway role1/0:/var/vcap/sys/log/openvpn/stdout.log role1-logs

if ! grep -q "TCP connection established with" role1-logs/client1-stdout.log* ; then
  fail "Client failed to connect to server"
elif ! grep -q "/sbin/ifconfig tun1 192.168.206.2 netmask 255.255.255.0" role1-logs/client1-stdout.log* ; then
  fail "Client failed to establish tunnel correctly"
elif ! grep -q "Initialization Sequence Completed" role1-logs/client1-stdout.log* ; then
  fail "Client did not complete initialization sequence"
elif ! grep -q "64 bytes from 192.168.206.1" role1-logs/client1-stdout.log* ; then
  fail "Client was unable to ping the remote gateway"
elif ! grep -q "process exiting" role1-logs/client1-stdout.log* ; then
  fail "Client did not exit cleanly"
fi

bosh ssh $gateway role2/0 '
  sudo ping -c 5 192.168.202.1 | sudo tee -a /var/vcap/sys/log/openvpn/client1-stdout.log
  sleep 5
  sudo /var/vcap/bosh/bin/monit stop openvpn-client1
'

mkdir -p role2-logs

bosh scp $gateway role2/0:/var/vcap/sys/log/openvpn/client1-stdout.log role2-logs
bosh scp $gateway role2/0:/var/vcap/sys/log/openvpn/stdout.log role2-logs

if ! grep -q "TCP connection established with" role2-logs/client1-stdout.log* ; then
  fail "Client failed to connect to server"
elif ! grep -q "/sbin/ifconfig tun1 192.168.202.2 netmask 255.255.255.0" role2-logs/client1-stdout.log* ; then
  fail "Client failed to establish tunnel correctly"
elif ! grep -q "Initialization Sequence Completed" role2-logs/client1-stdout.log* ; then
  fail "Client did not complete initialization sequence"
elif ! grep -q "64 bytes from 192.168.202.1" role2-logs/client1-stdout.log* ; then
  fail "Client was unable to ping the remote gateway"
elif ! grep -q "process exiting" role2-logs/client1-stdout.log* ; then
  fail "Client did not exit cleanly"
fi
