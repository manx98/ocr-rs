#!/usr/bin/env bash
# Build the Linux/amd64 prebuilt archive.
#
# Default variant features: CPU + OpenCL + Vulkan + OpenGL.
# CUDA variant: set OCRRS_VARIANT=cuda — additionally enables CUDA and
# writes the result under prebuilt/linux_amd64_cuda/.
#
# Expected to run on Ubuntu 18.04 (default variant) or
# nvidia/cuda:11.4.3-cudnn8-devel-ubuntu18.04 (cuda variant) so the
# archive only requires glibc 2.27 at runtime.
#
# Required tools (the GitHub Actions workflow installs them):
#   * Rust toolchain (cargo)
#   * cmake >= 3.10, gcc-8/g++-8, GNU ar/ranlib, clang + libclang-dev
#   * ocl-icd-opencl-dev, libvulkan-dev, libgl1-mesa-dev
#   * For OCRRS_VARIANT=cuda: full CUDA Toolkit (nvcc, cudart, cublas)
#     plus cuDNN dev headers/libs.
#
# Output:
#   * default: prebuilt/linux_amd64/libocr_rs_combined.a
#   * cuda:    prebuilt/linux_amd64_cuda/libocr_rs_combined.a
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHIM_DIR="$ROOT/ocr-rs-c"
RELEASE_DIR="$SHIM_DIR/target/release"

VARIANT="${OCRRS_VARIANT:-}"
DEFAULT_FEATURES="opencl vulkan opengl"
if [[ "$VARIANT" == "cuda" ]]; then
    DEFAULT_FEATURES="$DEFAULT_FEATURES cuda"
    OUTPUT_DIR="$ROOT/prebuilt/linux_amd64_cuda"
else
    OUTPUT_DIR="$ROOT/prebuilt/linux_amd64"
fi
FEATURES="${OCRRS_FEATURES:-$DEFAULT_FEATURES}"

cd "$SHIM_DIR"
echo "==> cargo build --release --features '$FEATURES'"
cargo build --release --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/libocr_rs_combined.a"
