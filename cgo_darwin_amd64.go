//go:build darwin && amd64

package ocrrs

/*
#cgo darwin,amd64 LDFLAGS: ${SRCDIR}/prebuilt/darwin_amd64/libocr_rs_combined.a -lc++ -ldl -lm -lpthread
#cgo darwin,amd64 LDFLAGS: -framework Foundation -framework CoreFoundation -framework CoreGraphics
#cgo darwin,amd64 LDFLAGS: -framework Metal -framework MetalKit -framework MetalPerformanceShaders
#cgo darwin,amd64 LDFLAGS: -framework Accelerate -framework IOKit
*/
import "C"
