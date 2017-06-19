Breaking Changes

 * properties are no longer prefixed with `openvpn` namespace
 * new `openvpn-client` job (client functionality removed from `openvpn` job)
    * client now assumes `openvpn` link with server properties
 * custom iptables rules are no longer managed (use the `iptables` job of [networking](https://github.com/cloudfoundry/networking-release) release instead)

New Features

 * UDP is now supported (see `protocol` property of `openvpn`)
 * the openvpn `compress` option is now supported (see `compress` property of `openvpn`)
