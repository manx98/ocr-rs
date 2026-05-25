#!/usr/bin/env bash
# Merge the shim + libmnn_wrapper + libMNN archives into one self-contained
# static library inside OUTPUT_DIR.
#
# The toolchain (and therefore the file extensions, archiver, and output
# name) is detected from what cargo actually produced under RELEASE_DIR:
#
#   * libocr_rs_c.a   → GNU/MinGW/macOS toolchain (`ar` or `libtool`)
#       output: libocr_rs_combined.a
#   * ocr_rs_c.lib    → MSVC toolchain (`lib.exe`)
#       output: ocr_rs_combined.lib
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

# ----- detect toolchain by which artifact name cargo produced ----------------
if [[ -f "$RELEASE_DIR/ocr_rs_c.lib" ]]; then
    TOOLCHAIN=msvc
elif [[ -f "$RELEASE_DIR/libocr_rs_c.a" ]]; then
    TOOLCHAIN=ar
else
    echo "error: could not find ocr_rs_c shim archive in $RELEASE_DIR" >&2
    echo "       expected ocr_rs_c.lib (MSVC) or libocr_rs_c.a (gcc/clang)" >&2
    exit 1
fi

if [[ "$TOOLCHAIN" == msvc ]]; then
    SHIM_A="$RELEASE_DIR/ocr_rs_c.lib"
    WRAPPER_A=$(find "$RELEASE_DIR/build" -name 'mnn_wrapper.lib' 2>/dev/null | head -1 || true)
    MNN_A=$(find "$RELEASE_DIR/build" -name 'MNN.lib' 2>/dev/null | sort | head -1 || true)
    OUT="$OUTPUT_DIR/ocr_rs_combined.lib"
else
    SHIM_A="$RELEASE_DIR/libocr_rs_c.a"
    WRAPPER_A=$(find "$RELEASE_DIR/build" -name 'libmnn_wrapper.a' 2>/dev/null | head -1 || true)
    MNN_A=$(find "$RELEASE_DIR/build" -name 'libMNN.a' 2>/dev/null | sort | head -1 || true)
    OUT="$OUTPUT_DIR/libocr_rs_combined.a"
fi

for f in "$SHIM_A" "$WRAPPER_A" "$MNN_A"; do
    if [[ -z "$f" || ! -f "$f" ]]; then
        echo "error: required archive not found: '$f'" >&2
        exit 1
    fi
done

rm -f "$OUT"
uname_s="$(uname -s 2>/dev/null || echo unknown)"

case "$TOOLCHAIN" in
    msvc)
        # lib.exe ships with MSVC; PATH must contain it (vcvars/msvc-dev-cmd).
        if ! command -v lib.exe >/dev/null 2>&1; then
            echo "error: lib.exe is not on PATH; initialise the VS environment first" >&2
            exit 1
        fi
        # /LTCG keeps LTO/-Clto compatible objects intact; harmless otherwise.
        lib.exe /NOLOGO /OUT:"$(cygpath -w "$OUT" 2>/dev/null || echo "$OUT")" \
            "$(cygpath -w "$SHIM_A" 2>/dev/null || echo "$SHIM_A")" \
            "$(cygpath -w "$WRAPPER_A" 2>/dev/null || echo "$WRAPPER_A")" \
            "$(cygpath -w "$MNN_A" 2>/dev/null || echo "$MNN_A")"
        ;;
    ar)
        case "$uname_s" in
            Darwin)
                # BSD libtool ships with Xcode/CommandLineTools.
                libtool -static -o "$OUT" "$SHIM_A" "$WRAPPER_A" "$MNN_A"
                ;;
            *)
                # GNU ar MRI script. Works on Linux and (in the rare MinGW
                # case) MSYS too.
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
        ;;
esac

size_str=""
if command -v du >/dev/null 2>&1; then
    size_str=" ($(du -sh "$OUT" | cut -f1))"
fi
echo "Created $OUT${size_str}"
