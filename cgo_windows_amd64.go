//go:build windows && amd64

package ocrrs

// #cgo windows,amd64 LDFLAGS: ${SRCDIR}/prebuilt/windows_amd64/libocr_rs_combined.a -lstdc++ -lpthread -lm -lws2_32 -luserenv -lbcrypt -lntdll -lgdi32 -lopengl32
import "C"
