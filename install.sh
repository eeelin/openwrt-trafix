#!/bin/sh

set -eu

REPO="${TRAFIX_GITHUB_REPO:-eeelin/openwrt-trafix}"
VERSION="latest"
DRY_RUN=0

log() {
	printf '[trafix/install] %s\n' "$*"
}

fail() {
	printf '[trafix/install] ERROR: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage: ./install.sh [--version TAG] [--dry-run]

Downloads and installs the newest compatible trafix package from GitHub.

Options:
  --version TAG  Install a specific release tag instead of the latest release
  --dry-run      Print the selected package without downloading or installing it
  -h, --help     Show this help

Environment:
  TRAFIX_GITHUB_REPO  GitHub owner/repository (default: eeelin/openwrt-trafix)
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--version)
			[ "$#" -ge 2 ] || fail '--version requires a tag'
			VERSION="$2"
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			fail "unknown argument: $1"
			;;
	esac
done

if command -v curl >/dev/null 2>&1; then
	fetch_stdout() { curl -fsSL -H 'Accept: application/vnd.github+json' "$1"; }
	download_file() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
	fetch_stdout() { wget -qO- "$1"; }
	download_file() { wget -qO "$2" "$1"; }
else
	fail 'curl or wget is required'
fi

case "$VERSION" in
	latest) api_url="https://api.github.com/repos/$REPO/releases/latest" ;;
	*) api_url="https://api.github.com/repos/$REPO/releases/tags/$VERSION" ;;
esac

log "querying GitHub release metadata"
release_json="$(fetch_stdout "$api_url")" || fail "unable to query $api_url"
tag="$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n 1)"
[ -n "$tag" ] || fail 'release metadata does not contain tag_name'

machine="$(uname -m)"
case "$machine" in
	x86_64|amd64)
		target='x86-64'
		package_arch='x86_64'
		;;
	aarch64|arm64)
		target='rockchip-armv8'
		package_arch='aarch64_generic'
		;;
	*)
		fail "unsupported architecture: $machine"
		;;
esac

if command -v apk >/dev/null 2>&1; then
	package_manager='apk'
	openwrt_version='25.12.5'
	asset_pattern="openwrt-25\\.12\\.5-${target}-trafix-${tag}-r[0-9]+\\.apk$"
elif command -v opkg >/dev/null 2>&1; then
	package_manager='opkg'
	openwrt_version='22.03.5'
	asset_pattern="openwrt-22\\.03\\.5-${target}-trafix_${tag}-[0-9]+_${package_arch}\\.ipk$"
else
	fail 'neither apk nor opkg was found; this installer must run on OpenWrt'
fi

asset_urls="$(printf '%s\n' "$release_json" | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')"
package_url="$(printf '%s\n' "$asset_urls" | grep -E "$asset_pattern" | head -n 1 || true)"
[ -n "$package_url" ] || fail "release $tag has no compatible $package_manager package for $machine"
escaped_openwrt_version="$(printf '%s' "$openwrt_version" | sed 's/\./\\./g')"
checksum_url="$(printf '%s\n' "$asset_urls" | grep -E "openwrt-${escaped_openwrt_version}-${target}-sha256sums\\.txt$" | head -n 1 || true)"

log "release: $tag"
log "architecture: $machine ($target)"
log "package manager: $package_manager"
log "asset: ${package_url##*/}"
[ "$DRY_RUN" = 0 ] || exit 0

tmp_dir="$(mktemp -d /tmp/trafix-install.XXXXXX)" || fail 'unable to create temporary directory'
trap 'rm -rf "$tmp_dir"' EXIT INT TERM
package_file="$tmp_dir/${package_url##*/}"
download_file "$package_url" "$package_file" || fail 'package download failed'

if [ -n "$checksum_url" ] && command -v sha256sum >/dev/null 2>&1; then
	checksum_file="$tmp_dir/sha256sums.txt"
	download_file "$checksum_url" "$checksum_file" || fail 'checksum download failed'
	expected_hash="$(awk 'NF >= 2 { print $1; exit }' "$checksum_file")"
	actual_hash="$(sha256sum "$package_file" | awk '{print $1}')"
	[ -n "$expected_hash" ] && [ "$actual_hash" = "$expected_hash" ] || fail 'package checksum verification failed'
	log 'checksum verified'
else
	log 'warning: release checksum could not be verified'
fi

log "installing $tag"
case "$package_manager" in
	apk) apk add --allow-untrusted "$package_file" ;;
	opkg) opkg install "$package_file" ;;
esac

if [ -x /etc/init.d/trafix ]; then
	/etc/init.d/trafix enable
	/etc/init.d/trafix restart
fi

log "trafix $tag installed successfully"
