//go:build windows && amd64 && ocrrs_cuda

package ocrrs

// CUDA variant of the Windows/amd64 build, selected via `-tags ocrrs_cuda`.
//
// Same MSVC tooling requirement as the default variant, plus the
// archive references CUDA Toolkit and cuDNN. The build host must have
// cuda.lib / cudart.lib / cublas.lib / cudnn.lib reachable through
// the `LIB` env var (vcvars64 + CUDA Toolkit + cuDNN normally set
// this up); at runtime the matching DLLs (cudart64_*.dll,
// cublas64_*.dll, cudnn64_*.dll) need to be on PATH, alongside an
// NVIDIA driver.

/*
#cgo windows,amd64 LDFLAGS: ${SRCDIR}/prebuilt/windows_amd64_cuda/ocr_rs_combined.lib
#cgo windows,amd64 LDFLAGS: ws2_32.lib userenv.lib bcrypt.lib advapi32.lib
#cgo windows,amd64 LDFLAGS: ole32.lib oleaut32.lib uuid.lib psapi.lib shell32.lib
#cgo windows,amd64 LDFLAGS: cuda.lib cudart.lib cublas.lib cudnn.lib cusolver.lib cusparse.lib
*/
import "C"
