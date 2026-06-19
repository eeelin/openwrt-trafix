# openwrt-trafix

OpenWrt package sources for `trafix`.

## Local build

Build with an existing OpenWrt SDK directory:

```sh
SDK_DIR=/path/to/openwrt-sdk ./build.sh
```

Or let the script download an SDK archive automatically:

```sh
SDK_URL=https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/openwrt-sdk-23.05.5-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz ./build.sh
```

Build artifacts are written to `dist/`.

## GitHub Actions

- `.github/workflows/build.yml`: validates scripts and builds the package on push, pull request, and manual trigger.
- `.github/workflows/release.yml`: builds and publishes release assets when a tag matching `v*` is pushed.
- `.github/openwrt-sdk-matrix.json`: editable SDK build matrix used by both workflows.
