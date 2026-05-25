//go:build linux && amd64

package ocrrs

// Linux/amd64: CPU + OpenCL + Vulkan.
//
// `-lOpenCL` / `-lvulkan` are NOT added: MNN dlopens both ICDs at
// runtime, so requested but absent drivers just disable the backend
// without breaking the link.

// #cgo linux,amd64 LDFLAGS: ${SRCDIR}/prebuilt/linux_amd64/libocr_rs_combined.a -lstdc++ -ldl -lm -lpthread
import "C"
