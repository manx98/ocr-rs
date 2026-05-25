# CMake toolchain fragment used by scripts/build_windows.ps1 to coax MSVC
# into emitting a smaller static archive for MNN.
#
# Default CMAKE_<lang>_FLAGS_RELEASE on MSVC is `/MD /O2 /Ob2 /DNDEBUG`,
# i.e. optimize-for-speed + aggressive inline expansion. For a static
# library that we ship as a prebuilt artifact, archive size matters more
# than the last few percent of inlined hot-path performance, so we swap
# to:
#
#   /Os     optimize for size (less aggressive code expansion)
#   /Ob1    only inline functions explicitly marked `inline`/`__forceinline`
#   /Gw     put each global into its own COMDAT — lets downstream
#           link.exe /OPT:REF strip unused globals
#   /Gy     same idea for functions
#   /Brepro reproducible build (no embedded build timestamp)
#   /DNDEBUG preserve the default Release define
#
# We deliberately keep /MD (dynamic CRT) — switching to /MT would balloon
# the archive again because each object would re-statically-link parts of
# msvcrt.

foreach(lang C CXX)
  foreach(config RELEASE MINSIZEREL RELWITHDEBINFO)
    set(CMAKE_${lang}_FLAGS_${config}
        "/Os /Ob1 /Gw /Gy /Brepro /DNDEBUG"
        CACHE STRING "size-tuned MSVC ${lang} flags for ${config}" FORCE)
  endforeach()
endforeach()
