#!/bin/bash
# Environment setup script for Windows ARM64 cross-compilation

echo "Setting up environment for Windows ARM64 cross-compilation..."

# Check if we're in MSYS2
if [[ -z "$MSYSTEM" ]]; then
    echo "Error: This script should be run in MSYS2 environment"
    echo "Please open MSYS2 MINGW64 terminal and run this script"
    exit 1
fi

echo "Current MSYSTEM: $MSYSTEM"


# Function to check and install packages
install_if_missing() {
    local package=$1
    if ! pacman -Qi "$package" &> /dev/null; then
        echo "Installing $package..."
        pacman -S --noconfirm "$package"
    else
        echo "✓ $package is already installed"
    fi
}

# Install MinGW-w64 ARM64 toolchain
echo "Checking MinGW-w64 ARM64 toolchain..."
install_if_missing mingw-w64-clang-aarch64-gcc
install_if_missing mingw-w64-clang-aarch64-gcc-compat
install_if_missing mingw-w64-clang-aarch64-cmake
install_if_missing mingw-w64-clang-aarch64-make
install_if_missing mingw-w64-clang-aarch64-pkg-config

# Install dependencies
echo "Checking dependencies..."
install_if_missing mingw-w64-clang-aarch64-boost
install_if_missing mingw-w64-clang-aarch64-sqlite3
install_if_missing mingw-w64-clang-aarch64-ragel
install_if_missing mingw-w64-clang-aarch64-pcre

# Add ARM64 toolchain to PATH
export PATH="/clangarm64/bin:$PATH"

# Verify installation
echo ""
echo "Verifying installation..."
if command -v aarch64-w64-mingw32-gcc &> /dev/null; then
    echo "✓ ARM64 GCC found: $(which aarch64-w64-mingw32-gcc): $(aarch64-w64-mingw32-gcc --version | head -1)"
    
else
    echo "✗ ARM64 GCC not found"
fi

if command -v aarch64-w64-mingw32-g++ &> /dev/null; then
    echo "✓ ARM64 G++ found: $(which aarch64-w64-mingw32-g++)"
else
    echo "✗ ARM64 G++ not found"
fi

if command -v cmake &> /dev/null; then
    echo "✓ CMake found: $(which cmake): $(cmake --version | head -1)"
    
else
    echo "✗ CMake not found"
fi

if command -v ragel &> /dev/null; then
    echo "✓ Ragel found: $(which ragel): $(ragel --version | head -1)"
else
    echo "✗ Ragel not found"
fi

echo ""
echo "Environment setup complete!"
echo "You can now run the build script:"
echo "  ./build-windows-arm64.sh"
