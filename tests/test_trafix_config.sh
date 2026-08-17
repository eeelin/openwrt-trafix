#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRAFIX="$ROOT_DIR/package/trafix/files/usr/bin/trafix"
FIXTURES="$ROOT_DIR/tests/fixtures"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_file_contains() {
	local file="$1" expected="$2"
	grep -Fqx -- "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_file_not_contains() {
	local file="$1" unexpected="$2"
	if grep -Fqx -- "$unexpected" "$file"; then
		fail "$file unexpectedly contains: $unexpected"
	fi
}

install_test_yq() {
	local fakebin="$1"
	cat >"$fakebin/yq" <<'PY'
#!/usr/bin/env python3
import json
import sys
import yaml

args = sys.argv[1:]
raw = "-r" in args
expression = next((arg for arg in args if not arg.startswith("-")), ".")
source = args[-1]
with open(source, encoding="utf-8") as stream:
    data = yaml.safe_load(stream) or {}

if expression == ".":
    print(json.dumps(data, separators=(",", ":")))
elif raw and expression == ".payload[]? // empty":
    for value in data.get("payload", []):
        print(value)
else:
    raise SystemExit(f"unsupported test yq expression: {expression}")
PY
	chmod +x "$fakebin/yq"
}

run_update() {
	local config="$1" work="$2"
	mkdir -p "$work/fakebin" "$work/state"
	install_test_yq "$work/fakebin"
	PATH="$work/fakebin:$PATH" \
		TRAFIX_CONFIG="$config" \
		TRAFIX_STATE_DIR="$work/state" \
		TRAFIX_DNSMASQ_OUT="$work/trafix.conf" \
		"$TRAFIX" update
}

test_inline_matchers_and_bypass_default() {
	local work
	work="$(mktemp -d)"
	run_update "$FIXTURES/trafix-inline.yaml" "$work"

	assert_file_contains "$work/state/runtime.env" 'FINAL_ACTION=bypass'
	assert_file_contains "$work/state/proxy-domain.list" 'proxy.example'
	assert_file_contains "$work/state/proxy-domain.list" 'proxy-suffix.example'
	assert_file_not_contains "$work/state/proxy-domain.list" 'disabled.example'
	assert_file_contains "$work/state/proxy-ipset.conf" '198.51.100.8'
	assert_file_contains "$work/state/proxy-ipset-net.conf" '198.51.100.0/24'
	assert_file_contains "$work/state/proxy-ip6set.conf" '2001:db8::8'
	assert_file_contains "$work/state/proxy-ip6set-net.conf" '2001:db8::/64'
	assert_file_contains "$work/state/block-domain.list" 'blocked.example'
	assert_file_contains "$work/state/block-ipset.conf" '203.0.113.7/32'
	assert_file_contains "$work/state/bypass-ip6set-net.conf" '2001:db8:1::/64'
	assert_file_contains "$work/trafix.conf" 'server=/proxy.example/127.0.0.1#6053'
	assert_file_contains "$work/trafix.conf" 'ipset=/proxy-suffix.example/trafix,trafix6'
	assert_file_contains "$work/trafix.conf" 'address=/blocked.example/0.0.0.0'
	rm -rf "$work"
}

test_proxy_default_and_disabled_rule() {
	local work
	work="$(mktemp -d)"
	run_update "$FIXTURES/trafix-final-proxy.yaml" "$work"

	assert_file_contains "$work/state/runtime.env" 'FINAL_ACTION=proxy'
	assert_file_contains "$work/state/bypass-domain.list" 'direct.example'
	assert_file_not_contains "$work/state/block-domain.list" 'ignored.example'
	assert_file_contains "$work/state/bypass-ipset.conf" '192.0.2.9'
	assert_file_contains "$work/state/block-ip6set.conf" '2001:db8:2::9/128'
	assert_file_contains "$work/trafix.conf" 'ipset=/direct.example/trafix-bypass,trafix6-bypass'
	assert_file_not_contains "$work/trafix.conf" 'address=/ignored.example/0.0.0.0'
	rm -rf "$work"
}

test_local_yaml_and_payload_rule_sets() {
	local work
	work="$(mktemp -d)"
	(
		# Run outside the repository to prove that local source paths are
		# resolved relative to the main YAML file, not the caller's cwd.
		cd "$work"
		run_update "$FIXTURES/trafix-local-sources.yaml" "$work"
	)

	assert_file_contains "$work/state/rule-set-cache/local-yaml.tsv" $'domain\tmalware.example'
	assert_file_contains "$work/state/rule-set-cache/local-yaml.tsv" $'ip_cidr\t203.0.113.0/24'
	assert_file_not_contains "$work/state/rule-set-cache/local-yaml.tsv" $'domain_suffix\tdisabled-source.example'
	assert_file_contains "$work/state/rule-set-cache/local-payload.tsv" $'domain\tpayload.example'
	assert_file_contains "$work/state/rule-set-cache/local-payload.tsv" $'ip6_cidr\t2001:db8:3::/64'
	assert_file_contains "$work/state/block-domain.list" 'malware.example'
	assert_file_contains "$work/state/block-ipset-net.conf" '203.0.113.0/24'
	assert_file_not_contains "$work/state/block-domain.list" 'disabled-source.example'
	assert_file_contains "$work/state/proxy-domain.list" 'payload.example'
	assert_file_contains "$work/state/proxy-domain.list" 'payload-suffix.example'
	assert_file_contains "$work/state/proxy-ipset-net.conf" '198.18.0.0/15'
	assert_file_contains "$work/state/proxy-ip6set-net.conf" '2001:db8:3::/64'
	rm -rf "$work"
}

test_absolute_local_rule_set_path() {
	local work config
	work="$(mktemp -d)"
	config="$work/absolute.yaml"
	cat >"$config" <<EOF
rule_sets:
  - tag: absolute
    type: local
    format: yaml
    path: $FIXTURES/trafix-rules.yaml
route_rules:
  - rule_set: [absolute]
    action: block
final_action: bypass
EOF
	(
		cd /tmp
		run_update "$config" "$work"
	)
	assert_file_contains "$work/state/block-domain.list" 'malware.example'
	assert_file_contains "$work/state/block-ipset-net.conf" '203.0.113.0/24'
	rm -rf "$work"
}

test_update_rebuilds_rule_set_cache() {
	local work config source
	work="$(mktemp -d)"
	config="$work/config.yaml"
	source="$work/rules.yaml"
	cat >"$config" <<'EOF'
rule_sets:
  - tag: changing
    type: local
    format: yaml
    path: rules.yaml
route_rules:
  - rule_set: [changing]
    action: block
final_action: bypass
EOF
	cat >"$source" <<'EOF'
match:
  - domain: [old.example]
EOF

	run_update "$config" "$work"
	assert_file_contains "$work/state/rule-set-cache/changing.tsv" $'domain\told.example'
	assert_file_contains "$work/state/block-domain.list" 'old.example'

	cat >"$source" <<'EOF'
match:
  - domain: [new.example]
EOF
	run_update "$config" "$work"

	assert_file_contains "$work/state/rule-set-cache/changing.tsv" $'domain\tnew.example'
	assert_file_not_contains "$work/state/rule-set-cache/changing.tsv" $'domain\told.example'
	assert_file_contains "$work/state/block-domain.list" 'new.example'
	assert_file_not_contains "$work/state/block-domain.list" 'old.example'
	rm -rf "$work"
}

command -v jq >/dev/null || fail 'jq is required to run config tests'
python3 -c 'import yaml' >/dev/null 2>&1 || fail 'PyYAML is required to run config tests'

test_inline_matchers_and_bypass_default
test_proxy_default_and_disabled_rule
test_local_yaml_and_payload_rule_sets
test_absolute_local_rule_set_path
test_update_rebuilds_rule_set_cache

echo 'All trafix YAML configuration tests passed.'
