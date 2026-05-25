#!/usr/bin/env bash
# Build the macOS prebuilt archive(s).
#
# Backends bundled: CPU + OpenCL + Vulkan + Metal.
#
# Run natively on macOS (Xcode Command Line Tools provide clang, libtool).
# The target arch defaults to the host's; override with OCRRS_TARGET, e.g.
#   OCRRS_TARGET=aarch64-apple-darwin scripts/build_macos.sh
#   OCRRS_TARGET=x86_64-apple-darwin  scripts/build_macos.sh
#
# Output: prebuilt/darwin_{amd64|arm64}/libocr_rs_combined.a
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHIM_DIR="$ROOT/ocr-rs-c"
FEATURES="${OCRRS_FEATURES:-opencl vulkan metal coreml}"

host_triple="$(rustc -vV | awk '/host:/ {print $2}')"
TARGET="${OCRRS_TARGET:-$host_triple}"

case "$TARGET" in
    x86_64-apple-darwin)   GO_ARCH=amd64 ;;
    aarch64-apple-darwin)  GO_ARCH=arm64 ;;
    *)
        echo "error: unsupported target '$TARGET' (need *-apple-darwin)" >&2
        exit 1
        ;;
esac

# Ensure the toolchain has the requested target.
rustup target add "$TARGET" >/dev/null

RELEASE_DIR="$SHIM_DIR/target/$TARGET/release"
OUTPUT_DIR="$ROOT/prebuilt/darwin_${GO_ARCH}"

# ocr-rs's build.rs forgets to emit `cargo:rustc-link-lib=framework=CoreVideo`
# when the coreml feature is on, even though MNN's CoreMLExecutor.mm calls
# CVPixelBuffer* (which lives in CoreVideo). Inject the missing link
# directive via RUSTFLAGS so it applies to ocr-rs's cdylib link step too.
export RUSTFLAGS="${RUSTFLAGS:-} -l framework=CoreVideo"

cd "$SHIM_DIR"
echo "==> cargo build --release --target $TARGET --features '$FEATURES'"
cargo build --release --target "$TARGET" --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/libocr_rs_combined.a"
