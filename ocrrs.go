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

func lastError() string {
	c := C.ocrrs_last_error()
	if c == nil {
		return "unknown error"
	}
	return C.GoString(c)
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

	h := C.ocrrs_create(cDet, cRec, cChar, C.int(backend))
	if h == nil {
		return nil, errors.New("ocrrs: create failed: " + lastError())
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

	out := C.ocrrs_recognize_json(e.handle, cPath)
	if out == nil {
		return "", errors.New("ocrrs: recognize failed: " + lastError())
	}
	defer C.ocrrs_free_string(out)
	return C.GoString(out), nil
}

// Recognize is a convenience that decodes the JSON into a typed Output.
func (e *Engine) Recognize(imagePath string) (*Output, error) {
	s, err := e.RecognizeJSON(imagePath)
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
