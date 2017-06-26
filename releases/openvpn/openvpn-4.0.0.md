*Please review these changes carefully - many properties and defaults have changed which may impact connectivity. While breaking changes are generally avoided, the goals of this release necessitated some significant changes. Those goals were: utilize modern BOSH features, improve performance, encourage secure defaults, avoid duplicated features, and simplify configuration requirements.*

Breaking Changes

 * properties are no longer prefixed with `openvpn` namespace
 * default protocol is now `udp` (this must be in sync with clients; previous default `tcp`)
 * the `openvpn` job will no longer act as a client (see the new `openvpn-client` job)
 * the `openvpn` job improves security defaults (either explicitly use older values, or upgrade clients as necessary)
    * `cipher` is now `AES-256-CBC` (this must be in sync with clients; previous default `BF-CBC`)
    * `tls_version_min` is now `1.2` (requires clients 2.3.3+; previous default `1.0`)
 * custom iptables rules are no longer managed (use the `iptables` job of [networking](https://github.com/cloudfoundry/networking-release) release instead)
 * server and client certificates are now configured with the `tls_key_pair` property with support for certificate generation (previously via `ca_crt`, `certificate`, and `private_key` properties)
 * certificate revocation lists for `openvpn` are now configured with the `tls_crl` property (previously via `crl_pem` property)

New Features

 * UDP is now supported (see `protocol` property of `openvpn`)
 * the openvpn `compress` option is now supported (see `compress` property of `openvpn`)
 * the openvpn `tls-crypt` option is now supported (see `tls_crypt` property of `openvpn`)
 * new `extra_configs` property of `openvpn` and `openvpn-client` (similar to `extra_config`, but accepts an array of openvpn directives)
 * new `device` property is now supported for explicit virtual network device usage

Upgrades

 * openvpn 2.4.3
