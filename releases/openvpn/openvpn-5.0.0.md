Breaking Changes

* the `openvpn` job will now always push the `compress` property to clients, when configured (`push_compress` property has been removed)

New Features

* the `compress` algorithm will now, by default, be automatically determined based on client compatibility (this adds implicit support for older, 2.3 clients)
* the `openvpn-client` job can now be configured with a static `username` and `password`

Upgrades

 * openvpn 2.4.5 (was 2.4.4)
 * openssl 1.1.0h (was 1.1.0g)

Development

* add job template testing
* move artifacts into a separate `artifacts` branch
* add dev/beta/rc/stable channels for external consumption
