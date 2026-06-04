# Amiberry QEMU-UAE PPC Plugin

This repository builds `qemu-uae`, the external QEMU-based PowerPC plugin used by Amiberry for CyberStorm PPC and Blizzard PPC accelerator emulation.

The plugin is intentionally kept outside the Amiberry source tree. Amiberry owns the host ABI, runtime loading, configuration, and packaging hooks; this repository owns the QEMU patch deck and plugin artifact build.

## Version

- QEMU: 11.0.1
- QEMU-UAE plugin API required by Amiberry: 3.8
- QEMU-UAE reference branch: https://github.com/reinauer/qemu-uae/tree/qemu-v11.0.1-uae
- Patch source: https://github.com/reinauer/uae-ppc-plugin

## Supported Artifacts

The GitHub Actions workflow builds the plugin for the desktop platforms that can load Amiberry dynamic plugins:

| Platform | Artifact | Notes |
| --- | --- | --- |
| Linux x86_64 | `qemu-uae-linux-x86_64` | Built in an Ubuntu 22.04 container for an older glibc baseline. |
| Linux aarch64 | `qemu-uae-linux-aarch64` | Built in an Ubuntu 22.04 container on an ARM64 runner. |
| macOS x86_64 | `qemu-uae-macos-x86_64` | Intermediate per-architecture dylib. |
| macOS arm64 | `qemu-uae-macos-arm64` | Intermediate per-architecture dylib. |
| macOS universal | `qemu-uae-macos-universal` | Lipo-merged dylib for Amiberry's universal app bundle. |
| Windows x64 | `qemu-uae-windows-x64` | Built with MSYS2 CLANG64. |
| Windows arm64 | `qemu-uae-windows-arm64` | Built with MSYS2 CLANGARM64. |

Android and iOS are not artifact targets because Amiberry currently disables dynamic PPC plugin loading there. FreeBSD and Haiku remain source-build or future-CI targets until their plugin packaging/runtime dependency story is proven.

## Release Publishing

Tagged releases publish reusable plugin asset archives for Amiberry packaging:

| Asset | Contents |
| --- | --- |
| `qemu-uae-linux-x86_64.tar.xz` | `qemu-uae.so` |
| `qemu-uae-linux-aarch64.tar.xz` | `qemu-uae.so` |
| `qemu-uae-macos-universal.zip` | `qemu-uae.dylib` |
| `qemu-uae-windows-x64.zip` | `qemu-uae.dll` |
| `qemu-uae-windows-arm64.zip` | `qemu-uae.dll` |
| `SHA256SUMS` | Checksums for the release assets |

Use a tag such as `v11.0.1-amiberry.1` for the first release. The plugin is expected to change rarely, so Amiberry releases can keep reusing the same plugin release tag until either the QEMU-UAE API or plugin patch deck changes.

These plugin artifacts are not signed here. Amiberry bundles the selected artifact into the final platform package, and the Amiberry release workflow handles macOS and Windows package signing after bundling.

## Build On Linux

Install build dependencies:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  curl \
  ninja-build \
  patch \
  pkg-config \
  python3 \
  python3-venv \
  xz-utils \
  libglib2.0-dev \
  libpixman-1-dev \
  zlib1g-dev
```

Build the plugin:

```bash
./build-qemu-uae-plugin.sh --clean -j "$(nproc)"
```

The default Linux output is:

```text
build/qemu-uae.so
```

Pass `--output /path/to/qemu-uae.so` to copy the finished artifact elsewhere.

## Build On macOS

Install build dependencies:

```bash
brew install ninja pkg-config glib
```

Build the plugin:

```bash
./build-qemu-uae-plugin.sh --clean -j "$(sysctl -n hw.ncpu)"
```

The default macOS output is:

```text
build/qemu-uae.dylib
```

## Build On Windows

Use an MSYS2 CLANG shell matching the target architecture:

- x64: `CLANG64`
- arm64: `CLANGARM64`

Install build dependencies with `pacman`/`pacboy`, then build:

```bash
pacboy -S --needed clang:p glib2:p ninja:p pkgconf:p python:p zlib:p
pacman -S --needed base-devel ca-certificates curl git patch tar xz
CC=clang CXX=clang++ ./build-qemu-uae-plugin.sh --clean -j "$(nproc)"
```

The default Windows output is:

```text
build/qemu-uae.dll
```

## Use With Amiberry

For local testing, place the built plugin in Amiberry's configured plugins directory, or configure Amiberry packaging with:

```bash
cmake -B build-amiberry \
  -DUSE_PPC=ON \
  -DUSE_QEMU_PPC=ON \
  -DQEMU_UAE_PLUGIN=/path/to/qemu-uae.so
```

Amiberry validates the plugin major API version exactly and requires minor version `3.8` or newer.

## Patch Deck

The ordered patch files in `patches/` are applied to the clean QEMU 11.0.1 release tarball. Keep patch filenames ordered and deterministic.

To refresh from the current upstream reference patch repo:

```bash
rm -f patches/*.patch
cp /path/to/uae-ppc-plugin/patches/*.patch patches/
```

After refreshing, run:

```bash
bash -n build-qemu-uae-plugin.sh
./build-qemu-uae-plugin.sh --clean -j "$(nproc)"
```
