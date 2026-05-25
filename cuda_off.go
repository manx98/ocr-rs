//go:build !(amd64 && ocrrs_cuda && (linux || windows))

package ocrrs

// cudaEnabled is false on any build that did not request the
// ocrrs_cuda build tag on a supported platform.
const cudaEnabled = false
