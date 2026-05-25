//go:build linux && amd64 && ocrrs_cuda

package ocrrs

// CUDA variant of the Linux/amd64 build, selected via `-tags ocrrs_cuda`.
//
// In addition to everything the default variant links, MNN's CUDA
// backend is statically baked in — so the resulting Go binary has hard
// link-time dependencies on `libcuda` (NVIDIA driver), `libcudart`
// (CUDA runtime), `libcublas`, and `libcudnn`. None of these are
// dlopen'd; without them present at link time the cgo step will fail,
// and without them present at runtime the binary won't start.
//
// Install CUDA Toolkit + cuDNN on the build host:
//   apt install nvidia-cuda-toolkit libcudnn8-dev  (Debian/Ubuntu)
//   or use the official NVIDIA repo packages.

// #cgo linux,amd64 LDFLAGS: ${SRCDIR}/prebuilt/linux_amd64_cuda/libocr_rs_combined.a -lstdc++ -ldl -lm -lpthread -lGL -lcuda -lcudart -lcublas -lcudnn
import "C"
