//go:build linux && amd64

package ocrrs

// #cgo linux,amd64 LDFLAGS: ${SRCDIR}/prebuilt/linux_amd64/libocr_rs_combined.a -lstdc++ -ldl -lm -lpthread
import "C"
