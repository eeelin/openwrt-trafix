# openwrt-trafix

OpenWrt package sources for `trafix`.

## Local build

Build with an existing OpenWrt SDK directory:

```sh
SDK_DIR=/path/to/openwrt-sdk ./build.sh
```

Or let the script download an SDK archive automatically:

```sh
SDK_URL=https://downloads.openwrt.org/releases/25.12.5/targets/x86/64/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst ./build.sh
```

Build artifacts are written to `dist/`. OpenWrt 24.10 and older SDKs produce
`.ipk` packages; OpenWrt 25.12 and newer SDKs produce `.apk` packages.

The build script installs only the feed source packages required by trafix
(`bind`, `jq`, and `yq`) by default. Set `FEEDS_INSTALL_ALL=1` to install every
feed package, or `BUILD_VERBOSE=1` to enable OpenWrt `V=s` output when debugging.

## OpenWrt package feed

Pushes to `main` publish a simple OpenWrt package feed to GitHub Pages. Release tags only publish the GitHub Release assets.

Feed URLs:

- `aarch64_generic`: `https://eeelin.github.io/openwrt-trafix/aarch64_generic`
- `x86_64`: `https://eeelin.github.io/openwrt-trafix/x86_64`

Example for NanoPi R5C (`aarch64_generic`):

```sh
echo 'src/gz trafix https://eeelin.github.io/openwrt-trafix/aarch64_generic' >> /etc/opkg/customfeeds.conf
opkg update
opkg install trafix
```

OpenWrt 25.12 switched from `opkg` to `apk`. Install a locally built 25.12
artifact with:

```sh
apk add --allow-untrusted ./trafix-*.apk
```

## GitHub Actions

- `.github/workflows/build.yml`: validates scripts, builds the package, and publishes the GitHub Pages OpenWrt feed on pushes to `main`.
- `.github/workflows/release.yml`: builds release assets and publishes a GitHub Release when a tag matching `v*` is pushed.
- `.github/openwrt-sdk-matrix.json`: editable SDK build matrix used by both workflows.


Default CI targets build OpenWrt 22.03.5 and OpenWrt 25.12.5 for `x86-64`
plus NanoPi R5C-compatible `rockchip/armv8`.

Release builds pass the Git tag directly into the OpenWrt package metadata.
Numeric release tags are used so a tag such as `0.0.8` produces package version
`0.0.8-r1` (APK) or `0.0.8-1` (IPK).
