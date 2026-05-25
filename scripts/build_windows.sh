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

# Git Bash on Windows prepends /usr/bin to PATH; that directory contains a
# GNU `link` (coreutils ln-equivalent) that shadows MSVC's `link.exe`. Strip
# Git's MSYS bin dirs so the VS link.exe / cl.exe / lib.exe resolve first.
case "$(uname -s 2>/dev/null || true)" in
    MINGW*|MSYS*|CYGWIN*)
        PATH="$(echo "$PATH" | tr ':' '\n' \
            | grep -viE '/[Gg]it/(usr|mingw[0-9]*)/bin' \
            | paste -sd ':' -)"
        export PATH
        # Pin cargo's MSVC linker to the absolute path of the right link.exe,
        # in case anything else fiddles with PATH later.
        if [[ -z "${CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER:-}" ]]; then
            link_path="$(where.exe link.exe 2>/dev/null | head -1 | tr -d '\r' || true)"
            if [[ -n "$link_path" ]]; then
                export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER="$link_path"
            fi
        fi
        ;;
esac

if command -v rustup >/dev/null 2>&1; then
    rustup target add "$TARGET" >/dev/null
fi

cd "$SHIM_DIR"
echo "==> cargo build --release --target $TARGET --features '$FEATURES'"
cargo build --release --target "$TARGET" --features "$FEATURES"

echo "==> merging static archives into $OUTPUT_DIR"
bash "$HERE/merge_libs.sh" "$RELEASE_DIR" "$OUTPUT_DIR"

echo "==> done: $OUTPUT_DIR/ocr_rs_combined.lib"
