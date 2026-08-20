#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"

printf 'test apk payload\n' >"$work/package.apk"
hash="$(sha256sum "$work/package.apk" | awk '{print $1}')"
printf '%s  ./trafix-0.0.8-r1.apk\n' "$hash" >"$work/sha256sums.txt"
cat >"$work/release.json" <<'EOF'
{
  "tag_name": "0.0.8",
  "assets": [
    {"browser_download_url": "https://example.test/openwrt-22.03.5-rockchip-armv8-sha256sums.txt"},
    {"browser_download_url": "https://example.test/openwrt-25.12.5-rockchip-armv8-sha256sums.txt"},
    {"browser_download_url": "https://example.test/openwrt-25.12.5-rockchip-armv8-trafix-0.0.8-r1.apk"}
  ]
}
EOF

cat >"$work/bin/uname" <<'EOF'
#!/bin/sh
echo aarch64
EOF
cat >"$work/bin/apk" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >"$TEST_APK_ARGS"
EOF
cat >"$work/bin/curl" <<'EOF'
#!/bin/sh
output=
last=
while [ "$#" -gt 0 ]; do
	case "$1" in
		-o) output="$2"; shift 2 ;;
		*) last="$1"; shift ;;
	esac
done
if [ -z "$output" ]; then
	cat "$TEST_RELEASE_JSON"
elif echo "$last" | grep -q 'sha256sums.txt$'; then
	cp "$TEST_CHECKSUM" "$output"
else
	cp "$TEST_PACKAGE" "$output"
fi
EOF
chmod +x "$work/bin/uname" "$work/bin/apk" "$work/bin/curl"

output="$(
	PATH="$work/bin:$PATH" \
	TEST_APK_ARGS="$work/apk.args" \
	TEST_RELEASE_JSON="$work/release.json" \
	TEST_CHECKSUM="$work/sha256sums.txt" \
	TEST_PACKAGE="$work/package.apk" \
	"$INSTALLER"
)"

[[ "$output" == *'[trafix/install] release: 0.0.8'* ]]
[[ "$output" == *'[trafix/install] checksum verified'* ]]
[[ "$output" == *'[trafix/install] trafix 0.0.8 installed successfully'* ]]
grep -Eq '^add --allow-untrusted .*/openwrt-25\.12\.5-rockchip-armv8-trafix-0\.0\.8-r1\.apk$' "$work/apk.args"

echo 'All installer tests passed.'
