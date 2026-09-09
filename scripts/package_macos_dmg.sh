#!/usr/bin/env bash
set -e

# =====================================================================
# AirFile - macOS Professional DMG Disk Image Generator
# Creates a polished, distributable AirFile.dmg with Applications shortcut
# =====================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_PATH="${ROOT_DIR}/build/macos/Build/Products/Release/AirFile.app"
DMG_OUTPUT="${ROOT_DIR}/AirFile.dmg"
STAGING_DIR="${ROOT_DIR}/build/macos/dmg_staging"

FLUTTER_CMD="flutter"
if command -v fvm >/dev/null 2>&1; then
    FLUTTER_CMD="fvm flutter"
fi

if [ ! -d "${APP_PATH}" ]; then
    echo "=== [1/4] Building macOS Release Application ==="
    $FLUTTER_CMD build macos --release
else
    echo "=== [1/4] Found existing Release Application ==="
fi

if [ ! -d "${APP_PATH}" ]; then
    # Fallback check if build produced airfile_mac.app
    if [ -d "${ROOT_DIR}/build/macos/Build/Products/Release/airfile_mac.app" ]; then
        APP_PATH="${ROOT_DIR}/build/macos/Build/Products/Release/airfile_mac.app"
    else
        echo "Error: Application bundle not found at ${APP_PATH}"
        exit 1
    fi
fi

echo "=== [2/4] Preparing DMG Staging Environment ==="
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

echo "Copying ${APP_PATH} to staging..."
cp -R "${APP_PATH}" "${STAGING_DIR}/AirFile.app"

echo "Creating /Applications shortcut..."
ln -s /Applications "${STAGING_DIR}/Applications"

echo "=== [3/3] Creating Compressed Disk Image (AirFile.dmg) ==="
rm -f "${DMG_OUTPUT}"

hdiutil create \
    -volname "AirFile" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_OUTPUT}"

rm -rf "${STAGING_DIR}"

echo "======================================================="
echo "✅ Successfully generated: ${DMG_OUTPUT} ($(du -h "${DMG_OUTPUT}" | awk '{print $1}'))"
echo "======================================================="
