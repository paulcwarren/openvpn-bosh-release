A little [BOSH](http://docs.cloudfoundry.org/bosh/) release to help manage an [OpenVPN](http://openvpn.net/) network.


## Getting Started

Create a directory for your deployment...

    $ mkdir openvpn
    $ cd openvpn

Customize an environment file to store some reusable config values, then load it...

    $ cat > .env << EOF
    export EASYRSA_VARS_FILE="vars"
    export EASYRSA_REQ_COUNTRY="US"
    export EASYRSA_REQ_PROVINCE="California"
    export EASYRSA_REQ_CITY="San Francisco"
    export EASYRSA_REQ_ORG="Copyleft Certificate Co"
    export EASYRSA_REQ_OU="My Organizational Unit"
    export EASYRSA_REQ_EMAIL="me@example.net"
    EOF
    $ source .env

OpenVPN uses a [PKI](http://en.wikipedia.org/wiki/Public_key_infrastructure) for authentication. You'll need to create
one from scratch and the [easy-rsa](https://github.com/OpenVPN/easy-rsa/) package simplifies those workflows...

    $ echo '/easyrsa' >> .gitignore
    $ mkdir easyrsa
    $ wget -qO- "https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.0-rc1/EasyRSA-3.0.0-rc1.tgz" \
      | tar -xzC easyrsa --strip-components 1

Initialize your PKI and create the authority...

    $ ( cd easyrsa/ && EASYRSA_PKI=../pki ./easyrsa init-pki )
    $ cd pki
    $ cat ../easyrsa/vars.example \
      | sed -E "s/^#?set_var[[:space:]]+EASYRSA[[:space:]]+.*\$/set_var EASYRSA \"\$PWD\/..\/easyrsa\"/" \
      | sed -E "s/^#?set_var[[:space:]]+EASYRSA_PKI[[:space:]]+.*\$/set_var EASYRSA_PKI \"\$PWD\"/" \
      > vars
    $ ../easyrsa/easyrsa build-ca
      # password will be used whenever you need to sign new certificates
      # common name = openvpn
    $ ../easyrsa/easyrsa gen-crl
    $ ../easyrsa/easyrsa gen-dh
    $ cd ../

Your server will need a server key, so create and sign one...

    $ cd pki
    $ openssl req -new -nodes -days 3650 -newkey rsa:2048 \
      -subj "/C=$EASYRSA_REQ_COUNTRY/ST=$EASYRSA_REQ_PROVINCE/L=$EASYRSA_REQ_CITY/O=$EASYRSA_REQ_ORG/OU=$EASYRSA_REQ_OU/CN=server/emailAddress=$EASYRSA_REQ_EMAIL" \
      -out "reqs/server.req" \
      -keyout "private/server.key"
    $ ../easyrsa/easyrsa sign server "server"
    $ cd ../

You can now create your BOSH manifest and deploy it...

    $ vim deploy_manifest.yml
      # properties.openvpn.ca_crt = ./pki/ca.crt
      # properties.openvpn.server_crt = ./pki/issued/server.crt
      # properties.openvpn.server_key = ./pki/private/server.key
      # properties.openvpn.crl_pem = ./pki/crl.pem
      # properties.openvpn.dh_pem = ./pki/dh.pem
    $ bosh -d deploy_manifest.yml deploy

Create a base OpenVPN client config file. To get started, you'll probably only need to customize the `remote` with the
IP or hostname the server will be deployed to...

    $ cat > openvpn-client.conf << EOF
    client
    dev tun
    proto tcp
    remote 192.0.2.8 1194
    comp-lzo
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    mute-replay-warnings
    remote-cert-tls server
    verb 3
    mute 20
    tls-client
    EOF

Each client that needs to connect should have their own signed client key. The following will create one and generate
an `openvpn.ovpn` file which can be used by an OpenVPN client. Once saved, the temporary directory can be removed.

    $ mkdir tmp-myovpn && cd tmp-myovpn
    $ TMP_CN=$(hostname -s)-$(date +%Y%m%da)
    $ openssl req -new -nodes -days 3650 -newkey rsa:2048 \
      -subj "/C=$EASYRSA_REQ_COUNTRY/ST=$EASYRSA_REQ_PROVINCE/L=$EASYRSA_REQ_CITY/O=$EASYRSA_REQ_ORG/OU=$EASYRSA_REQ_OU/CN=$TMP_CN/emailAddress=`git config user.email`" \
      -out "../pki/reqs/$TMP_CN.req" \
      -keyout openvpn.key
    $ ( cd ../pki && ../easyrsa/easyrsa sign client "$TMP_CN" )
    $ (
        cat ../openvpn-client.conf ;
        echo '<ca>' ;
        cat ../pki/ca.crt ;
        echo '</ca>' ;
        echo '<cert>' ;
        cat "../pki/issued/$TMP_CN.crt" ;
        echo '</cert>' ;
        echo '<key>' ;
        cat openvpn.key ;
        echo '</key>'
      ) >> openvpn.ovpn


## Examples

You might need to share the OpenVPN server's LAN with VPN clients...

    properties.openvpn.push_routes:
      # tell clients they can reach 10.10.0.0/16 through the VPN
      - "10.10.0.0 255.255.0.0"

You might need to manage some `iptables` rules to support the VPN-LAN communication...

    properties.openvpn.iptables:
      # allow VPN traffic to talk to the main network
      - "POSTROUTING -t nat -s 192.0.2.0/24 -d 10.10.1.0/24 -j MASQUERADE
      # allow VPN traffic to talk to a specific server
      - "POSTROUTING -t nat -s 192.0.2.0/24 -d 10.10.2.100/32 -j MASQUERADE

You might need to assign a specific IP address to a specific VPN client...

    properties.openvpn.ccd:
      -
        # this is the "common name" from the certificate they're using to connect
        - "myspecialclient"
        # these are the "client-specific-directives" to push to the client
        # in this case, the client will be assigned the VPN IP of 192.0.2.101
        - "ifconfig-push 192.0.2.101 255.255.255.0"

You might want to allow VPN clients to talk to each other...

    properties.openvpn.extra_config: |
      client-to-client


## OpenVPN Clients

 * [Tunnelblick](https://code.google.com/p/tunnelblick/) (OS X)
