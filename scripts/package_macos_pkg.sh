#!/usr/bin/env bash
set -e

# =====================================================================
# AirFile - macOS Native PKG Wizard Installer Generator
# Creates a standard Apple Installer package (.pkg) that guides the user
# through Introduction -> Destination -> Installation -> Summary wizard.
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_PATH="${ROOT_DIR}/build/macos/Build/Products/Release/AirFile.app"
PKG_OUTPUT="${ROOT_DIR}/AirFile.pkg"

if [ ! -d "${APP_PATH}" ]; then
    if [ -d "${ROOT_DIR}/build/macos/Build/Products/Release/airfile_mac.app" ]; then
        APP_PATH="${ROOT_DIR}/build/macos/Build/Products/Release/airfile_mac.app"
    else
        echo "Building release app first..."
        fvm flutter build macos --release
    fi
fi

echo "=== Building Apple Installer Package (.pkg) ==="
rm -f "${PKG_OUTPUT}"

productbuild \
    --component "${APP_PATH}" /Applications \
    --identifier "com.antigravity.airfile" \
    --version "1.0.0" \
    "${PKG_OUTPUT}"

echo "======================================================="
echo "✅ Successfully generated: ${PKG_OUTPUT} ($(du -h "${PKG_OUTPUT}" | awk '{print $1}'))"
echo "======================================================="
