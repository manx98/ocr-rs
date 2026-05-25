#!/usr/bin/env bash
# Build the Windows/amd64 prebuilt archive (CPU + OpenCL + Vulkan).
#
# Targets x86_64-pc-windows-msvc — ocr-rs's build.rs hard-codes a
# "NMake Makefiles" CMake generator plus /MT/MD compiler flags, both of
# which only make sense with MSVC. This script therefore expects the
# MSVC environment to already be initialised (vcvarsall or
# `ilammy/msvc-dev-cmd` in CI) so that cl.exe, lib.exe, link.exe and
# nmake.exe are all on PATH.
#
# In addition the VS environment must expose OpenCL.lib and vulkan.lib
# via the LIB env var (CI installs the Vulkan SDK and the Khronos
# OpenCL ICD loader for this).
#
# Output: prebuilt/windows_amd64/ocr_rs_combined.lib
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHIM_DIR="$ROOT/ocr-rs-c"
TARGET="${OCRRS_TARGET:-x86_64-pc-windows-msvc}"
RELEASE_DIR="$SHIM_DIR/target/$TARGET/release"
OUTPUT_DIR="$ROOT/prebuilt/windows_amd64"
FEATURES="${OCRRS_FEATURES:-opencl vulkan}"

if command -v rustup >/dev/null 2>&1; then
    rustup target add "$TARGET" >/dev/null
fi

cd "$SHIM_DIR"
echo "==> cargo build --release --target $TARGET --features '$FEATURES'"
cargo build --release --target "$TARGET" --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/ocr_rs_combined.lib"
