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
        FLUTTER_CMD="flutter"
        if command -v fvm >/dev/null 2>&1; then
            FLUTTER_CMD="fvm flutter"
        fi
        $FLUTTER_CMD build macos --release
    fi
fi

echo "=== Building Apple Installer Package (.pkg) ==="
rm -f "${PKG_OUTPUT}"

PKG_STAGING="${ROOT_DIR}/build/macos/pkg_staging"
rm -rf "${PKG_STAGING}"
mkdir -p "${PKG_STAGING}"
cp -R "${APP_PATH}" "${PKG_STAGING}/AirFile.app"

productbuild \
    --component "${PKG_STAGING}/AirFile.app" /Applications \
    --identifier "com.antigravity.airfile" \
    --version "1.0.0" \
    "${PKG_OUTPUT}"

rm -rf "${PKG_STAGING}"

echo "======================================================="
echo "✅ Successfully generated: ${PKG_OUTPUT} ($(du -h "${PKG_OUTPUT}" | awk '{print $1}'))"
echo "======================================================="
