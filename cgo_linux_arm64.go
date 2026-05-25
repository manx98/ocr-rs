//go:build linux && arm64

package ocrrs

// Linux/arm64: CPU + OpenCL + Vulkan.
//
// `-lOpenCL` / `-lvulkan` are NOT added: MNN dlopens both ICDs at
// runtime, so requested but absent drivers just disable the backend
// without breaking the link.

// #cgo linux,arm64 LDFLAGS: ${SRCDIR}/prebuilt/linux_arm64/libocr_rs_combined.a -lstdc++ -ldl -lm -lpthread
import "C"
