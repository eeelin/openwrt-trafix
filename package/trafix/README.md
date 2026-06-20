# trafix OpenWrt package

This directory contains a standard OpenWrt package definition for `trafix`.

## Layout

- `Makefile`: OpenWrt package metadata and install rules
- `files/etc/config/trafix`: UCI runtime settings
- `files/etc/trafix/config.yaml`: unified rule configuration
- `files/etc/init.d/trafix`: service script
- `files/usr/bin/trafix`: rule compiler / updater
- `files/usr/bin/trafix2dnsmasq.sh`: dnsmasq helper script

## Config model

`trafix` now uses one source config file built around:

- `rule_sets`: inline, local, or remote matcher sources
- `route_rules`: ordered routing decisions with `proxy`, `bypass`, or `block`
- `status_tests`: configurable `check` command targets for proxy / bypass / DNS checks
- `final_action`: default route policy (`bypass` or `proxy`)

Currently supported matcher types in `route_rules` are:

- `rule_set`
- `domain`
- `domain_suffix`
- `ip_cidr`
- `ip6_cidr`

Generated runtime artifacts are written under `/var/trafix/`.

The `status_tests` section is split by:

- `proxy.ipv4`
- `proxy.ipv6`
- `bypass.ipv4`
- `bypass.ipv6`
- `dns.ipv4`
- `dns.ipv6`

## Diagnostics

Run configured connectivity / DNS checks with:

```sh
/etc/init.d/trafix check
```

## Dry run

To review the ipset / iptables / ip6tables commands without applying them on the router:

```sh
/etc/init.d/trafix dryrun_start
/etc/init.d/trafix dryrun_stop
/etc/init.d/trafix dryrun_restart
```

You can also use the standard actions with an environment flag:

```sh
TRAFIX_DRY_RUN=1 /etc/init.d/trafix start
TRAFIX_DRY_RUN=1 /etc/init.d/trafix stop
```

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
