//go:build linux && amd64 && !ocrrs_cuda

package ocrrs

// Default Linux/amd64 variant: CPU + OpenCL + Vulkan + OpenGL.
//
// `-lGL` is a *link-time* requirement (MNN's OpenGL backend doesn't
// dlopen libGL), so consumers must have libGL.so.1 reachable at link
// time — `apt install libgl1-mesa-dev` on Debian/Ubuntu, `dnf install
// mesa-libGL-devel` on RHEL/Fedora. Headless containers usually ship
// libGL through the `libgl1` runtime package.
//
// `-lOpenCL` / `-lvulkan` are NOT added: MNN dlopens both ICDs at
// runtime, so requested but absent drivers just disable the backend
// without breaking the link.

// #cgo linux,amd64 LDFLAGS: ${SRCDIR}/prebuilt/linux_amd64/libocr_rs_combined.a -lstdc++ -ldl -lm -lpthread -lGL
import "C"
