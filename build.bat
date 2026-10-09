@echo off
rem mdlcc/studiomdl - pure MSVC build, no MSBuild, no CMake, no MinGW.
rem Usage: build.bat [Release|Debug] [x64|x86]
rem NOTE: delayed expansion is required below: values like
rem "C:\Program Files (x86)\..." contain parens which would otherwise
rem close parenthesized blocks early during parse-time expansion.
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "CONFIG=%~1"
if "%CONFIG%"=="" set "CONFIG=Release"
set "ARCH=%~2"
if "%ARCH%"=="" set "ARCH=x64"

if /i not "!ARCH!"=="x64" if /i not "!ARCH!"=="x86" (
  echo Unknown arch "!ARCH!". Use x64 or x86.
  exit /b 1
)
if /i not "!CONFIG!"=="Release" if /i not "!CONFIG!"=="Debug" (
  echo Unknown config "!CONFIG!". Use Release or Debug.
  exit /b 1
)

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
dir "!VSWHERE!" >nul 2>&1
if errorlevel 1 (
  echo vswhere not found: !VSWHERE!
  exit /b 1
)

rem NOTE: no for-loop here on purpose: a vswhere path with parens
rem (Program Files (x86)) breaks FOR IN-paren parsing after expansion.
set "VSINSTALL="
"!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "%TEMP%\mdlcc-vsinstall.txt"
set /p VSINSTALL=<"%TEMP%\mdlcc-vsinstall.txt"
del "%TEMP%\mdlcc-vsinstall.txt" >nul 2>&1
if not defined VSINSTALL (
  echo No Visual Studio with MSVC found.
  exit /b 1
)
echo Using MSVC from: %VSINSTALL%

if /i "!ARCH!"=="x64" (
  call "!VSINSTALL!\VC\Auxiliary\Build\vcvars64.bat" >nul
) else (
  call "!VSINSTALL!\VC\Auxiliary\Build\vcvars32.bat" >nul
)
if errorlevel 1 exit /b 1

set "OUTDIR=bin\%CONFIG%"
if /i "!ARCH!"=="x86" set "OUTDIR=bin\%CONFIG%-x86"
if not exist "!OUTDIR!" mkdir "!OUTDIR!"
if not exist obj mkdir obj

rem /EHsc is required: the compiler reports errors via C++ exceptions.
set "CXXFLAGS=/nologo /W3 /EHsc /std:c++17 /D_CRT_SECURE_NO_WARNINGS /I src /I src/utils /I src/format /I src/format/image /I src/monsters"
if /i "!CONFIG!"=="Release" (
  set "CXXFLAGS=!CXXFLAGS! /O2 /GL /DNDEBUG /MT"
  set "LDFLAGS=/LTCG"
) else (
  set "CXXFLAGS=!CXXFLAGS! /Od /Zi /MTd"
  set "LDFLAGS="
)

cl !CXXFLAGS! src\utils\cmdlib.cpp src\utils\mathlib.cpp src\utils\stripification.cpp src\format\image\bmpread.cpp src\format\qc.cpp src\studiomdl.cpp src\writemdl.cpp /Fe:"%OUTDIR%\studiomdl.exe" /Fo:obj\ /link !LDFLAGS!
if errorlevel 1 exit /b 1

echo Built %OUTDIR%\studiomdl.exe
