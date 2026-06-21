#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/package/trafix/files/etc/init.d/trafix"

assert_contains() {
	local haystack="$1"
	local needle="$2"
	if [[ "$haystack" != *"$needle"* ]]; then
		echo "Expected output to contain: $needle" >&2
		exit 1
	fi
}

assert_not_contains() {
	local haystack="$1"
	local needle="$2"
	if [[ "$haystack" == *"$needle"* ]]; then
		echo "Did not expect output to contain: $needle" >&2
		exit 1
	fi
}

prepare_common_stubs() {
	local fakebin="$1"

	cat >"$fakebin/curl" <<'EOF'
#!/bin/sh
last=""
for arg in "$@"; do
	last="$arg"
done
case "$last" in
	https://ipinfo.io/203.0.113.1)
		echo '{"org":"AS-GOOGLE","city":"Mountain View","country":"US"}'
		;;
	https://ipinfo.io/203.0.113.2)
		echo '{"org":"AS-IFCONFIG","city":"Phoenix","country":"US"}'
		;;
	https://ipinfo.io/2001:db8::1)
		echo '{"org":"AS-OPENWRT","city":"Berlin","country":"DE"}'
		;;
	https://ifconfig.io)
		echo '198.51.100.10'
		;;
	https://ipinfo.io/ip)
		echo '198.51.100.20'
		;;
	https://v6.ipinfo.io/ip)
		echo '2001:db8::20'
		;;
	*)
		echo '{}'
		;;
esac
EOF

	cat >"$fakebin/jq" <<'EOF'
#!/bin/sh
input="$(cat)"
case "$1" in
	-r)
		filter="$2"
		case "$filter" in
			'.city + " / " + .country')
				case "$input" in
					*'"city":"Mountain View"'*) echo 'Mountain View / US' ;;
					*'"city":"Phoenix"'*) echo 'Phoenix / US' ;;
					*'"city":"Berlin"'*) echo 'Berlin / DE' ;;
					*) echo ' / ' ;;
				esac
				;;
			'.org + " @ " + .city + " / " + .country')
				case "$input" in
					*'"org":"AS-GOOGLE"'*) echo 'AS-GOOGLE @ Mountain View / US' ;;
					*'"org":"AS-IFCONFIG"'*) echo 'AS-IFCONFIG @ Phoenix / US' ;;
					*'"org":"AS-OPENWRT"'*) echo 'AS-OPENWRT @ Berlin / DE' ;;
					*) echo ' @  / ' ;;
				esac
				;;
			*)
				echo "unsupported fake jq filter: $filter" >&2
				exit 1
				;;
		esac
		;;
	*)
		echo "unsupported fake jq args: $*" >&2
		exit 1
		;;
esac
EOF

	chmod +x "$fakebin/curl" "$fakebin/jq"
}

run_dns_check_test() {
	local tmpdir fakebin config_file output
	tmpdir="$(mktemp -d)"
	fakebin="$tmpdir/fakebin"
	mkdir -p "$fakebin"
	prepare_common_stubs "$fakebin"

	cat >"$fakebin/yq" <<'EOF'
#!/bin/sh
expr="$2"
case "$expr" in
	'(.status_tests.dns.ipv4 // [])[]')
		printf '%s\n' 'www.google.com' 'ifconfig.io'
		;;
	'(.status_tests.dns.ipv6 // [])[]')
		printf '%s\n' 'openwrt.org'
		;;
	*)
		echo "invalid input text \"empty\"" >&2
		exit 1
		;;
esac
EOF

	cat >"$fakebin/dig" <<'EOF'
#!/bin/sh
domain="$1"
record_type="$2"
case "${domain}/${record_type}" in
	www.google.com/a)
		echo 'www.google.com. 300 IN A 203.0.113.1'
		;;
	ifconfig.io/a)
		echo 'ifconfig.io. 300 IN A 203.0.113.2'
		;;
	openwrt.org/aaaa)
		echo 'openwrt.org. 300 IN AAAA 2001:db8::1'
		;;
esac
EOF

	chmod +x "$fakebin/yq" "$fakebin/dig"
	config_file="$tmpdir/config.yaml"
	printf 'status_tests: {}\n' >"$config_file"

	output="$(PATH="$fakebin:$PATH" bash -c '
		source "'"$SCRIPT_PATH"'"
		resolve_config_file() { echo "'"$config_file"'"; }
		test_dns
	')"

	assert_contains "$output" '[DNS/IPV4] www.google.com --> 203.0.113.1 [AS-GOOGLE @ Mountain View / US]'
	assert_contains "$output" '[DNS/IPV4] ifconfig.io --> 203.0.113.2 [AS-IFCONFIG @ Phoenix / US]'
	assert_contains "$output" '[DNS/IPV6] openwrt.org --> 2001:db8::1 [AS-OPENWRT @ Berlin / DE]'

	rm -rf "$tmpdir"
}

run_dryrun_bypass_test() {
	local tmpdir output
	tmpdir="$(mktemp -d)"
	mkdir -p "$tmpdir/state"
	printf '%s\n' '198.51.100.1' >"$tmpdir/state/proxy-ipset.conf"
	printf '%s\n' '198.51.100.0/24' >"$tmpdir/state/proxy-ipset-net.conf"
	printf '%s\n' '2001:db8::10' >"$tmpdir/state/proxy-ip6set.conf"
	printf '%s\n' '2001:db8::/64' >"$tmpdir/state/proxy-ip6set-net.conf"
	printf '%s\n' '198.51.100.2' >"$tmpdir/state/bypass-ipset.conf"
	printf '%s\n' '198.51.100.3' >"$tmpdir/state/block-ipset.conf"
	printf 'FINAL_ACTION=bypass\n' >"$tmpdir/state/runtime.env"

	output="$(bash -c '
		config_load() { :; }
		config_get() {
			case "$2/$3" in
				general/redir_ipv4_port) printf -v "$1" "%s" "12345" ;;
				general/redir_ipv6_port) printf -v "$1" "%s" "23456" ;;
				*) printf -v "$1" "%s" "" ;;
			esac
		}
		config_get_bool() { printf -v "$1" "%s" "0"; }
		source "'"$SCRIPT_PATH"'"
		STATE_DIR="'"$tmpdir"'/state"
		RUNTIME_ENV="$STATE_DIR/runtime.env"
		PROXY_IPSET_CONF="$STATE_DIR/proxy-ipset.conf"
		PROXY_IPSET_NET_CONF="$STATE_DIR/proxy-ipset-net.conf"
		PROXY_IP6SET_CONF="$STATE_DIR/proxy-ip6set.conf"
		PROXY_IP6SET_NET_CONF="$STATE_DIR/proxy-ip6set-net.conf"
		BYPASS_IPSET_CONF="$STATE_DIR/bypass-ipset.conf"
		BYPASS_IPSET_NET_CONF="$STATE_DIR/bypass-ipset-net.conf"
		BYPASS_IP6SET_CONF="$STATE_DIR/bypass-ip6set.conf"
		BYPASS_IP6SET_NET_CONF="$STATE_DIR/bypass-ip6set-net.conf"
		BLOCK_IPSET_CONF="$STATE_DIR/block-ipset.conf"
		BLOCK_IPSET_NET_CONF="$STATE_DIR/block-ipset-net.conf"
		BLOCK_IP6SET_CONF="$STATE_DIR/block-ip6set.conf"
		BLOCK_IP6SET_NET_CONF="$STATE_DIR/block-ip6set-net.conf"
		dryrun_start
	')"

	assert_contains "$output" '# dry-run start (FINAL_ACTION=bypass)'
	assert_contains "$output" '+ ipset -q add "trafix" "198.51.100.1"'
	assert_contains "$output" '+ iptables -t nat -C TRAFIX -p tcp -m set --match-set trafix dst -j REDIRECT --to-ports "12345" 2>/dev/null || iptables -t nat -A TRAFIX -p tcp -m set --match-set trafix dst -j REDIRECT --to-ports "12345"'
	assert_contains "$output" '+ ip6tables -t nat -C TRAFIX -p tcp -m set --match-set trafix6 dst -j REDIRECT --to-ports "23456" 2>/dev/null || ip6tables -t nat -A TRAFIX -p tcp -m set --match-set trafix6 dst -j REDIRECT --to-ports "23456"'
	assert_not_contains "$output" '+ iptables -t nat -C TRAFIX -p tcp -j REDIRECT --to-ports "12345" 2>/dev/null || iptables -t nat -A TRAFIX -p tcp -j REDIRECT --to-ports "12345"'

	rm -rf "$tmpdir"
}

run_dryrun_proxy_test() {
	local tmpdir output
	tmpdir="$(mktemp -d)"
	mkdir -p "$tmpdir/state"
	printf 'FINAL_ACTION=proxy\n' >"$tmpdir/state/runtime.env"

	output="$(bash -c '
		config_load() { :; }
		config_get() {
			case "$2/$3" in
				general/redir_ipv4_port) printf -v "$1" "%s" "12345" ;;
				general/redir_ipv6_port) printf -v "$1" "%s" "23456" ;;
				*) printf -v "$1" "%s" "" ;;
			esac
		}
		config_get_bool() { printf -v "$1" "%s" "1"; }
		source "'"$SCRIPT_PATH"'"
		STATE_DIR="'"$tmpdir"'/state"
		RUNTIME_ENV="$STATE_DIR/runtime.env"
		PROXY_IPSET_CONF="$STATE_DIR/proxy-ipset.conf"
		PROXY_IPSET_NET_CONF="$STATE_DIR/proxy-ipset-net.conf"
		PROXY_IP6SET_CONF="$STATE_DIR/proxy-ip6set.conf"
		PROXY_IP6SET_NET_CONF="$STATE_DIR/proxy-ip6set-net.conf"
		BYPASS_IPSET_CONF="$STATE_DIR/bypass-ipset.conf"
		BYPASS_IPSET_NET_CONF="$STATE_DIR/bypass-ipset-net.conf"
		BYPASS_IP6SET_CONF="$STATE_DIR/bypass-ip6set.conf"
		BYPASS_IP6SET_NET_CONF="$STATE_DIR/bypass-ip6set-net.conf"
		BLOCK_IPSET_CONF="$STATE_DIR/block-ipset.conf"
		BLOCK_IPSET_NET_CONF="$STATE_DIR/block-ipset-net.conf"
		BLOCK_IP6SET_CONF="$STATE_DIR/block-ip6set.conf"
		BLOCK_IP6SET_NET_CONF="$STATE_DIR/block-ip6set-net.conf"
		dryrun_start
	')"

	assert_contains "$output" '# dry-run start (FINAL_ACTION=proxy)'
	assert_contains "$output" '+ iptables -t nat -C TRAFIX -p tcp -j REDIRECT --to-ports "12345" 2>/dev/null || iptables -t nat -A TRAFIX -p tcp -j REDIRECT --to-ports "12345"'
	assert_contains "$output" '+ ip6tables -t nat -C TRAFIX -p tcp -j REDIRECT --to-ports "23456" 2>/dev/null || ip6tables -t nat -A TRAFIX -p tcp -j REDIRECT --to-ports "23456"'
	assert_contains "$output" '+ iptables -C TRAFIX_FILTER -p udp --dport 443 -j DROP 2>/dev/null || iptables -A TRAFIX_FILTER -p udp --dport 443 -j DROP'
	assert_contains "$output" '+ ip6tables -C TRAFIX_FILTER -p udp --dport 443 -j DROP 2>/dev/null || ip6tables -A TRAFIX_FILTER -p udp --dport 443 -j DROP'
	assert_not_contains "$output" '--match-set trafix dst -j REDIRECT --to-ports "12345"'

	rm -rf "$tmpdir"
}

run_dns_check_test
run_dryrun_bypass_test
run_dryrun_proxy_test

echo "All trafix init.d tests passed."
