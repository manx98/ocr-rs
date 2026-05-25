//go:build windows && amd64 && !ocrrs_cuda

package ocrrs

// Default Windows/amd64 variant: CPU + OpenCL + Vulkan, MSVC linkage.
//
// Consumers must build with the MSVC toolchain:
//   - Install Visual Studio Build Tools (Desktop C++)
//   - Run `go build` from a Developer Command Prompt (or after
//     vcvars64.bat) so cl.exe / link.exe / lib.exe are on PATH
//   - Set CC=cl so cgo uses the MSVC driver, not the default MinGW gcc
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
