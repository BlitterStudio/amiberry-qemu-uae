# Amiberry QEMU-UAE PPC Plugin

This repository builds `qemu-uae`, the external QEMU-based PowerPC plugin used by Amiberry for CyberStorm PPC and Blizzard PPC accelerator emulation.

The plugin is intentionally kept outside the Amiberry source tree. Amiberry owns the host ABI, runtime loading, configuration, and packaging hooks; this repository owns the QEMU patch deck and plugin artifact build.

## Version

- QEMU: 11.0.1
- QEMU-UAE plugin API required by Amiberry: 3.8
- QEMU-UAE reference branch: https://github.com/reinauer/qemu-uae/tree/qemu-v11.0.1-uae
- Patch source: https://github.com/reinauer/uae-ppc-plugin

## Build On Linux

Install build dependencies:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  curl \
  ninja-build \
  pkg-config \
  python3 \
  python3-venv \
  libglib2.0-dev \
  libpixman-1-dev \
  libslirp-dev \
  zlib1g-dev
```

Build the plugin:

```bash
./build-qemu-uae-plugin.sh --clean -j "$(nproc)"
```

The default output is:

```text
build/qemu-uae.so
```

Pass `--output /path/to/qemu-uae.so` to copy the finished artifact elsewhere.

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

## Current Platform Scope

The first supported artifact target is Linux x86-64. The repository layout is intended to support macOS and Windows artifacts next, but those need separate dependency and signing work before they should be treated as release outputs.
