//go:build amd64 && ocrrs_cuda && (linux || windows)

package ocrrs

// cudaEnabled is true only when the user built with `-tags ocrrs_cuda`
// on a platform where we actually ship a CUDA-enabled prebuilt archive
// (currently linux/amd64 and windows/amd64).
const cudaEnabled = true
