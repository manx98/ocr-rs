# ocr-rs

Go bindings for the Rust [`ocr-rs`](https://docs.rs/ocr-rs/) crate (PaddleOCR
text detection + recognition via MNN).

The repository ships **per-platform prebuilt static archives** at
`prebuilt/<os>_<arch>/libocr_rs_combined.a`, so end users do **not** need a
Rust toolchain, MNN install, or any other native dependency — `go get` and
`go build` are enough.

```go
import ocrrs "github.com/manx98/ocr-rs"

eng, err := ocrrs.New(detPath, recPath, charsetPath, ocrrs.BackendCPU)
if err != nil { /* ... */ }
defer eng.Close()

out, err := eng.Recognize("photo.jpg")
for _, r := range out.Results {
    fmt.Printf("%-40q  conf=%.2f  bbox=%+v\n", r.Text, r.Confidence, r.BBox)
}
```

## Supported targets

| GOOS    | GOARCH | Backends bundled                  |
|---------|--------|-----------------------------------|
| linux   | amd64  | CPU + OpenCL + Vulkan             |
| darwin  | amd64  | CPU + OpenCL + Vulkan + Metal     |
| darwin  | arm64  | CPU + OpenCL + Vulkan + Metal     |
| windows | amd64  | CPU + OpenCL + Vulkan             |

The Linux archive is produced inside an Ubuntu 18.04 container, so the
resulting binaries link cleanly on every distro with glibc ≥ 2.27.

OpenCL/Vulkan runtimes are `dlopen`'d at runtime by MNN — the static
archive itself has no link-time dependency on them, so falling back to the
CPU backend always works.

## Layout

```
ocrrs.go, cgo_<os>_<arch>.go     Go bindings (package ocrrs)
include/ocr_rs.h                 C ABI header
prebuilt/<os>_<arch>/...         Prebuilt static archives (consumed by cgo)
ocr-rs-c/                        Rust C-ABI shim source (for rebuilding)
scripts/build_<os>.sh            Platform build scripts
scripts/merge_libs.sh            Combines shim + libmnn_wrapper + libMNN
.github/workflows/prebuilt.yml   CI driving all four targets
examples/                        Sample binary (same Go module)
Makefile                         Convenience wrapper around the scripts
```

## Build the example

```sh
make example
./examples/ocr-example det.mnn rec.mnn keys.txt image.jpg
# or
make run ARGS="det.mnn rec.mnn keys.txt image.jpg"
```

## Rebuilding the prebuilt archives

End users never need to do this. The scripts below are for maintainers
shipping a new version. The recommended path is the GitHub Actions
workflow at `.github/workflows/prebuilt.yml`, which produces all four
archives on the matching runners; the `bundle` job collects them into a
single artifact you can drop back into `prebuilt/`.

To run a single platform locally:

```sh
# Ubuntu 18.04 (host or container)
make linux

# macOS (Xcode CLT installed). Defaults to host arch; or:
make macos-amd64
make macos-arm64

# Windows: from the MSYS2/MINGW64 shell
make windows
```

Each script:

1. Runs `cargo build --release --features '<backends>'` inside `ocr-rs-c/`
   (with the `build-mnn-from-source` feature already pinned in
   `ocr-rs-c/Cargo.toml`, so MNN is compiled from source — no MNN
   install required).
2. Invokes `scripts/merge_libs.sh` to combine the shim + MNN archives
   into a single self-contained `libocr_rs_combined.a` under the matching
   `prebuilt/` directory.

### Build prerequisites per platform

| Platform | Tools required                                                                      |
|----------|-------------------------------------------------------------------------------------|
| Linux    | gcc-8/g++-8, cmake ≥ 3.10, rustup, GNU `ar`/`ranlib`                                 |
| macOS    | Xcode Command Line Tools (clang, libtool), rustup with `*-apple-darwin` targets    |
| Windows  | MSYS2 MINGW64 toolchain (`mingw-w64-x86_64-{toolchain,cmake,ninja}`), rustup w/ gnu |

## API

```go
type Backend int

const (
    BackendCPU    Backend = 0
    BackendMetal  Backend = 1 // macOS only
    BackendOpenCL Backend = 2
    BackendOpenGL Backend = 3
    BackendVulkan Backend = 4
    BackendCUDA   Backend = 5 // not bundled
    BackendCoreML Backend = 6 // not bundled
)

func New(detPath, recPath, charsetPath string, backend Backend) (*Engine, error)
func (e *Engine) Close()
func (e *Engine) RecognizeJSON(imagePath string) (string, error)
func (e *Engine) Recognize(imagePath string) (*Output, error)
func Version() string
```

### JSON output shape

```json
{
  "results": [
    {
      "text": "Hello",
      "confidence": 0.93,
      "bbox": { "left": 12, "top": 34, "width": 100, "height": 24 }
    }
  ]
}
```
