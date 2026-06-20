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

## GitHub Actions

- `.github/workflows/build.yml`: validates scripts and builds the package on push, pull request, and manual trigger.
- `.github/workflows/release.yml`: builds and publishes release assets when a tag matching `v*` is pushed.
- `.github/openwrt-sdk-matrix.json`: editable SDK build matrix used by both workflows.


Default CI targets currently prefer OpenWrt 22.03.5 and are trimmed to `x86-64` plus NanoPi R5C matching `rockchip/armv8`.
