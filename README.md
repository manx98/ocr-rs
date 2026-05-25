# ocr-rs

Go bindings for the Rust [`ocr-rs`](https://docs.rs/ocr-rs/) crate (PaddleOCR
text detection + recognition via MNN).

The repository ships **per-platform prebuilt static archives** under
`prebuilt/<os>_<arch>/` (`.a` everywhere except Windows, where it is a
MSVC-format `.lib`), so end users do **not** need a Rust toolchain, MNN
install, or any other native dependency — `go get` and `go build` are
enough on Linux/macOS. Windows consumers need an MSVC environment (see
below).

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
| linux   | amd64  | CPU + OpenCL + Vulkan + OpenGL                                                       |
| linux   | amd64  | CPU + OpenCL + Vulkan + OpenGL + **CUDA** — opt-in via `-tags ocrrs_cuda`            |
| darwin  | amd64  | CPU + OpenCL + Vulkan + Metal + CoreML                                               |
| darwin  | arm64  | CPU + OpenCL + Vulkan + Metal + CoreML                                               |
| windows | amd64  | CPU + OpenCL + Vulkan (MSVC only)                                                    |
| windows | amd64  | CPU + OpenCL + Vulkan + **CUDA** — opt-in via `-tags ocrrs_cuda`, MSVC required      |

The Linux archive is produced inside an Ubuntu 18.04 container, so the
resulting binaries link cleanly on every distro with glibc ≥ 2.27.

On Linux/macOS the OpenCL/Vulkan runtimes are `dlopen`'d at runtime by
MNN — the static archive has no link-time dependency on them, so falling
back to the CPU backend always works.

Linux OpenGL is **not** dlopen'd: the static archive references libGL
symbols directly, so consumers need `libgl1` (Mesa or proprietary) at
link and run time. Desktop distros ship it by default; minimal server
images usually do not — install `libgl1-mesa-glx` (or equivalent).

### CUDA backend (Linux/amd64 and Windows/amd64)

`BackendCUDA` is built into a *separate* prebuilt archive:

* Linux:   `prebuilt/linux_amd64_cuda/libocr_rs_combined.a`
* Windows: `prebuilt/windows_amd64_cuda/ocr_rs_combined.lib`

Activate it by building your Go binary with the `ocrrs_cuda` build tag:

```sh
go build -tags ocrrs_cuda ./...
```

Calling `New(..., BackendCUDA)` without that tag returns an error
asking you to rebuild with it. The CUDA variant **also** statically
references CUDA Toolkit + cuDNN libraries (`-lcuda -lcudart -lcublas
-lcudnn` on Linux, `cuda.lib cudart.lib cublas.lib cudnn.lib` on
Windows), so:

* The host doing the `go build` needs CUDA Toolkit + cuDNN dev libs.
* The host running the binary needs matching runtime libs plus an
  NVIDIA driver.

If those aren't acceptable for your deployment, stick to the default
variant — `BackendCPU` / `BackendOpenCL` / `BackendVulkan` still cover
most workloads.

### Windows consumer requirements

The Windows prebuilt is MSVC-format because `ocr-rs` upstream hard-codes
an `NMake Makefiles` CMake generator plus MSVC-only compiler flags (no
MinGW path). To build a Go program against it:

1. Install **Visual Studio Build Tools** (Desktop development with C++).
2. Open a *Developer Command Prompt* (or run `vcvars64.bat`) so cl.exe,
   link.exe and lib.exe are on `PATH`.
3. Set `CC=cl` (and optionally `CXX=cl`) before `go build` — this makes
   cgo use the MSVC driver instead of its default MinGW gcc.

At runtime, OpenCL.dll and vulkan-1.dll must be reachable (both come
bundled with current NVIDIA/AMD/Intel GPU drivers). With neither
present, only `BackendCPU` is functional.

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

| Platform | Tools required                                                                                            |
|----------|-----------------------------------------------------------------------------------------------------------|
| Linux    | gcc-8/g++-8, cmake ≥ 3.13, rustup, GNU `ar`/`ranlib`, clang+libclang-dev, `ocl-icd-opencl-dev`, `libvulkan-dev`, `libgl1-mesa-dev libglew-dev libegl1-mesa-dev` |
| Linux CUDA | everything above **plus** CUDA Toolkit (nvcc, cudart, cublas) and cuDNN dev. Easiest in CI: build inside `nvidia/cuda:11.4.3-cudnn8-devel-ubuntu18.04` |
| Windows CUDA | everything in the Windows row above **plus** CUDA Toolkit (Jimver/cuda-toolkit action) and the cuDNN Windows redistributable (`cudnn-windows-x86_64-8.9.7.29_cuda11-archive.zip` from `developer.download.nvidia.com`) |
| macOS    | Xcode Command Line Tools (clang, libtool), rustup with `*-apple-darwin` targets                          |
| Windows  | VS Build Tools (cl/link/lib/nmake on PATH), Vulkan SDK (LunarG), OpenCL.lib (e.g. vcpkg `opencl`), rustup w/ MSVC |

> The OpenCL / Vulkan dev packages only satisfy the *build-time* linker for
> `ocr-rs`'s side-cdylib; the static archive we ship has no link-time
> dependency on either runtime. MNN `dlopen`'s the actual ICDs at startup,
> falling back to CPU when none are present.

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

// File-path entry points
func (e *Engine) RecognizeJSON(imagePath string)  (string,  error)
func (e *Engine) Recognize    (imagePath string)  (*Output, error)

// In-memory entry points — `data` is the contents of an encoded image
// (PNG / JPEG / WebP / BMP / TIFF / ICO …); format is auto-detected.
func (e *Engine) RecognizeJSONBytes(data []byte) (string,  error)
func (e *Engine) RecognizeBytes    (data []byte) (*Output, error)

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
