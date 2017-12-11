# Advanced Settings

There are a few additional options available which are intended for advanced configuration. Here are some examples of them...


## Compression

If you want to perform additional compress on data, use the `compress` option. Historically, `lzo` was used, but `lz4` is recommended for newer deployments. Compression requires additional CPU for both client and server.

    compress: lz4


## Share Intranet

In case you want to allow VPN clients to access a network accessible by the OpenVPN server.

    push_routes:
      # tell clients they can reach 10.10.0.0/16 through the VPN
      - "10.10.0.0 255.255.0.0"


## Client-specific Configuration

You might need to push specific directives or assign a specific IP address to a single VPN client...

    ccd:
      -
        # this is the "common name" from the certificate they're using to connect
        - "myspecialclient"
        # these are the "client-specific-directives" to push to the client
        # in this case, the client will be assigned the VPN IP of 192.0.2.101
        - "ifconfig-push 192.0.2.101 255.255.255.0"


## Extra Configurations

Use `extra_config` to include otherwise-unconfigurable directives for the OpenVPN server.

    extra_config: |
      client-to-client
      tcp-nodelay

Alternatively, configure directives as array elements with the `extra_configs` property...

    extra_configs:
    - client-to-client
    - tcp-nodelay
