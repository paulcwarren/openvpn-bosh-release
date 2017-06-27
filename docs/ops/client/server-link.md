# Server Link

The [`openvpn-client`](../../../jobs/openvpn-client) job requires a [link](https://bosh.io/docs/links.html) named `openvpn` which describes the connection to the server. The [`openvpn`](../../../jobs/openvpn) job implicitly provides the correct link.


## Cross-Deployment Links

Here's an example of consuming a [cross-deployment](https://bosh.io/docs/links.html#cross-deployment) link...

    instance_groups:
    - name: vpn
      jobs:
      - name: openvpn-client
        release: openvpn
        consumes:
          openvpn:
            from: openvpn
            deployment: aws-infra-vpn


## Manual Link

For scenarios where the OpenVPN server is not provided by BOSH, you can manually configure the link...

    instance_groups:
    - name: vpn
      jobs:
      - name: openvpn-client
        release: openvpn
        consumes:
          openvpn:
            instances:
            - address: infra-vpn.aws-use1.prod.acme.local
            properties:
              protocol: tcp
              port: 1194
              cipher: AES-256-CBC
              keysize: 256
              tls_key_pair:
                ca: |
                  -----BEGIN CERTIFICATE-----
                  ...
                  -----END CERTIFICATE-----
        properties:
          tls_key_pair:
            certificate: |
              -----BEGIN CERTIFICATE-----
              ...
              -----END CERTIFICATE-----
            private_key: |
              -----BEGIN RSA PRIVATE KEY-----
              ...
              -----END RSA PRIVATE KEY-----
