# trafix OpenWrt package

This directory contains a standard OpenWrt package definition for `trafix`.

## Layout

- `Makefile`: OpenWrt package metadata and install rules
- `files/etc/config/trafix`: UCI runtime settings
- `files/etc/trafix/config.yaml`: unified rule configuration
- `files/etc/init.d/trafix`: service script
- `files/usr/bin/trafix`: rule compiler / updater
- `files/usr/bin/trafix2dnsmasq.sh`: legacy helper retained for reference

## Config model

`trafix` now uses one source config file built around:

- `rule_sets`: inline, local, or remote matcher sources
- `route_rules`: ordered routing decisions with `proxy`, `bypass`, or `block`
- `final_action`: default route policy (`bypass` or `proxy`)

Currently supported matcher types in `route_rules` are:

- `rule_set`
- `domain`
- `domain_suffix`
- `ip_cidr`
- `ip6_cidr`

Generated runtime artifacts are written under `/var/trafix/`.

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
