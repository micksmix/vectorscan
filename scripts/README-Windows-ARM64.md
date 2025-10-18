# Windows ARM64 Build Instructions

[![Build Windows ARM64](https://github.com/username/vectorscan-ming/actions/workflows/build-windows-arm64.yml/badge.svg)](https://github.com/username/vectorscan-ming/actions/workflows/build-windows-arm64.yml)

This document provides instructions for building Vectorscan on Windows ARM64 machines using MinGW-w64.

## CI/CD Status

This repository includes automated GitHub Actions that build and test the ARM64 Windows version on every push and pull request. See [CI Documentation](.github/README-CI.md) for details.

## Prerequisites

1. **Windows ARM64 machine** (Windows 10 version 1903+ or Windows 11)
2. **MSYS2** installed from https://www.msys2.org/

## Quick Start

1. **Install MSYS2** and open the MINGW64 terminal
2. **Run the environment setup script**:
   ```bash
   ./setup-env.sh
   ```
3. **Build the project**:
   ```bash
   ./build-windows-arm64.sh
   ```

## Manual Setup (Alternative)

If you prefer to set up the environment manually:

### 1. Install MSYS2

Download and install MSYS2 from https://www.msys2.org/

### 2. Update MSYS2

Open MSYS2 MINGW64 terminal and run:
```bash
pacman -Syu
```

### 3. Install MinGW-w64 ARM64 Toolchain

```bash
pacman -S mingw-w64-clang-aarch64-gcc \
          mingw-w64-clang-aarch64-g++ \
          mingw-w64-clang-aarch64-cmake \
          mingw-w64-clang-aarch64-make \
          mingw-w64-clang-aarch64-pkg-config
```

### 4. Install Dependencies

```bash
pacman -S mingw-w64-clang-aarch64-boost \
          mingw-w64-clang-aarch64-sqlite3 \
          mingw-w64-clang-aarch64-ragel \
          mingw-w64-clang-aarch64-pcre
```

### 5. Build the Project

```bash
# Navigate to the project directory
cd /path/to/vectorscan-ming

## Ensure your PATH has the clangarm64 toolset
export PATH="/clangarm64/bin:$PATH"

# Create build directory
mkdir build-windows-arm64
cd build-windows-arm64

# Configure
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
    -DBUILD_SHARED_LIBS=ON \
    -DFAT_RUNTIME=ON \
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
mingw32-make -j$(nproc)
```

## Output Files

After a successful build, you'll find the following files:

### Static Libraries
- `lib/libhs.a` - Main Vectorscan library
- `lib/libhs_runtime.a` - Runtime-only library

### Shared Libraries (DLLs)
- `bin/hs.dll` - Main Vectorscan DLL
- `bin/hs_runtime.dll` - Runtime-only DLL

### Import Libraries
- `lib/libhs.dll.a` - Import library for hs.dll
- `lib/libhs_runtime.dll.a` - Import library for hs_runtime.dll

### Headers
- Header files in the source tree can be used for compilation

## Features Supported

- **ARM NEON**: Fully supported (Windows ARM64 guarantees NEON availability)
- **SVE/SVE2**: Currently disabled on Windows (not exposed by Windows APIs)
- **Static Linking**: Supported
- **Dynamic Linking**: Supported

## Limitations

1. **Fat Runtime**: Disabled on Windows ARM64
2. **SVE/SVE2**: Not currently supported on Windows
3. **Unit Tests**: Disabled by default for cross-compilation

## Using the Libraries

### Static Linking Example

```c
// Compile with: aarch64-w64-mingw32-gcc -I/path/to/headers main.c -L/path/to/lib -lhs -lws2_32
#include "hs.h"

int main() {
    // Your Vectorscan code here
    return 0;
}
```

### Dynamic Linking Example

```c
// Compile with: aarch64-w64-mingw32-gcc -I/path/to/headers main.c -L/path/to/lib -lhs
// Make sure hs.dll is in PATH or same directory as executable
#include "hs.h"

int main() {
    // Your Vectorscan code here
    return 0;
}
```

## Troubleshooting

### Compiler Not Found
If you get "ARM64 cross-compiler not found", ensure you've installed the ARM64 toolchain:
```bash
pacman -S mingw-w64-clang-aarch64-gcc mingw-w64-clang-aarch64-g++
```

### CMake Configuration Fails
Make sure you're running in the MINGW64 environment and have CMake installed:
```bash
pacman -S mingw-w64-clang-aarch64-cmake
```

### Missing Dependencies
Install all required dependencies:
```bash
pacman -S mingw-w64-clang-aarch64-boost \
          mingw-w64-clang-aarch64-ragel \
          mingw-w64-clang-aarch64-pcre
```

### Build Errors
1. Check that all Windows-specific modifications are in place
2. Ensure you're using the correct compiler flags
3. Verify that ARM64 target detection is working

## Architecture Detection

The build system now properly detects Windows ARM64 targets by checking for:
- `_M_ARM64` (MSVC-style macro)
- `__ARM_ARCH_ISA_A64` (GCC-style macro)

## CPU Feature Detection

On Windows ARM64, the build system:
- Automatically enables NEON support (guaranteed on Windows ARM64)
- Uses Windows APIs for feature detection where available
- Falls back to safe defaults for unsupported features

## Performance Notes

- NEON SIMD instructions provide good performance on ARM64
- SVE support may be added in future Windows versions
- Performance should be competitive with x86_64 builds for most workloads
