//go:build darwin && arm64

package ocrrs

// macOS arm64 (Apple Silicon): CPU + OpenCL + Vulkan + Metal + CoreML.
// See cgo_darwin_amd64.go for the rationale on which frameworks are
// linked and which backends are dlopen'd at runtime.

/*
#cgo darwin,arm64 LDFLAGS: ${SRCDIR}/prebuilt/darwin_arm64/libocr_rs_combined.a -lc++ -ldl -lm -lpthread -lobjc
#cgo darwin,arm64 LDFLAGS: -framework Foundation -framework CoreFoundation -framework CoreGraphics
#cgo darwin,arm64 LDFLAGS: -framework Metal -framework MetalKit -framework MetalPerformanceShaders
#cgo darwin,arm64 LDFLAGS: -framework OpenCL -framework CoreML -framework CoreVideo
#cgo darwin,arm64 LDFLAGS: -framework Accelerate -framework IOKit
*/
import "C"
