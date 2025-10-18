@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================
rem Vectorscan multi-arch build (Windows)
rem Always builds: ARM64 (CLANGARM64) and x64 (MINGW64)
rem ============================================

rem --- Locate MSYS2 ---
if not defined MSYS2_HOME set "MSYS2_HOME=C:\tools\msys64"
if not exist "%MSYS2_HOME%\usr\bin\bash.exe" (
  echo [ERROR] MSYS2 not found at "%MSYS2_HOME%"
  exit /b 1
)
set "BASH=%MSYS2_HOME%\usr\bin\bash.exe"

rem --- Repo root (strip trailing backslash) ---
set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"

rem --- Convert to MSYS path: C:\foo\bar -> /c/foo/bar ---
set "REPO_DRIVE=%REPO_ROOT:~0,1%"
set "REPO_PATH=%REPO_ROOT:~2%"
set "REPO_UNIX=/%REPO_DRIVE%%REPO_PATH%"
set "REPO_UNIX=%REPO_UNIX:\=/%"

rem --- PATH for this session ---
set "PATH=%MSYS2_HOME%\usr\bin;%MSYS2_HOME%\bin;%PATH%"

rem --- Bash prefixes: always cd into repo first ---
set "BASH_MSYS=export MSYSTEM=MSYS; cd '%REPO_UNIX%'; set -euo pipefail;"
set "BASH_CLANG=export MSYSTEM=CLANGARM64; export CHERE_INVOKING=1; cd '%REPO_UNIX%'; set -euo pipefail;"
set "BASH_MINGW64=export MSYSTEM=MINGW64; export CHERE_INVOKING=1; cd '%REPO_UNIX%'; set -euo pipefail;"

pushd "%REPO_ROOT%" >nul 2>&1

echo.
echo === Ensure base tools and both toolchains ===
"%BASH%" -lc "%BASH_MSYS% pacman -Sy --noconfirm --needed ^
  base-devel git file findutils coreutils tar gzip ^
  cmake ninja python ragel ^
  mingw-w64-clang-aarch64-toolchain ^
  mingw-w64-clang-x86_64-toolchain" || goto :fail

echo.
echo === Update submodules ===
where git >nul 2>&1
if %ERRORLEVEL%==0 (
  git submodule update --init --recursive || goto :fail
) else (
  "%BASH%" -lc "%BASH_MSYS% git submodule update --init --recursive" || goto :fail
)

echo.
echo === Sanity check: list scripts/ ===
"%BASH%" -lc "%BASH_MSYS% ls -l scripts || true"

rem ------------------------------------------------------------
rem ARM64 (CLANGARM64)
rem ------------------------------------------------------------
echo.
echo === [ARM64] Environment setup ===
"%BASH%" -lc "%BASH_CLANG% chmod +x ./scripts/setup-env.sh ./scripts/build-windows-arm64.sh && ./scripts/setup-env.sh" || goto :fail

echo.
echo === [ARM64] Build ===
"%BASH%" -lc "%BASH_CLANG% ./scripts/build-windows-arm64.sh" || goto :fail

echo.
echo === [ARM64] Verify ===
"%BASH%" -lc ^
"%BASH_CLANG% echo 'Checking artifacts (ARM64)...'; ^
  test -f 'build-windows-arm64/lib/libhs.a' || { echo '✗ libhs.a missing'; exit 1; }; ^
  test -f 'build-windows-arm64/bin/hs.dll' || test -f 'build-windows-arm64/bin/libhs.dll' || { echo '✗ hs.dll/libhs.dll missing'; exit 1; }; ^
  echo 'All ARM64 artifacts:'; find build-windows-arm64 -type f \( -name '*.a' -o -name '*.dll' -o -name '*.exe' \) | sort" || goto :fail

echo.
echo === [ARM64] Package ===
"%BASH%" -lc ^
"%BASH_CLANG% rm -rf release-package-arm64 && mkdir -p release-package-arm64/lib release-package-arm64/bin release-package-arm64/include; ^
  cp -f build-windows-arm64/lib/*.a              release-package-arm64/lib/ 2>/dev/null || true; ^
  cp -f build-windows-arm64/lib/*.dll.a          release-package-arm64/lib/ 2>/dev/null || true; ^
  cp -f build-windows-arm64/bin/*.dll            release-package-arm64/bin/ 2>/dev/null || true; ^
  cp -f build-windows-arm64/bin/*.exe            release-package-arm64/bin/ 2>/dev/null || true; ^
  cp -rf include/*                               release-package-arm64/include/ 2>/dev/null || true; ^
  cp -f src/hs*.h                                release-package-arm64/include/ 2>/dev/null || true; ^
  tar -czf vectorscan-windows-arm64.tar.gz -C release-package-arm64 .; ^
  ls -lh vectorscan-windows-arm64.tar.gz" || goto :fail

rem ------------------------------------------------------------
rem x64 (MINGW64)
rem ------------------------------------------------------------
echo.
echo === [x64] Environment setup ===
"%BASH%" -lc "%BASH_MINGW64% chmod +x ./scripts/setup-env-x64.sh ./scripts/build-windows-x64.sh && ./scripts/setup-env-x64.sh" || goto :fail

echo.
echo === [x64] Clean previous build directory (if generator changed) ===
if exist build-windows-x64\CMakeCache.txt rmdir /s /q build-windows-x64

echo.
echo === [x64] Build ===
"%BASH%" -lc "%BASH_MINGW64% ./scripts/build-windows-x64.sh" || goto :fail

echo.
echo === [x64] Verify ===
"%BASH%" -lc ^
"%BASH_MINGW64% echo 'Checking artifacts (x64)...'; ^
  test -f 'build-windows-x64/lib/libhs.a' || { echo '✗ libhs.a missing'; exit 1; }; ^
  test -f 'build-windows-x64/bin/hs.dll' || test -f 'build-windows-x64/bin/libhs.dll' || { echo '✗ hs.dll/libhs.dll missing'; exit 1; }; ^
  echo 'All x64 artifacts:'; find build-windows-x64 -type f \( -name '*.a' -o -name '*.dll' -o -name '*.exe' \) | sort" || goto :fail

echo.
echo === [x64] Package ===
"%BASH%" -lc ^
"%BASH_MINGW64% rm -rf release-package-x64 && mkdir -p release-package-x64/lib release-package-x64/bin release-package-x64/include; ^
  cp -f build-windows-x64/lib/*.a               release-package-x64/lib/ 2>/dev/null || true; ^
  cp -f build-windows-x64/lib/*.dll.a           release-package-x64/lib/ 2>/dev/null || true; ^
  cp -f build-windows-x64/bin/*.dll             release-package-x64/bin/ 2>/dev/null || true; ^
  cp -f build-windows-x64/bin/*.exe             release-package-x64/bin/ 2>/dev/null || true; ^
  cp -rf include/*                              release-package-x64/include/ 2>/dev/null || true; ^
  cp -f src/hs*.h                               release-package-x64/include/ 2>/dev/null || true; ^
  tar -czf vectorscan-windows-x64.tar.gz -C release-package-x64 .; ^
  ls -lh vectorscan-windows-x64.tar.gz" || goto :fail

echo.
echo ============================================
echo ✅ Build complete.
echo   - ARM64 artifacts : %REPO_ROOT%\build-windows-arm64
echo   - ARM64 package   : %REPO_ROOT%\vectorscan-windows-arm64.tar.gz
echo   - x64 artifacts   : %REPO_ROOT%\build-windows-x64
echo   - x64 package     : %REPO_ROOT%\vectorscan-windows-x64.tar.gz
echo ============================================
popd >nul 2>&1
exit /b 0

:fail
echo.
echo ============================================
echo ❌ Build failed. See messages above.
echo ============================================
popd >nul 2>&1
exit /b 1
