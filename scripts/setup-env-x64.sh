#!/bin/bash
# Environment setup script for Windows x64 (MINGW64)

set -e

echo "Setting up environment for Windows x64 (MINGW64)..."

if [[ -z "$MSYSTEM" ]]; then
  echo "Error: Run this inside MSYS2 (MINGW64 shell recommended)."
  exit 1
fi
echo "Current MSYSTEM: $MSYSTEM"

install_if_missing() {
  local pkg="$1"
  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    echo "Installing $pkg..."
    pacman -S --noconfirm --needed "$pkg"
  else
    echo "✓ $pkg already installed"
  fi
}

# Toolchain + basics (prefer GCC meta since it's on every mirror)
install_if_missing mingw-w64-x86_64-toolchain
install_if_missing mingw-w64-x86_64-cmake
install_if_missing mingw-w64-x86_64-make
install_if_missing mingw-w64-x86_64-pkg-config
install_if_missing mingw-w64-x86_64-ragel

# Common libs used by examples/tools
install_if_missing mingw-w64-x86_64-boost
install_if_missing mingw-w64-x86_64-sqlite3
install_if_missing mingw-w64-x86_64-pcre
install_if_missing mingw-w64-x86_64-ninja


# Put x64 toolchain first
export PATH="/mingw64/bin:$PATH"

echo
echo "Verifying installation..."
FOUND=""

if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "✓ GCC: $(which x86_64-w64-mingw32-gcc) — $(x86_64-w64-mingw32-gcc --version | head -1)"
  FOUND=gcc
fi

# Optional: Clang if you want it too (won’t fail if absent)
if pacman -Ss '^mingw-w64-clang-x86_64-toolchain$' | grep -q clang; then
  install_if_missing mingw-w64-clang-x86_64-toolchain || true
  if command -v clang >/dev/null 2>&1; then
    echo "✓ Clang: $(which clang) — $(clang --version | head -1)"
    [[ -z "$FOUND" ]] && FOUND=clang
  fi
fi

if command -v cmake >/dev/null 2>&1; then
  echo "✓ CMake: $(which cmake) — $(cmake --version | head -1)"
else
  echo "✗ CMake not found (unexpected)"
fi

if command -v ragel >/dev/null 2>&1; then
  echo "✓ Ragel: $(which ragel) — $(ragel --version | head -1)"
else
  echo "✗ Ragel not found (unexpected)"
fi

if [[ -z "$FOUND" ]]; then
  echo "✗ No x64 compiler in /mingw64/bin (check pacman output above)."
  exit 1
fi

echo
echo "Environment setup complete for x64 (compiler: $FOUND)."
echo "Run: ./build-windows-x64.sh"
