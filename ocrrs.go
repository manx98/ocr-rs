// Package ocrrs provides Go bindings for the Rust `ocr-rs` crate (PaddleOCR + MNN).
//
// The bindings link against a per-platform self-contained static archive
// shipped under prebuilt/<os>_<arch>/libocr_rs_combined.a, so consumers do
// not need a working Rust toolchain or MNN install.
//
// Supported targets (and backends bundled into each archive):
//
//	linux/amd64    CPU + OpenCL + Vulkan
//	darwin/amd64   CPU + OpenCL + Vulkan + Metal
//	darwin/arm64   CPU + OpenCL + Vulkan + Metal
//	windows/amd64  CPU + OpenCL + Vulkan
//
// To consume the package:
//
//	import ocrrs "github.com/manx98/ocr-rs"
package ocrrs

/*
#cgo CFLAGS: -I${SRCDIR}/include
#include <stdlib.h>
#include "ocr_rs.h"
*/
import "C"

import (
	"encoding/json"
	"errors"
	"runtime"
	"unsafe"
)

// Backend selects the MNN inference backend. The prebuilt archive must have
// been compiled with the matching cargo feature for non-CPU choices to work.
type Backend int

const (
	BackendCPU    Backend = 0
	BackendMetal  Backend = 1 // macOS only
	BackendOpenCL Backend = 2
	BackendOpenGL Backend = 3
	BackendVulkan Backend = 4
	BackendCUDA   Backend = 5 // not bundled in the shipped prebuilt archives
	BackendCoreML Backend = 6 // not bundled in the shipped prebuilt archives
)

func (b Backend) String() string {
	switch b {
	case BackendCPU:
		return "CPU"
	case BackendMetal:
		return "Metal"
	case BackendOpenCL:
		return "OpenCL"
	case BackendOpenGL:
		return "OpenGL"
	case BackendVulkan:
		return "Vulkan"
	case BackendCUDA:
		return "CUDA"
	case BackendCoreML:
		return "CoreML"
	default:
		return "Unknown"
	}
}

// BBox is the axis-aligned bounding box of a detected text region.
type BBox struct {
	Left   int32  `json:"left"`
	Top    int32  `json:"top"`
	Width  uint32 `json:"width"`
	Height uint32 `json:"height"`
}

// Result is one recognised text region.
type Result struct {
	Text       string  `json:"text"`
	Confidence float32 `json:"confidence"`
	BBox       BBox    `json:"bbox"`
}

// Output is the top-level JSON object returned by RecognizeJSON.
type Output struct {
	Results []Result `json:"results"`
}

// Engine is a handle to a live OCR engine. Not safe for concurrent use by
// multiple goroutines; create one engine per goroutine (or guard with a mutex).
type Engine struct {
	handle *C.OcrEngine
}

// takeCError consumes an owned C string returned by the shim and returns it as
// a Go error, freeing the C allocation. Returns nil if cErr is NULL.
func takeCError(cErr *C.char, prefix string) error {
	if cErr == nil {
		return nil
	}
	msg := C.GoString(cErr)
	C.ocrrs_free_string(cErr)
	if prefix == "" {
		return errors.New(msg)
	}
	return errors.New(prefix + ": " + msg)
}

// New creates an OCR engine.
//
//   - detPath:     path to the detection MNN model
//   - recPath:     path to the recognition MNN model
//   - charsetPath: path to the keys.txt charset file
//   - backend:     inference backend
//
// All three files must exist when called.
func New(detPath, recPath, charsetPath string, backend Backend) (*Engine, error) {
	cDet := C.CString(detPath)
	defer C.free(unsafe.Pointer(cDet))
	cRec := C.CString(recPath)
	defer C.free(unsafe.Pointer(cRec))
	cChar := C.CString(charsetPath)
	defer C.free(unsafe.Pointer(cChar))

	var h *C.OcrEngine
	if err := takeCError(
		C.ocrrs_create(cDet, cRec, cChar, C.int(backend), &h),
		"ocrrs: create failed",
	); err != nil {
		return nil, err
	}
	e := &Engine{handle: h}
	runtime.SetFinalizer(e, func(e *Engine) { e.Close() })
	return e, nil
}

// Close releases the engine. Safe to call multiple times.
func (e *Engine) Close() {
	if e == nil || e.handle == nil {
		return
	}
	C.ocrrs_destroy(e.handle)
	e.handle = nil
	runtime.SetFinalizer(e, nil)
}

// RecognizeJSON runs OCR on imagePath and returns the raw JSON output as
// produced by the Rust side. The JSON shape is:
//
//	{"results": [
//	  {"text": "...", "confidence": 0.93,
//	   "bbox": {"left": 12, "top": 34, "width": 100, "height": 24}}
//	]}
func (e *Engine) RecognizeJSON(imagePath string) (string, error) {
	if e == nil || e.handle == nil {
		return "", errors.New("ocrrs: engine is closed")
	}
	cPath := C.CString(imagePath)
	defer C.free(unsafe.Pointer(cPath))

	var out *C.char
	if err := takeCError(
		C.ocrrs_recognize_json(e.handle, cPath, &out),
		"ocrrs: recognize failed",
	); err != nil {
		return "", err
	}
	defer C.ocrrs_free_string(out)
	return C.GoString(out), nil
}

// RecognizeJSONBytes is the in-memory variant of RecognizeJSON: data must
// be the contents of an encoded image (PNG / JPEG / WebP / BMP / TIFF /
// ICO etc.); the format is auto-detected from the magic bytes.
func (e *Engine) RecognizeJSONBytes(data []byte) (string, error) {
	if e == nil || e.handle == nil {
		return "", errors.New("ocrrs: engine is closed")
	}
	if len(data) == 0 {
		return "", errors.New("ocrrs: data is empty")
	}

	var out *C.char
	if err := takeCError(
		C.ocrrs_recognize_json_bytes(
			e.handle,
			(*C.uint8_t)(unsafe.Pointer(&data[0])),
			C.size_t(len(data)),
			&out,
		),
		"ocrrs: recognize failed",
	); err != nil {
		return "", err
	}
	defer C.ocrrs_free_string(out)
	return C.GoString(out), nil
}

// Recognize is a convenience that decodes the JSON into a typed Output.
func (e *Engine) Recognize(imagePath string) (*Output, error) {
	return decodeOutput(e.RecognizeJSON(imagePath))
}

// RecognizeBytes is the in-memory variant of Recognize: data must contain
// an encoded image (PNG / JPEG / etc.); the format is auto-detected.
func (e *Engine) RecognizeBytes(data []byte) (*Output, error) {
	return decodeOutput(e.RecognizeJSONBytes(data))
}

func decodeOutput(s string, err error) (*Output, error) {
	if err != nil {
		return nil, err
	}
	var o Output
	if err := json.Unmarshal([]byte(s), &o); err != nil {
		return nil, err
	}
	return &o, nil
}

// Version returns the underlying Rust shim version.
func Version() string {
	return C.GoString(C.ocrrs_version())
}
