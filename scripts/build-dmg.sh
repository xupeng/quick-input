#!/usr/bin/env bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# ── Configuration ──────────────────────────────────────────────
SCHEME="QuickInput"
APP_NAME="Quick Input"
DMG_NAME="QuickInput.dmg"
VOLUME_NAME="Quick Input"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/QuickInput/QuickInput.xcodeproj"
DERIVED_DATA="${PROJECT_DIR}/build/DerivedData"
DMG_OUTPUT="${PROJECT_DIR}/${DMG_NAME}"

# ── Cleanup on exit ───────────────────────────────────────────
STAGING_DIR=""
cleanup() {
    if [[ -n "${STAGING_DIR}" && -d "${STAGING_DIR}" ]]; then
        rm -rf "${STAGING_DIR}"
    fi
}
trap cleanup EXIT

# ── Generate Xcode project ───────────────────────────────────
if command -v xcodegen &>/dev/null; then
    echo "==> Generating Xcode project..."
    xcodegen generate --spec "${PROJECT_DIR}/QuickInput/project.yml" --project "${PROJECT_DIR}/QuickInput"
else
    echo "Error: xcodegen not found. Install with: brew install xcodegen" >&2
    exit 1
fi

# ── Local signing config ─────────────────────────────────────
XCCONFIG="${PROJECT_DIR}/QuickInput/Local.xcconfig"
XCCONFIG_FLAG=""
if [[ -f "${XCCONFIG}" ]]; then
    XCCONFIG_FLAG="-xcconfig ${XCCONFIG}"
    echo "==> Using local signing config: ${XCCONFIG}"
fi

# ── Build ──────────────────────────────────────────────────────
echo "==> Building ${APP_NAME} (Release)..."
xcodebuild clean build \
    ${XCCONFIG_FLAG} \
    -project "${XCODEPROJ}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    -quiet

APP_PATH="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
    echo "Error: ${APP_PATH} not found" >&2
    exit 1
fi
echo "==> Build succeeded: ${APP_PATH}"

# ── Stage DMG contents ────────────────────────────────────────
STAGING_DIR="$(mktemp -d)"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# ── Create DMG ────────────────────────────────────────────────
# Remove old DMG if present
rm -f "${DMG_OUTPUT}"

echo "==> Creating DMG..."
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_OUTPUT}" \
    -quiet

# ── Verify ────────────────────────────────────────────────────
echo "==> Verifying DMG..."
hdiutil verify "${DMG_OUTPUT}" -quiet

# ── Done ──────────────────────────────────────────────────────
DMG_SIZE="$(du -h "${DMG_OUTPUT}" | cut -f1 | xargs)"
echo ""
echo "DMG created successfully:"
echo "  Path: ${DMG_OUTPUT}"
echo "  Size: ${DMG_SIZE}"
