#!/usr/bin/env bash
# Merge libocr_rs_c + libmnn_wrapper + libMNN into a single static archive
# named libocr_rs_combined.a in OUTPUT_DIR.
#
# Cross-platform:
#   * Linux / Windows (MinGW/MSYS): GNU ar MRI script (avoids extracting .o
#     files so identically-named objects from different MNN sub-projects
#     keep distinct archive entries).
#   * macOS: libtool -static, which already preserves directory layout.
#
# Usage: merge_libs.sh <cargo_target_release_dir> <output_dir>

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <cargo_target_release_dir> <output_dir>" >&2
    exit 1
fi

RELEASE_DIR="$1"
OUTPUT_DIR="$2"

if command -v realpath >/dev/null 2>&1; then
    RELEASE_DIR="$(realpath "$RELEASE_DIR")"
    OUTPUT_DIR="$(realpath -m "$OUTPUT_DIR")"
else
    RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
fi

SHIM_A="$RELEASE_DIR/libocr_rs_c.a"
WRAPPER_A=$(find "$RELEASE_DIR/build" -name 'libmnn_wrapper.a' 2>/dev/null | head -1 || true)
MNN_A=$(find "$RELEASE_DIR/build" -name 'libMNN.a' 2>/dev/null | sort | head -1 || true)

for f in "$SHIM_A" "$WRAPPER_A" "$MNN_A"; do
    if [[ -z "$f" || ! -f "$f" ]]; then
        echo "error: required archive not found: '$f'" >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR"
OUT="$OUTPUT_DIR/libocr_rs_combined.a"
rm -f "$OUT"

uname_s="$(uname -s 2>/dev/null || echo unknown)"

case "$uname_s" in
    Darwin)
        # BSD libtool ships with Xcode/CommandLineTools.
        libtool -static -o "$OUT" "$SHIM_A" "$WRAPPER_A" "$MNN_A"
        ;;
    *)
        # Use GNU ar's MRI script. Works on Linux and MSYS/MinGW.
        AR_BIN="${AR:-ar}"
        "$AR_BIN" -M <<EOF
CREATE $OUT
ADDLIB $SHIM_A
ADDLIB $WRAPPER_A
ADDLIB $MNN_A
SAVE
END
EOF
        if command -v ranlib >/dev/null 2>&1; then
            ranlib "$OUT"
        fi
        ;;
esac

size_str=""
if command -v du >/dev/null 2>&1; then
    size_str=" ($(du -sh "$OUT" | cut -f1))"
fi
echo "Created $OUT${size_str}"
