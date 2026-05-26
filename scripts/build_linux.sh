#!/usr/bin/env bash
# Build the Linux prebuilt archive for the *host's* architecture.
#
# Bundled backends: CPU + OpenCL + Vulkan.
#
# Expected to run on Ubuntu 18.04 (or a glibc-2.27 container) so the
# resulting archive links cleanly on every reasonably modern Linux
# distro. The output directory is derived from `uname -m`:
#
#   uname -m == x86_64   -> prebuilt/linux_amd64/
#   uname -m == aarch64  -> prebuilt/linux_arm64/
#
# Override with `OCRRS_GOARCH=amd64|arm64` if the host arch can't be
# auto-detected (e.g. cross-compiling).
#
# Required tools (the GitHub Actions workflow installs them):
#   * Rust toolchain (cargo)
#   * cmake >= 3.10, gcc-8/g++-8, GNU ar/ranlib, clang + libclang-dev
#   * ocl-icd-opencl-dev, libvulkan-dev
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHIM_DIR="$ROOT/ocr-rs-c"
RELEASE_DIR="$SHIM_DIR/target/release"
FEATURES="${OCRRS_FEATURES:-opencl vulkan}"

GOARCH="${OCRRS_GOARCH:-}"
if [[ -z "$GOARCH" ]]; then
    case "$(uname -m)" in
        x86_64)         GOARCH=amd64 ;;
        aarch64|arm64)  GOARCH=arm64 ;;
        *)
            echo "error: unsupported host arch '$(uname -m)'; set OCRRS_GOARCH explicitly" >&2
            exit 1
            ;;
    esac
fi
OUTPUT_DIR="$ROOT/prebuilt/linux_${GOARCH}"

cd "$SHIM_DIR"
echo "==> cargo build --release --features '$FEATURES'"
cargo build --release --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/libocr_rs_combined.a (GOARCH=$GOARCH)"
