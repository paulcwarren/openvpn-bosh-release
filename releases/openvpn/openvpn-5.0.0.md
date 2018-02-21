Breaking Changes

* the `openvpn` job will now always push the `compress` property to clients, when configured (`push_compress` property has been removed)

New Features

* the `compress` algorithm will now, by default, be automatically determined based on client compatibility (this adds implicit support for older, 2.3 clients)
