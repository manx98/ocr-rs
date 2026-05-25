//go:build windows && amd64

package ocrrs

// The Windows prebuilt archive is built with MSVC (target
// x86_64-pc-windows-msvc), so consumers must compile their cgo with the
// MSVC toolchain too:
//
//   - Install Visual Studio Build Tools (or full VS).
//   - Run `go build` from a Developer Command Prompt or after sourcing
//     vcvars64.bat, so that cl.exe / link.exe / lib.exe are on PATH.
//   - Set `CC=cl` (and optionally `CXX=cl`) so cgo selects the MSVC
//     driver instead of the default MinGW gcc.
//
// At runtime the binary additionally needs OpenCL.dll and vulkan-1.dll
// on PATH if the OpenCL or Vulkan backends are actually used; modern
// GPU drivers ship both.

/*
#cgo windows,amd64 LDFLAGS: ${SRCDIR}/prebuilt/windows_amd64/ocr_rs_combined.lib
#cgo windows,amd64 LDFLAGS: ws2_32.lib userenv.lib bcrypt.lib advapi32.lib
#cgo windows,amd64 LDFLAGS: ole32.lib oleaut32.lib uuid.lib psapi.lib shell32.lib
*/
import "C"
