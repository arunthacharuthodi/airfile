@echo off
REM =====================================================================
REM AirFile - Windows Build & Installer Generation Script
REM Requires Flutter SDK and Inno Setup (ISCC.exe)
REM =====================================================================

echo [1/3] Building Flutter Windows Release...
call fvm flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter Windows build failed.
    exit /b %ERRORLEVEL%
)

echo [2/3] Checking for Inno Setup Compiler (ISCC.exe)...
where iscc >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
        set "ISCC_PATH=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    ) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
        set "ISCC_PATH=%ProgramFiles%\Inno Setup 6\ISCC.exe"
    ) else (
        echo [WARNING] Inno Setup 6 compiler (ISCC.exe) not found in PATH or standard Program Files.
        echo Please install Inno Setup 6 from https://jrsoftware.org/isdl.php to compile the installer.
        exit /b 1
    )
) else (
    set "ISCC_PATH=iscc"
)

echo [3/3] Compiling AirFile-Setup-x64.exe...
"%ISCC_PATH%" "windows\installer\inno_setup.iss"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Inno Setup compilation failed.
    exit /b %ERRORLEVEL%
)

echo [SUCCESS] Windows Setup Wizard built at build\windows\installer\AirFile-Setup-x64.exe
