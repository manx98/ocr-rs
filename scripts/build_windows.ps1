# Build the Windows/amd64 prebuilt archive (CPU + OpenCL + Vulkan).
#
# Targets x86_64-pc-windows-msvc — ocr-rs's build.rs hard-codes a
# "NMake Makefiles" CMake generator plus /MT/MD compiler flags, both of
# which only make sense with MSVC.
#
# Run from PowerShell after MSVC's vcvars64.bat has been initialised
# (e.g. via ilammy/msvc-dev-cmd in CI, or from a Developer PowerShell).
# The Vulkan SDK and OpenCL.lib must be reachable via the LIB/INCLUDE
# environment variables.
#
# We deliberately stay in PowerShell instead of bash because GHA's
# `shell: bash` is Git Bash, which prepends C:\Program Files\Git\usr\bin
# to PATH — that directory contains a GNU `link` (coreutils) that
# shadows MSVC's link.exe and breaks cargo's linker invocation.
#
# Output: prebuilt/windows_amd64/ocr_rs_combined.lib

$ErrorActionPreference = 'Stop'

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$root    = Split-Path -Parent $here
$shim    = Join-Path $root 'ocr-rs-c'
$target  = if ($env:OCRRS_TARGET) { $env:OCRRS_TARGET } else { 'x86_64-pc-windows-msvc' }
$rel     = Join-Path $shim "target\$target\release"
$variant = if ($env:OCRRS_VARIANT) { $env:OCRRS_VARIANT } else { '' }

if ($variant -eq 'cuda') {
    $out  = Join-Path $root 'prebuilt\windows_amd64_cuda'
    $feat = if ($env:OCRRS_FEATURES) { $env:OCRRS_FEATURES } else { 'opencl vulkan cuda' }
} else {
    $out  = Join-Path $root 'prebuilt\windows_amd64'
    $feat = if ($env:OCRRS_FEATURES) { $env:OCRRS_FEATURES } else { 'opencl vulkan' }
}

# Pin cargo's MSVC linker to the absolute path of link.exe, just in case
# anything later in the build adds a shadowing directory to PATH.
$linkExe = (Get-Command link.exe -ErrorAction Stop |
            Where-Object { $_.Source -notmatch 'Git\\usr\\bin' } |
            Select-Object -First 1).Source
if (-not $linkExe) {
    throw "Could not find MSVC link.exe on PATH (did vcvars run?)"
}
$env:CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER = $linkExe
Write-Host "MSVC link.exe = $linkExe"

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup target add $target | Out-Null
}

Push-Location $shim
try {
    Write-Host "==> cargo build --release --target $target --features '$feat'"
    cargo build --release --target $target --features "$feat"
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

# ----- merge static archives via lib.exe ---------------------------------
$shimLib = Join-Path $rel 'ocr_rs_c.lib'
$buildDir = Join-Path $rel 'build'

$wrapperLib = Get-ChildItem -Path $buildDir -Recurse -Filter 'mnn_wrapper.lib' -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
$mnnLib = Get-ChildItem -Path $buildDir -Recurse -Filter 'MNN.lib' -ErrorAction SilentlyContinue |
    Sort-Object FullName | Select-Object -First 1 -ExpandProperty FullName

foreach ($lib in @($shimLib, $wrapperLib, $mnnLib)) {
    if (-not $lib -or -not (Test-Path $lib)) {
        throw "required archive not found: '$lib'"
    }
}

New-Item -ItemType Directory -Force -Path $out | Out-Null
$combined = Join-Path $out 'ocr_rs_combined.lib'
Remove-Item -Force -ErrorAction SilentlyContinue $combined

Write-Host "==> lib.exe /OUT:$combined ..."
lib.exe /NOLOGO /OUT:$combined $shimLib $wrapperLib $mnnLib
if ($LASTEXITCODE -ne 0) { throw "lib.exe failed (exit $LASTEXITCODE)" }

$size = (Get-Item $combined).Length / 1MB
Write-Host ("==> done: {0} ({1:N1} MiB)" -f $combined, $size)
