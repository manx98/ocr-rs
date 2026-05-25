//go:build darwin && amd64

package ocrrs

// macOS amd64: CPU + OpenCL + Vulkan + Metal + CoreML.
//
// OpenCL is a deprecated-but-still-shipping system framework; Metal /
// MetalKit / MetalPerformanceShaders are required for the Metal
// backend; CoreML / Foundation underpin BackendCoreML on Apple Silicon
// (where it talks to the Neural Engine).
//
// `-lvulkan` is intentionally NOT added: MNN dlopens libvulkan at
// runtime if the Vulkan backend is selected. Users wanting Vulkan on
// macOS must have MoltenVK / Vulkan SDK installed; otherwise the
// Vulkan backend simply fails to initialise while CPU/Metal/CoreML
// keep working.

/*
#cgo darwin,amd64 LDFLAGS: ${SRCDIR}/prebuilt/darwin_amd64/libocr_rs_combined.a -lc++ -ldl -lm -lpthread -lobjc
#cgo darwin,amd64 LDFLAGS: -framework Foundation -framework CoreFoundation -framework CoreGraphics
#cgo darwin,amd64 LDFLAGS: -framework Metal -framework MetalKit -framework MetalPerformanceShaders
#cgo darwin,amd64 LDFLAGS: -framework OpenCL -framework CoreML -framework CoreVideo
#cgo darwin,amd64 LDFLAGS: -framework Accelerate -framework IOKit
*/
import "C"
