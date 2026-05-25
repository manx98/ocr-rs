#!/usr/bin/env bash
# Build the Windows/amd64 prebuilt archive (CPU + OpenCL + Vulkan).
#
# Targets x86_64-pc-windows-gnu so the resulting archive links against
# MinGW-w64 — which is what cgo on Windows uses by default.
#
# Designed to run inside MSYS2/Git-Bash on the windows-latest GitHub runner
# (or any environment with bash + MinGW-w64 + cmake + rustup-x86_64-pc-windows-gnu).
#
# Output: prebuilt/windows_amd64/libocr_rs_combined.a
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHIM_DIR="$ROOT/ocr-rs-c"
TARGET="${OCRRS_TARGET:-x86_64-pc-windows-gnu}"
RELEASE_DIR="$SHIM_DIR/target/$TARGET/release"
OUTPUT_DIR="$ROOT/prebuilt/windows_amd64"
FEATURES="${OCRRS_FEATURES:-opencl vulkan}"

# Ensure the toolchain has the requested target. With the MSYS2-native
# `mingw-w64-x86_64-rust` package there is no rustup (the default host is
# already x86_64-pc-windows-gnu), so silently skip.
if command -v rustup >/dev/null 2>&1; then
    rustup target add "$TARGET" >/dev/null
fi

# Force MinGW gcc/ar/ranlib so cargo + cc-rs + cmake all agree on the toolchain.
export CC="${CC:-x86_64-w64-mingw32-gcc}"
export CXX="${CXX:-x86_64-w64-mingw32-g++}"
export AR="${AR:-x86_64-w64-mingw32-ar}"
export RANLIB="${RANLIB:-x86_64-w64-mingw32-ranlib}"
# Used by ocr-rs build.rs / MNN CMakeLists.txt
export CMAKE_C_COMPILER="$CC"
export CMAKE_CXX_COMPILER="$CXX"
export CMAKE_AR="$AR"
export CMAKE_RANLIB="$RANLIB"

cd "$SHIM_DIR"
echo "==> cargo build --release --target $TARGET --features '$FEATURES'"
cargo build --release --target "$TARGET" --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/libocr_rs_combined.a"
