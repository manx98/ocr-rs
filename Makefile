.PHONY: help linux macos macos-amd64 macos-arm64 windows example run clean

CARGO ?= cargo
GO    ?= go

help:
	@echo "Targets:"
	@echo "  linux        rebuild prebuilt/linux_amd64/libocr_rs_combined.a        (Ubuntu 18.04)"
	@echo "  linux-cuda   rebuild prebuilt/linux_amd64_cuda/libocr_rs_combined.a   (Ubuntu 18.04 + CUDA Toolkit + cuDNN)"
	@echo "  macos        rebuild the prebuilt archive for the host's arch    (run on macOS)"
	@echo "  macos-amd64  cross-build the darwin_amd64 archive                (run on macOS)"
	@echo "  macos-arm64  cross-build the darwin_arm64 archive                (run on macOS)"
	@echo "  windows      rebuild prebuilt/windows_amd64/ocr_rs_combined.lib       (MSVC dev cmd)"
	@echo "  windows-cuda rebuild prebuilt/windows_amd64_cuda/ocr_rs_combined.lib  (MSVC dev cmd + CUDA Toolkit + cuDNN)"
	@echo "  example      build the Go example binary"
	@echo "  run ARGS=... build + run the Go example"
	@echo "  clean        cargo clean and remove the Go example binary"
	@echo ""
	@echo "Backends bundled into each archive: CPU + OpenCL + Vulkan (+Metal on macOS)."
	@echo "GitHub Actions workflow (.github/workflows/prebuilt.yml) builds all targets."

linux:
	bash scripts/build_linux.sh

linux-cuda:
	OCRRS_VARIANT=cuda bash scripts/build_linux.sh

macos:
	bash scripts/build_macos.sh

macos-amd64:
	OCRRS_TARGET=x86_64-apple-darwin bash scripts/build_macos.sh

macos-arm64:
	OCRRS_TARGET=aarch64-apple-darwin bash scripts/build_macos.sh

windows:
	pwsh -File scripts/build_windows.ps1

windows-cuda:
	pwsh -Command "$env:OCRRS_VARIANT='cuda'; & scripts/build_windows.ps1"

example:
	cd examples && $(GO) build -o ocr-example .

run: example
	./examples/ocr-example $(ARGS)

clean:
	cd ocr-rs-c && $(CARGO) clean
	rm -f examples/ocr-example
