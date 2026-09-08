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

if [ ! -d "${APP_PATH}" ]; then
    echo "=== [1/4] Building macOS Release Application ==="
    fvm flutter build macos --release
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

echo "=== [3/4] Creating Formatted Disk Image ==="
TEMP_DMG="${ROOT_DIR}/build/macos/AirFile-temp.dmg"
rm -f "${TEMP_DMG}" "${DMG_OUTPUT}"

hdiutil create \
    -volname "AirFile" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "${TEMP_DMG}"

# Attempt visual styling via AppleScript if GUI is available
echo "Configuring Finder window presentation..."
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | grep "/Volumes/AirFile" || true)
if [ -n "${MOUNT_OUTPUT}" ]; then
    MOUNT_POINT="/Volumes/AirFile"
    osascript -e '
        tell application "Finder"
            tell disk "AirFile"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {400, 200, 940, 520}
                set viewOptions to the icon view options of container window
                set icon size of viewOptions to 120
                set arrangement of viewOptions to not arranged
                try
                    set position of item "AirFile.app" of container window to {130, 160}
                    set position of item "Applications" of container window to {410, 160}
                end try
                close
                open
                update without registering applications
                delay 1
            end tell
        end tell
    ' || echo "Notice: Headless or permission-restricted AppleScript execution; standard view applied."
    
    sync || true
    hdiutil detach "${MOUNT_POINT}" -force || true
    sync
    sleep 2
fi

echo "=== [4/4] Compressing Final Production DMG ==="
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_OUTPUT}"

rm -f "${TEMP_DMG}"
rm -rf "${STAGING_DIR}"

echo "======================================================="
echo "✅ Successfully generated: ${DMG_OUTPUT} ($(du -h "${DMG_OUTPUT}" | awk '{print $1}'))"
echo "======================================================="
