# trafix OpenWrt package

This directory contains a standard OpenWrt package definition for `trafix`.

## Layout

- `Makefile`: OpenWrt package metadata and install rules
- `files/etc/config/trafix`: UCI config
- `files/etc/trafix/*`: persistent config/data files
- `files/etc/init.d/trafix`: service script
- `files/usr/bin/trafix`: update helper
- `files/usr/bin/trafix2dnsmasq.sh`: dnsmasq rule generator

## Build inside OpenWrt SDK / tree

Put this directory under:

```text
package/trafix
```

Then run:

```sh
make package/trafix/compile V=s
```

The generated `.ipk` will be placed under `bin/packages/...`.

## Install on router

```sh
opkg install trafix_1.0.0-1_*.ipk
/etc/init.d/trafix enable
/etc/init.d/trafix start
```

## Update rules

```sh
trafix update
```
