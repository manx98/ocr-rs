//go:build darwin && arm64

package ocrrs

/*
#cgo darwin,arm64 LDFLAGS: ${SRCDIR}/prebuilt/darwin_arm64/libocr_rs_combined.a -lc++ -ldl -lm -lpthread
#cgo darwin,arm64 LDFLAGS: -framework Foundation -framework CoreFoundation -framework CoreGraphics
#cgo darwin,arm64 LDFLAGS: -framework Metal -framework MetalKit -framework MetalPerformanceShaders
#cgo darwin,arm64 LDFLAGS: -framework Accelerate -framework IOKit
*/
import "C"
