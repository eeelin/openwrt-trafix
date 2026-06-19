#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="${PACKAGE_NAME:-trafix}"
PACKAGE_DIR="${PACKAGE_DIR:-$ROOT_DIR/package/$PACKAGE_NAME}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.work}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$WORK_DIR/downloads}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/dist}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
KEEP_SDK="${KEEP_SDK:-1}"
FEEDS_UPDATE="${FEEDS_UPDATE:-1}"
SDK_URL="${SDK_URL:-}"
SDK_DIR="${SDK_DIR:-}"
SDK_ARCHIVE=""

usage() {
  cat <<USAGE
Usage:
  SDK_URL=<openwrt-sdk-url> ./build.sh
  SDK_DIR=/path/to/openwrt-sdk ./build.sh

Environment variables:
  PACKAGE_NAME   Package name to build (default: trafix)
  PACKAGE_DIR    Package directory (default: ./package/<PACKAGE_NAME>)
  SDK_URL        OpenWrt SDK archive URL to download and use
  SDK_DIR        Existing OpenWrt SDK directory to reuse
  WORK_DIR       Working directory for SDK/download cache (default: ./.work)
  DOWNLOAD_DIR   SDK archive cache directory (default: ./.work/downloads)
  ARTIFACT_DIR   Output directory for generated ipk files (default: ./dist)
  JOBS           Parallel make jobs (default: detected CPU count)
  KEEP_SDK       Keep extracted SDK after build, 1 or 0 (default: 1)
  FEEDS_UPDATE   Run feeds update/install before build, 1 or 0 (default: 1)

Examples:
  SDK_URL=https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/openwrt-sdk-23.05.5-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz ./build.sh
  SDK_DIR=$HOME/openwrt-sdk-23.05.5-x86-64 ./build.sh
USAGE
}

log() {
  printf '[build] %s\n' "$*"
}

fail() {
  printf '[build] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

prepare_sdk() {
  if [[ -n "$SDK_DIR" ]]; then
    [[ -d "$SDK_DIR" ]] || fail "SDK_DIR does not exist: $SDK_DIR"
    SDK_DIR="$(cd "$SDK_DIR" && pwd)"
    return
  fi

  [[ -n "$SDK_URL" ]] || fail "set SDK_URL or SDK_DIR before building"

  mkdir -p "$DOWNLOAD_DIR" "$WORK_DIR"
  SDK_ARCHIVE="$DOWNLOAD_DIR/$(basename "$SDK_URL")"
  if [[ ! -f "$SDK_ARCHIVE" ]]; then
    log "downloading SDK: $SDK_URL"
    require_command curl
    curl -fL --retry 3 --retry-delay 2 -o "$SDK_ARCHIVE" "$SDK_URL"
  else
    log "reusing cached SDK archive: $SDK_ARCHIVE"
  fi

  local extracted_root
  extracted_root="$(tar -tf "$SDK_ARCHIVE" | head -n1 | cut -d/ -f1)"
  [[ -n "$extracted_root" ]] || fail "unable to determine SDK archive root from $SDK_ARCHIVE"

  SDK_DIR="$WORK_DIR/$extracted_root"
  if [[ ! -d "$SDK_DIR" ]]; then
    log "extracting SDK to $SDK_DIR"
    mkdir -p "$WORK_DIR"
    tar -xf "$SDK_ARCHIVE" -C "$WORK_DIR"
  else
    log "reusing extracted SDK: $SDK_DIR"
  fi
}

sync_package() {
  [[ -d "$PACKAGE_DIR" ]] || fail "package directory not found: $PACKAGE_DIR"
  require_command rsync
  mkdir -p "$SDK_DIR/package/$PACKAGE_NAME"
  rsync -a --delete "$PACKAGE_DIR/" "$SDK_DIR/package/$PACKAGE_NAME/"
}

prepare_feeds() {
  if [[ "$FEEDS_UPDATE" != "1" ]]; then
    log "skipping feeds update/install"
    return
  fi

  log "updating feeds"
  (
    cd "$SDK_DIR"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
  )
}

build_package() {
  log "building package $PACKAGE_NAME"
  (
    cd "$SDK_DIR"
    make defconfig
    make "package/$PACKAGE_NAME/clean"
    make -j"$JOBS" "package/$PACKAGE_NAME/compile" V=s
  )
}

collect_artifacts() {
  mkdir -p "$ARTIFACT_DIR"
  find "$ARTIFACT_DIR" -maxdepth 1 -type f \( -name '*.ipk' -o -name 'sha256sums.txt' \) -delete

  mapfile -t ipks < <(find "$SDK_DIR/bin/packages" -type f -name "${PACKAGE_NAME}_*.ipk" | sort)
  [[ ${#ipks[@]} -gt 0 ]] || fail "no ipk artifacts found for $PACKAGE_NAME"

  for ipk in "${ipks[@]}"; do
    cp "$ipk" "$ARTIFACT_DIR/"
  done

  (
    cd "$ARTIFACT_DIR"
    sha256sum ./*.ipk > sha256sums.txt
  )

  log "artifacts written to $ARTIFACT_DIR"
  ls -1 "$ARTIFACT_DIR"
}

cleanup() {
  if [[ "$KEEP_SDK" == "0" && -n "$SDK_DIR" && -d "$SDK_DIR" && "$SDK_DIR" == "$WORK_DIR"/* ]]; then
    log "removing extracted SDK: $SDK_DIR"
    rm -rf "$SDK_DIR"
  fi
}

main() {
  if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    usage
    exit 0
  fi

  require_command tar
  require_command make
  require_command sha256sum

  prepare_sdk
  sync_package
  prepare_feeds
  build_package
  collect_artifacts
  cleanup
}

main "$@"
