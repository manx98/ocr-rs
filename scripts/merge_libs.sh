#!/usr/bin/env bash
# Merge the shim + libmnn_wrapper + libMNN archives into one self-contained
# static library at OUTPUT_DIR/libocr_rs_combined.a.
#
# Linux uses GNU `ar`'s MRI script (avoids extracting .o files, preserving
# identically-named objects across MNN sub-projects). macOS uses BSD
# `libtool -static`, which also preserves them.
#
# Windows builds the equivalent via scripts/build_windows.ps1 (lib.exe) —
# this script intentionally only handles the GNU/BSD ar-style toolchains
# so it can stay safely callable from Git Bash without PATH conflicts.
#
# Usage: merge_libs.sh <cargo_target_release_dir> <output_dir>

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <cargo_target_release_dir> <output_dir>" >&2
    exit 1
fi

RELEASE_DIR="$1"
OUTPUT_DIR="$2"

# Resolve both paths via cd/pwd so we don't depend on GNU realpath's `-m`
# (which BSD realpath on macOS does not support).
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

SHIM_A="$RELEASE_DIR/libocr_rs_c.a"
WRAPPER_A=$(find "$RELEASE_DIR/build" -name 'libmnn_wrapper.a' 2>/dev/null | head -1 || true)
MNN_A=$(find "$RELEASE_DIR/build" -name 'libMNN.a' 2>/dev/null | sort | head -1 || true)

for f in "$SHIM_A" "$WRAPPER_A" "$MNN_A"; do
    if [[ -z "$f" || ! -f "$f" ]]; then
        echo "error: required archive not found: '$f'" >&2
        exit 1
    fi
done

OUT="$OUTPUT_DIR/libocr_rs_combined.a"
rm -f "$OUT"

case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin)
        # BSD libtool ships with Xcode/CommandLineTools.
        libtool -static -o "$OUT" "$SHIM_A" "$WRAPPER_A" "$MNN_A"
        ;;
    *)
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
