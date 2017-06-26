title: Creating a PKI
---

OpenVPN uses a [PKI](http://en.wikipedia.org/wiki/Public_key_infrastructure) for authentication. You may need to create
one from scratch and the [easy-rsa](https://github.com/OpenVPN/easy-rsa/) package simplifies those workflows...

    $ echo '/easyrsa' >> .gitignore
    $ mkdir easyrsa
    $ wget -qO- "https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.0-rc1/EasyRSA-3.0.0-rc1.tgz" \
      | tar -xzC easyrsa --strip-components 1


## Setup


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


## Server Key-pair

You will need at least one server key, so create and sign one...

    $ cd pki
    $ CN=server
    $ openssl req -new -nodes -days 3650 -newkey rsa:2048 \
      -subj "/C=$EASYRSA_REQ_COUNTRY/ST=$EASYRSA_REQ_PROVINCE/L=$EASYRSA_REQ_CITY/O=$EASYRSA_REQ_ORG/OU=$EASYRSA_REQ_OU/CN=$CN/emailAddress=$EASYRSA_REQ_EMAIL" \
      -out "reqs/$CN.req" \
      -keyout "private/$CN.key"
    $ ../easyrsa/easyrsa sign server "$CN"
    $ cd ../


## Signing Client Requests

When the client sends a CSR to the operator, the operator can sign the request using the following...

    $ cd pki
    $ ../easyrsa/easyrsa sign client "$TMP_CN" )


## Deployment Configuration

Once you have a PKI setup and a server key-pair configured, you can use the file data for your deployment properties...

    * openvpn.ca_crt -> ./pki/ca.crt
    * openvpn.server_crt -> ./pki/issued/server.crt
    * openvpn.server_key -> ./pki/private/server.key
    * openvpn.crl_pem -> ./pki/crl.pem
    * openvpn.dh_pem -> ./pki/dh.pem
