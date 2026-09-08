#!/usr/bin/env bash
set -e

# =====================================================================
# AirFile - Universal Multi-Platform Release Packaging Script
# Generates ready-to-share distributions for macOS, Android, and Windows
# Output Directory: ./release_packages/
# =====================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DIST_DIR="${ROOT_DIR}/release_packages"
MACOS_DIST="${DIST_DIR}/macos"
ANDROID_DIST="${DIST_DIR}/android"
WINDOWS_DIST="${DIST_DIR}/windows"

echo "================================================================="
echo "   🚀 AIRFILE - MULTI-PLATFORM RELEASE PACKAGING PIPELINE"
echo "================================================================="
echo "Output Directory: ${DIST_DIR}"
echo ""

# 1. Clean & Prepare Target Directories
echo "📁 Initializing distribution directories..."
rm -rf "${DIST_DIR}"
mkdir -p "${MACOS_DIST}"
mkdir -p "${ANDROID_DIST}"
mkdir -p "${WINDOWS_DIST}"

# =====================================================================
# [1/3] MACOS PACKAGING (DMG, PKG Wizard, and ZIP)
# =====================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "🍏 [1/3] Packaging macOS Distributions..."
echo "-----------------------------------------------------------------"

# Run DMG generator
echo "-> Generating AirFile.dmg (Drag & Drop Disk Image)..."
./scripts/package_macos_dmg.sh

# Run PKG generator
echo "-> Generating AirFile.pkg (Guided Installer Wizard)..."
./scripts/package_macos_pkg.sh

# Generate standalone Zip
echo "-> Packaging AirFile-macOS-Release.zip (Standalone Application)..."
zip -r -q "${MACOS_DIST}/AirFile-macOS-Release.zip" build/macos/Build/Products/Release/AirFile.app

# Move DMG and PKG into macOS distribution folder
mv "${ROOT_DIR}/AirFile.dmg" "${MACOS_DIST}/AirFile.dmg"
mv "${ROOT_DIR}/AirFile.pkg" "${MACOS_DIST}/AirFile.pkg"

# Keep root shortcuts for convenience
cp "${MACOS_DIST}/AirFile.dmg" "${ROOT_DIR}/AirFile.dmg"
cp "${MACOS_DIST}/AirFile.pkg" "${ROOT_DIR}/AirFile.pkg"
cp "${MACOS_DIST}/AirFile-macOS-Release.zip" "${ROOT_DIR}/AirFile-macOS-Release.zip"

echo "✅ macOS packaging completed."

# =====================================================================
# [2/3] ANDROID PACKAGING (Installable APK)
# =====================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "🤖 [2/3] Packaging Android Distribution..."
echo "-----------------------------------------------------------------"

echo "-> Compiling Android Release APK (fvm flutter build apk --release)..."
fvm flutter build apk --release

APK_SOURCE="${ROOT_DIR}/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "${APK_SOURCE}" ]; then
    cp "${APK_SOURCE}" "${ANDROID_DIST}/AirFile-Android.apk"
    cp "${APK_SOURCE}" "${ROOT_DIR}/airfile-release.apk"
    echo "✅ Android packaging completed: ${ANDROID_DIST}/AirFile-Android.apk"
else
    echo "❌ Error: APK not found at ${APK_SOURCE}"
    exit 1
fi

# =====================================================================
# [3/3] WINDOWS SETUP WIZARD & BUILD AUTOMATION
# =====================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "🪟 [3/3] Preparing Windows Distribution & Installer Wizard..."
echo "-----------------------------------------------------------------"

# Copy Inno Setup script & batch builder
cp "${ROOT_DIR}/windows/installer/inno_setup.iss" "${WINDOWS_DIST}/inno_setup.iss"
cp "${ROOT_DIR}/scripts/build_windows_installer.bat" "${WINDOWS_DIST}/build_windows_installer.bat"

# Generate Windows instructions
cat << 'EOF' > "${WINDOWS_DIST}/README_WINDOWS.txt"
====================================================================
AIRFILE - WINDOWS INSTALLER BUILD INSTRUCTIONS
====================================================================

This folder contains the complete setup wizard configuration for AirFile
on Windows (64-bit).

TO BUILD THE STANDALONE 'AirFile-Setup-x64.exe' WIZARD:

1. Requirements on Windows machine:
   - Flutter SDK installed & in PATH
   - Inno Setup 6 (download free from: https://jrsoftware.org/isdl.php)

2. Run the 1-Click Build Script:
   Double-click or run from command prompt:
   > build_windows_installer.bat

3. Output:
   The compiler will generate:
   ..\..\build\windows\installer\AirFile-Setup-x64.exe

FEATURES INCLUDED IN AIRFILE WINDOWS SETUP:
- Modern Windows installation wizard (Welcome -> Install Directory -> Shortcuts -> Finish)
- Installs to C:\Program Files\AirFile
- Creates Desktop & Start Menu shortcuts
- Option to launch on Windows startup
- Automatically configures Windows Firewall for port 53317 (seamless discovery & transfer)
- Clean uninstaller registered in Windows Settings / Add & Remove Programs
====================================================================
EOF

echo "✅ Windows installer configuration prepared."

# =====================================================================
# SUMMARY REPORT
# =====================================================================
echo ""
echo "================================================================="
echo "🎉 ALL PLATFORM DISTRIBUTIONS READY TO SHARE!"
echo "================================================================="
echo ""
echo "Output Directory Structure:"
echo ""
find "${DIST_DIR}" -maxdepth 2 -not -path "${DIST_DIR}" | sort | while read -r item; do
    if [ -d "${item}" ]; then
        echo "📁 $(basename "${item}")/"
    else
        SIZE=$(du -h "${item}" | awk '{print $1}')
        PARENT=$(basename "$(dirname "${item}")")
        echo "   └── $(basename "${item}") (${SIZE})"
    fi
done

echo ""
echo "You can share individual files or zip the entire 'release_packages/' directory."
echo "================================================================="
