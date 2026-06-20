# openwrt-trafix

OpenWrt package sources for `trafix`.

## Local build

Build with an existing OpenWrt SDK directory:

```sh
SDK_DIR=/path/to/openwrt-sdk ./build.sh
```

Or let the script download an SDK archive automatically:

```sh
SDK_URL=https://downloads.openwrt.org/releases/22.03.5/targets/x86/64/openwrt-sdk-22.03.5-x86-64_gcc-11.2.0_musl.Linux-x86_64.tar.xz ./build.sh
```

Build artifacts are written to `dist/`.

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

## GitHub Actions

- `.github/workflows/build.yml`: validates scripts, builds the package, and publishes the GitHub Pages OpenWrt feed on pushes to `main`.
- `.github/workflows/release.yml`: builds release assets and publishes a GitHub Release when a tag matching `v*` is pushed.
- `.github/openwrt-sdk-matrix.json`: editable SDK build matrix used by both workflows.


Default CI targets currently prefer OpenWrt 22.03.5 and are trimmed to `x86-64` plus NanoPi R5C matching `rockchip/armv8`.
