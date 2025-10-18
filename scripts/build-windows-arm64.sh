#!/bin/bash
# Build script for Windows ARM64 using MinGW-w64

set -e

# Add ARM64 toolchain to PATH
export PATH="/clangarm64/bin:$PATH"

echo "Building Vectorscan for Windows ARM64..."

# Check if we're running in the right environment
if [[ "$MSYSTEM" != "MINGW64" && "$MSYSTEM" != "UCRT64" ]]; then
    echo "Warning: This script should be run in MSYS2 MINGW64 or UCRT64 environment"
    echo "Current MSYSTEM: $MSYSTEM"
fi

# Set environment variables for cross-compilation
export CMAKE_SYSTEM_NAME=Windows
export CMAKE_SYSTEM_PROCESSOR=ARM64

# Try to find the ARM64 cross-compiler
ARM64_GCC=""
ARM64_GPP=""
ARM64_AR=""
ARM64_RANLIB=""

# Check common locations for ARM64 cross-compiler
# First check if we have the ARM64 CLANG tools available
if command -v /clangarm64/bin/aarch64-w64-mingw32-gcc.exe &> /dev/null; then
    ARM64_GCC="/clangarm64/bin/aarch64-w64-mingw32-gcc.exe"
    ARM64_GPP="/clangarm64/bin/aarch64-w64-mingw32-g++.exe"
    # Use LLVM archiver since it's available
    ARM64_AR="/clangarm64/bin/llvm-ar.exe"
    ARM64_RANLIB="/clangarm64/bin/llvm-ranlib.exe"
    echo "Using CLANGARM64 ARM64 cross-compilation toolchain"
elif [[ "$MSYSTEM" == "CLANGARM64" ]] && command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
    ARM64_GCC="/clangarm64/bin/clang.exe"
    ARM64_GPP="/clangarm64/bin/clang++.exe"
    ARM64_AR="/clangarm64/bin/llvm-ar.exe"
    ARM64_RANLIB="/clangarm64/bin/llvm-ranlib.exe"
    echo "Using CLANGARM64 native toolchain"
elif command -v aarch64-w64-mingw32-gcc &> /dev/null; then
    ARM64_GCC="aarch64-w64-mingw32-gcc"
    ARM64_GPP="aarch64-w64-mingw32-g++"
    ARM64_AR="aarch64-w64-mingw32-ar"
    ARM64_RANLIB="aarch64-w64-mingw32-ranlib"
    echo "Using mingw-w64 GCC toolchain"
elif command -v /mingw64/bin/aarch64-w64-mingw32-gcc &> /dev/null; then
    ARM64_GCC="/mingw64/bin/aarch64-w64-mingw32-gcc"
    ARM64_GPP="/mingw64/bin/aarch64-w64-mingw32-g++"
    ARM64_AR="/mingw64/bin/aarch64-w64-mingw32-ar"
    ARM64_RANLIB="/mingw64/bin/aarch64-w64-mingw32-ranlib"
    echo "Using mingw64 GCC toolchain"
else
    echo "Error: ARM64 cross-compiler not found!"
    echo "Please install mingw-w64 ARM64 toolchain:"
    echo "  pacman -S mingw-w64-clang-aarch64-gcc mingw-w64-clang-aarch64-g++"
    exit 1
fi

echo "Using ARM64 cross-compiler: $ARM64_GCC"

# Set compiler environment
export CC="$ARM64_GCC"
export CXX="$ARM64_GPP"
export AR="$ARM64_AR"
export RANLIB="$ARM64_RANLIB"

# Create build directory
BUILD_DIR="build-windows-arm64"
echo "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo "Configuring with CMake..."
cmake .. \
    -G "MinGW Makefiles" -DCMAKE_MAKE_PROGRAM="mingw32-make" \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_SYSTEM_PROCESSOR=ARM64 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_AR="$AR" \
    -DCMAKE_RANLIB="$RANLIB" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DFAT_RUNTIME=OFF \
    -DBUILD_AVX2=OFF \
    -DBUILD_AVX512=OFF \
    -DBUILD_SVE=OFF \
    -DBUILD_SVE2=OFF \
    -DSIMDE_BACKEND=OFF \
    -DSIMDE_NATIVE=OFF \
    -DBUILD_UNIT=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-D_WIN32_WINNT=0x0A00 -DWIN32_LEAN_AND_MEAN" \
    -DCMAKE_CXX_FLAGS="-D_WIN32_WINNT=0x0A00 -DWIN32_LEAN_AND_MEAN -Wno-deprecated-declarations -Wno-error=deprecated-declarations"

# Build
NPROC=$(nproc 2>/dev/null || echo 4)
echo "Building with $NPROC parallel jobs..."
mingw32-make -j$NPROC

echo ""
echo "Build completed successfully!"
echo ""

# Copy required runtime DLLs to bin directory
echo "Copying runtime DLLs..."
BIN_DIR="$(pwd)/bin"
mkdir -p "$BIN_DIR"

# Function to find and copy DLL
copy_dll() {
    local dll_name="$1"
    local dll_path=""
    
    # Try to find the DLL in the toolchain directories
    if [[ -f "/clangarm64/bin/$dll_name" ]]; then
        dll_path="/clangarm64/bin/$dll_name"
    elif [[ -f "/mingw64/bin/$dll_name" ]]; then
        dll_path="/mingw64/bin/$dll_name"
    elif [[ -f "$(dirname "$ARM64_GCC")/$dll_name" ]]; then
        dll_path="$(dirname "$ARM64_GCC")/$dll_name"
    fi
    
    if [[ -n "$dll_path" && -f "$dll_path" ]]; then
        echo "  Copying $dll_name from $dll_path"
        cp "$dll_path" "$BIN_DIR/"
    else
        echo "  Warning: $dll_name not found in toolchain directories"
    fi
}

# Copy C++ runtime DLLs based on the toolchain being used
if [[ "$ARM64_GCC" == *"clang"* ]]; then
    # For Clang/LLVM toolchain
    copy_dll "libc++.dll"
    copy_dll "libunwind.dll"
elif [[ "$ARM64_GCC" == *"gcc"* ]]; then
    # For GCC toolchain
    copy_dll "libstdc++-6.dll"
    copy_dll "libgcc_s_seh-1.dll"
fi

# Always try to copy these common runtime DLLs
copy_dll "libwinpthread-1.dll"

echo "Runtime DLL copy completed."
echo ""


echo ""
echo "Output files:"
echo "  Static libraries:"
echo "    $(pwd)/lib/libhs.a"
echo "    $(pwd)/lib/libhs_runtime.a"
echo "  Shared libraries:"
echo "    $(pwd)/bin/hs.dll"
echo "    $(pwd)/bin/hs_runtime.dll"
echo "  Import libraries:"
echo "    $(pwd)/lib/libhs.dll.a"
echo "    $(pwd)/lib/libhs_runtime.dll.a"
echo "  Runtime DLLs:"
echo "    $(pwd)/bin/*.dll (C++ runtime and dependencies)"
echo ""
echo "All required runtime DLLs have been copied to the bin directory."
echo "To use these libraries, copy the entire bin/ and lib/ directories to your target Windows ARM64 system."
