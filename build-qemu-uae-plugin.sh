#!/usr/bin/env bash
set -euo pipefail

qemu_version="11.0.1"
qemu_archive="qemu-${qemu_version}.tar.xz"
qemu_url_default="https://download.qemu.org/${qemu_archive}"
qemu_sha256="0d235f5820278d914a3155ec27af8e4258d697ea892895570807d69c0cb8cd64"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patch_dir="${QEMU_UAE_PATCH_DIR:-${script_dir}/patches}"
patch_file="${QEMU_UAE_PATCH:-}"
work_dir="${QEMU_UAE_WORK_DIR:-${script_dir}/build}"
qemu_url="${QEMU_UAE_QEMU_URL:-${qemu_url_default}}"
tarball="${QEMU_UAE_TARBALL:-}"
source_dir="${QEMU_UAE_SOURCE_DIR:-}"
output_plugin="${QEMU_UAE_OUTPUT_PLUGIN:-}"
deps_prefix="${QEMU_UAE_DEPS_PREFIX:-}"
jobs="${QEMU_UAE_JOBS:-}"
clean=0
verify=1
configure_args=()
host_system="$(uname -s)"
case "${host_system}" in
    Darwin*)
        plugin_extension="dylib"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        plugin_extension="dll"
        ;;
    *)
        plugin_extension="so"
        ;;
esac
plugin_name="qemu-uae.${plugin_extension}"

usage() {
    cat <<EOF
Usage: $0 [options] [-- configure-arg ...]

Download QEMU ${qemu_version}, apply the QEMU-UAE patch deck, and build
the native qemu-uae plugin artifact.

Options:
  --work-dir DIR       Working directory. Default: ./build next to script.
  --source-dir DIR     Patched QEMU source directory.
  --tarball FILE       Use an existing QEMU ${qemu_version} tarball.
  --url URL            Download URL. Default: ${qemu_url_default}
  --output FILE        Copy the finished qemu-uae plugin to FILE.
  --patch-dir DIR      Directory containing ordered *.patch files.
  -j, --jobs N         Ninja parallelism.
  --clean              Remove the source directory before extracting.
  --no-verify          Skip tarball SHA-256 verification.
  -h, --help           Show this help.

Environment:
  QEMU_UAE_PATCH       Single patch file override.
  QEMU_UAE_PATCH_DIR   Directory containing ordered *.patch files.
  QEMU_UAE_DEPS_PREFIX  Prefix containing dependency pkg-config files.
  QEMU_UAE_NINJA        Ninja executable. Defaults to ninja in PATH.
  MACOSX_DEPLOYMENT_TARGET
                         macOS deployment target. Default on Darwin: 13.0.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --work-dir)
            [[ $# -ge 2 ]] || die "--work-dir requires an argument"
            work_dir="$2"
            shift 2
            ;;
        --source-dir)
            [[ $# -ge 2 ]] || die "--source-dir requires an argument"
            source_dir="$2"
            shift 2
            ;;
        --tarball)
            [[ $# -ge 2 ]] || die "--tarball requires an argument"
            tarball="$2"
            shift 2
            ;;
        --url)
            [[ $# -ge 2 ]] || die "--url requires an argument"
            qemu_url="$2"
            shift 2
            ;;
        --output)
            [[ $# -ge 2 ]] || die "--output requires an argument"
            output_plugin="$2"
            shift 2
            ;;
        --patch-dir)
            [[ $# -ge 2 ]] || die "--patch-dir requires an argument"
            patch_dir="$2"
            shift 2
            ;;
        -j|--jobs)
            [[ $# -ge 2 ]] || die "$1 requires an argument"
            jobs="$2"
            shift 2
            ;;
        --clean)
            clean=1
            shift
            ;;
        --no-verify)
            verify=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            configure_args=("$@")
            break
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

patch_files=()
if [[ -n "${patch_file}" ]]; then
    [[ -f "${patch_file}" ]] || die "patch not found: ${patch_file}"
    patch_files=("${patch_file}")
else
    [[ -d "${patch_dir}" ]] || die "patch directory not found: ${patch_dir}"
    while IFS= read -r patch; do
        patch_files+=("${patch}")
    done < <(find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' | sort)
    [[ "${#patch_files[@]}" -gt 0 ]] || die "no patch files found in ${patch_dir}"
fi

download_dir="${work_dir}/downloads"
if [[ -z "${tarball}" ]]; then
    tarball="${download_dir}/${qemu_archive}"
fi
if [[ -z "${source_dir}" ]]; then
    source_dir="${work_dir}/qemu-${qemu_version}-uae"
fi
if [[ -z "${output_plugin}" ]]; then
    output_plugin="${work_dir}/${plugin_name}"
fi

if [[ -z "${jobs}" ]]; then
    if command -v sysctl >/dev/null 2>&1; then
        jobs="$(sysctl -n hw.ncpu 2>/dev/null || true)"
    fi
    if [[ -z "${jobs}" ]] && command -v nproc >/dev/null 2>&1; then
        jobs="$(nproc)"
    fi
    jobs="${jobs:-4}"
fi

if [[ -n "${deps_prefix}" ]]; then
    [[ -d "${deps_prefix}" ]] || die "dependency prefix does not exist: ${deps_prefix}"
    deps_prefix="$(cd "${deps_prefix}" && pwd)"
    export PATH="${deps_prefix}/bin:${PATH}"
    export PKG_CONFIG_LIBDIR="${deps_prefix}/lib/pkgconfig:${deps_prefix}/share/pkgconfig${PKG_CONFIG_LIBDIR:+:${PKG_CONFIG_LIBDIR}}"
fi

if [[ "${host_system}" == "Darwin" ]]; then
    export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
fi

download_qemu() {
    if [[ -f "${tarball}" ]]; then
        return
    fi

    mkdir -p "$(dirname "${tarball}")"
    local tmp="${tarball}.tmp"
    rm -f "${tmp}"

    if command -v curl >/dev/null 2>&1; then
        curl -L --fail -o "${tmp}" "${qemu_url}"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "${tmp}" "${qemu_url}"
    else
        die "curl or wget is required to download ${qemu_url}"
    fi

    mv "${tmp}" "${tarball}"
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        return 1
    fi
}

verify_qemu() {
    [[ "${verify}" == "1" ]] || return

    local actual
    actual="$(sha256_file "${tarball}")" || die "no SHA-256 tool found; use --no-verify to skip"
    [[ "${actual}" == "${qemu_sha256}" ]] || die "SHA-256 mismatch for ${tarball}"
}

extract_qemu() {
    if [[ "${clean}" == "1" ]]; then
        rm -rf "${source_dir}"
    fi
    if [[ -d "${source_dir}" ]]; then
        return
    fi

    mkdir -p "${work_dir}" "$(dirname "${source_dir}")"
    local extract_dir="${work_dir}/.extract.$$"
    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"
    local tar_args=(-xf "${tarball}" -C "${extract_dir}")
    case "${host_system}" in
        MINGW*|MSYS*|CYGWIN*)
            tar_args=(
                --exclude="qemu-${qemu_version}/roms"
                --exclude="qemu-${qemu_version}/roms/*"
                --exclude="qemu-${qemu_version}/tests/lcitool"
                --exclude="qemu-${qemu_version}/tests/lcitool/*"
                "${tar_args[@]}"
            )
            ;;
    esac
    tar "${tar_args[@]}"
    mv "${extract_dir}/qemu-${qemu_version}" "${source_dir}"
    rm -rf "${extract_dir}"
}

apply_qemu_patch_file() {
    local patch_file="$1"
    local patch_name
    patch_name="$(basename "${patch_file}")"

    if (cd "${source_dir}" && patch -p1 --dry-run -f < "${patch_file}" >/dev/null); then
        echo "applying ${patch_name}"
        (cd "${source_dir}" && patch -p1 -f < "${patch_file}")
    elif (cd "${source_dir}" && patch -p1 -R --dry-run -f < "${patch_file}" >/dev/null); then
        echo "${patch_name} already applied"
    else
        die "${patch_name} does not apply cleanly to ${source_dir}"
    fi
}

apply_qemu_patches() {
    local patch_file

    for patch_file in "${patch_files[@]}"; do
        apply_qemu_patch_file "${patch_file}"
    done

    chmod +x "${source_dir}/configure-qemu-uae"
}

find_ninja() {
    if [[ -n "${QEMU_UAE_NINJA:-}" ]]; then
        echo "${QEMU_UAE_NINJA}"
    elif command -v ninja >/dev/null 2>&1; then
        command -v ninja
    elif command -v ninja-build >/dev/null 2>&1; then
        command -v ninja-build
    else
        return 1
    fi
}

build_qemu_uae() {
    local ninja
    ninja="$(find_ninja)" || die "ninja not found; set QEMU_UAE_NINJA"

    (
        cd "${source_dir}"
        ./configure-qemu-uae \
            --ninja="${ninja}" \
            ${configure_args[@]+"${configure_args[@]}"}
    )
    "${ninja}" -C "${source_dir}/build" -j "${jobs}" "${plugin_name}"

    local built_plugin="${source_dir}/build/${plugin_name}"
    [[ -f "${built_plugin}" ]] || die "${plugin_name} was not produced"
    mkdir -p "$(dirname "${output_plugin}")"
    cp "${built_plugin}" "${output_plugin}"
}

download_qemu
verify_qemu
extract_qemu
apply_qemu_patches
build_qemu_uae

echo "${output_plugin}"
