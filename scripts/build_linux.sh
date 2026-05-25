#!/usr/bin/env bash
# Build the Linux/amd64 prebuilt archive (CPU + OpenCL + Vulkan).
#
# Expects to run on an Ubuntu 18.04 host (or a glibc <= 2.27 container) so the
# resulting archive links cleanly on every reasonably modern Linux distro.
#
# Required tools (the GitHub Actions workflow installs them):
#   * Rust toolchain (cargo)
#   * cmake >= 3.10
#   * gcc/g++ with C++17 support, GNU ar/ranlib
#   * git (cargo registry fetches)
#
# Output: prebuilt/linux_amd64/libocr_rs_combined.a
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHIM_DIR="$ROOT/ocr-rs-c"
RELEASE_DIR="$SHIM_DIR/target/release"
OUTPUT_DIR="$ROOT/prebuilt/linux_amd64"
FEATURES="${OCRRS_FEATURES:-opencl vulkan}"

cd "$SHIM_DIR"
echo "==> cargo build --release --features '$FEATURES'"
cargo build --release --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/libocr_rs_combined.a"
