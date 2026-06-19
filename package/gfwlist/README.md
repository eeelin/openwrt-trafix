# gfwlist OpenWrt package

This directory contains a standard OpenWrt package definition for `gfwlist`.

## Layout

- `Makefile`: OpenWrt package metadata and install rules
- `files/etc/config/gfwlist`: UCI config
- `files/etc/gfwlist/*`: persistent config/data files
- `files/etc/init.d/gfwlist`: service script
- `files/usr/bin/gfwlist`: update helper
- `files/usr/bin/gfwlist2dnsmasq.sh`: dnsmasq rule generator

## Build inside OpenWrt SDK / tree

Put this directory under:

```text
package/gfwlist
```

Then run:

```sh
make package/gfwlist/compile V=s
```

The generated `.ipk` will be placed under `bin/packages/...`.

## Install on router

```sh
opkg install gfwlist_1.0.0-1_*.ipk
/etc/init.d/gfwlist enable
/etc/init.d/gfwlist start
```

## Update rules

```sh
gfwlist update
```
