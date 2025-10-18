#!/bin/bash
# Build script for Windows x64 using MinGW-w64 (MINGW64)
set -e

# Ensure MINGW64 (and UCRT64 fallback) toolchains are first
export PATH="/mingw64/bin:/ucrt64/bin:$PATH"

echo "Building Vectorscan for Windows x64..."

if [[ "$MSYSTEM" != "MINGW64" && "$MSYSTEM" != "UCRT64" ]]; then
  echo "Warning: Run this in MSYS2 MINGW64 or UCRT64"
  echo "Current MSYSTEM: $MSYSTEM"
fi

export CMAKE_SYSTEM_NAME=Windows
export CMAKE_SYSTEM_PROCESSOR=x86_64

# Detect compilers (prefer MinGW triplet GCC, then clang)
if command -v /mingw64/bin/x86_64-w64-mingw32-gcc.exe >/dev/null 2>&1; then
  X64_CC="/mingw64/bin/x86_64-w64-mingw32-gcc.exe"
  X64_CXX="/mingw64/bin/x86_64-w64-mingw32-g++.exe"
  # Prefer LLVM binutils if present
  X64_AR="$(command -v /mingw64/bin/llvm-ar     || command -v /mingw64/bin/ar     || echo ar)"
  X64_RANLIB="$(command -v /mingw64/bin/llvm-ranlib || command -v /mingw64/bin/ranlib || echo ranlib)"
  TOOLSET="gcc-triplet"
  echo "Using MinGW-w64 GCC: $X64_CC"
elif command -v clang >/dev/null 2>&1 && command -v clang++ >/dev/null 2>&1; then
  X64_CC="$(command -v clang)"
  X64_CXX="$(command -v clang++)"
  X64_AR="$(command -v llvm-ar || echo ar)"
  X64_RANLIB="$(command -v llvm-ranlib || echo ranlib)"
  TOOLSET="clang"
  echo "Using Clang/LLVM: $X64_CC"
else
  echo "Error: x64 compiler not found (neither x86_64-w64-mingw32-gcc nor clang present)"
  exit 1
fi

export CC="$X64_CC"
export CXX="$X64_CXX"
export AR="$X64_AR"
export RANLIB="$X64_RANLIB"

BUILD_DIR="build-windows-x64"
echo "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Harmonize generator: if cache exists and generator != Ninja, wipe the dir
if [[ -f CMakeCache.txt ]]; then
  CACHED_GEN=$(sed -n 's/^CMAKE_GENERATOR:INTERNAL=//p' CMakeCache.txt)
  if [[ "$CACHED_GEN" != "Ninja" ]]; then
    echo "Existing build dir uses generator: $CACHED_GEN. Recreating for Ninja..."
    cd ..
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
  fi
fi

echo "Configuring with CMake (toolset: $TOOLSET, generator: Ninja)..."
cmake .. \
  -G Ninja \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_AR="$AR" \
  -DCMAKE_RANLIB="$RANLIB" \
  -DBUILD_STATIC_LIBS=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DFAT_RUNTIME=OF \
  -DBUILD_AVX2=ON \
  -DBUILD_AVX512=OFF \
  -DSIMDE_BACKEND=OFF \
  -DSIMDE_NATIVE=OFF \
  -DBUILD_UNIT=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-D_WIN32_WINNT=0x0A00 -DWIN32_LEAN_AND_MEAN" \
  -DCMAKE_CXX_FLAGS="-D_WIN32_WINNT=0x0A00 -DWIN32_LEAN_AND_MEAN -Wno-deprecated-declarations -Wno-error=deprecated-declarations"

NPROC=$(nproc 2>/dev/null || echo 8)
echo "Building with $NPROC parallel jobs..."
cmake --build . --config Release -j"$NPROC"

echo ""
echo "Build completed successfully!"
echo ""

echo "Copying runtime DLLs to bin/..."
BIN_DIR="$(pwd)/bin"
mkdir -p "$BIN_DIR"

copy_dll() {
  local dll="$1"
  local p=""
  if [[ -f "/mingw64/bin/$dll" ]]; then
    p="/mingw64/bin/$dll"
  elif [[ -n "$(command -v "$dll" 2>/dev/null)" ]]; then
    p="$(command -v "$dll")"
  fi
  if [[ -n "$p" && -f "$p" ]]; then
    echo "  Copying $dll from $p"
    cp -f "$p" "$BIN_DIR/"
  else
    echo "  Warning: $dll not found"
  fi
}

if [[ "$TOOLSET" == "clang" ]]; then
  copy_dll "libc++.dll"
  copy_dll "libunwind.dll"
else
  copy_dll "libstdc++-6.dll"
  copy_dll "libgcc_s_seh-1.dll"
fi
copy_dll "libwinpthread-1.dll"

echo ""
echo "Output files (x64):"
echo "  Static libraries:"
echo "    $(pwd)/lib/libhs.a"
echo "    $(pwd)/lib/libhs_runtime.a"
echo "  Shared libraries:"
if [[ -f "$(pwd)/bin/hs.dll" ]]; then
  echo "    $(pwd)/bin/hs.dll"
elif [[ -f "$(pwd)/bin/libhs.dll" ]]; then
  echo "    $(pwd)/bin/libhs.dll"
else
  echo "    (no hs DLL found at expected names; check build output)"
fi
echo "  Import libraries:"
echo "    $(pwd)/lib/libhs.dll.a"
echo "    $(pwd)/lib/libhs_runtime.dll.a"
echo "  Runtime DLLs:"
echo "    $(pwd)/bin/*.dll"
echo ""
